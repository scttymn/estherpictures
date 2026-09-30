-- name: ListCraftServices :many
SELECT * FROM craft_services ORDER BY position, id;

-- name: GetCraftService :one
SELECT * FROM craft_services WHERE id = ?;

-- name: CountCraftServices :one
SELECT count(*) FROM craft_services;

-- name: CreateCraftService :one
INSERT INTO craft_services (position, title, description, created_at, updated_at) VALUES (@position, @title, @description, @now, @now)
RETURNING id;

-- name: RestoreCraftService :exec
INSERT INTO craft_services (id, position, title, description, created_at, updated_at) VALUES (@id, @position, @title, @description, @now, @now);

-- name: UpdateCraftService :exec
UPDATE craft_services SET position = @position, title = @title, description = @description, updated_at = @now WHERE id = @id;

-- name: DeleteCraftService :exec
DELETE FROM craft_services WHERE id = ?;
