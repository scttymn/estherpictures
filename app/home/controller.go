// Package home is the public site: one page, at /.
package home

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/scttymn/gantry/db"
	"github.com/scttymn/gantry/storage"
	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/models"
)

// Controller draws the home page.
type Controller struct {
	DB      *db.DB
	Storage *storage.Storage
}

// Page is everything the home page shows.
type Page struct {
	Settings   models.SiteSetting
	Craft      []models.CraftService
	Clips      []models.Clip
	Cast       []models.EnsembleMember
	Thumbnails map[int64]storage.Blob // by clip
	Headshots  map[int64]storage.Blob // by member
	Storage    *storage.Storage
}

// Show is GET /.
func (c Controller) Show(w http.ResponseWriter, r *http.Request) error {
	p, err := c.page(r.Context())
	if err != nil {
		return err
	}
	return web.Render(w, r, http.StatusOK, page(p))
}

func (c Controller) page(ctx context.Context) (p Page, err error) {
	q := models.New(c.DB.Read)
	if p.Settings, err = Settings(ctx, c.DB); err != nil {
		return p, err
	}
	if p.Craft, err = q.ListCraftServices(ctx); err != nil {
		return p, err
	}
	if p.Clips, err = q.ListClips(ctx); err != nil {
		return p, err
	}
	if p.Cast, err = q.ListEnsembleMembers(ctx); err != nil {
		return p, err
	}
	if p.Thumbnails, err = c.Storage.All(ctx, "Clip", "thumbnail"); err != nil {
		return p, err
	}
	if p.Headshots, err = c.Storage.All(ctx, "EnsembleMember", "headshot"); err != nil {
		return p, err
	}
	p.Storage = c.Storage
	return p, nil
}

// Settings is the site copy, made with its defaults when there's none yet.
func Settings(ctx context.Context, d *db.DB) (models.SiteSetting, error) {
	s, err := models.New(d.Read).GetSiteSettings(ctx)
	if !errors.Is(err, sql.ErrNoRows) {
		return s, err
	}
	if err := models.New(d.Write).CreateSiteSettings(ctx, models.Stamp(time.Now())); err != nil {
		return s, err
	}
	return models.New(d.Write).GetSiteSettings(ctx)
}

// posterSizes is how wide the hero's poster draws, for the browser to fetch
// a copy that sharp: it covers the reel, so a picture wider than the reel's
// shape is drawn wider than the reel, and cropped. Stacked (1080px and
// under), the reel is the page's width at 16:9 (site.css), so a 2:1 still
// draws 13% wider; beside the slate it's at least 560px tall.
func posterSizes(b storage.Blob) string {
	shape := 16.0 / 9
	if b.Width > 0 && b.Height > 0 {
		shape = float64(b.Width) / float64(b.Height)
	}
	stacked := max(1, shape/(16.0/9)) * 100
	return fmt.Sprintf("(max-width: 1080px) %.0fvw, max(80vw, 560px * %.4g)", stacked, shape)
}

// pad2 is a 1-based position as two digits: 1 is "01".
func pad2(n int) string { return fmt.Sprintf("%02d", n) }

// memberCode is the Nth member's code: 1 is "A1".
func memberCode(n int) string { return fmt.Sprintf("A%d", n) }
