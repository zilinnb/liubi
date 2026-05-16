const express = require('express')
const cors = require('cors')
const path = require('path')
const mysql = require('mysql2/promise')
const http = require('http')
const WebSocket = require('ws')
const jwt = require('jsonwebtoken')
const { PORT } = require('./config/env')
const { JWT_SECRET } = require('./config/env')
const db = require('./config/db')

const app = express()
const server = http.createServer(app)

const wss = new WebSocket.Server({ server, path: '/ws' })
const wsClients = new Map()

function broadcastOnlineCount() {
	const count = wsClients.size
	const msg = JSON.stringify({ type: 'online', data: { count } })
	wss.clients.forEach(ws => {
		if (ws.readyState === WebSocket.OPEN) {
			ws.send(msg)
		}
	})
}

function sendToUser(userId, data) {
	const clients = wsClients.get(userId)
	if (!clients) return
	const msg = JSON.stringify(data)
	for (const ws of clients) {
		if (ws.readyState === WebSocket.OPEN) {
			ws.send(msg)
		}
	}
}

wss.on('connection', (ws, req) => {
	const params = new URL(req.url, `http://${req.headers.host}`).searchParams
	const token = params.get('token')
	if (!token) { ws.close(4001, 'Missing token'); return }

	let userId
	try {
		const decoded = jwt.verify(token, JWT_SECRET)
		userId = decoded.id || decoded.userId
		if (!userId) { ws.close(4003, 'Invalid user'); return }
	} catch (e) {
		ws.close(4002, 'Invalid token'); return
	}

	if (!wsClients.has(userId)) wsClients.set(userId, new Set())
	wsClients.get(userId).add(ws)
	ws.userId = userId
	ws.isAlive = true

	broadcastOnlineCount()

	ws.on('pong', () => { ws.isAlive = true })

	ws.on('message', async (raw) => {
		try {
			const data = JSON.parse(raw)
			if (data.type === 'ping') {
				ws.send(JSON.stringify({ type: 'pong' }))
				return
			}
			if (data.type === 'chat') {
				const { conversation_id, content, msg_type } = data
				if (!conversation_id || !content) return

				const [memberCheck] = await db.query(
					'SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?',
					[conversation_id, userId]
				)
				if (!memberCheck.length) return

				const [result] = await db.query(
					'INSERT INTO chat_messages (conversation_id, sender_id, content, type) VALUES (?, ?, ?, ?)',
					[conversation_id, userId, content, msg_type || 1]
				)

				const [senderRows] = await db.query('SELECT nickname, avatar FROM users WHERE id = ?', [userId])
				const sender = senderRows[0] || {}

				const messageData = {
					id: result.insertId,
					conversation_id,
					sender_id: userId,
					sender_name: sender.nickname || '',
					sender_avatar: sender.avatar || '',
					content,
					type: msg_type || 1,
					is_recalled: 0,
					created_at: new Date().toISOString(),
				}

				await db.query('UPDATE chat_conversations SET updated_at = NOW() WHERE id = ?', [conversation_id])

				const [members] = await db.query('SELECT user_id FROM chat_members WHERE conversation_id = ?', [conversation_id])
				for (const m of members) {
					sendToUser(m.user_id, { type: 'chat', data: messageData })
					if (m.user_id !== userId && !wsClients.has(m.user_id)) {
						await db.query(
							'INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, 7, ?, ?)',
							[userId, m.user_id, content.substring(0, 200), conversation_id]
						)
					}
				}
			} else if (data.type === 'recall') {
				const { message_id, conversation_id } = data
				if (!message_id) return

				const [rows] = await db.query('SELECT * FROM chat_messages WHERE id = ? AND sender_id = ?', [message_id, userId])
				if (!rows.length) return

				await db.query('UPDATE chat_messages SET is_recalled = 1 WHERE id = ?', [message_id])

				const [members] = await db.query('SELECT user_id FROM chat_members WHERE conversation_id = ?', [conversation_id])
				for (const m of members) {
					sendToUser(m.user_id, { type: 'recall', data: { message_id, conversation_id } })
				}
			}
		} catch (e) {
			console.error('[WS] 消息处理错误:', e.message)
		}
	})

	ws.on('close', () => {
		const clients = wsClients.get(userId)
		if (clients) {
			clients.delete(ws)
			if (clients.size === 0) wsClients.delete(userId)
		}
		broadcastOnlineCount()
	})
})

