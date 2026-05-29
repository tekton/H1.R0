use axum::{
    extract::{Path, State},
    response::Html,
};
use tracing::{info, warn};

use crate::state::AppState;
use crate::workers;

/// GET /exif_parse/:folder
///
/// Scans `<images_base>/<folder>` for JPEG files.  For each file, ensures the
/// image row exists in `images` (INSERT ... ON CONFLICT DO NOTHING) and spawns
/// a background Tokio task to parse and store EXIF data.
pub async fn index(
    State(state): State<AppState>,
    Path(folder): Path<String>,
) -> Html<String> {
    let loc = format!("{}/{}", state.images_base, folder);
    info!("exif_parse: scanning {loc}");

    let entries = match std::fs::read_dir(&loc) {
        Ok(e) => e,
        Err(e) => {
            warn!("exif_parse: cannot read dir {loc}: {e}");
            return Html(format!("<p>Cannot read folder: {e}</p>"));
        }
    };

    let mut queued = 0usize;

    for entry in entries.flatten() {
        let file_name = entry.file_name();
        let fname = file_name.to_string_lossy().to_string();
        if !fname.to_lowercase().ends_with(".jpg") {
            continue;
        }

        let relative = format!("{folder}/{fname}");
        let full_path = format!("{loc}/{fname}");

        // Upsert image row
        let result = sqlx::query!(
            r#"
            INSERT INTO images (location, name, created_at, updated_at)
            VALUES ($1, $2, NOW(), NOW())
            ON CONFLICT DO NOTHING
            RETURNING id
            "#,
            relative,
            fname,
        )
        .fetch_optional(&state.pool)
        .await;

        // If we got no row back from INSERT, look up the existing id
        let image_id: Option<i32> = match result {
            Ok(Some(row)) => Some(row.id),
            Ok(None) => {
                // Row already exists
                sqlx::query_scalar!(
                    "SELECT id FROM images WHERE location = $1",
                    relative
                )
                .fetch_optional(&state.pool)
                .await
                .ok()
                .flatten()
            }
            Err(e) => {
                warn!("exif_parse: failed to upsert image {relative}: {e}");
                None
            }
        };

        if let Some(id) = image_id {
            workers::spawn_exif(state.pool.clone(), full_path, id);
            queued += 1;
        }
    }

    Html(format!(
        "<p>Parse through a folder to add exif data to the exif database...</p><p>Queued {queued} jobs for folder <code>{folder}</code>.</p>"
    ))
}
