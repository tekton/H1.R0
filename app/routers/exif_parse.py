"""ExifParse router — scan a folder and enqueue EXIF extraction jobs."""
from __future__ import annotations

import os
import re
from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.database import get_db
from app.models.image import Image
from app.workers.exif_worker import process_exif

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

IMAGES_BASE = os.environ.get(
    "IMAGES_BASE",
    os.path.join(os.path.dirname(__file__), "..", "assets", "images"),
)

_JPEG_RE = re.compile(r"\.jpe?g$", re.IGNORECASE)


@router.get("/exif_parse/{folder:path}", response_class=HTMLResponse)
def exif_parse_index(folder: str, request: Request, db: Session = Depends(get_db)):
    """
    Scan *folder* inside IMAGES_BASE for JPEGs.
    For each JPEG, upsert an Image row and enqueue an EXIF extraction job.
    """
    loc = os.path.normpath(os.path.join(IMAGES_BASE, folder))
    queued: list[str] = []
    errors: list[str] = []

    if not os.path.isdir(loc):
        errors.append(f"Directory not found: {loc}")
    else:
        for filename in os.listdir(loc):
            if not _JPEG_RE.search(filename):
                continue

            fname = f"{folder}/{filename}"
            filepath = os.path.join(loc, filename)

            # Upsert: find or create the Image record
            image = db.query(Image).filter(Image.location == fname).first()
            if image is None:
                image = Image(location=fname, name=filename)
                db.add(image)
                try:
                    db.commit()
                    db.refresh(image)
                except IntegrityError:
                    db.rollback()
                    image = db.query(Image).filter(Image.location == fname).first()

            if image:
                process_exif.delay(filepath, image.id)
                queued.append(filename)

    return templates.TemplateResponse(
        "exif_parse/index.html",
        {
            "request": request,
            "folder": folder,
            "queued": queued,
            "errors": errors,
        },
    )
