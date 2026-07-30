-- name: CreateConversation :one
INSERT INTO conversations (
    type
)
VALUES (
    $1
)
RETURNING *;


-- name: AddConversationMember :exec
INSERT INTO conversation_members (
    conversation_id,
    user_id
)
VALUES (
    $1,
    $2
);


-- name: GetConversationByID :one
SELECT *
FROM conversations
WHERE id = $1;


-- name: GetDirectConversation :one
SELECT c.*
FROM conversations c
JOIN conversation_members cm1
    ON cm1.conversation_id = c.id
JOIN conversation_members cm2
    ON cm2.conversation_id = c.id
WHERE
    c.type = 'direct'
    AND cm1.user_id = $1
    AND cm2.user_id = $2
    AND (
        SELECT COUNT(*)
        FROM conversation_members
        WHERE conversation_id = c.id
    ) = 2
LIMIT 1;

-- name: ListConversations :many
SELECT
    c.id,
    c.type,
    c.created_at
FROM conversations c
JOIN conversation_members cm
    ON cm.conversation_id = c.id
WHERE cm.user_id = $1
ORDER BY c.created_at DESC;
