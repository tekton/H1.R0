# Decision: Go as a Migration Target for H1.R0

## Summary

Go is a strong candidate for this app — stronger than Rust for a practical rewrite and a closer tradeoff with Python than it first appears. The web and database story is excellent, the image processing library is best-in-class, and the deployment model (single binary, no runtime) is a genuine win. The main gap is EXIF library maturity, which needs verification against your image set before committing.

---

## What H1.R0 Actually Needs

- Serve HTML pages from a PostgreSQL-backed image catalogue
- Parse JPEG EXIF tags from files on disk and store them in the DB
- Resize JPEG images to thumbnails (200×133) via background jobs
- Filter images by combined EXIF tag sets using a hash-keyed search table
- Run background jobs (EXIF extraction, thumbnail generation) asynchronously via a Redis queue

---

## Go Ecosystem Fit

### Web Framework

Two good options depending on how much structure you want:

| Framework | Style | Notes |
|-----------|-------|-------|
| **Chi** | Minimal router, stdlib-compatible | Closest to "just use `net/http`" — no magic, no ORM, very readable |
| **Echo** | More batteries-included | Middleware, binding, validation built in. Closer to the Rails feel. |

Either works well. Chi is recommended here — it's idiomatic Go, the routing maps cleanly to your existing routes, and it keeps the codebase easy to reason about.

HTML templating is handled by Go's stdlib **`html/template`** — no third-party dependency needed. Syntax is different from ERB but the conversion is mechanical.

### Database

**`pgx`** is the best PostgreSQL driver for Go — fast, well-maintained, supports all Postgres features including JSON columns.

For query building, two approaches:

| Library | Style | Notes |
|---------|-------|-------|
| **`sqlc`** | Generate Go code from SQL | Write SQL, get type-safe Go structs back. Compile-time safety. Best fit for this app given the existing raw SQL in `filter_controller`. |
| **`sqlx`** | Thin wrapper over `database/sql` | Adds struct scanning. Still write SQL manually. Less setup than sqlc. |
| **GORM** | Full ORM | Most Rails-like. More magic, more gotchas. Not recommended here. |

`sqlc` is the best fit — the filter query is already raw SQL, and getting type-safe generated code from it is a clear win.

### Image Processing (Thumbnails)

**`bimg`** wraps libvips and is the fastest option, but requires a C dependency. For a pure-Go solution, the **`imaging`** package (wraps stdlib `image`) is solid and handles the 200×133 thumbnail resize cleanly with no native deps.

```go
import "github.com/disintegration/imaging"

src, err := imaging.Open(srcPath)
thumb := imaging.Resize(src, 200, 133, imaging.Lanczos)
err = imaging.Save(thumb, destPath)
```

For this app's workload (batch thumbnail generation triggered by a worker), `imaging` is sufficient. `bimg`/libvips would matter at much higher volume.

### EXIF Parsing

**`rwcarlsen/goexif`** is the most widely used Go EXIF library. It decodes standard EXIF tags from JPEGs and returns typed values.

```go
import "github.com/rwcarlsen/goexif/exif"

f, err := os.Open(filepath)
x, err := exif.Decode(f)
x.Walk(exif.WalkFunc(func(name exif.FieldName, tag *tiff.Tag) error {
    fmt.Printf("%s: %s\n", name, tag)
    return nil
}))
```

**Gap (same as Rust):** `goexif` covers the standard EXIF spec well but has thinner coverage of vendor-specific and extended tags compared to Ruby's `exifr`. Verify it produces the same tag set for your actual images before committing. If coverage is insufficient, `bimg` (via libvips) exposes more metadata but pulls in the C dependency.

### Background Jobs

Go's concurrency model makes background jobs straightforward without any queue infrastructure if durability isn't required:

```go
// fire-and-forget within the same process
go func() {
    if err := generateThumbnail(folder, file); err != nil {
        log.Printf("thumbnail error: %v", err)
    }
}()
```

For durable jobs with Redis (closer to the current Sidekiq setup):

| Option | Notes |
|--------|-------|
| **Asynq** | Redis-backed, Sidekiq-inspired API. Best Go equivalent to Sidekiq. Actively maintained. |
| **Machinery** | Also Redis/AMQP-backed. Older, heavier. |
| **Goroutines only** | Fine for this workload if you can tolerate losing in-flight jobs on restart. |

**Asynq** is the recommended path — same Redis you already run, similar mental model to Sidekiq, and straightforward to wire up.

```go
// Enqueue
client := asynq.NewClient(asynq.RedisClientOpt{Addr: "localhost:6379"})
task := asynq.NewTask("thumbnail:generate", payload)
client.Enqueue(task)

// Worker
srv := asynq.NewServer(asynq.RedisClientOpt{Addr: "localhost:6379"}, asynq.Config{})
srv.Run(asynq.HandlerFunc(handleTask))
```

---

## Honest Tradeoff Table

