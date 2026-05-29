"""Thumbnails router — scan a folder and enqueue thumbnail generation jobs."""
from __future__ import annotations

import os
import re

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.workers.thumbnail_worker import generate_thumbnail

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

IMAGES_BASE = os.environ.get(
    "IMAGES_BASE",
    os.path.join(os.path.dirname(__file__), "..", "assets", "images"),
)

_JPEG_RE = re.compile(r"\.jpe?g$", re.IGNORECASE)


@router.get("/thumbnail/{folder:path}", response_class=HTMLResponse)
def thumbnails_create_from_folder(folder: str, request: Request):
    """
    Scan *folder* inside IMAGES_BASE for JPEGs and enqueue a thumbnail job
    for each one.
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
            generate_thumbnail.delay(folder, filename)
            queued.append(filename)

    return templates.TemplateResponse(
        "thumbnails/create_from_folder.html",
        {
            "request": request,
            "folder": folder,
            "queued": queued,
            "errors": errors,
        },
    )
