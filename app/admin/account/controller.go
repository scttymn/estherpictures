// Package account is a user's own: choosing a password (at
// /admin/change-password, which someone given a temporary one must do
// first), and setting up the first administrator (at /users/register,
// which closes once anyone has an account).
package account

import (
	"database/sql"
	"net/http"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/auth"
	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/models"
)

// Controller is the account's pages.
type Controller struct{ admin.Controller }

// EditPassword is GET /admin/change-password.
func (c Controller) EditPassword(w http.ResponseWriter, r *http.Request) error {
	return c.passwordForm(w, r, http.StatusOK, nil)
}

// UpdatePassword is PUT /admin/change-password: the new password ends
// every session the user had, then signs this browser in again.
func (c Controller) UpdatePassword(w http.ResponseWriter, r *http.Request) error {
	v := web.Sent(r, "user")
	if errs := models.PasswordErrors(v["password"], v["password_confirmation"]); len(errs) > 0 {
		return c.passwordForm(w, r, http.StatusUnprocessableEntity, errs)
	}
	u := admin.User(r)
	if err := c.Auth.SetPassword(r.Context(), u.ID, v["password"]); err != nil {
		return err
	}
	if err := models.New(c.DB.Write).SetMustChangePassword(r.Context(), models.SetMustChangePasswordParams{MustChangePassword: 0, Now: c.Now(), ID: u.ID}); err != nil {
		return err
	}
	signedIn, err := c.Auth.Find(r.Context(), u.ID)
	if err != nil {
		return err
	}
	if _, err := c.Auth.StartSession(w, r, signedIn); err != nil {
		return err
	}
	c.Notice(w, r, "/admin", "Password updated.")
	return nil
}

func (c Controller) passwordForm(w http.ResponseWriter, r *http.Request, status int, errs []string) error {
	forced := admin.User(r).MustChange()
	title := "Change your password"
	if forced {
		title = "Choose a new password"
	}
	return c.Render(w, r, status, title, func(p admin.Page) templ.Component { return passwordForm(p, title, forced, errs) })
}

// Setup is GET /users/register: the first administrator's form, while no
// one has an account.
func (c Controller) Setup(w http.ResponseWriter, r *http.Request) error {
	if done, err := c.closed(w, r); done || err != nil {
		return err
	}
	return c.setupForm(w, r, http.StatusOK, "", nil)
}

// CreateAdmin is POST /users/register.
func (c Controller) CreateAdmin(w http.ResponseWriter, r *http.Request) error {
	if done, err := c.closed(w, r); done || err != nil {
		return err
	}
	v := web.Sent(r, "user")
	email := auth.Normalize(v["email_address"])
	errs := append(models.EmailErrors(email), models.PasswordErrors(v["password"], v["password_confirmation"])...)
	if len(errs) > 0 {
		return c.setupForm(w, r, http.StatusUnprocessableEntity, email, errs)
	}
	digest, err := auth.Hash(v["password"])
	if err != nil {
		return err
	}
	id, err := models.New(c.DB.Write).CreateUser(r.Context(), models.CreateUserParams{EmailAddress: email,
		PasswordDigest: sql.NullString{String: digest, Valid: true}, Role: models.Admin, Now: c.Now()})
	if err != nil {
		return err
	}
	u, err := c.Auth.Find(r.Context(), id)
	if err != nil {
		return err
	}
	if _, err := c.Auth.StartSession(w, r, u); err != nil {
		return err
	}
	c.Notice(w, r, "/admin", "Welcome — your administrator account is ready.")
	return nil
}

// closed sends anyone signed in to the admin, and everyone to sign in once
// the first account is made: done is true when it answered.
func (c Controller) closed(w http.ResponseWriter, r *http.Request) (done bool, err error) {
	if c.Auth.SignedIn(r) {
		web.Redirect(w, r, "/admin")
		return true, nil
	}
	n, err := models.New(c.DB.Read).CountUsers(r.Context())
	if err != nil || n == 0 {
		return false, err
	}
	c.Alert(w, r, "/login", "Registration is closed. Please log in.")
	return true, nil
}

func (c Controller) setupForm(w http.ResponseWriter, r *http.Request, status int, email string, errs []string) error {
	return c.Render(w, r, status, "Set up the site administrator", func(p admin.Page) templ.Component { return setupForm(p, email, errs) })
}
