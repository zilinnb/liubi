<template>
	<view class="page-user-profile">
		<view class="sticky-nav" :style="{ paddingTop: statusBarH + 'px', background: navBg }">
			<view class="sticky-nav-inner">
				<view class="nav-back" @tap="goBack">
					<image class="nav-back-icon" src="/static/icons/back.png" mode="aspectFit" />
				</view>
				<view class="nav-center" :style="{ opacity: titleOpacity }">
					<text class="nav-name">{{ profile.nickname || profile.username }}</text>
				</view>
			</view>
		</view>

		<scroll-view
			scroll-y
			class="main-scroll"
			:show-scrollbar="false"
			@scroll="onScroll"
			@scrolltolower="loadMore"
			:scroll-top="scrollTopVal"
		>
			<view class="bg-area" :style="{ paddingTop: statusBarH + 'px' }">
				<image v-if="profile.bg_image" class="bg-image" :src="fullUrl(profile.bg_image)" mode="aspectFill" />
				<view v-else class="bg-default"></view>
				<view class="bg-mask"></view>
				<view class="top-actions">
					<view class="top-btn" @tap="goBack">
						<image class="top-btn-icon" src="/static/icons/back.png" mode="aspectFit" />
					</view>
				</view>
			</view>

			<view class="profile-section">
				<view class="card-top">
					<view class="avatar-wrap">
						<image v-if="profile.avatar" class="avatar-img" :src="fullUrl(profile.avatar)" mode="aspectFill" />
						<view v-else class="avatar-letter" :style="{ background: avatarBg }">
							<text class="letter-text">{{ avatarLetter }}</text>
						</view>
					</view>
					<view class="action-area" v-if="!isSelf">
						<view class="follow-btn" :class="{ followed: isFollowed }" @tap="onFollow">
							<text class="follow-text">{{ followLabel }}</text>
						</view>
						<view class="msg-btn" @tap="onMessage">
							<text class="msg-text">私信</text>
						</view>
					</view>
					<view class="action-area" v-else>
						<view class="edit-btn" @tap="goEdit">
							<text class="edit-text">编辑资料</text>
						</view>
					</view>
				</view>

				<view class="name-row">
					<text class="user-name">{{ profile.nickname || profile.username }}</text>
					<text class="gender-icon" v-if="profile.gender === 1">♂</text>
					<text class="gender-icon female" v-else-if="profile.gender === 2">♀</text>
				</view>
				<text class="user-id">留笔号：{{ profile.username }}</text>
				<text class="user-bio">{{ profile.bio || '这个人很懒，什么都没写～' }}</text>
				<view class="info-row" v-if="profile.birthday">
					<image class="info-icon" src="/static/icons/dianzan.png" mode="aspectFit" />
					<text class="info-text">{{ formatBirthday(profile.birthday) }}</text>
				</view>
				<view class="info-row" v-if="profile.location">
					<image class="info-icon" src="/static/icons/location.png" mode="aspectFit" />
					<text class="info-text">{{ profile.location }}</text>
				</view>

				<view class="stats-row">
					<view class="st" @tap="goList('follows')">
						<text class="st-num">{{ profile.follow_count||0 }}</text>
						<text class="st-label">关注</text>
					</view>
					<view class="st" @tap="goList('fans')">
						<text class="st-num">{{ profile.fans_count||0 }}</text>
						<text class="st-label">粉丝</text>
					</view>
					<view class="st" @tap="goList('likers')">
						<text class="st-num">{{ profile.like_count||0 }}</text>
						<text class="st-label">获赞与收藏</text>
					</view>
				</view>

				<view class="act-entry" @tap="goActivities">
					<text class="act-entry-text">查看动态 ›</text>
				</view>
			</view>

			<view class="content-tabs">
				<view class="c-tab c-tab-on"><text class="c-tab-text c-tab-text-on">笔记</text></view>
			</view>

			<view class="feed-list">
				<view class="empty-box" v-if="!posts.length && !loading">
					<text class="empty-hint">暂无笔记</text>
				</view>
				<waterfall :list="posts" :colNum="2" v-else>
					<template #item="{ item }">
						<post-card :item="item" />
					</template>
				</waterfall>
			</view>
			<view class="feed-end">
				<view class="loading-dots" v-if="loading">
					<view class="dot" v-for="i in 3" :key="i"></view>
				</view>
			</view>
			<view style="height: 120rpx;"></view>
		</scroll-view>

		<view class="back-top-btn" v-if="showBackTop" @tap="scrollToTop">
			<image class="bt-icon" src="/static/icons/top.png" mode="aspectFit" />
		</view>
	</view>
