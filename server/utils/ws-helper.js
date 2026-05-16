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

function pushNotification(toUserId, notifType, fromUserId) {
	sendToUser(toUserId, {
		type: 'notification',
		data: { to_user_id: toUserId, notif_type: notifType, from_user_id: fromUserId }
	})
}

module.exports = { wsClients, sendToUser, pushNotification, setWsClients }
