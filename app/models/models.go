// Package models is every table's type, its queries and its rules: the
// queries in <table>.sql beside each model, turned into Go by sqlc
// (sqlc.yaml), and the rules in <table>.go.
package models

import (
	"strings"
	"time"
	"unicode/utf8"
)

// Stamp is a time as the tables keep it: UTC, as gantry's SQLite driver
// writes one, so a column sorts in time order whatever wrote each row (the
// Phoenix app's rows were moved to it).
func Stamp(t time.Time) string { return t.UTC().Format("2006-01-02 15:04:05-07:00") }

// Unstamp reads a stamp back; the zero time when it isn't one.
func Unstamp(s string) time.Time {
	for _, layout := range []string{"2006-01-02 15:04:05.999999999-07:00", "2006-01-02 15:04:05", time.RFC3339Nano} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC()
		}
	}
	return time.Time{}
}

// required is a field that can't be blank, of at most 120 characters (the
// Ecto changesets' validate_required and validate_length).
func required(name, value string) []string {
	switch {
	case strings.TrimSpace(value) == "":
		return []string{name + " can't be blank"}
	case utf8.RuneCountInString(value) > 120:
		return []string{name + " should be at most 120 characters"}
	}
	return nil
}
