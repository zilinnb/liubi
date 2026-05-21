const express = require('express')
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const { ensureUserRecords } = require('./coins')
const { getLevelInfo } = require('./level-config')
const { pushNotification } = require('../utils/ws-helper')
const { sendMail } = require('../utils/mailer')
const router = express.Router()

// 搜索用户
router.get('/search', auth, async (req, res) => {
	try {
		const { keyword } = req.query
		if (!keyword) return res.json({ code: 400, msg: '请输入关键词' })
		const [rows] = await db.query(
			'SELECT id, username, nickname, avatar, bg_image, bio FROM users WHERE status = 1 AND (nickname LIKE ? OR username LIKE ?) LIMIT 20',
			[`%${keyword}%`, `%${keyword}%`]
		)
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 推荐用户（必须在 /:id 之前）
router.get('/recommend', auth, async (req, res) => {
	try {
		const [myFollows] = await db.query(
			'SELECT following_id FROM follows WHERE follower_id = ?',
			[req.user.id]
		)
		const followIds = myFollows.map(f => f.following_id)

		const [rows] = await db.query(
			`SELECT id, username, nickname, avatar, bio, fans_count, role FROM users WHERE status = 1 AND id != ? ORDER BY role DESC, fans_count DESC LIMIT 10`,
			[req.user.id]
		)

		const myFollowSet = new Set(followIds)
		const [myFans] = await db.query(
			'SELECT follower_id FROM follows WHERE following_id = ?',
			[req.user.id]
		)
		const myFanSet = new Set(myFans.map(f => f.follower_id))

		rows.forEach(u => {
			u.is_followed = myFollowSet.has(u.id)
			u.is_fan = myFanSet.has(u.id)
		})

		// 批量查询推荐用户等级
		const recommendIds = rows.map(u => u.id)
		let recommendLevelMap = {}
		if (recommendIds.length) {
			const [levelRows] = await db.query('SELECT user_id, exp FROM user_levels WHERE user_id IN (?)', [recommendIds])
			levelRows.forEach(lr => { recommendLevelMap[lr.user_id] = getLevelInfo(lr.exp) })
		}
		rows.forEach(u => {
			u.level_info = recommendLevelMap[u.id] || null
		})

		res.json({ code: 200, data: rows })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// @搜索用户（必须在 /:id 之前）
router.get('/mention-search', auth, async (req, res) => {
	try {
		const { keyword } = req.query
		if (!keyword) return res.json({ code: 200, data: [] })
		const [rows] = await db.query(
			'SELECT id, username, nickname, avatar FROM users WHERE status = 1 AND (nickname LIKE ? OR username LIKE ?) LIMIT 10',
			[`%${keyword}%`, `%${keyword}%`]
		)
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取关注状态（必须在 /:id 之前）
router.get('/:id/follow-status', auth, async (req, res) => {
	try {
		const targetId = req.params.id
		const [follow] = await db.query(
			'SELECT id FROM follows WHERE follower_id = ? AND following_id = ?',
			[req.user.id, targetId]
		)
		const [fan] = await db.query(
			'SELECT id FROM follows WHERE follower_id = ? AND following_id = ?',
			[targetId, req.user.id]
		)
		res.json({ code: 200, data: { is_followed: follow.length > 0, is_fan: fan.length > 0 } })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户信息（含隐私控制）
router.get('/:id', async (req, res) => {
	try {
		const [rows] = await db.query(
			'SELECT id,username,nickname,avatar,bg_image,bio,gender,birthday,location,fans_count,follow_count,like_count,collect_count,privacy_follows,privacy_fans,privacy_likes,privacy_activities,created_at FROM users WHERE id = ? AND status = 1',
			[req.params.id]
		)
		if (!rows.length) return res.json({ code: 404, msg: '用户不存在' })

		const user = rows[0]
		user.is_followed = false
			user.is_fan = false
		user.can_see_follows = true
		user.can_see_fans = true
		user.can_see_likes = true
		user.can_see_activities = true

		const token = req.headers.authorization?.replace('Bearer ', '')
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const me = jwt.verify(token, JWT_SECRET)
				const [follow] = await db.query('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [me.id, req.params.id])
				user.is_followed = follow.length > 0
				const [fan] = await db.query('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [req.params.id, me.id])
				user.is_fan = fan.length > 0
				const isSelf = me.id === Number(req.params.id)
				if (!isSelf) {
					user.can_see_follows = user.privacy_follows === 0
					user.can_see_fans = user.privacy_fans === 0
					user.can_see_likes = user.privacy_likes === 0
					user.can_see_activities = (user.privacy_activities || 0) === 0
				}
			} catch {}
		} else {
			user.can_see_follows = user.privacy_follows === 0
			user.can_see_fans = user.privacy_fans === 0
			user.can_see_likes = user.privacy_likes === 0
			user.can_see_activities = (user.privacy_activities || 0) === 0
		}

		delete user.privacy_follows
		delete user.privacy_fans
		delete user.privacy_likes
		delete user.privacy_activities

		// 添加留币和等级数据
		await ensureUserRecords(req.params.id)
		const [coinRows] = await db.query('SELECT balance FROM user_coins WHERE user_id = ?', [req.params.id])
		const [levelRows] = await db.query('SELECT level, exp FROM user_levels WHERE user_id = ?', [req.params.id])
		const levelInfo = getLevelInfo(levelRows[0]?.exp || 0)
		user.coins = coinRows[0]?.balance || 0
		user.level_info = levelInfo

		res.json({ code: 200, data: user })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 关注/取消关注
router.post('/:id/follow', auth, async (req, res) => {
	try {
		const targetId = req.params.id
		if (Number(targetId) === req.user.id) return res.json({ code: 400, msg: '不能关注自己' })

		const [exist] = await db.query('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [req.user.id, targetId])
		if (exist.length) {
			await db.query('DELETE FROM follows WHERE follower_id = ? AND following_id = ?', [req.user.id, targetId])
			await db.query('UPDATE users SET follow_count = GREATEST(follow_count - 1, 0) WHERE id = ?', [req.user.id])
			await db.query('UPDATE users SET fans_count = GREATEST(fans_count - 1, 0) WHERE id = ?', [targetId])
			await db.query('DELETE FROM activities WHERE user_id = ? AND type = 5 AND target_id = ?', [req.user.id, targetId])
			const [fanCheck] = await db.query('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [targetId, req.user.id])
				res.json({ code: 200, msg: '取消关注', data: { followed: false, is_fan: fanCheck.length > 0 } })
		} else {
			await db.query('INSERT INTO follows (follower_id, following_id) VALUES (?, ?)', [req.user.id, targetId])
			await db.query('UPDATE users SET follow_count = follow_count + 1 WHERE id = ?', [req.user.id])
			await db.query('UPDATE users SET fans_count = fans_count + 1 WHERE id = ?', [targetId])
			await db.query('DELETE FROM messages WHERE from_user_id = ? AND to_user_id = ? AND type = 3', [req.user.id, targetId])
			await db.query('INSERT INTO messages (from_user_id, to_user_id, type, content) VALUES (?, ?, 3, ?)',
				[req.user.id, targetId, '关注了你'])
			pushNotification(db, targetId, 3, req.user.id, null)
			await db.query('INSERT INTO activities (user_id, type, target_id, target_type, content) VALUES (?, 5, ?, 2, ?)',
				[req.user.id, targetId, '关注了用户'])
			const [fanCheck2] = await db.query('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [targetId, req.user.id])
				res.json({ code: 200, msg: '关注成功', data: { followed: true, is_fan: fanCheck2.length > 0 } })
		}
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户的帖子
router.get('/:id/posts', async (req, res) => {
	try {
		const { page = 1, pageSize = 20 } = req.query
		const offset = (page - 1) * pageSize

		let statusFilter = 'p.status = 1'
		let privateFilter = ''
		const token = req.headers.authorization?.replace('Bearer ', '')
		let currentUserId = null
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const user = jwt.verify(token, JWT_SECRET)
				currentUserId = user.id
				if (user.id === Number(req.params.id)) {
					statusFilter = 'p.status IN (1, 2)'
				}
			} catch {}
		}

		if (Number(req.params.id) !== currentUserId) {
			privateFilter = ' AND (p.is_private = 0 OR p.is_private IS NULL)'
		}

		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar, c.name as category_name FROM posts p
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN categories c ON p.category_id = c.id
			WHERE p.user_id = ? AND ${statusFilter}${privateFilter}
			ORDER BY p.created_at DESC LIMIT ? OFFSET ?`,
			[req.params.id, Number(pageSize), Number(offset)]
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
				imgMap[img.post_id].push({
					url: img.image_url,
					type: img.media_type === 2 ? 'live' : 'image',
					video_url: img.video_url || ''
				})
			})
		}

		const list = rows.map(r => ({ ...r, images: imgMap[r.id] || [] }))
		res.json({ code: 200, data: list })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户的关注列表
router.get('/:id/follows', auth, async (req, res) => {
	try {
		const targetId = req.params.id
		const isSelf = Number(targetId) === req.user.id

		if (!isSelf) {
			const [privacy] = await db.query('SELECT privacy_follows FROM users WHERE id = ?', [targetId])
			if (privacy.length && privacy[0].privacy_follows === 1) {
				return res.json({ code: 403, msg: '对方关注列表不公开' })
			}
		}

		const [rows] = await db.query(
			`SELECT u.id, u.username, u.nickname, u.avatar, u.bio, u.fans_count
			FROM follows f LEFT JOIN users u ON f.following_id = u.id
			WHERE f.follower_id = ? AND u.status = 1
			ORDER BY f.created_at DESC`,
			[targetId]
		)

		const [myFollows] = await db.query(
			'SELECT following_id FROM follows WHERE follower_id = ?',
			[req.user.id]
		)
		const myFollowSet = new Set(myFollows.map(f => f.following_id))
		rows.forEach(u => { u.is_followed = myFollowSet.has(u.id) })
		const [myFans2] = await db.query('SELECT follower_id FROM follows WHERE following_id = ?', [req.user.id])
			const myFanSet2 = new Set(myFans2.map(f => f.follower_id))
			rows.forEach(u => { u.is_fan = myFanSet2.has(u.id) })

		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户的粉丝列表
router.get('/:id/fans', auth, async (req, res) => {
	try {
		const targetId = req.params.id
		const isSelf = Number(targetId) === req.user.id

		if (!isSelf) {
			const [privacy] = await db.query('SELECT privacy_fans FROM users WHERE id = ?', [targetId])
			if (privacy.length && privacy[0].privacy_fans === 1) {
				return res.json({ code: 403, msg: '对方粉丝列表不公开' })
			}
		}

		const [rows] = await db.query(
			`SELECT u.id, u.username, u.nickname, u.avatar, u.bio, u.fans_count
			FROM follows f LEFT JOIN users u ON f.follower_id = u.id
			WHERE f.following_id = ? AND u.status = 1
			ORDER BY f.created_at DESC`,
			[targetId]
		)

		const [myFollows] = await db.query(
			'SELECT following_id FROM follows WHERE follower_id = ?',
			[req.user.id]
		)
		const myFollowSet = new Set(myFollows.map(f => f.following_id))
		rows.forEach(u => { u.is_followed = myFollowSet.has(u.id) })
		const [myFans2] = await db.query('SELECT follower_id FROM follows WHERE following_id = ?', [req.user.id])
			const myFanSet2 = new Set(myFans2.map(f => f.follower_id))
			rows.forEach(u => { u.is_fan = myFanSet2.has(u.id) })

		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取赞过该用户的人
router.get('/:id/likers', auth, async (req, res) => {
	try {
		const targetId = req.params.id
		const isSelf = Number(targetId) === req.user.id

		if (!isSelf) {
			const [privacy] = await db.query('SELECT privacy_likes FROM users WHERE id = ?', [targetId])
			if (privacy.length && privacy[0].privacy_likes === 1) {
				return res.json({ code: 403, msg: '对方赞过列表不公开' })
			}
		}

		const [postIds] = await db.query('SELECT id FROM posts WHERE user_id = ?', [targetId])
		if (!postIds.length) return res.json({ code: 200, data: [] })

		const ids = postIds.map(p => p.id)
		const [rows] = await db.query(
			`SELECT DISTINCT u.id, u.username, u.nickname, u.avatar, u.bio
			FROM likes l LEFT JOIN users u ON l.user_id = u.id
			WHERE l.target_id IN (?) AND l.target_type = 1 AND u.status = 1
			ORDER BY l.created_at DESC LIMIT 50`,
			[ids]
		)

		const [myFollows] = await db.query(
			'SELECT following_id FROM follows WHERE follower_id = ?',
			[req.user.id]
		)
		const myFollowSet = new Set(myFollows.map(f => f.following_id))
		rows.forEach(u => { u.is_followed = myFollowSet.has(u.id) })
		const [myFans2] = await db.query('SELECT follower_id FROM follows WHERE following_id = ?', [req.user.id])
			const myFanSet2 = new Set(myFans2.map(f => f.follower_id))
			rows.forEach(u => { u.is_fan = myFanSet2.has(u.id) })

		res.json({ code: 200, data: rows })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户收藏的帖子
router.get('/:id/collects', auth, async (req, res) => {
	try {
		const { page = 1, pageSize = 20 } = req.query
		const offset = (page - 1) * pageSize
		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar, c.name as category_name
			FROM collects cl
			LEFT JOIN posts p ON cl.post_id = p.id
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN categories c ON p.category_id = c.id
			WHERE cl.user_id = ? AND p.status = 1 AND (p.is_private = 0 OR p.is_private IS NULL OR p.user_id = ?)
			ORDER BY cl.created_at DESC LIMIT ? OFFSET ?`,
			[req.params.id, req.user.id, Number(pageSize), Number(offset)]
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
				imgMap[img.post_id].push({ url: img.image_url, type: img.media_type === 2 ? 'live' : 'image', video_url: img.video_url || '' })
			})
		}
		const list = rows.map(r => ({ ...r, images: imgMap[r.id] || [], isCollected: true, isLiked: false }))
		const token = req.headers.authorization?.replace('Bearer ', '')
		if (token && list.length) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const user = jwt.verify(token, JWT_SECRET)
				const ids = list.map(p => p.id)
				const [likes] = await db.query('SELECT target_id FROM likes WHERE user_id = ? AND target_type = 1 AND target_id IN (?)', [user.id, ids])
				const likedSet = new Set(likes.map(l => l.target_id))
				list.forEach(p => { p.isLiked = likedSet.has(p.id) })
			} catch {}
		}
		res.json({ code: 200, data: list })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户赞过的帖子
router.get('/:id/likes', auth, async (req, res) => {
	try {
		const { page = 1, pageSize = 20 } = req.query
		const offset = (page - 1) * pageSize
		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.avatar, c.name as category_name
			FROM likes l
			LEFT JOIN posts p ON l.target_id = p.id
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN categories c ON p.category_id = c.id
			WHERE l.user_id = ? AND l.target_type = 1 AND p.status = 1 AND (p.is_private = 0 OR p.is_private IS NULL OR p.user_id = ?)
			ORDER BY l.created_at DESC LIMIT ? OFFSET ?`,
			[req.params.id, req.user.id, Number(pageSize), Number(offset)]
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
				imgMap[img.post_id].push({ url: img.image_url, type: img.media_type === 2 ? 'live' : 'image', video_url: img.video_url || '' })
			})
		}
		const list = rows.map(r => ({ ...r, images: imgMap[r.id] || [], isLiked: true, isCollected: false }))
		const token = req.headers.authorization?.replace('Bearer ', '')
		if (token && list.length) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const user = jwt.verify(token, JWT_SECRET)
				const ids = list.map(p => p.id)
				const [collects] = await db.query('SELECT post_id FROM collects WHERE user_id = ? AND post_id IN (?)', [user.id, ids])
				const collectedSet = new Set(collects.map(c => c.post_id))
				list.forEach(p => { p.isCollected = collectedSet.has(p.id) })
			} catch {}
		}
		res.json({ code: 200, data: list })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取用户动态
router.get('/:id/activities', async (req, res) => {
	try {
		const [privacyRows] = await db.query('SELECT privacy_activities FROM users WHERE id = ? AND status = 1', [req.params.id])
		if (!privacyRows.length) return res.json({ code: 404, msg: '用户不存在' })

		const token = req.headers.authorization?.replace('Bearer ', '')
		let currentUserId = null
		if (token) {
			try {
				const jwt = require('jsonwebtoken')
				const { JWT_SECRET } = require('../config/env')
				const me = jwt.verify(token, JWT_SECRET)
				currentUserId = me.id
			} catch {}
		}

		if (Number(req.params.id) !== currentUserId && (privacyRows[0].privacy_activities || 0) === 1) {
			return res.json({ code: 403, msg: '对方动态不公开', data: [] })
		}

		const { page = 1, pageSize = 20 } = req.query
		const offset = (page - 1) * pageSize

			const [rows] = await db.query(
				`SELECT a.*, u.avatar as user_avatar, u.nickname as user_nickname,
					CASE
						WHEN a.target_type = 1 THEN (SELECT title FROM posts WHERE id = a.target_id)
						WHEN a.target_type = 2 THEN (SELECT nickname FROM users WHERE id = a.target_id)
						ELSE NULL
					END as target_title
				FROM activities a
				LEFT JOIN users u ON a.user_id = u.id
				WHERE a.user_id = ?
				ORDER BY a.created_at DESC
				LIMIT ? OFFSET ?`,
				[req.params.id, Number(pageSize), Number(offset)]
			)

		for (const a of rows) {
			if (a.target_type === 1 && a.target_id) {
				const [postRows] = await db.query(
					`SELECT p.id, p.title, p.content, (SELECT image_url FROM post_images WHERE post_id = p.id ORDER BY sort_order LIMIT 1) as cover
					FROM posts p WHERE p.id = ?`, [a.target_id]
				)
				a.post = postRows.length ? postRows[0] : null
			}
			if (a.target_type === 2 && a.target_id) {
				const [userRows] = await db.query(
					`SELECT id, nickname, avatar FROM users WHERE id = ?`, [a.target_id]
				)
				a.target_user = userRows.length ? userRows[0] : null
			}
		}

		res.json({ code: 200, data: rows })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 发送修改密码验证码
router.post('/send-reset-code', async (req, res) => {
	try {
		const { email } = req.body
		if (!email) return res.json({ code: 400, msg: '请输入邮箱' })
		// 检查邮箱是否注册
		const [users] = await db.query('SELECT id FROM users WHERE email = ?', [email])
		if (!users.length) return res.json({ code: 400, msg: '该邮箱未注册' })
		// 生成6位验证码
		const code = String(Math.floor(100000 + Math.random() * 900000))
		// 存储验证码（5分钟有效）
		await db.query('INSERT INTO reset_codes (email, code, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 5 MINUTE)) ON DUPLICATE KEY UPDATE code = ?, expires_at = DATE_ADD(NOW(), INTERVAL 5 MINUTE)', [email, code, code])
		// 发送邮件
		await sendMail(db, email, '留笔 - 修改密码验证码', `<div style="padding:20px;background:#f8f8f8;border-radius:8px;"><h2 style="color:#FF2442;">修改密码验证码</h2><p>您的验证码是：<b style="font-size:24px;color:#FF2442;">${code}</b></p><p>验证码5分钟内有效，请勿泄露给他人。</p></div>`)
		res.json({ code: 200, msg: '验证码已发送' })
	} catch (e) {
		console.error('发送验证码失败:', e)
		res.json({ code: 500, msg: '发送失败，请检查邮箱配置' })
	}
})

// 通过验证码修改密码
router.post('/reset-password', async (req, res) => {
	try {
		const { email, code, new_password } = req.body
		if (!email || !code || !new_password) return res.json({ code: 400, msg: '参数不完整' })
		if (new_password.length < 6) return res.json({ code: 400, msg: '密码至少6位' })
		// 验证验证码
		const [rows] = await db.query('SELECT * FROM reset_codes WHERE email = ? AND code = ? AND expires_at > NOW()', [email, code])
		if (!rows.length) return res.json({ code: 400, msg: '验证码错误或已过期' })
		// 更新密码
		const bcrypt = require('bcryptjs')
		const hash = await bcrypt.hash(new_password, 10)
		await db.query('UPDATE users SET password = ? WHERE email = ?', [hash, email])
		// 删除已使用的验证码
		await db.query('DELETE FROM reset_codes WHERE email = ?', [email])
		res.json({ code: 200, msg: '密码修改成功' })
	} catch (e) {
		res.json({ code: 500, msg: '修改失败' })
	}
})

module.exports = router
