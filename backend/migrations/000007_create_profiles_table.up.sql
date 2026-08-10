CREATE TABLE profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,

    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,

    bio TEXT,
    avatar_url TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
