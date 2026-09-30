// Package settings is the site copy, at /admin/settings: every one-off
// piece of text on the home page.
package settings

import (
	"net/http"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/home"
	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
)

const param = "site_setting" // the form's fields are site_setting[tagline], …

// Controller is the site copy's form.
type Controller struct{ admin.Controller }

// Edit is GET /admin/settings.
func (c Controller) Edit(w http.ResponseWriter, r *http.Request) error {
	s, err := home.Settings(r.Context(), c.DB)
	if err != nil {
		return err
	}
	return c.form(w, r, http.StatusOK, s, nil)
}

// Update is PUT /admin/settings.
func (c Controller) Update(w http.ResponseWriter, r *http.Request) error {
	s, err := home.Settings(r.Context(), c.DB)
	if err != nil {
		return err
	}
	v := web.Sent(r, param)
	s.CollectiveName, s.Tagline, s.HeroHeading = v["collective_name"], v["tagline"], v["hero_heading"]
	s.ContactHeading, s.Email, s.StudioLocations = v["contact_heading"], v["email"], v["studio_locations"]
	s.InstagramUrl, s.LetterboxdUrl, s.FooterText = v["instagram_url"], v["letterboxd_url"], v["footer_text"]
	if errs := s.Errors(); len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, s, errs)
	}
	err = c.Content.Update(r.Context(), content.SiteSetting, s.ID, admin.User(r).ID, content.Change{Write: func(q *models.Queries, now string) error {
		return q.UpdateSiteSettings(r.Context(), models.UpdateSiteSettingsParams{CollectiveName: s.CollectiveName, Tagline: s.Tagline,
			HeroHeading: s.HeroHeading, ContactHeading: s.ContactHeading, Email: s.Email, StudioLocations: s.StudioLocations,
			InstagramUrl: s.InstagramUrl, LetterboxdUrl: s.LetterboxdUrl, FooterText: s.FooterText, Now: now})
	}})
	if err != nil {
		return err
	}
	c.Notice(w, r, "/admin/settings", "Site copy updated.")
	return nil
}

func (c Controller) form(w http.ResponseWriter, r *http.Request, status int, s models.SiteSetting, errs []string) error {
	return c.Render(w, r, status, "Site copy", func(p admin.Page) templ.Component { return form(p, s, errs) })
}
