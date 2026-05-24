-- 经验记录表
CREATE TABLE IF NOT EXISTS `exp_records` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `amount` INT NOT NULL COMMENT '经验变化量（正数）',
  `type` TINYINT NOT NULL COMMENT '类型: 1发帖 2评论 3点赞 4被赞 5签到 6聊天 7管理员调整 8关注 9被关注 10收藏',
  `desc` VARCHAR(100) NOT NULL DEFAULT '' COMMENT '描述',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_type` (`type`),
  INDEX `idx_created_at` (`created_at`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 经验任务配置表（后端可动态配置）
CREATE TABLE IF NOT EXISTS `exp_task_config` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `type` TINYINT NOT NULL UNIQUE COMMENT '任务类型: 1发帖 2评论 3点赞 4签到 5聊天 6关注 7收藏',
  `name` VARCHAR(50) NOT NULL COMMENT '任务名称',
  `exp` INT NOT NULL DEFAULT 0 COMMENT '奖励经验',
  `daily_limit` INT NOT NULL DEFAULT 0 COMMENT '每日上限次数(0=无限)',
  `is_active` TINYINT NOT NULL DEFAULT 1 COMMENT '是否启用',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 等级配置表（后端可动态配置）
CREATE TABLE IF NOT EXISTS `level_config` (
  `level` TINYINT UNSIGNED PRIMARY KEY COMMENT '等级',
  `title` VARCHAR(30) NOT NULL COMMENT '称号',
  `exp` INT UNSIGNED NOT NULL COMMENT '累计经验阈值',
  `exp_to_next` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '升到下一级需要的经验增量',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 初始化等级配置
INSERT IGNORE INTO `level_config` (`level`, `title`, `exp`, `exp_to_next`) VALUES
(1, '初来乍到', 0, 50),
(2, '略知一二', 50, 150),
(3, '崭露头角', 200, 300),
(4, '小有名气', 500, 500),
(5, '声名远扬', 1000, 800),
(6, '如雷贯耳', 1800, 1200),
(7, '名震一方', 3000, 2000),
(8, '威震天下', 5000, 3000),
(9, '独步江湖', 8000, 4000),
(10, '登峰造极', 12000, 6000),
(11, '超凡入圣', 18000, 8000),
(12, '返璞归真', 26000, 0);

-- 初始化任务配置
INSERT IGNORE INTO `exp_task_config` (`type`, `name`, `exp`, `daily_limit`, `is_active`) VALUES
(1, '发布笔记', 10, 5, 1),
(2, '发表评论', 3, 20, 1),
(3, '点赞笔记', 1, 30, 1),
(4, '每日签到', 5, 1, 1),
(5, '聊天互动', 1, 20, 1),
(6, '关注用户', 2, 10, 1),
(7, '收藏笔记', 1, 20, 1);
