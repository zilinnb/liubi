const express = require('express')
const db = require('../config/db')
const redis = require('../config/redis')
const { auth } = require('../middleware/auth')
const { getIpLocation, getClientIp } = require('../utils/ip-location')
const { addExp } = require('./coins')
const { EXP_RULES } = require('./level-config')
const { getLevelInfo } = require('./level-config')
const { pushNotification } = require('../utils/ws-helper')
const router = express.Router()

// 提取话题标签
function extractTopics(text) {
	const matches = text.match(/#([^#\s]+)#/g) || []
	return matches.map(t => t.replace(/#/g, '').trim()).filter(t => t)
}

// 提取@用户
function extractMentions(text) {
	const matches = text.match(/@(\S+)/g) || []
	return matches.map(m => m.replace('@', '').trim()).filter(m => m)
}

// 处理@提及通知
async function processMentions(fromUserId, text, targetId, targetType) {
	const usernames = extractMentions(text)
	if (!usernames.length) return
	for (const name of usernames) {
		const [users] = await db.query('SELECT id FROM users WHERE (nickname = ? OR username = ?) AND status = 1', [name, name])
		if (users.length) {
			const toUserId = users[0].id
			if (toUserId !== fromUserId) {
				await db.query(
					'INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, 5, ?, ?)',
					[fromUserId, toUserId, '在笔记中提到了你', targetId]
				).catch(() => {})
				await db.query(
					'INSERT INTO mentions (from_user_id, to_user_id, target_id, target_type) VALUES (?, ?, ?, ?)',
					[fromUserId, toUserId, targetId, targetType]
				).catch(() => {})
			}
		}
	}
}

// 获取帖子列表 - 缓存30秒
router.get('/', async (req, res) => {
	try {
		const { category_id, page = 1, pageSize = 20, user_id, following, sort } = req.query
		const offset = (page - 1) * pageSize

		// 非个性化请求才缓存（无following、无user_id）
		const canCache = !following && !user_id
		const cacheKey = canCache ? `posts:list:${category_id || 'all'}:${page}:${pageSize}:${sort || 'latest'}` : null
		if (cacheKey) {
			const cached = await redis.get(cacheKey)
			if (cached) return res.json({ code: 200, data: cached })
		}
		let where = 'WHERE p.status = 1'
		const params = []

		if (category_id) { where += ' AND p.category_id = ?'; params.push(category_id) }

		let currentUserId = null
		const _token = req.headers.authorization?.replace('Bearer ', '')
		if (_token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const decoded = jwt.verify(_token, JWT_SECRET)
				currentUserId = decoded.id
			} catch {}
		}

		if (user_id) {
			where += ' AND p.user_id = ?'; params.push(user_id)
			if (Number(user_id) !== currentUserId) {
				where += ' AND (p.is_private = 0 OR p.is_private IS NULL)'
			}
		} else {
			if (currentUserId) {
				where += ' AND ((p.is_private = 0 OR p.is_private IS NULL) OR p.user_id = ?)'
				params.push(currentUserId)
			} else {
				where += ' AND (p.is_private = 0 OR p.is_private IS NULL)'
			}
		}

		if (following === '1') {
			const token = req.headers.authorization?.replace('Bearer ', '')
			if (token) {
				try {
					const jwt = require('jsonwebtoken')
					const { JWT_SECRET } = require('../config/env')
					const user = jwt.verify(token, JWT_SECRET)
					where += ' AND p.user_id IN (SELECT following_id FROM follows WHERE follower_id = ?)'
					params.push(user.id)
				} catch {}
			}
		}

		const orderMap = {
			latest: 'p.created_at DESC',
			hot: '(p.views_count * 1 + p.likes_count * 5 + p.collects_count * 3 + p.comments_count * 2) DESC, p.created_at DESC',
			random: 'RAND()',
		}
		const orderBy = orderMap[sort] || orderMap.latest

		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar, c.name as category_name
			FROM posts p
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN categories c ON p.category_id = c.id
			${where}
			ORDER BY ${orderBy}
			LIMIT ? OFFSET ?`,
			[...params, Number(pageSize), Number(offset)]
		)

		const postIds = rows.map(r => r.id)
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

		// 批量查询作者等级
		let levelMap = {}
		if (postIds.length) {
			const [levelRows] = await db.query('SELECT user_id, exp FROM user_levels WHERE user_id IN (?)', [rows.map(r => r.user_id)])
			levelRows.forEach(lr => { levelMap[lr.user_id] = getLevelInfo(lr.exp) })
		}

		const [countRows] = await db.query(`SELECT COUNT(*) as total FROM posts p ${where}`, params)

		const list = rows.map(r => ({
			...r,
			images: imgMap[r.id] || [],
			level_info: levelMap[r.user_id] || null,
			isLiked: false,
			isCollected: false
		}))

		const token = req.headers.authorization?.replace('Bearer ', '')
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const user = jwt.verify(token, JWT_SECRET)
				if (list.length) {
					const ids = list.map(p => p.id)
					const [likes] = await db.query(`SELECT target_id FROM likes WHERE user_id = ? AND target_type = 1 AND target_id IN (?)`, [user.id, ids])
					const [collects] = await db.query(`SELECT post_id FROM collects WHERE user_id = ? AND post_id IN (?)`, [user.id, ids])
					const likedSet = new Set(likes.map(l => l.target_id))
					const collectedSet = new Set(collects.map(c => c.post_id))
					list.forEach(p => { p.isLiked = likedSet.has(p.id); p.isCollected = collectedSet.has(p.id) })
				}
			} catch {}
		}

		const result = { list, total: countRows[0].total, page: Number(page), pageSize: Number(pageSize) }
		if (cacheKey) await redis.set(cacheKey, result, 30)
		res.json({ code: 200, data: result })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 搜索帖子
router.get('/search', async (req, res) => {
	try {
		const { keyword, page = 1, pageSize = 20, sort = 'default' } = req.query
		if (!keyword) return res.json({ code: 400, msg: '请输入关键词' })
		const offset = (page - 1) * pageSize

		db.query('INSERT INTO search_logs (keyword) VALUES (?)', [keyword.trim()]).catch(() => {})

		const orderMap = {
			default: 'p.created_at DESC',
			latest: 'p.created_at DESC',
			hot: '(p.views_count * 1 + p.likes_count * 5 + p.collects_count * 3 + p.comments_count * 2) DESC',
			most_liked: 'p.likes_count DESC',
		}
		const orderBy = orderMap[sort] || orderMap.default

		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar, c.name as category_name
			FROM posts p
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN categories c ON p.category_id = c.id
			WHERE p.status = 1 AND (p.is_private = 0 OR p.is_private IS NULL) AND (p.title LIKE ? OR p.content LIKE ? OR p.topics LIKE ?)
			ORDER BY ${orderBy} LIMIT ? OFFSET ?`,
			[`%${keyword}%`, `%${keyword}%`, `%${keyword}%`, Number(pageSize), Number(offset)]
		)

		const postIds = rows.map(r => r.id)
		let imgMap = {}
		if (postIds.length) {
			const [imgs] = await db.query(
				'SELECT post_id, image_url, video_url, media_type, sort_order FROM post_images WHERE post_id IN (?) ORDER BY sort_order',
				[postIds]
			)
			imgs.forEach(img => {
				if (!imgMap[img.post_id]) imgMap[img.post_id] = []
				imgMap[img.post_id].push({ url: img.image_url, type: img.media_type === 2 ? 'live' : 'image', video_url: img.video_url || '', ratio: img.ratio || 1.2 })
			})
		}

		const [countRows] = await db.query(
			`SELECT COUNT(*) as total FROM posts p WHERE p.status = 1 AND (p.is_private = 0 OR p.is_private IS NULL) AND (p.title LIKE ? OR p.content LIKE ? OR p.topics LIKE ?)`,
			[`%${keyword}%`, `%${keyword}%`, `%${keyword}%`]
		)

		// 批量查询作者等级
		const authorIds = [...new Set(rows.map(r => r.user_id))]
		const levelMap = {}
		if (authorIds.length) {
			const { getLevelInfo } = require('./level-config')
			const [lvlRows] = await db.query('SELECT user_id, exp FROM user_levels WHERE user_id IN (?)', [authorIds])
			lvlRows.forEach(l => { levelMap[l.user_id] = getLevelInfo(l.exp || 0) })
		}

		const list = rows.map(r => ({ ...r, images: imgMap[r.id] || [], isLiked: false, isCollected: false, level_info: levelMap[r.user_id] || null }))
		res.json({ code: 200, data: { list, total: countRows[0].total, page: Number(page), pageSize: Number(pageSize) } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 热门榜单 - 缓存120秒
router.get('/trending', async (req, res) => {
	try {
		const { type = 'hot', limit = 30 } = req.query
		const limitNum = Math.min(Number(limit) || 30, 100)

		const cacheKey = `posts:trending:${type}:${limitNum}`
		const cached = await redis.get(cacheKey)
		if (cached) return res.json({ code: 200, data: cached })

		let rows
		if (type === 'hot') {
			const [r] = await db.query(
				`SELECT p.id, p.title, p.content, p.post_type, p.voice_url, p.voice_duration, p.text_template,
					p.views_count, p.likes_count, p.collects_count, p.comments_count,
					u.nickname, u.avatar, c.name as category_name
				FROM posts p
				LEFT JOIN users u ON p.user_id = u.id
				LEFT JOIN categories c ON p.category_id = c.id
				WHERE p.status = 1 AND (p.is_private = 0 OR p.is_private IS NULL) AND p.created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
				ORDER BY (p.views_count * 1 + p.likes_count * 5 + p.collects_count * 3 + p.comments_count * 2) DESC
				LIMIT ?`,
				[limitNum]
			)
			rows = r
		} else if (type === 'latest') {
			const [r] = await db.query(
				`SELECT p.id, p.title, p.content, p.post_type, p.voice_url, p.voice_duration, p.text_template,
					p.views_count, p.likes_count, p.collects_count, p.comments_count,
					u.nickname, u.avatar, c.name as category_name
				FROM posts p
				LEFT JOIN users u ON p.user_id = u.id
				LEFT JOIN categories c ON p.category_id = c.id
				WHERE p.status = 1 AND (p.is_private = 0 OR p.is_private IS NULL)
				ORDER BY p.created_at DESC LIMIT ?`,
				[limitNum]
			)
			rows = r
		} else {
			const [r] = await db.query(
				`SELECT keyword, COUNT(*) as count FROM search_logs GROUP BY keyword ORDER BY count DESC LIMIT 20`
			)
			return res.json({ code: 200, data: r })
		}

		for (const post of rows) {
			const [imgs] = await db.query(
				'SELECT image_url as url, ratio FROM post_images WHERE post_id = ? ORDER BY sort_order',
				[post.id]
			)
			post.images = imgs
		}

		// 批量查询作者等级
		if (rows.length) {
			const userIds = [...new Set(rows.map(r => r.user_id))]
			const [levelRows] = await db.query('SELECT user_id, exp FROM user_levels WHERE user_id IN (?)', [userIds])
			const levelMap = {}
			levelRows.forEach(lr => { levelMap[lr.user_id] = getLevelInfo(lr.exp) })
			rows.forEach(r => { r.level_info = levelMap[r.user_id] || null })
		}

		await redis.set(cacheKey, rows, 120)
		res.json({ code: 200, data: rows })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取帖子详情
router.get('/:id', async (req, res) => {
	try {
		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar, u.bio, u.fans_count, u.gender, c.name as category_name
			FROM posts p
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN categories c ON p.category_id = c.id
			WHERE p.id = ? AND p.status = 1`,
			[req.params.id]
		)
		if (!rows.length) return res.json({ code: 404, msg: '帖子不存在' })

		const postRow = rows[0]
		if (postRow.is_private == 1) {
			const token = req.headers.authorization?.replace('Bearer ', '')
			let currentUserId = null
			if (token) {
				try {
					const jwt = require('jsonwebtoken')
					const { JWT_SECRET } = require('../config/env')
					const user = jwt.verify(token, JWT_SECRET)
					currentUserId = user.id
				} catch {}
			}
			if (currentUserId !== postRow.user_id) {
				return res.json({ code: 403, msg: '该图文已被对方私密，无法查看', data: { is_private: true, user_id: postRow.user_id, nickname: postRow.nickname, avatar: postRow.avatar } })
			}
		}

		db.query('UPDATE posts SET views_count = views_count + 1 WHERE id = ?', [req.params.id]).catch(() => {})

		const [imgs] = await db.query(
			'SELECT image_url, video_url, media_type, ratio, sort_order FROM post_images WHERE post_id = ? ORDER BY sort_order',
			[req.params.id]
		)
		const images = imgs.map(i => ({
			url: i.image_url,
			type: i.media_type === 2 ? 'live' : 'image',
			video_url: i.video_url || '',
			ratio: i.ratio || 1.2
		}))

		// 查询作者等级
		const [authorLevelRows] = await db.query('SELECT exp FROM user_levels WHERE user_id = ?', [postRow.user_id])
		const authorLevelInfo = authorLevelRows.length ? getLevelInfo(authorLevelRows[0].exp) : null

		const post = { ...rows[0], images, level_info: authorLevelInfo, isLiked: false, isCollected: false, is_followed: false, is_fan: false, redpacket: null }

		// 查询红包信息
		if (post.redpacket_id) {
			const [rpRows] = await db.query('SELECT id, total_coins, total_count, remaining_coins, remaining_count, message FROM coin_redpackets WHERE id = ?', [post.redpacket_id])
			if (rpRows.length) {
				post.redpacket = rpRows[0]
			}
		}

		if (post.content_blocks && typeof post.content_blocks === 'string') {
			try { post.content_blocks = JSON.parse(post.content_blocks) } catch (e) { post.content_blocks = null }
		}

		// 如果content_blocks为null，尝试从content和images重建
		if (!post.content_blocks && (post.content || post.images?.length)) {
			const synthetic = []
			if (post.content) synthetic.push({ type: 'text', content: post.content })
			if (post.images?.length) synthetic.push({ type: 'images', images: post.images.map(img => ({ url: img.url, type: img.type, video_url: img.video_url, ratio: img.ratio || 1.2 })), layout: 'grid' })
			if (post.link) synthetic.push({ type: 'link', url: post.link })
			post.content_blocks = synthetic
		}

		const token = req.headers.authorization?.replace('Bearer ', '')
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const user = jwt.verify(token, JWT_SECRET)
				const [lk] = await db.query('SELECT id FROM likes WHERE user_id=? AND target_id=? AND target_type=1', [user.id, post.id])
				const [cl] = await db.query('SELECT id FROM collects WHERE user_id=? AND post_id=?', [user.id, post.id])
				post.isLiked = lk.length > 0
				post.isCollected = cl.length > 0
				if (user.id !== post.user_id) {
					const [fl] = await db.query('SELECT id FROM follows WHERE follower_id=? AND following_id=?', [user.id, post.user_id])
					post.is_followed = fl.length > 0
					const [fan] = await db.query('SELECT id FROM follows WHERE follower_id=? AND following_id=?', [post.user_id, user.id])
					post.is_fan = fan.length > 0
				}
			} catch {}
		}

		res.json({ code: 200, data: post })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 发布帖子
router.post('/', auth, async (req, res) => {
	try {
		const { title, content, category_id, images, post_type, voice_url, voice_duration, text_template, link } = req.body
		if (!title) return res.json({ code: 400, msg: '标题必填' })
		if (!content && (!images || !images.length) && !voice_url) return res.json({ code: 400, msg: '内容必填' })

		if (category_id) {
			const [catRows] = await db.query('SELECT publish_restriction, min_level FROM categories WHERE id = ?', [category_id])
			if (catRows.length) {
				if (catRows[0].publish_restriction === 1 && req.user.role !== 1) {
					return res.json({ code: 403, msg: '该分类为官方分类，仅管理员可发布' })
				}
				if (catRows[0].min_level > 0 && req.user.role !== 1) {
					const { getLevelInfo } = require('./level-config')
					const [lvlRows] = await db.query('SELECT exp FROM user_levels WHERE user_id = ?', [req.user.id])
					const userLevel = getLevelInfo(lvlRows[0]?.exp || 0)
					if (userLevel.level < catRows[0].min_level) {
						return res.json({ code: 403, msg: `该分类需要Lv.${catRows[0].min_level}以上等级才能发布` })
					}
				}
			}
		}

		const topics = extractTopics(title + ' ' + (content || ''))
		const topicsStr = topics.join(',')

		const contentBlocks = req.body.content_blocks ? JSON.stringify(req.body.content_blocks) : null

		const clientIp = getClientIp(req)
		const location = await getIpLocation(clientIp)

		const redpacket_id = req.body.redpacket_id || null

		const [result] = await db.query(
			'INSERT INTO posts (user_id, title, content, content_blocks, category_id, location, topics, post_type, voice_url, voice_duration, text_template, link, redpacket_id, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
			[req.user.id, title, content || '', contentBlocks, category_id || null, location, topicsStr, post_type || 3, voice_url || '', voice_duration || 0, text_template || 0, link || '', redpacket_id]
		)

		// 更新红包的post_id关联
		if (redpacket_id) {
			await db.query('UPDATE coin_redpackets SET post_id = ? WHERE id = ?', [result.insertId, redpacket_id])
		}

		if (images && images.length) {
			const vals = images.map((img, i) => {
				const mediaType = img.type === 'live' ? 2 : 1
				return [result.insertId, img.url, mediaType, img.video_url || '', img.ratio || 1.2, i]
			})
			await db.query('INSERT INTO post_images (post_id, image_url, media_type, video_url, ratio, sort_order) VALUES ?', [vals])
		}

		if (category_id) {
			await db.query('UPDATE categories SET post_count = post_count + 1 WHERE id = ?', [category_id])
		}

		await db.query('INSERT INTO activities (user_id, type, target_id, target_type, content) VALUES (?, 1, ?, 1, ?)',
			[req.user.id, result.insertId, '发布了笔记'])

		await processMentions(req.user.id, title + ' ' + (content || ''), result.insertId, 1)

		await db.query('UPDATE users SET location = ? WHERE id = ?', [location, req.user.id])

		res.json({ code: 200, msg: '发布成功', data: { id: result.insertId } })
		addExp(req.user.id, EXP_RULES.post).catch(() => {})
		redis.del('posts:list:*').catch(() => {})
		redis.del('categories:all').catch(() => {})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 编辑帖子
router.put('/:id', auth, async (req, res) => {
	try {
		const { title, content, category_id, location, images, post_type, voice_url, voice_duration, text_template, link, content_blocks } = req.body
		const postId = req.params.id

		const [own] = await db.query('SELECT id, category_id FROM posts WHERE id = ? AND user_id = ?', [postId, req.user.id])
		if (!own.length) return res.json({ code: 403, msg: '无权编辑' })

		if (category_id && Number(category_id) !== own[0].category_id) {
			const [catRows] = await db.query('SELECT publish_restriction FROM categories WHERE id = ?', [category_id])
			if (catRows.length && catRows[0].publish_restriction === 1 && req.user.role !== 1) {
				return res.json({ code: 403, msg: '该分类为官方分类，仅管理员可发布' })
			}
		}

		const oldCatId = own[0].category_id
		const topics = extractTopics((title || '') + ' ' + (content || ''))
		const topicsStr = topics.join(',')
		const contentBlocks = content_blocks ? JSON.stringify(content_blocks) : null

		await db.query(
			'UPDATE posts SET title = ?, content = ?, content_blocks = ?, category_id = ?, location = ?, topics = ?, post_type = ?, voice_url = ?, voice_duration = ?, text_template = ?, link = ? WHERE id = ?',
			[title || '', content || '', contentBlocks, category_id || null, location || '', topicsStr, post_type || 3, voice_url || '', voice_duration || 0, text_template || 0, link || '', postId]
		)

		if (oldCatId !== Number(category_id)) {
			if (oldCatId) await db.query('UPDATE categories SET post_count = GREATEST(post_count - 1, 0) WHERE id = ?', [oldCatId])
			if (category_id) await db.query('UPDATE categories SET post_count = post_count + 1 WHERE id = ?', [category_id])
		}

		await db.query('DELETE FROM post_images WHERE post_id = ?', [postId])
		if (images && images.length) {
			const vals = images.map((img, i) => {
				const mediaType = img.type === 'live' ? 2 : 1
				return [postId, img.url, mediaType, img.video_url || '', img.ratio || 1.2, i]
			})
			await db.query('INSERT INTO post_images (post_id, image_url, media_type, video_url, ratio, sort_order) VALUES ?', [vals])
		}

		await processMentions(req.user.id, (title || '') + ' ' + (content || ''), postId, 1)

		res.json({ code: 200, msg: '编辑成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 点赞/取消点赞
router.post('/:id/like', auth, async (req, res) => {
	try {
		const postId = req.params.id
		const [exist] = await db.query('SELECT id FROM likes WHERE user_id=? AND target_id=? AND target_type=1', [req.user.id, postId])
		if (exist.length) {
			await db.query('DELETE FROM likes WHERE user_id=? AND target_id=? AND target_type=1', [req.user.id, postId])
			await db.query('UPDATE posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = ?', [postId])
			await db.query('UPDATE users SET like_count = GREATEST(like_count - 1, 0) WHERE id = (SELECT user_id FROM posts WHERE id = ?)', [postId])
			await db.query('DELETE FROM activities WHERE user_id = ? AND type = 2 AND target_id = ? AND target_type = 1', [req.user.id, postId])
			res.json({ code: 200, msg: '取消点赞', data: { liked: false } })
		} else {
			await db.query('INSERT INTO likes (user_id, target_id, target_type) VALUES (?, ?, 1)', [req.user.id, postId])
			await db.query('UPDATE posts SET likes_count = likes_count + 1 WHERE id = ?', [postId])
			await db.query('UPDATE users SET like_count = like_count + 1 WHERE id = (SELECT user_id FROM posts WHERE id = ?)', [postId])
			const [post] = await db.query('SELECT user_id FROM posts WHERE id = ?', [postId])
			if (post.length && post[0].user_id !== req.user.id) {
				await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, 1, ?, ?)',
					[req.user.id, post[0].user_id, '赞了你的笔记', postId])
				pushNotification(db, post[0].user_id, 1, req.user.id, postId)
			}
			// 记录活动
			await db.query('INSERT INTO activities (user_id, type, target_id, target_type, content) VALUES (?, 2, ?, 1, ?)',
				[req.user.id, postId, '赞了笔记'])
			res.json({ code: 200, msg: '点赞成功', data: { liked: true } })
		}
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 收藏/取消收藏
router.post('/:id/collect', auth, async (req, res) => {
	try {
		const postId = req.params.id
		const [exist] = await db.query('SELECT id FROM collects WHERE user_id=? AND post_id=?', [req.user.id, postId])
		if (exist.length) {
			await db.query('DELETE FROM collects WHERE user_id=? AND post_id=?', [req.user.id, postId])
			await db.query('UPDATE posts SET collects_count = GREATEST(collects_count - 1, 0) WHERE id = ?', [postId])
			await db.query('UPDATE users SET collect_count = GREATEST(collect_count - 1, 0) WHERE id = (SELECT user_id FROM posts WHERE id = ?)', [postId])
			await db.query('DELETE FROM activities WHERE user_id = ? AND type = 4 AND target_id = ? AND target_type = 1', [req.user.id, postId])
			res.json({ code: 200, msg: '取消收藏', data: { collected: false } })
		} else {
			await db.query('INSERT INTO collects (user_id, post_id) VALUES (?, ?)', [req.user.id, postId])
			await db.query('UPDATE posts SET collects_count = collects_count + 1 WHERE id = ?', [postId])
			await db.query('UPDATE users SET collect_count = collect_count + 1 WHERE id = (SELECT user_id FROM posts WHERE id = ?)', [postId])
			// 收藏通知
			const [post] = await db.query('SELECT user_id FROM posts WHERE id = ?', [postId])
			if (post.length && post[0].user_id !== req.user.id) {
				await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, 6, ?, ?)',
					[req.user.id, post[0].user_id, '收藏了你的笔记', postId])
				pushNotification(db, post[0].user_id, 6, req.user.id, postId)
			}
			// 记录活动
			await db.query('INSERT INTO activities (user_id, type, target_id, target_type, content) VALUES (?, 4, ?, 1, ?)',
				[req.user.id, postId, '收藏了笔记'])
			res.json({ code: 200, msg: '收藏成功', data: { collected: true } })
		}
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 置顶/取消置顶帖子（管理员）
router.post('/:id/pin', auth, async (req, res) => {
	try {
		if (req.user.role !== 1) return res.json({ code: 403, msg: '仅管理员可操作' })
		const postId = req.params.id
		const { category_id } = req.body
		if (!category_id) return res.json({ code: 400, msg: '请指定分类' })

		const [post] = await db.query('SELECT id, is_pinned, pinned_category_id FROM posts WHERE id = ? AND status = 1', [postId])
		if (!post.length) return res.json({ code: 404, msg: '帖子不存在' })

		if (Number(post[0].is_pinned) === 1 && post[0].pinned_category_id === Number(category_id)) {
			await db.query('UPDATE posts SET is_pinned = 0, pinned_at = NULL, pinned_category_id = NULL WHERE id = ?', [postId])
			res.json({ code: 200, msg: '取消置顶', data: { pinned: false } })
		} else {
			await db.query('UPDATE posts SET is_pinned = 1, pinned_at = NOW(), pinned_category_id = ? WHERE id = ?', [category_id, postId])
			res.json({ code: 200, msg: '置顶成功', data: { pinned: true } })
		}
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.post('/:id/private', auth, async (req, res) => {
	try {
		const postId = req.params.id
		const [post] = await db.query('SELECT id, is_private FROM posts WHERE id = ? AND user_id = ?', [postId, req.user.id])
		if (!post.length) return res.json({ code: 403, msg: '无权操作' })
		const newPrivate = Number(post[0].is_private) === 1 ? 0 : 1
		await db.query('UPDATE posts SET is_private = ? WHERE id = ?', [newPrivate, postId])
		res.json({ code: 200, msg: newPrivate === 1 ? '已设为私密' : '已设为公开', data: { is_private: newPrivate } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 删除帖子
router.delete('/:id', auth, async (req, res) => {
	try {
		const [post] = await db.query('SELECT category_id FROM posts WHERE id = ? AND user_id = ?', [req.params.id, req.user.id])
		if (!post.length) return res.json({ code: 403, msg: '无权删除' })
		await db.query('DELETE FROM posts WHERE id = ? AND user_id = ?', [req.params.id, req.user.id])
		if (post[0].category_id) {
			await db.query('UPDATE categories SET post_count = GREATEST(post_count - 1, 0) WHERE id = ?', [post[0].category_id])
		}
		await db.query('DELETE FROM activities WHERE target_id = ? AND target_type = 1', [req.params.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
