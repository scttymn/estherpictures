package content

import (
	"context"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/scttymn/gantry/storage"

	"github.com/scttymn/estherpictures/app/models"
)

// ImportUploads moves the Phoenix app's uploads into storage, once: each
// clip's thumbnail_path and member's headshot_path ("/uploads/clips/…",
// files under dir) becomes an attachment, and each version that names one
// names its blob instead ("thumbnail": key), so restoring it brings the
// image back. A row is cleared as it's moved, so running it again moves
// only what's left; a file that's missing is left out, and said so. The
// files stay where they were, for going back to Phoenix; nothing reads them.
func (c *Content) ImportUploads(ctx context.Context, dir string) (moved int, err error) {
	keys := map[string]string{} // by upload path: its blob, stored once
	blobFor := func(upload string) (string, error) {
		if key, ok := keys[upload]; ok {
			return key, nil
		}
		rel, ok := strings.CutPrefix(path.Clean(upload), "/uploads/")
		if !ok || !fs.ValidPath(rel) {
			c.Log.Warn("[uploads] not an upload's path", "path", upload)
			keys[upload] = ""
			return "", nil
		}
		data, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(rel)))
		if errors.Is(err, fs.ErrNotExist) {
			c.Log.Warn("[uploads] missing, left out", "path", upload)
			keys[upload] = ""
			return "", nil
		}
		if err != nil {
			return "", err
		}
		b, err := c.Storage.Store(ctx, storage.File{Filename: path.Base(rel), Data: data})
		if err != nil {
			return "", err
		}
		keys[upload] = b.Key
		moved++
		return b.Key, nil
	}
	q := models.New(c.DB.Write)
	attach := func(ref storage.Ref, upload string, clear func() error) error {
		key, err := blobFor(upload)
		if err != nil {
			return err
		}
		if key != "" {
			if _, err := c.Storage.AttachBlob(ctx, ref, key); err != nil {
				return err
			}
		}
		return clear()
	}
	clips, err := q.ListClipUploads(ctx)
	if err != nil {
		return 0, err
	}
	for _, cl := range clips {
		if err := attach(Thumbnail(cl.ID), cl.ThumbnailPath, func() error { return q.ClearClipUpload(ctx, cl.ID) }); err != nil {
			return moved, err
		}
	}
	members, err := q.ListEnsembleMemberUploads(ctx)
	if err != nil {
		return moved, err
	}
	for _, m := range members {
		if err := attach(Headshot(m.ID), m.HeadshotPath, func() error { return q.ClearEnsembleMemberUpload(ctx, m.ID) }); err != nil {
			return moved, err
		}
	}
	versions, err := q.ListContentVersionData(ctx)
	if err != nil {
		return moved, err
	}
	for _, v := range versions {
		field, ok := imageField[v.ItemType]
		if !ok {
			continue
		}
		var d map[string]any
		if err := json.Unmarshal([]byte(v.Data), &d); err != nil {
			return moved, err
		}
		old := field + "_path" // thumbnail_path, headshot_path
		upload, had := d[old].(string)
		if !had {
			continue
		}
		delete(d, old)
		d[field] = ""
		if upload != "" {
			if d[field], err = blobFor(upload); err != nil {
				return moved, err
			}
		}
		data, err := json.Marshal(d)
		if err != nil {
			return moved, err
		}
		if err := q.UpdateContentVersionData(ctx, models.UpdateContentVersionDataParams{Data: string(data), ID: v.ID}); err != nil {
			return moved, err
		}
	}
	if moved > 0 {
		c.Log.Info("[uploads] moved into storage", "files", moved)
		c.Storage.WarmLater()
	}
	return moved, nil
}
