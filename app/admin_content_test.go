package app_test

import (
	"net/http"
	"strings"
	"testing"

	"github.com/scttymn/gantry/testkit"

	"github.com/scttymn/estherpictures/app/services/content"
)

// The dashboard counts what the site has.
func TestDashboard(t *testing.T) {
	_, _, b := admin(t)
	page := b.Get("/admin")
	if page.Text("h1") != "Welcome, admin@example.com" {
		t.Errorf("h1 %q", page.Text("h1"))
	}
	if got := page.Text(".card .badge"); got != "443" {
		t.Errorf("counts: %q, want craft 4, clips 4, cast 3", got)
	}
}

// Site copy: validated, saved, on the home page, and in the history.
func TestSiteCopy(t *testing.T) {
	_, h, b := admin(t)
	page := b.Get("/admin/settings")
	if page.Find("textarea[name='site_setting[hero_heading]']").Text() != "Films that trust\nthe audience." {
		t.Fatal("the hero heading, line break and all")
	}
	if bad := page.Submit("form.form", map[string]string{"site_setting[collective_name]": " "}); bad.Code != http.StatusUnprocessableEntity || !strings.Contains(bad.Text(".errors"), "Collective name can't be blank") {
		t.Errorf("a blank name: %d", bad.Code)
	}
	page = page.Submit("form.form", map[string]string{"site_setting[tagline]": "NOW IN CHICAGO"})
	if page.Header.Get("Location") != "/admin/settings" || !strings.Contains(page.Follow().Text(".flash--notice"), "Site copy updated.") {
		t.Fatalf("saving: %d", page.Code)
	}
	if got := testkit.Browser(t, h).Get("/").Text(".ep-nav__tag"); got != "NOW IN CHICAGO" {
		t.Errorf("the home page: %q", got)
	}
	history := b.Get("/admin/history")
	if !strings.Contains(history.Text(".history .what"), "Site setting") || !strings.Contains(history.Text(".before"), "AN INDEPENDENT FILM COLLECTIVE") || !strings.Contains(history.Text(".after"), "NOW IN CHICAGO") {
		t.Errorf("the history: %s", history.Text(".history"))
	}
}

// Craft: added, edited and deleted, each change in the history; a deleted
// one comes back, under its id.
func TestCraft(t *testing.T) {
	a, _, b := admin(t)
	page := b.Get("/admin/craft/new")
	if bad := page.Submit("form.form", map[string]string{"craft_service[title]": ""}); bad.Code != http.StatusUnprocessableEntity || !strings.Contains(bad.Text(".errors"), "Title can't be blank") {
		t.Errorf("no title: %d", bad.Code)
	}
	if bad := page.Submit("form.form", map[string]string{"craft_service[title]": "X", "craft_service[position]": "two"}); bad.Code != http.StatusUnprocessableEntity || !strings.Contains(bad.Text(".errors"), "Position is invalid") {
		t.Errorf("a position that isn't a number: %d", bad.Code)
	}
	page = page.Submit("form.form", map[string]string{"craft_service[title]": "Scoring", "craft_service[position]": "5", "craft_service[description]": "Music."})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Service added.") {
		t.Fatalf("adding: %d %s", page.Code, page.Text(".errors"))
	}
	var id int64
	a.DB.Read.QueryRow(`SELECT id FROM craft_services WHERE title = 'Scoring'`).Scan(&id)
	page = b.Get("/admin/craft/"+itoa(id)+"/edit").Submit("form.form", map[string]string{"craft_service[title]": "Score"})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Service updated.") {
		t.Fatalf("editing: %d", page.Code)
	}
	list := b.Get("/admin/craft")
	del := list.Find("form[action='/admin/craft/" + itoa(id) + "']")
	if del.AttrOr("data-turbo-confirm", "") != "Delete “Score”?" {
		t.Errorf("the delete button: %q", del.AttrOr("data-turbo-confirm", ""))
	}
	page = b.Post("/admin/craft/"+itoa(id), map[string][]string{"_method": {"delete"}})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Service removed.") || strings.Contains(b.Get("/admin/craft").Text("tbody"), "Score") {
		t.Fatalf("deleting: %d", page.Code)
	}
	history := b.Get("/admin/history")
	first := history.Find(".history details").First()
	if !strings.Contains(first.Text(), "Craft service") || !strings.Contains(first.Text(), "deleted") || !strings.Contains(first.Text(), "Score") || !strings.Contains(first.Text(), "admin@example.com") {
		t.Fatalf("the deletion: %s", first.Text())
	}
	restore := first.Find("form[action$='/restore']")
	if restore.AttrOr("data-turbo-confirm", "") != "Bring back this craft service?" {
		t.Errorf("bring back: %q", restore.AttrOr("data-turbo-confirm", ""))
	}
	page = b.Post(restore.AttrOr("action", ""), nil).Follow()
	if !strings.Contains(page.Text(".flash--notice"), "Restored craft service.") {
		t.Fatalf("restoring: %q", page.Text(".flash"))
	}
	var title string
	a.DB.Read.QueryRow(`SELECT title FROM craft_services WHERE id = ?`, id).Scan(&title)
	if title != "Score" {
		t.Errorf("brought back as %q, under its id", title)
	}
	// The edit's entry: title before and after, and a revert.
	edit := history.Find(".history details").Eq(1)
	if edit.Find(".before").Text() != "Scoring" || edit.Find(".after").Text() != "Score" {
		t.Errorf("the edit: %s", edit.Text())
	}
	b.Post(edit.Find("form[action$='/restore']").AttrOr("action", ""), nil)
	a.DB.Read.QueryRow(`SELECT title FROM craft_services WHERE id = ?`, id).Scan(&title)
	if title != "Scoring" {
		t.Errorf("reverted to %q", title)
	}
}

