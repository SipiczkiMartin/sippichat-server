CREATE TABLE if not exists `messages` (
    `id` int unsigned auto_increment PRIMARY KEY,
    `chatroom_id` INT unsigned not null,
    `sender_id` INT unsigned not null,
    `content` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (`chatroom_id`) REFERENCES `chatrooms`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`sender_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);