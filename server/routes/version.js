const express = require('express')
const db = require('../config/db')
const redis = require('../config/redis')
const { auth, adminAuth } = require('../middleware/auth')
const router = express.Router()

router.get('/check', async (req, res) => {
	try {
		const platform = req.query.platform || 'android'
		const currentCode = parseInt(req.query.versionCode) || 0

		// 尝试从缓存获取（redis.js的set/get已内置JSON序列化，无需再JSON.stringify）
		const cacheKey = `version:latest:${platform}`
		let cached = await redis.get(cacheKey)
		if (cached) {
			const latest = cached
			if (latest.version_code <= currentCode) {
				return res.json({ code: 200, data: { hasUpdate: false } })
			}
			return res.json({
				code: 200,
				data: {
					hasUpdate: true,
					versionCode: latest.version_code,
					versionName: latest.version_name,
					updateType: latest.update_type,
					forceUpdate: latest.force_update === 1,
					downloadUrl: latest.download_url,
					updateContent: latest.update_content ? latest.update_content.split('\n').filter(s => s.trim()) : [],
					packageSize: latest.package_size
				}
			})
		}

		const [rows] = await db.query(
			'SELECT * FROM app_versions WHERE platform = ? AND status = 1 ORDER BY version_code DESC LIMIT 1',
			[platform]
		)

		if (!rows.length) {
			return res.json({ code: 200, data: { hasUpdate: false } })
		}

		const latest = rows[0]
		// 缓存5分钟（redis.js的set已内置JSON.stringify，直接传对象）
		await redis.set(cacheKey, latest, 300)

		if (latest.version_code <= currentCode) {
			return res.json({ code: 200, data: { hasUpdate: false } })
		}

		res.json({
			code: 200,
			data: {
				hasUpdate: true,
				versionCode: latest.version_code,
				versionName: latest.version_name,
				updateType: latest.update_type,
				forceUpdate: latest.force_update === 1,
				downloadUrl: latest.download_url,
				updateContent: latest.update_content ? latest.update_content.split('\n').filter(s => s.trim()) : [],
				packageSize: latest.package_size
			}
		})
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.get('/list', adminAuth, async (req, res) => {
	try {
		const [rows] = await db.query('SELECT * FROM app_versions ORDER BY version_code DESC LIMIT 50')
		res.json({ code: 200, data: rows })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.post('/', adminAuth, async (req, res) => {
	try {
		const { version_code, version_name, platform, update_type, force_update, download_url, update_content, package_size } = req.body
		if (!version_code || !version_name || !download_url) {
			return res.json({ code: 400, msg: '版本号、版本名和下载地址必填' })
		}
		const [result] = await db.query(
			'INSERT INTO app_versions (version_code, version_name, platform, update_type, force_update, download_url, update_content, package_size) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
			[version_code, version_name, platform || 'android', update_type || 1, force_update || 0, download_url, update_content || '', package_size || '']
		)
		res.json({ code: 200, msg: '版本发布成功', data: { id: result.insertId } })
	} catch (e) {
		console.error(e)
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.put('/:id', adminAuth, async (req, res) => {
	try {
		const { version_code, version_name, platform, update_type, force_update, download_url, update_content, package_size, status } = req.body
		await db.query(
			'UPDATE app_versions SET version_code=?, version_name=?, platform=?, update_type=?, force_update=?, download_url=?, update_content=?, package_size=?, status=? WHERE id=?',
			[version_code, version_name, platform, update_type, force_update, download_url, update_content, package_size, status, req.params.id]
		)
		res.json({ code: 200, msg: '更新成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

router.delete('/:id', adminAuth, async (req, res) => {
	try {
		await db.query('DELETE FROM app_versions WHERE id = ?', [req.params.id])
		res.json({ code: 200, msg: '删除成功' })
	} catch (e) {
		res.json({ code: 500, msg: '服务器错误' })
	}
})

module.exports = router
