package app_test

import (
	"net/http"
	"regexp"
	"strings"
	"testing"

	"github.com/PuerkitoBio/goquery"

	"github.com/scttymn/gantry/testkit"

	"github.com/scttymn/estherpictures/app/models"
)

// Every admin page asks a visitor to sign in, and brings them back after.
func TestSignInRequired(t *testing.T) {
	a := newApp(t, nil)
	h := a.Handler()
	user(t, a, "admin@example.com", "Admin1234", models.Admin, false)
	b := testkit.Browser(t, h)
	for _, path := range []string{"/admin", "/admin/settings", "/admin/clips", "/admin/users", "/admin/history", "/admin/change-password"} {
		if page := b.Get(path); page.Code != http.StatusFound || page.Header.Get("Location") != "/login" {
			t.Errorf("%s signed out: %d %q", path, page.Code, page.Header.Get("Location"))
		}
	}
	b.Get("/admin/clips")
	page := b.Get("/login")
	if page.Find("a[href='/passwords/new']").Length() != 0 {
		t.Error("no reset by email: the app sends none")
	}
	page = page.Submit("form", map[string]string{"email_address": "Admin@Example.com", "password": "Admin1234"})
	if page.Header.Get("Location") != "/admin/clips" {
		t.Errorf("back to where they were going: %q", page.Header.Get("Location"))
	}
	if page := b.Get("/login").Submit("form", map[string]string{"email_address": "admin@example.com", "password": "wrong"}).Follow(); !strings.Contains(page.Text(".flash--alert"), "Try another email address or password.") {
		t.Errorf("a wrong password: %s", page.Text(".flash"))
	}
	// Signing out ends the session.
	page = b.Get("/admin").Submit("form[action='/users/log-out']", nil)
	if page.Code != http.StatusSeeOther {
		t.Fatalf("log out: %d", page.Code)
	}
	if page := b.Get("/admin"); page.Header.Get("Location") != "/login" {
		t.Errorf("signed out, still in: %d", page.Code)
	}
}

// The first account becomes the administrator; then registration closes.
func TestSetup(t *testing.T) {
	h := handler(t)
	b := testkit.Browser(t, h)
	page := b.Get("/users/register")
	if page.Code != http.StatusOK || page.Find("#registration_form").Length() != 1 {
		t.Fatalf("the setup form: %d", page.Code)
	}
	weak := page.Submit("#registration_form", map[string]string{"user[email_address]": "Owner@Example.com", "user[password]": "short", "user[password_confirmation]": "short"})
	if weak.Code != http.StatusUnprocessableEntity || !strings.Contains(weak.Text(".errors"), "at least 7 characters") || !strings.Contains(weak.Text(".errors"), "upper case") {
		t.Errorf("a weak password: %d %s", weak.Code, weak.Text(".errors"))
	}
	page = page.Submit("#registration_form", map[string]string{"user[email_address]": "Owner@Example.com", "user[password]": "Owner1234", "user[password_confirmation]": "Owner1234"})
	if page.Header.Get("Location") != "/admin" {
		t.Fatalf("setting up: %d %s", page.Code, page.Text(".errors"))
	}
	page = page.Follow()
	if page.Text("h1") != "Welcome, owner@example.com" || !strings.Contains(page.Text(".flash--notice"), "administrator account is ready") {
		t.Errorf("the dashboard: %q %q", page.Text("h1"), page.Text(".flash"))
	}
	if page.Find("a[href='/admin/users']").Length() == 0 {
		t.Error("the first account is an admin")
	}
	if page := b.Get("/users/register"); page.Header.Get("Location") != "/admin" {
		t.Errorf("signed in: %q", page.Header.Get("Location"))
	}
	other := testkit.Browser(t, h)
	page = other.Get("/users/register")
	if page.Header.Get("Location") != "/login" || !strings.Contains(page.Follow().Text(".flash--alert"), "Registration is closed") {
		t.Errorf("registration closes: %d %q", page.Code, page.Header.Get("Location"))
	}
	if page := other.Post("/users/register", nil); page.Header.Get("Location") != "/login" {
		t.Errorf("posting to a closed registration: %d", page.Code)
	}
}

