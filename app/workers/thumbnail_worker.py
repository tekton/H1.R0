"""Celery task: generate a thumbnail for one image file."""
import logging
import os

from app.workers.celery_app import celery_app
from app.services.thumbnail_service import create_thumbnail

logger = logging.getLogger(__name__)

# Base path where images are stored (mirrors Rails app/assets/images/)
IMAGES_BASE = os.environ.get(
    "IMAGES_BASE",
    os.path.join(os.path.dirname(__file__), "..", "assets", "images"),
)


@celery_app.task(name="app.workers.thumbnail_worker.generate_thumbnail", bind=True, max_retries=3)
def generate_thumbnail(self, folder: str, filename: str) -> None:
    """Create a thumbnail for *folder*/*filename*."""
    logger.info("ThumbnailWorker: %s / %s", folder, filename)
    src = os.path.normpath(os.path.join(IMAGES_BASE, folder, filename))
    dst = os.path.normpath(os.path.join(IMAGES_BASE, "thumbnails", folder, filename))
    try:
        create_thumbnail(src, dst)
    except Exception as exc:
        logger.error("ThumbnailWorker: error on %s/%s: %s", folder, filename, exc)
        raise self.retry(exc=exc, countdown=10)
