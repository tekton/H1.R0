"""Browse router — GET / (home page)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.image import Image
from app.models.exif_datum import ExifDatum
from app.routers.filter_utils import compute_filter_hash, filter_check

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

# Tags we filter out of the browse sidebar (noisy / date fields)
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


@router.get("/", response_class=HTMLResponse)
def browse_index(request: Request, db: Session = Depends(get_db)):
    # 4 random images ordered by name then randomised
    images = (
        db.query(Image)
        .order_by(Image.name)
        .order_by(func.random())
        .limit(4)
        .all()
    )

    # Tag/value counts — same query as the Rails controller
    rows = (
        db.query(
            ExifDatum.tag,
            ExifDatum.value,
            func.count().label("count"),
        )
        .group_by(ExifDatum.tag, ExifDatum.value)
        .order_by(ExifDatum.tag.asc())
        .all()
    )

    exif_list = []
    for row in rows:
        tags = [{"tag": row.tag, "value": row.value}]
        h = compute_filter_hash(tags)
        filter_check(h, tags, db)
        exif_list.append(
            {
                "tag": row.tag,
                "value": row.value,
                "count": row.count,
                "hash": h,
            }
        )

    return templates.TemplateResponse(
        "browse/index.html",
        {
            "request": request,
            "images": images,
            "exif_list": exif_list,
            "excluded_tags": EXCLUDED_TAGS,
        },
    )
