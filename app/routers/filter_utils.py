"""
Shared utilities for filter hash computation and filter_check upsert.
"""
from __future__ import annotations

import hashlib
import json
import logging

from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.search import Search

logger = logging.getLogger(__name__)


def compute_filter_hash(tags: list[dict]) -> str:
    """
    Return MD5 of a canonical JSON representation of *tags*.

    Tags are sorted by (tag, value) so the hash is order-independent.
    Each dict must have "tag" and "value" keys.
    """
    sorted_tags = sorted(tags, key=lambda x: (x["tag"], x["value"]))
    canonical = json.dumps(sorted_tags, sort_keys=True, separators=(",", ":"))
    return hashlib.md5(canonical.encode()).hexdigest()


def filter_check(md5hash: str, tags: list[dict], db: Session) -> Search:
    """
    Ensure a Search row exists for *md5hash* / *tags*.

    Equivalent to Rails' first_or_create! — reads first, inserts if missing,
    and handles concurrent inserts gracefully (ON CONFLICT via exception catch).
    """
    existing = db.query(Search).filter(Search.md5hash == md5hash).first()
    if existing:
        return existing

    serial_json = json.dumps(tags)
    search = Search(md5hash=md5hash, serial=serial_json)
    db.add(search)
    try:
        db.commit()
        db.refresh(search)
    except IntegrityError:
        db.rollback()
        # Another request inserted it concurrently — just fetch it
        existing = db.query(Search).filter(Search.md5hash == md5hash).first()
        if existing:
            return existing
        raise
    return search
