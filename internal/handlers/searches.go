package handlers

import (
	"log"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/tyler-agee/h1r0/internal/db"
)

// ─── Searches index ──────────────────────────────────────────────────────────

type SearchesIndexData struct {
	Notice   string
	Searches []db.Search
}

func SearchesIndex(w http.ResponseWriter, r *http.Request) {
	searches, err := db.ListSearches(r.Context())
	if err != nil {
		log.Printf("SearchesIndex: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	render(w, "searches_index.html", SearchesIndexData{Searches: searches})
}

// ─── Searches show ───────────────────────────────────────────────────────────

type SearchesShowData struct {
	Notice string
	Search *db.Search
}

func SearchesShow(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	s, err := db.GetSearch(r.Context(), id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	render(w, "searches_show.html", SearchesShowData{Search: s})
}

// ─── Searches new ────────────────────────────────────────────────────────────

type SearchesFormData struct {
	Notice string
	Search *db.Search
	Errors []string
	Action string
	Method string
}

func SearchesNew(w http.ResponseWriter, r *http.Request) {
	render(w, "searches_new.html", SearchesFormData{
		Search: &db.Search{},
		Action: "/searches",
		Method: "POST",
	})
}

// ─── Searches create ─────────────────────────────────────────────────────────

func SearchesCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	md5hash := r.FormValue("md5hash")
	serial := r.FormValue("serial")

	s, err := db.CreateSearch(r.Context(), md5hash, serial, "", "", "")
	if err != nil {
		log.Printf("SearchesCreate: %v", err)
		render(w, "searches_new.html", SearchesFormData{
			Search: &db.Search{Md5hash: md5hash, Serial: serial},
			Errors: []string{"Failed to create search: " + err.Error()},
			Action: "/searches",
			Method: "POST",
		})
		return
	}

	http.Redirect(w, r, "/searches/"+strconv.FormatInt(s.ID, 10)+"?notice=Search+was+successfully+created.", http.StatusSeeOther)
}

// ─── Searches edit ───────────────────────────────────────────────────────────

func SearchesEdit(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	s, err := db.GetSearch(r.Context(), id)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	render(w, "searches_edit.html", SearchesFormData{
		Search: s,
		Action: "/searches/" + strconv.FormatInt(id, 10),
		Method: "PUT",
	})
}

// ─── Searches update ─────────────────────────────────────────────────────────

func SearchesUpdate(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	md5hash := r.FormValue("md5hash")
	serial := r.FormValue("serial")

	s, err := db.UpdateSearch(r.Context(), id, md5hash, serial, "", "", "")
	if err != nil {
		log.Printf("SearchesUpdate %d: %v", id, err)
		render(w, "searches_edit.html", SearchesFormData{
			Search: &db.Search{ID: id, Md5hash: md5hash, Serial: serial},
			Errors: []string{"Failed to update: " + err.Error()},
			Action: "/searches/" + strconv.FormatInt(id, 10),
			Method: "PUT",
		})
		return
	}

	http.Redirect(w, r, "/searches/"+strconv.FormatInt(s.ID, 10)+"?notice=Search+was+successfully+updated.", http.StatusSeeOther)
}

// ─── Searches delete ─────────────────────────────────────────────────────────

func SearchesDelete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	if err := db.DeleteSearch(r.Context(), id); err != nil {
		log.Printf("SearchesDelete %d: %v", id, err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/searches", http.StatusSeeOther)
}