// A clip's thumbnail: checked, attached, replaced (the old one kept while
// the history names it), restored with a revert, and swept once nothing
// names it.
func TestClipThumbnail(t *testing.T) {
	a, h, b := admin(t)
	page := b.Get("/admin/clips/new")
	bad := page.SubmitFiles("form.form", map[string]string{"clip[title]": "Dusk"}, map[string]testkit.Upload{"clip[thumbnail]": {Filename: "notes.txt", Data: []byte("not a picture")}})
	if bad.Code != http.StatusUnprocessableEntity || !strings.Contains(bad.Text(".errors"), "Thumbnail must be a JPG, PNG, WebP, or GIF image.") {
		t.Errorf("a file that isn't a picture: %d %s", bad.Code, bad.Text(".errors"))
	}
	big := append(picture(t, 16, 16), make([]byte, 5<<20)...) // a JPEG, and then some
	if tooBig := page.SubmitFiles("form.form", map[string]string{"clip[title]": "Dusk"}, map[string]testkit.Upload{"clip[thumbnail]": {Filename: "big.jpg", Data: big}}); tooBig.Code != http.StatusUnprocessableEntity || !strings.Contains(tooBig.Text(".errors"), "5 MB or smaller") {
		t.Errorf("a file over 5 MB: %d %s", tooBig.Code, tooBig.Text(".errors"))
	}
	page = page.SubmitFiles("form.form", map[string]string{"clip[title]": "Dusk", "clip[position]": "5", "clip[video_url]": "https://vimeo.com/76979871"},
		map[string]testkit.Upload{"clip[thumbnail]": {Filename: "dusk.jpg", Data: picture(t, 640, 360)}})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Clip added.") {
		t.Fatalf("adding: %d %s", page.Code, page.Text(".errors"))
	}
	var id int64
	a.DB.Read.QueryRow(`SELECT id FROM clips WHERE title = 'Dusk'`).Scan(&id)
	first, ok, _ := a.Storage.Find(ctx, content.Thumbnail(id))
	if !ok || first.Filename != "dusk.jpg" {
		t.Fatalf("attached: %+v", first)
	}
	a.Storage.Wait()
	if list := b.Get("/admin/clips"); list.Find("tbody tr .thumb img").Length() != 1 {
		t.Error("the list shows the thumbnail")
	}
	home := testkit.Browser(t, h).Get("/")
	if home.Find(".ep-clip img.ep-clip__thumb").Length() != 1 {
		t.Error("the home page shows the thumbnail")
	}
	if kind := home.Find(".ep-clip").Eq(4).AttrOr("data-kind", ""); kind != "vimeo" {
		t.Errorf("a Vimeo clip: %q", kind)
	}

	edit := b.Get("/admin/clips/" + itoa(id) + "/edit")
	if edit.Find(".current img").Length() != 1 || !strings.Contains(edit.Text(".hint"), "Uploading a new image replaces the current one.") {
		t.Error("the form shows the current thumbnail")
	}
	page = edit.SubmitFiles("form.form", nil, map[string]testkit.Upload{"clip[thumbnail]": {Filename: "dawn.png", Data: picture(t, 320, 180)}})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Clip updated.") {
		t.Fatalf("replacing: %d %s", page.Code, page.Text(".errors"))
	}
	now, _, _ := a.Storage.Find(ctx, content.Thumbnail(id))
	if now.Filename != "dawn.png" {
		t.Errorf("the new thumbnail: %+v", now)
	}
	if loose, _ := a.Storage.Unattached(ctx); len(loose) != 1 || loose[0].Key != first.Key {
		t.Errorf("the old one is kept for the history: %+v", loose)
	}
	history := b.Get("/admin/history")
	entry := history.Find(".history details").First()
	if entry.Find(".before").Text() != "dusk.jpg" || entry.Find(".after").Text() != "dawn.png" {
		t.Errorf("the change, by file name: %s", entry.Text())
	}
	b.Post(entry.Find("form[action$='/restore']").AttrOr("action", ""), nil)
	if back, _, _ := a.Storage.Find(ctx, content.Thumbnail(id)); back.Key != first.Key {
		t.Errorf("reverted to %+v", back)
	}
	// Both are named by a version now; clearing the history leaves the one
	// attached, and sweeps the other.
	page = b.Post("/admin/history", map[string][]string{"_method": {"delete"}}).Follow()
	if !strings.Contains(page.Text(".flash--notice"), "Discarded 2 history entries and deleted 1 unused image.") {
		t.Errorf("clearing: %q", page.Text(".flash"))
	}
	if loose, _ := a.Storage.Unattached(ctx); len(loose) != 0 {
		t.Errorf("left: %+v", loose)
	}
	if _, ok, _ := a.Storage.Find(ctx, content.Thumbnail(id)); !ok {
		t.Error("the attached one went too")
	}
}

