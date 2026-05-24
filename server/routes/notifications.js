const express = require('express')
const router = express.Router()
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const { sendNotificationEmail } = require('../utils/mailer')

router.get('/', auth, async (req, res) => {
	try {
		const { type } = req.query
		const page = Math.max(1, parseInt(req.query.page) || 1)
		const pageSize = Math.min(50, Math.max(1, parseInt(req.query.pageSize) || 20))
		const offset = (page - 1) * pageSize

		// 构建条件
		let whereSql = 'm.to_user_id = ?'
		const baseParams = [req.user.id]
		if (type && type !== '0') {
			const types = String(type).split(',').map(t => parseInt(t)).filter(t => !isNaN(t))
			if (types.length === 1) {
				whereSql += ' AND m.type = ?'
				baseParams.push(types[0])
			} else if (types.length > 1) {
				whereSql += ' AND m.type IN (?)'
				baseParams.push(types)
			}
		}

		// 查总数
		const [[totalRow]] = await db.query(`SELECT COUNT(*) as total FROM messages m WHERE ${whereSql}`, baseParams)

		// 查列表
		const [rows] = await db.query(
			`SELECT m.*, u.nickname as from_nickname, u.avatar as from_avatar FROM messages m LEFT JOIN users u ON m.from_user_id = u.id WHERE ${whereSql} ORDER BY m.created_at DESC LIMIT ? OFFSET ?`,
			[...baseParams, pageSize, offset]
		)

		res.json({ code: 200, data: { list: rows, total: totalRow.total, page, pageSize } })
	} catch(e) {
		console.error('get notifications error:', e)
		res.json({ code: 500, msg: '获取通知失败' })
	}
})

router.get('/unread', auth, async (req, res) => {
	try {
		const [countRows] = await db.query(
			'SELECT COUNT(*) as count, SUM(CASE WHEN type IN (1,6) THEN 1 ELSE 0 END) as like_count, SUM(CASE WHEN type = 2 THEN 1 ELSE 0 END) as comment_count, SUM(CASE WHEN type = 3 THEN 1 ELSE 0 END) as follow_count FROM messages WHERE to_user_id = ? AND is_read = 0',
			[req.user.id]
		)
		const d = countRows[0]
			res.json({ code: 200, data: { count: Number(d.count)||0, like_count: Number(d.like_count)||0, comment_count: Number(d.comment_count)||0, follow_count: Number(d.follow_count)||0 } })
	} catch(e) {
		console.error('get unread error:', e)
		res.json({ code: 500, msg: '获取未读数失败' })
	}
})

router.post('/:id/read', auth, async (req, res) => {
	try {
		await db.query('UPDATE messages SET is_read = 1 WHERE id = ? AND to_user_id = ?', [req.params.id, req.user.id])
		res.json({ code: 200, msg: 'ok' })
	} catch(e) {
		console.error('read notification error:', e)
		res.json({ code: 500, msg: '操作失败' })
	}
})

router.post('/read-all', auth, async (req, res) => {
	try {
		const { type } = req.query
		if (type && type !== '0') {
			const types = String(type).split(',').map(t => parseInt(t)).filter(t => !isNaN(t))
			if (types.length === 1) {
				await db.query('UPDATE messages SET is_read = 1 WHERE to_user_id = ? AND type = ?', [req.user.id, types[0]])
			} else if (types.length > 1) {
				await db.query('UPDATE messages SET is_read = 1 WHERE to_user_id = ? AND type IN (?)', [req.user.id, types])
			}
		} else {
			await db.query('UPDATE messages SET is_read = 1 WHERE to_user_id = ?', [req.user.id])
		}
		res.json({ code: 200, msg: 'ok' })
	} catch(e) {
		console.error('read all error:', e)
		res.json({ code: 500, msg: '操作失败' })
	}
})

router.get('/email-settings', auth, async (req, res) => {
	try {
		const [rows] = await db.query('SELECT email_notify, email FROM users WHERE id = ?', [req.user.id])
		if (!rows.length) return res.json({ code: 404, msg: '用户不存在' })
		const row = rows[0]
		res.json({ code: 200, data: { email_notify: row.email_notify || 0, email: row.email || '' } })
	} catch(e) {
		console.error('get email settings error:', e)
		res.json({ code: 500, msg: '获取邮件设置失败' })
	}
})

router.post('/email-settings', auth, async (req, res) => {
	try {
		const { email_notify } = req.body
		if (typeof email_notify === 'undefined') return res.json({ code: 400, msg: '参数缺失' })
		const [rows] = await db.query('SELECT email FROM users WHERE id = ?', [req.user.id])
		if (!rows.length) return res.json({ code: 404, msg: '用户不存在' })
		if (email_notify === 1 && !rows[0].email) return res.json({ code: 400, msg: '请先绑定邮箱' })
		await db.query('UPDATE users SET email_notify = ? WHERE id = ?', [email_notify ? 1 : 0, req.user.id])
		res.json({ code: 200, msg: 'ok' })
	} catch(e) {
		console.error('update email settings error:', e)
		res.json({ code: 500, msg: '更新邮件设置失败' })
	}
})

async function createNotification(toUserId, fromUserId, type, content, targetId) {
	if (!toUserId || !fromUserId || toUserId === fromUserId) return
	const [exists] = await db.query('SELECT id FROM messages WHERE to_user_id = ? AND from_user_id = ? AND type = ? AND target_id = ? AND is_read = 0', [toUserId, fromUserId, type, targetId || 0])
	if (exists.length > 0) return
	await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, ?, ?, ?)', [fromUserId, toUserId, type, content || '', targetId || null])

	if ([1, 2, 3, 6].includes(type)) {
		try {
			const [targetRows] = await db.query('SELECT email_notify, email FROM users WHERE id = ?', [toUserId])
			const [fromRows] = await db.query('SELECT nickname FROM users WHERE id = ?', [fromUserId])
			if (targetRows.length && targetRows[0].email_notify === 1 && targetRows[0].email) {
				let targetTitle = ''
				if (targetId && [1, 2, 6].includes(type)) {
					const [postRows] = await db.query('SELECT title FROM posts WHERE id = ?', [targetId])
					if (postRows.length) targetTitle = postRows[0].title
				}
				const fromUserName = fromRows.length ? fromRows[0].nickname : '用户'
				sendNotificationEmail(db, targetRows[0].email, fromUserName, type, targetTitle, content || '')
			}
		} catch(e) {
			console.error('send notification email error:', e)
		}
	}
}

module.exports = { router, createNotification }
