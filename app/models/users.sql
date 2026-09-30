-- name: ListUsers :many
SELECT id, email_address, role, must_change_password FROM users ORDER BY role, email_address;

-- name: GetUser :one
SELECT id, email_address, role, must_change_password FROM users WHERE id = ?;

-- name: CountUsers :one
SELECT count(*) FROM users;

-- name: CreateUser :one
INSERT INTO users (email_address, password_digest, role, must_change_password, created_at, updated_at)
VALUES (@email_address, @password_digest, @role, @must_change_password, @now, @now)
RETURNING id;

-- name: SetMustChangePassword :exec
UPDATE users SET must_change_password = @must_change_password, updated_at = @now WHERE id = @id;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = ?;