// A deleted member comes back with their headshot.
func TestCastHeadshot(t *testing.T) {
	a, _, b := admin(t)
	page := b.Get("/admin/ensemble/new").SubmitFiles("form.form",
		map[string]string{"ensemble_member[name]": "Ada", "ensemble_member[bio]": "Edits.", "ensemble_member[since_year]": "2020"},
		map[string]testkit.Upload{"ensemble_member[headshot]": {Filename: "ada.jpg", Data: picture(t, 300, 400)}})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Member added.") {
		t.Fatalf("adding: %d %s", page.Code, page.Text(".errors"))
	}
	var id int64
	a.DB.Read.QueryRow(`SELECT id FROM ensemble_members WHERE name = 'Ada'`).Scan(&id)
	page = b.Get("/admin/ensemble/"+itoa(id)+"/edit").SubmitFiles("form.form", nil,
		map[string]testkit.Upload{"ensemble_member[headshot]": {Filename: "ada-2.jpg", Data: picture(t, 300, 400)}})
	if !strings.Contains(page.Follow().Text(".flash--notice"), "Member updated.") {
		t.Fatalf("a new headshot: %d %s", page.Code, page.Text(".errors"))
	}
	shot, _, _ := a.Storage.Find(ctx, content.Headshot(id))
	if shot.Filename != "ada-2.jpg" {
		t.Errorf("the new headshot: %+v", shot)
	}
	b.Post("/admin/ensemble/"+itoa(id), map[string][]string{"_method": {"delete"}})
	if _, ok, _ := a.Storage.Find(ctx, content.Headshot(id)); ok {
		t.Error("a deleted member keeps their headshot attached")
	}
	history := b.Get("/admin/history")
	entry := history.Find(".history details").First()
	if !strings.Contains(entry.Text(), "Cast member") || !strings.Contains(entry.Find(".before").Text(), "ada-2.jpg") {
		t.Errorf("the deletion: %s", entry.Text())
	}
	b.Post(entry.Find("form[action$='/restore']").AttrOr("action", ""), nil)
	if back, ok, _ := a.Storage.Find(ctx, content.Headshot(id)); !ok || back.Key != shot.Key {
		t.Errorf("brought back without the headshot: %+v", back)
	}
}
