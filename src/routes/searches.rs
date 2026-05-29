use axum::{
    extract::{Form, Path, State},
    response::{Html, Redirect},
};
use tera::Context;
use tracing::error;

use crate::models::search::SearchForm;
use crate::state::AppState;

/// GET /searches
pub async fn index(State(state): State<AppState>) -> Html<String> {
    let searches = sqlx::query!(
        r#"SELECT id, md5hash, serial, new_tag, new_val, "left", created_at, updated_at FROM searches ORDER BY id"#
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    // Convert to a serde-serialisable vec of maps
    let rows: Vec<serde_json::Value> = searches
        .into_iter()
        .map(|s| {
            serde_json::json!({
                "id": s.id,
                "md5hash": s.md5hash,
                "serial": s.serial,
                "new_tag": s.new_tag,
                "new_val": s.new_val,
                "left": s.left,
            })
        })
        .collect();

    let mut ctx = Context::new();
    ctx.insert("searches", &rows);
    render(&state, "searches/index.html", &ctx)
}

/// GET /searches/new
pub async fn new(State(state): State<AppState>) -> Html<String> {
    let ctx = Context::new();
    render(&state, "searches/new.html", &ctx)
}

/// POST /searches  (create)
pub async fn create(
    State(state): State<AppState>,
    Form(form): Form<SearchForm>,
) -> Result<Redirect, Html<String>> {
    let result = sqlx::query!(
        r#"INSERT INTO searches (md5hash, serial, new_tag, new_val, "left", created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, NOW(), NOW()) RETURNING id"#,
        form.md5hash,
        form.serial,
        form.new_tag,
        form.new_val,
        form.left,
    )
    .fetch_one(&state.pool)
    .await;

    match result {
        Ok(row) => Ok(Redirect::to(&format!("/searches/{}", row.id))),
        Err(e) => {
            error!("searches/create error: {e}");
            let mut ctx = Context::new();
            ctx.insert("error", &e.to_string());
            Err(render(&state, "searches/new.html", &ctx))
        }
    }
}

/// GET /searches/:id
pub async fn show(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let search = fetch_one(&state, id).await;
    let mut ctx = Context::new();
    match search {
        Some(s) => {
            ctx.insert("search", &s);
            render(&state, "searches/show.html", &ctx)
        }
        None => Html(format!("<p>Search {id} not found</p>")),
    }
}

/// GET /searches/:id/edit
pub async fn edit(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let search = fetch_one(&state, id).await;
    let mut ctx = Context::new();
    match search {
        Some(s) => {
            ctx.insert("search", &s);
            render(&state, "searches/edit.html", &ctx)
        }
        None => Html(format!("<p>Search {id} not found</p>")),
    }
}

/// POST /searches/:id  (update)
pub async fn update(
    State(state): State<AppState>,
    Path(id): Path<i32>,
    Form(form): Form<SearchForm>,
) -> Result<Redirect, Html<String>> {
    let result = sqlx::query!(
        r#"UPDATE searches SET md5hash = $1, serial = $2, new_tag = $3, new_val = $4, "left" = $5, updated_at = NOW() WHERE id = $6"#,
        form.md5hash,
        form.serial,
        form.new_tag,
        form.new_val,
        form.left,
        id
    )
    .execute(&state.pool)
    .await;

    match result {
        Ok(_) => Ok(Redirect::to(&format!("/searches/{id}"))),
        Err(e) => {
            error!("searches/update error: {e}");
            let mut ctx = Context::new();
            ctx.insert("error", &e.to_string());
            Err(render(&state, "searches/edit.html", &ctx))
        }
    }
}

/// POST /searches/:id/delete
pub async fn delete(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Redirect {
    let _ = sqlx::query!("DELETE FROM searches WHERE id = $1", id)
        .execute(&state.pool)
        .await;
    Redirect::to("/searches")
}

async fn fetch_one(state: &AppState, id: i32) -> Option<serde_json::Value> {
    sqlx::query!(
        r#"SELECT id, md5hash, serial, new_tag, new_val, "left", created_at, updated_at FROM searches WHERE id = $1"#,
        id
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten()
    .map(|s| {
        serde_json::json!({
            "id": s.id,
            "md5hash": s.md5hash,
            "serial": s.serial,
            "new_tag": s.new_tag,
            "new_val": s.new_val,
            "left": s.left,
        })
    })
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
