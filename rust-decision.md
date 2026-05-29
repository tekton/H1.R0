# Decision: Rust as a Migration Target for H1.R0

## Summary

Rust is a viable but significantly harder path compared to Python+FastAPI for this app. The performance wins are real but not needed here. The ecosystem is nearly sufficient but has meaningful gaps. Recommended **only if** performance at scale or a single-binary deployment is a hard requirement; otherwise Python is the pragmatic choice.

---

## What H1.R0 Actually Needs

Before evaluating Rust, it helps to be concrete about the workload:

- Serve HTML pages from a PostgreSQL-backed image catalogue (~hundreds to low thousands of rows)
- Parse JPEG EXIF tags from files on disk and store them in the DB
- Resize JPEG images to thumbnails (200×133) via background jobs
- Filter images by combined EXIF tag sets using a hash-keyed search table
- Run background jobs (EXIF extraction, thumbnail generation) asynchronously via a Redis queue

None of this is CPU-bound in a way that Rails or Python is the bottleneck. The bottleneck is I/O: disk reads for images, DB queries for EXIF/filter lookups.

---

## Rust Ecosystem Fit

### Web Framework

**Axum** (on Tokio) is the closest thing to a modern, ergonomic Rust web framework. It's mature and well-maintained. Actix-web is also an option — higher raw throughput in benchmarks, slightly less ergonomic API.

- Route definition, middleware, and JSON handling are all first-class
- HTML templating via **Tera** (Jinja2-compatible syntax — direct map from ERB)
- No equivalent of Rails' asset pipeline; static files served directly

### Database / ORM

Two real options:

| Library     | Style          | Notes |
|-------------|----------------|-------|
| **SQLx**    | Query-first, async | Raw SQL with compile-time checked queries. No magic. Requires writing SQL. |
| **SeaORM**  | ORM-style, async | More like ActiveRecord. Migrations via `sea-orm-cli`. Less mature than SQLAlchemy. |

For this app, SQLx is the better fit — the filter query is already raw SQL (`ExifDatum.find_by_sql`), and compile-time query checking is a genuine safety win given that the filter logic builds dynamic WHERE clauses.

### Image Processing (Thumbnails)

The **`image`** crate handles JPEG read/resize/write natively in pure Rust — no ImageMagick dependency required.

```rust
use image::imageops::FilterType;

let img = image::open(src_path)?;
let thumb = img.resize(200, 133, FilterType::Lanczos3);
thumb.save(dest_path)?;
```

This is a direct win over both Rails (requires native ImageMagick/RMagick bindings) and Python (Pillow is a C extension). The Rust binary ships with image handling built in.

### EXIF Parsing

**`kamadak-exif`** is the most complete pure-Rust EXIF library. It reads EXIF IFDs and returns typed tag/value pairs.

```rust
use exif::{Reader, In, Tag};

let file = std::fs::File::open(path)?;
let mut bufreader = std::io::BufReader::new(file);
let exif = Reader::new().read_from_container(&mut bufreader)?;
for field in exif.fields() {
    println!("{}: {}", field.tag, field.display_value());
}
```

**Gap:** `kamadak-exif` returns fewer decoded tag names than `exifr` (Ruby) or `piexif` (Python). Some vendor-specific or less common EXIF tags will come back as raw tag IDs rather than human-readable names. This needs verification against your actual image set.

### Background Jobs

No Sidekiq/Celery equivalent exists in Rust that is as mature. Options:

| Option | Notes |
|--------|-------|
| **Tokio tasks** | Async tasks within the same process. No Redis. Simpler but not durable — tasks lost on restart. |
| **Faktory** (via `faktory` crate) | Language-agnostic job queue backed by Faktory server. Closer to Sidekiq's model. The Rust client is functional but not widely used. |
| **RabbitMQ / AMQP** | More infrastructure overhead; probably overkill. |
| Keep Sidekiq | Run the Rust web server alongside a minimal Ruby worker just for jobs — not ideal but practical short-term. |

