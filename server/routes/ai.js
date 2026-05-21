const express = require('express')
const router = express.Router()
const { auth } = require('../middleware/auth')
const db = require('../config/db')
const https = require('https')
const http = require('http')

const DEFAULT_SYSTEM_PROMPT = `你是"留笔"App的AI助手，一个温暖、有趣、有创意的智能伙伴。你的特点：
1. 回答简洁明了，不啰嗦
2. 善于写文艺文案、诗歌、故事
3. 乐于推荐音乐、电影、美食
4. 说话风格轻松自然，像朋友聊天
5. 适当使用emoji增加趣味性
6. 遇到不确定的问题会诚实说明`

async function getAIConfig() {
	try {
		const [rows] = await db.query('SELECT * FROM ai_config ORDER BY id DESC LIMIT 1')
		if (rows.length) {
			return {
				apiUrl: rows[0].api_url || 'https://api.deepseek.com/v1/chat/completions',
				apiKey: rows[0].api_key || '',
				modelName: rows[0].model_name || 'deepseek-chat',
				systemPrompt: rows[0].system_prompt || DEFAULT_SYSTEM_PROMPT,
				enabled: rows[0].enabled !== 0
			}
		}
	} catch (e) {
		console.error('getAIConfig error:', e.message)
	}
	return { apiUrl: 'https://api.deepseek.com/v1/chat/completions', apiKey: '', modelName: 'deepseek-chat', systemPrompt: DEFAULT_SYSTEM_PROMPT, enabled: true }
}

function callAI(messages, config) {
	return new Promise((resolve, reject) => {
		if (!config.apiKey || !config.enabled) {
			return resolve({ content: getLocalReply(messages) })
		}

		const body = JSON.stringify({
			model: config.modelName,
			messages: [{ role: 'system', content: config.systemPrompt }, ...messages],
			max_tokens: 1024,
			temperature: 0.8
		})

		const url = new URL(config.apiUrl)
		const options = {
			hostname: url.hostname,
			port: url.port || 443,
			path: url.pathname,
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': 'Bearer ' + config.apiKey,
				'Content-Length': Buffer.byteLength(body)
			}
		}

		const mod = url.protocol === 'https:' ? https : http
		const req = mod.request(options, (res) => {
			let data = ''
			res.on('data', (chunk) => { data += chunk })
			res.on('end', () => {
				try {
					const json = JSON.parse(data)
					if (json.choices && json.choices[0] && json.choices[0].message) {
						resolve({ content: json.choices[0].message.content })
					} else if (json.error) {
						console.error('AI API error:', json.error)
						resolve({ content: getLocalReply(messages) })
					} else {
						resolve({ content: getLocalReply(messages) })
					}
				} catch (e) {
					console.error('AI parse error:', e.message)
					resolve({ content: getLocalReply(messages) })
				}
			})
		})

		req.on('error', (e) => {
			console.error('AI request error:', e.message)
			resolve({ content: getLocalReply(messages) })
		})

		req.setTimeout(30000, () => {
			req.destroy()
			resolve({ content: getLocalReply(messages) })
		})

		req.write(body)
		req.end()
	})
}

