use axum::{
    extract::{Path, State},
    response::Html,
};
use tracing::{info, warn};

use crate::state::AppState;
use crate::workers;

/// GET /thumbnail/:folder
///
/// Scans `<images_base>/<folder>` for JPEG files and spawns a background
/// Tokio task for each one to generate a 200×133 thumbnail.
pub async fn create_from_folder(
    State(state): State<AppState>,
    Path(folder): Path<String>,
) -> Html<String> {
    let loc = format!("{}/{}", state.images_base, folder);
    info!("thumbnails: scanning {loc}");

    let entries = match std::fs::read_dir(&loc) {
        Ok(e) => e,
        Err(e) => {
            warn!("thumbnails: cannot read dir {loc}: {e}");
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

        workers::spawn_thumbnail(state.images_base.clone(), folder.clone(), fname);
        queued += 1;
    }

    Html(format!(
        "Thumbnails added to the queue...<p>Queued {queued} jobs for folder <code>{folder}</code>.</p>"
    ))
}
