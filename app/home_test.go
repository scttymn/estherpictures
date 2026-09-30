package app_test

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/scttymn/gantry/testkit"

	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
)

func get(t *testing.T, h http.Handler, host, path string) *httptest.ResponseRecorder {
	t.Helper()
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", path, nil)
	r.Host = host
	r.Header.Set("Accept", "text/html")
	h.ServeHTTP(w, r)
	return w
}

// The home page shows the site copy, the craft, the clips and the cast, the
// first clip playing muted.
func TestHome(t *testing.T) {
	h := handler(t)
	page := testkit.Browser(t, h).Get("/")
	if page.Code != http.StatusOK {
		t.Fatalf("GET / = %d", page.Code)
	}
	for sel, want := range map[string]string{
		".ep-nav__brand":                                "ESTHER PICTURES",
		".ep-nav__tag":                                  "AN INDEPENDENT FILM COLLECTIVE — NY / LA",
		".ep-nav__links a:first-child":                  "01 CLIPS",
		".ep-reel__title":                               "Films that trust\nthe audience.",
		"#reel-slate [data-slot=title]":                 "The Quiet Coast",
		"#reel-slate [data-slot=status]":                "● NOW PLAYING",
		".ep-clip.is-active .ep-clip__label":            "CLIP 01 · THE QUIET COAST",
		".ep-craft__cell:first-child .ep-craft__num":    "01",
		".ep-craft__cell:nth-child(4) .ep-craft__title": "Post & Craft",
		".ep-ensemble .ep-member__code":                 "A1A2A3",
		".ep-contact__heading":                          "Let's make\nsomething.",
		".ep-footer":                                    "© 2026 ESTHER PICTURES — INDEPENDENT FILM COLLECTIVE",
	} {
		if got := page.Text(sel); got != want {
			t.Errorf("%s: %q, want %q", sel, got, want)
		}
	}
	// Nothing plays until a tap: the first clip's player is loaded paused,
	// with sound, and a tap on Play plays it.
	if src, _ := page.Find("#reel-yt").Attr("src"); !strings.HasPrefix(src, "https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w?") || !strings.Contains(src, "autoplay=0") || !strings.Contains(src, "mute=0") {
		t.Errorf("the first clip's player: %q", src)
	}
	if page.Text("#reel-play") != "PLAY" {
		t.Errorf("the button: %q", page.Text("#reel-play"))
	}
	if src := page.Find(".ep-clip").First().AttrOr("data-src", ""); !strings.Contains(src, "autoplay=1") || !strings.Contains(src, "mute=0") {
		t.Errorf("a clip, picked, plays with sound: %q", src)
	}
	// The player waits for the page (site.js puts it in after load), so
	// YouTube's megabytes don't hold up the first paint.
	if page.Find("template#reel-embed #reel-yt").Length() != 1 || page.Find("#reel-player > iframe").Length() != 0 {
		t.Error("the player is in the page from the start")
	}
	if page.Find(".ep-reel__poster").Length() != 0 {
		t.Error("a poster, with no thumbnail")
	}
	clip := page.Find(".ep-clip").First()
	if id, _ := clip.Attr("data-yt-id"); id != "bFcu0Rn1d7w" {
		t.Errorf("data-yt-id %q", id)
	}
	if _, ok := page.Find(".ep-clip").Eq(1).Attr("data-yt-id"); ok {
		t.Error("a clip that isn't on YouTube has no data-yt-id")
	}
	if kind, _ := page.Find(".ep-clip").Eq(1).Attr("data-kind"); kind != "none" {
		t.Errorf("a clip with no video: %q", kind)
	}
	if page.Find(".ep-reel__placeholder").Length() != 0 {
		t.Error("NO CLIP SET, with a clip set")
	}
	// Every stylesheet, font and script the page refers to loads.
	testkit.Links(t, h, testkit.Page{Path: "/"})
}

// With no clips, the hero says so, and there's no sound button.
func TestHomeWithoutClips(t *testing.T) {
	a := newApp(t, nil)
	a.DB.Write.Exec(`DELETE FROM clips`)
	page := testkit.Browser(t, a.Handler()).Get("/")
	if page.Text(".ep-reel__placeholder") != "NO CLIP SET" {
		t.Error("no placeholder")
	}
	if _, hidden := page.Find("#reel-play").Attr("hidden"); !hidden {
		t.Error("a play button with nothing to play")
	}
}

