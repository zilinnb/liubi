const express = require('express')
const db = require('../config/db')
const { auth } = require('../middleware/auth')
const { getLevelInfo } = require('./level-config')
const router = express.Router()

// 获取会话列表
router.get('/conversations', auth, async (req, res) => {
	try {
		const [members] = await db.query(
			'SELECT conversation_id, is_pinned, is_hidden FROM chat_members WHERE user_id = ?',
			[req.user.id]
		)
		if (!members.length) return res.json({ code: 200, data: [] })

		const memberMap = {}
		for (const m of members) memberMap[m.conversation_id] = m

		const convIds = members.filter(m => !m.is_hidden).map(m => m.conversation_id)
		const [convs] = await db.query(
			`SELECT c.*,
				(SELECT COUNT(*) FROM chat_messages WHERE conversation_id = c.id AND is_read = 0 AND sender_id != ?) as unread_count,
				(SELECT content FROM chat_messages WHERE conversation_id = c.id AND is_recalled = 0 ORDER BY created_at DESC LIMIT 1) as last_message,
				(SELECT type FROM chat_messages WHERE conversation_id = c.id AND is_recalled = 0 ORDER BY created_at DESC LIMIT 1) as last_message_type,
				(SELECT is_recalled FROM chat_messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_recalled,
				(SELECT created_at FROM chat_messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_time
			FROM chat_conversations c
			WHERE c.id IN (?)`,
			[req.user.id, convIds]
		)

		const list = []
		for (const c of convs) {
			const item = { ...c }
			item.is_pinned = memberMap[c.id]?.is_pinned || 0
			if (c.last_recalled) {
				item.last_message = '[消息已撤回]'
			} else if (c.last_message_type === 3) {
				item.last_message = '[系统消息]'
			} else if (c.last_message_type === 2) {
				item.last_message = '[图片]'
			} else if (c.last_message_type === 4) {
				item.last_message = '[语音]'
			} else if (c.last_message_type === 5) {
				item.last_message = '[实况图片]'
			} else if (c.last_message_type === 6) {
				item.last_message = '[红包]'
			}
			if (c.type === 1) {
				const [other] = await db.query(
					'SELECT u.id, u.nickname, u.avatar FROM chat_members m LEFT JOIN users u ON m.user_id = u.id WHERE m.conversation_id = ? AND m.user_id != ?',
					[c.id, req.user.id]
				)
				if (other.length) {
					item.name = other[0].nickname
					item.avatar = other[0].avatar
					item.other_user_id = other[0].id
				}
			} else if (c.type === 2) {
				const [groupMembers] = await db.query(
					'SELECT u.id, u.nickname, u.avatar FROM chat_members m LEFT JOIN users u ON m.user_id = u.id WHERE m.conversation_id = ?',
					[c.id]
				)
				console.log('[群聊] 群成员:', groupMembers.map(m => ({ id: m.id, nickname: m.nickname, avatar: m.avatar })))
				item.member_count = groupMembers.length
				item.member_avatars = groupMembers.slice(0, 4).map(m => m.avatar || '')
				item.member_names = groupMembers.slice(0, 4).map(m => m.nickname || '用户')
				item.member_ids = groupMembers.slice(0, 4).map(m => m.id || 0)
				console.log('[群聊] member_names:', item.member_names)
				console.log('[群聊] member_ids:', item.member_ids)
			}
			list.push(item)
		}

		// 批量查询对方用户等级
		const otherUserIds = list.map(c => c.other_user_id).filter(Boolean)
		let chatLevelMap = {}
		if (otherUserIds.length) {
			const [levelRows] = await db.query('SELECT user_id, exp FROM user_levels WHERE user_id IN (?)', [otherUserIds])
			levelRows.forEach(lr => { chatLevelMap[lr.user_id] = getLevelInfo(lr.exp) })
		}
		list.forEach(c => {
			c.level_info = chatLevelMap[c.other_user_id] || null
		})

		list.sort((a, b) => new Date(b.last_time || b.updated_at) - new Date(a.last_time || a.updated_at))
		res.json({ code: 200, data: list })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取或创建私聊会话
router.post('/conversation/private', auth, async (req, res) => {
	try {
		const { user_id } = req.body
		if (!user_id) return res.json({ code: 400, msg: '缺少用户ID' })
		if (Number(user_id) === req.user.id) return res.json({ code: 400, msg: '不能和自己私聊' })

		const [myConvs] = await db.query('SELECT conversation_id FROM chat_members WHERE user_id = ?', [req.user.id])
		if (myConvs.length) {
			const convIds = myConvs.map(m => m.conversation_id)
			const [shared] = await db.query(
				`SELECT m.conversation_id FROM chat_members m
				JOIN chat_conversations c ON m.conversation_id = c.id
				WHERE m.conversation_id IN (?) AND m.user_id = ? AND c.type = 1`,
				[convIds, user_id]
			)
			if (shared.length) return res.json({ code: 200, data: { conversation_id: shared[0].conversation_id } })
		}

		const [result] = await db.query('INSERT INTO chat_conversations (type) VALUES (1)')
		await db.query('INSERT INTO chat_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
			[result.insertId, req.user.id, result.insertId, user_id])
		res.json({ code: 200, data: { conversation_id: result.insertId } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 创建群聊（仅超级管理员可创建，自动生成群聊号）
router.post('/conversation/group', auth, async (req, res) => {
	try {
		// 检查是否为超级管理员 (role=1)
		const [userRows] = await db.query('SELECT role FROM users WHERE id = ?', [req.user.id])
		if (!userRows.length || userRows[0].role !== 1) {
			return res.json({ code: 403, msg: '仅超级管理员可创建群聊' })
		}

		const { name, member_ids } = req.body
		if (!name) return res.json({ code: 400, msg: '请输入群名' })
		if (!member_ids || !member_ids.length) return res.json({ code: 400, msg: '请选择成员' })

		const allIds = [req.user.id, ...member_ids.map(id => Number(id)).filter(id => id !== req.user.id)]
		const [myConvs] = await db.query('SELECT conversation_id FROM chat_members WHERE user_id = ?', [req.user.id])
		if (myConvs.length) {
			const convIds = myConvs.map(m => m.conversation_id)
			const [groupConvs] = await db.query(
				'SELECT c.id, COUNT(m.user_id) as mc FROM chat_conversations c JOIN chat_members m ON c.id = m.conversation_id WHERE c.id IN (?) AND c.type = 2 GROUP BY c.id',
				[convIds]
			)
			for (const gc of groupConvs) {
				if (gc.mc === allIds.length) {
					const [gMembers] = await db.query('SELECT user_id FROM chat_members WHERE conversation_id = ?', [gc.id])
					const gMemberIds = gMembers.map(m => m.user_id).sort((a, b) => a - b)
					const sortedAll = [...allIds].sort((a, b) => a - b)
					if (gMemberIds.join(',') === sortedAll.join(',')) {
						return res.json({ code: 200, data: { conversation_id: gc.id } })
					}
				}
			}
		}

		// 生成唯一群聊号
		let groupCode
		let exists = true
		while (exists) {
			groupCode = String(Math.floor(100000 + Math.random() * 900000))
			const [rows] = await db.query('SELECT id FROM chat_conversations WHERE group_code = ?', [groupCode])
			exists = rows.length > 0
		}

		const [result] = await db.query(
			'INSERT INTO chat_conversations (type, name, group_code, created_by) VALUES (2, ?, ?, ?)',
			[name, groupCode, req.user.id]
		)
		const vals = [[result.insertId, req.user.id]]
		member_ids.forEach(uid => {
			if (Number(uid) !== req.user.id) vals.push([result.insertId, uid])
		})
		await db.query('INSERT INTO chat_members (conversation_id, user_id) VALUES ?', [vals])

		await db.query(
			'INSERT INTO chat_messages (conversation_id, sender_id, content, type) VALUES (?, 0, ?, 3)',
			[result.insertId, '群聊已创建']
		)

		res.json({ code: 200, data: { conversation_id: result.insertId, group_code: groupCode } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 通过群聊号加入群聊
router.post('/conversation/join', auth, async (req, res) => {
	try {
		const { group_code } = req.body
		if (!group_code) return res.json({ code: 400, msg: '请输入群聊号' })

		const [convs] = await db.query('SELECT * FROM chat_conversations WHERE group_code = ? AND type = 2', [group_code])
		if (!convs.length) return res.json({ code: 404, msg: '群聊不存在' })

		const convId = convs[0].id
		const [members] = await db.query('SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?', [convId, req.user.id])
		if (members.length) return res.json({ code: 400, msg: '你已在该群聊中' })

		await db.query('INSERT INTO chat_members (conversation_id, user_id) VALUES (?, ?)', [convId, req.user.id])

		const [userRows] = await db.query('SELECT nickname FROM users WHERE id = ?', [req.user.id])
		const nickname = userRows.length ? userRows[0].nickname : '用户'
		await db.query(
			'INSERT INTO chat_messages (conversation_id, sender_id, content, type) VALUES (?, 0, ?, 3)',
			[convId, nickname + ' 加入了群聊']
		)

		res.json({ code: 200, data: { conversation_id: convId } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 退出群聊
router.post('/conversation/leave', auth, async (req, res) => {
	try {
		const { conversation_id } = req.body
		if (!conversation_id) return res.json({ code: 400, msg: '参数不完整' })

		const [conv] = await db.query('SELECT type, created_by FROM chat_conversations WHERE id = ?', [conversation_id])
		if (!conv.length) return res.json({ code: 404, msg: '群聊不存在' })
		if (conv[0].type !== 2) return res.json({ code: 400, msg: '仅群聊可退出' })

		// 群主不能退出
		if (conv[0].created_by === req.user.id) return res.json({ code: 400, msg: '群主不能退出群聊' })

		await db.query('DELETE FROM chat_members WHERE conversation_id = ? AND user_id = ?', [conversation_id, req.user.id])
		res.json({ code: 200, msg: '已退出群聊' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 管理员踢人
router.post('/conversation/kick', auth, async (req, res) => {
	try {
		const { conversation_id, user_id } = req.body
		if (!conversation_id || !user_id) return res.json({ code: 400, msg: '参数不完整' })

		// 检查是否为群聊
		const [conv] = await db.query('SELECT type, created_by FROM chat_conversations WHERE id = ?', [conversation_id])
		if (!conv.length) return res.json({ code: 404, msg: '群聊不存在' })
		if (conv[0].type !== 2) return res.json({ code: 400, msg: '仅群聊可踢人' })

		// 检查操作者是否为群主或管理员
		const [op] = await db.query('SELECT role FROM users WHERE id = ?', [req.user.id])
		if (!op.length) return res.json({ code: 403, msg: '无权操作' })
		if (op[0].role !== 1 && conv[0].created_by !== req.user.id) return res.json({ code: 403, msg: '仅群主或管理员可踢人' })

		// 不能踢自己
		if (user_id === req.user.id) return res.json({ code: 400, msg: '不能踢自己' })

		// 不能踢群主
		if (user_id === conv[0].created_by) return res.json({ code: 400, msg: '不能踢群主' })

		await db.query('DELETE FROM chat_members WHERE conversation_id = ? AND user_id = ?', [conversation_id, user_id])
		res.json({ code: 200, msg: '已将该成员移出群聊' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取会话消息
router.get('/messages/:conversationId', auth, async (req, res) => {
	try {
		const { page = 1, pageSize = 30 } = req.query
		const offset = (page - 1) * pageSize

		const [member] = await db.query(
			'SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?',
			[req.params.conversationId, req.user.id]
		)
		if (!member.length) return res.json({ code: 403, msg: '无权访问' })

		const [msgs] = await db.query(
			`SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar
			FROM chat_messages m
			LEFT JOIN users u ON m.sender_id = u.id
			WHERE m.conversation_id = ?
			ORDER BY m.created_at DESC
			LIMIT ? OFFSET ?`,
			[req.params.conversationId, Number(pageSize), Number(offset)]
		)

		await db.query(
			'UPDATE chat_messages SET is_read = 1 WHERE conversation_id = ? AND sender_id != ? AND is_read = 0',
			[req.params.conversationId, req.user.id]
		)

		res.json({ code: 200, data: msgs.reverse() })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 发送消息
router.post('/messages', auth, async (req, res) => {
	try {
		const { conversation_id, content, type } = req.body
		if (!conversation_id || !content) return res.json({ code: 400, msg: '参数不完整' })

		const [member] = await db.query(
			'SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?',
			[conversation_id, req.user.id]
		)
		if (!member.length) return res.json({ code: 403, msg: '无权发送' })

		let finalContent = content
		// 处理红包消息：扣款
		if (type === 6) {
			try {
				const rpData = JSON.parse(content)
				const coins = Math.max(0, Math.min(parseInt(rpData.coins) || 0, 10000))
				if (coins > 0) {
					const [userRows] = await db.query('SELECT balance FROM user_coins WHERE user_id = ?', [req.user.id])
					if (!userRows.length || userRows[0].balance < coins) {
						return res.json({ code: 400, msg: '留币不足' })
					}
					await db.query('UPDATE user_coins SET balance = balance - ?, total_spent = total_spent + ? WHERE user_id = ?', [coins, coins, req.user.id])
					await db.query('INSERT INTO coin_transactions (user_id, type, amount, description) VALUES (?, 2, ?, ?)',
						[req.user.id, -coins, `聊天红包(${coins}留币)`])
					rpData.sender_id = req.user.id
					finalContent = JSON.stringify(rpData)
				}
			} catch (e) {
				console.error('红包处理失败:', e)
			}
		}

		const [result] = await db.query(
			'INSERT INTO chat_messages (conversation_id, sender_id, content, type) VALUES (?, ?, ?, ?)',
			[conversation_id, req.user.id, finalContent, type || 1]
		)

		await db.query('UPDATE chat_conversations SET updated_at = NOW() WHERE id = ?', [conversation_id])

		const [others] = await db.query(
			'SELECT user_id FROM chat_members WHERE conversation_id = ? AND user_id != ?',
			[conversation_id, req.user.id]
		)
		for (const o of others) {
			await db.query(
				'INSERT INTO messages (from_user_id, to_user_id, type, content, target_id) VALUES (?, ?, 4, ?, ?)',
				[req.user.id, o.user_id, '发来了一条私信', conversation_id]
			)
		}

		res.json({ code: 200, data: { id: result.insertId } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取未读私信总数
router.get('/unread', auth, async (req, res) => {
	try {
		const [members] = await db.query('SELECT conversation_id FROM chat_members WHERE user_id = ?', [req.user.id])
		if (!members.length) return res.json({ code: 200, data: { count: 0 } })

		const convIds = members.map(m => m.conversation_id)
		const [rows] = await db.query(
			'SELECT COUNT(*) as count FROM chat_messages WHERE conversation_id IN (?) AND sender_id != ? AND is_read = 0',
			[convIds, req.user.id]
		)
		res.json({ code: 200, data: { count: Number(rows[0].count)||0 } })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 获取群聊成员列表
router.get('/conversation/:id/members', auth, async (req, res) => {
	try {
		const [member] = await db.query(
			'SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?',
			[req.params.id, req.user.id]
		)
		if (!member.length) return res.json({ code: 403, msg: '无权访问' })

		const [members] = await db.query(
			'SELECT u.id, u.nickname, u.avatar FROM chat_members m LEFT JOIN users u ON m.user_id = u.id WHERE m.conversation_id = ?',
			[req.params.id]
		)
		res.json({ code: 200, data: members })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})


// 撤回消息
router.delete("/messages/:id", auth, async (req, res) => {
	try {
		const [rows] = await db.query("SELECT * FROM chat_messages WHERE id = ? AND sender_id = ?", [req.params.id, req.user.id])
		if (!rows.length) return res.json({ code: 403, msg: "无权撤回" })
		const msg = rows[0]
		const diff = (Date.now() - new Date(msg.created_at).getTime()) / 1000
		if (diff > 120) return res.json({ code: 400, msg: "超过2分钟，无法撤回" })
		await db.query("UPDATE chat_messages SET is_recalled = 1 WHERE id = ?", [req.params.id])
		res.json({ code: 200, msg: "ok" })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: "服务器错误" })
	}
})

// 标记已读
router.post('/messages/:conversationId/read', auth, async (req, res) => {
	try {
		await db.query(
			'UPDATE chat_messages SET is_read = 1 WHERE conversation_id = ? AND sender_id != ? AND is_read = 0',
			[req.params.conversationId, req.user.id]
		)
		res.json({ code: 200, msg: 'ok' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 置顶/取消置顶会话
router.post('/conversation/pin', auth, async (req, res) => {
	try {
		const { conversation_id, pinned } = req.body
		if (!conversation_id) return res.json({ code: 400, msg: '缺少会话ID' })
		const [member] = await db.query('SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?', [conversation_id, req.user.id])
		if (!member.length) return res.json({ code: 403, msg: '无权操作' })
		await db.query('UPDATE chat_members SET is_pinned = ? WHERE conversation_id = ? AND user_id = ?', [pinned ? 1 : 0, conversation_id, req.user.id])
		res.json({ code: 200, msg: pinned ? '已置顶' : '已取消置顶' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

// 隐藏/删除会话（仅对当前用户）
router.post('/conversation/hide', auth, async (req, res) => {
	try {
		const { conversation_id } = req.body
		if (!conversation_id) return res.json({ code: 400, msg: '缺少会话ID' })
		const [member] = await db.query('SELECT id FROM chat_members WHERE conversation_id = ? AND user_id = ?', [conversation_id, req.user.id])
		if (!member.length) return res.json({ code: 403, msg: '无权操作' })
		await db.query('UPDATE chat_members SET is_hidden = 1 WHERE conversation_id = ? AND user_id = ?', [conversation_id, req.user.id])
		res.json({ code: 200, msg: '已删除' })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
