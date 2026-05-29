use anyhow::Result;
use image::imageops::FilterType;
use std::path::{Path, PathBuf};
use tracing::{info, warn};

/// Resize a JPEG to fit 200×133 (Lanczos3) and write the thumbnail to
/// `<images_base>/thumbnails/<folder>/<filename>`.
pub async fn create_thumbnail(images_base: String, folder: String, file: String) -> Result<()> {
    let src: PathBuf = [&images_base, &folder, &file].iter().collect();
    info!("Thumbnail: reading {}", src.display());

    let img = match image::open(&src) {
        Ok(i) => i,
        Err(e) => {
            warn!("Thumbnail: could not open {}: {e}", src.display());
            return Ok(());
        }
    };

    let thumb = img.resize(200, 133, FilterType::Lanczos3);

    // Destination: <images_base>/thumbnails/<folder>/<file>
    let thumb_dir: PathBuf = [&images_base, "thumbnails", &folder].iter().collect();
    std::fs::create_dir_all(&thumb_dir)?;

    let dest = thumb_dir.join(Path::new(&file).file_name().unwrap_or_default());
    info!("Thumbnail: writing {}", dest.display());
    thumb.save(&dest)?;

    Ok(())
}
