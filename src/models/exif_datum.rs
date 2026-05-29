use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};

/// Corresponds to the `exif_data` table.
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ExifDatum {
    pub id: i32,
    pub image_id: Option<i32>,
    pub tag: Option<String>,
    pub value: Option<String>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

/// Aggregated exif row used for browse / filter views (tag, value, count).
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ExifAggregate {
    pub tag: String,
    pub value: String,
    pub count: i64,
    /// MD5 hash computed in Rust – not stored in DB.
    #[sqlx(default)]
    pub q: String,
}

/// Input from a create/update form.
#[derive(Debug, Deserialize)]
pub struct ExifDatumForm {
    pub image_id: Option<i32>,
    pub tag: Option<String>,
    pub value: Option<String>,
}
