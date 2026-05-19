const express = require('express')
const multer = require('multer')
const path = require('path')
const fs = require('fs')
const { auth } = require('../middleware/auth')
const router = express.Router()

const uploadDir = path.join(__dirname, '..', 'uploads')
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true })

const thumbDir = path.join(__dirname, '..', 'uploads', 'thumbs')
if (!fs.existsSync(thumbDir)) fs.mkdirSync(thumbDir, { recursive: true })

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

router.post('/', auth, upload.array('files', 18), async (req, res) => {
	if (!req.files || !req.files.length) return res.json({ code: 400, msg: '请选择文件' })
	const list = []
	for (const f of req.files) {
		const type = f.mimetype.startsWith('video/') ? 'video' : (f.mimetype.startsWith('audio/') ? 'audio' : 'image')
		const item = { url: '/uploads/' + f.filename, type }
		if (type === 'image') {
			try {
				const thumbUrl = await generateThumb(f.path, f.filename)
				if (thumbUrl) item.thumb_url = thumbUrl
			} catch (_) {}
		}
		list.push(item)
	}
	res.json({ code: 200, data: { list } })
})

router.post('/single', auth, upload.single('file'), async (req, res) => {
	if (!req.file) return res.json({ code: 400, msg: '请选择文件' })
	const type = req.file.mimetype.startsWith('video/') ? 'video' : (req.file.mimetype.startsWith('audio/') ? 'audio' : 'image')
	const data = { url: '/uploads/' + req.file.filename, type }
	if (type === 'image') {
		try {
			const thumbUrl = await generateThumb(req.file.path, req.file.filename)
			if (thumbUrl) data.thumb_url = thumbUrl
		} catch (_) {}
	}
	res.json({ code: 200, data })
})

async function generateThumb(filePath, originalFilename) {
	try {
		const sharp = require('sharp')
		const ext = path.extname(originalFilename)
		const baseName = path.basename(originalFilename, ext)
		const thumbFilename = baseName + '_thumb' + ext
		const thumbPath = path.join(thumbDir, thumbFilename)

		await sharp(filePath)
			.resize(400, 400, { fit: 'inside', withoutEnlargement: true })
			.jpeg({ quality: 75 })
			.toFile(thumbPath)

		return '/uploads/thumbs/' + thumbFilename
	} catch (_) {
		return null
	}
}

router.get('/thumb', (req, res) => {
	const src = req.query.src
	if (!src) return res.status(400).json({ code: 400, msg: '缺少src参数' })

	const imagePath = path.join(__dirname, '..', src.startsWith('/uploads/') ? src : '/uploads/' + src)
	if (!fs.existsSync(imagePath)) return res.status(404).json({ code: 404, msg: '图片不存在' })

	const ext = path.extname(imagePath).toLowerCase()
	const baseName = path.basename(imagePath, ext)
	const thumbFilename = baseName + '_thumb.jpg'
	const thumbPath = path.join(thumbDir, thumbFilename)

	if (fs.existsSync(thumbPath)) {
		return res.sendFile(thumbPath)
	}

	try {
		const sharp = require('sharp')
		sharp(imagePath)
			.resize(400, 400, { fit: 'inside', withoutEnlargement: true })
			.jpeg({ quality: 75 })
			.toFile(thumbPath)
			.then(() => {
				res.sendFile(thumbPath)
			})
			.catch(() => {
				res.sendFile(imagePath)
			})
	} catch (_) {
		res.sendFile(imagePath)
	}
})

module.exports = router
