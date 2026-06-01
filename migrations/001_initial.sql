-- 001_initial.sql
-- Reflects the existing schema created by Rails migrations.
-- Run this only on a fresh database; the production database already has these tables.

CREATE TABLE IF NOT EXISTS images (
    id          SERIAL PRIMARY KEY,
    location    VARCHAR NOT NULL,
    name        VARCHAR,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS index_images_on_location ON images (location);

CREATE TABLE IF NOT EXISTS exif_data (
    id          SERIAL PRIMARY KEY,
    image_id    INTEGER NOT NULL REFERENCES images(id) ON DELETE CASCADE,
    tag         VARCHAR,
    value       VARCHAR,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS index_exif_data_on_image_id ON exif_data (image_id);

-- ON CONFLICT DO NOTHING target: unique (image_id, tag, value)
CREATE UNIQUE INDEX IF NOT EXISTS index_exif_data_on_image_id_tag_value
    ON exif_data (image_id, tag, value);

CREATE TABLE IF NOT EXISTS searches (
    id          SERIAL PRIMARY KEY,
    md5hash     VARCHAR,
    serial      TEXT,
    new_tag     VARCHAR,
    new_val     VARCHAR,
    "left"      VARCHAR,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS index_searches_on_md5hash ON searches (md5hash);
