package handlers

import (
	"html/template"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

// tmpl holds all parsed templates.
var tmpl *template.Template

// InitTemplates parses all .html files in the templates directory.
// Call this once at startup after determining the templates root.
func InitTemplates(templatesDir string) error {
	pattern := filepath.Join(templatesDir, "*.html")
	t, err := template.ParseGlob(pattern)
	if err != nil {
		return err
	}
	tmpl = t
	return nil
}

// render executes a named template with the given data, writing the result to w.
func render(w http.ResponseWriter, name string, data interface{}) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tmpl.ExecuteTemplate(w, name, data); err != nil {
		log.Printf("template %s error: %v", name, err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// AssetsBase returns the absolute path to app/assets/images, which is the
// directory from which images and thumbnails are served.
func AssetsBase() string {
	if v := os.Getenv("ASSETS_BASE"); v != "" {
		return v
	}
	// Default: relative to the binary's working directory.
	return "app/assets/images"
}
