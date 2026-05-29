"""Searches router — CRUD for saved filter searches."""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.search import Search

router = APIRouter(prefix="/searches")
templates = Jinja2Templates(directory="app/templates")


# ---------------------------------------------------------------------------
# GET /searches
# ---------------------------------------------------------------------------
@router.get("", response_class=HTMLResponse)
def searches_index(request: Request, db: Session = Depends(get_db)):
    searches = db.query(Search).all()
    return templates.TemplateResponse(
        "searches/index.html",
        {"request": request, "searches": searches},
    )


# ---------------------------------------------------------------------------
# GET /searches/new
# ---------------------------------------------------------------------------
@router.get("/new", response_class=HTMLResponse)
def searches_new(request: Request):
    return templates.TemplateResponse(
        "searches/new.html",
        {"request": request, "search": None, "errors": []},
    )


# ---------------------------------------------------------------------------
# POST /searches
# ---------------------------------------------------------------------------
@router.post("", response_class=HTMLResponse)
def searches_create(
    request: Request,
    md5hash: str = Form(""),
    serial: str = Form(""),
    db: Session = Depends(get_db),
):
    errors = []
    if not md5hash:
        errors.append("Hash can't be blank")

    # Validate serial is valid JSON if provided
    serial_json = serial
    if serial:
        try:
            json.loads(serial)
        except ValueError:
            errors.append("Serial must be valid JSON")

    if errors:
        return templates.TemplateResponse(
            "searches/new.html",
            {"request": request, "search": None, "errors": errors},
            status_code=422,
        )

    search = Search(md5hash=md5hash, serial=serial_json)
    db.add(search)
    db.commit()
    db.refresh(search)
    return RedirectResponse(url=f"/searches/{search.id}", status_code=303)


# ---------------------------------------------------------------------------
# GET /searches/{id}
# ---------------------------------------------------------------------------
@router.get("/{search_id}", response_class=HTMLResponse)
def searches_show(search_id: int, request: Request, db: Session = Depends(get_db)):
    search = db.get(Search, search_id)
    if search is None:
        raise HTTPException(status_code=404, detail="Search not found")
    return templates.TemplateResponse(
        "searches/show.html",
        {"request": request, "search": search},
    )


# ---------------------------------------------------------------------------
# GET /searches/{id}/edit
# ---------------------------------------------------------------------------
@router.get("/{search_id}/edit", response_class=HTMLResponse)
def searches_edit(search_id: int, request: Request, db: Session = Depends(get_db)):
    search = db.get(Search, search_id)
    if search is None:
        raise HTTPException(status_code=404, detail="Search not found")
    return templates.TemplateResponse(
        "searches/edit.html",
        {"request": request, "search": search, "errors": []},
    )


# ---------------------------------------------------------------------------
# POST /searches/{id}/update
# ---------------------------------------------------------------------------
@router.post("/{search_id}/update", response_class=HTMLResponse)
def searches_update(
    search_id: int,
    request: Request,
    md5hash: str = Form(""),
    serial: str = Form(""),
    db: Session = Depends(get_db),
):
    search = db.get(Search, search_id)
    if search is None:
        raise HTTPException(status_code=404, detail="Search not found")

    errors = []
    if not md5hash:
        errors.append("Hash can't be blank")
    if serial:
        try:
            json.loads(serial)
        except ValueError:
            errors.append("Serial must be valid JSON")

    if errors:
        return templates.TemplateResponse(
            "searches/edit.html",
            {"request": request, "search": search, "errors": errors},
            status_code=422,
        )

    search.md5hash = md5hash
    search.serial = serial
    db.commit()
    return RedirectResponse(url=f"/searches/{search_id}", status_code=303)


# ---------------------------------------------------------------------------
# POST /searches/{id}/delete
# ---------------------------------------------------------------------------
@router.post("/{search_id}/delete", response_class=HTMLResponse)
def searches_destroy(search_id: int, db: Session = Depends(get_db)):
    search = db.get(Search, search_id)
    if search is None:
        raise HTTPException(status_code=404, detail="Search not found")
    db.delete(search)
    db.commit()
    return RedirectResponse(url="/searches", status_code=303)
