package db

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

// ─── Model types ────────────────────────────────────────────────────────────

// Image maps to the images table.
type Image struct {
	ID        int64
	Location  string
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ExifDatum maps to the exif_data table.
type ExifDatum struct {
	ID        int64
	ImageID   int64
	Tag       string
	Value     string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ExifCount is used for tag/value aggregation queries.
type ExifCount struct {
	Tag   string
	Value string
	Count int64
	// Hash is populated in-memory, not from the DB.
	Hash string
}

// Search maps to the searches table.
type Search struct {
	ID        int64
	Md5hash   string
	Serial    string // JSON text
	NewTag    string
	NewVal    string
	Left      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// FilterTag is one element of a searches.serial JSON array.
type FilterTag struct {
	Tag   string `json:"tag"`
	Value string `json:"value"`
}

// ParseSerial deserialises the JSON serial column into a []FilterTag.
func (s *Search) ParseSerial() ([]FilterTag, error) {
	var tags []FilterTag
	if s.Serial == "" {
		return tags, nil
	}
	if err := json.Unmarshal([]byte(s.Serial), &tags); err != nil {
		return nil, err
	}
	return tags, nil
}

// ─── Images ─────────────────────────────────────────────────────────────────

func ListImages(ctx context.Context) ([]Image, error) {
	rows, err := Pool.Query(ctx, `SELECT id, location, name, created_at, updated_at FROM images ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var images []Image
	for rows.Next() {
		var img Image
		if err := rows.Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt); err != nil {
			return nil, err
		}
		images = append(images, img)
	}
	return images, rows.Err()
}

func RandomImages(ctx context.Context, n int) ([]Image, error) {
	rows, err := Pool.Query(ctx, `SELECT id, location, name, created_at, updated_at FROM images ORDER BY RANDOM() LIMIT $1`, n)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var images []Image
	for rows.Next() {
		var img Image
		if err := rows.Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt); err != nil {
			return nil, err
		}
		images = append(images, img)
	}
	return images, rows.Err()
}

func GetImage(ctx context.Context, id int64) (*Image, error) {
	img := &Image{}
	err := Pool.QueryRow(ctx,
		`SELECT id, location, name, created_at, updated_at FROM images WHERE id = $1`, id,
	).Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return img, nil
}

func CreateImage(ctx context.Context, location, name string) (*Image, error) {
	img := &Image{}
	err := Pool.QueryRow(ctx,
		`INSERT INTO images (location, name, created_at, updated_at)
		 VALUES ($1, $2, NOW(), NOW())
		 RETURNING id, location, name, created_at, updated_at`,
		location, name,
	).Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt)
	return img, err
}

func UpdateImage(ctx context.Context, id int64, location, name string) (*Image, error) {
	img := &Image{}
	err := Pool.QueryRow(ctx,
		`UPDATE images SET location=$1, name=$2, updated_at=NOW()
		 WHERE id=$3
		 RETURNING id, location, name, created_at, updated_at`,
		location, name, id,
	).Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt)
	return img, err
}

func DeleteImage(ctx context.Context, id int64) error {
	_, err := Pool.Exec(ctx, `DELETE FROM images WHERE id = $1`, id)
	return err
}

// FindOrCreateImage returns the existing image for a location or creates it.
func FindOrCreateImage(ctx context.Context, location string) (*Image, error) {
	img := &Image{}
	err := Pool.QueryRow(ctx,
		`INSERT INTO images (location, name, created_at, updated_at)
		 VALUES ($1, $1, NOW(), NOW())
		 ON CONFLICT (location) DO UPDATE SET updated_at=images.updated_at
		 RETURNING id, location, name, created_at, updated_at`,
		location,
	).Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt)
	if err != nil {
		// Fallback: plain select
		err2 := Pool.QueryRow(ctx,
			`SELECT id, location, name, created_at, updated_at FROM images WHERE location = $1`, location,
		).Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt)
		if err2 != nil {
			return nil, fmt.Errorf("FindOrCreateImage: %w", err)
		}
	}
	return img, nil
}

// ─── ExifData ────────────────────────────────────────────────────────────────

func ListExifCounts(ctx context.Context) ([]ExifCount, error) {
	rows, err := Pool.Query(ctx,
		`SELECT tag, value, count(*) AS count FROM exif_data GROUP BY tag, value ORDER BY tag ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var counts []ExifCount
	for rows.Next() {
		var ec ExifCount
		if err := rows.Scan(&ec.Tag, &ec.Value, &ec.Count); err != nil {
			return nil, err
		}
		counts = append(counts, ec)
	}
	return counts, rows.Err()
}

func ListExifCountsForImages(ctx context.Context, imageIDs []int64) ([]ExifCount, error) {
	if len(imageIDs) == 0 {
		return nil, nil
	}
	rows, err := Pool.Query(ctx,
		`SELECT tag, value, count(*) AS count
		 FROM exif_data
		 WHERE image_id = ANY($1)
		 GROUP BY tag, value
		 ORDER BY tag ASC`,
		imageIDs,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var counts []ExifCount
	for rows.Next() {
		var ec ExifCount
		if err := rows.Scan(&ec.Tag, &ec.Value, &ec.Count); err != nil {
			return nil, err
		}
		counts = append(counts, ec)
	}
	return counts, rows.Err()
}

func GetExifDatum(ctx context.Context, id int64) (*ExifDatum, error) {
	e := &ExifDatum{}
	err := Pool.QueryRow(ctx,
		`SELECT id, image_id, tag, value, created_at, updated_at FROM exif_data WHERE id = $1`, id,
	).Scan(&e.ID, &e.ImageID, &e.Tag, &e.Value, &e.CreatedAt, &e.UpdatedAt)
	return e, err
}

func ListExifData(ctx context.Context) ([]ExifDatum, error) {
	rows, err := Pool.Query(ctx,
		`SELECT id, image_id, tag, value, created_at, updated_at FROM exif_data ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var data []ExifDatum
	for rows.Next() {
		var e ExifDatum
		if err := rows.Scan(&e.ID, &e.ImageID, &e.Tag, &e.Value, &e.CreatedAt, &e.UpdatedAt); err != nil {
			return nil, err
		}
		data = append(data, e)
	}
	return data, rows.Err()
}

func CreateExifDatum(ctx context.Context, imageID int64, tag, value string) (*ExifDatum, error) {
	e := &ExifDatum{}
	err := Pool.QueryRow(ctx,
		`INSERT INTO exif_data (image_id, tag, value, created_at, updated_at)
		 VALUES ($1, $2, $3, NOW(), NOW())
		 RETURNING id, image_id, tag, value, created_at, updated_at`,
		imageID, tag, value,
	).Scan(&e.ID, &e.ImageID, &e.Tag, &e.Value, &e.CreatedAt, &e.UpdatedAt)
	return e, err
}

func UpdateExifDatum(ctx context.Context, id int64, imageID int64, tag, value string) (*ExifDatum, error) {
	e := &ExifDatum{}
	err := Pool.QueryRow(ctx,
		`UPDATE exif_data SET image_id=$1, tag=$2, value=$3, updated_at=NOW()
		 WHERE id=$4
		 RETURNING id, image_id, tag, value, created_at, updated_at`,
		imageID, tag, value, id,
	).Scan(&e.ID, &e.ImageID, &e.Tag, &e.Value, &e.CreatedAt, &e.UpdatedAt)
	return e, err
}

func DeleteExifDatum(ctx context.Context, id int64) error {
	_, err := Pool.Exec(ctx, `DELETE FROM exif_data WHERE id = $1`, id)
	return err
}

// UpsertExifDatum inserts a tag/value for an image, ignoring duplicates.
func UpsertExifDatum(ctx context.Context, imageID int64, tag, value string) error {
	_, err := Pool.Exec(ctx,
		`INSERT INTO exif_data (image_id, tag, value, created_at, updated_at)
		 VALUES ($1, $2, $3, NOW(), NOW())
		 ON CONFLICT DO NOTHING`,
		imageID, tag, value,
	)
	return err
}

// ─── Filter query (parameterised – no SQL injection) ─────────────────────────

// FilterResult holds image_id and count from the filter aggregate query.
type FilterResult struct {
	ImageID int64
	Count   int64
}

// FilterImages returns image IDs that match ALL tags in the filter set.
// It uses parameterised queries to prevent SQL injection.
func FilterImages(ctx context.Context, tags []FilterTag) ([]int64, error) {
	if len(tags) == 0 {
		return nil, nil
	}

	// Build: WHERE (tag=$1 AND value=$2) OR (tag=$3 AND value=$4) ...
	args := make([]interface{}, 0, len(tags)*2)
	query := `SELECT image_id, count(*) FROM exif_data
	          INNER JOIN images ON exif_data.image_id = images.id
	          WHERE `
	for i, t := range tags {
		if i > 0 {
			query += " OR "
		}
		query += fmt.Sprintf("(tag=$%d AND value=$%d)", len(args)+1, len(args)+2)
		args = append(args, t.Tag, t.Value)
	}
	query += fmt.Sprintf(" GROUP BY image_id HAVING count(*) = %d", len(tags))

	rows, err := Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []int64
	for rows.Next() {
		var imageID, count int64
		if err := rows.Scan(&imageID, &count); err != nil {
			return nil, err
		}
		ids = append(ids, imageID)
	}
	return ids, rows.Err()
}

// GetImagesByIDs fetches images for a list of IDs (preserving order).
func GetImagesByIDs(ctx context.Context, ids []int64) ([]Image, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := Pool.Query(ctx,
		`SELECT id, location, name, created_at, updated_at FROM images WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var images []Image
	for rows.Next() {
		var img Image
		if err := rows.Scan(&img.ID, &img.Location, &img.Name, &img.CreatedAt, &img.UpdatedAt); err != nil {
			return nil, err
		}
		images = append(images, img)
	}
	return images, rows.Err()
}

// GetExifDataForImages returns raw exif rows for the given image IDs
// (used on the image show page).
func GetExifDataForImages(ctx context.Context, imageIDs []int64) ([]ExifDatum, error) {
	if len(imageIDs) == 0 {
		return nil, nil
	}
	rows, err := Pool.Query(ctx,
		`SELECT id, image_id, tag, value, created_at, updated_at FROM exif_data WHERE image_id = ANY($1) ORDER BY tag`,
		imageIDs,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var data []ExifDatum
	for rows.Next() {
		var e ExifDatum
		if err := rows.Scan(&e.ID, &e.ImageID, &e.Tag, &e.Value, &e.CreatedAt, &e.UpdatedAt); err != nil {
			return nil, err
		}
		data = append(data, e)
	}
	return data, rows.Err()
}

// ─── Searches ────────────────────────────────────────────────────────────────

func ListSearches(ctx context.Context) ([]Search, error) {
	rows, err := Pool.Query(ctx,
		`SELECT id, md5hash, COALESCE(serial,''), COALESCE(new_tag,''), COALESCE(new_val,''), COALESCE("left",''), created_at, updated_at FROM searches ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var searches []Search
	for rows.Next() {
		var s Search
		if err := rows.Scan(&s.ID, &s.Md5hash, &s.Serial, &s.NewTag, &s.NewVal, &s.Left, &s.CreatedAt, &s.UpdatedAt); err != nil {
			return nil, err
		}
		searches = append(searches, s)
	}
	return searches, rows.Err()
}

func GetSearch(ctx context.Context, id int64) (*Search, error) {
	s := &Search{}
	err := Pool.QueryRow(ctx,
		`SELECT id, md5hash, COALESCE(serial,''), COALESCE(new_tag,''), COALESCE(new_val,''), COALESCE("left",''), created_at, updated_at FROM searches WHERE id = $1`, id,
	).Scan(&s.ID, &s.Md5hash, &s.Serial, &s.NewTag, &s.NewVal, &s.Left, &s.CreatedAt, &s.UpdatedAt)
	return s, err
}

func GetSearchByHash(ctx context.Context, hash string) (*Search, error) {
	s := &Search{}
	err := Pool.QueryRow(ctx,
		`SELECT id, md5hash, COALESCE(serial,''), COALESCE(new_tag,''), COALESCE(new_val,''), COALESCE("left",''), created_at, updated_at FROM searches WHERE md5hash = $1`, hash,
	).Scan(&s.ID, &s.Md5hash, &s.Serial, &s.NewTag, &s.NewVal, &s.Left, &s.CreatedAt, &s.UpdatedAt)
	return s, err
}

func CreateSearch(ctx context.Context, md5hash, serial, newTag, newVal, left string) (*Search, error) {
	s := &Search{}
	err := Pool.QueryRow(ctx,
		`INSERT INTO searches (md5hash, serial, new_tag, new_val, "left", created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		 RETURNING id, md5hash, COALESCE(serial,''), COALESCE(new_tag,''), COALESCE(new_val,''), COALESCE("left",''), created_at, updated_at`,
		md5hash, serial, newTag, newVal, left,
	).Scan(&s.ID, &s.Md5hash, &s.Serial, &s.NewTag, &s.NewVal, &s.Left, &s.CreatedAt, &s.UpdatedAt)
	return s, err
}

func UpdateSearch(ctx context.Context, id int64, md5hash, serial, newTag, newVal, left string) (*Search, error) {
	s := &Search{}
	err := Pool.QueryRow(ctx,
		`UPDATE searches SET md5hash=$1, serial=$2, new_tag=$3, new_val=$4, "left"=$5, updated_at=NOW()
		 WHERE id=$6
		 RETURNING id, md5hash, COALESCE(serial,''), COALESCE(new_tag,''), COALESCE(new_val,''), COALESCE("left",''), created_at, updated_at`,
		md5hash, serial, newTag, newVal, left, id,
	).Scan(&s.ID, &s.Md5hash, &s.Serial, &s.NewTag, &s.NewVal, &s.Left, &s.CreatedAt, &s.UpdatedAt)
	return s, err
}

func DeleteSearch(ctx context.Context, id int64) error {
	_, err := Pool.Exec(ctx, `DELETE FROM searches WHERE id = $1`, id)
	return err
}

// UpsertSearch inserts a search record if the md5hash doesn't already exist.
func UpsertSearch(ctx context.Context, md5hash, serial string) error {
	_, err := Pool.Exec(ctx,
		`INSERT INTO searches (md5hash, serial, created_at, updated_at)
		 VALUES ($1, $2, NOW(), NOW())
		 ON CONFLICT (md5hash) DO NOTHING`,
		md5hash, serial,
	)
	return err
}
