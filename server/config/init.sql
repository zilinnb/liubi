-- 留笔数据库初始化脚本
-- 使用方法: mysql -u root -p < init.sql

CREATE DATABASE IF NOT EXISTS `bbs` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `bbs`;

-- 用户表
CREATE TABLE IF NOT EXISTS `users` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`username` VARCHAR(50) NOT NULL UNIQUE,
	`password` VARCHAR(200) NOT NULL,
	`nickname` VARCHAR(50) NOT NULL DEFAULT '',
	`avatar` VARCHAR(500) DEFAULT '',
	`bg_image` VARCHAR(500) DEFAULT '',
	`email` VARCHAR(100) DEFAULT '',
	`bio` VARCHAR(200) DEFAULT '',
	`gender` TINYINT DEFAULT NULL COMMENT '0女 1男 NULL未设置',
	`birthday` DATE DEFAULT NULL,
	`role` TINYINT NOT NULL DEFAULT 0 COMMENT '0普通用户 1管理员',
	`fans_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`follow_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`like_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`status` TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1正常',
	`privacy_follows` TINYINT NOT NULL DEFAULT 0 COMMENT '0公开 1私密',
	`privacy_fans` TINYINT NOT NULL DEFAULT 0 COMMENT '0公开 1私密',
	`privacy_likes` TINYINT NOT NULL DEFAULT 0 COMMENT '0公开 1私密',
	`username_changed_at` DATETIME DEFAULT NULL,
	`mute_until` DATETIME DEFAULT NULL COMMENT '禁言截止时间',
	`location` VARCHAR(100) DEFAULT '' COMMENT 'IP属地',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX `idx_username` (`username`),
	INDEX `idx_role` (`role`),
	INDEX `idx_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 分类表
CREATE TABLE IF NOT EXISTS `categories` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`name` VARCHAR(30) NOT NULL UNIQUE,
	`icon` VARCHAR(10) DEFAULT '',
	`cover` VARCHAR(500) DEFAULT '',
	`description` VARCHAR(200) DEFAULT '',
	`color` VARCHAR(20) DEFAULT '',
	`sort_order` INT NOT NULL DEFAULT 0,
	`post_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`author_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`heat` INT UNSIGNED NOT NULL DEFAULT 0,
	`follow_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`status` TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1正常',
	`publish_restriction` TINYINT NOT NULL DEFAULT 0 COMMENT '0所有人 1仅管理员',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 帖子/笔记表
CREATE TABLE IF NOT EXISTS `posts` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`title` VARCHAR(100) NOT NULL DEFAULT '',
	`content` TEXT NOT NULL,
	`category_id` INT UNSIGNED DEFAULT NULL,
	`location` VARCHAR(100) DEFAULT '',
	`topics` VARCHAR(500) DEFAULT '',
	`post_type` TINYINT NOT NULL DEFAULT 3 COMMENT '1文字 2语音 3图文',
	`voice_url` VARCHAR(500) DEFAULT '',
	`voice_duration` INT UNSIGNED NOT NULL DEFAULT 0,
	`text_template` TINYINT NOT NULL DEFAULT 0,
	`link` VARCHAR(500) DEFAULT '',
	`content_blocks` JSON DEFAULT NULL COMMENT '块编辑器内容',
	`likes_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`collects_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`comments_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`views_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`shares_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`status` TINYINT NOT NULL DEFAULT 1 COMMENT '0下架 1正常 2审核中',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX `idx_user` (`user_id`),
	INDEX `idx_category` (`category_id`),
	INDEX `idx_status` (`status`),
	INDEX `idx_created` (`created_at` DESC),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 帖子图片表
