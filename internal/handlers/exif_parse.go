package handlers

import (
	"log"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/tyler-agee/h1r0/internal/db"
	"github.com/tyler-agee/h1r0/internal/workers"
	"io/fs"
	"os"
)

// ExifParseIndex handles GET /exif_parse/{folder}
// It scans the folder for JPEGs and dispatches goroutine workers to extract
// EXIF data for each one, creating image records as needed.
func ExifParseIndex(w http.ResponseWriter, r *http.Request) {
	folder := chi.URLParam(r, "folder")
	assetsBase := AssetsBase()
	loc := filepath.Join(assetsBase, folder)

	entries, err := os.ReadDir(loc)
	if err != nil {
		log.Printf("ExifParseIndex ReadDir %s: %v", loc, err)
		http.Error(w, "Folder not found: "+loc, http.StatusNotFound)
		return
	}

	dispatched := 0
	fs.WalkDir(os.DirFS(loc), ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		return nil
	})

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.EqualFold(filepath.Ext(name), ".jpg") {
			continue
		}

		imageLocation := folder + "/" + name
		filePath := filepath.Join(loc, name)

		img, err := db.FindOrCreateImage(r.Context(), imageLocation)
		if err != nil {
			log.Printf("ExifParseIndex FindOrCreateImage %s: %v", imageLocation, err)
			continue
		}

		workers.DispatchEXIF(filePath, img.ID)
		dispatched++
	}

	log.Printf("ExifParseIndex: dispatched %d EXIF jobs for folder %s", dispatched, folder)
	render(w, "exif_parse_index.html", map[string]interface{}{
		"Folder":     folder,
		"Dispatched": dispatched,
	})
}
