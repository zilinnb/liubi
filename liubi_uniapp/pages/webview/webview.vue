<template>
	<view class="page-webview">
		<view class="wv-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="wv-nav-inner">
				<view class="wv-back" @tap="goBack"><text class="wv-back-arrow">‹</text></view>
				<view class="wv-title-wrap">
					<text class="wv-title">{{ pageTitle }}</text>
				</view>
				<view class="wv-action" @tap="copyUrl"><text class="wv-action-text">复制</text></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>
		<web-view :src="url" class="wv-content" @message="onMessage"></web-view>
	</view>
</template>

<script setup>
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const url = ref('')
const pageTitle = ref('')

onLoad((query) => {
	if (query.url) {
		url.value = decodeURIComponent(query.url)
		try {
			const u = new URL(url.value)
			pageTitle.value = u.hostname
		} catch {
			pageTitle.value = '链接'
		}
	}
	if (query.title) {
		pageTitle.value = decodeURIComponent(query.title)
	}
})

function goBack() {
	uni.navigateBack()
}

function copyUrl() {
	uni.setClipboardData({
		data: url.value,
		success: () => {
			uni.showToast({ title: '链接已复制', icon: 'none' })
		}
	})
}

function onMessage(e) {
}
</script>

<style lang="scss" scoped>
.page-webview { min-height: 100vh; background: #fff; }
.wv-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.wv-nav-inner { height: 44px; display: flex; align-items: center; padding: 0 16rpx; }
.wv-back { padding: 8rpx 16rpx; }
.wv-back-arrow { font-size: 44rpx; color: #222; font-weight: 300; }
.wv-title-wrap { flex: 1; overflow: hidden; display: flex; align-items: center; justify-content: center; }
.wv-title { font-size: 28rpx; color: #333; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 100%; }
.wv-action { padding: 8rpx 16rpx; }
.wv-action-text { font-size: 26rpx; color: #3378e5; }
.wv-content { width: 100%; }
</style>
