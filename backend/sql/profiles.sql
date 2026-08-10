-- name: CreateProfile :one
INSERT INTO profiles (
    user_id,
    username,
    display_name
)
VALUES (
    $1,
    $2,
    $3
)
RETURNING *;

-- name: UpdateProfile :one
UPDATE profiles
SET
    display_name = $2,
    bio = $3,
    updated_at = NOW()
WHERE user_id = $1
RETURNING
    user_id,
    username,
    display_name,
    bio,
    avatar_url,
    created_at,
    updated_at;
