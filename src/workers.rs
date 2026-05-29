use sqlx::PgPool;
use tracing::{error, info};

use crate::services::exif;
use crate::services::thumbnail;

/// Fire-and-forget Tokio task: parse EXIF for one image file.
pub fn spawn_exif(pool: PgPool, file_path: String, image_id: i32) {
    tokio::spawn(async move {
        info!("worker: spawning EXIF parse for {file_path}");
        if let Err(e) = exif::parse_and_store(pool, file_path.clone(), image_id).await {
            error!("worker: EXIF parse failed for {file_path}: {e}");
        }
    });
}

/// Fire-and-forget Tokio task: generate thumbnail for one image file.
pub fn spawn_thumbnail(images_base: String, folder: String, file: String) {
    tokio::spawn(async move {
        info!("worker: spawning thumbnail for {folder}/{file}");
        if let Err(e) = thumbnail::create_thumbnail(images_base, folder.clone(), file.clone()).await {
            error!("worker: thumbnail failed for {folder}/{file}: {e}");
        }
    });
}
