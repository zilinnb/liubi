<template>
	<view class="page-mine">
		<view class="sticky-nav" :style="{ paddingTop: statusBarH + 'px', background: navBg }">
			<view class="sticky-nav-inner">
				<view class="nav-center" :style="{ opacity: titleOpacity }">
					<text class="nav-name">{{ userInfo.nickname || userInfo.username || '我' }}</text>
				</view>
			</view>
		</view>

		<scroll-view
			scroll-y
			class="main-scroll"
			:show-scrollbar="false"
			@scroll="onScroll"
			:scroll-top="scrollTopVal"
		>
			<view class="bg-area" :style="{ paddingTop: (statusBarH + 10) + 'px' }">
				<image v-if="userInfo.bg_image" class="bg-image" :src="fullUrl(userInfo.bg_image)" mode="aspectFill" />
				<view v-else class="bg-default"></view>
				<view class="bg-mask"></view>
			</view>

			<view class="profile-card">
				<view class="profile-row">
					<view class="avatar-box">
						<image v-if="userInfo.avatar" class="big-avatar-img" :src="fullUrl(userInfo.avatar)" mode="aspectFill" />
						<view v-else class="big-avatar" :style="{ background: avatarBg }">
							<text class="big-avatar-text">{{ avatarLetter }}</text>
						</view>
					</view>
					<view class="profile-info" v-if="userStore.isLoggedIn">
						<view class="name-row">
							<text class="p-name">{{ userInfo.nickname || userInfo.username }}</text>
							<text class="gender-tag tag-male" v-if="userInfo.gender === 1">♂</text>
							<text class="gender-tag tag-female" v-else-if="userInfo.gender === 2">♀</text>
						</view>
						<text class="p-id">留笔号：{{ userInfo.username }}</text>
						<text class="p-bio">{{ userInfo.bio || '这个人很懒，什么都没写～' }}</text>
					</view>
					<view class="profile-info" v-else>
						<text class="p-name" @tap="goLogin">点击登录</text>
						<text class="p-bio">登录后查看更多内容</text>
					</view>
				</view>
				<view class="stats-row" v-if="userStore.isLoggedIn">
					<view class="st" @tap="goList('follows')"><text class="st-num">{{ userInfo.follow_count||0 }}</text><text class="st-label">关注</text></view>
					<view class="st" @tap="goList('fans')"><text class="st-num">{{ userInfo.fans_count||0 }}</text><text class="st-label">粉丝</text></view>
					<view class="st" @tap="goList('likers')"><text class="st-num">{{ userInfo.like_count||0 }}</text><text class="st-label">获赞与收藏</text></view>
				</view>
				<view class="btn-row" v-if="userStore.isLoggedIn">
					<view class="edit-btn" @tap="onEdit"><text class="edit-btn-text">编辑资料</text></view>
					<view class="act-btn" @tap="goActivities"><text class="act-btn-text">动态</text></view>
				</view>
				<view class="btn-row" v-else>
					<view class="edit-btn" @tap="goLogin"><text class="edit-btn-text">去登录</text></view>
				</view>
			</view>

			<view class="content-tabs">
				<view class="c-tab" :class="{ 'c-tab-on': tab === 'posts' }" @tap="tab='posts'">
					<text class="c-tab-text" :class="{ 'c-tab-text-on': tab === 'posts' }">笔记</text>
				</view>
				<view class="c-tab" :class="{ 'c-tab-on': tab === 'collects' }" @tap="tab='collects'">
					<text class="c-tab-text" :class="{ 'c-tab-text-on': tab === 'collects' }">收藏</text>
				</view>
				<view class="c-tab" :class="{ 'c-tab-on': tab === 'likes' }" @tap="tab='likes'">
					<text class="c-tab-text" :class="{ 'c-tab-text-on': tab === 'likes' }">赞过</text>
				</view>
			</view>

			<view class="grid-area">
				<view class="empty-box" v-if="!userStore.isLoggedIn">
					<view class="empty-icon-circle"><text class="empty-icon-text">!</text></view>
					<text class="empty-hint">登录后查看你的内容</text>
				</view>
				<view class="empty-box" v-else-if="!myPosts.length">
					<view class="empty-icon-circle"><text class="empty-icon-text">~</text></view>
					<text class="empty-hint">还没有笔记，去发布第一条吧～</text>
				</view>
				<waterfall v-else :list="myPosts" :colNum="2">
					<template #item="{ item }">
						<mine-card :item="item" @Tap="goDetail(item.id)" />
					</template>
				</waterfall>
			</view>
			<view style="height: 180rpx;"></view>
		</scroll-view>

		<view class="back-top-btn" v-if="showBackTop" @tap="scrollToTop">
			<image class="bt-icon" src="/static/icons/top.png" mode="aspectFit" />
		</view>

		<view class="bg-actions-fixed" v-if="userStore.isLoggedIn && scrollY < 100" :style="{ top: (statusBarH + 52) + 'px' }">
				<view class="bg-action-btn" @tap="onSetting">
					<text class="bg-action-icon">⚙</text>
				</view>
				<view class="bg-action-btn" @tap="changeBgImage">
					<text class="bg-action-icon">✎</text>
				</view>
			</view>

		<custom-tabbar :current="3" />
	</view>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { onShow, onPullDownRefresh } from '@dcloudio/uni-app'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL, uploadFile } from '@/utils/request.js'
