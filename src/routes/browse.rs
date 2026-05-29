use axum::{extract::State, response::Html};
use tera::Context;
use tracing::error;

use crate::filter_hash::build_exif_hashes;
use crate::state::AppState;

/// GET /  →  browse/index
pub async fn index(State(state): State<AppState>) -> Html<String> {
    // Random 4 images
    let images = sqlx::query_as!(
        crate::models::Image,
        r#"SELECT id, location, name, created_at, updated_at FROM images ORDER BY RANDOM() LIMIT 4"#
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    // Build exif tag/value aggregates with hashes
    let exif_rows = build_exif_hashes(&state.pool).await;

    let mut ctx = Context::new();
    ctx.insert("images", &images);
    ctx.insert("exif_rows", &exif_rows);

    match state.tera.render("browse/index.html", &ctx) {
        Ok(html) => Html(html),
        Err(e) => {
            error!("browse/index template error: {e}");
            Html(format!("<pre>Template error: {e}</pre>"))
        }
    }
}
