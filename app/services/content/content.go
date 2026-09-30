// Package content is everything on the public site that the admin edits:
// the site copy, the craft services, the clips and the cast, and their
// history.
//
// Every update and deletion records a version: the record as it was just
// before, so an admin can see what changed and roll it back. A restore is
// recorded too, so it can be undone. The newest 20 versions of each record
// are kept. A clip's thumbnail and a member's headshot are attachments
// (gantry's storage); a version names the image it had by its key, so a
// replaced image is kept (detached) while a version still names it, and
// swept once none does.
package content

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/scttymn/gantry/db"
	"github.com/scttymn/gantry/storage"

	"github.com/scttymn/estherpictures/app/models"
)

// The kinds of record the history keeps, as their versions name them.
const (
	SiteSetting    = "site_setting"
	CraftService   = "craft_service"
	Clip           = "clip"
	EnsembleMember = "ensemble_member"
)

// KeepVersions is how many versions of a record are kept.
const KeepVersions = 20

// Thumbnail is a clip's image, and Headshot a member's.
func Thumbnail(clipID int64) storage.Ref {
	return storage.Ref{RecordType: "Clip", RecordID: clipID, Name: "thumbnail"}
}

func Headshot(memberID int64) storage.Ref {
	return storage.Ref{RecordType: "EnsembleMember", RecordID: memberID, Name: "headshot"}
}

// imageField is the field a kind's image has in its versions.
var imageField = map[string]string{Clip: "thumbnail", EnsembleMember: "headshot"}

// Content is the site's editable content.
type Content struct {
	DB      *db.DB
	Storage *storage.Storage
	Log     *slog.Logger
	Now     func() time.Time // time.Now when nil; tests set it
}

func (c *Content) now() string {
	if c.Now != nil {
		return models.Stamp(c.Now())
	}
	return models.Stamp(time.Now())
}

// Data is a record's fields as a version keeps them, by name.
type Data map[string]any

func (d Data) text(name string) string {
	s, _ := d[name].(string)
	return s
}

func (d Data) int(name string) int64 {
	switch v := d[name].(type) {
	case float64:
		return int64(v)
	case int64:
		return v
	}
	return 0
}

// imageRef is the attachment a kind's record keeps its image at.
func imageRef(kind string, id int64) (storage.Ref, bool) {
	switch kind {
	case Clip:
		return Thumbnail(id), true
	case EnsembleMember:
		return Headshot(id), true
	}
	return storage.Ref{}, false
}

// Snapshot is a record as it is now, as a version keeps it; ok is false
// when it's gone.
func (c *Content) Snapshot(ctx context.Context, kind string, id int64) (d Data, ok bool, err error) {
	q := models.New(c.DB.Read)
	switch kind {
	case SiteSetting:
		s, err := q.GetSiteSettings(ctx)
		if err != nil {
			return nil, false, notFound(err)
		}
		d = Data{"collective_name": s.CollectiveName, "tagline": s.Tagline, "hero_heading": s.HeroHeading,
			"contact_heading": s.ContactHeading, "email": s.Email, "studio_locations": s.StudioLocations,
			"instagram_url": s.InstagramUrl, "letterboxd_url": s.LetterboxdUrl, "footer_text": s.FooterText}
	case CraftService:
		s, err := q.GetCraftService(ctx, id)
		if err != nil {
			return nil, false, notFound(err)
		}
		d = Data{"position": s.Position, "title": s.Title, "description": s.Description}
	case Clip:
		cl, err := q.GetClip(ctx, id)
		if err != nil {
			return nil, false, notFound(err)
		}
		d = Data{"position": cl.Position, "title": cl.Title, "video_url": cl.VideoUrl, "runtime": cl.Runtime,
			"format": cl.Format, "years": cl.Years, "status": cl.Status}
	case EnsembleMember:
		m, err := q.GetEnsembleMember(ctx, id)
		if err != nil {
			return nil, false, notFound(err)
		}
		d = Data{"position": m.Position, "name": m.Name, "role": m.Role, "since_year": m.SinceYear, "bio": m.Bio}
	default:
		return nil, false, fmt.Errorf("content: no kind %q", kind)
	}
	if ref, ok := imageRef(kind, id); ok {
		b, found, err := c.Storage.Find(ctx, ref)
		if err != nil {
			return nil, false, err
		}
		d[imageField[kind]] = ""
		if found {
			d[imageField[kind]] = b.Key
		}
	}
	return d, true, nil
}