// Someone given a temporary password chooses their own before anything
// else; choosing it ends their other sessions.
func TestForcedPasswordChange(t *testing.T) {
	a := newApp(t, nil)
	h := a.Handler()
	user(t, a, "editor@example.com", "5551234", models.Editor, true)
	elsewhere := signIn(t, h, "editor@example.com", "5551234")
	b := signIn(t, h, "editor@example.com", "5551234")
	page := b.Get("/admin")
	if page.Header.Get("Location") != "/admin/change-password" {
		t.Fatalf("a temporary password: %q", page.Header.Get("Location"))
	}
	page = page.Follow()
	if page.Text("h1") != "Choose a new password" || !strings.Contains(page.Text(".flash--alert"), "Please choose a new password") || page.Find(".topnav").Length() != 0 {
		t.Errorf("the forced change: %q %q", page.Text("h1"), page.Text(".flash"))
	}
	if weak := page.Submit("form", map[string]string{"user[password]": "Newpass1", "user[password_confirmation]": "Newpass2"}); weak.Code != http.StatusUnprocessableEntity || !strings.Contains(weak.Text(".errors"), "does not match") {
		t.Errorf("a mismatch: %d %s", weak.Code, weak.Text(".errors"))
	}
	page = page.Submit("form", map[string]string{"user[password]": "Newpass1", "user[password_confirmation]": "Newpass1"})
	if page.Header.Get("Location") != "/admin" || !strings.Contains(page.Follow().Text(".flash--notice"), "Password updated.") {
		t.Fatalf("choosing: %d %q", page.Code, page.Header.Get("Location"))
	}
	if page := b.Get("/admin"); page.Code != http.StatusOK {
		t.Errorf("signed in after choosing: %d", page.Code)
	}
	if page := elsewhere.Get("/admin"); page.Header.Get("Location") != "/login" {
		t.Errorf("another session outlived the change: %d %q", page.Code, page.Header.Get("Location"))
	}
	signIn(t, h, "editor@example.com", "Newpass1")
	if page := testkit.Browser(t, h).Get("/login").Submit("form", map[string]string{"email_address": "editor@example.com", "password": "5551234"}); page.Header.Get("Location") != "/login" {
		t.Errorf("the temporary password still works: %q", page.Header.Get("Location"))
	}
	// Someone who chose theirs may change it again, without being made to.
	if page := b.Get("/admin/change-password"); page.Text("h1") != "Change your password" {
		t.Errorf("a chosen change: %q", page.Text("h1"))
	}
}

// Editors edit the site; the users and the history are admins'.
func TestEditors(t *testing.T) {
	a := newApp(t, nil)
	h := a.Handler()
	user(t, a, "editor@example.com", "Editor123", models.Editor, false)
	b := signIn(t, h, "editor@example.com", "Editor123")
	page := b.Get("/admin")
	if page.Find("a[href='/admin/users']").Length() != 0 || page.Find("a[href='/admin/history']").Length() != 0 {
		t.Error("an editor is shown the users or the history")
	}
	for _, path := range []string{"/admin/users", "/admin/users/new", "/admin/history"} {
		page := b.Get(path)
		if page.Header.Get("Location") != "/admin" || !strings.Contains(page.Follow().Text(".flash--alert"), "restricted to administrators") {
			t.Errorf("%s: %d %q", path, page.Code, page.Header.Get("Location"))
		}
	}
	for _, path := range []string{"/admin/settings", "/admin/craft", "/admin/clips", "/admin/ensemble"} {
		if page := b.Get(path); page.Code != http.StatusOK {
			t.Errorf("%s: %d", path, page.Code)
		}
	}
}

var tempPassword = regexp.MustCompile(`\A\d{7}\z`)

