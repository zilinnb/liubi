const https = require('https')
const http = require('http')

const cache = new Map()
const CACHE_TTL = 3600000

function getIpLocation(ip) {
	return new Promise((resolve) => {
		if (!ip || ip === '127.0.0.1' || ip === '::1' || ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
			return resolve('本地')
		}

		const cached = cache.get(ip)
		if (cached && Date.now() - cached.time < CACHE_TTL) {
			return resolve(cached.location)
		}

		const url = `http://ip-api.com/json/${ip}?lang=zh-CN&fields=status,country,regionName,city`

		http.get(url, (res) => {
			let data = ''
			res.on('data', (chunk) => { data += chunk })
			res.on('end', () => {
				try {
					const json = JSON.parse(data)
					if (json.status === 'success') {
						let location = ''
						if (json.regionName && json.city && json.regionName !== json.city) {
							location = json.regionName + '·' + json.city
						} else if (json.city) {
							location = json.city
						} else if (json.regionName) {
							location = json.regionName
						} else if (json.country) {
							location = json.country
						}
						if (!location) location = '未知'
						cache.set(ip, { location, time: Date.now() })
						resolve(location)
					} else {
						resolve('未知')
					}
				} catch (e) {
					resolve('未知')
				}
			})
		}).on('error', () => {
			resolve('未知')
		})

		setTimeout(() => resolve('未知'), 3000)
	})
}

function getClientIp(req) {
	let ip = req.headers['x-forwarded-for'] ||
		req.headers['x-real-ip'] ||
		req.connection?.remoteAddress ||
		req.socket?.remoteAddress ||
		req.ip ||
		''

	if (ip.includes(',')) {
		ip = ip.split(',')[0].trim()
	}

	if (ip.startsWith('::ffff:')) {
		ip = ip.replace('::ffff:', '')
	}

	return ip
}

module.exports = { getIpLocation, getClientIp }
