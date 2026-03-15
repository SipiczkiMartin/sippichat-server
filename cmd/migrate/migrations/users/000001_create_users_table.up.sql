create table if not exists `users` (
    `id` int unsigned not null auto_increment primary key,
    `username` varchar(255) not null unique,
    `password` varchar(255) not null,
    `createdAt` timestamp not null default current_timestamp
);