package handlers

import (
	"log"
	"net/http"

	"github.com/tyler-agee/h1r0/internal/db"
	"github.com/tyler-agee/h1r0/internal/filter"
)

// BrowseData is the view-model for the homepage.
type BrowseData struct {
	Notice    string
	Images    []db.Image
	ExifCounts []ExifCountView
}

// ExifCountView wraps db.ExifCount with the filter hash pre-computed.
type ExifCountView struct {
	db.ExifCount
	Hash string
}

// BrowseIndex handles GET / — random 4 images + all EXIF tag/value counts.
func BrowseIndex(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	images, err := db.RandomImages(ctx, 4)
	if err != nil {
		log.Printf("BrowseIndex RandomImages: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	counts, err := db.ListExifCounts(ctx)
	if err != nil {
		log.Printf("BrowseIndex ListExifCounts: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	views := make([]ExifCountView, 0, len(counts))
	for _, ec := range counts {
		tags := []filter.TagValue{{Tag: ec.Tag, Value: ec.Value}}
		hash, err := filter.FilterCheck(ctx, tags)
		if err != nil {
			log.Printf("BrowseIndex FilterCheck tag=%s: %v", ec.Tag, err)
			hash = ""
		}
		views = append(views, ExifCountView{ExifCount: ec, Hash: hash})
	}

	render(w, "browse_index.html", BrowseData{
		Images:     images,
		ExifCounts: views,
	})
}
