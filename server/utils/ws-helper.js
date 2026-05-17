const WebSocket = require('ws')

let wsClients = new Map()

function setWsClients(map) {
	wsClients = map
}

function sendToUser(userId, data) {
	const clients = wsClients.get(userId)
	if (!clients) return
	const msg = JSON.stringify(data)
	for (const ws of clients) {
		if (ws.readyState === WebSocket.OPEN) {
			ws.send(msg)
		}
	}
}

async function pushNotification(db, toUserId, notifType, fromUserId, targetId) {
	try {
		const [fromUser] = await db.query('SELECT nickname, avatar FROM users WHERE id = ?', [fromUserId])
		const sender = fromUser[0] || {}

		let targetTitle = ''
		if (targetId && [1, 2, 6].includes(notifType)) {
			const [post] = await db.query('SELECT title FROM posts WHERE id = ?', [targetId])
			if (post.length) targetTitle = post[0].title || ''
		}

		sendToUser(toUserId, {
			type: 'notification',
			data: {
				notif_type: notifType,
				from_user_id: fromUserId,
				from_user_name: sender.nickname || '',
				from_user_avatar: sender.avatar || '',
				target_id: targetId || null,
				target_title: targetTitle,
			}
		})
	} catch (e) {
		console.error('[WS] pushNotification error:', e.message)
	}
}

module.exports = { wsClients, sendToUser, pushNotification, setWsClients }
