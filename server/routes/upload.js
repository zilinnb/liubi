const express = require('express')
const multer = require('multer')
const path = require('path')
const fs = require('fs')
const { auth } = require('../middleware/auth')
const router = express.Router()

// 确保uploads目录存在
const uploadDir = path.join(__dirname, '..', 'uploads')
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true })

const storage = multer.diskStorage({
	destination: (req, file, cb) => cb(null, uploadDir),
	filename: (req, file, cb) => {
		const ext = path.extname(file.originalname) || getExtByMime(file.mimetype)
		cb(null, Date.now() + '-' + Math.random().toString(36).slice(2, 8) + ext)
	}
})

function getExtByMime(mime) {
	const map = {
		'image/jpeg': '.jpg', 'image/png': '.png', 'image/gif': '.gif', 'image/webp': '.webp',
		'video/mp4': '.mp4', 'video/quicktime': '.mov', 'video/x-msvideo': '.avi',
		'video/webm': '.webm', 'video/3gpp': '.3gp',
		'audio/mpeg': '.mp3', 'audio/wav': '.wav', 'audio/x-wav': '.wav',
		'audio/aac': '.aac', 'audio/x-m4a': '.m4a', 'audio/mp4': '.m4a',
		'audio/ogg': '.ogg', 'audio/flac': '.flac', 'audio/x-flac': '.flac'
	}
	return map[mime] || '.bin'
}

const upload = multer({
	storage,
	limits: { fileSize: 50 * 1024 * 1024 },
	fileFilter: (req, file, cb) => {
		const imgExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
		const vidExts = ['.mp4', '.mov', '.avi', '.webm', '.3gp']
		const audExts = ['.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac']
		const ext = path.extname(file.originalname).toLowerCase()
		if (imgExts.includes(ext) || vidExts.includes(ext) || audExts.includes(ext)) cb(null, true)
		else cb(new Error('不支持的文件格式: ' + ext))
	}
})

// 多文件上传（图片+视频混合）
router.post('/', auth, upload.array('files', 18), (req, res) => {
	if (!req.files || !req.files.length) return res.json({ code: 400, msg: '请选择文件' })
	const list = req.files.map(f => ({
		url: '/uploads/' + f.filename,
		type: f.mimetype.startsWith('video/') ? 'video' : (f.mimetype.startsWith('audio/') ? 'audio' : 'image')
	}))
	res.json({ code: 200, data: { list } })
})

router.post('/single', auth, upload.single('file'), (req, res) => {
	if (!req.file) return res.json({ code: 400, msg: '请选择文件' })
	const type = req.file.mimetype.startsWith('video/') ? 'video' : (req.file.mimetype.startsWith('audio/') ? 'audio' : 'image')
	res.json({ code: 200, data: { url: '/uploads/' + req.file.filename, type } })
})

module.exports = router
