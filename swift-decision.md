# Decision: Swift as a Migration Target for H1.R0

## Summary

Swift on the server is viable for this app, with **Vapor** as a mature, Rails-like framework and a good background-job and database story. The decisive constraint is the deployment target: **this will run in a Linux container**, which rules out every Apple-platform image and metadata framework (Core Image, ImageIO, Core Graphics). That pushes image processing and EXIF parsing onto third-party C-library bindings or shelling out to system tools — and that is where Swift is weakest for *this particular* app. Recommended only if you specifically want Swift; Go or Python remain easier fits for an image-centric workload.

---

## The Linux Constraint Is the Whole Story

On macOS, an image app in Swift would be a joy: `ImageIO` reads EXIF natively, `Core Image`/`Core Graphics` resize with one call, all first-party and fast. **None of that exists on Linux.** Swift-on-Linux ships Foundation, the standard library, and swift-nio — but not the Apple media frameworks.

So every imaging and metadata decision below is constrained to: pure-Swift packages, C-library bindings via SwiftPM's C-interop, or shelling out to binaries installed in the container. This is the single biggest difference from the Python/Go/Rust evaluations, where the imaging library was a non-issue.

**Practical consequence:** the container image must install native dependencies (`libgd` or ImageMagick or libvips, plus `exiv2`/`exiftool`) via `apt-get` in the Dockerfile. The Swift binary alone is not self-contained the way the Go binary is.

---

## What H1.R0 Actually Needs

- Serve HTML pages from a PostgreSQL-backed image catalogue
- Parse JPEG EXIF tags from files on disk and store them in the DB
- Resize JPEGs to thumbnails (200×133) via background jobs
- Filter images by combined EXIF tag sets using a hash-keyed search table
- Run background jobs (EXIF extraction, thumbnail generation) asynchronously via Redis

---

## Swift Ecosystem Fit

### Web Framework

**Vapor 4** is the clear choice — it's the most mature Swift server framework, explicitly Linux-first, and structurally the closest thing Swift has to Rails:

- Routing, middleware, content negotiation all first-class
- **Leaf** templating engine (block/inheritance syntax — maps cleanly from ERB)
- Built-in async/await throughout (Swift Concurrency)
- Hummingbird 2 is a lighter alternative, but Vapor's batteries-included ecosystem (ORM + queues + templating in one stack) fits a Rails port better.

### Database / ORM

**Fluent** is Vapor's ORM, with a first-party PostgreSQL driver (`FluentPostgresDriver`):

- ActiveRecord-like model definitions with `@ID`, `@Field`, `@Parent`, `@Children` property wrappers — genuinely the closest ORM ergonomics to Rails of any language evaluated here
- Migrations defined as Swift types
- For the raw filter query, drop to `SQLKit` / `PostgresNIO` with parameterized bindings

This is a real strength — Fluent's model layer will feel familiar coming from ActiveRecord.

### Image Processing (Thumbnails) — THE HARD PART

No Apple frameworks on Linux. Options, worst to best for this app:

| Option | Notes |
|--------|-------|
| **SwiftGD** | Swift wrapper over `libgd`. Pure-ish, simple resize API. Requires `libgd-dev` in the container. JPEG quality and filter options are basic but adequate for 200×133 thumbnails. **Recommended.** |
| **swift-vips** bindings | Wraps libvips — fast, high quality. Bindings are immature/unofficial; you may end up writing your own C-interop shim. |
| **Shell out to ImageMagick** | `Process` → `convert in.jpg -resize 200x133 out.jpg`. Dead simple, matches what RMagick did under the hood anyway. Loses type safety and adds process-spawn overhead, but is the most predictable. Solid fallback. |

SwiftGD is the recommended path; shelling out to ImageMagick is the reliable fallback if `libgd` quality disappoints.

### EXIF Parsing — THE OTHER HARD PART

This is the weakest spot in the entire Swift-on-Linux story for this app. There is **no mature, pure-Swift, Linux-compatible EXIF library**. Options:

| Option | Notes |
|--------|-------|
| **Shell out to `exiftool`** | The most complete EXIF data available anywhere, far exceeding `exifr`/`piexif`/`goexif`. Parse its `-json` output. Requires `exiftool` (Perl) in the container. **Recommended** — best coverage, lowest implementation risk. |
| **Shell out to `exiv2`** | Lighter than exiftool, C++ binary, structured output. Good coverage. |
| **C-interop with `libexif`** | Write a SwiftPM system-library target wrapping `libexif`. Most "native" but the most work, and `libexif` tag coverage is middling. |
| **Hand-roll a JPEG APP1/TIFF IFD parser** | Full control, no deps — but reinventing a solved problem and a real maintenance burden. Not recommended. |

