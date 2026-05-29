use sqlx::{PgPool, postgres::PgPoolOptions};
use anyhow::Result;

/// Create and return a connection pool using DATABASE_URL from the environment.
pub async fn create_pool() -> Result<PgPool> {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;

    Ok(pool)
}
