const jwt = require('jsonwebtoken')
const { JWT_SECRET } = require('../config/env')

function auth(req, res, next) {
	const token = req.headers.authorization?.replace('Bearer ', '')
	if (!token) return res.status(401).json({ code: 401, msg: '未登录' })
	try {
		req.user = jwt.verify(token, JWT_SECRET)
		next()
	} catch {
		res.status(401).json({ code: 401, msg: 'token无效' })
	}
}

function adminAuth(req, res, next) {
	auth(req, res, () => {
		if (req.user.role !== 1) return res.status(403).json({ code: 403, msg: '无权限' })
		next()
	})
}

module.exports = { auth, adminAuth }
