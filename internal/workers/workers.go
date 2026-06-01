// Package workers provides goroutine-based fire-and-forget background jobs.
// Jobs run within the server process; they are not durable across restarts.
package workers

import (
	"context"
	"log"

	"github.com/tyler-agee/h1r0/internal/services"
)

// DispatchEXIF launches a goroutine to extract EXIF data from filePath and
// store the tags for imageID.
func DispatchEXIF(filePath string, imageID int64) {
	go func() {
		if err := services.ExtractEXIF(context.Background(), filePath, imageID); err != nil {
			log.Printf("exif worker error (file=%s id=%d): %v", filePath, imageID, err)
		}
	}()
}

// DispatchThumbnail launches a goroutine to generate a thumbnail.
// sourceFile and destFile are absolute paths.
func DispatchThumbnail(sourceFile, destFile string) {
	go func() {
		if err := services.GenerateThumbnail(sourceFile, destFile); err != nil {
			log.Printf("thumbnail worker error (src=%s): %v", sourceFile, err)
		}
	}()
}
