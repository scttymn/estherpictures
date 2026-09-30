-- name: ListEnsembleMembers :many
SELECT * FROM ensemble_members ORDER BY position, id;

-- name: GetEnsembleMember :one
SELECT * FROM ensemble_members WHERE id = ?;

-- name: CountEnsembleMembers :one
SELECT count(*) FROM ensemble_members;

-- name: CreateEnsembleMember :one
INSERT INTO ensemble_members (position, name, role, since_year, bio, created_at, updated_at)
VALUES (@position, @name, @role, @since_year, @bio, @now, @now)
RETURNING id;

-- name: RestoreEnsembleMember :exec
INSERT INTO ensemble_members (id, position, name, role, since_year, bio, created_at, updated_at)
VALUES (@id, @position, @name, @role, @since_year, @bio, @now, @now);

-- name: UpdateEnsembleMember :exec
UPDATE ensemble_members SET position = @position, name = @name, role = @role, since_year = @since_year, bio = @bio,
  updated_at = @now
WHERE id = @id;

-- name: DeleteEnsembleMember :exec
DELETE FROM ensemble_members WHERE id = ?;

-- Phoenix's headshots, for moving them into storage: gone once moved.

-- name: ListEnsembleMemberUploads :many
SELECT id, headshot_path FROM ensemble_members WHERE headshot_path <> '';

-- name: ClearEnsembleMemberUpload :exec
UPDATE ensemble_members SET headshot_path = '' WHERE id = ?;
