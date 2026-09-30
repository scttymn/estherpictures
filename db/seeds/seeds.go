// Package seeds is the data a fresh database starts with (Rails' db/seeds):
// run at start and by gantry db seed, so it must be safe to run again.
package seeds

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/scttymn/gantry/db"

	"github.com/scttymn/estherpictures/app/models"
)

// Run gives a new database the launch copy: the site copy, the craft, the
// clips and the cast. A database with site copy already is left as it is.
func Run(ctx context.Context, d *db.DB) error {
	if _, err := models.New(d.Read).GetSiteSettings(ctx); !errors.Is(err, sql.ErrNoRows) {
		return err
	}
	now := models.Stamp(time.Now())
	return d.Tx(ctx, func(tx *db.Tx) error {
		q := models.New(tx)
		if err := q.CreateSiteSettings(ctx, now); err != nil {
			return err
		}
		if err := q.UpdateSiteSettings(ctx, models.UpdateSiteSettingsParams{
			CollectiveName:  "ESTHER PICTURES",
			Tagline:         "AN INDEPENDENT FILM COLLECTIVE — NY / LA",
			HeroHeading:     "Films that trust\nthe audience.",
			ContactHeading:  "Let's make\nsomething.",
			Email:           "hello@estherpictures.com",
			StudioLocations: "New York · Los Angeles",
			InstagramUrl:    "#",
			LetterboxdUrl:   "#",
			FooterText:      "© 2026 ESTHER PICTURES — INDEPENDENT FILM COLLECTIVE",
			Now:             now,
		}); err != nil {
			return err
		}
		for _, s := range []models.CreateCraftServiceParams{
			{Position: 1, Title: "Writing", Description: "Original screenplays and adaptations, developed in-house from first page to shooting draft."},
			{Position: 2, Title: "Directing", Description: "A tight bench of directors with a point of view, from short-form to feature."},
			{Position: 3, Title: "Acting & Ensemble", Description: "A resident ensemble and a casting network built over a decade of independent work."},
			{Position: 4, Title: "Post & Craft", Description: "Edit, color, sound, and score — the finishing that protects the cut."},
		} {
			s.Now = now
			if _, err := q.CreateCraftService(ctx, s); err != nil {
				return err
			}
		}
		for _, c := range []models.CreateClipParams{
			{Position: 1, Title: "The Quiet Coast", VideoUrl: "https://www.youtube.com/watch?v=bFcu0Rn1d7w", Runtime: "04:12", Format: "2.39 : 1 · DCP", Years: "2023", Status: "NOW PLAYING"},
			{Position: 2, Title: "Nightshift", Runtime: "03:48", Format: "1.85 : 1", Years: "2022", Status: "SELECTED"},
			{Position: 3, Title: "Salt", Runtime: "02:31", Format: "2.39 : 1", Years: "2024", Status: "SELECTED"},
			{Position: 4, Title: "A Long Winter", Runtime: "05:07", Format: "1.66 : 1", Years: "2021", Status: "SELECTED"},
		} {
			c.Now = now
			if _, err := q.CreateClip(ctx, c); err != nil {
				return err
			}
		}
		for _, m := range []models.CreateEnsembleMemberParams{
			{Position: 1, Name: "Mara Vance", Role: "FOUNDER / WRITER-DIRECTOR", SinceYear: "2019"},
			{Position: 2, Name: "Idris Bellê", Role: "DIRECTOR / ACTOR", SinceYear: "2021"},
			{Position: 3, Name: "Cleo Nakamura", Role: "WRITER / EDITOR", SinceYear: "2022"},
		} {
			m.Now = now
			if _, err := q.CreateEnsembleMember(ctx, m); err != nil {
				return err
			}
		}
		return nil
	})
}
