/// Shared Axum application state threaded through all route handlers.
use sqlx::PgPool;
use std::sync::Arc;
use tera::Tera;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub tera: Arc<Tera>,
    /// Absolute path to `app/assets/images` (no trailing slash).
    pub images_base: String,
}