Shelling out to `exiftool -json` is recommended: it inverts the usual gap — instead of *fewer* tags than Ruby (the Rust/Go problem), you get *more* and better-decoded tags than the original Rails app had.

### Background Jobs

**Vapor Queues** with the Redis driver (`QueuesRedisDriver`) is a genuine Sidekiq analogue:

- Same Redis backend the app already uses
- Durable jobs, retries, scheduled jobs
- Define a `Job` type, dispatch with `queue.dispatch(...)`

This is one of Swift's stronger showings — closer to Sidekiq's model than Rust's Tokio-tasks or Go's bare goroutines.

```swift
struct ExifJob: AsyncJob {
    struct Payload: Codable { let filePath: String; let imageID: Int }
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        try await ExifService.extract(path: payload.filePath, imageID: payload.imageID, db: context.application.db)
    }
}
```

### Hashing

`swift-crypto` (Apple's cross-platform Crypto package, works on Linux) provides MD5 via `Insecure.MD5`. Canonicalize the tag list as JSON (sorted), hash the UTF-8 bytes.

---

## Honest Tradeoff Table

| Dimension | Python + FastAPI | Go + Chi | Rust + Axum | **Swift + Vapor** |
|-----------|-----------------|----------|-------------|-------------------|
| Development speed | Fast | Medium-fast | Slow | Medium — clean syntax, slower compiles |
| Image processing | Pillow (excellent) | imaging (very good) | image crate (excellent) | **SwiftGD or shell-out — weakest fit** |
| EXIF support | piexif (comprehensive) | goexif (gaps) | kamadak-exif (gaps) | **exiftool shell-out — best coverage** |
| ORM / DB | SQLAlchemy (best) | sqlc/pgx (excellent) | SQLx (adequate) | **Fluent — most Rails-like ORM** |
| Background jobs | Celery (proven) | Asynq (solid) | Tokio/Faktory (thin) | **Vapor Queues (Sidekiq-like, solid)** |
| Deployment | Python runtime | Single binary | Single binary | Binary **+ apt native deps** (libgd, exiftool) |
| Self-contained container | No | **Yes** | **Yes** | No — needs system packages |
| Memory footprint | ~50–100 MB | ~10–20 MB | ~5–15 MB | ~30–50 MB |
| Runtime performance | Sufficient | Fast | Fastest | Fast |
| Ecosystem maturity (server) | Excellent | Excellent | Good | Good but smaller; Linux is second-class to macOS |
| Learning curve (from Ruby) | Low | Medium | High | Medium — ARC + Concurrency + optionals |
| YAML → JSON migration | Yes | Yes | Yes | Yes |

---

## When Swift Would Be the Right Call

- You or the team already know Swift (iOS/macOS background) and want to consolidate on one language
- You value Fluent's ActiveRecord-like ergonomics and Vapor's all-in-one stack
- You're comfortable installing native deps (`libgd`/ImageMagick + `exiftool`) into the container
- The `exiftool` dependency is acceptable, in exchange for the best EXIF coverage of any option here

## When It's Not Worth It

- You want a self-contained, dependency-free container image (Go is far better)
- You want the imaging/EXIF path to be first-party and type-safe — on Linux, Swift has neither for this domain
- Nobody on the team knows Swift — the payoff doesn't justify it over Python/Go for an image app

---

## If You Choose Swift: Project Structure

```
h1r0/
├── Sources/
│   └── App/
│       ├── entrypoint.swift        # @main, Vapor bootstrap
│       ├── configure.swift         # DB, Leaf, Queues, migrations, routes wiring
│       ├── routes.swift            # route registration
│       ├── Models/
│       │   ├── Image.swift
│       │   ├── ExifDatum.swift
│       │   └── Search.swift
│       ├── Migrations/
│       │   ├── CreateImage.swift
│       │   ├── CreateExifDatum.swift
│       │   └── CreateSearch.swift
│       ├── Controllers/
│       │   ├── BrowseController.swift
│       │   ├── ImagesController.swift
│       │   ├── ExifDataController.swift
│       │   ├── ExifParseController.swift
│       │   ├── FilterController.swift
│       │   ├── SearchesController.swift
│       │   └── ThumbnailsController.swift
│       ├── Services/
│       │   ├── ExifService.swift       # exiftool -json shell-out + parse
│       │   ├── ThumbnailService.swift  # SwiftGD resize
│       │   └── FilterHash.swift        # MD5 of canonical JSON
│       └── Jobs/
│           ├── ExifJob.swift
│           └── ThumbnailJob.swift
├── Resources/
│   └── Views/                      # Leaf .leaf templates
├── Public/                         # static; images served from app/assets/images
├── Package.swift
├── Dockerfile                      # MUST apt-get install libgd-dev libexif + exiftool
└── .env.example
```

### Package.swift dependencies

```swift
dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
    .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
    .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
    .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
    .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.1.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/twostraws/SwiftGD.git", from: "2.5.0"),
]
```

### Dockerfile note (critical)

The runtime image is NOT just the Swift binary. It must include:

```dockerfile
RUN apt-get update && apt-get install -y \
    libgd3 \
    libjpeg62-turbo \
    libexif12 \
    exiftool \
    && rm -rf /var/lib/apt/lists/*
```

Build stage additionally needs `libgd-dev`. This is the concrete cost of the Linux constraint.

---

## Migration Steps

### Phase 1 — Setup
- [ ] `swift package init`, wire `Package.swift`, Vapor `configure.swift`
- [ ] Configure Fluent + PostgreSQL pointing at existing DB
- [ ] Define Fluent migrations matching existing schema (mark as already-applied for the live DB)

### Phase 2 — Core Routes
- [ ] `GET /` — Browse (random 4 images + EXIF tag/value counts with hashes)
- [ ] Images CRUD + `GET /images/:id/exif`
- [ ] ExifDatum CRUD

### Phase 3 — Processing Logic
- [ ] `ExifService` — shell out to `exiftool -json`, map fields to ExifDatum rows, upsert
- [ ] `ThumbnailService` — SwiftGD resize to 200×133 (ImageMagick shell-out as fallback)
- [ ] Wire Vapor Queues jobs for both

### Phase 4 — Filter / Search
- [ ] `FilterHash` — MD5 of canonical JSON (sorted by tag+value) via swift-crypto
- [ ] Data migration: reserialize `searches.serial` YAML → JSON, recompute `md5hash` (N/A if no live DB)
- [ ] `GET /filter/:hash` using parameterized SQLKit query (fix the Rails SQL injection)

### Phase 5 — Templates & Static
- [ ] Convert ERB → Leaf templates
- [ ] Serve `app/assets/images` via Vapor `FileMiddleware` / custom static route
- [ ] Migrate CoffeeScript to vanilla JS

### Phase 6 — Cutover
- [ ] Build container with native deps; run alongside Rails against same DB
- [ ] Verify EXIF data, thumbnail output, filter hashes are consistent
- [ ] Swap process to the Vapor binary

---

## Risks

| Risk | Mitigation |
|------|-----------|
| No native Linux imaging — extra container deps | Accept `libgd`/ImageMagick in Dockerfile; document clearly |
| `exiftool` is a Perl dependency in the container | Acceptable; or switch to `exiv2` (C++) if Perl is unwanted |
| SwiftGD JPEG quality vs RMagick | Compare output; fall back to ImageMagick shell-out if needed |
| Process-spawn overhead (shelling out per file) | Jobs are async/queued, not request-path — overhead is tolerable |
| Swift Linux ecosystem smaller than macOS | Stick to Vapor's first-party packages, which are well-maintained on Linux |
| Raw filter SQL injection (from Rails original) | Use SQLKit parameterized bindings |

---

## Recommendation

Swift + Vapor is a **competent but not ideal** fit for this app under the Linux-container constraint. The web layer (Vapor), ORM (Fluent — the most Rails-like of any option), and job queue (Vapor Queues — the most Sidekiq-like) are genuine strengths. But the two things this app is *most about* — image resizing and EXIF parsing — are exactly where Swift-on-Linux is weakest, forcing C-library bindings or shell-outs and a non-self-contained container.

Choose Swift here only if the team already knows it and values consolidating on one language. For an image-processing app specifically, **Go** (self-contained binary, decent imaging) or **Python** (Pillow + piexif, zero friction) remain the easier recommendations. The one silver lining unique to Swift: shelling out to `exiftool` gives you the *best* EXIF coverage of any option in this whole evaluation.
