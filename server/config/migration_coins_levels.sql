USE `bbs`;

-- 用户留币余额表
CREATE TABLE IF NOT EXISTS `user_coins` (
	`user_id` INT UNSIGNED PRIMARY KEY,
	`balance` INT NOT NULL DEFAULT 0 COMMENT '当前余额',
	`total_earned` INT NOT NULL DEFAULT 0 COMMENT '累计获得',
	`total_spent` INT NOT NULL DEFAULT 0 COMMENT '累计消费',
	`checkin_days` INT NOT NULL DEFAULT 0 COMMENT '连续签到天数',
	`last_checkin` DATE DEFAULT NULL COMMENT '最后签到日期',
	`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 留币交易记录表
CREATE TABLE IF NOT EXISTS `coin_transactions` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`type` TINYINT NOT NULL COMMENT '1签到 2发红包 3抢红包 4赞赏 5收到赞赏 6管理员调整',
	`amount` INT NOT NULL COMMENT '正数收入负数支出',
	`related_id` INT UNSIGNED DEFAULT NULL COMMENT '关联ID(红包ID/帖子ID等)',
	`description` VARCHAR(200) DEFAULT '',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_user` (`user_id`),
	INDEX `idx_created` (`created_at` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 留币红包表
CREATE TABLE IF NOT EXISTS `coin_redpackets` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`post_id` INT UNSIGNED DEFAULT NULL COMMENT '关联帖子ID',
	`total_coins` INT NOT NULL COMMENT '总留币数',
	`total_count` INT NOT NULL COMMENT '总份数',
	`remaining_coins` INT NOT NULL DEFAULT 0 COMMENT '剩余留币',
	`remaining_count` INT NOT NULL DEFAULT 0 COMMENT '剩余份数',
	`message` VARCHAR(50) DEFAULT '恭喜发财' COMMENT '红包祝福语',
	`status` TINYINT NOT NULL DEFAULT 1 COMMENT '1进行中 2已抢完 3已过期',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_post` (`post_id`),
	INDEX `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 红包领取记录表
CREATE TABLE IF NOT EXISTS `coin_redpacket_grabs` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`redpacket_id` INT UNSIGNED NOT NULL,
	`user_id` INT UNSIGNED NOT NULL,
	`amount` INT NOT NULL COMMENT '领取数量',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_redpacket_user` (`redpacket_id`, `user_id`),
	INDEX `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 帖子赞赏记录表
CREATE TABLE IF NOT EXISTS `coin_appreciations` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`post_id` INT UNSIGNED NOT NULL,
	`from_user_id` INT UNSIGNED NOT NULL,
	`amount` INT NOT NULL COMMENT '赞赏数量',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_post` (`post_id`),
	INDEX `idx_from` (`from_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 用户等级经验表
CREATE TABLE IF NOT EXISTS `user_levels` (
	`user_id` INT UNSIGNED PRIMARY KEY,
	`level` INT NOT NULL DEFAULT 1 COMMENT '当前等级',
	`exp` INT NOT NULL DEFAULT 0 COMMENT '当前经验值',
	`total_exp` INT NOT NULL DEFAULT 0 COMMENT '累计经验值',
	`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 为分类表添加等级限制字段
ALTER TABLE `categories` ADD COLUMN `min_level` TINYINT NOT NULL DEFAULT 0 COMMENT '发帖最低等级要求' AFTER `publish_restriction`;

-- 为帖子表添加红包字段
ALTER TABLE `posts` ADD COLUMN `redpacket_id` INT UNSIGNED DEFAULT NULL COMMENT '关联红包ID' AFTER `content_blocks`;
