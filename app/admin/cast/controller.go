// Package cast is the roster of people, at /admin/ensemble: each member,
// their bio and headshot.
package cast

import (
	"net/http"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/storage"
	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
)

const (
	path  = "/admin/ensemble"
	param = "ensemble_member" // the form's fields are ensemble_member[name], …, and ensemble_member[headshot]
)

// Controller is the members' list, their forms, and deleting.
type Controller struct{ admin.Controller }

func (c Controller) Index(w http.ResponseWriter, r *http.Request) error {
	list, err := models.New(c.DB.Read).ListEnsembleMembers(r.Context())
	if err != nil {
		return err
	}
	shots, err := c.Storage.All(r.Context(), "EnsembleMember", "headshot")
	if err != nil {
		return err
	}
	return c.Render(w, r, http.StatusOK, "Cast", func(p admin.Page) templ.Component { return index(p, c.Storage, list, shots) })
}

func (c Controller) New(w http.ResponseWriter, r *http.Request) error {
	return c.form(w, r, http.StatusOK, models.EnsembleMember{}, nil)
}

func (c Controller) Create(w http.ResponseWriter, r *http.Request) error {
	m, image, errs := c.fromForm(r, models.EnsembleMember{})
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, m, errs)
	}
	id, err := models.New(c.DB.Write).CreateEnsembleMember(r.Context(), models.CreateEnsembleMemberParams{Position: m.Position, Name: m.Name,
		Role: m.Role, SinceYear: m.SinceYear, Bio: m.Bio, Now: c.Now()})
	if err != nil {
		return err
	}
	if image != nil {
		if _, err := c.Storage.Attach(r.Context(), content.Headshot(id), *image); err != nil {
			return err
		}
	}
	c.Notice(w, r, path, "Member added.")
	return nil
}

func (c Controller) Edit(w http.ResponseWriter, r *http.Request) error {
	m, err := models.New(c.DB.Read).GetEnsembleMember(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	return c.form(w, r, http.StatusOK, m, nil)
}

func (c Controller) Update(w http.ResponseWriter, r *http.Request) error {
	was, err := models.New(c.DB.Read).GetEnsembleMember(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	m, image, errs := c.fromForm(r, was)
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, m, errs)
	}
	err = c.Content.Update(r.Context(), content.EnsembleMember, m.ID, admin.User(r).ID, content.Change{Image: image, Write: func(q *models.Queries, now string) error {
		return q.UpdateEnsembleMember(r.Context(), models.UpdateEnsembleMemberParams{Position: m.Position, Name: m.Name, Role: m.Role,
			SinceYear: m.SinceYear, Bio: m.Bio, Now: now, ID: m.ID})
	}})
	if err != nil {
		return err
	}
	c.Notice(w, r, path, "Member updated.")
	return nil
}

func (c Controller) Delete(w http.ResponseWriter, r *http.Request) error {
	m, err := models.New(c.DB.Read).GetEnsembleMember(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	if err := c.Content.Delete(r.Context(), content.EnsembleMember, m.ID, admin.User(r).ID); err != nil {
		return err
	}
	c.Notice(w, r, path, "Member removed.")
	return nil
}

// fromForm is m with what the form sent, their new headshot if one was
// chosen, and what's wrong with them.
func (c Controller) fromForm(r *http.Request, m models.EnsembleMember) (models.EnsembleMember, *storage.File, []string) {
	v := web.Sent(r, param)
	var errs []string
	pos, ok := admin.Position(v["position"])
	if !ok {
		errs = append(errs, "Position is invalid")
	}
	m.Position, m.Name, m.Role, m.Bio, m.SinceYear = pos, v["name"], v["role"], v["bio"], v["since_year"]
	errs = append(errs, m.Errors()...)
	image, problem := c.Image(r, param+"[headshot]", "Headshot")
	if problem != "" {
		errs = append(errs, problem)
	}
	return m, image, errs
}

func (c Controller) form(w http.ResponseWriter, r *http.Request, status int, m models.EnsembleMember, errs []string) error {
	title := "Add cast member"
	var shot *storage.Blob
	if m.ID != 0 {
		title = "Edit cast member"
		b, ok, err := c.Storage.Find(r.Context(), content.Headshot(m.ID))
		if err != nil {
			return err
		}
		if ok {
			shot = &b
		}
	}
	return c.Render(w, r, status, title, func(p admin.Page) templ.Component { return form(p, title, c.Storage, m, shot, errs) })
}