import customTabbar from '@/components/custom-tabbar/custom-tabbar.vue'
import waterfall from '@/components/waterfall/waterfall.vue'
import mineCard from '@/components/mine-card/mine-card.vue'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const navBarH = statusBarH + 44

const tab = ref('posts')
const myPosts = ref([])
const showBackTop = ref(false)
const scrollTopVal = ref(0)
const scrollY = ref(0)

const bgH = 400
const collapseZone = bgH - navBarH + 60

const navProgress = computed(() => Math.min(1, Math.max(0, scrollY.value / (collapseZone - 20))))
const navBg = computed(() => `rgba(255,255,255,${navProgress.value})`)
const titleOpacity = computed(() => Math.min(1, Math.max(0, (navProgress.value - 0.3) / 0.5)))

const userInfo = computed(() => userStore.userInfo || {})
const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
const avatarBg = computed(() => COLORS[(userInfo.value.id||0) % COLORS.length])
const avatarLetter = computed(() => (userInfo.value.nickname || userInfo.value.username || '?').slice(0, 1))

function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api', '') + url }

let lastScrollTop = 0
let scrollAnimTimer = null

async function loadMyPosts() {
	if (!userStore.isLoggedIn) return
	if (tab.value === 'posts') {
		const res = await request({ url: '/users/' + userInfo.value.id + '/posts' })
		if (res.code === 200) myPosts.value = res.data
	} else if (tab.value === 'collects') {
		const res = await request({ url: '/users/' + userInfo.value.id + '/collects' })
		if (res.code === 200) myPosts.value = res.data
	} else {
		const res = await request({ url: '/users/' + userInfo.value.id + '/likes' })
		if (res.code === 200) myPosts.value = res.data
	}
}

async function changeBgImage() {
	uni.chooseImage({
		count: 1,
		sizeType: ['compressed'],
		success: async (res) => {
			const imgRes = await uploadFile('/upload/single', res.tempFilePaths[0])
			if (imgRes.code === 200 && imgRes.data.url) {
				await userStore.updateProfile({ bg_image: imgRes.data.url })
				uni.showToast({ title: '背景已更换', icon: 'success' })
			} else {
				uni.showToast({ title: '上传失败', icon: 'none' })
			}
		}
	})
}

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
	if (scrollAnimTimer) { clearInterval(scrollAnimTimer); scrollAnimTimer = null }
	const start = lastScrollTop
	if (start <= 0) { scrollTopVal.value = 0; showBackTop.value = false; return }
	const duration = 400
	const startTime = Date.now()
	scrollAnimTimer = setInterval(() => {
		const elapsed = Date.now() - startTime
		const progress = Math.min(elapsed / duration, 1)
		const eased = 1 - Math.pow(1 - progress, 3)
		scrollTopVal.value = Math.round(start * (1 - eased))
		if (progress >= 1) { clearInterval(scrollAnimTimer); scrollAnimTimer = null; scrollTopVal.value = 0; lastScrollTop = 0 }
	}, 16)
	showBackTop.value = false
}

onPullDownRefresh(async () => {
	if (userStore.isLoggedIn) { await userStore.fetchProfile(); await loadMyPosts() }
	uni.stopPullDownRefresh()
})

function goLogin() { uni.navigateTo({ url: '/pages/login/login' }) }
function goDetail(id) { uni.navigateTo({ url: '/pages/detail/detail?id=' + id }) }
function onEdit() { uni.navigateTo({ url: '/pages/edit-profile/edit-profile' }) }
function goActivities() { uni.navigateTo({ url: '/pages/activities/activities?userId=' + userInfo.value.id }) }
function goList(type) { uni.navigateTo({ url: '/pages/user-list/user-list?userId=' + userInfo.value.id + '&type=' + type }) }
function onSetting() { uni.navigateTo({ url: '/pages/settings/settings' }) }

watch(tab, loadMyPosts)
onMounted(() => { if (userStore.isLoggedIn) { userStore.fetchProfile(); loadMyPosts() } })
onShow(() => { uni.hideTabBar({ animation: false }); if (userStore.isLoggedIn) { userStore.fetchProfile(); loadMyPosts() } })
</script>

