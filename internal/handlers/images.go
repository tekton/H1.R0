package handlers

import (
	"log"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/tyler-agee/h1r0/internal/db"
)

// ─── Images index ────────────────────────────────────────────────────────────

type ImagesIndexData struct {
	Notice string
	Images []db.Image
}

func ImagesIndex(w http.ResponseWriter, r *http.Request) {
	images, err := db.ListImages(r.Context())
	if err != nil {
		log.Printf("ImagesIndex: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	render(w, "images_index.html", ImagesIndexData{Images: images})
}

// ─── Images show ─────────────────────────────────────────────────────────────

type ImagesShowData struct {
	Notice   string
	Image    *db.Image
	ExifData []db.ExifDatum
}

func ImagesShow(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	img, err := db.GetImage(r.Context(), id)
	if err != nil {
		log.Printf("ImagesShow GetImage %d: %v", id, err)
		http.NotFound(w, r)
		return
	}

	exifData, err := db.GetExifDataForImages(r.Context(), []int64{id})
	if err != nil {
		log.Printf("ImagesShow GetExifData %d: %v", id, err)
	}

	render(w, "images_show.html", ImagesShowData{Image: img, ExifData: exifData})
}

// ─── Images new ──────────────────────────────────────────────────────────────

type ImagesFormData struct {
	Notice string
	Image  *db.Image
	Errors []string
	Action string
	Method string
}

func ImagesNew(w http.ResponseWriter, r *http.Request) {
	render(w, "images_new.html", ImagesFormData{
		Image:  &db.Image{},
		Action: "/images",
		Method: "POST",
	})
}

// ─── Images create ───────────────────────────────────────────────────────────

func ImagesCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	location := r.FormValue("location")
	name := r.FormValue("name")

	if location == "" {
		render(w, "images_new.html", ImagesFormData{
			Image:  &db.Image{Location: location, Name: name},
			Errors: []string{"Location cannot be blank"},
			Action: "/images",
			Method: "POST",
		})
		return
	}

	img, err := db.CreateImage(r.Context(), location, name)
	if err != nil {
		log.Printf("ImagesCreate: %v", err)
		render(w, "images_new.html", ImagesFormData{
			Image:  &db.Image{Location: location, Name: name},
			Errors: []string{"Failed to create image: " + err.Error()},
			Action: "/images",
			Method: "POST",
		})
		return
	}

	http.Redirect(w, r, "/images/"+strconv.FormatInt(img.ID, 10)+"?notice=Image+was+successfully+created.", http.StatusSeeOther)
}

// ─── Images edit ─────────────────────────────────────────────────────────────

func ImagesEdit(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	img, err := db.GetImage(r.Context(), id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	render(w, "images_edit.html", ImagesFormData{
		Image:  img,
		Action: "/images/" + strconv.FormatInt(id, 10),
		Method: "PUT",
	})
}

// ─── Images update ───────────────────────────────────────────────────────────

func ImagesUpdate(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	location := r.FormValue("location")
	name := r.FormValue("name")

	img, err := db.UpdateImage(r.Context(), id, location, name)
	if err != nil {
		log.Printf("ImagesUpdate %d: %v", id, err)
		render(w, "images_edit.html", ImagesFormData{
			Image:  &db.Image{ID: id, Location: location, Name: name},
			Errors: []string{"Failed to update image: " + err.Error()},
			Action: "/images/" + strconv.FormatInt(id, 10),
			Method: "PUT",
		})
		return
	}

	http.Redirect(w, r, "/images/"+strconv.FormatInt(img.ID, 10)+"?notice=Image+was+successfully+updated.", http.StatusSeeOther)
}

// ─── Images delete ───────────────────────────────────────────────────────────

func ImagesDelete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if err := db.DeleteImage(r.Context(), id); err != nil {
		log.Printf("ImagesDelete %d: %v", id, err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/images", http.StatusSeeOther)
}

// ─── Images get_exif_data ────────────────────────────────────────────────────

type ImageExifData struct {
	Image    *db.Image
	ExifData []db.ExifDatum
}

func ImagesGetExif(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	img, err := db.GetImage(r.Context(), id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	exifData, err := db.GetExifDataForImages(r.Context(), []int64{id})
	if err != nil {
		log.Printf("ImagesGetExif %d: %v", id, err)
	}
	render(w, "images_exif.html", ImageExifData{Image: img, ExifData: exifData})
}
