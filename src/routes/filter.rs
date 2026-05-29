use axum::{
    extract::{Path, State},
    response::Html,
};
use serde_json::Value as JsonValue;
use tera::Context;
use tracing::error;

use crate::filter_hash::{build_filter_exif_hashes, is_excluded_tag};
use crate::models::search::TagValue;
use crate::state::AppState;

/// GET /filter/:hash_filter
///
/// Loads the saved search for the given hash, then:
/// 1. Queries images that match ALL tag/value pairs (HAVING count = N).
/// 2. Loads aggregate exif for those images with new combined hashes.
pub async fn hash_filter(
    State(state): State<AppState>,
    Path(hash_filter): Path<String>,
) -> Html<String> {
    // Load the search row
    let search = sqlx::query!(
        "SELECT id, md5hash, serial, new_tag, new_val, \"left\", created_at, updated_at FROM searches WHERE md5hash = $1",
        hash_filter
    )
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    let search = match search {
        Some(s) => s,
        None => {
            return Html(format!("<p>No saved search found for hash <code>{hash_filter}</code></p>"));
        }
    };

    // Parse the serial JSON
    let serial_pairs: Vec<TagValue> = {
        let raw = search.serial.clone().unwrap_or_default();
        serde_json::from_str::<Vec<JsonValue>>(&raw)
            .unwrap_or_default()
            .into_iter()
            .filter_map(|v| {
                let tag = v.get("tag")?.as_str()?.to_string();
                let value = v.get("value")?.as_str()?.to_string();
                Some(TagValue { tag, value })
            })
            .collect()
    };

    if serial_pairs.is_empty() {
        return Html("<p>Search has no tag/value pairs</p>".to_string());
    }

    // Build parameterised WHERE clause for matching images.
    // Fixed SQL injection from original Rails code — use SQLx parameterised queries.
    // We want: image_id IN (SELECT image_id FROM exif_data WHERE (tag=$1 AND value=$2) OR ...
    //           GROUP BY image_id HAVING count(*) = N)
    let n = serial_pairs.len() as i64;

    // Build the query dynamically but safely using parameterised binds.
    // We collect (tag, value) tuples and build unnest-based SQL.
    let tags: Vec<&str> = serial_pairs.iter().map(|p| p.tag.as_str()).collect();
    let values: Vec<&str> = serial_pairs.iter().map(|p| p.value.as_str()).collect();

    let matching_image_ids: Vec<i32> = sqlx::query_scalar!(
        r#"
        SELECT image_id AS "image_id!"
        FROM exif_data
        WHERE (tag, value) = ANY(SELECT * FROM UNNEST($1::text[], $2::text[]))
        GROUP BY image_id
        HAVING count(*) = $3
        "#,
        &tags as &[&str],
        &values as &[&str],
        n
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    // Load exif rows for the matched images (for thumbnail display)
    let matched_exif: Vec<serde_json::Value> = if !matching_image_ids.is_empty() {
        sqlx::query!(
            r#"
            SELECT DISTINCT ON (exif_data.image_id) exif_data.image_id AS "image_id!",
                   images.location AS "location!"
            FROM exif_data
            INNER JOIN images ON exif_data.image_id = images.id
            WHERE exif_data.image_id = ANY($1)
            ORDER BY exif_data.image_id
            "#,
            &matching_image_ids
        )
        .fetch_all(&state.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|r| serde_json::json!({ "image_id": r.image_id, "location": r.location }))
        .collect()
    } else {
        vec![]
    };

    // Build filter exif hashes for the sidebar
    let exif_rows =
        build_filter_exif_hashes(&state.pool, &matching_image_ids, &serial_pairs).await;

    // Filter excluded tags
    let exif_rows: Vec<_> = exif_rows
        .into_iter()
        .filter(|(_, tag, _, _)| !is_excluded_tag(tag))
        .collect();

    // Build serial display list
    let serial_display: Vec<(String, String)> = serial_pairs
        .iter()
        .map(|p| (p.tag.clone(), p.value.clone()))
        .collect();

    let mut ctx = Context::new();
    ctx.insert("serial_display", &serial_display);
    ctx.insert("matched_exif", &matched_exif);
    ctx.insert("exif_rows", &exif_rows);

    match state.tera.render("filter/hash_filter.html", &ctx) {
        Ok(html) => Html(html),
        Err(e) => {
            error!("filter/hash_filter template error: {e}");
            Html(format!("<pre>Template error: {e}</pre>"))
        }
    }
}