// A member with a bio opens to show it, and their headshot; one without is
// a plain row. A clip's thumbnail is drawn at every width it comes in.
func TestHomeCastAndImages(t *testing.T) {
	a := newApp(t, nil)
	a.DB.Write.Exec(`DELETE FROM ensemble_members`)
	q := models.New(a.DB.Write)
	withBio, _ := q.CreateEnsembleMember(ctx, models.CreateEnsembleMemberParams{Position: 1, Name: "Michael Joiner", Role: "FOUNDER / ACTOR", SinceYear: "1991", Bio: "A lifelong student of the craft.", Now: "2026-09-30 00:00:00+00:00"})
	without, _ := q.CreateEnsembleMember(ctx, models.CreateEnsembleMemberParams{Position: 2, Name: "Mara Vance", Role: "WRITER-DIRECTOR", SinceYear: "2019", Now: "2026-09-30 00:00:00+00:00"})
	if _, err := a.Storage.Attach(ctx, content.Headshot(withBio), storageFile("michael.jpg", picture(t, 300, 400))); err != nil {
		t.Fatal(err)
	}
	if _, err := a.Storage.Attach(ctx, content.Thumbnail(1), storageFile("still.jpg", picture(t, 640, 360))); err != nil {
		t.Fatal(err)
	}
	a.Storage.Wait()
	h := a.Handler()
	page := testkit.Browser(t, h).Get("/")
	member := page.Find("details#cast-member-" + itoa(withBio))
	if member.Length() != 1 || !strings.Contains(member.Text(), "A lifelong student of the craft.") || !strings.Contains(member.Text(), "Show Bio") {
		t.Fatalf("the member with a bio: %s", page.Body)
	}
	if shot := member.Find("img.ep-member__headshot"); shot.Length() != 1 || shot.AttrOr("alt", "") != "Michael Joiner" || !strings.Contains(shot.AttrOr("srcset", ""), "/storage/") {
		t.Errorf("the headshot: %v", shot.Nodes)
	}
	if page.Find("#cast-member-"+itoa(without)).Length() != 0 || !strings.Contains(page.Text(".ep-ensemble"), "Mara Vance") {
		t.Error("a member with no bio is a plain row")
	}
	if page.Find("img.ep-member__headshot").Length() != 1 {
		t.Error("one headshot")
	}
	poster := page.Find("#reel-player img.ep-reel__poster")
	if poster.Length() != 1 || poster.AttrOr("fetchpriority", "") != "high" || poster.AttrOr("loading", "") != "eager" ||
		poster.AttrOr("sizes", "") != "(max-width: 1080px) 100vw, max(80vw, 560px * 1.778)" {
		t.Errorf("the first clip's thumbnail is the hero's poster, fetched first: %v", poster.Nodes)
	}
	thumb := page.Find(".ep-clip").First().Find("img.ep-clip__thumb")
	if thumb.Length() != 1 || thumb.AttrOr("width", "") != "640" || !strings.Contains(thumb.AttrOr("srcset", ""), "320w") {
		t.Errorf("the thumbnail: %s", page.Find(".ep-clip").First().Text())
	}
	testkit.Links(t, h, testkit.Page{Path: "/"})
}

func TestApex(t *testing.T) {
	h := handler(t)
	w := get(t, h, "www.estherpictures.com", "/?a=1")
	if w.Code != http.StatusMovedPermanently || w.Header().Get("Location") != "https://estherpictures.com/?a=1" {
		t.Errorf("www: %d %q", w.Code, w.Header().Get("Location"))
	}
	if w := get(t, h, "www.estherpictures.com", "/up"); w.Code != http.StatusOK {
		t.Errorf("a health check on www: %d", w.Code)
	}
	if w := get(t, h, "estherpictures.com", "/"); w.Code != http.StatusOK {
		t.Errorf("the apex: %d", w.Code)
	}
}

func TestErrorPages(t *testing.T) {
	w := get(t, handler(t), "estherpictures.com", "/no-such-page")
	if w.Code != http.StatusNotFound || !strings.Contains(w.Body.String(), "doesn't exist") {
		t.Fatalf("a missing page = %d\n%s", w.Code, w.Body)
	}
}
