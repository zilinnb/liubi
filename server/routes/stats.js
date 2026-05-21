const express = require('express')
const router = express.Router()
const db = require('../config/db')

let _wsClients = null

function setWsClients(map) {
	_wsClients = map
}

router.get('/online', async (req, res) => {
	try {
		const [userRows] = await db.query('SELECT COUNT(*) as total FROM users WHERE status = 1')
		const [postRows] = await db.query('SELECT COUNT(*) as total FROM posts WHERE status = 1')
		const [commentRows] = await db.query('SELECT COUNT(*) as total FROM comments')
		let onlineCount = 0
		if (_wsClients) {
			onlineCount = _wsClients.size
		}
		res.json({
			code: 200,
			data: {
				online_count: onlineCount,
				total_users: userRows[0].total,
				total_posts: postRows[0].total,
				total_comments: commentRows[0].total,
			}
		})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.get('/overview', async (req, res) => {
	try {
		const [userRows] = await db.query('SELECT COUNT(*) as total FROM users WHERE status = 1')
		const [postRows] = await db.query('SELECT COUNT(*) as total FROM posts WHERE status = 1')
		const [commentRows] = await db.query('SELECT COUNT(*) as total FROM comments')
		const [catRows] = await db.query('SELECT COUNT(*) as total FROM categories')
		const [todayPostRows] = await db.query('SELECT COUNT(*) as total FROM posts WHERE status = 1 AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)')
		const [todayUserRows] = await db.query('SELECT COUNT(*) as total FROM users WHERE created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)')
		let onlineCount = 0
		if (_wsClients) {
			onlineCount = _wsClients.size
		}
		// 数据库连接测试
		let dbStatus = 'connected'
		try {
			await db.query('SELECT 1')
		} catch (e) {
			dbStatus = 'disconnected'
		}
		res.json({
			code: 200,
			data: {
				online_count: onlineCount,
				total_users: userRows[0].total,
				total_posts: postRows[0].total,
				total_comments: commentRows[0].total,
				total_categories: catRows[0].total,
				today_posts: todayPostRows[0].total,
				today_users: todayUserRows[0].total,
				node_version: process.version,
				db_status: dbStatus,
				server_time: new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' }),
				uptime: Math.floor(process.uptime() / 3600) + 'h',
			}
		})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = { router, setWsClients }