const heartbeatInterval = setInterval(() => {
	wss.clients.forEach((ws) => {
		if (!ws.isAlive) return ws.terminate()
		ws.isAlive = false
		ws.ping()
	})
}, 30000)

wss.on('close', () => { clearInterval(heartbeatInterval) })

const wsHelper = require('./utils/ws-helper')
wsHelper.setWsClients(wsClients)

// 自动初始化数据库和表
async function autoInit() {
	const DB_NAME = process.env.DB_NAME || 'bbs'
	const DB_HOST = process.env.DB_HOST || 'localhost'
	const DB_PORT = process.env.DB_PORT || 3306
	const DB_USER = process.env.DB_USER || 'root'
	const DB_PASS = process.env.DB_PASS || '123456'

	// 1. 先不指定数据库连接，创建数据库
	const conn = await mysql.createConnection({ host: DB_HOST, port: DB_PORT, user: DB_USER, password: DB_PASS })
	await conn.query(`CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`)
	await conn.end()
	console.log(`  [初始化] 数据库 "${DB_NAME}" 已就绪`)

	// 2. 建表（IF NOT EXISTS，已有表不会动）
	const tables = [
		`CREATE TABLE IF NOT EXISTS users (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			username VARCHAR(50) NOT NULL UNIQUE,
			password VARCHAR(200) NOT NULL,
			nickname VARCHAR(50) NOT NULL DEFAULT '',
			avatar VARCHAR(500) DEFAULT '',
			bg_image VARCHAR(500) DEFAULT '',
			email VARCHAR(100) DEFAULT '',
			bio VARCHAR(200) DEFAULT '',
			gender TINYINT DEFAULT NULL COMMENT '0女 1男 NULL未设置',
			birthday DATE DEFAULT NULL,
			role TINYINT NOT NULL DEFAULT 0 COMMENT '0普通用户 1管理员',
			fans_count INT UNSIGNED NOT NULL DEFAULT 0,
			follow_count INT UNSIGNED NOT NULL DEFAULT 0,
			like_count INT UNSIGNED NOT NULL DEFAULT 0,
			status TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1正常',
			privacy_follows TINYINT NOT NULL DEFAULT 0 COMMENT '0公开 1私密',
			privacy_fans TINYINT NOT NULL DEFAULT 0 COMMENT '0公开 1私密',
			privacy_likes TINYINT NOT NULL DEFAULT 0 COMMENT '0公开 1私密',
			username_changed_at DATETIME DEFAULT NULL,
			mute_until DATETIME DEFAULT NULL COMMENT '禁言截止时间',
			location VARCHAR(100) DEFAULT '' COMMENT 'IP属地',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			INDEX idx_username (username),
			INDEX idx_role (role),
			INDEX idx_email (email)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS categories (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			name VARCHAR(30) NOT NULL UNIQUE,
			icon VARCHAR(10) DEFAULT '',
			cover VARCHAR(500) DEFAULT '',
			description VARCHAR(200) DEFAULT '',
			color VARCHAR(20) DEFAULT '',
			sort_order INT NOT NULL DEFAULT 0,
			post_count INT UNSIGNED NOT NULL DEFAULT 0,
			author_count INT UNSIGNED NOT NULL DEFAULT 0,
			heat INT UNSIGNED NOT NULL DEFAULT 0,
			follow_count INT UNSIGNED NOT NULL DEFAULT 0,
			status TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1正常',
			publish_restriction TINYINT NOT NULL DEFAULT 0 COMMENT '0所有人 1仅管理员',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS posts (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			user_id INT UNSIGNED NOT NULL,
			title VARCHAR(100) NOT NULL DEFAULT '',
			content TEXT NOT NULL,
			category_id INT UNSIGNED DEFAULT NULL,
			location VARCHAR(100) DEFAULT '',
			topics VARCHAR(500) DEFAULT '',
			post_type TINYINT NOT NULL DEFAULT 3 COMMENT '1文字 2语音 3图文',
			voice_url VARCHAR(500) DEFAULT '',
			voice_duration INT UNSIGNED NOT NULL DEFAULT 0,
			text_template TINYINT NOT NULL DEFAULT 0,
			link VARCHAR(500) DEFAULT '',
			content_blocks JSON DEFAULT NULL COMMENT '块编辑器内容',
			likes_count INT UNSIGNED NOT NULL DEFAULT 0,
			collects_count INT UNSIGNED NOT NULL DEFAULT 0,
			comments_count INT UNSIGNED NOT NULL DEFAULT 0,
			views_count INT UNSIGNED NOT NULL DEFAULT 0,
			shares_count INT UNSIGNED NOT NULL DEFAULT 0,
			status TINYINT NOT NULL DEFAULT 1 COMMENT '0下架 1正常 2审核中',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			INDEX idx_user (user_id),
			INDEX idx_category (category_id),
			INDEX idx_status (status),
			INDEX idx_created (created_at DESC),
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS post_images (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			post_id INT UNSIGNED NOT NULL,
			image_url VARCHAR(500) NOT NULL,
			media_type TINYINT NOT NULL DEFAULT 1 COMMENT '1图片 2实况照片',
			video_url VARCHAR(500) DEFAULT '',
			ratio FLOAT DEFAULT 1.2 COMMENT '宽高比 width/height',
			sort_order INT NOT NULL DEFAULT 0,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_post (post_id),
			FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS comments (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			post_id INT UNSIGNED NOT NULL,
			user_id INT UNSIGNED NOT NULL,
			parent_id INT UNSIGNED DEFAULT NULL COMMENT '父评论ID',
			content VARCHAR(500) NOT NULL,
			image_url VARCHAR(500) DEFAULT '',
			likes_count INT UNSIGNED NOT NULL DEFAULT 0,
			status TINYINT NOT NULL DEFAULT 1,
			location VARCHAR(100) DEFAULT '' COMMENT 'IP属地',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_post (post_id),
			INDEX idx_user (user_id),
			INDEX idx_parent (parent_id),
			FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS likes (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			user_id INT UNSIGNED NOT NULL,
			target_id INT UNSIGNED NOT NULL,
			target_type TINYINT NOT NULL COMMENT '1帖子 2评论',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE KEY uk_user_target (user_id, target_id, target_type),
			INDEX idx_target (target_id, target_type)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS collects (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			user_id INT UNSIGNED NOT NULL,
			post_id INT UNSIGNED NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE KEY uk_user_post (user_id, post_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS follows (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			follower_id INT UNSIGNED NOT NULL,
			following_id INT UNSIGNED NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE KEY uk_follower_following (follower_id, following_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS messages (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			from_user_id INT UNSIGNED NOT NULL,
			to_user_id INT UNSIGNED NOT NULL,
			type TINYINT NOT NULL COMMENT '1赞 2评论 3关注 4系统 5@提及 6收藏',
			content VARCHAR(200) DEFAULT '',
			target_id INT UNSIGNED DEFAULT NULL,
			is_read TINYINT NOT NULL DEFAULT 0,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_to_user (to_user_id, is_read),
			INDEX idx_created (created_at DESC)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS verify_codes (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			email VARCHAR(100) NOT NULL,
			code VARCHAR(10) NOT NULL,
			type TINYINT NOT NULL COMMENT '1注册 2登录 3修改密码 4绑定邮箱',
			expires_at DATETIME NOT NULL,
			used TINYINT NOT NULL DEFAULT 0,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_email_code (email, code, type)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS activities (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			user_id INT UNSIGNED NOT NULL,
			type TINYINT NOT NULL COMMENT '1发布 2赞 3评论 4收藏 5关注',
			target_id INT UNSIGNED NOT NULL,
			target_type TINYINT NOT NULL COMMENT '1帖子 2用户',
			content VARCHAR(200) DEFAULT '',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_user (user_id),
			INDEX idx_target (target_id, target_type)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS mentions (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			from_user_id INT UNSIGNED NOT NULL,
			to_user_id INT UNSIGNED NOT NULL,
			target_id INT UNSIGNED NOT NULL,
			target_type TINYINT NOT NULL COMMENT '1帖子 2评论',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_to_user (to_user_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS search_logs (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			keyword VARCHAR(100) NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_keyword (keyword)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS category_follows (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			user_id INT UNSIGNED NOT NULL,
			category_id INT UNSIGNED NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE KEY uk_user_category (user_id, category_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS chat_conversations (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			type TINYINT NOT NULL COMMENT '1私聊 2群聊',
			name VARCHAR(50) DEFAULT '',
			avatar VARCHAR(500) DEFAULT '',
			group_code VARCHAR(20) DEFAULT '' COMMENT '群聊号',
			created_by INT UNSIGNED DEFAULT NULL COMMENT '群创建者ID',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			UNIQUE KEY uk_group_code (group_code)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS chat_members (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			conversation_id INT UNSIGNED NOT NULL,
			user_id INT UNSIGNED NOT NULL,
			joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE KEY uk_conv_user (conversation_id, user_id),
			INDEX idx_user (user_id),
			FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS chat_messages (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			conversation_id INT UNSIGNED NOT NULL,
			sender_id INT UNSIGNED NOT NULL,
			content TEXT NOT NULL,
			type TINYINT NOT NULL DEFAULT 1 COMMENT '1文本 2图片',
			is_read TINYINT NOT NULL DEFAULT 0,
			is_recalled TINYINT NOT NULL DEFAULT 0 COMMENT '0未撤回 1已撤回',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_conv (conversation_id),
			INDEX idx_sender (sender_id),
			FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

		`CREATE TABLE IF NOT EXISTS app_versions (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			version_code INT UNSIGNED NOT NULL COMMENT '版本号',
			version_name VARCHAR(20) NOT NULL COMMENT '版本名',
			platform VARCHAR(10) NOT NULL DEFAULT 'android',
			update_type TINYINT NOT NULL DEFAULT 1 COMMENT '1浏览器跳转 2直链静默更新',
			force_update TINYINT NOT NULL DEFAULT 0 COMMENT '0可跳过 1强制更新',
			download_url VARCHAR(500) NOT NULL DEFAULT '',
			update_content TEXT,
			package_size VARCHAR(20) DEFAULT '',
			status TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1启用',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_platform_code (platform, version_code)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,
		`CREATE TABLE IF NOT EXISTS ai_config (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			api_url VARCHAR(500) NOT NULL DEFAULT 'https://api.deepseek.com/v1/chat/completions',
			api_key VARCHAR(500) NOT NULL DEFAULT '',
			model_name VARCHAR(100) NOT NULL DEFAULT 'deepseek-chat',
			system_prompt TEXT,
			enabled TINYINT NOT NULL DEFAULT 1 COMMENT '0禁用 1启用',
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,
		`CREATE TABLE IF NOT EXISTS ai_chat_history (
			id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			user_id INT UNSIGNED NOT NULL,
			role ENUM('user','assistant') NOT NULL,
			content TEXT NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_user (user_id),
			INDEX idx_user_time (user_id, created_at)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,
	]

	for (const sql of tables) {
		try {
			await db.query(sql)
		} catch (e) {
			// 已有表或外键依赖顺序问题，忽略
			if (e.code !== 'ER_TABLE_EXISTS_ERROR') {
				console.error('  [初始化] 建表警告:', e.message)
			}
		}
	}
	console.log('  [初始化] 数据表已就绪')

	// 3. 初始数据（INSERT IGNORE 不重复插入）
	const initData = [
		`INSERT IGNORE INTO categories (name, icon, sort_order, color, description) VALUES
		('穿搭', '👗', 1, '#ff2442', '时尚穿搭分享'),
		('美食', '🍜', 2, '#faad14', '美食探店推荐'),
		('旅行', '✈', 3, '#1890ff', '旅行攻略游记'),
		('摄影', '📷', 4, '#722ed1', '摄影作品技巧'),
		('日常', '☀', 5, '#52c41a', '日常生活记录'),
		('情感', '💕', 6, '#ff2442', '情感故事倾诉'),
		('读书', '📖', 7, '#13c2c2', '读书笔记推荐'),
		('运动', '🏃', 8, '#52c41a', '运动健身打卡'),
		('家居', '🏠', 9, '#faad14', '家居装修生活')`,
		`INSERT IGNORE INTO users (username, password, nickname, bio, role) VALUES
		('admin', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '管理员', '系统管理员', 1)`,
	]
	for (const sql of initData) {
		try { await db.query(sql) } catch (e) { /* 忽略 */ }
	}
	console.log('  [初始化] 初始数据已就绪')

	// 4. 补充已有表缺失的字段
	const migrations = [
		{ table: 'users', column: 'mute_until', definition: 'DATETIME DEFAULT NULL' },
		{ table: 'users', column: 'privacy_follows', definition: 'TINYINT NOT NULL DEFAULT 0' },
		{ table: 'users', column: 'privacy_fans', definition: 'TINYINT NOT NULL DEFAULT 0' },
		{ table: 'users', column: 'privacy_likes', definition: 'TINYINT NOT NULL DEFAULT 0' },
		{ table: 'users', column: 'username_changed_at', definition: 'DATETIME DEFAULT NULL' },
		{ table: 'posts', column: 'content_blocks', definition: 'JSON DEFAULT NULL' },
		{ table: 'chat_messages', column: 'is_recalled', definition: 'TINYINT NOT NULL DEFAULT 0 COMMENT "0未撤回 1已撤回"' },
		{ table: 'chat_conversations', column: 'group_code', definition: 'VARCHAR(20) DEFAULT "" COMMENT "群聊号"' },
		{ table: 'chat_conversations', column: 'created_by', definition: 'INT UNSIGNED DEFAULT NULL COMMENT "群创建者ID"' },
		{ table: 'posts', column: 'is_pinned', definition: 'TINYINT NOT NULL DEFAULT 0 COMMENT "0普通 1置顶"' },
		{ table: 'posts', column: 'pinned_at', definition: 'DATETIME DEFAULT NULL COMMENT "置顶时间"' },
		{ table: 'posts', column: 'pinned_category_id', definition: 'INT UNSIGNED DEFAULT NULL COMMENT "在哪个分类置顶"' },
		{ table: 'comments', column: 'location', definition: 'VARCHAR(100) DEFAULT "" COMMENT "IP属地"' },
		{ table: 'comments', column: 'is_pinned', definition: 'TINYINT NOT NULL DEFAULT 0 COMMENT "0普通 1置顶"' },
		{ table: 'users', column: 'location', definition: 'VARCHAR(100) DEFAULT "" COMMENT "IP属地"' },
		{ table: 'chat_members', column: 'is_pinned', definition: 'TINYINT NOT NULL DEFAULT 0 COMMENT "0普通 1置顶"' },
		{ table: 'chat_members', column: 'is_hidden', definition: 'TINYINT NOT NULL DEFAULT 0 COMMENT "0正常 1隐藏"' },
	]
	for (const m of migrations) {
		try {
			const [rows] = await db.query(
				`SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
				[m.table, m.column]
			)
			if (rows.length === 0) {
				await db.query(`ALTER TABLE ${m.table} ADD COLUMN ${m.column} ${m.definition}`)
				console.log(`  [迁移] 已添加字段: ${m.table}.${m.column}`)
			}
		} catch (e) {
			console.error(`  [迁移] 字段检查失败: ${m.table}.${m.column}`, e.message)
		}
	}

	// 5. 创建默认群聊666666并加入所有用户
	try {
		const [groups] = await db.query('SELECT id FROM chat_conversations WHERE group_code = ? AND type = 2', ['666666'])
		if (!groups.length) {
			const [result] = await db.query(
				'INSERT INTO chat_conversations (type, name, group_code, created_by) VALUES (2, ?, ?, ?)',
				['官方群', '666666', 1]
			)
			const groupId = result.insertId
			const [users] = await db.query('SELECT id FROM users WHERE status = 1')
			if (users.length) {
				const vals = users.map(u => [groupId, u.id])
				await db.query('INSERT IGNORE INTO chat_members (conversation_id, user_id) VALUES ?', [vals])
			}
			console.log('  [迁移] 已创建默认群聊666666并加入所有用户')
		}
	} catch (e) {
		console.error('  [迁移] 默认群聊创建失败:', e.message)
	}
}

// 中间件
app.use(cors())
app.use(express.json({ limit: '50mb' }))
app.use(express.urlencoded({ extended: true, limit: '50mb' }))

app.use('/uploads', express.static(path.join(__dirname, 'uploads')))

// API路由
app.use('/api/auth', require('./routes/auth'))
app.use('/api/posts', require('./routes/posts'))
app.use('/api/comments', require('./routes/comments'))
app.use('/api/users', require('./routes/users'))
app.use('/api/categories', require('./routes/categories'))
app.use('/api/messages', require('./routes/messages'))
app.use('/api/admin', require('./routes/admin'))
app.use('/api/upload', require('./routes/upload'))
app.use('/api/chat', require('./routes/chat'))
app.use('/api/ai', require('./routes/ai'))
app.use('/api/version', require('./routes/version'))
app.use('/api/notifications', require('./routes/notifications').router)
const statsModule = require('./routes/stats')
statsModule.setWsClients(wsClients)
app.use('/api/stats', statsModule.router)

app.use((req, res) => {
	res.status(404).json({ code: 404, msg: '接口不存在' })
})

// 启动
async function start() {
	await autoInit()
	server.listen(PORT, () => {
		console.log('')
		console.log('  ╔══════════════════════════════════════╗')
		console.log('  ║     留笔服务端已启动               ║')
		console.log('  ╠══════════════════════════════════════╣')
		console.log(`  ║  API地址:  http://localhost:${PORT}/api  ║`)
		console.log(`  ║  WS地址:   ws://localhost:${PORT}/ws    ║`)
		console.log('  ╚══════════════════════════════════════╝')
		console.log('')
	})
}
start()
