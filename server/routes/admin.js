const express = require('express')
const fs = require('fs')
const path = require('path')
const db = require('../config/db')
const { adminAuth } = require('../middleware/auth')
const router = express.Router()

router.use(adminAuth)

// 统计数据
router.get('/stats', async (req, res) => {
	try {
		const [users] = await db.query('SELECT COUNT(*) as count FROM users')
		const [posts] = await db.query('SELECT COUNT(*) as count FROM posts')
		const [comments] = await db.query('SELECT COUNT(*) as count FROM comments')
		const [pending] = await db.query('SELECT COUNT(*) as count FROM posts WHERE status = 2')
		res.json({ code: 200, data: { users: users[0].count, posts: posts[0].count, comments: comments[0].count, pending: pending[0].count } })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 用户列表
router.get('/users', async (req, res) => {
	try {
		const { page = 1, pageSize = 50, keyword } = req.query
		const offset = (page - 1) * pageSize
		let where = ''
		const params = []
		if (keyword) { where = 'WHERE username LIKE ? OR nickname LIKE ?'; params.push(`%${keyword}%`, `%${keyword}%`) }
		const [rows] = await db.query(
			`SELECT id,username,nickname,email,avatar,bio,role,fans_count,follow_count,like_count,status,mute_until,created_at FROM users ${where} ORDER BY id DESC LIMIT ? OFFSET ?`,
			[...params, Number(pageSize), Number(offset)]
		)
		const [count] = await db.query(`SELECT COUNT(*) as total FROM users ${where}`, params)
		res.json({ code: 200, data: { list: rows, total: count[0].total } })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 禁用/启用用户
router.put('/users/:id/status', async (req, res) => {
	try {
		await db.query('UPDATE users SET status = ? WHERE id = ?', [req.body.status, req.params.id])
		res.json({ code: 200, msg: '操作成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 编辑用户信息
router.put('/users/:id', async (req, res) => {
	try {
		const { nickname, email, bio, role, avatar } = req.body
		const fields = []
		const vals = []
		if (nickname !== undefined && nickname !== null) { fields.push('nickname = ?'); vals.push(nickname) }
		if (email !== undefined && email !== null) { fields.push('email = ?'); vals.push(email) }
		if (bio !== undefined && bio !== null) { fields.push('bio = ?'); vals.push(bio) }
		if (role !== undefined && role !== null) { fields.push('role = ?'); vals.push(Number(role)) }
		if (avatar !== undefined && avatar !== null) { fields.push('avatar = ?'); vals.push(avatar) }
		if (!fields.length) return res.json({ code: 400, msg: '无更新内容' })
		vals.push(req.params.id)
		await db.query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, vals)
		res.json({ code: 200, msg: '更新成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 禁言用户
router.put('/users/:id/mute', async (req, res) => {
	try {
		const { mute_until } = req.body
		await db.query('UPDATE users SET mute_until = ? WHERE id = ?', [mute_until || null, req.params.id])
		res.json({ code: 200, msg: mute_until ? '禁言成功' : '已解除禁言' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 帖子列表
router.get('/posts', async (req, res) => {
	try {
		const { page = 1, pageSize = 50, status } = req.query
		const offset = (page - 1) * pageSize
		let where = ''
		const params = []
		if (status !== undefined && status !== '') { where = 'WHERE p.status = ?'; params.push(Number(status)) }
		const [rows] = await db.query(
			`SELECT p.*, u.nickname, u.username, u.avatar FROM posts p LEFT JOIN users u ON p.user_id = u.id ${where} ORDER BY p.created_at DESC LIMIT ? OFFSET ?`,
			[...params, Number(pageSize), Number(offset)]
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
		const [count] = await db.query(`SELECT COUNT(*) as total FROM posts p ${where}`, params)
		res.json({ code: 200, data: { list, total: count[0].total } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 帖子审核/下架
router.put('/posts/:id/status', async (req, res) => {
	try {
		await db.query('UPDATE posts SET status = ? WHERE id = ?', [req.body.status, req.params.id])
		res.json({ code: 200, msg: '操作成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 删除帖子
router.delete('/posts/:id', async (req, res) => {
	try {
		await db.query('DELETE FROM posts WHERE id = ?', [req.params.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 分类CRUD
router.get('/categories', async (req, res) => {
	try {
		const [rows] = await db.query('SELECT * FROM categories ORDER BY sort_order ASC')
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.post('/categories', async (req, res) => {
	try {
		const { name, icon, cover, description, color, sort_order, publish_restriction } = req.body
		if (!name) return res.json({ code: 400, msg: '分类名必填' })
		await db.query('INSERT INTO categories (name, icon, cover, description, color, sort_order, publish_restriction) VALUES (?, ?, ?, ?, ?, ?, ?)', [name, icon || '', cover || '', description || '', color || '', sort_order || 0, publish_restriction || 0])
		res.json({ code: 200, msg: '添加成功' })
	} catch (e) {
		if (e.code === 'ER_DUP_ENTRY') return res.json({ code: 400, msg: '分类名已存在' })
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.put('/categories/:id', async (req, res) => {
	try {
		const { name, icon, cover, description, color, sort_order, status, publish_restriction } = req.body
		await db.query('UPDATE categories SET name=?, icon=?, cover=?, description=?, color=?, sort_order=?, status=?, publish_restriction=? WHERE id=?', [name, icon, cover || '', description || '', color || '', sort_order, status, publish_restriction || 0, req.params.id])
		res.json({ code: 200, msg: '更新成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.delete('/categories/:id', async (req, res) => {
	try {
		await db.query('DELETE FROM categories WHERE id = ?', [req.params.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 评论管理
router.get('/comments', async (req, res) => {
	try {
		const { page = 1, pageSize = 50 } = req.query
		const offset = (page - 1) * pageSize
		const [rows] = await db.query(
			`SELECT c.*, u.nickname FROM comments c LEFT JOIN users u ON c.user_id = u.id ORDER BY c.created_at DESC LIMIT ? OFFSET ?`,
			[Number(pageSize), Number(offset)]
		)
		const [count] = await db.query('SELECT COUNT(*) as total FROM comments')
		res.json({ code: 200, data: { list: rows, total: count[0].total } })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.delete('/comments/:id', async (req, res) => {
	try {
		await db.query('DELETE FROM comments WHERE id = ?', [req.params.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 会话管理
router.get('/conversations', async (req, res) => {
	try {
		const { page = 1, pageSize = 50, type } = req.query
		const offset = (page - 1) * pageSize
		let where = ''
		const params = []
		if (type !== undefined && type !== '') { where = 'WHERE c.type = ?'; params.push(Number(type)) }
		const [rows] = await db.query(
			`SELECT c.*, (SELECT COUNT(*) FROM chat_messages WHERE conversation_id = c.id) as msg_count,
				(SELECT content FROM chat_messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message
			FROM chat_conversations c ${where} ORDER BY c.updated_at DESC LIMIT ? OFFSET ?`,
			[...params, Number(pageSize), Number(offset)]
		)
		// 补充成员信息
		for (const c of rows) {
			const [members] = await db.query(
				'SELECT cm.user_id, u.nickname, u.username FROM chat_members cm LEFT JOIN users u ON cm.user_id = u.id WHERE cm.conversation_id = ?',
				[c.id]
			)
			c.members = members
		}
		const [count] = await db.query(`SELECT COUNT(*) as total FROM chat_conversations c ${where}`, params)
		res.json({ code: 200, data: { list: rows, total: count[0].total } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 编辑群聊号
router.put('/conversations/:id/group-code', async (req, res) => {
	try {
		const { group_code } = req.body
		if (!group_code || !group_code.trim()) return res.json({ code: 400, msg: '群聊号不能为空' })

		// 检查群聊号是否已被占用
		const [existing] = await db.query('SELECT id FROM chat_conversations WHERE group_code = ? AND id != ?', [group_code.trim(), req.params.id])
		if (existing.length) return res.json({ code: 400, msg: '该群聊号已被使用' })

		await db.query('UPDATE chat_conversations SET group_code = ? WHERE id = ?', [group_code.trim(), req.params.id])
		res.json({ code: 200, msg: '修改成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.delete('/conversations/:id', async (req, res) => {
	try {
		await db.query('DELETE FROM chat_messages WHERE conversation_id = ?', [req.params.id])
		await db.query('DELETE FROM chat_members WHERE conversation_id = ?', [req.params.id])
		await db.query('DELETE FROM chat_conversations WHERE id = ?', [req.params.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 邮箱配置
router.get('/email-config', async (req, res) => {
	try {
		const envPath = path.join(__dirname, '..', '.env')
		if (!fs.existsSync(envPath)) return res.json({ code: 200, data: {} })
		const content = fs.readFileSync(envPath, 'utf-8')
		const data = {}
		content.split('\n').forEach(line => {
			const m = line.match(/^MAIL_(\w+)=(.*)$/)
			if (m) data[m[1].toLowerCase()] = m[2].trim()
		})
		res.json({ code: 200, data })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.put('/email-config', async (req, res) => {
	try {
		const envPath = path.join(__dirname, '..', '.env')
		let content = ''
		if (fs.existsSync(envPath)) content = fs.readFileSync(envPath, 'utf-8')

		const fields = { host: 'MAIL_HOST', port: 'MAIL_PORT', secure: 'MAIL_SECURE', user: 'MAIL_USER', pass: 'MAIL_PASS', from: 'MAIL_FROM' }
		for (const [key, envKey] of Object.entries(fields)) {
			if (req.body[key] !== undefined) {
				const regex = new RegExp(`^${envKey}=.*$`, 'm')
				const newLine = `${envKey}=${req.body[key]}`
				if (regex.test(content)) {
					content = content.replace(regex, newLine)
				} else {
					content += `\n${newLine}`
				}
			}
		}

		fs.writeFileSync(envPath, content, 'utf-8')
		res.json({ code: 200, msg: '保存成功，需重启后端生效' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '保存失败' })
	}
})

router.get('/ai-config', async (req, res) => {
	try {
		const [rows] = await db.query('SELECT * FROM ai_config ORDER BY id DESC LIMIT 1')
		if (rows.length) {
			const c = rows[0]
			res.json({ code: 200, data: { id: c.id, api_url: c.api_url, api_key: c.api_key, model_name: c.model_name, system_prompt: c.system_prompt || '', enabled: c.enabled } })
		} else {
			res.json({ code: 200, data: { id: 0, api_url: 'https://api.deepseek.com/v1/chat/completions', api_key: '', model_name: 'deepseek-chat', system_prompt: '', enabled: 1 } })
		}
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

router.put('/ai-config', async (req, res) => {
	try {
		const { api_url, api_key, model_name, system_prompt, enabled } = req.body
		const [rows] = await db.query('SELECT id FROM ai_config ORDER BY id DESC LIMIT 1')
		if (rows.length) {
			await db.query('UPDATE ai_config SET api_url=?, api_key=?, model_name=?, system_prompt=?, enabled=? WHERE id=?',
				[api_url || '', api_key || '', model_name || 'deepseek-chat', system_prompt || '', enabled !== undefined ? enabled : 1, rows[0].id])
		} else {
			await db.query('INSERT INTO ai_config (api_url, api_key, model_name, system_prompt, enabled) VALUES (?,?,?,?,?)',
				[api_url || 'https://api.deepseek.com/v1/chat/completions', api_key || '', model_name || 'deepseek-chat', system_prompt || '', enabled !== undefined ? enabled : 1])
		}
		res.json({ code: 200, msg: '保存成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '保存失败' })
	}
})

// AI绘画配置
router.get('/ai-image-config', async (req, res) => {
	try {
		const [rows] = await db.query('SELECT * FROM ai_image_config ORDER BY id DESC LIMIT 1')
		if (rows.length) {
			const c = rows[0]
			res.json({ code: 200, data: { id: c.id, api_url: c.api_url, api_key: c.api_key, model_name: c.model_name, enabled: c.enabled } })
		} else {
			res.json({ code: 200, data: { id: 0, api_url: 'https://api.openai.com/v1/images/generations', api_key: '', model_name: 'gpt-image-2', enabled: 0 } })
		}
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

router.put('/ai-image-config', async (req, res) => {
	try {
		const { api_url, api_key, model_name, enabled } = req.body
		const [rows] = await db.query('SELECT id FROM ai_image_config ORDER BY id DESC LIMIT 1')
		if (rows.length) {
			await db.query('UPDATE ai_image_config SET api_url=?, api_key=?, model_name=?, enabled=? WHERE id=?',
				[api_url || '', api_key || '', model_name || 'gpt-image-2', enabled !== undefined ? enabled : 0, rows[0].id])
		} else {
			await db.query('INSERT INTO ai_image_config (api_url, api_key, model_name, enabled) VALUES (?,?,?,?)',
				[api_url || 'https://api.openai.com/v1/images/generations', api_key || '', model_name || 'gpt-image-2', enabled !== undefined ? enabled : 0])
		}
		res.json({ code: 200, msg: '保存成功' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '保存失败' })
	}
})

module.exports = router
