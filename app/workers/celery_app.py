"""Celery application factory."""
import os
from celery import Celery

BROKER_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

celery_app = Celery(
    "h1r0",
    broker=BROKER_URL,
    backend=BROKER_URL,
    include=[
        "app.workers.exif_worker",
        "app.workers.thumbnail_worker",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
)