CREATE TABLE IF NOT EXISTS `post_images` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`post_id` INT UNSIGNED NOT NULL,
	`image_url` VARCHAR(500) NOT NULL,
	`media_type` TINYINT NOT NULL DEFAULT 1 COMMENT '1图片 2实况照片',
	`video_url` VARCHAR(500) DEFAULT '',
	`ratio` FLOAT DEFAULT 1.2 COMMENT '宽高比 width/height',
	`sort_order` INT NOT NULL DEFAULT 0,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_post` (`post_id`),
	FOREIGN KEY (`post_id`) REFERENCES `posts`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 评论表
CREATE TABLE IF NOT EXISTS `comments` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`post_id` INT UNSIGNED NOT NULL,
	`user_id` INT UNSIGNED NOT NULL,
	`parent_id` INT UNSIGNED DEFAULT NULL COMMENT '父评论ID，NULL为顶级评论',
	`content` VARCHAR(500) NOT NULL,
	`image_url` VARCHAR(500) DEFAULT '',
	`voice_url` VARCHAR(500) DEFAULT '',
	`voice_duration` INT UNSIGNED NOT NULL DEFAULT 0,
	`likes_count` INT UNSIGNED NOT NULL DEFAULT 0,
	`status` TINYINT NOT NULL DEFAULT 1,
	`location` VARCHAR(100) DEFAULT '' COMMENT 'IP属地',
	`is_pinned` TINYINT NOT NULL DEFAULT 0 COMMENT '0普通 1置顶',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_post` (`post_id`),
	INDEX `idx_user` (`user_id`),
	INDEX `idx_parent` (`parent_id`),
	FOREIGN KEY (`post_id`) REFERENCES `posts`(`id`) ON DELETE CASCADE,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 点赞记录表
CREATE TABLE IF NOT EXISTS `likes` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`target_id` INT UNSIGNED NOT NULL,
	`target_type` TINYINT NOT NULL COMMENT '1帖子 2评论',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_user_target` (`user_id`, `target_id`, `target_type`),
	INDEX `idx_target` (`target_id`, `target_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 收藏记录表
CREATE TABLE IF NOT EXISTS `collects` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`post_id` INT UNSIGNED NOT NULL,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_user_post` (`user_id`, `post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 关注记录表
CREATE TABLE IF NOT EXISTS `follows` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`follower_id` INT UNSIGNED NOT NULL,
	`following_id` INT UNSIGNED NOT NULL,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_follower_following` (`follower_id`, `following_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 消息通知表
