-- name: CreateContentVersion :exec
INSERT INTO content_versions (item_type, item_id, action, data, user_id, created_at)
VALUES (@item_type, @item_id, @action, @data, @user_id, @now);

-- name: ListContentVersions :many
SELECT v.id, v.item_type, v.item_id, v.action, v.data, v.created_at, COALESCE(u.email_address, '') AS email_address
FROM content_versions v LEFT JOIN users u ON u.id = v.user_id
ORDER BY v.created_at DESC, v.id DESC
LIMIT ?;

-- name: GetContentVersion :one
SELECT * FROM content_versions WHERE id = ?;

-- name: ListContentVersionIDs :many
SELECT id FROM content_versions WHERE item_type = ? AND item_id = ? ORDER BY created_at DESC, id DESC;

-- name: ListContentVersionData :many
SELECT id, item_type, data FROM content_versions;

-- name: UpdateContentVersionData :exec
UPDATE content_versions SET data = ? WHERE id = ?;

-- name: DeleteContentVersion :exec
DELETE FROM content_versions WHERE id = ?;

-- name: DeleteContentVersions :execrows
DELETE FROM content_versions;
