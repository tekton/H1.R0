"""Celery task: extract EXIF data for one image file."""
import logging

from app.workers.celery_app import celery_app
from app.database import SessionLocal
from app.services.exif_service import extract_exif

logger = logging.getLogger(__name__)


@celery_app.task(name="app.workers.exif_worker.process_exif", bind=True, max_retries=3)
def process_exif(self, filepath: str, image_id: int) -> None:
    """Extract EXIF tags from *filepath* and persist for *image_id*."""
    logger.info("ExifWorker: processing %s (image_id=%s)", filepath, image_id)
    try:
        with SessionLocal() as db:
            extract_exif(filepath, image_id, db)
    except Exception as exc:
        logger.error("ExifWorker: error on %s: %s", filepath, exc)
        raise self.retry(exc=exc, countdown=10)
