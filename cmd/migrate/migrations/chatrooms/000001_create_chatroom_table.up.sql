CREATE TABLE if not exists `chatrooms` (
    `id` int unsigned not null auto_increment PRIMARY KEY,
    `name` VARCHAR(100) not null,                  -- optional for 1:1, required for groups
    `type` VARCHAR(10) NOT NULL,          -- 'private' or 'group'
    `created_at` TIMESTAMP DEFAULT NOW(),
    `last_activity_at` TIMESTAMP DEFAULT NOW(),
    `lifetime_days` INT DEFAULT 30        -- number of days before room is archived
);
