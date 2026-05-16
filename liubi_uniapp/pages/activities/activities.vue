<template>
	<view class="page-activities">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">动态</text>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="act-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="act-list">
				<view class="act-card" v-for="a in activities" :key="a.id">
					<view class="act-top">
							<image v-if="a.user_avatar" class="act-avatar" :src="fullUrl(a.user_avatar)" mode="aspectFill" />
						<view v-else class="act-avatar act-avatar-letter" :style="{ background: actBg(a.type) }">
							<text class="act-avatar-text">{{ (a.user_nickname||"?").slice(0,1) }}</text>
						</view>
						<view class="act-main">
							<text class="act-content">{{ formatActivity(a) }}</text>
							<text class="act-time">{{ fmtTime(a.created_at) }}</text>
						</view>
					</view>
					<view v-if="a.post" class="act-post" @tap="goDetail(a.target_id)">
						<image v-if="a.post.cover" class="act-cover" :src="fullUrl(a.post.cover)" mode="aspectFill" />
						<view class="act-post-info">
							<text class="act-post-title">{{ a.post.title }}</text>
							<text class="act-post-preview">{{ (a.post.content||'').slice(0, 50) }}</text>
						</view>
					</view>
				</view>
			</view>
			<view class="feed-end" v-if="loading">
				<view class="loading-dots">
					<view class="dot" v-for="i in 3" :key="i"></view>
				</view>
			</view>
			<view class="feed-end" v-if="!loading && !activities.length">
				<text class="empty-hint">暂无动态</text>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { request, BASE_URL } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const userId = ref(null)
const activities = ref([])
const page = ref(1)
const loading = ref(false)

function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api', '') + url }


function actBg(type) {
	return { 1: '#fff7e6', 2: '#fff0f0', 3: '#e8f4fd', 4: '#f9f0ff', 5: '#e8f8e8' }[type] || '#f5f5f5'
}

function formatActivity(a) {
	const map = {
		1: '发布了笔记',
		2: '赞了笔记',
		3: '评论了笔记',
		4: '收藏了笔记',
		5: a.target_title ? `关注了 ${a.target_title}` : '关注了用户'
	}
	if (a.type === 5 && a.target_title) return `关注了 ${a.target_title}`
	const prefix = a.target_title ? `${map[a.type]}「${a.target_title.slice(0, 20)}」` : map[a.type]
	return prefix
}

function fmtTime(d) {
	if (!d) return ''
	const now = Date.now(), t = new Date(d).getTime(), diff = (now - t) / 1000
	if (diff < 60) return '刚刚'
	if (diff < 3600) return Math.floor(diff / 60) + '分钟前'
	if (diff < 86400) return Math.floor(diff / 3600) + '小时前'
	return Math.floor(diff / 86400) + '天前'
}

onLoad(async (o) => {
	userId.value = o.userId
	await loadActivities()
})

async function loadActivities() {
	if (loading.value) return
	loading.value = true
	const res = await request({ url: '/users/' + userId.value + '/activities', data: { page: page.value } })
	if (res.code === 200) {
		activities.value = page.value === 1 ? res.data : [...activities.value, ...res.data]
	}
	loading.value = false
}

function loadMore() {
	page.value++
	loadActivities()
}

function goDetail(id) { if (id) uni.navigateTo({ url: '/pages/detail/detail?id=' + id }) }
function goBack() { uni.navigateBack() }
</script>

<style lang="scss" scoped>
.page-activities { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 16rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; }
.nav-title { font-size: 32rpx; font-weight: 700; color: #222; }

.act-scroll { height: calc(100vh - 44px - 40rpx); }
.act-list { padding: 12rpx 16rpx; }
.act-card { background: #fff; border-radius: 16rpx; padding: 24rpx; margin-bottom: 12rpx; animation: fadeIn .3s ease; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(12rpx); } to { opacity: 1; transform: translateY(0); } }
.act-top { display: flex; align-items: flex-start; }
.act-avatar { width: 56rpx; height: 56rpx; border-radius: 50%; flex-shrink: 0; margin-right: 16rpx; }
.act-avatar-letter { display: flex; align-items: center; justify-content: center; }
.act-avatar-text { font-size: 24rpx; color: #fff; font-weight: 600; }
.act-main { flex: 1; }
.act-content { font-size: 28rpx; color: #333; line-height: 1.5; }
.act-time { font-size: 22rpx; color: #bbb; display: block; margin-top: 8rpx; }

.act-post { display: flex; margin-top: 16rpx; padding: 16rpx; background: #f8f8f8; border-radius: 12rpx; transition: background .15s; }
.act-post:active { background: #f0f0f0; }
.act-cover { width: 100rpx; height: 80rpx; border-radius: 8rpx; flex-shrink: 0; margin-right: 14rpx; }
.act-post-info { flex: 1; overflow: hidden; }
.act-post-title { font-size: 26rpx; color: #333; font-weight: 500; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 1; overflow: hidden; }
.act-post-preview { font-size: 22rpx; color: #999; display: block; margin-top: 6rpx; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.feed-end { padding: 32rpx 0; text-align: center; }
.empty-hint { font-size: 26rpx; color: #ccc; }
.loading-dots { display: flex; justify-content: center; gap: 12rpx; }
.dot { width: 12rpx; height: 12rpx; border-radius: 50%; background: #ccc; animation: dotPulse 1.2s ease infinite; }
.dot:nth-child(2) { animation-delay: .2s; }
.dot:nth-child(3) { animation-delay: .4s; }
@keyframes dotPulse { 0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }
</style>
