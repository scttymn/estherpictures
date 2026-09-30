package admin

import (
	"net/http"

	"github.com/a-h/templ"

	"github.com/scttymn/estherpictures/app/models"
)

// Counts are how many of each list the site has.
type Counts struct{ Craft, Clips, Cast int64 }

// Dashboard is GET /admin: a card for each part of the site.
func (c Controller) Dashboard(w http.ResponseWriter, r *http.Request) error {
	q := models.New(c.DB.Read)
	var n Counts
	var err error
	if n.Craft, err = q.CountCraftServices(r.Context()); err != nil {
		return err
	}
	if n.Clips, err = q.CountClips(r.Context()); err != nil {
		return err
	}
	if n.Cast, err = q.CountEnsembleMembers(r.Context()); err != nil {
		return err
	}
	return c.Render(w, r, http.StatusOK, "Dashboard", func(p Page) templ.Component { return dashboard(p, n) })
}
