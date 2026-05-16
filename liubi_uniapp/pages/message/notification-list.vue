<template>
	<view class="page-notify">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">{{ title }}</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="notify-scroll" :show-scrollbar="false" refresher-enabled @refresherrefresh="onRefresh" :refresher-triggered="isRefreshing">
			<view v-if="list.length" class="notify-list">
				<view class="notify-row" v-for="m in list" :key="m.id" @tap="onTap(m)">
					<view class="notify-avatar" :style="{ background: msgColor(m.from_user_id) }">
						<image v-if="m.from_avatar" class="avatar-img" :src="fullUrl(m.from_avatar)" mode="aspectFill" />
						<text v-else class="avatar-text">{{ (m.from_nickname||'?').slice(0,1) }}</text>
						<view class="unread-dot" v-if="!m.is_read"></view>
					</view>
					<view class="notify-content">
						<view class="notify-header">
							<text class="notify-name">{{ m.from_nickname || '用户' }}</text>
							<text class="notify-time">{{ fmtTime(m.created_at) }}</text>
						</view>
						<view class="notify-desc-row">
							<text class="notify-type-label" :style="{ color: typeColor(m.type) }">{{ typeLabel(m.type) }}</text>
							<text class="notify-preview">{{ msgContent(m) }}</text>
						</view>
					</view>
				</view>
			</view>
			<view v-else-if="loaded" class="empty-state">
				<text class="empty-title">{{ emptyHint }}</text>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL } from '@/utils/request.js'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const list = ref([])
const loaded = ref(false)
const isRefreshing = ref(false)
const notifyType = ref('')

const titleMap = { '1,6': '赞和收藏', '3': '新增关注', '2,5': '评论和@' }
const title = computed(() => titleMap[notifyType.value] || '通知')

const emptyHint = computed(() => {
	if (notifyType.value === '1,6') return '暂无赞和收藏'
	if (notifyType.value === '3') return '暂无新增关注'
	if (notifyType.value === '2,5') return '暂无评论和@'
	return '暂无通知'
})

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function msgColor(id) { return COLORS[id % COLORS.length] }

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function fmtTime(d) {
	if (!d) return ''
	const now = Date.now(), t = new Date(d).getTime(), diff = (now - t) / 1000
	if (diff < 60) return '刚刚'
	if (diff < 3600) return Math.floor(diff / 60) + '分钟前'
	if (diff < 86400) return Math.floor(diff / 3600) + '小时前'
	return Math.floor(diff / 86400) + '天前'
}

function typeLabel(type) {
	const map = { 1: '赞', 2: '评论', 3: '关注', 5: '@', 6: '收藏' }
	return map[type] || '通知'
}

function typeColor(type) {
	const map = { 1: '#ff2442', 2: '#13c2c2', 3: '#1890ff', 5: '#722ed1', 6: '#faad14' }
	return map[type] || '#999'
}

function msgContent(m) {
	const map = {
		1: '了你的笔记',
		2: m.content || '了你的笔记',
		3: '了你',
		5: '在笔记中提到了你',
		6: '了你的笔记'
	}
	return map[m.type] || '新消息'
}

async function loadList() {
	try {
		const res = await request({ url: '/notifications?type=' + notifyType.value })
		if (res.code === 200 && Array.isArray(res.data)) {
			list.value = res.data
		} else {
			list.value = []
		}
	} catch (e) { list.value = [] }
	loaded.value = true
}

async function markAllRead() {
	try {
		await request({ url: '/notifications/read-all?type=' + notifyType.value, method: 'POST' })
	} catch (e) {}
}

async function onRefresh() {
	isRefreshing.value = true
	await loadList()
	setTimeout(() => { isRefreshing.value = false }, 300)
}

function onTap(m) {
	if (!m.is_read) {
		m.is_read = 1
		request({ url: '/notifications/' + m.id + '/read', method: 'POST' }).catch(() => {})
	}
	if (m.type === 3) {
		uni.navigateTo({ url: '/pages/user-profile/user-profile?userId=' + m.from_user_id })
	} else if (m.target_id) {
		uni.navigateTo({ url: '/pages/detail/detail?id=' + m.target_id })
	}
}

function goBack() { uni.navigateBack() }

onLoad(async (o) => {
	notifyType.value = o.type || ''
	await loadList()
	markAllRead()
})
</script>

<style lang="scss" scoped>
.page-notify { min-height: 100vh; background: #f5f5f5; }

.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 20rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 40rpx; color: #222; font-weight: 300; }
.nav-title { font-size: 32rpx; font-weight: 600; color: #222; }
.nav-right { width: 60rpx; }

.notify-scroll { height: calc(100vh - 120rpx); }
.notify-list { background: #fff; }

.notify-row { display: flex; align-items: center; padding: 24rpx; border-bottom: 1rpx solid #f5f5f5; }
.notify-row:active { background: #fafafa; }
.notify-row:last-child { border-bottom: none; }

.notify-avatar { width: 80rpx; height: 80rpx; border-radius: 16rpx; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 20rpx; position: relative; overflow: hidden; }
.avatar-img { width: 100%; height: 100%; }
.avatar-text { font-size: 30rpx; color: #fff; font-weight: 600; }
.unread-dot { position: absolute; top: 0; right: 0; width: 20rpx; height: 20rpx; border-radius: 50%; background: #ff2442; border: 3rpx solid #fff; }

.notify-content { flex: 1; overflow: hidden; }
.notify-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8rpx; }
.notify-name { font-size: 28rpx; color: #222; font-weight: 600; }
.notify-time { font-size: 22rpx; color: #bbb; }
.notify-desc-row { display: flex; align-items: center; gap: 6rpx; }
.notify-type-label { font-size: 22rpx; font-weight: 600; }
.notify-preview { font-size: 26rpx; color: #888; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.empty-state { display: flex; flex-direction: column; align-items: center; padding-top: 200rpx; }
.empty-title { font-size: 28rpx; color: #aaa; }
</style>
