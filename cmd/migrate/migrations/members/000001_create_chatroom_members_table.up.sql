CREATE TABLE IF NOT EXISTS `chatroommembers` (
    `chatroom_id` INT unsigned NOT NULL,
    `user_id` INT unsigned NOT NULL,
    `role` VARCHAR(20) DEFAULT 'member',
    `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`chatroom_id`, `user_id`),
    FOREIGN KEY (`chatroom_id`) REFERENCES `chatrooms`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);