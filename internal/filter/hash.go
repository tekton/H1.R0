// Package filter implements the MD5 hash used to key saved searches.
//
// A search is identified by the canonical MD5 of its sorted tag/value set.
// The original Rails app used YAML serialisation; this Go port uses JSON
// for a clean, portable format.  Existing hashes stored in the database
// will need to be recomputed if you are migrating live data from the Rails app.
package filter

import (
	"context"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"sort"

	"github.com/tyler-agee/h1r0/internal/db"
)

// TagValue is one element of a filter set.
type TagValue struct {
	Tag   string `json:"tag"`
	Value string `json:"value"`
}

// Hash computes the MD5 of a canonical JSON representation of the tag/value set.
// The slice is sorted by (tag, value) before serialisation so that the hash is
// independent of insertion order.
func Hash(tags []TagValue) string {
	sorted := make([]TagValue, len(tags))
	copy(sorted, tags)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Tag != sorted[j].Tag {
			return sorted[i].Tag < sorted[j].Tag
		}
		return sorted[i].Value < sorted[j].Value
	})

	b, _ := json.Marshal(sorted)
	sum := md5.Sum(b)
	return fmt.Sprintf("%x", sum)
}

// FilterCheck upserts a search row for the given hash and tag set.
// It mirrors the Rails filter_check helper in ApplicationController.
func FilterCheck(ctx context.Context, tags []TagValue) (string, error) {
	hash := Hash(tags)

	// Serialise as JSON for storage.
	serialJSON, err := json.Marshal(tags)
	if err != nil {
		return "", fmt.Errorf("filter.FilterCheck marshal: %w", err)
	}

	// Convert to db.FilterTag slice for the upsert.
	if err := db.UpsertSearch(ctx, hash, string(serialJSON)); err != nil {
		return "", fmt.Errorf("filter.FilterCheck upsert: %w", err)
	}
	return hash, nil
}

// ToDBTags converts []TagValue to []db.FilterTag.
func ToDBTags(tags []TagValue) []db.FilterTag {
	out := make([]db.FilterTag, len(tags))
	for i, t := range tags {
		out[i] = db.FilterTag{Tag: t.Tag, Value: t.Value}
	}
	return out
}

// FromDBTags converts []db.FilterTag to []TagValue.
func FromDBTags(tags []db.FilterTag) []TagValue {
	out := make([]TagValue, len(tags))
	for i, t := range tags {
		out[i] = TagValue{Tag: t.Tag, Value: t.Value}
	}
	return out
}