function getLocalReply(messages) {
	const lastMsg = messages[messages.length - 1]
	const text = (lastMsg?.content || '').toLowerCase()

	if (text.includes('你好') || text.includes('嗨') || text.includes('hi') || text.includes('hello')) {
		return '你好呀！✨ 很高兴见到你～有什么想聊的吗？'
	}
	if (text.includes('文案') || text.includes('写')) {
		return '好的，来一段文艺的：\n\n"世间所有的相遇，都是久别重逢。每一次落笔，都是与灵魂的一次对话。在留笔，让文字替你记住那些来不及说出口的温柔。"\n\n喜欢吗？可以告诉我你想要什么风格的～ ✍️'
	}
	if (text.includes('歌') || text.includes('音乐') || text.includes('推荐')) {
		return '给你推荐几首好听的歌吧 🎵\n\n1. 《晚风》— 温暖治愈系\n2. 《起风了》— 青春回忆杀\n3. 《漠河舞厅》— 故事感满满\n4. 《孤勇者》— 燃起来！\n5. 《稻香》— 经典永不过时\n\n想听什么类型的？我可以继续推荐～'
	}
	if (text.includes('故事') || text.includes('讲')) {
		return '从前有座山，山上有棵树，树下有只猫🐱\n\n这只猫每天都会在树下等一个人。那个人曾经给它取了一个名字，叫"留笔"。因为那个人说："我想把每一天都写下来，这样就不会忘记了。"\n\n后来那个人走了，但猫还在等。它觉得，只要自己还在，那些故事就不会消失。\n\n——每一个认真生活的人，都值得被记住 ✨'
	}
	if (text.includes('美食') || text.includes('吃') || text.includes('食物')) {
		return '说到美食我可就不困了！🍜\n\n🔥 近期热门推荐：\n• 螺蛳粉 — 爱的人爱到骨子里\n• 烤肉 — 滋滋作响的快乐\n• 奶茶 — 续命必备\n• 火锅 — 万物皆可涮\n\n你是甜党还是咸党？🤔'
	}
	if (text.includes('笑话') || text.includes('搞笑') || text.includes('有趣')) {
		return '来一个 😄\n\n程序员最讨厌的四件事：\n1. 写注释\n2. 写文档\n3. 别人不写注释\n4. 别人不写文档\n\n哈哈，是不是很真实？😂'
	}
	if (text.includes('谢谢') || text.includes('感谢') || text.includes('thanks')) {
		return '不客气呀～随时都可以来找我聊天 💫\n\n有什么需要帮忙的尽管说！'
	}
	if (text.includes('穿搭') || text.includes('衣服') || text.includes('时尚')) {
		return '穿搭小建议来啦 👗✨\n\n🔥 本季流行趋势：\n• 极简风 — 永远的高级感\n• 运动休闲 — 舒适又时髦\n• 复古风 — 经典轮回\n\n💡 小技巧：全身颜色不超过3种，就能穿出质感！\n\n想了解什么风格？'
	}

	const replies = [
		'这个问题很有意思！让我想想... 🤔\n\n我觉得最重要的是保持好奇心和热情。你有什么具体的想法吗？',
		'嗯嗯，我理解你的意思～ 💭\n\n每个人看待事物的角度不同，这正是世界有趣的地方。你愿意多说说吗？',
		'好的好的！✨\n\n虽然我还在学习中，但我会尽力帮你。你可以试着问我写文案、推荐、讲故事之类的问题～',
		'嘿，你说的这个让我想到了一个有趣的观点 🌟\n\n有时候换个角度看问题，会有意想不到的收获呢！'
	]
	return replies[Math.floor(Math.random() * replies.length)]
}

// 对话列表
router.get('/conversations', auth, async (req, res) => {
	try {
		const [rows] = await db.query(
			'SELECT c.id, c.title, c.created_at, c.updated_at, (SELECT content FROM ai_chat_history WHERE conversation_id = c.id AND role = \'user\' ORDER BY id DESC LIMIT 1) as last_message FROM ai_conversations c WHERE c.user_id = ? ORDER BY c.updated_at DESC',
			[req.user.id]
		)
		res.json({ code: 200, data: rows })
	} catch (e) {
		console.error('get conversations error:', e.message)
		res.json({ code: 200, data: [] })
	}
})

// 创建对话
router.post('/conversations', auth, async (req, res) => {
	try {
		const title = req.body.title || '新对话'
		const [result] = await db.query('INSERT INTO ai_conversations (user_id, title) VALUES (?, ?)', [req.user.id, title])
		res.json({ code: 200, data: { id: result.insertId, title } })
	} catch (e) {
		console.error('create conversation error:', e.message)
		res.json({ code: 500, msg: '创建失败' })
	}
})

// 删除对话
router.delete('/conversations/:id', auth, async (req, res) => {
	try {
		await db.query('DELETE FROM ai_chat_history WHERE conversation_id = ?', [req.params.id])
		await db.query('DELETE FROM ai_conversations WHERE id = ? AND user_id = ?', [req.params.id, req.user.id])
		res.json({ code: 200, msg: '已删除' })
	} catch (e) {
		res.json({ code: 500, msg: '删除失败' })
	}
})

// 重命名对话
router.put('/conversations/:id', auth, async (req, res) => {
	try {
		const { title } = req.body
		if (!title) return res.json({ code: 400, msg: '标题不能为空' })
		await db.query('UPDATE ai_conversations SET title = ? WHERE id = ? AND user_id = ?', [title, req.params.id, req.user.id])
		res.json({ code: 200, msg: 'ok' })
	} catch (e) {
		res.json({ code: 500, msg: '重命名失败' })
	}
})

