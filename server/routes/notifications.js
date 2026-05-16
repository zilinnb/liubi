const express = require('express')
const router = express.Router()
const db = require('../config/db')
const { auth } = require('../middleware/auth')

router.get('/', auth, async (req, res) => {
	try {
		const { type } = req.query
		let sql = `SELECT m.*, u.nickname as from_nickname, u.avatar as from_avatar FROM messages m LEFT JOIN users u ON m.from_user_id = u.id WHERE m.to_user_id = ?`
		const params = [req.user.id]

		if (type && type !== '0') {
			const types = String(type).split(',').map(t => parseInt(t)).filter(t => !isNaN(t))
			if (types.length === 1) {
				sql += ' AND m.type = ?'
				params.push(types[0])
			} else if (types.length > 1) {
				sql += ' AND m.type IN (?)'
				params.push(types)
			}
		}

		sql += ' ORDER BY m.created_at DESC LIMIT 50'
		const [rows] = await db.query(sql, params)
		res.json({ code: 200, data: rows })
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

async function createNotification(toUserId, fromUserId, type, content, targetId) {
	if (!toUserId || !fromUserId || toUserId === fromUserId) return
	const [exists] = await db.query('SELECT id FROM messages WHERE to_user_id = ? AND from_user_id = ? AND type = ? AND target_id = ? AND is_read = 0', [toUserId, fromUserId, type, targetId || 0])
	if (exists.length > 0) return
	await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, ?, ?, ?)', [fromUserId, toUserId, type, content || '', targetId || null])
}

module.exports = { router, createNotification }
