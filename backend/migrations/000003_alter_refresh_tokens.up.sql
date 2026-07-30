ALTER TABLE refresh_tokens
ADD COLUMN revoked_at TIMESTAMPTZ;

ALTER TABLE refresh_tokens
ADD CONSTRAINT refresh_tokens_token_hash_unique UNIQUE (token_hash);
