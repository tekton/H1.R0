package handlers

import (
	"log"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/tyler-agee/h1r0/internal/db"
	"github.com/tyler-agee/h1r0/internal/filter"
)

// ─── ExifData index ──────────────────────────────────────────────────────────

type ExifDataIndexData struct {
	Notice     string
	ExifCounts []ExifCountView
}

func ExifDataIndex(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	counts, err := db.ListExifCounts(ctx)
	if err != nil {
		log.Printf("ExifDataIndex: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	views := make([]ExifCountView, 0, len(counts))
	for _, ec := range counts {
		tags := []filter.TagValue{{Tag: ec.Tag, Value: ec.Value}}
		hash, err := filter.FilterCheck(ctx, tags)
		if err != nil {
			log.Printf("ExifDataIndex FilterCheck tag=%s: %v", ec.Tag, err)
		}
		views = append(views, ExifCountView{ExifCount: ec, Hash: hash})
	}

	render(w, "exif_data_index.html", ExifDataIndexData{ExifCounts: views})
}

// ─── ExifData show ───────────────────────────────────────────────────────────

type ExifDataShowData struct {
	Notice    string
	ExifDatum *db.ExifDatum
}

func ExifDataShow(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	e, err := db.GetExifDatum(r.Context(), id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	render(w, "exif_data_show.html", ExifDataShowData{ExifDatum: e})
}

// ─── ExifData new ────────────────────────────────────────────────────────────

type ExifDataFormData struct {
	Notice    string
	ExifDatum *db.ExifDatum
	Errors    []string
	Action    string
	Method    string
}

func ExifDataNew(w http.ResponseWriter, r *http.Request) {
	render(w, "exif_data_new.html", ExifDataFormData{
		ExifDatum: &db.ExifDatum{},
		Action:    "/exif_data",
		Method:    "POST",
	})
}

// ─── ExifData create ─────────────────────────────────────────────────────────

func ExifDataCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	imageIDStr := r.FormValue("image_id")
	tag := r.FormValue("tag")
	value := r.FormValue("value")

	imageID, err := strconv.ParseInt(imageIDStr, 10, 64)
	if err != nil || imageID == 0 {
		render(w, "exif_data_new.html", ExifDataFormData{
			ExifDatum: &db.ExifDatum{Tag: tag, Value: value},
			Errors:    []string{"Image ID must be a valid number"},
			Action:    "/exif_data",
			Method:    "POST",
		})
		return
	}

	e, err := db.CreateExifDatum(r.Context(), imageID, tag, value)
	if err != nil {
		log.Printf("ExifDataCreate: %v", err)
		render(w, "exif_data_new.html", ExifDataFormData{
			ExifDatum: &db.ExifDatum{ImageID: imageID, Tag: tag, Value: value},
			Errors:    []string{"Failed to create exif datum: " + err.Error()},
			Action:    "/exif_data",
			Method:    "POST",
		})
		return
	}

	http.Redirect(w, r, "/exif_data/"+strconv.FormatInt(e.ID, 10)+"?notice=Exif+datum+was+successfully+created.", http.StatusSeeOther)
}

// ─── ExifData edit ───────────────────────────────────────────────────────────

func ExifDataEdit(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	e, err := db.GetExifDatum(r.Context(), id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	render(w, "exif_data_edit.html", ExifDataFormData{
		ExifDatum: e,
		Action:    "/exif_data/" + strconv.FormatInt(id, 10),
		Method:    "PUT",
	})
}

// ─── ExifData update ─────────────────────────────────────────────────────────

func ExifDataUpdate(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	imageID, _ := strconv.ParseInt(r.FormValue("image_id"), 10, 64)
	tag := r.FormValue("tag")
	value := r.FormValue("value")

	e, err := db.UpdateExifDatum(r.Context(), id, imageID, tag, value)
	if err != nil {
		log.Printf("ExifDataUpdate %d: %v", id, err)
		render(w, "exif_data_edit.html", ExifDataFormData{
			ExifDatum: &db.ExifDatum{ID: id, ImageID: imageID, Tag: tag, Value: value},
			Errors:    []string{"Failed to update: " + err.Error()},
			Action:    "/exif_data/" + strconv.FormatInt(id, 10),
			Method:    "PUT",
		})
		return
	}

	http.Redirect(w, r, "/exif_data/"+strconv.FormatInt(e.ID, 10)+"?notice=Exif+datum+was+successfully+updated.", http.StatusSeeOther)
}

// ─── ExifData delete ─────────────────────────────────────────────────────────

func ExifDataDelete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if err := db.DeleteExifDatum(r.Context(), id); err != nil {
		log.Printf("ExifDataDelete %d: %v", id, err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/exif_data", http.StatusSeeOther)
}
