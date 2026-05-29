"""
EXIF extraction service.

Reads EXIF data from a JPEG file using piexif + Pillow and upserts
ExifDatum rows into the database (one row per tag/value pair).
"""
from __future__ import annotations

import logging
from pathlib import Path

from PIL import Image as PILImage
import piexif
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.models.exif_datum import ExifDatum
from app.models.image import Image

logger = logging.getLogger(__name__)

# Tags we skip when storing to keep the table clean
SKIP_TAGS = {
    "MakerNote",
    "UserComment",
    "thumbnail",
}


def extract_exif(filepath: str, image_id: int, db: Session) -> None:
    """Extract EXIF tags from *filepath* and persist them for *image_id*."""
    path = Path(filepath)
    if not path.exists():
        logger.warning("EXIF extract: file not found: %s", filepath)
        return

    try:
        img = PILImage.open(path)
        exif_bytes = img.info.get("exif")
    except Exception as exc:
        logger.error("EXIF extract: could not open %s: %s", filepath, exc)
        return

    if not exif_bytes:
        logger.info("EXIF extract: no EXIF bytes in %s", filepath)
        return

    try:
        exif_dict = piexif.load(exif_bytes)
    except Exception as exc:
        logger.error("EXIF extract: piexif failed on %s: %s", filepath, exc)
        return

    for ifd_name, ifd_data in exif_dict.items():
        if ifd_name == "thumbnail" or not isinstance(ifd_data, dict):
            continue
        for tag_id, raw_value in ifd_data.items():
            tag_info = piexif.TAGS.get(ifd_name, {}).get(tag_id, {})
            tag_name = tag_info.get("name", str(tag_id))

            if tag_name in SKIP_TAGS:
                continue

            # Convert bytes to string, fall back to repr for complex types
            if isinstance(raw_value, bytes):
                try:
                    value_str = raw_value.decode("utf-8", errors="replace").strip("\x00")
                except Exception:
                    value_str = repr(raw_value)
            else:
                value_str = str(raw_value)

            # ON CONFLICT DO NOTHING — safe upsert
            stmt = (
                pg_insert(ExifDatum)
                .values(image_id=image_id, tag=tag_name, value=value_str)
                .on_conflict_do_nothing()
            )
            try:
                db.execute(stmt)
            except Exception as exc:
                logger.warning(
                    "EXIF insert skipped (%s, %s, %s): %s",
                    image_id, tag_name, value_str, exc,
                )

    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("EXIF extract: commit failed: %s", exc)
