// Package clips is the hero's filmstrip, at /admin/clips: each clip's
// video, its slate stats and its thumbnail.
package clips

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
	path  = "/admin/clips"
	param = "clip" // the form's fields are clip[title], …, and clip[thumbnail]
)

// Controller is the clips' list, their forms, and deleting.
type Controller struct{ admin.Controller }

func (c Controller) Index(w http.ResponseWriter, r *http.Request) error {
	list, err := models.New(c.DB.Read).ListClips(r.Context())
	if err != nil {
		return err
	}
	thumbs, err := c.Storage.All(r.Context(), "Clip", "thumbnail")
	if err != nil {
		return err
	}
	return c.Render(w, r, http.StatusOK, "Clips", func(p admin.Page) templ.Component { return index(p, c.Storage, list, thumbs) })
}

func (c Controller) New(w http.ResponseWriter, r *http.Request) error {
	return c.form(w, r, http.StatusOK, models.Clip{}, nil)
}

func (c Controller) Create(w http.ResponseWriter, r *http.Request) error {
	cl, image, errs := c.fromForm(r, models.Clip{})
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, cl, errs)
	}
	id, err := models.New(c.DB.Write).CreateClip(r.Context(), models.CreateClipParams{Position: cl.Position, Title: cl.Title,
		VideoUrl: cl.VideoUrl, Runtime: cl.Runtime, Format: cl.Format, Years: cl.Years, Status: cl.Status, Now: c.Now()})
	if err != nil {
		return err
	}
	if image != nil {
		if _, err := c.Storage.Attach(r.Context(), content.Thumbnail(id), *image); err != nil {
			return err
		}
	}
	c.Notice(w, r, path, "Clip added.")
	return nil
}

func (c Controller) Edit(w http.ResponseWriter, r *http.Request) error {
	cl, err := models.New(c.DB.Read).GetClip(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	return c.form(w, r, http.StatusOK, cl, nil)
}

func (c Controller) Update(w http.ResponseWriter, r *http.Request) error {
	was, err := models.New(c.DB.Read).GetClip(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	cl, image, errs := c.fromForm(r, was)
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, cl, errs)
	}
	err = c.Content.Update(r.Context(), content.Clip, cl.ID, admin.User(r).ID, content.Change{Image: image, Write: func(q *models.Queries, now string) error {
		return q.UpdateClip(r.Context(), models.UpdateClipParams{Position: cl.Position, Title: cl.Title, VideoUrl: cl.VideoUrl,
			Runtime: cl.Runtime, Format: cl.Format, Years: cl.Years, Status: cl.Status, Now: now, ID: cl.ID})
	}})
	if err != nil {
		return err
	}
	c.Notice(w, r, path, "Clip updated.")
	return nil
}

func (c Controller) Delete(w http.ResponseWriter, r *http.Request) error {
	cl, err := models.New(c.DB.Read).GetClip(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	if err := c.Content.Delete(r.Context(), content.Clip, cl.ID, admin.User(r).ID); err != nil {
		return err
	}
	c.Notice(w, r, path, "Clip removed.")
	return nil
}

// fromForm is cl with what the form sent, its new thumbnail if one was
// chosen, and what's wrong with them.
func (c Controller) fromForm(r *http.Request, cl models.Clip) (models.Clip, *storage.File, []string) {
	v := web.Sent(r, param)
	var errs []string
	pos, ok := admin.Position(v["position"])
	if !ok {
		errs = append(errs, "Position is invalid")
	}
	cl.Position, cl.Title, cl.VideoUrl = pos, v["title"], v["video_url"]
	cl.Runtime, cl.Format, cl.Years, cl.Status = v["runtime"], v["format"], v["years"], v["status"]
	errs = append(errs, cl.Errors()...)
	image, problem := c.Image(r, param+"[thumbnail]", "Thumbnail")
	if problem != "" {
		errs = append(errs, problem)
	}
	return cl, image, errs
}

func (c Controller) form(w http.ResponseWriter, r *http.Request, status int, cl models.Clip, errs []string) error {
	title := "Add clip"
	var thumb *storage.Blob
	if cl.ID != 0 {
		title = "Edit clip"
		b, ok, err := c.Storage.Find(r.Context(), content.Thumbnail(cl.ID))
		if err != nil {
			return err
		}
		if ok {
			thumb = &b
		}
	}
	return c.Render(w, r, status, title, func(p admin.Page) templ.Component { return form(p, title, c.Storage, cl, thumb, errs) })
}