For this app, Tokio tasks with a simple in-process queue are probably fine since thumbnail generation and EXIF parsing are not critical-path and losing in-flight jobs on restart is tolerable. If durability matters, Faktory is the cleanest path.

---

## Honest Tradeoff Table

| Dimension | Python + FastAPI | Rust + Axum |
|-----------|-----------------|-------------|
| Development speed | Fast — familiar patterns, great stdlib | Slow — borrow checker, longer compile times, more boilerplate |
| Image processing | Pillow (excellent, C-backed) | `image` crate (excellent, pure Rust) — slight edge |
| EXIF support | `piexif` — comprehensive, well-documented | `kamadak-exif` — functional, some tag gaps |
| ORM / DB | SQLAlchemy 2.x — best-in-class | SQLx (query-first) or SeaORM (less mature) — adequate |
| Background jobs | Celery + Redis — proven, production-grade | Tokio tasks or Faktory — workable but less mature |
| Deployment | Docker or bare VM, Python runtime required | Single static binary — genuinely simpler |
| Memory footprint | ~50–100 MB at idle | ~5–15 MB at idle |
| Runtime performance | More than sufficient for this workload | 10–20× faster — also more than sufficient |
| Ecosystem maturity | Excellent for web apps | Good and growing, but thinner |
| Learning curve (from Ruby) | Low — Python reads like Ruby | High — ownership/lifetimes are a conceptual shift |
| YAML → JSON migration needed | Yes | Yes |

---

## When Rust Would Be the Right Call

- You want to ship a single binary with no runtime dependencies (e.g., embedded or constrained deployment)
- You're planning to process very large image collections (thousands of files at once) and want native concurrency with no GIL
- You're actively interested in learning Rust and this is a good vehicle for it
- You want memory safety guarantees enforced at compile time (legitimate, but Python+FastAPI is safe enough for a personal/small-team app)

## When It's Not Worth It

- You want to be productive quickly
- The app will stay roughly this size
- You don't already know Rust — the initial investment is substantial (weeks, not days) before the app is working again
- The EXIF tag gap in `kamadak-exif` affects your data (verify first)

---

## If You Choose Rust: Project Structure

```
h1r0/
├── src/
│   ├── main.rs
│   ├── db.rs               # SQLx pool setup
│   ├── models/
│   │   ├── image.rs
│   │   ├── exif_datum.rs
│   │   └── search.rs
│   ├── routes/
│   │   ├── images.rs
│   │   ├── browse.rs
│   │   ├── exif_parse.rs
│   │   ├── filter.rs
│   │   ├── searches.rs
│   │   └── thumbnails.rs
│   ├── services/
│   │   ├── exif.rs
│   │   └── thumbnail.rs
│   └── workers.rs          # Tokio background task spawning
├── templates/              # Tera .html files
├── static/
│   └── images/
│       └── thumbnails/
├── migrations/             # SQLx migration files
└── Cargo.toml
```

### Key Dependencies (`Cargo.toml`)

```toml
[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
sqlx = { version = "0.7", features = ["runtime-tokio", "postgres", "json"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tera = "1"
image = "0.25"
kamadak-exif = "0.5"
md5 = "0.7"
tower-http = { version = "0.5", features = ["fs"] }   # static file serving
```

---

## Recommendation

**Go with Python + FastAPI** unless you have a specific reason to choose Rust listed above. Both will work; Python gets you there faster with a better job queue story and more complete EXIF support. The Rust path is not wrong — it's a better long-term technical foundation — but the cost is weeks of ramp-up before you have a working app again, for a workload that doesn't demand it.

If you want Rust experience, a reasonable middle path: start with Python+FastAPI to get the app working and de-risk the migration, then port individual services (the thumbnail worker, the EXIF parser) to Rust as standalone binaries called from the Python app. That gives you Rust where it adds value without betting the whole rewrite on learning a new language simultaneously.
