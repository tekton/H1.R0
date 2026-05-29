"""
Thumbnail generation service.

Resizes a source JPEG to fit within 200x133 pixels (maintaining aspect ratio)
using Pillow's LANCZOS filter — equivalent to RMagick's resize_to_fit!.
"""
from __future__ import annotations

import logging
from pathlib import Path

from PIL import Image as PILImage

logger = logging.getLogger(__name__)

THUMBNAIL_SIZE = (200, 133)


def create_thumbnail(src_path: str, dest_path: str, size: tuple[int, int] = THUMBNAIL_SIZE) -> None:
    """Resize *src_path* to *size* and write to *dest_path*."""
    src = Path(src_path)
    if not src.exists():
        logger.warning("Thumbnail: source not found: %s", src_path)
        return

    dest = Path(dest_path)
    dest.parent.mkdir(parents=True, exist_ok=True)

    try:
        img = PILImage.open(src)
        img.thumbnail(size, PILImage.LANCZOS)
        img.save(dest)
        logger.info("Thumbnail created: %s", dest_path)
    except Exception as exc:
        logger.error("Thumbnail creation failed %s → %s: %s", src_path, dest_path, exc)