</template>

<script setup>
import { ref, computed } from 'vue'
import { onLoad, onPullDownRefresh } from '@dcloudio/uni-app'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL } from '@/utils/request.js'
import waterfall from '@/components/waterfall/waterfall.vue'
import postCard from '@/components/quote-card/quote-card.vue'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const navBarH = statusBarH + 44

const userId = ref(null)
const profile = ref({})
const posts = ref([])
const isFollowed = ref(false)
const isFan = ref(false)
const loading = ref(false)
const showBackTop = ref(false)
const scrollTopVal = ref(0)
const scrollY = ref(0)

const bgH = 480
const collapseZone = bgH - navBarH

const navProgress = computed(() => Math.min(1, Math.max(0, scrollY.value / (collapseZone - 20))))
const navBg = computed(() => {
	const p = navProgress.value
	return `rgba(255,255,255,${p})`
})
const titleOpacity = computed(() => Math.min(1, Math.max(0, (navProgress.value - 0.3) / 0.5)))

const isSelf = computed(() => userStore.userInfo && Number(userId.value) === userStore.userInfo.id)
const followLabel = computed(() => {
	if (isFollowed.value && isFan.value) return '互相关注'
	if (isFollowed.value) return '已关注'
	if (isFan.value) return '回关'
	return '+ 关注'
})

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
const avatarBg = computed(() => COLORS[(profile.value.id||0) % COLORS.length])
const avatarLetter = computed(() => (profile.value.nickname || profile.value.username || '?').slice(0, 1))

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function formatBirthday(dateStr) {
	if (!dateStr) return ''
	const d = new Date(dateStr)
	if (isNaN(d.getTime())) return dateStr
	const y = d.getFullYear()
	const m = String(d.getMonth() + 1).padStart(2, '0')
	const day = String(d.getDate()).padStart(2, '0')
	return y + '-' + m + '-' + day
}

onLoad(async (o) => {
	userId.value = o.userId
	await loadProfile()
	await loadPosts()
})

async function loadProfile() {
	const res = await request({ url: '/users/' + userId.value })
	if (res.code === 200) {
		profile.value = res.data
		isFollowed.value = res.data.is_followed || false
		isFan.value = res.data.is_fan || false
	}
}

async function loadPosts() {
	loading.value = true
	const res = await request({ url: '/users/' + userId.value + '/posts' })
	if (res.code === 200) posts.value = res.data
	loading.value = false
}

function loadMore() {}

onPullDownRefresh(async () => {
	await Promise.all([loadProfile(), loadPosts()])
	uni.stopPullDownRefresh()
})

async function onFollow() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const res = await userStore.followUser(userId.value)
	if (res?.code === 200) {
		isFollowed.value = res.data.followed
		isFan.value = res.data.is_fan || false
		if (res.data.followed) {
			profile.value.fans_count = (profile.value.fans_count || 0) + 1
		} else {
			profile.value.fans_count = Math.max((profile.value.fans_count || 1) - 1, 0)
		}
	}
}

function onMessage() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	request({
		url: '/chat/conversation/private',
		method: 'POST',
		data: { user_id: Number(userId.value) }
	}).then(res => {
		if (res.code === 200) {
			uni.navigateTo({ url: '/pages/chat/chat?conversationId=' + res.data.conversation_id })
		} else {
			uni.showToast({ title: res.msg || '操作失败', icon: 'none' })
		}
	})
}

let lastScrollTop = 0
let scrollAnimTimer = null

function onScroll(e) {
	const st = e.detail.scrollTop || 0
	scrollY.value = st

	if (st > 600) {
		if (!showBackTop.value) showBackTop.value = true
	} else {
		if (showBackTop.value) showBackTop.value = false
	}

	lastScrollTop = st
}