// An admin invites an editor with a temporary password, shown once, resets
// one, and removes one; never themself.
func TestUsers(t *testing.T) {
	a, h, b := admin(t)
	page := b.Get("/admin/users/new").Submit("form.form", map[string]string{"user[email_address]": "New@Example.com", "user[role]": "editor"})
	if page.Header.Get("Location") != "/admin/users" {
		t.Fatalf("inviting: %d %q %s", page.Code, page.Header.Get("Location"), page.Text(".errors"))
	}
	page = page.Follow()
	password := page.Text(".secret code")
	if !tempPassword.MatchString(password) || !strings.Contains(page.Text(".modal h3"), "Account created for new@example.com") {
		t.Fatalf("the temporary password: %q %q", password, page.Text(".modal h3"))
	}
	if again := b.Get("/admin/users"); again.Find(".modal").Length() != 0 {
		t.Error("the password is shown again")
	}
	if !strings.Contains(page.Text("tbody"), "Pending first login") || !strings.Contains(page.Text("tbody"), "you") {
		t.Errorf("the list: %s", page.Text("tbody"))
	}
	invitee := signIn(t, h, "new@example.com", password)
	if page := invitee.Get("/admin"); page.Header.Get("Location") != "/admin/change-password" {
		t.Error("an invitee chooses a password first")
	}
	if dup := b.Get("/admin/users/new").Submit("form.form", map[string]string{"user[email_address]": "new@example.com"}); dup.Code != http.StatusUnprocessableEntity || !strings.Contains(dup.Text(".errors"), "already been taken") {
		t.Errorf("a second account for an email: %d", dup.Code)
	}
	if bad := b.Get("/admin/users/new").Submit("form.form", map[string]string{"user[email_address]": "not an email"}); bad.Code != http.StatusUnprocessableEntity {
		t.Errorf("a bad email: %d", bad.Code)
	}

	id := page.Find("tbody tr").FilterFunction(func(_ int, s *goquery.Selection) bool { return strings.Contains(s.Text(), "new@example.com") })
	reset := id.Find("form[action$='/reset-password']")
	if reset.Length() != 1 || !strings.Contains(reset.AttrOr("data-turbo-confirm", ""), "Reset password for new@example.com?") {
		t.Fatalf("the reset button: %d", reset.Length())
	}
	page = b.Post(reset.AttrOr("action", ""), nil).Follow()
	fresh := page.Text(".secret code")
	if !tempPassword.MatchString(fresh) || fresh == password || !strings.Contains(page.Text(".modal h3"), "Password reset for new@example.com") {
		t.Fatalf("a reset: %q %q", fresh, page.Text(".modal h3"))
	}
	if page := invitee.Get("/admin/change-password"); page.Header.Get("Location") != "/login" {
		t.Error("a reset ends the user's sessions")
	}
	if page := signIn(t, h, "new@example.com", fresh).Get("/admin"); page.Header.Get("Location") != "/admin/change-password" {
		t.Error("after a reset, they choose a password first")
	}

	// Not themself.
	var mine int64
	a.DB.Read.QueryRow(`SELECT id FROM users WHERE email_address = 'admin@example.com'`).Scan(&mine)
	if page.Find("form[action='/admin/users/"+itoa(mine)+"']").Length() != 0 {
		t.Error("a button to remove themself")
	}
	if page := b.Post("/admin/users/"+itoa(mine)+"/reset-password", nil).Follow(); !strings.Contains(page.Text(".flash--alert"), "can't reset your own password") {
		t.Errorf("resetting their own: %q", page.Text(".flash"))
	}
	if page := b.Post("/admin/users/"+itoa(mine), map[string][]string{"_method": {"delete"}}).Follow(); !strings.Contains(page.Text(".flash--alert"), "can't delete your own account") {
		t.Errorf("removing themself: %q", page.Text(".flash"))
	}
	remove := id.Find("form[data-turbo-confirm^='Remove new@example.com?']")
	page = b.Post(remove.AttrOr("action", ""), map[string][]string{"_method": {"delete"}}).Follow()
	if !strings.Contains(page.Text(".flash--notice"), "Removed new@example.com.") || strings.Contains(page.Text("tbody"), "new@example.com") {
		t.Errorf("removing: %q", page.Text(".flash"))
	}
}
