<template>
	<view class="page-user-list">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">{{ title }}</text>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<view v-if="privateTip" class="private-box">
			<text class="private-icon">🔒</text>
			<text class="private-text">对方已设为私密</text>
		</view>

		<scroll-view v-else scroll-y class="list-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="user-list">
				<view class="user-row" v-for="u in users" :key="u.id" @tap="goProfile(u.id)">
					<view class="user-av" :style="{ background: avColor(u.id) }">
						<image v-if="u.avatar" class="user-av-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
						<text v-else class="user-av-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
					</view>
					<view class="user-info">
						<text class="user-name">{{ u.nickname || u.username }}</text>
						<text class="user-bio">{{ u.bio || '这个人很懒，什么都没写～' }}</text>
					</view>
					<view v-if="!isSelf(u.id)" class="follow-btn" :class="{ followed: u.is_followed }" @tap.stop="onFollow(u)">
						<text class="follow-text">{{ followLabel(u) }}</text>
					</view>
				</view>
			</view>
			<view class="feed-end" v-if="loading">
				<view class="loading-dots">
					<view class="dot" v-for="i in 3" :key="i"></view>
				</view>
			</view>
			<view class="feed-end" v-if="!loading && !users.length">
				<text class="empty-hint">暂无数据</text>
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

const userId = ref(null)
const type = ref('follows')
const users = ref([])
const loading = ref(false)
const privateTip = ref(false)

const titleMap = { follows: '关注', fans: '粉丝', likers: '赞过' }
const title = computed(() => titleMap[type.value] || '')

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function avColor(id) { return COLORS[id % COLORS.length] }
function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api', '') + url }
function followLabel(u) {
	if (u.is_followed && u.is_fan) return '互相关注'
	if (u.is_followed) return '已关注'
	if (u.is_fan) return '回关'
	return '+ 关注'
}
function isSelf(id) { return userStore.userInfo && id === userStore.userInfo.id }

onLoad(async (o) => {
	userId.value = o.userId
	type.value = o.type || 'follows'
	await loadUsers()
})

async function loadUsers() {
	loading.value = true
	privateTip.value = false
	const res = await request({ url: '/users/' + userId.value + '/' + type.value })
	if (res.code === 403) {
		privateTip.value = true
	} else if (res.code === 200) {
		users.value = res.data
	}
	loading.value = false
}

async function onFollow(u) {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const res = await userStore.followUser(u.id)
	if (res?.code === 200) { u.is_followed = res.data.followed; u.is_fan = res.data.is_fan }
}

function loadMore() { /* 当前不分页 */ }

function goProfile(id) { uni.navigateTo({ url: '/pages/user-profile/user-profile?userId=' + id }) }
function goBack() { uni.navigateBack() }
</script>

<style lang="scss" scoped>
.page-user-list { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; }
.nav-inner { height: 44px; display: flex; align-items: center; padding: 0 16rpx; }
.nav-left { padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; }
.nav-title { font-size: 32rpx; font-weight: 700; color: #222; margin-left: 16rpx; }

.private-box { display: flex; flex-direction: column; align-items: center; padding-top: 200rpx; }
.private-icon { font-size: 64rpx; }
.private-text { font-size: 28rpx; color: #999; margin-top: 16rpx; }

.list-scroll { height: calc(100vh - 44px - 40rpx); }
.user-list { padding: 12rpx 16rpx; }
.user-row { display: flex; align-items: center; padding: 20rpx 16rpx; background: #fff; border-radius: 16rpx; margin-bottom: 8rpx; transition: transform .15s; }
.user-row:active { transform: scale(0.98); }
.user-av { width: 88rpx; height: 88rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 20rpx; overflow: hidden; }
.user-av-img { width: 88rpx; height: 88rpx; }
.user-av-text { font-size: 32rpx; color: #fff; font-weight: 600; }
.user-info { flex: 1; overflow: hidden; }
.user-name { font-size: 28rpx; font-weight: 600; color: #222; display: block; }
.user-bio { font-size: 24rpx; color: #999; display: block; margin-top: 6rpx; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.follow-btn { padding: 10rpx 24rpx; border-radius: 24rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); transition: all .2s; flex-shrink: 0; }
.follow-btn:active { transform: scale(0.95); }
.followed { background: #f5f5f5; border: 1rpx solid #e8e8e8; }
.follow-text { font-size: 24rpx; color: #fff; font-weight: 600; }
.followed .follow-text { color: #999; font-weight: 400; }

.feed-end { padding: 32rpx 0; text-align: center; }
.empty-hint { font-size: 26rpx; color: #ccc; }
.loading-dots { display: flex; justify-content: center; gap: 12rpx; }
.dot { width: 12rpx; height: 12rpx; border-radius: 50%; background: #ccc; animation: dotPulse 1.2s ease infinite; }
.dot:nth-child(2) { animation-delay: .2s; }
.dot:nth-child(3) { animation-delay: .4s; }
@keyframes dotPulse { 0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }
</style>
