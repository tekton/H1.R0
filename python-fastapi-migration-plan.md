# Migration Plan: Rails → Python + FastAPI

## Overview

Migrate H1.R0 — a photo management app with EXIF parsing, thumbnail generation, and tag-based filtering — from Rails 3.2 to Python 3.12+ with FastAPI. The app is small enough that a full rewrite (not a gradual migration) is the right call. Rails 3.2 is well past EOL and the dependency surface is a liability.

---

## Library Mapping

| Ruby / Rails              | Python / FastAPI                       |
|---------------------------|----------------------------------------|
| Rails (MVC framework)     | FastAPI + Jinja2 (routing + templates) |
| ActiveRecord              | SQLAlchemy 2.x (ORM)                   |
| ActiveRecord migrations   | Alembic                                |
| RMagick / ImageMagick     | Pillow                                 |
| exifr gem                 | `piexif` + `Pillow` (EXIF read/write)  |
| Sidekiq                   | Celery + Redis                         |
| Digest::MD5               | `hashlib.md5` (stdlib)                 |
| YAML serialization        | `json` (stdlib) — switch from YAML     |
| ERB templates             | Jinja2                                 |
| CoffeeScript assets       | Vanilla JS or Vite (drop CoffeeScript) |
| `config/routes.rb`        | FastAPI router decorators              |
| `db/schema.rb`            | Alembic `env.py` + migration scripts   |

---

## Project Structure

```
h1r0/
├── app/
│   ├── main.py               # FastAPI app factory
│   ├── database.py           # SQLAlchemy engine + session
│   ├── models/
│   │   ├── image.py
│   │   ├── exif_datum.py
│   │   └── search.py
│   ├── routers/
│   │   ├── images.py         # /images CRUD
│   │   ├── browse.py         # / root browse
│   │   ├── exif_parse.py     # /exif_parse/:folder
│   │   ├── filter.py         # /filter/:hash
│   │   ├── searches.py       # /searches CRUD
│   │   └── thumbnails.py     # /thumbnail/:folder
│   ├── services/
│   │   ├── exif_service.py   # EXIF extraction logic
│   │   └── thumbnail_service.py
│   ├── workers/
│   │   ├── celery_app.py     # Celery config
│   │   ├── exif_worker.py
│   │   └── thumbnail_worker.py
│   └── templates/            # Jinja2 .html files
├── alembic/
│   └── versions/
├── static/
│   └── images/
│       └── thumbnails/
├── requirements.txt
└── Procfile
```

---

## Data Model

The three tables map directly; no schema changes needed on the DB side.

```python
# models/image.py
class Image(Base):
    __tablename__ = "images"
    id = Column(Integer, primary_key=True)
    location = Column(String)
    name = Column(String)
    exif_data = relationship("ExifDatum", back_populates="image", cascade="all, delete")

# models/exif_datum.py
class ExifDatum(Base):
    __tablename__ = "exif_data"
    id = Column(Integer, primary_key=True)
    image_id = Column(Integer, ForeignKey("images.id"))
    tag = Column(String)
    value = Column(String)
    image = relationship("Image", back_populates="exif_data")

# models/search.py
class Search(Base):
    __tablename__ = "searches"
    id = Column(Integer, primary_key=True)
    md5hash = Column(String, unique=True, index=True)
    serial = Column(JSON)   # replaces YAML serialization — store as JSON array
```

The `serial` column currently holds YAML-serialized arrays of `{tag, value}` dicts. Switch to JSON when migrating data — the structure is identical, just a different serializer.

---

## Key Logic Translations

### EXIF Parsing (`exif_parse_controller.rb` → `exif_service.py`)

```python
from PIL import Image as PILImage
import piexif

def extract_exif(filepath: str, image_id: int, db: Session):
    img = PILImage.open(filepath)
    exif_bytes = img.info.get("exif")
    if not exif_bytes:
        return
    exif_dict = piexif.load(exif_bytes)
    for ifd_name in exif_dict:
        for tag_id, value in exif_dict[ifd_name].items():
            tag_name = piexif.TAGS[ifd_name].get(tag_id, {}).get("name", str(tag_id))
            datum = ExifDatum(image_id=image_id, tag=tag_name, value=str(value))
            db.merge(datum)  # upsert equivalent to first_or_create!
    db.commit()
```

### Thumbnail Generation (`thumbnails_controller.rb` → `thumbnail_service.py`)

