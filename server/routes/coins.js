const express = require('express')
const router = express.Router()
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const { LEVEL_CONFIG, EXP_RULES, getLevelInfo } = require('./level-config')

// 确保用户有留币和等级记录
async function ensureUserRecords(userId) {
	await db.query('INSERT IGNORE INTO user_coins (user_id) VALUES (?)', [userId])
	await db.query('INSERT IGNORE INTO user_levels (user_id) VALUES (?)', [userId])
}

// 添加经验值
async function addExp(userId, amount) {
	await ensureUserRecords(userId)
	await db.query('UPDATE user_levels SET exp = exp + ?, total_exp = total_exp + ? WHERE user_id = ?', [amount, amount, userId])
	// 检查升级
	const [rows] = await db.query('SELECT exp FROM user_levels WHERE user_id = ?', [userId])
	const info = getLevelInfo(rows[0].exp)
	await db.query('UPDATE user_levels SET level = ? WHERE user_id = ?', [info.level, userId])
	return info
}

// ═══════════════ 留币相关 ═══════════════

// 获取留币余额
router.get('/balance', auth, async (req, res) => {
	try {
		await ensureUserRecords(req.user.id)
		const [rows] = await db.query('SELECT balance, total_earned, total_spent, checkin_days, last_checkin FROM user_coins WHERE user_id = ?', [req.user.id])
		const data = { ...rows[0] }
		if (data.last_checkin instanceof Date) {
			const d = data.last_checkin
			data.last_checkin = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
		}
		res.json({ code: 200, data })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 每日签到
router.post('/checkin', auth, async (req, res) => {
	try {
		await ensureUserRecords(req.user.id)
		const [rows] = await db.query('SELECT last_checkin, checkin_days FROM user_coins WHERE user_id = ?', [req.user.id])
		const now = new Date()
		const today = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`
		const lastCheckin = rows[0].last_checkin ? String(rows[0].last_checkin).slice(0, 10) : null
		if (lastCheckin === today) {
			return res.json({ code: 400, msg: '今日已签到' })
		}
		// 连续签到判断
		const yesterdayDate = new Date(Date.now() - 86400000)
		const yesterday = `${yesterdayDate.getFullYear()}-${String(yesterdayDate.getMonth()+1).padStart(2,'0')}-${String(yesterdayDate.getDate()).padStart(2,'0')}`
		const isConsecutive = lastCheckin === yesterday
		const newDays = isConsecutive ? rows[0].checkin_days + 1 : 1
		// 连续签到奖励递增：从数据库读取配置
		const [configRows] = await db.query("SELECT `key`, `value` FROM coin_config WHERE `key` IN ('checkin_base_reward', 'checkin_max_bonus', 'checkin_min_reward')")
		const configMap = {}
		configRows.forEach(r => { configMap[r.key] = parseInt(r.value) })
		const baseReward = configMap['checkin_base_reward'] || 5
		const minReward = configMap['checkin_min_reward'] || baseReward
		const maxBonus = configMap['checkin_max_bonus'] || 30
		// 奖励 = 基础奖励 + (连续天数-1)的递增，限制在[minReward, maxBonus]区间
		const reward = Math.min(Math.max(baseReward + (newDays - 1) * 2, minReward), maxBonus)
		// 更新余额和签到
		await db.query('UPDATE user_coins SET balance = balance + ?, total_earned = total_earned + ?, checkin_days = ?, last_checkin = ? WHERE user_id = ?',
			[reward, reward, newDays, today, req.user.id])
		// 记录交易
		await db.query('INSERT INTO coin_transactions (user_id, type, amount, description) VALUES (?, 1, ?, ?)',
			[req.user.id, reward, `每日签到(连续${newDays}天)`])
		// 签到获得经验
		await addExp(req.user.id, EXP_RULES.checkin)
		res.json({ code: 200, data: { reward, days: newDays } })
	} catch (e) {
		res.json({ code: 500, msg: '签到失败' })
	}
})

// 获取交易记录
router.get('/transactions', auth, async (req, res) => {
	try {
		const limit = parseInt(req.query.limit) || 20
		const offset = parseInt(req.query.offset) || 0
		const [rows] = await db.query(
			'SELECT id, type, amount, description, created_at FROM coin_transactions WHERE user_id = ? ORDER BY id DESC LIMIT ? OFFSET ?',
			[req.user.id, limit, offset]
		)
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 发红包
router.post('/redpacket/send', auth, async (req, res) => {
	try {
		const { total_coins, total_count, message, post_id } = req.body
		if (!total_coins || total_coins < 1 || !total_count || total_count < 1) {
			return res.json({ code: 400, msg: '参数错误' })
		}
		if (total_coins < total_count) {
			return res.json({ code: 400, msg: '每个红包至少1留币' })
		}
		await ensureUserRecords(req.user.id)
		// 检查余额
		const [rows] = await db.query('SELECT balance FROM user_coins WHERE user_id = ?', [req.user.id])
		if (rows[0].balance < total_coins) {
			return res.json({ code: 400, msg: '留币不足' })
		}
		// 扣除留币
		await db.query('UPDATE user_coins SET balance = balance - ?, total_spent = total_spent + ? WHERE user_id = ?',
			[total_coins, total_coins, req.user.id])
		// 创建红包
		const [result] = await db.query(
			'INSERT INTO coin_redpackets (user_id, post_id, total_coins, total_count, remaining_coins, remaining_count, message) VALUES (?, ?, ?, ?, ?, ?, ?)',
			[req.user.id, post_id || null, total_coins, total_count, total_coins, total_count, message || '恭喜发财']
		)
		// 记录交易
		await db.query('INSERT INTO coin_transactions (user_id, type, amount, related_id, description) VALUES (?, 2, ?, ?, ?)',
			[req.user.id, -total_coins, result.insertId, `发红包(${total_coins}留币${total_count}份)`])
		res.json({ code: 200, data: { redpacket_id: result.insertId } })
	} catch (e) {
		res.json({ code: 500, msg: '发送失败' })
	}
})

// 抢红包
router.post('/redpacket/grab', auth, async (req, res) => {
	try {
		const { redpacket_id } = req.body
		await ensureUserRecords(req.user.id)
		// 检查是否已抢
		const [existing] = await db.query('SELECT id FROM coin_redpacket_grabs WHERE redpacket_id = ? AND user_id = ?', [redpacket_id, req.user.id])
		if (existing.length > 0) {
			return res.json({ code: 400, msg: '已领取过' })
		}
		// 获取红包信息
		const [rpRows] = await db.query('SELECT * FROM coin_redpackets WHERE id = ? AND status = 1', [redpacket_id])
		if (rpRows.length === 0) {
			return res.json({ code: 400, msg: '红包已抢完' })
		}
		const rp = rpRows[0]
		if (rp.remaining_count <= 0 || rp.remaining_coins <= 0) {
			await db.query('UPDATE coin_redpackets SET status = 2 WHERE id = ?', [redpacket_id])
			return res.json({ code: 400, msg: '红包已抢完' })
		}
		// 计算金额：最后一个拿剩余，其他随机
		let amount
		if (rp.remaining_count === 1) {
			amount = rp.remaining_coins
		} else {
			const maxPer = Math.floor(rp.remaining_coins / rp.remaining_count) * 2
			amount = Math.max(1, Math.floor(Math.random() * maxPer) + 1)
			if (amount > rp.remaining_coins - rp.remaining_count + 1) {
				amount = rp.remaining_coins - rp.remaining_count + 1
			}
		}
		// 更新红包
		await db.query('UPDATE coin_redpackets SET remaining_coins = remaining_coins - ?, remaining_count = remaining_count - ? WHERE id = ?',
			[amount, 1, redpacket_id])
		if (rp.remaining_count <= 1) {
			await db.query('UPDATE coin_redpackets SET status = 2 WHERE id = ?', [redpacket_id])
		}
		// 增加用户余额
		await db.query('UPDATE user_coins SET balance = balance + ?, total_earned = total_earned + ? WHERE user_id = ?',
			[amount, amount, req.user.id])
		// 记录领取
		await db.query('INSERT INTO coin_redpacket_grabs (redpacket_id, user_id, amount) VALUES (?, ?, ?)',
			[redpacket_id, req.user.id, amount])
		// 记录交易
		await db.query('INSERT INTO coin_transactions (user_id, type, amount, related_id, description) VALUES (?, 3, ?, ?, ?)',
			[req.user.id, amount, redpacket_id, `抢红包获得${amount}留币`])
		res.json({ code: 200, data: { amount } })
	} catch (e) {
		res.json({ code: 500, msg: '领取失败' })
	}
})

// 获取红包详情（谁抢了）
router.get('/redpacket/:id', auth, async (req, res) => {
	try {
		const [rp] = await db.query('SELECT * FROM coin_redpackets WHERE id = ?', [req.params.id])
		if (rp.length === 0) return res.json({ code: 404, msg: '红包不存在' })
		const [grabs] = await db.query(
			'SELECT g.amount, g.created_at, u.id as user_id, u.nickname, u.avatar FROM coin_redpacket_grabs g JOIN users u ON g.user_id = u.id WHERE g.redpacket_id = ? ORDER BY g.id',
			[req.params.id]
		)
		res.json({ code: 200, data: { redpacket: rp[0], grabs } })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 赞赏帖子
router.post('/appreciate', auth, async (req, res) => {
	try {
		const { post_id, amount } = req.body
		if (!post_id || !amount || amount < 1) return res.json({ code: 400, msg: '参数错误' })
		await ensureUserRecords(req.user.id)
		// 检查余额
		const [rows] = await db.query('SELECT balance FROM user_coins WHERE user_id = ?', [req.user.id])
		if (rows[0].balance < amount) return res.json({ code: 400, msg: '留币不足' })
		// 获取帖子作者
		const [postRows] = await db.query('SELECT user_id FROM posts WHERE id = ?', [post_id])
		if (postRows.length === 0) return res.json({ code: 404, msg: '帖子不存在' })
		if (postRows[0].user_id === req.user.id) return res.json({ code: 400, msg: '不能赞赏自己' })
		const authorId = postRows[0].user_id
		// 扣除赞赏者留币
		await db.query('UPDATE user_coins SET balance = balance - ?, total_spent = total_spent + ? WHERE user_id = ?',
			[amount, amount, req.user.id])
		// 增加作者留币
		await ensureUserRecords(authorId)
		await db.query('UPDATE user_coins SET balance = balance + ?, total_earned = total_earned + ? WHERE user_id = ?',
			[amount, amount, authorId])
		// 记录赞赏
		await db.query('INSERT INTO coin_appreciations (post_id, from_user_id, amount) VALUES (?, ?, ?)',
			[post_id, req.user.id, amount])
		// 双方交易记录
		await db.query('INSERT INTO coin_transactions (user_id, type, amount, related_id, description) VALUES (?, 4, ?, ?, ?)',
			[req.user.id, -amount, post_id, `赞赏帖子${amount}留币`])
		await db.query('INSERT INTO coin_transactions (user_id, type, amount, related_id, description) VALUES (?, 5, ?, ?, ?)',
			[authorId, amount, post_id, `收到赞赏${amount}留币`])
		res.json({ code: 200, msg: '赞赏成功' })
	} catch (e) {
		res.json({ code: 500, msg: '赞赏失败' })
	}
})

// 获取帖子赞赏记录
router.get('/appreciations/:postId', async (req, res) => {
	try {
		const [rows] = await db.query(
			'SELECT a.amount, a.created_at, u.id as user_id, u.nickname, u.avatar FROM coin_appreciations a JOIN users u ON a.from_user_id = u.id WHERE a.post_id = ? ORDER BY a.id DESC',
			[req.params.postId]
		)
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// ═══════════════ 等级相关 ═══════════════

// 获取我的等级信息
router.get('/level', auth, async (req, res) => {
	try {
		await ensureUserRecords(req.user.id)
		const [rows] = await db.query('SELECT level, exp, total_exp FROM user_levels WHERE user_id = ?', [req.user.id])
		const info = getLevelInfo(rows[0].exp)
		res.json({ code: 200, data: { ...rows[0], ...info } })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 获取指定用户等级信息（公开）
router.get('/level/:userId', async (req, res) => {
	try {
		await ensureUserRecords(req.params.userId)
		const [rows] = await db.query('SELECT level, exp, total_exp FROM user_levels WHERE user_id = ?', [req.params.userId])
		const info = getLevelInfo(rows[0].exp)
		res.json({ code: 200, data: { ...rows[0], ...info } })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 获取等级配置表
router.get('/level-config', (req, res) => {
	res.json({ code: 200, data: LEVEL_CONFIG })
})

// ═══════════════ 管理员接口 ═══════════════

// 管理员调整留币
router.post('/admin/adjust', auth, async (req, res) => {
	try {
		if (req.user.role !== 1) return res.json({ code: 403, msg: '无权限' })
		const { user_id, amount, description } = req.body
		if (!user_id || !amount) return res.json({ code: 400, msg: '参数错误' })
		await ensureUserRecords(user_id)
		if (amount > 0) {
			await db.query('UPDATE user_coins SET balance = balance + ?, total_earned = total_earned + ? WHERE user_id = ?', [amount, amount, user_id])
		} else {
			await db.query('UPDATE user_coins SET balance = balance + ?, total_spent = total_spent + ? WHERE user_id = ?', [amount, -amount, user_id])
		}
		await db.query('INSERT INTO coin_transactions (user_id, type, amount, description) VALUES (?, 6, ?, ?)',
			[user_id, amount, description || '管理员调整'])
		res.json({ code: 200, msg: '调整成功' })
	} catch (e) {
		res.json({ code: 500, msg: '调整失败' })
	}
})

// 管理员调整经验值
router.post('/admin/adjust-exp', auth, async (req, res) => {
	try {
		if (req.user.role !== 1) return res.json({ code: 403, msg: '无权限' })
		const { user_id, exp } = req.body
		if (!user_id || exp === undefined) return res.json({ code: 400, msg: '参数错误' })
		await ensureUserRecords(user_id)
		const info = await addExp(user_id, exp)
		res.json({ code: 200, data: info })
	} catch (e) {
		res.json({ code: 500, msg: '调整失败' })
	}
})

// 管理员获取所有用户留币/等级列表
router.get('/admin/users', auth, async (req, res) => {
	try {
		if (req.user.role !== 1) return res.json({ code: 403, msg: '无权限' })
		const page = parseInt(req.query.page) || 1
		const pageSize = parseInt(req.query.pageSize) || 10
		const offset = (page - 1) * pageSize
		let where = ''
		const params = []
		if (req.query.nickname) {
			where = 'WHERE u.nickname LIKE ?'
			params.push(`%${req.query.nickname}%`)
		}
		const [countRows] = await db.query(`SELECT COUNT(*) as total FROM users u ${where}`, params)
		const [rows] = await db.query(
			`SELECT u.id, u.nickname, u.avatar, COALESCE(uc.balance, 0) as coins, COALESCE(ul.level, 1) as level, COALESCE(ul.exp, 0) as exp
			FROM users u
			LEFT JOIN user_coins uc ON u.id = uc.user_id
			LEFT JOIN user_levels ul ON u.id = ul.user_id
			${where}
			ORDER BY u.id DESC LIMIT ? OFFSET ?`,
			[...params, pageSize, offset]
		)
		res.json({ code: 200, data: { list: rows, total: countRows[0].total } })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 获取留币配置（管理员）
router.get('/config', auth, async (req, res) => {
	try {
		const [rows] = await db.query('SELECT `key`, `value`, description FROM coin_config')
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 更新留币配置（管理员）
router.put('/config', auth, async (req, res) => {
	try {
		if (req.user.role !== 1) return res.json({ code: 403, msg: '无权限' })
		const { key, value } = req.body
		if (!key || value === undefined) return res.json({ code: 400, msg: '参数错误' })
		await db.query('UPDATE coin_config SET `value` = ? WHERE `key` = ?', [String(value), key])
		res.json({ code: 200, msg: '更新成功' })
	} catch (e) {
		res.json({ code: 500, msg: '更新失败' })
	}
})

module.exports = router
module.exports.addExp = addExp
module.exports.EXP_RULES = EXP_RULES
module.exports.getLevelInfo = getLevelInfo
module.exports.ensureUserRecords = ensureUserRecords