| Dimension | Python + FastAPI | Rust + Axum | **Go + Chi** |
|-----------|-----------------|-------------|-------------|
| Development speed | Fast | Slow | **Medium-fast** — verbose but readable |
| Image processing | Pillow (excellent) | `image` crate (excellent) | `imaging` or `bimg` — very good |
| EXIF support | `piexif` — comprehensive | `kamadak-exif` — some gaps | `goexif` — some gaps (same caveat as Rust) |
| ORM / DB | SQLAlchemy 2.x — best-in-class | SQLx — adequate | `sqlc` + `pgx` — excellent for SQL-first |
| Background jobs | Celery + Redis — proven | Tokio tasks / Faktory — thinner | Asynq + Redis — solid Sidekiq equivalent |
| Deployment | Python runtime required | Single binary | **Single binary** |
| Memory footprint | ~50–100 MB at idle | ~5–15 MB at idle | ~10–20 MB at idle |
| Runtime performance | Sufficient | 10–20× over Python | 5–10× over Python — sufficient and then some |
| Ecosystem maturity | Excellent | Good, growing | **Excellent for web/API** |
| Learning curve (from Ruby) | Low | High | **Medium** — simple language, explicit style |
| Compile times | N/A | Slow | **Fast** |
| YAML → JSON migration | Yes | Yes | Yes |

---

## Go vs. Python: Key Differences for This App

**Go wins:**
- Single binary deployment — no virtualenv, no `requirements.txt`, no runtime version management
- Faster cold starts — relevant if this runs in a container that scales to zero
- Compile-time type checking catches the kind of bugs Rails' duck typing hides
- `sqlc` + `pgx` is arguably better than SQLAlchemy for an app that already uses raw SQL for its most complex query
- Goroutine concurrency handles the folder-scan + batch EXIF/thumbnail pattern naturally

**Python wins:**
- Less boilerplate — Go's explicit error handling and struct definitions add noise
- `piexif` EXIF coverage is more complete
- Celery is more battle-tested than Asynq
- Faster to get to a working app if Go is unfamiliar

---

## If You Choose Go: Project Structure

```
h1r0/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── db/
│   │   ├── db.go             # pgx pool setup
│   │   ├── query.sql         # sqlc source queries
│   │   └── models.go         # sqlc generated
│   ├── handlers/
│   │   ├── images.go
│   │   ├── browse.go
│   │   ├── exif_parse.go
│   │   ├── filter.go
│   │   ├── searches.go
│   │   └── thumbnails.go
│   ├── services/
│   │   ├── exif.go
│   │   └── thumbnail.go
│   └── workers/
│       ├── asynq.go
│       ├── exif_worker.go
│       └── thumbnail_worker.go
├── templates/                # html/template .html files
├── static/
│   └── images/
│       └── thumbnails/
├── migrations/               # plain .sql files
└── go.mod
```

### Key Dependencies (`go.mod`)

```
github.com/go-chi/chi/v5
github.com/jackc/pgx/v5
github.com/sqlc-dev/sqlc          (dev tool — generates DB code)
github.com/disintegration/imaging
github.com/rwcarlsen/goexif/exif
github.com/hibiken/asynq
```

---

## Migration Steps

### Phase 1 — Setup
- [ ] `go mod init`, wire Chi router and pgx pool
- [ ] Set up `sqlc.yaml`, write initial queries, generate models
- [ ] Verify generated structs match existing schema (`images`, `exif_data`, `searches`)

### Phase 2 — Core Routes
- [ ] `GET /` — Browse (random images + EXIF tag counts via `ORDER BY RANDOM() LIMIT 4`)
- [ ] `GET/POST/PUT/DELETE /images` — Images CRUD
- [ ] `GET /images/:id` with EXIF display
- [ ] `GET /exif_data` — ExifDatum CRUD

### Phase 3 — Processing Logic
- [ ] Implement `services/exif.go` using `goexif`; verify tag parity against current data
- [ ] Implement `services/thumbnail.go` using `imaging`; compare output to RMagick thumbnails
- [ ] Wire Asynq workers for both

### Phase 4 — Filter / Search
- [ ] Port `filter_check` hash logic (MD5 of canonical JSON, sorted by tag+value)
- [ ] Write data migration SQL to reserialize `searches.serial` from YAML → JSON
- [ ] Recompute all `md5hash` values
- [ ] Implement `GET /filter/:hash` handler

### Phase 5 — Templates & Static
- [ ] Convert ERB templates to `html/template` syntax
- [ ] Serve `static/` via `http.FileServer`
- [ ] Migrate CoffeeScript to vanilla JS

### Phase 6 — Cutover
- [ ] Run Go server alongside Rails on separate port, both hitting the same DB
- [ ] Verify EXIF, thumbnails, and filter hashes are consistent
- [ ] Swap Procfile entry to `./h1r0`

---

## Risks

| Risk | Mitigation |
|------|-----------|
| `goexif` tag gaps vs `exifr` | Run both against your image set before committing; log all tag names and compare |
| YAML → JSON hash recompute | One-time migration script; run in a transaction with rollback |
| `html/template` auto-escaping | Stricter than ERB — some template tricks may need adjustment |
| No ActiveRecord `first_or_create!` | Write explicit upsert SQL: `INSERT ... ON CONFLICT DO NOTHING` |
| Asynq less proven than Sidekiq | Acceptable for this scale; monitor job failure rate in first weeks |

---

## Recommendation

Go is a better choice than Rust for a full rewrite here, and it's a genuine alternative to Python rather than a clear second place. If you want a single binary, fast compilation, good type safety, and are comfortable writing slightly more explicit code, Go delivers all of that without Rust's learning curve. Python is still the faster path to a working app, but Go's web/database ecosystem is mature enough that the gap is smaller than it used to be.

If the EXIF tag coverage from `goexif` checks out against your image set — **Go is a solid pick**.
