"""
H1.R0 — FastAPI application factory.
"""
from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.routers import browse, images, exif_data, exif_parse, filter, searches, thumbnails

app = FastAPI(title="H1.R0", version="2.0.0")

# ---------------------------------------------------------------------------
# Static files — serve app/assets/images at /assets/images
# This mirrors the Rails asset path used throughout the templates.
# ---------------------------------------------------------------------------
_assets_dir = Path(__file__).parent / "assets" / "images"
_assets_dir.mkdir(parents=True, exist_ok=True)

app.mount(
    "/assets/images",
    StaticFiles(directory=str(_assets_dir)),
    name="images",
)

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(browse.router)
app.include_router(images.router)
app.include_router(exif_data.router)
app.include_router(exif_parse.router)
app.include_router(filter.router)
app.include_router(searches.router)
app.include_router(thumbnails.router)
