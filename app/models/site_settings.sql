-- name: GetSiteSettings :one
SELECT * FROM site_settings WHERE id = 1;

-- name: CreateSiteSettings :exec
INSERT INTO site_settings (id, collective_name, created_at, updated_at) VALUES (1, 'ESTHER PICTURES', @now, @now)
ON CONFLICT (id) DO NOTHING;

-- name: UpdateSiteSettings :exec
UPDATE site_settings SET collective_name = @collective_name, tagline = @tagline, hero_heading = @hero_heading,
  contact_heading = @contact_heading, email = @email, studio_locations = @studio_locations,
  instagram_url = @instagram_url, letterboxd_url = @letterboxd_url, footer_text = @footer_text, updated_at = @now
WHERE id = 1;
