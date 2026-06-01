package handlers

import (
	"log"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/tyler-agee/h1r0/internal/workers"
	"os"
)

// ThumbnailsCreateFromFolder handles GET /thumbnail/{folder}
// It scans the folder for JPEGs and dispatches goroutine workers to generate
// thumbnails, saving them into a thumbnails/<folder>/ sub-directory.
func ThumbnailsCreateFromFolder(w http.ResponseWriter, r *http.Request) {
	folder := chi.URLParam(r, "folder")
	assetsBase := AssetsBase()
	loc := filepath.Join(assetsBase, folder)

	entries, err := os.ReadDir(loc)
	if err != nil {
		log.Printf("ThumbnailsCreateFromFolder ReadDir %s: %v", loc, err)
		http.Error(w, "Folder not found: "+loc, http.StatusNotFound)
		return
	}

	dispatched := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.EqualFold(filepath.Ext(name), ".jpg") {
			continue
		}

		sourceFile := filepath.Join(loc, name)
		destFile := filepath.Join(assetsBase, "thumbnails", folder, name)

		workers.DispatchThumbnail(sourceFile, destFile)
		dispatched++
	}

	log.Printf("ThumbnailsCreateFromFolder: dispatched %d thumbnail jobs for folder %s", dispatched, folder)
	render(w, "thumbnails_create_from_folder.html", map[string]interface{}{
		"Folder":     folder,
		"Dispatched": dispatched,
	})
}
