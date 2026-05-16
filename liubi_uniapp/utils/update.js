import { BASE_URL } from '@/utils/request.js'

const CHECK_INTERVAL = 30 * 60 * 1000

export function checkUpdate(silent = true) {
	return new Promise((resolve) => {
		// #ifndef APP-PLUS
		if (silent) return resolve(null)
		uni.showToast({ title: '仅支持App端更新', icon: 'none' })
		return resolve(null)
		// #endif

		// #ifdef APP-PLUS
		const now = Date.now()
		const lastCheck = uni.getStorageSync('last_update_check') || 0

		if (silent && now - lastCheck < CHECK_INTERVAL) {
			return resolve(null)
		}

		plus.runtime.getProperty(plus.runtime.appid, (widgetInfo) => {
			const currentCode = parseInt(widgetInfo.versionCode) || 0
			const platform = plus.os.name === 'iOS' ? 'ios' : 'android'

			uni.request({
				url: BASE_URL + '/version/check',
				method: 'GET',
				data: { platform, versionCode: currentCode },
				success: (res) => {
					uni.setStorageSync('last_update_check', Date.now())
					if (res.statusCode === 200 && res.data && res.data.code === 200) {
						const data = res.data.data
						if (data.hasUpdate) {
							uni.setStorageSync('update_info', JSON.stringify(data))
							resolve(data)
						} else {
							uni.removeStorageSync('update_info')
							if (!silent) {
								uni.showToast({ title: '已是最新版本', icon: 'none' })
							}
							resolve(null)
						}
					} else {
						if (!silent) {
							uni.showToast({ title: '检查失败', icon: 'none' })
						}
						resolve(null)
					}
				},
				fail: () => {
					if (!silent) {
						uni.showToast({ title: '网络异常', icon: 'none' })
					}
					resolve(null)
				}
			})
		}, () => {
			plus.runtime.getProperty('__UNI__F1B7E9E', (widgetInfo) => {
				const currentCode = parseInt(widgetInfo.versionCode) || 0
				const platform = plus.os.name === 'iOS' ? 'ios' : 'android'

				uni.request({
					url: BASE_URL + '/version/check',
					method: 'GET',
					data: { platform, versionCode: currentCode },
					success: (res) => {
						uni.setStorageSync('last_update_check', Date.now())
						if (res.statusCode === 200 && res.data && res.data.code === 200) {
							const data = res.data.data
							if (data.hasUpdate) {
								uni.setStorageSync('update_info', JSON.stringify(data))
								resolve(data)
							} else {
								uni.removeStorageSync('update_info')
								if (!silent) uni.showToast({ title: '已是最新版本', icon: 'none' })
								resolve(null)
							}
						} else {
							if (!silent) uni.showToast({ title: '检查失败', icon: 'none' })
							resolve(null)
						}
					},
					fail: () => {
						if (!silent) uni.showToast({ title: '网络异常', icon: 'none' })
						resolve(null)
					}
				})
			}, () => {
				resolve(null)
			})
		})
		// #endif
	})
}

export function getStoredUpdateInfo() {
	try {
		const str = uni.getStorageSync('update_info')
		if (str) return JSON.parse(str)
	} catch {}
	return null
}

export function clearStoredUpdateInfo() {
	uni.removeStorageSync('update_info')
}
