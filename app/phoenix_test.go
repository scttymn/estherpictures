package app_test

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/PuerkitoBio/goquery"

	"github.com/scttymn/gantry/db"
	"github.com/scttymn/gantry/testkit"

	"github.com/scttymn/estherpictures/app/services/content"
	"github.com/scttymn/estherpictures/db/migrations"
	"github.com/scttymn/estherpictures/db/seeds"
)

// phoenix is a copy of a database the Phoenix app made (test/phoenix: its
// migrations, its seeds, then an admin, an editor with a temporary
// password, a clip whose thumbnail was replaced, a member's headshot and
// bio, an edited service and a deleted one, all through its own code), with
// its uploads, brought up to date as a deploy does.
func phoenix(t *testing.T) (d *db.DB, uploads string) {
	t.Helper()
	dir := t.TempDir()
	data, err := os.ReadFile("../test/phoenix/esther_pictures.db")
	if err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dir, "esther_pictures.db"), data, 0o644)
	if err := os.CopyFS(filepath.Join(dir, "uploads"), os.DirFS("../test/phoenix/uploads")); err != nil {
		t.Fatal(err)
	}
	d, err = db.Open(ctx, "sqlite://"+filepath.Join(dir, "esther_pictures.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
	if err := migrations.Up(ctx, d); err != nil {
		t.Fatal(err)
	}
	if err := seeds.Run(ctx, d); err != nil {
		t.Fatal(err)
	}
	return d, filepath.Join(dir, "uploads")
}

// Moved from Phoenix, the site and its admin carry on: the same content,
// passwords that still work, the uploads in storage, and the history,
// images and all.
func TestFromPhoenix(t *testing.T) {
	d, uploads := phoenix(t)
	a := newApp(t, d)
	moved, err := a.Content.ImportUploads(ctx, uploads)
	if err != nil || moved != 3 {
		t.Fatalf("moved %d uploads (%v), want the two thumbnails and the headshot", moved, err)
	}
	if _, err := os.Stat(uploads); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("the uploads folder stays: %v", err)
	}
	if again, err := a.Content.ImportUploads(ctx, uploads); again != 0 || err != nil {
		t.Errorf("moving again moved %d (%v)", again, err)
	}
	var paths int
	d.Read.QueryRow(`SELECT (SELECT count(*) FROM clips WHERE thumbnail_path <> '') + (SELECT count(*) FROM ensemble_members WHERE headshot_path <> '')`).Scan(&paths)
	if paths != 0 {
		t.Errorf("%d upload paths left", paths)
	}
	a.Storage.Wait()
	h := a.Handler()

	// Every time the Phoenix app wrote is as gantry writes one, so a column
	// sorts in time order whichever app wrote a row.
	for _, column := range []string{"users.created_at", "users.updated_at", "site_settings.updated_at", "clips.created_at", "clips.updated_at",
		"craft_services.updated_at", "ensemble_members.updated_at", "content_versions.created_at"} {
		table, col, _ := strings.Cut(column, ".")
		var odd int
		d.Read.QueryRow(`SELECT count(*) FROM ` + table + ` WHERE ` + col + ` NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]+00:00'`).Scan(&odd)
		if odd != 0 {
			t.Errorf("%s: %d rows in another format", column, odd)
		}
	}

	// The site: the seeds left alone, the edits kept, the images drawn.
	home := testkit.Browser(t, h).Get("/")
	if got := home.Text("#reel-slate [data-slot=title]"); got != "The Quiet Coast (cut)" {
		t.Errorf("the first clip: %q", got)
	}
	if home.Find(".ep-clip").First().Find("img.ep-clip__thumb").Length() != 1 {
		t.Error("the clip's thumbnail")
	}
	member := home.Find("details.ep-member").First()
	if !strings.Contains(member.Text(), "Founded the collective.") || member.Find("img.ep-member__headshot").Length() != 1 {
		t.Errorf("the member's bio and headshot: %s", member.Text())
	}
	if strings.Contains(home.Text(".ep-craft"), "Directing") || !strings.Contains(home.Text(".ep-craft"), "Screenplays, developed in-house.") {
		t.Errorf("the craft: %s", home.Text(".ep-craft"))
	}
	testkit.Links(t, h, testkit.Page{Path: "/"})

	// Phoenix's bcrypt hashes sign in; its email, lowercased.
	b := signIn(t, h, "admin@example.com", "Admin1234")
	editor := signIn(t, h, "editor@example.com", "5551234")
	if page := editor.Get("/admin"); page.Header.Get("Location") != "/admin/change-password" {
		t.Error("the editor's temporary password still has to be changed")
	}

	// The history: every version, dated, with the thumbnail's change by
	// its file.
	history := b.Get("/admin/history")
	entries := history.Find(".history details")
	if entries.Length() != 6 {
		t.Fatalf("%d entries, want Phoenix's 6", entries.Length())
	}
	if when := entries.First().Find(".when").Text(); !strings.Contains(when, "2026") {
		t.Errorf("dated %q", when)
	}
	var replaced, deleted, early = -1, -1, -1
	entries.Each(func(i int, s *goquery.Selection) {
		switch {
		case strings.Contains(s.Find(".before").Text(), "NyMoyrb3YLeyiR7ZQyurbQ.jpg"):
			replaced = i
		case strings.Contains(s.Text(), "Directing") && strings.Contains(s.Text(), "deleted"):
			deleted = i
		case strings.Contains(s.Text(), "Site setting"):
			early = i
		}
	})
	if replaced < 0 || deleted < 0 || early < 0 {
		t.Fatalf("entries: replaced %d, deleted %d, the seeds' %d\n%s", replaced, deleted, early, history.Text(".history"))
	}
	if after := entries.Eq(replaced).Find(".after").Text(); !strings.Contains(after, "yczV_DdYpj-FGGRccsOYew.jpg") {
		t.Errorf("the thumbnail after: %q", after)
	}
	// Revert the thumbnail's change: the first one back.
	b.Post(entries.Eq(replaced).Find("form[action$='/restore']").AttrOr("action", ""), nil)
	if back, _, _ := a.Storage.Find(ctx, content.Thumbnail(1)); back.Filename != "NyMoyrb3YLeyiR7ZQyurbQ.jpg" {
		t.Errorf("reverted to %+v", back)
	}
	// Bring back the deleted service.
	b.Post(entries.Eq(deleted).Find("form[action$='/restore']").AttrOr("action", ""), nil)
	if !strings.Contains(testkit.Browser(t, h).Get("/").Text(".ep-craft"), "Directing") {
		t.Error("Directing isn't back")
	}
	// The seeds' version holds one field: reverting it writes that alone.
	b.Post(entries.Eq(early).Find("form[action$='/restore']").AttrOr("action", ""), nil)
	if tag := testkit.Browser(t, h).Get("/").Text(".ep-nav__tag"); tag != "AN INDEPENDENT FILM COLLECTIVE — NY / LA" {
		t.Errorf("the tagline after reverting an early version: %q", tag)
	}
}
