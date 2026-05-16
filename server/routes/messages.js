const express = require('express')
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const router = express.Router()

// 获取我的消息列表
router.get('/', auth, async (req, res) => {
	try {
		const { type, page = 1, pageSize = 20 } = req.query
		const offset = (page - 1) * pageSize
		let where = 'WHERE m.to_user_id = ?'
		const params = [req.user.id]

		if (type) { where += ' AND m.type = ?'; params.push(type) }

		const [rows] = await db.query(
			`SELECT m.*, u.nickname as from_nickname, u.avatar as from_avatar
			FROM messages m
			LEFT JOIN users u ON m.from_user_id = u.id
			${where}
			ORDER BY m.created_at DESC
			LIMIT ? OFFSET ?`,
			[...params, Number(pageSize), Number(offset)]
		)

		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 标记已读
router.put('/read', auth, async (req, res) => {
	try {
		await db.query('UPDATE messages SET is_read = 1 WHERE to_user_id = ? AND is_read = 0', [req.user.id])
		res.json({ code: 200, msg: '已全部标记已读' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 未读数量
router.get('/unread', auth, async (req, res) => {
	try {
		const [rows] = await db.query('SELECT COUNT(*) as count FROM messages WHERE to_user_id = ? AND is_read = 0', [req.user.id])
		res.json({ code: 200, data: { count: rows[0].count } })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
