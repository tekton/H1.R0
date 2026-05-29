mod db;
mod filter_hash;
mod models;
mod routes;
mod services;
mod state;
mod workers;

use std::sync::Arc;
use axum::{
    routing::{get, post},
    Router,
};
use tera::Tera;
use tower_http::services::ServeDir;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use state::AppState;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load .env file if present
    let _ = dotenvy::dotenv();

    // Init tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "h1r0=debug,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Database pool
    let pool = db::create_pool().await?;
    info!("Database pool created");

    // Tera templating — load all .html templates from the `templates/` dir
    // At runtime, resolve relative to the current working directory.
    let project_root = std::env::var("PROJECT_ROOT")
        .unwrap_or_else(|_| ".".to_string());
    let template_glob = format!("{project_root}/templates/**/*.html");
    info!("Loading templates from: {template_glob}");
    let tera = Arc::new(Tera::new(&template_glob)?);

    // Images base path
    let images_base = std::env::var("IMAGES_BASE_PATH")
        .unwrap_or_else(|_| format!("{project_root}/app/assets/images"));
    info!("Images base: {images_base}");

    let state = AppState {
        pool,
        tera,
        images_base: images_base.clone(),
    };

    // Static file serving for images and thumbnails
    let serve_images = ServeDir::new(&images_base);

    let app = Router::new()
        // ── Browse ──────────────────────────────────────────────────────────
        .route("/", get(routes::browse::index))
        // ── Images ──────────────────────────────────────────────────────────
        .route("/images", get(routes::images::index))
        .route("/images/new", get(routes::images::new))
        .route("/images", post(routes::images::create))
        .route("/images/:id", get(routes::images::show))
        .route("/images/:id/edit", get(routes::images::edit))
        .route("/images/:id", post(routes::images::update))
        .route("/images/:id/delete", post(routes::images::delete))
        .route("/images/:id/exif", get(routes::images::get_exif_data))
        // ── EXIF Data ────────────────────────────────────────────────────────
        .route("/exif_data", get(routes::exif_data::index))
        .route("/exif_data/new", get(routes::exif_data::new))
        .route("/exif_data", post(routes::exif_data::create))
        .route("/exif_data/:id", get(routes::exif_data::show))
        .route("/exif_data/:id/edit", get(routes::exif_data::edit))
        .route("/exif_data/:id", post(routes::exif_data::update))
        .route("/exif_data/:id/delete", post(routes::exif_data::delete))
        // ── EXIF Parse ──────────────────────────────────────────────────────
        .route("/exif_parse/:folder", get(routes::exif_parse::index))
        // ── Thumbnails ──────────────────────────────────────────────────────
        .route("/thumbnail/:folder", get(routes::thumbnails::create_from_folder))
        // ── Filter ──────────────────────────────────────────────────────────
        .route("/filter/:hash_filter", get(routes::filter::hash_filter))
        // ── Searches ────────────────────────────────────────────────────────
        .route("/searches", get(routes::searches::index))
        .route("/searches/new", get(routes::searches::new))
        .route("/searches", post(routes::searches::create))
        .route("/searches/:id", get(routes::searches::show))
        .route("/searches/:id/edit", get(routes::searches::edit))
        .route("/searches/:id", post(routes::searches::update))
        .route("/searches/:id/delete", post(routes::searches::delete))
        // ── Static assets ───────────────────────────────────────────────────
        .nest_service("/assets/images", serve_images)
        .with_state(state);

    let bind_addr = std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:3000".to_string());
    let listener = tokio::net::TcpListener::bind(&bind_addr).await?;
    info!("Listening on http://{bind_addr}");

    axum::serve(listener, app).await?;
    Ok(())
}
