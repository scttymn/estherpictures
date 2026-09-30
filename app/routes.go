// Package app is the app: every route, and the controllers behind them,
// built from what they depend on.
package app

import (
	"log/slog"
	"net/http"
	"slices"
	"strings"
	"time"

	"github.com/scttymn/gantry/auth"
	"github.com/scttymn/gantry/db"
	"github.com/scttymn/gantry/jobs"
	"github.com/scttymn/gantry/live"
	"github.com/scttymn/gantry/sign"
	"github.com/scttymn/gantry/storage"
	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/admin/account"
	"github.com/scttymn/estherpictures/app/admin/cast"
	"github.com/scttymn/estherpictures/app/admin/clips"
	"github.com/scttymn/estherpictures/app/admin/craft"
	"github.com/scttymn/estherpictures/app/admin/history"
	"github.com/scttymn/estherpictures/app/admin/settings"
	"github.com/scttymn/estherpictures/app/admin/users"
	"github.com/scttymn/estherpictures/app/home"
	"github.com/scttymn/estherpictures/app/services/content"
	"github.com/scttymn/estherpictures/assets"
)

// App is what the controllers share.
type App struct {
	DB     *db.DB
	Log    *slog.Logger
	Signer sign.Signer
	Jobs   *jobs.Queue // the background jobs, defined in app/jobs.go
	Live   *live.Hub
	// Storage is the uploaded images (clips' thumbnails, the cast's
	// headshots), and Content the site's editable content and its history.
	Storage *storage.Storage
	Content *content.Content
	Auth    *auth.Auth
	Limits  web.Limits
	Now     func() time.Time // time.Now when nil; tests set it
}

// Handler is every route, in gantry's middleware.
func (a *App) Handler() http.Handler {
	rt := web.NewRouter(a.Log, nil)
	// Errors are assets/public's pages (404.html, 500.html ...), plain
	// files, so they show even when the app can't draw a page.
	rt.Public = assets.All

	if a.Auth == nil {
		// No mail: an admin resets a password by hand (a temporary one).
		a.Auth = &auth.Auth{DB: a.DB, Signer: a.Signer, Limits: &a.Limits, Log: a.Log, Now: a.Now,
			Paths: auth.Paths{Login: "/login", Logout: "/users/log-out", AfterLogin: "/admin"}}
	}
	adm := admin.Controller{DB: a.DB, Auth: a.Auth, Content: a.Content, Storage: a.Storage, Flash: web.Flash{Signer: a.Signer}, Clock: a.Now}
	a.Auth.Views = adm.Views()
	a.Auth.Routes(rt)

	homePage := home.Controller{DB: a.DB, Storage: a.Storage}
	rt.Handle("GET /{$}", homePage.Show)
	rt.Mount("GET /storage/", a.Storage)

	acct := account.Controller{Controller: adm}
	rt.Handle("GET /users/register", acct.Setup)
	rt.Handle("POST /users/register", acct.CreateAdmin)

	// Signed in: choosing a password, which someone given a temporary one
	// must do before anything else.
	signedIn := web.Pipeline{a.Auth.Required, adm.LoadUser}
	rt.Scope("", signedIn, func(s *web.Scope) {
		s.Handle("GET /admin/change-password", acct.EditPassword)
		s.Handle("PUT /admin/change-password", acct.UpdatePassword)
	})
	// The admin proper: editors and admins.
	editors := append(slices.Clip(signedIn), adm.PasswordChosen)
	rt.Scope("", editors, func(s *web.Scope) {
		s.Handle("GET /admin", adm.Dashboard)
		siteCopy := settings.Controller{Controller: adm}
		s.Handle("GET /admin/settings", siteCopy.Edit)
		s.Handle("PUT /admin/settings", siteCopy.Update)
		s.Handle("PATCH /admin/settings", siteCopy.Update)
		s.Resources("/admin/craft", craft.Controller{Controller: adm}, nil)
		s.Resources("/admin/clips", clips.Controller{Controller: adm}, nil)
		s.Resources("/admin/ensemble", cast.Controller{Controller: adm}, nil)
	})
	// The users and the history: admins only.
	rt.Scope("", append(slices.Clip(editors), adm.AdminsOnly), func(s *web.Scope) {
		people := users.Controller{Controller: adm}
		s.Resources("/admin/users", people, nil)
		s.Handle("POST /admin/users/{id}/reset-password", people.ResetPassword)
		past := history.Controller{Controller: adm}
		s.Handle("GET /admin/history", past.Index)
		s.Handle("POST /admin/history/{id}/restore", past.Restore)
		s.Handle("DELETE /admin/history/{id}", past.Discard)
		s.Handle("DELETE /admin/history", past.Clear)
	})

	assets.Routes(rt.Mount)
	return Apex(rt.Handler())
}

// Apex sends www.<host> to <host>, path and query kept, so the site has one
// address (estherpictures.com). Health checks pass on any host.
func Apex(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if apex, ok := strings.CutPrefix(r.Host, "www."); ok && r.URL.Path != "/up" {
			http.Redirect(w, r, "https://"+apex+r.URL.RequestURI(), http.StatusMovedPermanently)
			return
		}
		next.ServeHTTP(w, r)
	})
}
