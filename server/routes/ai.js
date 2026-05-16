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

router.post('/chat', auth, async (req, res) => {
	try {
		const { messages, userMessage } = req.body
		if (!messages || !Array.isArray(messages) || !messages.length) {
			return res.json({ code: 400, msg: '消息不能为空' })
		}

		if (userMessage) {
			await db.query('INSERT INTO ai_chat_history (user_id, role, content) VALUES (?, ?, ?)', [req.user.id, 'user', userMessage])
		}

		const config = await getAIConfig()
		const recentMsgs = messages.slice(-20)
		const result = await callAI(recentMsgs, config)

		await db.query('INSERT INTO ai_chat_history (user_id, role, content) VALUES (?, ?, ?)', [req.user.id, 'assistant', result.content])

		res.json({ code: 200, data: { content: result.content } })
	} catch (e) {
		console.error('AI chat error:', e.message)
		res.json({ code: 500, msg: 'AI 服务暂时不可用' })
	}
})

router.get('/history', auth, async (req, res) => {
	try {
		const limit = Math.min(parseInt(req.query.limit) || 50, 100)
		const [rows] = await db.query('SELECT role, content, created_at FROM ai_chat_history WHERE user_id = ? ORDER BY id DESC LIMIT ?', [req.user.id, limit])
		res.json({ code: 200, data: rows.reverse() })
	} catch (e) {
		console.error('AI history error:', e.message)
		res.json({ code: 200, data: [] })
	}
})

router.delete('/history', auth, async (req, res) => {
	try {
		await db.query('DELETE FROM ai_chat_history WHERE user_id = ?', [req.user.id])
		res.json({ code: 200, msg: '已清空' })
	} catch (e) {
		res.json({ code: 500, msg: '清空失败' })
	}
})

module.exports = router
