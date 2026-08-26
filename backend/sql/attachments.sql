-- name: CreateAttachment :one
INSERT INTO attachments (
    message_id,
    type,
    filename,
    mime_type,
    size,
    storage_key,
    external_url,
    metadata,
    sort_order
)
VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9
)
RETURNING *;


-- name: ListAttachmentsByMessageID :many
SELECT
    id,
    message_id,
    type,
    filename,
    mime_type,
    size,
    storage_key,
    external_url,
    metadata,
    sort_order,
    created_at
FROM attachments
WHERE message_id = $1
ORDER BY sort_order ASC, created_at ASC;