// notFound turns no row into a record that's gone (ok false, no error).
func notFound(err error) error {
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	return err
}

// Change is what a form changes: the record's new fields, written in the
// transaction that records the version, and, for a clip or member, a new
// image to attach.
type Change struct {
	Write func(q *models.Queries, now string) error
	Image *storage.File
}

// Update saves a change to a record, recording the version it replaces.
// The image it replaces is detached, not purged: the version names it.
func (c *Content) Update(ctx context.Context, kind string, id, actor int64, ch Change) error {
	before, ok, err := c.Snapshot(ctx, kind, id)
	if err != nil {
		return err
	}
	if !ok {
		return sql.ErrNoRows
	}
	if err := c.record(ctx, kind, id, "update", before, actor, ch.Write); err != nil {
		return err
	}
	if ch.Image != nil {
		ref, _ := imageRef(kind, id)
		if _, _, err := c.Storage.Detach(ctx, ref); err != nil {
			return err
		}
		if _, err := c.Storage.Attach(ctx, ref, *ch.Image); err != nil {
			return err
		}
	}
	return nil
}

// Delete deletes a record, recording the version it was, so it can be
// brought back, image and all.
func (c *Content) Delete(ctx context.Context, kind string, id, actor int64) error {
	before, ok, err := c.Snapshot(ctx, kind, id)
	if err != nil || !ok {
		return err
	}
	err = c.record(ctx, kind, id, "delete", before, actor, func(q *models.Queries, _ string) error {
		switch kind {
		case CraftService:
			return q.DeleteCraftService(ctx, id)
		case Clip:
			return q.DeleteClip(ctx, id)
		case EnsembleMember:
			return q.DeleteEnsembleMember(ctx, id)
		}
		return fmt.Errorf("content: %s can't be deleted", kind)
	})
	if err != nil {
		return err
	}
	if ref, ok := imageRef(kind, id); ok {
		_, _, err = c.Storage.Detach(ctx, ref)
	}
	return err
}

// record writes a change and the version before it, together, then keeps
// the newest KeepVersions of the record's versions.
func (c *Content) record(ctx context.Context, kind string, id int64, action string, before Data, actor int64, write func(*models.Queries, string) error) error {
	data, err := json.Marshal(before)
	if err != nil {
		return err
	}
	now := c.now()
	pruned := false
	err = c.DB.Tx(ctx, func(tx *db.Tx) error {
		q := models.New(tx)
		if err := write(q, now); err != nil {
			return err
		}
		if err := q.CreateContentVersion(ctx, models.CreateContentVersionParams{ItemType: kind, ItemID: id, Action: action,
			Data: string(data), UserID: sql.NullInt64{Int64: actor, Valid: actor != 0}, Now: now}); err != nil {
			return err
		}
		ids, err := q.ListContentVersionIDs(ctx, models.ListContentVersionIDsParams{ItemType: kind, ItemID: id})
		if err != nil {
			return err
		}
		for _, old := range ids[min(len(ids), KeepVersions):] {
			if err := q.DeleteContentVersion(ctx, old); err != nil {
				return err
			}
			pruned = true
		}
		return nil
	})
	if err == nil && pruned {
		_, err = c.Sweep(ctx)
	}
	return err
}

