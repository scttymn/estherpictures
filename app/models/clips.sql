-- name: ListClips :many
SELECT * FROM clips ORDER BY position, id;

-- name: GetClip :one
SELECT * FROM clips WHERE id = ?;

-- name: CountClips :one
SELECT count(*) FROM clips;

-- name: CreateClip :one
INSERT INTO clips (position, title, video_url, runtime, format, years, status, created_at, updated_at)
VALUES (@position, @title, @video_url, @runtime, @format, @years, @status, @now, @now)
RETURNING id;

-- name: RestoreClip :exec
INSERT INTO clips (id, position, title, video_url, runtime, format, years, status, created_at, updated_at)
VALUES (@id, @position, @title, @video_url, @runtime, @format, @years, @status, @now, @now);

-- name: UpdateClip :exec
UPDATE clips SET position = @position, title = @title, video_url = @video_url, runtime = @runtime, format = @format,
  years = @years, status = @status, updated_at = @now
WHERE id = @id;

-- name: DeleteClip :exec
DELETE FROM clips WHERE id = ?;

-- Phoenix's thumbnails, for moving them into storage: gone once moved.

-- name: ListClipUploads :many
SELECT id, thumbnail_path FROM clips WHERE thumbnail_path <> '';

-- name: ClearClipUpload :exec
UPDATE clips SET thumbnail_path = '' WHERE id = ?;
