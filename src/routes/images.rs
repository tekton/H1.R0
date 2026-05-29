use axum::{
    extract::{Form, Path, State},
    response::{Html, Redirect},
};
use tera::Context;
use tracing::error;

use crate::models::image::ImageForm;
use crate::state::AppState;

// exif is the re-export name of kamadak-exif

/// GET /images
pub async fn index(State(state): State<AppState>) -> Html<String> {
    let images = sqlx::query_as!(
        crate::models::Image,
        "SELECT id, location, name, created_at, updated_at FROM images ORDER BY id"
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let mut ctx = Context::new();
    ctx.insert("images", &images);
    render(&state, "images/index.html", &ctx)
}

/// GET /images/new
pub async fn new(State(state): State<AppState>) -> Html<String> {
    let ctx = Context::new();
    render(&state, "images/new.html", &ctx)
}

/// POST /images  (create)
pub async fn create(
    State(state): State<AppState>,
    Form(form): Form<ImageForm>,
) -> Result<Redirect, Html<String>> {
    let result = sqlx::query!(
        "INSERT INTO images (location, name, created_at, updated_at) VALUES ($1, $2, NOW(), NOW()) RETURNING id",
        form.location,
        form.name,
    )
    .fetch_one(&state.pool)
    .await;

    match result {
        Ok(row) => Ok(Redirect::to(&format!("/images/{}", row.id))),
        Err(e) => {
            error!("images/create error: {e}");
            let mut ctx = Context::new();
            ctx.insert("error", &e.to_string());
            Err(render(&state, "images/new.html", &ctx))
        }
    }
}

/// GET /images/:id
pub async fn show(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let image = sqlx::query_as!(
        crate::models::Image,
        "SELECT id, location, name, created_at, updated_at FROM images WHERE id = $1",
        id
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    let mut ctx = Context::new();
    match image {
        Some(img) => {
            ctx.insert("image", &img);
            render(&state, "images/show.html", &ctx)
        }
        None => Html(format!("<p>Image {id} not found</p>")),
    }
}

/// GET /images/:id/edit
pub async fn edit(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let image = sqlx::query_as!(
        crate::models::Image,
        "SELECT id, location, name, created_at, updated_at FROM images WHERE id = $1",
        id
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    let mut ctx = Context::new();
    match image {
        Some(img) => {
            ctx.insert("image", &img);
            render(&state, "images/edit.html", &ctx)
        }
        None => Html(format!("<p>Image {id} not found</p>")),
    }
}

/// POST /images/:id  (update)
pub async fn update(
    State(state): State<AppState>,
    Path(id): Path<i32>,
    Form(form): Form<ImageForm>,
) -> Result<Redirect, Html<String>> {
    let result = sqlx::query!(
        "UPDATE images SET location = $1, name = $2, updated_at = NOW() WHERE id = $3",
        form.location,
        form.name,
        id
    )
    .execute(&state.pool)
    .await;

    match result {
        Ok(_) => Ok(Redirect::to(&format!("/images/{id}"))),
        Err(e) => {
            error!("images/update error: {e}");
            let mut ctx = Context::new();
            ctx.insert("error", &e.to_string());
            ctx.insert("id", &id);
            Err(render(&state, "images/edit.html", &ctx))
        }
    }
}

/// POST /images/:id/delete
pub async fn delete(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Redirect {
    let _ = sqlx::query!("DELETE FROM images WHERE id = $1", id)
        .execute(&state.pool)
        .await;
    Redirect::to("/images")
}

/// GET /images/:id/exif
pub async fn get_exif_data(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Html<String> {
    let image = sqlx::query_as!(
        crate::models::Image,
        "SELECT id, location, name, created_at, updated_at FROM images WHERE id = $1",
        id
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    if let Some(img) = image {
        let location = img.location.clone().unwrap_or_default();
        let file_path = format!("{}/{}", state.images_base, location);

        // Parse EXIF on the fly for display
        let mut exif_pairs: Vec<(String, String)> = Vec::new();
        if let Ok(file) = std::fs::File::open(&file_path) {
            let mut bufreader = std::io::BufReader::new(file);
            if let Ok(exif) = exif::Reader::new().read_from_container(&mut bufreader) {
                for field in exif.fields() {
                    exif_pairs.push((
                        field.tag.to_string(),
                        field.display_value().with_unit(&exif).to_string(),
                    ));
                }
            }
        }

        let mut ctx = Context::new();
        ctx.insert("image", &img);
        ctx.insert("exif_pairs", &exif_pairs);
        render(&state, "images/get_exif_data.html", &ctx)
    } else {
        Html(format!("<p>Image {id} not found</p>"))
    }
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