// 聊天
router.post('/chat', auth, async (req, res) => {
	try {
		const { messages, userMessage, conversation_id } = req.body
		if (!messages || !Array.isArray(messages) || !messages.length) {
			return res.json({ code: 400, msg: '消息不能为空' })
		}

		let convId = conversation_id
		if (!convId) {
			const title = userMessage ? userMessage.substring(0, 30) : '新对话'
			const [result] = await db.query('INSERT INTO ai_conversations (user_id, title) VALUES (?, ?)', [req.user.id, title])
			convId = result.insertId
		}

		if (userMessage) {
			await db.query('INSERT INTO ai_chat_history (user_id, role, content, conversation_id) VALUES (?, ?, ?, ?)', [req.user.id, 'user', userMessage, convId])
		}

		const config = await getAIConfig()
		const recentMsgs = messages.slice(-20)
		const result = await callAI(recentMsgs, config)

		const [aiResult] = await db.query('INSERT INTO ai_chat_history (user_id, role, content, conversation_id) VALUES (?, ?, ?, ?)', [req.user.id, 'assistant', result.content, convId])

		const autoTitle = userMessage ? userMessage.substring(0, 30) : null
		if (autoTitle) {
			const [conv] = await db.query('SELECT title FROM ai_conversations WHERE id = ?', [convId])
			if (conv.length && conv[0].title === '新对话') {
				await db.query('UPDATE ai_conversations SET title = ? WHERE id = ?', [autoTitle, convId])
			}
		}

		res.json({ code: 200, data: { content: result.content, conversation_id: convId, message_id: aiResult.insertId } })
	} catch (e) {
		console.error('AI chat error:', e.message)
		res.json({ code: 500, msg: 'AI 服务暂时不可用' })
	}
})

// 历史记录（支持按对话ID筛选）
router.get('/history', auth, async (req, res) => {
	try {
		const limit = Math.min(parseInt(req.query.limit) || 50, 100)
		const convId = req.query.conversation_id
		let sql, params
		if (convId) {
			sql = 'SELECT id, role, content, is_liked, is_disliked, created_at, conversation_id FROM ai_chat_history WHERE user_id = ? AND conversation_id = ? ORDER BY id ASC LIMIT ?'
			params = [req.user.id, convId, limit]
		} else {
			sql = 'SELECT id, role, content, is_liked, is_disliked, created_at, conversation_id FROM ai_chat_history WHERE user_id = ? AND conversation_id IS NULL ORDER BY id DESC LIMIT ?'
			params = [req.user.id, limit]
		}
		const [rows] = await db.query(sql, params)
		res.json({ code: 200, data: convId ? rows : rows.reverse() })
	} catch (e) {
		console.error('AI history error:', e.message)
		res.json({ code: 200, data: [] })
	}
})

// 清空历史
router.delete('/history', auth, async (req, res) => {
	try {
		await db.query('DELETE FROM ai_chat_history WHERE user_id = ?', [req.user.id])
		await db.query('DELETE FROM ai_conversations WHERE user_id = ?', [req.user.id])
		res.json({ code: 200, msg: '已清空' })
	} catch (e) {
		res.json({ code: 500, msg: '清空失败' })
	}
})

// 消息反馈（点赞/踩）
router.post('/messages/feedback', auth, async (req, res) => {
	try {
		const { message_id, action } = req.body
		if (!message_id || !action) {
			return res.json({ code: 400, msg: '参数错误' })
		}

		let sql
		if (action === 'like') {
			sql = 'UPDATE ai_chat_history SET is_liked = 1, is_disliked = 0 WHERE id = ? AND user_id = ?'
		} else if (action === 'dislike') {
			sql = 'UPDATE ai_chat_history SET is_liked = 0, is_disliked = 1 WHERE id = ? AND user_id = ?'
		} else if (action === 'cancel') {
			sql = 'UPDATE ai_chat_history SET is_liked = 0, is_disliked = 0 WHERE id = ? AND user_id = ?'
		} else {
			return res.json({ code: 400, msg: '无效的操作' })
		}

		await db.query(sql, [message_id, req.user.id])
		res.json({ code: 200, msg: 'ok' })
	} catch (e) {
		console.error('AI feedback error:', e.message)
		res.json({ code: 500, msg: '操作失败' })
	}
})

// AI绘画配置
async function getImageConfig() {
	try {
		const [rows] = await db.query('SELECT * FROM ai_image_config ORDER BY id DESC LIMIT 1')
		if (rows.length) {
			return {
				apiUrl: rows[0].api_url || 'https://api.openai.com/v1/images/generations',
				apiKey: rows[0].api_key || '',
				modelName: rows[0].model_name || 'gpt-image-2',
				enabled: rows[0].enabled !== 0
			}
		}
	} catch (e) {
		console.error('getImageConfig error:', e.message)
	}
	return { apiUrl: 'https://api.openai.com/v1/images/generations', apiKey: '', modelName: 'gpt-image-2', enabled: false }
}

