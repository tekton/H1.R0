-- migrations/001_initial.sql
-- Reflects the existing Rails schema - run only if tables do not exist

CREATE TABLE IF NOT EXISTS images (
    id          SERIAL PRIMARY KEY,
    location    VARCHAR,
    name        VARCHAR,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exif_data (
    id          SERIAL PRIMARY KEY,
    parent      INTEGER,
    tag         VARCHAR,
    value       VARCHAR,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    image_id    INTEGER REFERENCES images(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS searches (
    id          SERIAL PRIMARY KEY,
    md5hash     VARCHAR,
    serial      TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    new_tag     VARCHAR,
    new_val     VARCHAR,
    "left"      VARCHAR
);

CREATE UNIQUE INDEX IF NOT EXISTS index_searches_on_md5hash ON searches (md5hash);