function scrollToTop() {
	if (scrollAnimTimer) {
		clearInterval(scrollAnimTimer)
		scrollAnimTimer = null
	}
	const start = lastScrollTop
	if (start <= 0) {
		scrollTopVal.value = 0
		showBackTop.value = false
		return
	}
	const duration = 400
	const startTime = Date.now()
	scrollAnimTimer = setInterval(() => {
		const elapsed = Date.now() - startTime
		const progress = Math.min(elapsed / duration, 1)
		const eased = 1 - Math.pow(1 - progress, 3)
		scrollTopVal.value = Math.round(start * (1 - eased))
		if (progress >= 1) {
			clearInterval(scrollAnimTimer)
			scrollAnimTimer = null
			scrollTopVal.value = 0
			lastScrollTop = 0
		}
	}, 16)
	showBackTop.value = false
}

function goEdit() { uni.navigateTo({ url: '/pages/edit-profile/edit-profile' }) }
function goActivities() { uni.navigateTo({ url: '/pages/activities/activities?userId=' + userId.value }) }
function goList(type) {
	const canSee = { follows: profile.value.can_see_follows, fans: profile.value.can_see_fans, likers: profile.value.can_see_likes }
	if (canSee[type] === false) {
		return uni.showToast({ title: '对方已设为私密', icon: 'none' })
	}
	uni.navigateTo({ url: '/pages/user-list/user-list?userId=' + userId.value + '&type=' + type })
}
function goBack() { uni.navigateBack() }
</script>