<style lang="scss" scoped>
.page-mine { height: 100vh; background: #f5f5f5; display: flex; flex-direction: column; overflow: hidden; }

.sticky-nav {
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	z-index: 999;
	will-change: background;
}
.sticky-nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 24rpx; }
.nav-center { transition: opacity 0.15s ease; }
.nav-name { font-size: 32rpx; font-weight: 700; color: #222; }

.main-scroll { flex: 1; height: 100vh; }

.bg-area { position: relative; height: 400rpx; overflow: hidden; }
.bg-image { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
.bg-default { width: 100%; height: 100%; position: absolute; top: 0; left: 0; background: linear-gradient(145deg, #ff2442, #ff5a6e, #ff8a9e); }
.bg-mask { position: absolute; bottom: 0; left: 0; right: 0; height: 180rpx; background: linear-gradient(transparent, rgba(0,0,0,0.2)); }
.bg-actions-fixed { position: fixed; right: 24rpx; z-index: 1000; display: flex; gap: 12rpx; }
.bg-action-btn { width: 64rpx; height: 64rpx; border-radius: 50%; background: rgba(0,0,0,0.3); backdrop-filter: blur(6px); display: flex; align-items: center; justify-content: center; transition: all .2s; }
.bg-action-btn:active { background: rgba(0,0,0,0.5); transform: scale(0.9); }
.bg-action-icon { font-size: 28rpx; color: #fff; }

.profile-card {
	position: relative; z-index: 10;
	margin-top: -60rpx;
	background: #fff;
	border-radius: 28rpx 28rpx 0 0;
	padding: 0 28rpx 24rpx;
	animation: cardSlide .35s cubic-bezier(0.34, 1.56, 0.64, 1);
}
@keyframes cardSlide { from { transform: translateY(40rpx); opacity: 0; } to { transform: translateY(0); opacity: 1; } }

.profile-row { display: flex; padding-top: 24rpx; }
.avatar-box { margin-right: 24rpx; }
.big-avatar-img { width: 128rpx; height: 128rpx; border-radius: 50%; border: 6rpx solid #fff; box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.1); }
.big-avatar { width: 128rpx; height: 128rpx; border-radius: 50%; border: 6rpx solid #fff; box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.1); display: flex; align-items: center; justify-content: center; }
.big-avatar-text { font-size: 48rpx; color: #fff; font-weight: 700; }
.profile-info { flex: 1; }
.name-row { display: flex; align-items: center; gap: 8rpx; }
.p-name { font-size: 36rpx; font-weight: 700; color: #222; }
.gender-tag { font-size: 22rpx; padding: 2rpx 10rpx; border-radius: 10rpx; }
.tag-male { background: #e6f7ff; color: #1890ff; }
.tag-female { background: #fff0f6; color: #ff2442; }
.p-id { font-size: 22rpx; color: #aaa; display: block; margin-top: 6rpx; }
.p-bio { font-size: 26rpx; color: #666; display: block; margin-top: 8rpx; line-height: 1.5; }

.stats-row { display: flex; padding: 28rpx 0 0; }
.st { flex: 1; display: flex; flex-direction: column; align-items: center; }
.st-num { font-size: 32rpx; font-weight: 700; color: #222; }
.st-label { font-size: 22rpx; color: #999; margin-top: 4rpx; }

.btn-row { display: flex; padding: 20rpx 0 0; gap: 12rpx; }
.edit-btn { flex: 1; height: 68rpx; border-radius: 34rpx; border: 1rpx solid #e8e8e8; display: flex; align-items: center; justify-content: center; transition: all .2s; }
.edit-btn:active { background: #f5f5f5; }
.edit-btn-text { font-size: 26rpx; color: #333; font-weight: 500; }
.act-btn { height: 68rpx; padding: 0 32rpx; border-radius: 34rpx; border: 1rpx solid #e8e8e8; display: flex; align-items: center; justify-content: center; transition: all .2s; }
.act-btn:active { background: #f5f5f5; }
.act-btn-text { font-size: 26rpx; color: #333; font-weight: 500; }

.content-tabs { display: flex; background: #fff; border-bottom: 1rpx solid #f0f0f0; position: sticky; top: 0; z-index: 10; }
.c-tab { flex: 1; display: flex; justify-content: center; padding: 24rpx 0 18rpx; position: relative; }
.c-tab-on::after { content: ''; position: absolute; bottom: 0; left: 50%; transform: translateX(-50%); width: 32rpx; height: 6rpx; background: #ff2442; border-radius: 3rpx; }
.c-tab-text { font-size: 28rpx; color: #aaa; transition: color .2s; }
.c-tab-text-on { color: #222; font-weight: 600; }

.grid-area { padding: 16rpx 8rpx 0; }
.empty-box { padding: 120rpx 0; display: flex; flex-direction: column; align-items: center; }
.empty-icon-circle { width: 80rpx; height: 80rpx; border-radius: 50%; background: #f0f0f0; display: flex; align-items: center; justify-content: center; }
.empty-icon-text { font-size: 36rpx; color: #ccc; }
.empty-hint { font-size: 28rpx; color: #ccc; margin-top: 16rpx; }

.back-top-btn {
	position: fixed;
	right: 32rpx;
	bottom: 180rpx;
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
