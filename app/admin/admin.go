// Package admin is the admin's shell: who's signed in and what they may
// do, the layout its pages are drawn in, and the pieces its forms share.
// Each part of it is a package beside this one (clips, users, history...).
package admin

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/auth"
	"github.com/scttymn/gantry/db"
	"github.com/scttymn/gantry/storage"
	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
)

// Controller is what the admin's pages share.
type Controller struct {
	DB      *db.DB
	Auth    *auth.Auth
	Content *content.Content
	Storage *storage.Storage
	Flash   web.Flash
	Clock   func() time.Time // time.Now when nil; tests set it
}

// Now is the time, as the tables keep it.
func (c Controller) Now() string {
	if c.Clock != nil {
		return models.Stamp(c.Clock())
	}
	return models.Stamp(time.Now())
}

// userKey is the signed-in user, with their role, in Current.
var userKey = web.NewKey[models.GetUserRow]("admin.user")

// User is the signed-in user of a request past LoadUser.
func User(r *http.Request) models.GetUserRow {
	u, _ := web.Get(r, userKey)
	return u
}

// LoadUser reads the signed-in user's role and whether they must choose a
// password, after auth's Required: every admin page's first filter.
func (c Controller) LoadUser(w http.ResponseWriter, r *http.Request) error {
	signedIn, ok := auth.Current(r)
	if !ok {
		return web.NotFound
	}
	u, err := models.New(c.DB.Read).GetUser(r.Context(), signedIn.ID)
	if err != nil {
		return err
	}
	web.Set(r, userKey, u)
	return nil
}

// PasswordChosen sends someone who signed in with a temporary password to
// choose their own before anything else.
func (c Controller) PasswordChosen(w http.ResponseWriter, r *http.Request) error {
	if User(r).MustChange() {
		c.Flash.Redirect(w, r, "/admin/change-password", "alert", "Please choose a new password before continuing.")
	}
	return nil
}

// AdminsOnly keeps editors out of the users and the history.
func (c Controller) AdminsOnly(w http.ResponseWriter, r *http.Request) error {
	if !User(r).IsAdmin() {
		c.Flash.Redirect(w, r, "/admin", "alert", "That area is restricted to administrators.")
	}
	return nil
}

// Page is the layout's settings for a request: its title, who's signed in,
// and the flash, taken.
type Page struct {
	Title         string
	User          models.GetUserRow
	SignedIn      bool
	Notice, Alert string
	// Password is a temporary password to show once: the users page's,
	// after an invite or a reset.
	Password *TempPassword
}

// TempPassword is a new temporary password, for the admin to send on.
type TempPassword struct {
	Password, Email string
	Reset           bool // a reset; otherwise a new account
}

// PasswordFlash is the flash kind that carries a TempPassword.
const PasswordFlash = "password"

// SetPassword puts a temporary password in the flash for the next page.
func (c Controller) SetPassword(w http.ResponseWriter, r *http.Request, p TempPassword) {
	data, _ := json.Marshal(p)
	c.Flash.Set(w, r, PasswordFlash, string(data))
}

// Page is this request's layout settings, the flash taken.
func (c Controller) Page(w http.ResponseWriter, r *http.Request, title string) Page {
	p := Page{Title: title, User: User(r)}
	p.SignedIn = p.User.ID != 0
	if kind, msg, ok := c.Flash.Take(w, r); ok {
		switch kind {
		case "alert":
			p.Alert = msg
		case PasswordFlash:
			var tp TempPassword
			if json.Unmarshal([]byte(msg), &tp) == nil {
				p.Password = &tp
			}
		default:
			p.Notice = msg
		}
	}
	return p
}

// Render draws a page in the admin's layout.
func (c Controller) Render(w http.ResponseWriter, r *http.Request, status int, title string, page func(Page) templ.Component) error {
	return web.Render(w, r, status, page(c.Page(w, r, title)))
}

// Notice and Alert go to a page with a message.
func (c Controller) Notice(w http.ResponseWriter, r *http.Request, to, msg string) {
	c.Flash.Redirect(w, r, to, "notice", msg)
}

func (c Controller) Alert(w http.ResponseWriter, r *http.Request, to, msg string) {
	c.Flash.Redirect(w, r, to, "alert", msg)
}

// Views are the sign-in page in the admin's plain layout, for gantry's
// auth, which took the flash already.
func (c Controller) Views() auth.Views {
	return auth.Views{
		Login: func(w http.ResponseWriter, r *http.Request, a auth.Page) error {
			p := Page{Title: "Log in", Notice: a.Notice, Alert: a.Alert}
			return web.Render(w, r, http.StatusOK, Login(p, a.Paths.Login))
		},
	}
}
