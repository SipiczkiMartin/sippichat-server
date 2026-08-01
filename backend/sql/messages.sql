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
SELECT id, conversation_id, sender_id, content, created_at
FROM messages
WHERE conversation_id = $1
ORDER BY created_at ASC
LIMIT $2;


-- name: IsConversationMember :one
SELECT EXISTS(
    SELECT 1
    FROM conversation_members
    WHERE conversation_id = $1
    AND user_id = $2
);
