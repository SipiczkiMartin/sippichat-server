-- name: MarkMessageRead :exec
INSERT INTO message_reads (
    message_id,
    user_id
)
VALUES (
    $1,
    $2
)
ON CONFLICT (message_id, user_id)
DO UPDATE SET
    read_at = NOW();


-- name: GetMessageReaders :many
SELECT
    user_id,
    read_at
FROM message_reads
WHERE message_id = $1;


-- name: MarkMessageDelivered :exec
INSERT INTO message_deliveries (
    message_id,
    user_id
)
VALUES (
    $1,
    $2
)
ON CONFLICT (message_id, user_id)
DO NOTHING;
