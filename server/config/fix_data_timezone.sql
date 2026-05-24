-- 修复历史数据：UTC时间+8小时转为北京时间
-- 只修复 created_at 在今天之前的数据（今天之后时区已正确）

-- 帖子
UPDATE posts SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';
UPDATE posts SET updated_at = DATE_ADD(updated_at, INTERVAL 8 HOUR) WHERE updated_at < '2026-05-24 19:00:00' AND updated_at IS NOT NULL;

-- 评论
UPDATE comments SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 聊天消息
UPDATE chat_messages SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 用户（注册时间等）
UPDATE users SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';
UPDATE users SET last_login = DATE_ADD(last_login, INTERVAL 8 HOUR) WHERE last_login < '2026-05-24 19:00:00' AND last_login IS NOT NULL;

-- 留币交易记录
UPDATE coin_transactions SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 经验记录
UPDATE exp_records SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 活动
UPDATE activities SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 消息
UPDATE messages SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 红包
UPDATE coin_redpackets SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';
UPDATE coin_redpacket_grabs SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 签到
UPDATE user_coins SET last_checkin = DATE_ADD(last_checkin, INTERVAL 8 HOUR) WHERE last_checkin IS NOT NULL AND last_checkin < '2026-05-24 19:00:00';

-- 验证码
UPDATE verify_codes SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- mentions
UPDATE mentions SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- AI聊天历史
UPDATE ai_chat_history SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- AI图片历史
UPDATE ai_image_history SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 搜索日志
UPDATE search_logs SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 收藏
UPDATE collects SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 点赞
UPDATE likes SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 关注
UPDATE follows SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';

-- 赞赏
UPDATE coin_appreciations SET created_at = DATE_ADD(created_at, INTERVAL 8 HOUR) WHERE created_at < '2026-05-24 19:00:00';
