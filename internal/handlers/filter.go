package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/tyler-agee/h1r0/internal/db"
	"github.com/tyler-agee/h1r0/internal/filter"
)

// FilterHashData is the view-model for the filter page.
type FilterHashData struct {
	Notice       string
	Search       *db.Search
	SerialTags   []db.FilterTag
	Images       []db.Image
	ExifCounts   []ExifCountView
}

// FilterHashFilter handles GET /filter/{hash_filter}
// It looks up the saved search by hash, executes a safe parameterised query
// to find matching images, then computes new hashes for refinement links.
func FilterHashFilter(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	hashFilter := chi.URLParam(r, "hash_filter")

	// Look up the saved search.
	s, err := db.GetSearchByHash(ctx, hashFilter)
	if err != nil {
		log.Printf("FilterHashFilter GetSearchByHash %s: %v", hashFilter, err)
		http.NotFound(w, r)
		return
	}

	// Deserialise the serial JSON.
	var serialTags []db.FilterTag
	if s.Serial != "" {
		if err := json.Unmarshal([]byte(s.Serial), &serialTags); err != nil {
			log.Printf("FilterHashFilter unmarshal serial: %v", err)
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
	}

	// Find images matching ALL tags in the filter set.
	imageIDs, err := db.FilterImages(ctx, serialTags)
	if err != nil {
		log.Printf("FilterHashFilter FilterImages: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	images, err := db.GetImagesByIDs(ctx, imageIDs)
	if err != nil {
		log.Printf("FilterHashFilter GetImagesByIDs: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	// Get EXIF counts for filtered images.
	exifCounts, err := db.ListExifCountsForImages(ctx, imageIDs)
	if err != nil {
		log.Printf("FilterHashFilter ListExifCountsForImages: %v", err)
	}

	// Build refinement hashes: current filter tags + each additional tag/value.
	currentTags := filter.FromDBTags(serialTags)
	views := make([]ExifCountView, 0, len(exifCounts))
	for _, ec := range exifCounts {
		newTags := append(append([]filter.TagValue{}, currentTags...), filter.TagValue{Tag: ec.Tag, Value: ec.Value})
		hash, err := filter.FilterCheck(ctx, newTags)
		if err != nil {
			log.Printf("FilterHashFilter FilterCheck: %v", err)
		}
		views = append(views, ExifCountView{ExifCount: ec, Hash: hash})
	}

	render(w, "filter_hash_filter.html", FilterHashData{
		Search:     s,
		SerialTags: serialTags,
		Images:     images,
		ExifCounts: views,
	})
}
