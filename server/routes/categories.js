const express = require('express')
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const router = express.Router()

// 获取所有分类（含统计数据）
router.get('/', async (req, res) => {
	try {
		const [rows] = await db.query('SELECT * FROM categories WHERE status = 1 ORDER BY sort_order ASC')
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取分类详情（贴吧风格）
router.get('/:id', async (req, res) => {
	try {
		const [rows] = await db.query('SELECT * FROM categories WHERE id = ? AND status = 1', [req.params.id])
		if (!rows.length) return res.json({ code: 404, msg: '分类不存在' })

		const cat = rows[0]

		// 热度计算: 帖子数*1 + 点赞*3 + 评论*2 + 收藏*1.5
		const [heatRow] = await db.query(
			`SELECT COALESCE(SUM(p.views_count * 0.1 + p.likes_count * 3 + p.comments_count * 2 + p.collects_count * 1.5), 0) as heat
			FROM posts p WHERE p.category_id = ? AND p.status = 1`,
			[cat.id]
		)
		cat.heat = Math.round(heatRow[0].heat)

		// 本分类发帖用户数
		const [userCount] = await db.query(
			'SELECT COUNT(DISTINCT user_id) as count FROM posts WHERE category_id = ? AND status = 1',
			[cat.id]
		)
		cat.author_count = userCount[0].count

		// 当前用户是否关注了该分类
		cat.is_followed = false
		const token = req.headers.authorization?.replace('Bearer ', '')
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const me = jwt.verify(token, JWT_SECRET)
				const [f] = await db.query('SELECT id FROM category_follows WHERE user_id = ? AND category_id = ?', [me.id, cat.id])
				cat.is_followed = f.length > 0
			} catch {}
		}

		// 该分类下的热门帖子
		const [hotPosts] = await db.query(
			`SELECT p.id, p.title, p.likes_count, p.comments_count, p.views_count, p.created_at, u.nickname, u.avatar,
				(SELECT image_url FROM post_images WHERE post_id = p.id ORDER BY sort_order LIMIT 1) as cover
			FROM posts p LEFT JOIN users u ON p.user_id = u.id
			WHERE p.category_id = ? AND p.status = 1
			ORDER BY (p.views_count * 0.1 + p.likes_count * 3 + p.comments_count * 2 + p.collects_count * 1.5) DESC
			LIMIT 10`,
			[cat.id]
		)
		cat.hot_posts = hotPosts

		// 最近发帖
		const [recentPosts] = await db.query(
			`SELECT p.id, p.title, p.likes_count, p.comments_count, p.views_count, p.created_at, u.nickname, u.avatar
			FROM posts p LEFT JOIN users u ON p.user_id = u.id
			WHERE p.category_id = ? AND p.status = 1
			ORDER BY p.created_at DESC LIMIT 10`,
			[cat.id]
		)
		cat.recent_posts = recentPosts

		res.json({ code: 200, data: cat })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 关注/取关分类
router.post('/:id/follow', auth, async (req, res) => {
	try {
		const catId = req.params.id
		const [exist] = await db.query('SELECT id FROM category_follows WHERE user_id = ? AND category_id = ?', [req.user.id, catId])
		if (exist.length) {
			await db.query('DELETE FROM category_follows WHERE user_id = ? AND category_id = ?', [req.user.id, catId])
			await db.query('UPDATE categories SET follow_count = GREATEST(follow_count - 1, 0) WHERE id = ?', [catId])
			res.json({ code: 200, data: { followed: false } })
		} else {
			await db.query('INSERT INTO category_follows (user_id, category_id) VALUES (?, ?)', [req.user.id, catId])
			await db.query('UPDATE categories SET follow_count = follow_count + 1 WHERE id = ?', [catId])
			res.json({ code: 200, data: { followed: true } })
		}
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取分类下的帖子列表（分页）
router.get('/:id/posts', async (req, res) => {
	try {
		const { page = 1, pageSize = 20, sort = 'latest' } = req.query
		const offset = (page - 1) * pageSize

		const orderMap = {
			latest: 'p.created_at DESC',
			hot: '(p.views_count * 0.1 + p.likes_count * 3 + p.comments_count * 2 + p.collects_count * 1.5) DESC',
			most_liked: 'p.likes_count DESC',
		}
		const orderBy = orderMap[sort] || orderMap.latest

		const [pinnedRows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar FROM posts p LEFT JOIN users u ON p.user_id = u.id
			WHERE p.category_id = ? AND p.status = 1 AND p.is_pinned = 1 AND p.pinned_category_id = ?
			ORDER BY p.pinned_at DESC`,
			[req.params.id, req.params.id]
		)

		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar FROM posts p LEFT JOIN users u ON p.user_id = u.id
			WHERE p.category_id = ? AND p.status = 1 AND (p.is_pinned = 0 OR p.pinned_category_id != ? OR p.pinned_category_id IS NULL)
			ORDER BY ${orderBy} LIMIT ? OFFSET ?`,
			[req.params.id, req.params.id, Number(pageSize), Number(offset)]
		)

		const allRows = [...pinnedRows, ...rows]
		const postIds = allRows.map(r => r.id)
		let imgMap = {}
		if (postIds.length) {
			const [imgs] = await db.query(
				'SELECT post_id, image_url, video_url, media_type, ratio, sort_order FROM post_images WHERE post_id IN (?) ORDER BY sort_order',
				[postIds]
			)
			imgs.forEach(img => {
				if (!imgMap[img.post_id]) imgMap[img.post_id] = []
				imgMap[img.post_id].push({
					url: img.image_url,
					type: img.media_type === 2 ? 'live' : 'image',
					video_url: img.video_url || '',
					ratio: img.ratio || 1.2
				})
			})
		}

		const pinnedIds = new Set(pinnedRows.map(r => r.id))
		const list = allRows.map(r => {
			const imgs = imgMap[r.id] || []
			return {
				...r,
				cover: imgs.length ? imgs[0].url : '',
				images: imgs,
				isLiked: false,
				isCollected: false,
				is_pinned: pinnedIds.has(r.id) ? 1 : 0
			}
		})
		const [countRows] = await db.query('SELECT COUNT(*) as total FROM posts WHERE category_id = ? AND status = 1', [req.params.id])

		res.json({ code: 200, data: { list, pinned_count: pinnedRows.length, total: countRows[0].total, page: Number(page), pageSize: Number(pageSize) } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
