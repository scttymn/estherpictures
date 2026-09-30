package app_test

import (
	"bytes"
	"context"
	"database/sql"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"testing"
	"time"

	"github.com/scttymn/gantry/auth"
	"github.com/scttymn/gantry/db"
	"github.com/scttymn/gantry/jobs"
	"github.com/scttymn/gantry/live"
	"github.com/scttymn/gantry/sign"
	"github.com/scttymn/gantry/storage"
	"github.com/scttymn/gantry/testkit"

	"github.com/scttymn/estherpictures/app"
	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
	"github.com/scttymn/estherpictures/db/seeds"
	"github.com/scttymn/estherpictures/test"
)

var ctx = context.Background()

// newApp is the app on d (a new, seeded test database when nil), its
// images kept in a folder of the test's, made in this process, as WebP.
func newApp(t *testing.T, d *db.DB) *app.App {
	t.Helper()
	if d == nil {
		d = test.DB(t)
		if err := seeds.Run(ctx, d); err != nil {
			t.Fatal(err)
		}
	}
	q, err := jobs.New(ctx, d, jobs.Options{})
	if err != nil {
		t.Fatal(err)
	}
	signer := sign.Signer{Key: []byte("test-key")}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	st := &storage.Storage{DB: d, Root: t.TempDir(), NoAVIF: true, Log: log}
	t.Cleanup(st.Wait)
	a := &app.App{DB: d, Log: log, Signer: signer, Jobs: q, Live: live.New(signer, live.Options{}),
		Storage: st, Content: &content.Content{DB: d, Storage: st, Log: log}}
	if err := a.DefineJobs(); err != nil {
		t.Fatal(err)
	}
	return a
}

func handler(t *testing.T) http.Handler { return newApp(t, nil).Handler() }

// user adds someone who can sign in; mustChange is a temporary password.
func user(t *testing.T, a *app.App, email, password, role string, mustChange bool) int64 {
	t.Helper()
	digest, err := auth.Hash(password)
	if err != nil {
		t.Fatal(err)
	}
	var must int64
	if mustChange {
		must = 1
	}
	id, err := models.New(a.DB.Write).CreateUser(ctx, models.CreateUserParams{EmailAddress: email,
		PasswordDigest: sql.NullString{String: digest, Valid: true}, Role: role, MustChangePassword: must, Now: models.Stamp(time.Now())})
	if err != nil {
		t.Fatal(err)
	}
	return id
}

// signIn is a browser signed in as email.
func signIn(t *testing.T, h http.Handler, email, password string) *testkit.Visitor {
	t.Helper()
	b := testkit.Browser(t, h)
	page := b.Get("/login").Submit("form", map[string]string{"email_address": email, "password": password})
	if page.Code != http.StatusFound || page.Header.Get("Location") != "/admin" {
		t.Fatalf("signing in as %s: %d %v", email, page.Code, page.Header.Get("Location"))
	}
	return b
}

// admin is the app, and a browser signed in as its administrator.
func admin(t *testing.T) (*app.App, http.Handler, *testkit.Visitor) {
	t.Helper()
	a := newApp(t, nil)
	h := a.Handler()
	user(t, a, "admin@example.com", "Admin1234", models.Admin, false)
	return a, h, signIn(t, h, "admin@example.com", "Admin1234")
}

// picture is a JPEG this size.
func picture(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for x := range w {
		for y := range h {
			img.Set(x, y, color.RGBA{uint8(x), uint8(y), 120, 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, nil); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func storageFile(name string, data []byte) storage.File {
	return storage.File{Filename: name, Data: data}
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }
