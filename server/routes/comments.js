const express = require('express')
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const { getIpLocation, getClientIp } = require('../utils/ip-location')
const { addExp } = require('./coins')
const { EXP_RULES, getLevelInfo } = require('./level-config')
const { pushNotification } = require('../utils/ws-helper')
const router = express.Router()

// 提取@用户
function extractMentions(text) {
	const matches = text.match(/@(\S+)/g) || []
	return matches.map(m => m.replace('@', '').trim()).filter(m => m)
}

// 处理@提及通知
async function processMentions(fromUserId, text, postId, commentId) {
	const usernames = extractMentions(text)
	if (!usernames.length) return
	for (const name of usernames) {
		const [users] = await db.query('SELECT id FROM users WHERE (nickname = ? OR username = ?) AND status = 1', [name, name])
		if (users.length) {
			const toUserId = users[0].id
			if (toUserId !== fromUserId) {
				await db.query(
					'INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, 5, ?, ?)',
					[fromUserId, toUserId, '在评论中提到了你', postId]
				).catch(() => {})
				await db.query(
					'INSERT INTO mentions (from_user_id, to_user_id, target_id, target_type) VALUES (?, ?, ?, 2)',
					[fromUserId, toUserId, commentId]
				).catch(() => {})
			}
		}
	}
}

// 获取帖子评论
router.get('/post/:postId', async (req, res) => {
	try {
		const sort = req.query.sort || 'latest'
		const page = Math.max(1, parseInt(req.query.page) || 1)
		const pageSize = Math.min(50, Math.max(1, parseInt(req.query.pageSize) || 20))
		const offset = (page - 1) * pageSize
		let orderClause
		if (sort === 'hot') {
			orderClause = 'c.is_pinned DESC, c.likes_count DESC, c.created_at DESC'
		} else {
			orderClause = 'c.is_pinned DESC, c.created_at DESC'
		}

		const [rows] = await db.query(
			`SELECT c.*, u.nickname, u.avatar
			FROM comments c
			LEFT JOIN users u ON c.user_id = u.id
			WHERE c.post_id = ? AND c.status = 1
			ORDER BY ${orderClause}
			LIMIT ? OFFSET ?`,
			[req.params.postId, pageSize, offset]
		)

		const [[countRow]] = await db.query('SELECT COUNT(*) as total FROM comments WHERE post_id = ? AND status = 1', [req.params.postId])

		const token = req.headers.authorization?.replace('Bearer ', '')
		let likedSet = new Set()
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const user = jwt.verify(token, JWT_SECRET)
				if (rows.length) {
					const ids = rows.map(r => r.id)
					const [likes] = await db.query('SELECT target_id FROM likes WHERE user_id=? AND target_type=2 AND target_id IN (?)', [user.id, ids])
					likedSet = new Set(likes.map(l => l.target_id))
				}
			} catch {}
		}

		const replyToUserIds = new Set()
		rows.forEach(r => {
			if (r.reply_to_user_id) replyToUserIds.add(r.reply_to_user_id)
		})
		let replyToUserMap = {}
		if (replyToUserIds.size) {
			const [replyUsers] = await db.query('SELECT id, nickname FROM users WHERE id IN (?)', [[...replyToUserIds]])
			replyUsers.forEach(u => { replyToUserMap[u.id] = u.nickname })
		}

		// 批量查询评论者等级
		const commenterIds = [...new Set(rows.map(r => r.user_id))]
		let commentLevelMap = {}
		if (commenterIds.length) {
			const [levelRows] = await db.query('SELECT user_id, exp FROM user_levels WHERE user_id IN (?)', [commenterIds])
			levelRows.forEach(lr => { commentLevelMap[lr.user_id] = getLevelInfo(lr.exp) })
		}

		const map = {}
		const list = []
		rows.forEach(r => {
			// 解析images JSON
			let imagesList = []
			if (r.images) {
				try { imagesList = typeof r.images === 'string' ? JSON.parse(r.images) : r.images } catch { imagesList = [] }
			} else if (r.image_url) {
				imagesList = [{ url: r.image_url, video_url: '', media_type: 1 }]
			}
			const item = {
				...r,
				is_pinned: Number(r.is_pinned) || 0,
				images: imagesList,
				subComments: [],
				isLiked: likedSet.has(r.id),
				reply_to_nickname: r.reply_to_user_id ? (replyToUserMap[r.reply_to_user_id] || '') : '',
				level_info: commentLevelMap[r.user_id] || null,
			}
			map[r.id] = item
		})
		rows.forEach(r => {
			if (r.parent_id && map[r.parent_id]) {
				map[r.parent_id].subComments.push(map[r.id])
			} else if (!r.parent_id) {
				list.push(map[r.id])
			}
		})

		res.json({ code: 200, data: { list, total: countRow.total, page, pageSize } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 发表评论（支持多图、实况、@提及）
router.post('/', auth, async (req, res) => {
	try {
		const { post_id, parent_id, content, image_url, images, voice_url, voice_duration, reply_to_user_id } = req.body
		if (!post_id || (!content && !image_url && !images && !voice_url)) return res.json({ code: 400, msg: '参数不完整' })

		const clientIp = getClientIp(req)
		const location = await getIpLocation(clientIp)

		// 处理images字段：支持数组格式 [{url, video_url, media_type}]
		let imagesJson = null
		if (images && Array.isArray(images) && images.length > 0) {
			imagesJson = JSON.stringify(images)
		} else if (image_url) {
			// 兼容旧的单图格式
			imagesJson = JSON.stringify([{ url: image_url, video_url: '', media_type: 1 }])
		}

		const [result] = await db.query(
			'INSERT INTO comments (post_id, user_id, parent_id, content, image_url, images, voice_url, voice_duration, location, reply_to_user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
			[post_id, req.user.id, parent_id || null, content || '', image_url || '', imagesJson, voice_url || '', voice_duration || 0, location, reply_to_user_id || null]
		)
		await db.query('UPDATE posts SET comments_count = comments_count + 1 WHERE id = ?', [post_id])

		await db.query('UPDATE users SET location = ? WHERE id = ?', [location, req.user.id])

		// 通知
		if (parent_id) {
			const [parent] = await db.query('SELECT user_id FROM comments WHERE id = ?', [parent_id])
			if (parent.length && parent[0].user_id !== req.user.id) {
				await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content, target_id, comment_id) VALUES (?, ?, 2, ?, ?, ?)',
					[req.user.id, parent[0].user_id, '回复了你的评论', post_id, result.insertId])
				pushNotification(db, parent[0].user_id, 2, req.user.id, post_id, result.insertId)
			}
		} else {
			const [post] = await db.query('SELECT user_id FROM posts WHERE id = ?', [post_id])
			if (post.length && post[0].user_id !== req.user.id) {
				await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content, target_id, comment_id) VALUES (?, ?, 2, ?, ?, ?)',
					[req.user.id, post[0].user_id, '评论了你的笔记', post_id, result.insertId])
				pushNotification(db, post[0].user_id, 2, req.user.id, post_id, result.insertId)
			}
		}

		// 记录活动
		await db.query('INSERT INTO activities (user_id, type, target_id, target_type, content) VALUES (?, 3, ?, 1, ?)',
			[req.user.id, post_id, '评论了笔记'])

		// 处理@提及
		if (content) {
			await processMentions(req.user.id, content, post_id, result.insertId)
		}

		res.json({ code: 200, msg: '评论成功', data: { id: result.insertId, location } })
		addExp(req.user.id, EXP_RULES.comment, 2, '发表评论').catch(() => {})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 删除评论
router.delete('/:id', auth, async (req, res) => {
	try {
		const [comment] = await db.query('SELECT post_id, user_id, is_pinned FROM comments WHERE id = ?', [req.params.id])
		if (!comment.length) return res.json({ code: 404, msg: '评论不存在' })
		const isOwner = comment[0].user_id === req.user.id
		const [post] = await db.query('SELECT user_id FROM posts WHERE id = ?', [comment[0].post_id])
		const isPostAuthor = post.length && post[0].user_id === req.user.id
		if (!isOwner && !isPostAuthor) return res.json({ code: 403, msg: '无权删除' })
		await db.query('DELETE FROM comments WHERE id = ?', [req.params.id])
		await db.query('UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = ?', [comment[0].post_id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 置顶/取消置顶评论
router.post('/:id/pin', auth, async (req, res) => {
	try {
		const [comment] = await db.query('SELECT post_id, user_id, is_pinned FROM comments WHERE id = ?', [req.params.id])
		if (!comment.length) return res.json({ code: 404, msg: '评论不存在' })
		const [post] = await db.query('SELECT user_id FROM posts WHERE id = ?', [comment[0].post_id])
		if (!post.length || post[0].user_id !== req.user.id) return res.json({ code: 403, msg: '仅帖子作者可置顶' })
		const currentPinned = Number(comment[0].is_pinned) || 0
		const newPinned = currentPinned === 1 ? 0 : 1
		if (newPinned === 1) {
			await db.query('UPDATE comments SET is_pinned = 0 WHERE post_id = ? AND is_pinned = 1', [comment[0].post_id])
		}
		await db.query('UPDATE comments SET is_pinned = ? WHERE id = ?', [newPinned, req.params.id])
		res.json({ code: 200, msg: newPinned === 1 ? '已置顶' : '已取消置顶', data: { pinned: newPinned === 1 } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.post('/:id/like', auth, async (req, res) => {
	try {
		const commentId = req.params.id
		const [exist] = await db.query('SELECT id FROM likes WHERE user_id=? AND target_id=? AND target_type=2', [req.user.id, commentId])
		if (exist.length) {
			await db.query('DELETE FROM likes WHERE user_id=? AND target_id=? AND target_type=2', [req.user.id, commentId])
			await db.query('UPDATE comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = ?', [commentId])
			res.json({ code: 200, msg: '取消点赞', data: { liked: false } })
		} else {
			await db.query('INSERT INTO likes (user_id, target_id, target_type) VALUES (?, ?, 2)', [req.user.id, commentId])
			await db.query('UPDATE comments SET likes_count = likes_count + 1 WHERE id = ?', [commentId])
			res.json({ code: 200, msg: '点赞成功', data: { liked: true } })
		}
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