CREATE TABLE IF NOT EXISTS `messages` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`from_user_id` INT UNSIGNED NOT NULL,
	`to_user_id` INT UNSIGNED NOT NULL,
	`type` TINYINT NOT NULL COMMENT '1赞 2评论 3关注 4系统 5@提及 6收藏',
	`content` VARCHAR(200) DEFAULT '',
	`target_id` INT UNSIGNED DEFAULT NULL,
	`is_read` TINYINT NOT NULL DEFAULT 0,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_to_user` (`to_user_id`, `is_read`),
	INDEX `idx_created` (`created_at` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 验证码表
CREATE TABLE IF NOT EXISTS `verify_codes` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`email` VARCHAR(100) NOT NULL,
	`code` VARCHAR(10) NOT NULL,
	`type` TINYINT NOT NULL COMMENT '1注册 2登录 3修改密码 4绑定邮箱',
	`expires_at` DATETIME NOT NULL,
	`used` TINYINT NOT NULL DEFAULT 0,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_email_code` (`email`, `code`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 用户动态表
CREATE TABLE IF NOT EXISTS `activities` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`type` TINYINT NOT NULL COMMENT '1发布 2赞 3评论 4收藏 5关注',
	`target_id` INT UNSIGNED NOT NULL,
	`target_type` TINYINT NOT NULL COMMENT '1帖子 2用户',
	`content` VARCHAR(200) DEFAULT '',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_user` (`user_id`),
	INDEX `idx_target` (`target_id`, `target_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- @提及记录表
CREATE TABLE IF NOT EXISTS `mentions` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`from_user_id` INT UNSIGNED NOT NULL,
	`to_user_id` INT UNSIGNED NOT NULL,
	`target_id` INT UNSIGNED NOT NULL,
	`target_type` TINYINT NOT NULL COMMENT '1帖子 2评论',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_to_user` (`to_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 搜索日志表
CREATE TABLE IF NOT EXISTS `search_logs` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`keyword` VARCHAR(100) NOT NULL,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_keyword` (`keyword`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 分类关注表
CREATE TABLE IF NOT EXISTS `category_follows` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`user_id` INT UNSIGNED NOT NULL,
	`category_id` INT UNSIGNED NOT NULL,
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_user_category` (`user_id`, `category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 聊天会话表
CREATE TABLE IF NOT EXISTS `chat_conversations` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`type` TINYINT NOT NULL COMMENT '1私聊 2群聊',
	`name` VARCHAR(50) DEFAULT '',
	`avatar` VARCHAR(500) DEFAULT '',
	`group_code` VARCHAR(20) DEFAULT '' COMMENT '群聊号(仅群聊使用)',
	`created_by` INT UNSIGNED DEFAULT NULL COMMENT '群创建者ID',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_group_code` (`group_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 会话成员表
CREATE TABLE IF NOT EXISTS `chat_members` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`conversation_id` INT UNSIGNED NOT NULL,
	`user_id` INT UNSIGNED NOT NULL,
	`joined_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	UNIQUE KEY `uk_conv_user` (`conversation_id`, `user_id`),
	INDEX `idx_user` (`user_id`),
	FOREIGN KEY (`conversation_id`) REFERENCES `chat_conversations`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 聊天消息表
CREATE TABLE IF NOT EXISTS `chat_messages` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`conversation_id` INT UNSIGNED NOT NULL,
	`sender_id` INT UNSIGNED NOT NULL,
	`content` TEXT NOT NULL,
	`type` TINYINT NOT NULL DEFAULT 1 COMMENT '1文本 2图片',
	`is_read` TINYINT NOT NULL DEFAULT 0,
	`is_recalled` TINYINT NOT NULL DEFAULT 0 COMMENT '0未撤回 1已撤回',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_conv` (`conversation_id`),
	INDEX `idx_sender` (`sender_id`),
	FOREIGN KEY (`conversation_id`) REFERENCES `chat_conversations`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 应用版本表
CREATE TABLE IF NOT EXISTS `app_versions` (
	`id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`version_code` INT UNSIGNED NOT NULL COMMENT '版本号(数字，用于比较大小)',
	`version_name` VARCHAR(20) NOT NULL COMMENT '版本名(如1.0.1)',
	`platform` VARCHAR(10) NOT NULL DEFAULT 'android' COMMENT 'android/ios',
	`update_type` TINYINT NOT NULL DEFAULT 1 COMMENT '1浏览器跳转 2直链静默更新',
	`force_update` TINYINT NOT NULL DEFAULT 0 COMMENT '0可跳过 1强制更新',
	`download_url` VARCHAR(500) NOT NULL DEFAULT '' COMMENT '下载地址(直链或网盘链接)',
	`update_content` TEXT COMMENT '更新内容(换行分隔)',
	`package_size` VARCHAR(20) DEFAULT '' COMMENT '安装包大小(如23.5MB)',
	`status` TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1启用',
	`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX `idx_platform_code` (`platform`, `version_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 初始分类数据
INSERT IGNORE INTO `categories` (`name`, `icon`, `sort_order`, `color`, `description`) VALUES
('穿搭', '👗', 1, '#ff2442', '时尚穿搭分享'),
('美食', '🍜', 2, '#faad14', '美食探店推荐'),
('旅行', '✈', 3, '#1890ff', '旅行攻略游记'),
('摄影', '📷', 4, '#722ed1', '摄影作品技巧'),
('日常', '☀', 5, '#52c41a', '日常生活记录'),
('情感', '💕', 6, '#ff2442', '情感故事倾诉'),
('读书', '📖', 7, '#13c2c2', '读书笔记推荐'),
('运动', '🏃', 8, '#52c41a', '运动健身打卡'),
('家居', '🏠', 9, '#faad14', '家居装修生活');

-- 初始管理员账号 (密码: admin123, bcrypt加密)
INSERT IGNORE INTO `users` (`username`, `password`, `nickname`, `bio`, `role`) VALUES
('admin', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '管理员', '系统管理员', 1);

-- 为已有数据库添加content_blocks字段
ALTER TABLE posts ADD COLUMN content_blocks JSON DEFAULT NULL COMMENT '块编辑器内容' AFTER link;

-- 为已有数据库添加mute_until字段
ALTER TABLE users ADD COLUMN mute_until DATETIME DEFAULT NULL COMMENT '禁言截止时间';
