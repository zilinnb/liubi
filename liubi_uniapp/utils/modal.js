export function showModal(options = {}) {
	return new Promise((resolve) => {
		uni.showModal({
			title: options.title || '提示',
			content: options.content || '',
			showCancel: options.showCancel !== false,
			cancelText: options.cancelText || '取消',
			confirmText: options.confirmText || '确定',
			confirmColor: '#ff2442',
			success: (res) => resolve(res.confirm)
		})
	})
}
