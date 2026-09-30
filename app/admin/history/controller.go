// Package history is every edit and deletion, at /admin/history: what each
// changed, restoring the state before it, and discarding versions.
package history

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
)

const path = "/admin/history"

// Limit is how many versions the page shows.
const Limit = 100

// Controller is the history's page and what it does.
type Controller struct{ admin.Controller }

// Index is GET /admin/history, newest first.
func (c Controller) Index(w http.ResponseWriter, r *http.Request) error {
	entries, err := c.Content.History(r.Context(), Limit)
	if err != nil {
		return err
	}
	return c.Render(w, r, http.StatusOK, "History", func(p admin.Page) templ.Component { return index(p, entries) })
}

// Restore is POST /admin/history/{id}/restore.
func (c Controller) Restore(w http.ResponseWriter, r *http.Request) error {
	kind, err := c.Content.Restore(r.Context(), web.ID(r, "id"), admin.User(r).ID)
	if err != nil {
		return err
	}
	c.Notice(w, r, path, "Restored "+strings.ToLower(KindName(kind))+".")
	return nil
}

// Discard is DELETE /admin/history/{id}.
func (c Controller) Discard(w http.ResponseWriter, r *http.Request) error {
	if _, err := models.New(c.DB.Read).GetContentVersion(r.Context(), web.ID(r, "id")); err != nil {
		return err
	}
	if err := c.Content.Discard(r.Context(), web.ID(r, "id")); err != nil {
		return err
	}
	c.Notice(w, r, path, "History entry discarded.")
	return nil
}

// Clear is DELETE /admin/history: every version, and the images only they
// named.
func (c Controller) Clear(w http.ResponseWriter, r *http.Request) error {
	versions, images, err := c.Content.Clear(r.Context())
	if err != nil {
		return err
	}
	c.Notice(w, r, path, fmt.Sprintf("Discarded %d history %s and deleted %d unused %s.",
		versions, plural(versions, "entry", "entries"), images, plural(int64(images), "image", "images")))
	return nil
}

func plural(n int64, one, many string) string {
	if n == 1 {
		return one
	}
	return many
}

// KindName is a kind of record as people say it: "Craft service".
func KindName(kind string) string {
	if kind == content.EnsembleMember {
		return "Cast member"
	}
	s := strings.ReplaceAll(kind, "_", " ")
	return strings.ToUpper(s[:1]) + s[1:]
}

// fieldName is a field as people say it: "video url".
func fieldName(field string) string { return strings.ReplaceAll(field, "_", " ") }

// shown is a value in the before and after columns: "—" for blank.
func shown(v string) string {
	if v == "" {
		return "—"
	}
	return v
}
