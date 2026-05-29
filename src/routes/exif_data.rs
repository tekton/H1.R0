use axum::{
    extract::{Form, Path, State},
    response::{Html, Redirect},
};
use tera::Context;
use tracing::error;

use crate::filter_hash::build_exif_hashes;
use crate::models::exif_datum::ExifDatumForm;
use crate::state::AppState;

/// GET /exif_data
pub async fn index(State(state): State<AppState>) -> Html<String> {
    let exif_rows = build_exif_hashes(&state.pool).await;

    let mut ctx = Context::new();
    ctx.insert("exif_rows", &exif_rows);
    render(&state, "exif_data/index.html", &ctx)
}

/// GET /exif_data/new
pub async fn new(State(state): State<AppState>) -> Html<String> {
    let ctx = Context::new();
    render(&state, "exif_data/new.html", &ctx)
}

/// POST /exif_data  (create)
pub async fn create(
    State(state): State<AppState>,
    Form(form): Form<ExifDatumForm>,
) -> Result<Redirect, Html<String>> {
    let result = sqlx::query!(
        "INSERT INTO exif_data (image_id, tag, value, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING id",
        form.image_id,
        form.tag,
        form.value,
    )
    .fetch_one(&state.pool)
    .await;

    match result {
        Ok(row) => Ok(Redirect::to(&format!("/exif_data/{}", row.id))),
        Err(e) => {
            error!("exif_data/create error: {e}");
            let mut ctx = Context::new();
            ctx.insert("error", &e.to_string());
            Err(render(&state, "exif_data/new.html", &ctx))
        }
    }
}

/// GET /exif_data/:id
pub async fn show(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let datum = sqlx::query_as!(
        crate::models::ExifDatum,
        "SELECT id, image_id, tag, value, created_at, updated_at FROM exif_data WHERE id = $1",
        id
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    let mut ctx = Context::new();
    match datum {
        Some(d) => {
            ctx.insert("exif_datum", &d);
            render(&state, "exif_data/show.html", &ctx)
        }
        None => Html(format!("<p>ExifDatum {id} not found</p>")),
    }
}

/// GET /exif_data/:id/edit
pub async fn edit(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let datum = sqlx::query_as!(
        crate::models::ExifDatum,
        "SELECT id, image_id, tag, value, created_at, updated_at FROM exif_data WHERE id = $1",
        id
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    let mut ctx = Context::new();
    match datum {
        Some(d) => {
            ctx.insert("exif_datum", &d);
            render(&state, "exif_data/edit.html", &ctx)
        }
        None => Html(format!("<p>ExifDatum {id} not found</p>")),
    }
}

/// POST /exif_data/:id  (update)
pub async fn update(
    State(state): State<AppState>,
    Path(id): Path<i32>,
    Form(form): Form<ExifDatumForm>,
) -> Result<Redirect, Html<String>> {
    let result = sqlx::query!(
        "UPDATE exif_data SET image_id = $1, tag = $2, value = $3, updated_at = NOW() WHERE id = $4",
        form.image_id,
        form.tag,
        form.value,
        id
    )
    .execute(&state.pool)
    .await;

    match result {
        Ok(_) => Ok(Redirect::to(&format!("/exif_data/{id}"))),
        Err(e) => {
            error!("exif_data/update error: {e}");
            let mut ctx = Context::new();
            ctx.insert("error", &e.to_string());
            ctx.insert("id", &id);
            Err(render(&state, "exif_data/edit.html", &ctx))
        }
    }
}

/// POST /exif_data/:id/delete
pub async fn delete(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Redirect {
    let _ = sqlx::query!("DELETE FROM exif_data WHERE id = $1", id)
        .execute(&state.pool)
        .await;
    Redirect::to("/exif_data")
}

fn render(state: &AppState, template: &str, ctx: &Context) -> Html<String> {
    match state.tera.render(template, ctx) {
        Ok(html) => Html(html),
        Err(e) => {
            error!("template {template} error: {e}");
            Html(format!("<pre>Template error: {e}</pre>"))
        }
    }
}
