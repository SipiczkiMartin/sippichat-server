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
    c.created_at,

    p.user_id       AS participant_id,
    p.username,
    p.display_name,
    p.avatar_url,

    (
        SELECT COUNT(*)
        FROM messages m
        WHERE m.conversation_id = c.id
          AND m.sender_id <> $1
          AND NOT EXISTS (
              SELECT 1
              FROM message_reads mr
              WHERE mr.message_id = m.id
                AND mr.user_id = $1
          )
    ) AS unread_count

FROM conversations c

JOIN conversation_members self
    ON self.conversation_id = c.id

JOIN conversation_members other
    ON other.conversation_id = c.id
   AND other.user_id <> self.user_id

JOIN profiles p
    ON p.user_id = other.user_id

WHERE self.user_id = $1

ORDER BY c.created_at DESC;


-- name: ListConversationMembers :many
SELECT user_id
FROM conversation_members
WHERE conversation_id = $1;

-- name: GetConversationDetails :one
SELECT
    c.id,
    c.type,
    c.created_at,

    p.user_id AS participant_id,
    p.username,
    p.display_name,
    p.avatar_url

FROM conversations c

JOIN conversation_members cm_self
ON cm_self.conversation_id = c.id

JOIN conversation_members cm_other
ON cm_other.conversation_id = c.id
AND cm_other.user_id <> cm_self.user_id

JOIN profiles p
ON p.user_id = cm_other.user_id

WHERE
    c.id = $1
    AND cm_self.user_id = $2

LIMIT 1;
