// Package services implements EXIF extraction using github.com/rwcarlsen/goexif.
package services

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
	"github.com/tyler-agee/h1r0/internal/db"
)

// exifWalker collects all tag names and string values.
type exifWalker struct {
	imageID int64
	ctx     context.Context
	errs    []error
}

func (w *exifWalker) Walk(name exif.FieldName, tag *tiff.Tag) error {
	tagStr := string(name)
	valStr := tag.String()
	if err := db.UpsertExifDatum(w.ctx, w.imageID, tagStr, valStr); err != nil {
		w.errs = append(w.errs, fmt.Errorf("upsert %s: %w", tagStr, err))
	}
	return nil
}

// ExtractEXIF parses EXIF data from a JPEG file and stores each tag/value
// pair in the exif_data table.  Duplicate rows are silently ignored via
// ON CONFLICT DO NOTHING.
func ExtractEXIF(ctx context.Context, filePath string, imageID int64) error {
	f, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("ExtractEXIF open %s: %w", filePath, err)
	}
	defer f.Close()

	x, err := exif.Decode(f)
	if err != nil {
		// Not all JPEGs have EXIF data — log and continue.
		log.Printf("EXIF decode skipped %s: %v", filePath, err)
		return nil
	}

	walker := &exifWalker{imageID: imageID, ctx: ctx}
	if err := x.Walk(walker); err != nil {
		return fmt.Errorf("ExtractEXIF walk %s: %w", filePath, err)
	}
	if len(walker.errs) > 0 {
		log.Printf("ExtractEXIF %s: %d tag errors (first: %v)", filePath, len(walker.errs), walker.errs[0])
	}
	return nil
}
