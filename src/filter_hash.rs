use crate::models::search::TagValue;
use sqlx::PgPool;
use tracing::warn;

/// Compute the MD5 hash for a slice of tag/value pairs.
/// The list is sorted by (tag, value) before hashing so the hash is canonical.
/// The JSON encoding is a compact array of {"tag":"...","value":"..."} objects.
pub fn compute_hash(pairs: &[TagValue]) -> String {
    let mut sorted = pairs.to_vec();
    sorted.sort();
    let json = serde_json::to_string(&sorted).unwrap_or_default();
    format!("{:x}", md5::compute(json.as_bytes()))
}

/// Ensure a search row exists for this hash.  If it does not exist, insert it.
/// Mirrors the Rails `filter_check` helper in ApplicationController.
pub async fn filter_check(pool: &PgPool, md5hash: &str, pairs: &[TagValue]) {
    let serial = serde_json::to_string(pairs).unwrap_or_default();

    let result = sqlx::query!(
        r#"
        INSERT INTO searches (md5hash, serial, created_at, updated_at)
        VALUES ($1, $2, NOW(), NOW())
        ON CONFLICT (md5hash) DO NOTHING
        "#,
        md5hash,
        serial,
    )
    .execute(pool)
    .await;

    if let Err(e) = result {
        warn!("filter_check: failed to upsert search hash={md5hash}: {e}");
    }
}

/// Build all single-tag-value hashes from the aggregate exif list and return
/// a vec of (hash, tag, value, count) for use in browse / exif_data views.
pub async fn build_exif_hashes(
    pool: &PgPool,
) -> Vec<(String, String, String, i64)> {
    let rows = sqlx::query!(
        r#"
        SELECT tag, value, count(*) AS "count!"
        FROM exif_data
        GROUP BY tag, value
        ORDER BY tag ASC
        "#
    )
    .fetch_all(pool)
    .await
    .unwrap_or_default();

    let mut out = Vec::new();
    for row in rows {
        let tag = row.tag.unwrap_or_default();
        let value = row.value.unwrap_or_default();
        let count = row.count;
        let pair = vec![TagValue { tag: tag.clone(), value: value.clone() }];
        let hash = compute_hash(&pair);
        filter_check(pool, &hash, &pair).await;
        out.push((hash, tag, value, count));
    }
    out
}

/// Same as `build_exif_hashes` but restricted to images in `image_ids`,
/// and each new tag/value is appended to the existing `base_pairs` from the
/// current search.  Mirrors the Rails filter controller's `@exi2` block.
pub async fn build_filter_exif_hashes(
    pool: &PgPool,
    image_ids: &[i32],
    base_pairs: &[TagValue],
) -> Vec<(String, String, String, i64)> {
    if image_ids.is_empty() {
        return vec![];
    }

    // Build a parameterised IN clause
    let rows = sqlx::query!(
        r#"
        SELECT tag, value, count(*) AS "count!"
        FROM exif_data
        WHERE image_id = ANY($1)
        GROUP BY tag, value
        ORDER BY tag ASC
        "#,
        image_ids
    )
    .fetch_all(pool)
    .await
    .unwrap_or_default();

    let mut out = Vec::new();
    for row in rows {
        let tag = row.tag.unwrap_or_default();
        let value = row.value.unwrap_or_default();
        let count = row.count;

        let mut pairs = base_pairs.to_vec();
        pairs.push(TagValue { tag: tag.clone(), value: value.clone() });
        let hash = compute_hash(&pairs);
        filter_check(pool, &hash, &pairs).await;
        out.push((hash, tag, value, count));
    }
    out
}

/// Tags excluded from the browse / filter view (same list as the Rails ERB).
pub fn is_excluded_tag(tag: &str) -> bool {
    matches!(
        tag,
        "DateTimeDigitized"
            | "UserComment"
            | "DateTimeOriginal"
            | "DateTime"
            | "SubjectArea"
            | "date_time_digitized"
            | "user_comment"
            | "date_time_original"
            | "date_time"
            | "subject_area"
    )
}
