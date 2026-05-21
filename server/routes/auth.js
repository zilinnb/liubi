const express = require('express')
const bcrypt = require('bcryptjs')
const jwt = require('jsonwebtoken')
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const { JWT_SECRET } = require('../config/env')
const { sendVerifyCode } = require('../utils/mailer')
const router = express.Router()

// 生成6位验证码
function genCode() {
	return String(Math.floor(100000 + Math.random() * 900000))
}

// 生成9位随机数字用户名（确保唯一）
async function genUsername() {
	let username = ''
	let exists = true
	while (exists) {
		username = String(Math.floor(100000000 + Math.random() * 900000000))
		const [rows] = await db.query('SELECT id FROM users WHERE username = ?', [username])
		exists = rows.length > 0
	}
	return username
}

// 验证验证码
async function verifyCode(email, code, type) {
	const [rows] = await db.query(
		'SELECT id FROM verify_codes WHERE email = ? AND code = ? AND type = ? AND used = 0 AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1',
		[email, code, type]
	)
	if (!rows.length) return false
	await db.query('UPDATE verify_codes SET used = 1 WHERE id = ?', [rows[0].id])
	return true
}

// 发送验证码
router.post('/send-code', async (req, res) => {
	try {
		let { email, type } = req.body
		if (!email) return res.json({ code: 400, msg: '请输入邮箱' })
		if (!type) return res.json({ code: 400, msg: '缺少类型' })

		if (!email.includes('@')) {
			const [rows] = await db.query('SELECT email FROM users WHERE username = ? AND status = 1', [email])
			if (!rows.length || !rows[0].email) return res.json({ code: 400, msg: '该账号未绑定邮箱，无法使用验证码' })
			email = rows[0].email
		}

		const [recent] = await db.query(
			'SELECT id FROM verify_codes WHERE email = ? AND type = ? AND created_at > DATE_SUB(NOW(), INTERVAL 60 SECOND)',
			[email, type]
		)
		if (recent.length) return res.json({ code: 429, msg: '发送太频繁，请60秒后再试' })

		if (Number(type) === 1) {
			const [exist] = await db.query('SELECT id FROM users WHERE email = ?', [email])
			if (exist.length) return res.json({ code: 400, msg: '该邮箱已注册' })
		}

		if (Number(type) === 2 || Number(type) === 3) {
			const [exist] = await db.query('SELECT id FROM users WHERE email = ?', [email])
			if (!exist.length) return res.json({ code: 400, msg: '该邮箱未注册' })
		}

		if (Number(type) === 4) {
			const [exist] = await db.query('SELECT id FROM users WHERE email = ?', [email])
			if (exist.length) return res.json({ code: 400, msg: '该邮箱已被其他账号绑定' })
		}

		const code = genCode()
		await db.query(
			'INSERT INTO verify_codes (email, code, type, expires_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 5 MINUTE))',
			[email, code, type]
		)

		const typeLabel = { 1: '注册', 2: '登录', 3: '修改密码', 4: '绑定邮箱' }[type] || '验证'
		try {
			await sendVerifyCode(db, email, code, typeLabel)
		} catch (mailErr) {
			return res.json({ code: 500, msg: mailErr.message || '验证码发送失败' })
		}

		res.json({ code: 200, msg: '验证码已发送' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 邮箱+验证码注册
router.post('/register', async (req, res) => {
	try {
		const { email, code, password, nickname } = req.body
		if (!email || !code || !password) return res.json({ code: 400, msg: '请填写完整信息' })
		if (password.length < 6) return res.json({ code: 400, msg: '密码至少6位' })

		const valid = await verifyCode(email, code, 1)
		if (!valid) return res.json({ code: 400, msg: '验证码错误或已过期' })

		const username = await genUsername()
		const hash = await bcrypt.hash(password, 10)
		const [result] = await db.query(
			'INSERT INTO users (username, password, nickname, email) VALUES (?, ?, ?, ?)',
			[username, hash, nickname || '用户' + username.slice(-4), email]
		)

		// 新用户自动加入群号666666的群聊
		try {
			const [groups] = await db.query('SELECT id FROM chat_conversations WHERE group_code = ? AND type = 2', ['666666'])
			if (groups.length) {
				await db.query('INSERT IGNORE INTO chat_members (conversation_id, user_id) VALUES (?, ?)', [groups[0].id, result.insertId])
			}
		} catch (e) { console.error('自动加群失败:', e) }

		const token = jwt.sign({ id: result.insertId, username, role: 0 }, JWT_SECRET, { expiresIn: '7d' })
		res.json({
			code: 200, msg: '注册成功', data: {
				token,
				user: { id: result.insertId, username, nickname: nickname || '用户' + username.slice(-4), email, role: 0 }
			}
		})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 邮箱/用户名+验证码登录
router.post('/login-code', async (req, res) => {
	try {
		let { email, code } = req.body
		if (!email || !code) return res.json({ code: 400, msg: '请填写邮箱和验证码' })

		if (!email.includes('@')) {
			const [rows] = await db.query('SELECT email FROM users WHERE username = ? AND status = 1', [email])
			if (!rows.length || !rows[0].email) return res.json({ code: 400, msg: '该账号未绑定邮箱，无法使用验证码登录' })
			email = rows[0].email
		}

		const valid = await verifyCode(email, code, 2)
		if (!valid) return res.json({ code: 400, msg: '验证码错误或已过期' })

		const [rows] = await db.query('SELECT * FROM users WHERE email = ? AND status = 1', [email])
		if (!rows.length) return res.json({ code: 400, msg: '账号不存在或已禁用' })

		const user = rows[0]
		const token = jwt.sign({ id: user.id, username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '7d' })

		// 登录时自动加入群号666666的群聊（如果还未加入）
		try {
			const [groups] = await db.query('SELECT id FROM chat_conversations WHERE group_code = ? AND type = 2', ['666666'])
			if (groups.length) {
				await db.query('INSERT IGNORE INTO chat_members (conversation_id, user_id) VALUES (?, ?)', [groups[0].id, user.id])
			}
		} catch (e) { console.error('自动加群失败:', e) }

		res.json({
			code: 200, msg: '登录成功', data: {
				token,
				user: { id: user.id, username: user.username, nickname: user.nickname, avatar: user.avatar, bio: user.bio, email: user.email, role: user.role, fans_count: user.fans_count, follow_count: user.follow_count, like_count: user.like_count, collect_count: user.collect_count }
			}
		})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 邮箱/用户名+密码登录
router.post('/login', async (req, res) => {
	try {
		const { email, password } = req.body
		if (!email || !password) return res.json({ code: 400, msg: '请填写账号和密码' })

		const [rows] = await db.query(
			'SELECT * FROM users WHERE (email = ? OR username = ?) AND status = 1',
			[email, email]
		)
		if (!rows.length) return res.json({ code: 400, msg: '账号不存在或已禁用' })

		const user = rows[0]
		const valid = await bcrypt.compare(password, user.password)
		if (!valid) return res.json({ code: 400, msg: '密码错误' })

		const token = jwt.sign({ id: user.id, username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '7d' })

		// 登录时自动加入群号666666的群聊（如果还未加入）
		try {
			const [groups] = await db.query('SELECT id FROM chat_conversations WHERE group_code = ? AND type = 2', ['666666'])
			if (groups.length) {
				await db.query('INSERT IGNORE INTO chat_members (conversation_id, user_id) VALUES (?, ?)', [groups[0].id, user.id])
			}
		} catch (e) { console.error('自动加群失败:', e) }

		res.json({
			code: 200, msg: '登录成功', data: {
				token,
				user: { id: user.id, username: user.username, nickname: user.nickname, avatar: user.avatar, bio: user.bio, email: user.email, role: user.role, fans_count: user.fans_count, follow_count: user.follow_count, like_count: user.like_count, collect_count: user.collect_count }
			}
		})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 绑定邮箱
router.post('/bind-email', auth, async (req, res) => {
	try {
		const { email, code } = req.body
		if (!email || !code) return res.json({ code: 400, msg: '请填写邮箱和验证码' })

		const [exist] = await db.query('SELECT id FROM users WHERE email = ? AND id != ?', [email, req.user.id])
		if (exist.length) return res.json({ code: 400, msg: '该邮箱已被其他账号绑定' })

		const valid = await verifyCode(email, code, 4)
		if (!valid) return res.json({ code: 400, msg: '验证码错误或已过期' })

		await db.query('UPDATE users SET email = ? WHERE id = ?', [email, req.user.id])
		res.json({ code: 200, msg: '邮箱绑定成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 修改密码
router.post('/change-password', auth, async (req, res) => {
	try {
		const { email, code, new_password } = req.body
		if (!email || !code || !new_password) return res.json({ code: 400, msg: '请填写完整信息' })
		if (new_password.length < 6) return res.json({ code: 400, msg: '密码至少6位' })

		const valid = await verifyCode(email, code, 3)
		if (!valid) return res.json({ code: 400, msg: '验证码错误或已过期' })

		const hash = await bcrypt.hash(new_password, 10)
		await db.query('UPDATE users SET password = ? WHERE id = ? AND email = ?', [hash, req.user.id, email])
		res.json({ code: 200, msg: '密码修改成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 修改邮箱（需验证码）
router.post('/change-email', auth, async (req, res) => {
	try {
		const { email, code } = req.body
		if (!email || !code) return res.json({ code: 400, msg: '请填写邮箱和验证码' })

		const [exist] = await db.query('SELECT id FROM users WHERE email = ? AND id != ?', [email, req.user.id])
		if (exist.length) return res.json({ code: 400, msg: '该邮箱已被其他账号绑定' })

		const valid = await verifyCode(email, code, 4)
		if (!valid) return res.json({ code: 400, msg: '验证码错误或已过期' })

		await db.query('UPDATE users SET email = ? WHERE id = ?', [email, req.user.id])
		res.json({ code: 200, msg: '邮箱修改成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 修改用户名
router.post('/change-username', auth, async (req, res) => {
	try {
		const { new_username } = req.body
		if (!new_username) return res.json({ code: 400, msg: '请输入新用户名' })
		if (new_username.length < 3 || new_username.length > 30) return res.json({ code: 400, msg: '用户名长度需在3-30位之间' })
		if (!/^[a-zA-Z0-9_.\-@]+$/.test(new_username)) return res.json({ code: 400, msg: '用户名只能包含英文、数字和符号 _ . - @' })

		const [userRows] = await db.query('SELECT username, username_changed_at FROM users WHERE id = ?', [req.user.id])
		if (!userRows.length) return res.json({ code: 404, msg: '用户不存在' })

		const user = userRows[0]
		if (user.username_changed_at) {
			const daysSince = (Date.now() - new Date(user.username_changed_at).getTime()) / (1000 * 60 * 60 * 24)
			if (daysSince < 90) {
				const remain = Math.ceil(90 - daysSince)
				return res.json({ code: 400, msg: `${remain}天后才能再次修改用户名` })
			}
		}

		const [exist] = await db.query('SELECT id FROM users WHERE username = ? AND id != ?', [new_username, req.user.id])
		if (exist.length) return res.json({ code: 400, msg: '该用户名已被占用' })

		await db.query('UPDATE users SET username = ?, username_changed_at = NOW() WHERE id = ?', [new_username, req.user.id])
		res.json({ code: 200, msg: '用户名修改成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取当前用户信息
router.get('/profile', auth, async (req, res) => {
	try {
		const [rows] = await db.query(
			'SELECT id,username,nickname,avatar,bg_image,email,bio,gender,birthday,location,role,fans_count,follow_count,like_count,collect_count,privacy_follows,privacy_fans,privacy_likes,privacy_activities,username_changed_at,created_at FROM users WHERE id = ?',
			[req.user.id]
		)
		if (!rows.length) return res.json({ code: 404, msg: '用户不存在' })
		const user = rows[0]
		// 添加留币和等级数据
		const { ensureUserRecords } = require('./coins')
		const { getLevelInfo } = require('./level-config')
		await ensureUserRecords(req.user.id)
		const [coinRows] = await db.query('SELECT balance FROM user_coins WHERE user_id = ?', [req.user.id])
		const [levelRows] = await db.query('SELECT exp FROM user_levels WHERE user_id = ?', [req.user.id])
		user.coins = coinRows[0]?.balance || 0
		user.level_info = levelRows.length ? getLevelInfo(levelRows[0].exp) : null
		res.json({ code: 200, data: user })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 更新个人资料（含性别、生日、隐私设置）
	router.put('/profile', auth, async (req, res) => {
	try {
		const allowed = ['nickname', 'avatar', 'bg_image', 'bio', 'gender', 'birthday', 'privacy_follows', 'privacy_fans', 'privacy_likes', 'privacy_activities']
		const sets = []
		const vals = []
		for (const key of allowed) {
			if (req.body[key] !== undefined) {
				let val = req.body[key]
				if (key === 'birthday') {
					if (val === '' || val === null) {
						val = null
					} else {
						const d = new Date(val)
						if (!isNaN(d.getTime())) {
							val = d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0')
						} else {
							val = null
						}
					}
				}
				sets.push(key + ' = ?')
				vals.push(val)
			}
		}
		if (!sets.length) return res.json({ code: 400, msg: '没有要更新的字段' })
		vals.push(req.user.id)
		await db.query('UPDATE users SET ' + sets.join(', ') + ' WHERE id = ?', vals)
		res.json({ code: 200, msg: '更新成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
