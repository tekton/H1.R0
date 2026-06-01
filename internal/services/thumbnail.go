// Package services implements thumbnail generation using
// github.com/disintegration/imaging.
package services

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/disintegration/imaging"
)

// GenerateThumbnail resizes a JPEG to fit within 200×133 pixels (Lanczos
// resampling) and saves the result to the thumbnails sub-directory that
// mirrors the source folder structure.
//
// sourceFile is the absolute path to the original JPEG.
// destFile is the absolute path where the thumbnail should be written.
// The destination directory is created if it does not already exist.
func GenerateThumbnail(sourceFile, destFile string) error {
	src, err := imaging.Open(sourceFile)
	if err != nil {
		return fmt.Errorf("GenerateThumbnail open %s: %w", sourceFile, err)
	}

	thumb := imaging.Resize(src, 200, 133, imaging.Lanczos)

	destDir := filepath.Dir(destFile)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("GenerateThumbnail mkdir %s: %w", destDir, err)
	}

	if err := imaging.Save(thumb, destFile); err != nil {
		return fmt.Errorf("GenerateThumbnail save %s: %w", destFile, err)
	}

	log.Printf("thumbnail created: %s", destFile)
	return nil
}
