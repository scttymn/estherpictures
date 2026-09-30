package content_test

import (
	"context"
	"io"
	"log/slog"
	"testing"

	"github.com/scttymn/gantry/storage"

	"github.com/scttymn/estherpictures/app/models"
	"github.com/scttymn/estherpictures/app/services/content"
	"github.com/scttymn/estherpictures/db/seeds"
	"github.com/scttymn/estherpictures/test"
)

func newContent(t *testing.T) *content.Content {
	d := test.DB(t)
	if err := seeds.Run(context.Background(), d); err != nil {
		t.Fatal(err)
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	st := &storage.Storage{DB: d, Root: t.TempDir(), NoAVIF: true, Log: log}
	t.Cleanup(st.Wait)
	return &content.Content{DB: d, Storage: st, Log: log}
}

// A record keeps its newest 20 versions; an image only a pruned one named
// is swept with it.
func TestPrune(t *testing.T) {
	c := newContent(t)
	ctx := context.Background()
	if _, err := c.Storage.Attach(ctx, content.Thumbnail(1), storage.File{Filename: "first.gif", Data: gif}); err != nil {
		t.Fatal(err)
	}
	update := func(title string, image *storage.File) {
		t.Helper()
		err := c.Update(ctx, content.Clip, 1, 0, content.Change{Image: image, Write: func(q *models.Queries, now string) error {
			return q.UpdateClip(ctx, models.UpdateClipParams{ID: 1, Title: title, Now: now})
		}})
		if err != nil {
			t.Fatal(err)
		}
	}
	update("with a new image", &storage.File{Filename: "second.gif", Data: gif}) // the version names first.gif
	for i := range 19 {
		update("take "+string(rune('a'+i)), nil)
	}
	count := func() (n int) {
		c.DB.Read.QueryRow(`SELECT count(*) FROM content_versions WHERE item_type = 'clip'`).Scan(&n)
		return n
	}
	if loose, _ := c.Storage.Unattached(ctx); count() != 20 || len(loose) != 1 {
		t.Fatalf("%d versions, %d loose images: want 20, and first.gif kept", count(), len(loose))
	}
	update("one more", nil)
	if loose, _ := c.Storage.Unattached(ctx); count() != 20 || len(loose) != 0 {
		t.Errorf("%d versions, %d loose images: the oldest pruned, and first.gif with it", count(), len(loose))
	}
}

// Discarding one version sweeps only the images no other version names.
func TestSweepKeepsNamed(t *testing.T) {
	c := newContent(t)
	ctx := context.Background()
	old, _ := c.Storage.Attach(ctx, content.Thumbnail(1), storage.File{Filename: "old.gif", Data: gif})
	err := c.Update(ctx, content.Clip, 1, 0, content.Change{Image: &storage.File{Filename: "new.gif", Data: gif}, Write: func(q *models.Queries, now string) error {
		return q.UpdateClip(ctx, models.UpdateClipParams{ID: 1, Title: "Replaced", Now: now})
	}})
	if err != nil {
		t.Fatal(err)
	}
	err = c.Update(ctx, content.CraftService, 1, 0, content.Change{Write: func(q *models.Queries, now string) error {
		return q.UpdateCraftService(ctx, models.UpdateCraftServiceParams{ID: 1, Title: "Other", Now: now})
	}})
	if err != nil {
		t.Fatal(err)
	}
	var craft int64
	c.DB.Read.QueryRow(`SELECT id FROM content_versions WHERE item_type = 'craft_service'`).Scan(&craft)
	if err := c.Discard(ctx, craft); err != nil {
		t.Fatal(err)
	}
	if loose, _ := c.Storage.Unattached(ctx); len(loose) != 1 || loose[0].Key != old.Key {
		t.Errorf("the clip's version still names old.gif: %+v", loose)
	}
}

// gif is a 1×1 GIF.
var gif = []byte("GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;")