function callImageAI(prompt, config) {
	return new Promise((resolve, reject) => {
		if (!config.apiKey || !config.enabled) {
			return reject(new Error('AI绘画功能未配置'))
		}

		const body = JSON.stringify({
			model: config.modelName,
			prompt: prompt,
			n: 1,
			size: '1024x1024',
			quality: 'medium',
			response_format: 'b64_json'
		})

		const url = new URL(config.apiUrl)
		const options = {
			hostname: url.hostname,
			port: url.port || 443,
			path: url.pathname,
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': 'Bearer ' + config.apiKey,
				'Content-Length': Buffer.byteLength(body)
			}
		}

		const mod = url.protocol === 'https:' ? https : http
		const req = mod.request(options, (res) => {
			let data = ''
			res.on('data', (chunk) => { data += chunk })
			res.on('end', () => {
				try {
					const json = JSON.parse(data)
					if (json.data && json.data[0]) {
						const imageData = json.data[0]
						if (imageData.url) {
							resolve({ url: imageData.url })
						} else if (imageData.b64_json) {
							resolve({ b64_json: imageData.b64_json })
						} else {
							reject(new Error('未返回图片数据'))
						}
					} else if (json.error) {
						reject(new Error(json.error.message || 'API错误'))
					} else {
						reject(new Error('未返回图片数据'))
					}
				} catch (e) {
					reject(new Error('解析响应失败'))
				}
			})
		})

		req.on('error', (e) => reject(e))
		req.setTimeout(120000, () => {
			req.destroy()
			reject(new Error('请求超时'))
		})
		req.write(body)
		req.end()
	})
}

// 生成AI图片
router.post('/image/generate', auth, async (req, res) => {
	try {
		const { prompt } = req.body
		if (!prompt || !prompt.trim()) {
			return res.json({ code: 400, msg: '请输入描述' })
		}

		const config = await getImageConfig()
		console.log('[AI绘画] 配置:', JSON.stringify({ apiUrl: config.apiUrl, modelName: config.modelName, enabled: config.enabled, hasKey: !!config.apiKey }))
		if (!config.enabled || !config.apiKey) {
			return res.json({ code: 503, msg: 'AI绘画功能暂未开放' })
		}

		const [result] = await db.query(
			'INSERT INTO ai_image_history (user_id, prompt, status) VALUES (?, ?, ?)',
			[req.user.id, prompt.trim(), 'generating']
		)
		const historyId = result.insertId
		console.log('[AI绘画] 开始生成, historyId:', historyId, 'prompt:', prompt.trim())

		try {
			const imageResult = await callImageAI(prompt.trim(), config)
			console.log('[AI绘画] API返回成功, hasUrl:', !!imageResult.url, 'hasB64:', !!imageResult.b64_json)
			let imageUrl = imageResult.url || ''

			if (imageResult.b64_json) {
				const fs = require('fs')
				const path = require('path')
				const uploadDir = path.join(__dirname, '..', 'uploads', 'ai_images')
				if (!fs.existsSync(uploadDir)) {
					fs.mkdirSync(uploadDir, { recursive: true })
				}
				const filename = `ai_${Date.now()}_${req.user.id}.png`
				const filePath = path.join(uploadDir, filename)
				fs.writeFileSync(filePath, Buffer.from(imageResult.b64_json, 'base64'))
				imageUrl = `/uploads/ai_images/${filename}`
				console.log('[AI绘画] 图片已保存:', filename)
			}

			await db.query('UPDATE ai_image_history SET image_url = ?, status = ? WHERE id = ?',
				[imageUrl, 'completed', historyId])

			res.json({ code: 200, data: { id: historyId, image_url: imageUrl, prompt: prompt.trim() } })
		} catch (e) {
			console.error('[AI绘画] 生成失败:', e.message)
			await db.query('UPDATE ai_image_history SET status = ? WHERE id = ?', ['failed', historyId])
			res.json({ code: 500, msg: e.message || '生成失败' })
		}
	} catch (e) {
		console.error('[AI绘画] 外层错误:', e.message)
		res.json({ code: 500, msg: '生成失败' })
	}
})

// 获取AI绘画历史
router.get('/image/history', auth, async (req, res) => {
	try {
		const limit = parseInt(req.query.limit) || 20
		const offset = parseInt(req.query.offset) || 0
		const [rows] = await db.query(
			'SELECT id, prompt, image_url, status, created_at FROM ai_image_history WHERE user_id = ? ORDER BY id DESC LIMIT ? OFFSET ?',
			[req.user.id, limit, offset]
		)
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '获取失败' })
	}
})

// 删除AI绘画记录
router.delete('/image/:id', auth, async (req, res) => {
	try {
		await db.query('DELETE FROM ai_image_history WHERE id = ? AND user_id = ?', [req.params.id, req.user.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '删除失败' })
	}
})

module.exports = router
