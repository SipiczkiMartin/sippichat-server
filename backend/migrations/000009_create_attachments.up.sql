CREATE TABLE attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    message_id UUID NOT NULL
        REFERENCES messages(id)
        ON DELETE CASCADE,

    type TEXT NOT NULL,

    filename TEXT,
    mime_type TEXT,
    size BIGINT,

    storage_key TEXT,
    external_url TEXT,

    metadata JSONB,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT attachments_type_check
        CHECK (type IN ('file', 'image', 'gif'))
);


CREATE INDEX idx_attachments_message_id
ON attachments(message_id);
