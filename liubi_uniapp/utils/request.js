const BASE_URL = 'http://38.55.198.185:3000/api'

const request = (options) => {
	const token = uni.getStorageSync('token') || ''
	return new Promise((resolve, reject) => {
		const isPost = options.method === 'POST' || options.method === 'PUT'
		const sendData = isPost && options.data ? JSON.stringify(options.data) : (options.data || null)
		uni.request({
			url: BASE_URL + options.url,
			method: options.method || 'GET',
			data: sendData,
			header: {
				'Content-Type': 'application/json',
				'Authorization': token ? 'Bearer ' + token : ''
			},
			success: (res) => {
				if (res.statusCode === 200) {
					resolve(res.data)
				} else if (res.statusCode === 401) {
					uni.removeStorageSync('token')
					uni.removeStorageSync('userInfo')
					resolve({ code: 401, msg: '请先登录' })
				} else {
					reject(new Error('HTTP ' + res.statusCode))
				}
			},
			fail: (err) => {
				reject(new Error(err.errMsg || '网络请求失败'))
			}
		})
	})
}

const uploadFile = (url, filePath) => {
	const token = uni.getStorageSync('token') || ''
	return new Promise((resolve) => {
		uni.uploadFile({
			url: BASE_URL + url,
			filePath,
			name: 'file',
			header: { 'Authorization': token ? 'Bearer ' + token : '' },
			success: (res) => {
				try {
					resolve(JSON.parse(res.data))
				} catch (e) {
					resolve({ code: 500, msg: '解析响应失败' })
				}
			},
			fail: () => {
				resolve({ code: 500, msg: '上传失败' })
			}
		})
	})
}

export { request, uploadFile, BASE_URL }