// Restore writes a version back: the record as it was, image and all. A
// record that's gone (deleted, or a deletion's version) comes back under
// its id; one that's there is updated, and what it was is recorded, so the
// restore can be undone.
func (c *Content) Restore(ctx context.Context, versionID, actor int64) (kind string, err error) {
	v, err := models.New(c.DB.Read).GetContentVersion(ctx, versionID)
	if err != nil {
		return "", err
	}
	var d Data
	if err := json.Unmarshal([]byte(v.Data), &d); err != nil {
		return "", err
	}
	now, exists, err := c.Snapshot(ctx, v.ItemType, v.ItemID)
	if err != nil {
		return "", err
	}
	// Only the fields the version has are written back: an early one may
	// hold a few (the Phoenix app's left out those that were unset).
	if exists {
		for field, value := range d {
			now[field] = value
		}
		d = now
	}
	write := func(q *models.Queries, now string) error {
		return restore(ctx, q, v.ItemType, v.ItemID, d, now, exists)
	}
	if exists {
		err = c.Update(ctx, v.ItemType, v.ItemID, actor, Change{Write: write})
	} else {
		err = c.DB.Tx(ctx, func(tx *db.Tx) error { return write(models.New(tx), c.now()) })
	}
	if err != nil {
		return "", err
	}
	if ref, ok := imageRef(v.ItemType, v.ItemID); ok {
		key := d.text(imageField[v.ItemType])
		if _, _, err := c.Storage.Detach(ctx, ref); err != nil {
			return "", err
		}
		if key != "" {
			if _, found, err := c.Storage.Blob(ctx, key); err != nil {
				return "", err
			} else if found {
				if _, err := c.Storage.AttachBlob(ctx, ref, key); err != nil {
					return "", err
				}
			}
		}
	}
	return v.ItemType, nil
}

// restore writes d's fields to the record: an update, or, for a record
// that's gone, an insert under its id.
func restore(ctx context.Context, q *models.Queries, kind string, id int64, d Data, now string, exists bool) error {
	switch kind {
	case SiteSetting:
		return q.UpdateSiteSettings(ctx, models.UpdateSiteSettingsParams{CollectiveName: d.text("collective_name"), Tagline: d.text("tagline"),
			HeroHeading: d.text("hero_heading"), ContactHeading: d.text("contact_heading"), Email: d.text("email"),
			StudioLocations: d.text("studio_locations"), InstagramUrl: d.text("instagram_url"), LetterboxdUrl: d.text("letterboxd_url"),
			FooterText: d.text("footer_text"), Now: now})
	case CraftService:
		if !exists {
			return q.RestoreCraftService(ctx, models.RestoreCraftServiceParams{ID: id, Position: d.int("position"), Title: d.text("title"), Description: d.text("description"), Now: now})
		}
		return q.UpdateCraftService(ctx, models.UpdateCraftServiceParams{ID: id, Position: d.int("position"), Title: d.text("title"), Description: d.text("description"), Now: now})
	case Clip:
		if !exists {
			return q.RestoreClip(ctx, models.RestoreClipParams{ID: id, Position: d.int("position"), Title: d.text("title"), VideoUrl: d.text("video_url"),
				Runtime: d.text("runtime"), Format: d.text("format"), Years: d.text("years"), Status: d.text("status"), Now: now})
		}
		return q.UpdateClip(ctx, models.UpdateClipParams{ID: id, Position: d.int("position"), Title: d.text("title"), VideoUrl: d.text("video_url"),
			Runtime: d.text("runtime"), Format: d.text("format"), Years: d.text("years"), Status: d.text("status"), Now: now})
	case EnsembleMember:
		if !exists {
			return q.RestoreEnsembleMember(ctx, models.RestoreEnsembleMemberParams{ID: id, Position: d.int("position"), Name: d.text("name"), Role: d.text("role"),
				SinceYear: d.text("since_year"), Bio: d.text("bio"), Now: now})
		}
		return q.UpdateEnsembleMember(ctx, models.UpdateEnsembleMemberParams{ID: id, Position: d.int("position"), Name: d.text("name"), Role: d.text("role"),
			SinceYear: d.text("since_year"), Bio: d.text("bio"), Now: now})
	}
	return fmt.Errorf("content: no kind %q", kind)
}

// Discard removes one version, then the images nothing names any more.
func (c *Content) Discard(ctx context.Context, versionID int64) error {
	if err := models.New(c.DB.Write).DeleteContentVersion(ctx, versionID); err != nil {
		return err
	}
	_, err := c.Sweep(ctx)
	return err
}

// Clear removes every version, then the images nothing names any more.
func (c *Content) Clear(ctx context.Context) (versions int64, images int, err error) {
	if versions, err = models.New(c.DB.Write).DeleteContentVersions(ctx); err != nil {
		return 0, 0, err
	}
	images, err = c.Sweep(ctx)
	return versions, images, err
}

