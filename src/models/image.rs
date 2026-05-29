use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};

/// Corresponds to the `images` table.
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Image {
    pub id: i32,
    pub location: Option<String>,
    pub name: Option<String>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

/// Input from a create/update form.
#[derive(Debug, Deserialize)]
pub struct ImageForm {
    pub location: Option<String>,
    pub name: Option<String>,
}
