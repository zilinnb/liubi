require('dotenv').config()
const redis = require('redis')

let client = null

async function init() {
	if (client) return client
	try {
		client = redis.createClient({
			url: process.env.REDIS_URL || 'redis://localhost:6379',
			socket: { connectTimeout: 5000 }
		})
		client.on('error', (err) => {
			console.error('  [Redis] 连接错误:', err.message)
			client = null
		})
		await client.connect()
		console.log('  [Redis] 连接成功')
		return client
	} catch (e) {
		console.warn('  [Redis] 连接失败，将使用无缓存模式:', e.message)
		client = null
		return null
	}
}

async function get(key) {
	if (!client) return null
	try {
		const val = await client.get(key)
		return val ? JSON.parse(val) : null
	} catch { return null }
}

async function set(key, value, ttlSeconds = 60) {
	if (!client) return
	try {
		await client.setEx(key, ttlSeconds, JSON.stringify(value))
	} catch {}
}

async function del(key) {
	if (!client) return
	try {
		if (key.includes('*')) {
			const keys = await client.keys(key)
			if (keys.length) await client.del(keys)
		} else {
			await client.del(key)
		}
	} catch {}
}

module.exports = { init, get, set, del }