```python
from PIL import Image as PILImage

def create_thumbnail(src_path: str, dest_path: str, size=(200, 133)):
    img = PILImage.open(src_path)
    img.thumbnail(size, PILImage.LANCZOS)
    img.save(dest_path)
```

### Filter / Search Hash (`filter_controller.rb` → `routers/filter.py`)

The current code builds an MD5 from a YAML-serialized list of `{tag, value}` dicts. Replace YAML with canonical JSON (sorted keys) to keep hash consistency:

```python
import hashlib, json

def compute_filter_hash(tags: list[dict]) -> str:
    canonical = json.dumps(sorted(tags, key=lambda x: (x["tag"], x["value"])), sort_keys=True)
    return hashlib.md5(canonical.encode()).hexdigest()
```

**Note:** Existing hashes in the `searches` table were computed from YAML — you'll need a one-time migration script to recompute them in JSON before cutting over.

### Background Jobs (`sidekiq` → `celery`)

```python
# workers/celery_app.py
from celery import Celery
app = Celery("h1r0", broker="redis://localhost:6379/0")

# workers/exif_worker.py
@celery_app.task
def process_exif(filepath: str, image_id: int):
    with SessionLocal() as db:
        extract_exif(filepath, image_id, db)

# workers/thumbnail_worker.py
@celery_app.task
def generate_thumbnail(folder: str, filename: str):
    src = f"static/images/{folder}/{filename}"
    dst = f"static/images/thumbnails/{folder}/{filename}"
    create_thumbnail(src, dst)
```

---

## Migration Steps

### Phase 1 — Setup
- [ ] Initialize FastAPI project, install dependencies
- [ ] Configure SQLAlchemy to point at existing PostgreSQL DB
- [ ] Run `alembic init` and generate initial migration from current schema
- [ ] Verify models reflect existing tables correctly

### Phase 2 — Core Routes
- [ ] `GET /` — Browse (random images + EXIF tag counts)
- [ ] `GET/POST/PUT/DELETE /images` — Images CRUD
- [ ] `GET /images/:id` with EXIF display
- [ ] `GET /exif_data` — ExifDatum CRUD

### Phase 3 — Processing Logic
- [ ] Implement `exif_service.py` and verify EXIF extraction parity
- [ ] Implement `thumbnail_service.py` and verify resize output matches RMagick
- [ ] Wire Celery workers for both

### Phase 4 — Filter / Search
- [ ] Port `filter_check` logic and hash computation
- [ ] Write data migration script to re-serialize `searches.serial` from YAML → JSON
- [ ] Recompute all MD5 hashes using new JSON canonical form
- [ ] Implement `GET /filter/:hash` route

### Phase 5 — Templates & Static
- [ ] Convert ERB templates to Jinja2 (mostly mechanical `<% %>` → `{{ }}`)
- [ ] Migrate CoffeeScript to vanilla JS or compile once to JS and leave static
- [ ] Wire static file serving for `/static/images`

### Phase 6 — Cutover
- [ ] Run both apps against the same DB in parallel for a period
- [ ] Confirm EXIF data, thumbnail output, and filter hashes are consistent
- [ ] Swap Procfile to point at `uvicorn app.main:app`

---

## Dependencies (`requirements.txt`)

```
fastapi>=0.110
uvicorn[standard]>=0.29
sqlalchemy>=2.0
alembic>=1.13
psycopg2-binary>=2.9
pillow>=10.0
piexif>=1.1
celery[redis]>=5.3
jinja2>=3.1
python-multipart>=0.0.9   # for file uploads
```

---

## What Gets Dropped

- CoffeeScript pipeline — compile to JS once or rewrite; no runtime CoffeeScript in Python
- Asset pipeline (sprockets) — serve static files directly via FastAPI's `StaticFiles` or a CDN
- Rails-style `first_or_create!` — replace with SQLAlchemy `merge()` or a manual upsert
- YAML serialization of `searches.serial` — replaced with JSON (requires one-time data migration)

---

## Risks

| Risk | Mitigation |
|------|-----------|
| EXIF hash mismatch (YAML → JSON) | Data migration script + verification pass before cutover |
| `piexif` tag name differences vs `exifr` | Map mismatches during phase 3 testing; log all tags to compare |
| Pillow thumbnail quality vs RMagick | Compare outputs visually; tune `LANCZOS` filter if needed |
| Raw SQL in `filter_controller` | Port carefully — parameterize the query with SQLAlchemy `text()` to avoid injection |