<style lang="scss" scoped>
.page-user-profile { height: 100vh; background: #f5f5f5; display: flex; flex-direction: column; overflow: hidden; }

.sticky-nav {
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	z-index: 999;
	will-change: background;
}
.sticky-nav-inner { height: 44px; display: flex; align-items: center; position: relative; padding: 0 20rpx; }
.nav-back { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.nav-back-icon { width: 36rpx; height: 36rpx; }
.nav-center { position: absolute; left: 50%; transform: translateX(-50%); transition: opacity 0.15s ease; }
.nav-name { font-size: 32rpx; font-weight: 700; color: #222; }

.main-scroll { flex: 1; height: 100vh; }

.bg-area { position: relative; height: 480rpx; overflow: hidden; }
.bg-image { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
.bg-default { width: 100%; height: 100%; position: absolute; top: 0; left: 0; background: linear-gradient(135deg, #ff2442, #ff5a6e, #ff8a9e); }
.bg-mask { position: absolute; bottom: 0; left: 0; right: 0; height: 200rpx; background: linear-gradient(transparent, rgba(0,0,0,0.25)); }
.top-actions { position: relative; z-index: 10; height: 44px; display: flex; align-items: center; padding: 0 16rpx; }
.top-btn { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; background: rgba(0,0,0,0.2); border-radius: 50%; }
.top-btn-icon { width: 32rpx; height: 32rpx; filter: brightness(100); }

.profile-section {
	position: relative;
	z-index: 10;
	margin-top: -80rpx;
	background: #fff;
	border-radius: 24rpx 24rpx 0 0;
	padding: 0 24rpx 24rpx;
	animation: cardSlide .35s cubic-bezier(0.34, 1.56, 0.64, 1);
}
@keyframes cardSlide { from { transform: translateY(40rpx); opacity: 0; } to { transform: translateY(0); opacity: 1; } }

.card-top { display: flex; align-items: flex-end; justify-content: space-between; margin-top: -64rpx; }
.avatar-wrap { flex-shrink: 0; }
.avatar-img { width: 128rpx; height: 128rpx; border-radius: 50%; border: 6rpx solid #fff; box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.1); }
.avatar-letter { width: 128rpx; height: 128rpx; border-radius: 50%; border: 6rpx solid #fff; box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.1); display: flex; align-items: center; justify-content: center; }
.letter-text { font-size: 48rpx; color: #fff; font-weight: 700; }

.action-area { display: flex; gap: 12rpx; }
.follow-btn { padding: 12rpx 32rpx; border-radius: 28rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); box-shadow: 0 4rpx 12rpx rgba(255,36,66,0.25); transition: all .2s cubic-bezier(0.34, 1.56, 0.64, 1); }
.follow-btn:active { transform: scale(0.95); }
.followed { background: #f5f5f5; box-shadow: none; border: 1rpx solid #e8e8e8; }
.follow-text { font-size: 26rpx; color: #fff; font-weight: 600; }
.followed .follow-text { color: #999; font-weight: 400; }

.msg-btn { padding: 12rpx 24rpx; border-radius: 28rpx; border: 1rpx solid #e8e8e8; transition: all .2s; }
.msg-btn:active { transform: scale(0.95); background: #f5f5f5; }
.msg-text { font-size: 26rpx; color: #333; }

.edit-btn { padding: 12rpx 32rpx; border-radius: 28rpx; border: 1rpx solid #e8e8e8; transition: all .2s; }
.edit-btn:active { transform: scale(0.95); background: #f5f5f5; }
.edit-text { font-size: 26rpx; color: #333; }

.name-row { display: flex; align-items: center; margin-top: 24rpx; }
.user-name { font-size: 36rpx; font-weight: 700; color: #222; }
.gender-icon { font-size: 30rpx; color: #1890ff; margin-left: 8rpx; }
.gender-icon.female { color: #ff2442; }
.user-id { font-size: 22rpx; color: #999; display: block; margin-top: 6rpx; }
.user-bio { font-size: 26rpx; color: #666; display: block; margin-top: 10rpx; line-height: 1.5; }
.info-row { margin-top: 10rpx; display: flex; align-items: center; gap: 8rpx; }
.info-icon { width: 28rpx; height: 28rpx; flex-shrink: 0; }
.info-text { font-size: 24rpx; color: #999; }

.stats-row { display: flex; padding: 24rpx 0 8rpx; }
.st { flex: 1; display: flex; flex-direction: column; align-items: center; }
.st-num { font-size: 32rpx; font-weight: 700; color: #222; }
.st-label { font-size: 22rpx; color: #999; margin-top: 4rpx; }

.act-entry { padding: 12rpx 0 4rpx; }
.act-entry-text { font-size: 26rpx; color: #3378e5; }

.content-tabs { display: flex; background: #fff; border-bottom: 1rpx solid #f0f0f0; position: sticky; top: 0; z-index: 10; }
.c-tab { flex: 1; display: flex; justify-content: center; padding: 24rpx 0 18rpx; position: relative; }
.c-tab-on::after { content: ''; position: absolute; bottom: 0; left: 50%; transform: translateX(-50%); width: 48rpx; height: 4rpx; background: #ff2442; border-radius: 2rpx; }
.c-tab-text { font-size: 28rpx; color: #999; }
.c-tab-text-on { color: #222; font-weight: 600; }

.feed-list { padding: 12rpx 12rpx 0; }
.empty-box { padding: 120rpx 0; text-align: center; }
.empty-hint { font-size: 28rpx; color: #ccc; }

.feed-end { padding: 32rpx 0; text-align: center; }
.loading-dots { display: flex; justify-content: center; gap: 12rpx; }
.dot { width: 12rpx; height: 12rpx; border-radius: 50%; background: #ccc; animation: dotPulse 1.2s ease infinite; }
.dot:nth-child(2) { animation-delay: .2s; }
.dot:nth-child(3) { animation-delay: .4s; }
@keyframes dotPulse { 0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }

.back-top-btn {
	position: fixed;
	right: 32rpx;
	bottom: 120rpx;
	width: 100rpx;
	height: 100rpx;
	border-radius: 50%;
	background: linear-gradient(135deg, #ff2442, #ff5a6e);
	box-shadow: 0 8rpx 24rpx rgba(255,36,66,0.3);
	display: flex;
	align-items: center;
	justify-content: center;
	z-index: 997;
	transition: transform .2s cubic-bezier(0.34, 1.56, 0.64, 1);
	animation: btIn .3s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.back-top-btn:active { transform: scale(0.9); }
.bt-icon { width: 40rpx; height: 40rpx; filter: brightness(100); }

@keyframes btIn {
	from { opacity: 0; transform: scale(0.5) translateY(20rpx); }
	to { opacity: 1; transform: scale(1) translateY(0); }
}
</style>
