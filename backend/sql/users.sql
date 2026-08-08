-- name: GetUserByEmail :one
SELECT *
FROM users
WHERE email = $1
LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (
    email,
    password_hash
)
VALUES (
    $1,
    $2
)
RETURNING *;

-- name: GetUserByID :one
SELECT *
FROM users
WHERE id = $1
LIMIT 1;

-- name: GetCurrentUser :one
SELECT
    u.id,
    u.email,
    u.created_at,
    p.username,
    p.display_name,
    p.bio,
    p.avatar_url
FROM users u
LEFT JOIN profiles p
    ON p.user_id = u.id
WHERE u.id = $1
LIMIT 1;
