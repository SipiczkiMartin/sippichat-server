ALTER TABLE refresh_tokens
DROP CONSTRAINT refresh_tokens_token_hash_unique;

ALTER TABLE refresh_tokens
DROP COLUMN revoked_at;
