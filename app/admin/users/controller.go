// Package users is who may use the admin, at /admin/users: admins invite
// editors (or admins) with a temporary password, reset one, or remove
// someone.
package users

import (
	"crypto/rand"
	"database/sql"
	"errors"
	"math/big"
	"net/http"
	"strings"

	"github.com/a-h/templ"

	"github.com/scttymn/gantry/auth"
	"github.com/scttymn/gantry/web"

	"github.com/scttymn/estherpictures/app/admin"
	"github.com/scttymn/estherpictures/app/models"
)

const (
	path  = "/admin/users"
	param = "user"
)

// Controller is the users' list, the invite, a reset, and removing.
type Controller struct{ admin.Controller }

func (c Controller) Index(w http.ResponseWriter, r *http.Request) error {
	list, err := models.New(c.DB.Read).ListUsers(r.Context())
	if err != nil {
		return err
	}
	return c.Render(w, r, http.StatusOK, "Users", func(p admin.Page) templ.Component { return index(p, list) })
}

func (c Controller) New(w http.ResponseWriter, r *http.Request) error {
	return c.form(w, r, http.StatusOK, "", models.Editor, nil)
}

// Create is POST /admin/users: an account with a temporary password, shown
// once, to be changed at its first sign-in.
func (c Controller) Create(w http.ResponseWriter, r *http.Request) error {
	v := web.Sent(r, param)
	email, role := auth.Normalize(v["email_address"]), v["role"]
	if role != models.Admin {
		role = models.Editor
	}
	errs := models.EmailErrors(email)
	if len(errs) == 0 {
		if _, err := c.Auth.FindByEmail(r.Context(), email); err == nil {
			errs = append(errs, "Email has already been taken")
		} else if !errors.Is(err, auth.ErrNoUser) {
			return err
		}
	}
	if len(errs) > 0 {
		return c.form(w, r, http.StatusUnprocessableEntity, email, role, errs)
	}
	password := TempPassword()
	digest, err := auth.Hash(password)
	if err != nil {
		return err
	}
	if _, err := models.New(c.DB.Write).CreateUser(r.Context(), models.CreateUserParams{EmailAddress: email,
		PasswordDigest: sql.NullString{String: digest, Valid: true}, Role: role, MustChangePassword: 1, Now: c.Now()}); err != nil {
		return err
	}
	c.SetPassword(w, r, admin.TempPassword{Password: password, Email: email})
	web.Redirect(w, r, path)
	return nil
}

// ResetPassword is POST /admin/users/{id}/reset-password: a new temporary
// password, and every session the user had ends.
func (c Controller) ResetPassword(w http.ResponseWriter, r *http.Request) error {
	u, err := models.New(c.DB.Read).GetUser(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	if u.ID == admin.User(r).ID {
		c.Alert(w, r, path, "You can't reset your own password this way. Use Change password instead.")
		return nil
	}
	password := TempPassword()
	if err := c.Auth.SetPassword(r.Context(), u.ID, password); err != nil {
		return err
	}
	if err := models.New(c.DB.Write).SetMustChangePassword(r.Context(), models.SetMustChangePasswordParams{MustChangePassword: 1, Now: c.Now(), ID: u.ID}); err != nil {
		return err
	}
	c.SetPassword(w, r, admin.TempPassword{Password: password, Email: u.EmailAddress, Reset: true})
	web.Redirect(w, r, path)
	return nil
}

func (c Controller) Delete(w http.ResponseWriter, r *http.Request) error {
	u, err := models.New(c.DB.Read).GetUser(r.Context(), web.ID(r, "id"))
	if err != nil {
		return err
	}
	if u.ID == admin.User(r).ID {
		c.Alert(w, r, path, "You can't delete your own account.")
		return nil
	}
	if err := models.New(c.DB.Write).DeleteUser(r.Context(), u.ID); err != nil {
		return err
	}
	c.Notice(w, r, path, "Removed "+u.EmailAddress+".")
	return nil
}

func (c Controller) form(w http.ResponseWriter, r *http.Request, status int, email, role string, errs []string) error {
	return c.Render(w, r, status, "Invite editor", func(p admin.Page) templ.Component { return form(p, email, role, errs) })
}

// TempPassword is seven random digits: easy to read out, and good for the
// one sign-in before its owner chooses their own.
func TempPassword() string {
	var b strings.Builder
	for range 7 {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			panic(err)
		}
		b.WriteByte(byte('0' + n.Int64()))
	}
	return b.String()
}
