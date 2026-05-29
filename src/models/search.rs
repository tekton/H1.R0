use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;

/// Corresponds to the `searches` table.
/// `serial` is stored as JSON text in the DB and deserialized on read.
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Search {
    pub id: i32,
    pub md5hash: Option<String>,
    /// Stored as JSON text; a list of {"tag": "...", "value": "..."} objects.
    pub serial: Option<String>,
    pub new_tag: Option<String>,
    pub new_val: Option<String>,
    pub left: Option<String>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

impl Search {
    /// Parse the `serial` text field as a JSON array.
    pub fn serial_as_json(&self) -> Vec<JsonValue> {
        match &self.serial {
            Some(s) => serde_json::from_str(s).unwrap_or_default(),
            None => vec![],
        }
    }
}

/// Input from a create/update form.
#[derive(Debug, Deserialize)]
pub struct SearchForm {
    pub md5hash: Option<String>,
    pub serial: Option<String>,
    pub new_tag: Option<String>,
    pub new_val: Option<String>,
    pub left: Option<String>,
}

/// A tag/value pair used for composing filter hashes.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct TagValue {
    pub tag: String,
    pub value: String,
}
