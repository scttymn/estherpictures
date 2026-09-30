// Package craft is the "what we do" services, at /admin/craft.
package craft

import (
	"net/http"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
)

const (
	path  = "/admin/craft"
	param = "craft_service" // the form's fields are craft_service[title], …
)

// Controller is the services' list, their forms, and deleting.
type Controller struct{ admin.Controller }

func (c Controller) Index(w http.ResponseWriter, r *http.Request) error {
	list, err := models.New(c.DB.Read).ListCraftServices(r.Context())
	if err != nil {
		return err
	}
	return c.Render(w, r, http.StatusOK, "Craft services", func(p admin.Page) templ.Component { return index(p, list) })
}

func (c Controller) New(w http.ResponseWriter, r *http.Request) error {
	return c.form(w, r, http.StatusOK, models.CraftService{}, nil)
}

func (c Controller) Create(w http.ResponseWriter, r *http.Request) error {
	s, errs := fromForm(r, models.CraftService{})
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, s, errs)
	}
	if _, err := models.New(c.DB.Write).CreateCraftService(r.Context(), models.CreateCraftServiceParams{
		Position: s.Position, Title: s.Title, Description: s.Description, Now: c.Now()}); err != nil {
		return err
	}
	c.Notice(w, r, path, "Service added.")
	return nil
}

func (c Controller) Edit(w http.ResponseWriter, r *http.Request) error {
	s, err := models.New(c.DB.Read).GetCraftService(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	return c.form(w, r, http.StatusOK, s, nil)
}

func (c Controller) Update(w http.ResponseWriter, r *http.Request) error {
	was, err := models.New(c.DB.Read).GetCraftService(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	s, errs := fromForm(r, was)
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, s, errs)
	}
	err = c.Content.Update(r.Context(), content.CraftService, s.ID, admin.User(r).ID, content.Change{Write: func(q *models.Queries, now string) error {
		return q.UpdateCraftService(r.Context(), models.UpdateCraftServiceParams{Position: s.Position, Title: s.Title, Description: s.Description, Now: now, ID: s.ID})
	}})
	if err != nil {
		return err
	}
	c.Notice(w, r, path, "Service updated.")
	return nil
}

func (c Controller) Delete(w http.ResponseWriter, r *http.Request) error {
	s, err := models.New(c.DB.Read).GetCraftService(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	if err := c.Content.Delete(r.Context(), content.CraftService, s.ID, admin.User(r).ID); err != nil {
		return err
	}
	c.Notice(w, r, path, "Service removed.")
	return nil
}

// fromForm is s with what the form sent, and what's wrong with it.
func fromForm(r *http.Request, s models.CraftService) (models.CraftService, []string) {
	v := web.Sent(r, param)
	var errs []string
	pos, ok := admin.Position(v["position"])
	if !ok {
		errs = append(errs, "Position is invalid")
	}
	s.Position, s.Title, s.Description = pos, v["title"], v["description"]
	return s, append(errs, s.Errors()...)
}

func (c Controller) form(w http.ResponseWriter, r *http.Request, status int, s models.CraftService, errs []string) error {
	title := "Add craft service"
	if s.ID != 0 {
		title = "Edit craft service"
	}
	return c.Render(w, r, status, title, func(p admin.Page) templ.Component { return form(p, title, s, errs) })
}
