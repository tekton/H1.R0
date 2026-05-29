"""Images router — full CRUD + /images/{id}/exif."""
from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

import piexif
from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from PIL import Image as PILImage
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.image import Image

router = APIRouter(prefix="/images")
templates = Jinja2Templates(directory="app/templates")

IMAGES_BASE = os.environ.get(
    "IMAGES_BASE",
    os.path.join(os.path.dirname(__file__), "..", "assets", "images"),
)


# ---------------------------------------------------------------------------
# GET /images
# ---------------------------------------------------------------------------
@router.get("", response_class=HTMLResponse)
def images_index(request: Request, db: Session = Depends(get_db)):
    images = db.query(Image).all()
    return templates.TemplateResponse(
        "images/index.html",
        {"request": request, "images": images},
    )


# ---------------------------------------------------------------------------
# GET /images/new
# ---------------------------------------------------------------------------
@router.get("/new", response_class=HTMLResponse)
def images_new(request: Request):
    return templates.TemplateResponse(
        "images/new.html",
        {"request": request, "image": None, "errors": []},
    )


# ---------------------------------------------------------------------------
# POST /images
# ---------------------------------------------------------------------------
@router.post("", response_class=HTMLResponse)
def images_create(
    request: Request,
    location: str = Form(""),
    name: str = Form(""),
    db: Session = Depends(get_db),
):
    errors = []
    if not location:
        errors.append("Location can't be blank")

    if errors:
        return templates.TemplateResponse(
            "images/new.html",
            {"request": request, "image": None, "errors": errors, "location": location, "name": name},
            status_code=422,
        )

    image = Image(location=location, name=name)
    db.add(image)
    db.commit()
    db.refresh(image)
    return RedirectResponse(url=f"/images/{image.id}", status_code=303)


# ---------------------------------------------------------------------------
# GET /images/{id}
# ---------------------------------------------------------------------------
@router.get("/{image_id}", response_class=HTMLResponse)
def images_show(image_id: int, request: Request, db: Session = Depends(get_db)):
    image = db.get(Image, image_id)
    if image is None:
        raise HTTPException(status_code=404, detail="Image not found")

    exif_pairs = _gather_exif_from_file(image, db)

    return templates.TemplateResponse(
        "images/show.html",
        {"request": request, "image": image, "exif_pairs": exif_pairs},
    )


# ---------------------------------------------------------------------------
# GET /images/{id}/edit
# ---------------------------------------------------------------------------
@router.get("/{image_id}/edit", response_class=HTMLResponse)
def images_edit(image_id: int, request: Request, db: Session = Depends(get_db)):
    image = db.get(Image, image_id)
    if image is None:
        raise HTTPException(status_code=404, detail="Image not found")
    return templates.TemplateResponse(
        "images/edit.html",
        {"request": request, "image": image, "errors": []},
    )


# ---------------------------------------------------------------------------
# POST /images/{id} (PUT via form method override)
# ---------------------------------------------------------------------------
@router.post("/{image_id}/update", response_class=HTMLResponse)
def images_update(
    image_id: int,
    request: Request,
    location: str = Form(""),
    name: str = Form(""),
    db: Session = Depends(get_db),
):
    image = db.get(Image, image_id)
    if image is None:
        raise HTTPException(status_code=404, detail="Image not found")

    errors = []
    if not location:
        errors.append("Location can't be blank")

    if errors:
        return templates.TemplateResponse(
            "images/edit.html",
            {"request": request, "image": image, "errors": errors},
            status_code=422,
        )

    image.location = location
    image.name = name
    db.commit()
    return RedirectResponse(url=f"/images/{image_id}", status_code=303)


# ---------------------------------------------------------------------------
# POST /images/{id}/delete (DELETE via form method override)
# ---------------------------------------------------------------------------
@router.post("/{image_id}/delete", response_class=HTMLResponse)
def images_destroy(image_id: int, db: Session = Depends(get_db)):
    image = db.get(Image, image_id)
    if image is None:
        raise HTTPException(status_code=404, detail="Image not found")
    db.delete(image)
    db.commit()
    return RedirectResponse(url="/images", status_code=303)


# ---------------------------------------------------------------------------
# GET /images/{id}/exif
# ---------------------------------------------------------------------------
@router.get("/{image_id}/exif", response_class=HTMLResponse)
def images_get_exif(image_id: int, request: Request, db: Session = Depends(get_db)):
    image = db.get(Image, image_id)
    if image is None:
        raise HTTPException(status_code=404, detail="Image not found")

    exif_pairs = _gather_exif_from_file(image, db)

    return templates.TemplateResponse(
        "images/get_exif_data.html",
        {"request": request, "image": image, "exif_pairs": exif_pairs},
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _gather_exif_from_file(image: Image, db: Session) -> dict:
    """
    Read raw EXIF data directly from the image file (mirrors EXIFGatherFile.rb).
    Returns a flat dict of {tag_name: value_str}.
    """
    filepath = os.path.normpath(os.path.join(IMAGES_BASE, image.location))
    result: dict = {}
    if not os.path.exists(filepath):
        return result

    try:
        img = PILImage.open(filepath)
        exif_bytes = img.info.get("exif")
        if not exif_bytes:
            return result
        exif_dict = piexif.load(exif_bytes)
    except Exception:
        return result

    for ifd_name, ifd_data in exif_dict.items():
        if ifd_name == "thumbnail" or not isinstance(ifd_data, dict):
            continue
        for tag_id, raw_value in ifd_data.items():
            tag_info = piexif.TAGS.get(ifd_name, {}).get(tag_id, {})
            tag_name = tag_info.get("name", str(tag_id))
            if isinstance(raw_value, bytes):
                value_str = raw_value.decode("utf-8", errors="replace").strip("\x00")
            else:
                value_str = str(raw_value)
            result[tag_name] = value_str

    return result
