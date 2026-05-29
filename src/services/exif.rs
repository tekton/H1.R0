use anyhow::Result;
use sqlx::PgPool;
use std::path::Path;
use tracing::{info, warn};

/// Parse EXIF tags from a single JPEG file and store each tag/value pair
/// in the `exif_data` table. Uses INSERT ... ON CONFLICT DO NOTHING so that
/// re-running on the same file is idempotent.
pub async fn parse_and_store(pool: PgPool, file_path: String, image_id: i32) -> Result<()> {
    info!("EXIF: parsing {file_path} for image_id={image_id}");

    let path = Path::new(&file_path);
    let file = std::fs::File::open(path)?;
    let mut bufreader = std::io::BufReader::new(file);

    let exif_reader = exif::Reader::new();
    let exif_data = match exif_reader.read_from_container(&mut bufreader) {
        Ok(e) => e,
        Err(e) => {
            warn!("EXIF: could not read EXIF from {file_path}: {e}");
            return Ok(());
        }
    };

    for field in exif_data.fields() {
        let tag = field.tag.to_string();
        let value = field.display_value().with_unit(&exif_data).to_string();

        let result = sqlx::query!(
            r#"
            INSERT INTO exif_data (image_id, tag, value, created_at, updated_at)
            SELECT $1, $2, $3, NOW(), NOW()
            WHERE NOT EXISTS (
                SELECT 1 FROM exif_data WHERE image_id = $1 AND tag = $2 AND value = $3
            )
            "#,
            image_id,
            tag,
            value
        )
        .execute(&pool)
        .await;

        if let Err(e) = result {
            warn!("EXIF: failed to insert tag={tag} value={value}: {e}");
        } else {
            info!("EXIF: stored tag={tag} value={value}");
        }
    }

    Ok(())
}
