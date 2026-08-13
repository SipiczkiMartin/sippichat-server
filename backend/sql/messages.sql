-- name: CreateMessage :one
INSERT INTO messages (
    conversation_id,
    sender_id,
    content
)
VALUES (
    $1,
    $2,
    $3
)
RETURNING *;


-- name: ListMessages :many
SELECT
    m.id,
    m.conversation_id,
    m.sender_id,
    m.content,
    m.created_at,
    p.username,
    p.display_name,
    p.avatar_url
FROM messages m
JOIN profiles p
    ON p.user_id = m.sender_id
WHERE m.conversation_id = $1
  AND (
      sqlc.narg('before_created_at')::timestamptz IS NULL
      OR (
          m.created_at,
          m.id
      ) < (
          sqlc.narg('before_created_at')::timestamptz,
          sqlc.narg('before_id')::uuid
      )
  )
ORDER BY m.created_at DESC, m.id DESC
LIMIT $2;


-- name: IsConversationMember :one
SELECT EXISTS(
    SELECT 1
    FROM conversation_members
    WHERE conversation_id = $1
    AND user_id = $2
);

-- name: GetMessageByID :one
SELECT
    m.id,
    m.conversation_id,
    m.sender_id,
    m.content,
    m.created_at,

    p.username,
    p.display_name,
    p.avatar_url

FROM messages m

JOIN profiles p
    ON p.user_id = m.sender_id

WHERE m.id = $1;
