"""ExifData router — CRUD for ExifDatum records."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.exif_datum import ExifDatum
from app.routers.filter_utils import compute_filter_hash, filter_check

router = APIRouter(prefix="/exif_data")
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


# ---------------------------------------------------------------------------
# GET /exif_data
# ---------------------------------------------------------------------------
@router.get("", response_class=HTMLResponse)
def exif_data_index(request: Request, db: Session = Depends(get_db)):
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
        "exif_data/index.html",
        {
            "request": request,
            "exif_list": exif_list,
            "excluded_tags": EXCLUDED_TAGS,
        },
    )


# ---------------------------------------------------------------------------
# GET /exif_data/new
# ---------------------------------------------------------------------------
@router.get("/new", response_class=HTMLResponse)
def exif_data_new(request: Request):
    return templates.TemplateResponse(
        "exif_data/new.html",
        {"request": request, "datum": None, "errors": []},
    )


# ---------------------------------------------------------------------------
# POST /exif_data
# ---------------------------------------------------------------------------
@router.post("", response_class=HTMLResponse)
def exif_data_create(
    request: Request,
    image_id: int = Form(...),
    tag: str = Form(""),
    value: str = Form(""),
    db: Session = Depends(get_db),
):
    errors = []
    if not tag:
        errors.append("Tag can't be blank")

    if errors:
        return templates.TemplateResponse(
            "exif_data/new.html",
            {"request": request, "datum": None, "errors": errors},
            status_code=422,
        )

    datum = ExifDatum(image_id=image_id, tag=tag, value=value)
    db.add(datum)
    db.commit()
    db.refresh(datum)
    return RedirectResponse(url=f"/exif_data/{datum.id}", status_code=303)


# ---------------------------------------------------------------------------
# GET /exif_data/{id}
# ---------------------------------------------------------------------------
@router.get("/{datum_id}", response_class=HTMLResponse)
def exif_data_show(datum_id: int, request: Request, db: Session = Depends(get_db)):
    datum = db.get(ExifDatum, datum_id)
    if datum is None:
        raise HTTPException(status_code=404, detail="ExifDatum not found")
    return templates.TemplateResponse(
        "exif_data/show.html",
        {"request": request, "datum": datum},
    )


# ---------------------------------------------------------------------------
# GET /exif_data/{id}/edit
# ---------------------------------------------------------------------------
@router.get("/{datum_id}/edit", response_class=HTMLResponse)
def exif_data_edit(datum_id: int, request: Request, db: Session = Depends(get_db)):
    datum = db.get(ExifDatum, datum_id)
    if datum is None:
        raise HTTPException(status_code=404, detail="ExifDatum not found")
    return templates.TemplateResponse(
        "exif_data/edit.html",
        {"request": request, "datum": datum, "errors": []},
    )


# ---------------------------------------------------------------------------
# POST /exif_data/{id}/update
# ---------------------------------------------------------------------------
@router.post("/{datum_id}/update", response_class=HTMLResponse)
def exif_data_update(
    datum_id: int,
    request: Request,
    image_id: int = Form(...),
    tag: str = Form(""),
    value: str = Form(""),
    db: Session = Depends(get_db),
):
    datum = db.get(ExifDatum, datum_id)
    if datum is None:
        raise HTTPException(status_code=404, detail="ExifDatum not found")

    errors = []
    if not tag:
        errors.append("Tag can't be blank")

    if errors:
        return templates.TemplateResponse(
            "exif_data/edit.html",
            {"request": request, "datum": datum, "errors": errors},
            status_code=422,
        )

    datum.image_id = image_id
    datum.tag = tag
    datum.value = value
    db.commit()
    return RedirectResponse(url=f"/exif_data/{datum_id}", status_code=303)


# ---------------------------------------------------------------------------
# POST /exif_data/{id}/delete
# ---------------------------------------------------------------------------
@router.post("/{datum_id}/delete", response_class=HTMLResponse)
def exif_data_destroy(datum_id: int, db: Session = Depends(get_db)):
    datum = db.get(ExifDatum, datum_id)
    if datum is None:
        raise HTTPException(status_code=404, detail="ExifDatum not found")
    db.delete(datum)
    db.commit()
    return RedirectResponse(url="/exif_data", status_code=303)
