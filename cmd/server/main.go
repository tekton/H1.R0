package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/joho/godotenv"
	"github.com/tyler-agee/h1r0/internal/db"
	"github.com/tyler-agee/h1r0/internal/handlers"
)

func main() {
	// Load .env if present (dev convenience; ignored in production).
	_ = godotenv.Load()

	// Initialise database pool.
	if err := db.Connect(context.Background()); err != nil {
		log.Fatalf("db connect: %v", err)
	}
	defer db.Pool.Close()

	// Locate templates directory relative to the source file (works when running
	// via `go run ./cmd/server` from the repo root) or relative to the binary.
	templatesDir := findDir("templates")
	if err := handlers.InitTemplates(templatesDir); err != nil {
		log.Fatalf("template init: %v", err)
	}

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(methodOverrideMiddleware)

	// Static assets — serve app/assets/images/ at /assets/images/
	assetsBase := handlers.AssetsBase()
	r.Handle("/assets/images/*", http.StripPrefix("/assets/images/",
		http.FileServer(http.Dir(assetsBase))))

	// ── Routes ───────────────────────────────────────────────────────────────

	// Homepage
	r.Get("/", handlers.BrowseIndex)

	// Images
	r.Route("/images", func(r chi.Router) {
		r.Get("/", handlers.ImagesIndex)
		r.Post("/", handlers.ImagesCreate)
		r.Get("/new", handlers.ImagesNew)
		r.Route("/{id}", func(r chi.Router) {
			r.Get("/", handlers.ImagesShow)
			r.Get("/edit", handlers.ImagesEdit)
			r.Put("/", handlers.ImagesUpdate)
			r.Delete("/", handlers.ImagesDelete)
			r.Get("/exif", handlers.ImagesGetExif)
		})
	})

	// ExifData
	r.Route("/exif_data", func(r chi.Router) {
		r.Get("/", handlers.ExifDataIndex)
		r.Post("/", handlers.ExifDataCreate)
		r.Get("/new", handlers.ExifDataNew)
		r.Route("/{id}", func(r chi.Router) {
			r.Get("/", handlers.ExifDataShow)
			r.Get("/edit", handlers.ExifDataEdit)
			r.Put("/", handlers.ExifDataUpdate)
			r.Delete("/", handlers.ExifDataDelete)
		})
	})

	// Background job triggers
	r.Get("/exif_parse/{folder}", handlers.ExifParseIndex)
	r.Get("/thumbnail/{folder}", handlers.ThumbnailsCreateFromFolder)

	// Filter
	r.Get("/filter/{hash_filter}", handlers.FilterHashFilter)

	// Searches
	r.Route("/searches", func(r chi.Router) {
		r.Get("/", handlers.SearchesIndex)
		r.Post("/", handlers.SearchesCreate)
		r.Get("/new", handlers.SearchesNew)
		r.Route("/{id}", func(r chi.Router) {
			r.Get("/", handlers.SearchesShow)
			r.Get("/edit", handlers.SearchesEdit)
			r.Put("/", handlers.SearchesUpdate)
			r.Delete("/", handlers.SearchesDelete)
		})
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	addr := ":" + port
	log.Printf("H1.R0 listening on %s", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("listen: %v", err)
	}
}

// methodOverrideMiddleware rewrites POST requests that carry a _method form
// field to the appropriate HTTP method (PUT, DELETE, PATCH).  This lets HTML
// forms submit PUT and DELETE requests that browsers don't support natively.
func methodOverrideMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			// Parse the form so we can read _method.
			// We clone the request to avoid consuming the body.
			if err := r.ParseForm(); err == nil {
				if m := r.FormValue("_method"); m != "" {
					r.Method = strings.ToUpper(m)
				}
			}
		}
		next.ServeHTTP(w, r)
	})
}

// findDir searches for a directory by walking up from the binary/source location.
func findDir(name string) string {
	// When running via `go run`, __file__ is not available in Go; use os.Getwd.
	wd, err := os.Getwd()
	if err == nil {
		candidate := filepath.Join(wd, name)
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			return candidate
		}
	}

	// Fallback: walk up from the current source file location (useful during
	// development when the binary is in a temp dir).
	_, filename, _, ok := runtime.Caller(0)
	if ok {
		dir := filepath.Dir(filename)
		for i := 0; i < 5; i++ {
			candidate := filepath.Join(dir, name)
			if info, err := os.Stat(candidate); err == nil && info.IsDir() {
				return candidate
			}
			dir = filepath.Dir(dir)
		}
	}

	return name // relative fallback
}