// Sweep purges the images attached to nothing that no version names.
func (c *Content) Sweep(ctx context.Context) (purged int, err error) {
	loose, err := c.Storage.Unattached(ctx)
	if err != nil || len(loose) == 0 {
		return 0, err
	}
	named := map[string]bool{}
	versions, err := models.New(c.DB.Read).ListContentVersionData(ctx)
	if err != nil {
		return 0, err
	}
	for _, v := range versions {
		var d Data
		if field, ok := imageField[v.ItemType]; ok && json.Unmarshal([]byte(v.Data), &d) == nil {
			named[d.text(field)] = true
		}
	}
	for _, b := range loose {
		if named[b.Key] {
			continue
		}
		if err := c.Storage.PurgeBlob(ctx, b.Key); err != nil {
			return purged, err
		}
		purged++
	}
	return purged, nil
}

// Entry is a version as the history shows it: who changed what, when, and
// each field it changed.
type Entry struct {
	ID       int64
	Kind     string
	ItemID   int64
	Action   string // "update" or "delete"
	At       time.Time
	By       string // the editor's email; "" when they're gone
	Label    string // the record's title or name
	Changes  []FieldChange
	Deletion bool
}

// FieldChange is a field's value before a change and after it ("" for
// blank). An image's value is its file's name.
type FieldChange struct{ Field, Before, After string }

// History is the newest versions, newest first, each with what it
// changed: a version keeps a record before its change, so what came after
// is the next version of the same record, or, for its newest, the record
// as it is now.
func (c *Content) History(ctx context.Context, limit int64) ([]Entry, error) {
	rows, err := models.New(c.DB.Read).ListContentVersions(ctx, limit)
	if err != nil {
		return nil, err
	}
	after := map[[2]any]Data{} // by kind and id: the state after the newer version
	var out []Entry
	for _, r := range rows {
		var before Data
		if err := json.Unmarshal([]byte(r.Data), &before); err != nil {
			return nil, err
		}
		item := [2]any{r.ItemType, r.ItemID}
		next, seen := after[item]
		if !seen {
			now, ok, err := c.Snapshot(ctx, r.ItemType, r.ItemID)
			if err != nil {
				return nil, err
			}
			if ok {
				next = now
			}
		}
		after[item] = before
		e := Entry{ID: r.ID, Kind: r.ItemType, ItemID: r.ItemID, Action: r.Action, At: models.Unstamp(r.CreatedAt), By: r.EmailAddress,
			Label: firstOf(before.text("title"), before.text("name"), before.text("collective_name")), Deletion: r.Action == "delete"}
		if e.Deletion {
			next = nil
		}
		if e.Changes, err = c.changes(ctx, r.ItemType, before, next); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, nil
}

// changes are the fields that differ from before to after, by name; with
// no after (a deletion, a record gone), every field before that had a value.
func (c *Content) changes(ctx context.Context, kind string, before, after Data) ([]FieldChange, error) {
	fields := map[string]bool{}
	for f := range before {
		fields[f] = true
	}
	for f := range after {
		fields[f] = true
	}
	names := make([]string, 0, len(fields))
	for f := range fields {
		names = append(names, f)
	}
	sort.Strings(names)
	var out []FieldChange
	for _, f := range names {
		b, a := c.shown(ctx, kind, f, before[f]), ""
		if after != nil {
			a = c.shown(ctx, kind, f, after[f])
		}
		if b != a {
			out = append(out, FieldChange{Field: f, Before: b, After: a})
		}
	}
	return out, nil
}

// shown is a field's value as the history shows it: an image by its file's
// name, anything else as text.
func (c *Content) shown(ctx context.Context, kind, field string, v any) string {
	switch v := v.(type) {
	case nil:
		return ""
	case string:
		if field == imageField[kind] && v != "" {
			if b, ok, err := c.Storage.Blob(ctx, v); err == nil && ok {
				return b.Filename
			}
			return "(an image since removed)"
		}
		return v
	case float64:
		return fmt.Sprint(int64(v))
	default:
		return fmt.Sprint(v)
	}
}

func firstOf(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
