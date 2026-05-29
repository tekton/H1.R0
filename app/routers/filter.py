"""Filter router — display images matching a saved search hash."""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.exif_datum import ExifDatum
from app.models.image import Image
from app.models.search import Search
from app.routers.filter_utils import compute_filter_hash, filter_check

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

EXCLUDED_TAGS = {
    "date_time_digitized",
    "user_comment",
    "date_time_original",
    "date_time",
    "subject_area",
    "DateTimeDigitized",
    "UserComment",
    "DateTimeOriginal",
    "DateTime",
    "SubjectArea",
}


@router.get("/filter/{hash_filter}", response_class=HTMLResponse)
def hash_filter(hash_filter: str, request: Request, db: Session = Depends(get_db)):
    search = db.query(Search).filter(Search.md5hash == hash_filter).first()
    if search is None:
        raise HTTPException(status_code=404, detail="Search not found")

    # Deserialise — serial is stored as a JSON string
    try:
        serial: list[dict] = json.loads(search.serial) if search.serial else []
    except (ValueError, TypeError):
        serial = []

    if not serial:
        raise HTTPException(status_code=400, detail="Search has no filter criteria")

    # ---------------------------------------------------------------------------
    # Build a parameterised SQL query that finds image_ids matching ALL criteria.
    # The original Rails code built this by string concatenation (SQL injection
    # risk). We use SQLAlchemy text() with named bind params instead.
    #
    # Logic: find image_ids that have ALL tag/value pairs (AND semantics).
    # We express this as: for each (tag, value) pair count how many rows match,
    # then HAVING count(*) == len(serial).
    # ---------------------------------------------------------------------------
    clauses = []
    params: dict[str, str] = {}
    for i, t in enumerate(serial):
        tag_key = f"tag_{i}"
        val_key = f"val_{i}"
        clauses.append(f"(tag = :{tag_key} AND value = :{val_key})")
        params[tag_key] = t["tag"]
        params[val_key] = t["value"]

    where_clause = " OR ".join(clauses)
    params["required_count"] = len(serial)

    sql = text(
        f"""
        SELECT ed.image_id
        FROM exif_data ed
        INNER JOIN images i ON ed.image_id = i.id
        WHERE {where_clause}
        GROUP BY ed.image_id
        HAVING count(*) = :required_count
        """
    )

    rows = db.execute(sql, params).fetchall()
    id_array = [row[0] for row in rows]

    # Fetch the matching ExifDatum rows to display thumbnails
    matched_exif: list[ExifDatum] = []
    if id_array:
        matched_exif = (
            db.query(ExifDatum)
            .filter(ExifDatum.image_id.in_(id_array))
            .group_by(ExifDatum.image_id, ExifDatum.id)
            .distinct(ExifDatum.image_id)
            .all()
        )

    # Build refinement tag list (exi2 in Rails)
    refinement_rows = []
    if id_array:
        raw_rows = (
            db.query(
                ExifDatum.tag,
                ExifDatum.value,
                func.count().label("count"),
            )
            .filter(ExifDatum.image_id.in_(id_array))
            .group_by(ExifDatum.tag, ExifDatum.value)
            .order_by(ExifDatum.tag.asc())
            .all()
        )

        for row in raw_rows:
            # New filter = existing serial entries + this new tag/value
            new_tags = [{"tag": t["tag"], "value": t["value"]} for t in serial]
            new_tags.append({"tag": row.tag, "value": row.value})
            h = compute_filter_hash(new_tags)
            filter_check(h, new_tags, db)
            refinement_rows.append(
                {
                    "tag": row.tag,
                    "value": row.value,
                    "count": row.count,
                    "hash": h,
                }
            )

    return templates.TemplateResponse(
        "filter/hash_filter.html",
        {
            "request": request,
            "search": search,
            "serial": serial,
            "matched_exif": matched_exif,
            "refinement_rows": refinement_rows,
            "excluded_tags": EXCLUDED_TAGS,
        },
    )
