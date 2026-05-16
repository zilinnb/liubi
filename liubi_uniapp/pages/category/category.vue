<template>
	<view class="page-category">
		<view class="sticky-nav" :style="{ paddingTop: statusBarH + 'px', background: navBg, opacity: navOpacity }">
			<view class="sticky-nav-inner">
				<view class="nav-back" @tap="goBack">
					<image class="nav-back-icon" src="/static/icons/back.png" mode="aspectFit" />
				</view>
				<text class="nav-title" :style="{ opacity: titleOpacity }">{{ cat.name }}</text>
				<view class="nav-follow" v-if="!cat.is_followed" @tap="onFollowCat">
					<text class="nav-follow-text">关注</text>
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
			<view class="cat-header" :style="{ paddingTop: statusBarH + 'px' }">
				<image v-if="cat.cover" class="cat-cover" :src="fullUrl(cat.cover)" mode="aspectFill" />
				<view v-else class="cat-cover-default" :style="{ background: cat.color || '#ff2442' }"></view>
				<view class="cat-mask"></view>
				<view class="top-actions">
					<view class="top-btn" @tap="goBack">
						<image class="top-btn-icon" src="/static/icons/back.png" mode="aspectFit" />
					</view>
				</view>
				<view class="cat-info">
					<view class="cat-icon-wrap" :style="{ background: cat.color || '#ff2442' }">
						<image v-if="cat.cover" class="cat-icon-img" :src="fullUrl(cat.cover)" mode="aspectFill" />
						<text v-else class="cat-icon-letter">{{ cat.icon || cat.name?.slice(0,1) }}</text>
					</view>
					<view class="cat-name-row">
						<text class="cat-name">{{ cat.name }}</text>
						<text class="cat-badge" v-if="cat.publish_restriction === 1">官方</text>
					</view>
					<text class="cat-desc">{{ cat.description || '暂无介绍' }}</text>
				</view>
			</view>

			<view class="stats-bar">
				<view class="stat-item">
					<text class="stat-num">{{ cat.post_count || 0 }}</text>
					<text class="stat-label">笔记</text>
				</view>
				<view class="stat-item">
					<text class="stat-num">{{ cat.author_count || 0 }}</text>
					<text class="stat-label">创作者</text>
				</view>
				<view class="stat-item">
					<text class="stat-num">{{ fmtHeat(cat.heat) }}</text>
					<text class="stat-label">热度</text>
				</view>
				<view class="stat-item">
					<text class="stat-num">{{ cat.follow_count || 0 }}</text>
					<text class="stat-label">关注</text>
				</view>
				<view class="follow-btn" :class="{ followed: cat.is_followed }" @tap="onFollowCat">
					<text class="follow-btn-text">{{ cat.is_followed ? '已关注' : '+ 关注' }}</text>
				</view>
			</view>

			<view class="content-tabs" id="stickyAnchor">
				<view class="c-tab" :class="{ 'c-tab-on': tab === 'hot' }" @tap="switchTab('hot')">
					<text class="c-tab-text" :class="{ 'c-tab-text-on': tab === 'hot' }">最热</text>
				</view>
				<view class="c-tab" :class="{ 'c-tab-on': tab === 'latest' }" @tap="switchTab('latest')">
					<text class="c-tab-text" :class="{ 'c-tab-text-on': tab === 'latest' }">最新</text>
				</view>
			</view>

			<view class="pinned-section" v-if="pinnedPosts.length">
				<view class="pinned-header">
					<view class="pinned-icon-wrap"><text class="pinned-icon-text">📌</text></view>
					<text class="pinned-label">置顶</text>
				</view>
				<scroll-view scroll-x class="pinned-scroll" :show-scrollbar="false">
					<view class="pinned-list">
						<view class="pinned-card" v-for="p in pinnedPosts" :key="p.id" @tap="goDetail(p.id)">
							<image v-if="p.cover || p.images?.length" class="pinned-cover" :src="fullUrl(p.cover || p.images[0]?.url)" mode="aspectFill" />
							<view v-else class="pinned-cover-text">
								<text class="pinned-cover-letter">{{ (p.title||'').slice(0,1) }}</text>
							</view>
							<view class="pinned-info">
								<text class="pinned-title">{{ p.title }}</text>
								<view class="pinned-meta">
									<text class="pinned-author">{{ p.nickname || '匿名' }}</text>
									<text class="pinned-stat">{{ p.likes_count||0 }}赞 · {{ p.comments_count||0 }}评</text>
								</view>
							</view>
							<view class="pinned-badge">
								<text class="pinned-badge-text">置顶</text>
							</view>
						</view>
					</view>
				</scroll-view>
			</view>

			<view class="feed-list">
				<waterfall :list="posts" :colNum="2">
					<template #item="{ item }">
						<post-card :item="item" />
					</template>
				</waterfall>
				<view class="feed-end" v-if="loading">
					<view class="loading-dots">
						<view class="dot" v-for="i in 3" :key="i"></view>
					</view>
				</view>
				<view class="feed-end" v-if="!loading && !posts.length">
					<text class="empty-hint">暂无笔记，来发布第一条吧～</text>
				</view>
			</view>
			<view style="height: 160rpx;"></view>
		</scroll-view>

		<view class="fab-group">
			<view class="fab-btn fab-top" v-if="showBackTop" @tap="scrollToTop">
				<image class="fab-icon" src="/static/icons/top.png" mode="aspectFit" />
			</view>
			<view class="fab-btn fab-publish" @tap="goPublish" v-if="cat.publish_restriction !== 1 || userStore.userInfo?.role === 1">
				<text class="fab-text">+</text>
			</view>
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

const catId = ref(null)
const cat = ref({})
const posts = ref([])
const pinnedPosts = ref([])
const tab = ref('hot')
const page = ref(1)
const loading = ref(false)
const hasMore = ref(true)
const showBackTop = ref(false)
const scrollTopVal = ref(0)
const scrollY = ref(0)

const headerH = 420
const statsH = 100
const collapseZone = headerH - navBarH + statsH

const navProgress = computed(() => Math.min(1, Math.max(0, scrollY.value / (collapseZone - 20))))
const navBg = computed(() => {
	const p = navProgress.value
	return `rgba(255,255,255,${p})`
})
const navOpacity = computed(() => navProgress.value > 0.05 ? 1 : 0)
const titleOpacity = computed(() => Math.min(1, Math.max(0, (navProgress.value - 0.3) / 0.5)))

let lastScrollTop = 0
let scrollAnimTimer = null

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function fmtHeat(n) {
	n = n || 0
	if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
	if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
	return String(n)
}

onLoad(async (o) => {
	catId.value = o.id
	await loadCategory()
	await loadPosts()
})

async function loadCategory() {
	const res = await request({ url: '/categories/' + catId.value })
	if (res.code === 200) cat.value = res.data
}

async function loadPosts() {
	if (loading.value) return
	loading.value = true
	const res = await request({ url: '/categories/' + catId.value + '/posts', data: { page: page.value, sort: tab.value } })
	if (res.code === 200) {
		const allList = res.data.list || []
		pinnedPosts.value = allList.filter(p => p.is_pinned === 1)
		const normalPosts = allList.filter(p => p.is_pinned !== 1)
		if (page.value === 1) {
			posts.value = normalPosts
		} else {
			posts.value = [...posts.value, ...normalPosts]
		}
		hasMore.value = posts.value.length < res.data.total - pinnedPosts.value.length
	}
	loading.value = false
}

function switchTab(t) {
	if (tab.value === t) return
	tab.value = t
	page.value = 1
	loadPosts()
}

function loadMore() {
	if (!hasMore.value || loading.value) return
	page.value++
	loadPosts()
}

onPullDownRefresh(async () => {
	page.value = 1
	await Promise.all([loadCategory(), loadPosts()])
	uni.stopPullDownRefresh()
})

async function onFollowCat() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const res = await request({ url: '/categories/' + catId.value + '/follow', method: 'POST' })
	if (res.code === 200) {
		cat.value.is_followed = res.data.followed
		cat.value.follow_count = res.data.followed ? (cat.value.follow_count || 0) + 1 : Math.max((cat.value.follow_count || 1) - 1, 0)
	}
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

function goPublish() { uni.navigateTo({ url: '/pages/publish/publish?categoryId=' + catId.value }) }
function goDetail(id) { uni.navigateTo({ url: '/pages/detail/detail?id=' + id }) }
function goBack() { uni.navigateBack() }
</script>

<style lang="scss" scoped>
.page-category { height: 100vh; background: #f5f5f5; display: flex; flex-direction: column; overflow: hidden; }

.sticky-nav {
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	z-index: 999;
	transition: opacity 0.1s ease;
	will-change: background, opacity;
}
.sticky-nav-inner { height: 44px; display: flex; align-items: center; position: relative; padding: 0 20rpx; }
.nav-back { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.nav-back-icon { width: 36rpx; height: 36rpx; }
.nav-title { position: absolute; left: 50%; transform: translateX(-50%); font-size: 32rpx; font-weight: 700; color: #222; transition: opacity 0.15s ease; }
.nav-follow { padding: 8rpx 24rpx; border-radius: 20rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); margin-left: auto; }
.nav-follow-text { font-size: 22rpx; color: #fff; font-weight: 600; }

.main-scroll { flex: 1; height: 100vh; }

.cat-header { position: relative; height: 420rpx; overflow: hidden; }
.cat-cover { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
.cat-cover-default { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
.cat-mask { position: absolute; bottom: 0; left: 0; right: 0; height: 280rpx; background: linear-gradient(transparent, rgba(0,0,0,0.55)); }
.top-actions { position: relative; z-index: 10; height: 44px; display: flex; align-items: center; padding: 0 16rpx; }
.top-btn { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; background: rgba(0,0,0,0.2); border-radius: 50%; }
.top-btn-icon { width: 32rpx; height: 32rpx; filter: brightness(100); }
.cat-info { position: absolute; bottom: 30rpx; left: 24rpx; right: 24rpx; z-index: 10; display: flex; flex-direction: column; align-items: center; }
.cat-icon-wrap { width: 88rpx; height: 88rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; border: 4rpx solid rgba(255,255,255,0.8); box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.2); overflow: hidden; }
.cat-icon-img { width: 88rpx; height: 88rpx; }
.cat-icon-letter { font-size: 36rpx; color: #fff; font-weight: 700; }
.cat-name-row { display: flex; align-items: center; margin-top: 12rpx; }
.cat-name { font-size: 34rpx; font-weight: 700; color: #fff; text-shadow: 0 2rpx 8rpx rgba(0,0,0,0.3); }
.cat-badge { font-size: 20rpx; color: #fff; background: rgba(255,36,66,0.85); padding: 2rpx 12rpx; border-radius: 8rpx; margin-left: 12rpx; font-weight: 600; }
.cat-desc { font-size: 24rpx; color: rgba(255,255,255,0.9); margin-top: 8rpx; text-align: center; }

.stats-bar { display: flex; align-items: center; background: #fff; padding: 24rpx; gap: 4rpx; }
.stat-item { flex: 1; display: flex; flex-direction: column; align-items: center; }
.stat-num { font-size: 30rpx; font-weight: 700; color: #222; }
.stat-label { font-size: 20rpx; color: #999; margin-top: 4rpx; }
.follow-btn { padding: 12rpx 28rpx; border-radius: 24rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); box-shadow: 0 4rpx 12rpx rgba(255,36,66,0.2); transition: all .2s cubic-bezier(0.34, 1.56, 0.64, 1); }
.follow-btn:active { transform: scale(0.95); }
.followed { background: #f5f5f5; box-shadow: none; border: 1rpx solid #e8e8e8; }
.follow-btn-text { font-size: 24rpx; color: #fff; font-weight: 600; }
.followed .follow-btn-text { color: #999; font-weight: 400; }

.content-tabs { display: flex; background: #fff; border-bottom: 1rpx solid #f0f0f0; position: sticky; top: 0; z-index: 10; }
.c-tab { flex: 1; display: flex; justify-content: center; padding: 24rpx 0 18rpx; position: relative; }
.c-tab-on::after { content: ''; position: absolute; bottom: 0; left: 50%; transform: translateX(-50%); width: 48rpx; height: 4rpx; background: #ff2442; border-radius: 2rpx; }
.c-tab-text { font-size: 28rpx; color: #999; transition: all .2s; }
.c-tab-text-on { color: #222; font-weight: 600; }

.feed-list { padding: 12rpx 12rpx 0; }

.pinned-section { background: #fff; padding: 16rpx 0 8rpx; }
.pinned-header { display: flex; align-items: center; padding: 0 24rpx 12rpx; }
.pinned-icon-wrap { width: 36rpx; height: 36rpx; display: flex; align-items: center; justify-content: center; }
.pinned-icon-text { font-size: 24rpx; }
.pinned-label { font-size: 26rpx; font-weight: 700; color: #ff2442; margin-left: 6rpx; }
.pinned-scroll { white-space: nowrap; }
.pinned-list { display: flex; padding: 0 20rpx 8rpx; gap: 16rpx; }
.pinned-card { display: inline-flex; align-items: center; background: #fafafa; border-radius: 16rpx; padding: 16rpx; min-width: 520rpx; max-width: 640rpx; position: relative; transition: all .15s; border: 1rpx solid #f0f0f0; }
.pinned-card:active { background: #f5f5f5; transform: scale(0.98); }
.pinned-cover { width: 100rpx; height: 100rpx; border-radius: 12rpx; flex-shrink: 0; }
.pinned-cover-text { width: 100rpx; height: 100rpx; border-radius: 12rpx; flex-shrink: 0; background: linear-gradient(135deg, #ff2442, #ff5a6e); display: flex; align-items: center; justify-content: center; }
.pinned-cover-letter { font-size: 36rpx; color: #fff; font-weight: 700; }
.pinned-info { flex: 1; margin-left: 16rpx; overflow: hidden; }
.pinned-title { font-size: 28rpx; color: #222; font-weight: 600; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; overflow: hidden; white-space: normal; line-height: 1.4; }
.pinned-meta { display: flex; align-items: center; margin-top: 8rpx; gap: 12rpx; }
.pinned-author { font-size: 22rpx; color: #999; }
.pinned-stat { font-size: 22rpx; color: #bbb; }
.pinned-badge { position: absolute; top: 0; right: 0; background: linear-gradient(135deg, #ff2442, #ff5a6e); border-radius: 0 16rpx 0 12rpx; padding: 4rpx 16rpx; }
.pinned-badge-text { font-size: 20rpx; color: #fff; font-weight: 600; }

.fab-group { position: fixed; right: 32rpx; bottom: 140rpx; z-index: 100; display: flex; flex-direction: column; align-items: center; gap: 20rpx; }
.fab-btn { width: 100rpx; height: 100rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; transition: transform .2s cubic-bezier(0.34, 1.56, 0.64, 1); }
.fab-btn:active { transform: scale(0.9); }
.fab-publish { background: linear-gradient(135deg, #ff2442, #ff5a6e); box-shadow: 0 8rpx 24rpx rgba(255,36,66,0.3); }
.fab-text { font-size: 48rpx; color: #fff; font-weight: 300; line-height: 1; }
.fab-top {
	background: linear-gradient(135deg, #ff2442, #ff5a6e);
	box-shadow: 0 8rpx 24rpx rgba(255,36,66,0.3);
	animation: fabIn .3s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.fab-icon { width: 40rpx; height: 40rpx; filter: brightness(100); }

@keyframes fabIn {
	from { opacity: 0; transform: scale(0.5) translateY(20rpx); }
	to { opacity: 1; transform: scale(1) translateY(0); }
}

.feed-end { padding: 32rpx 0; text-align: center; }
.empty-hint { font-size: 26rpx; color: #ccc; }
.loading-dots { display: flex; justify-content: center; gap: 12rpx; }
.dot { width: 12rpx; height: 12rpx; border-radius: 50%; background: #ccc; animation: dotPulse 1.2s ease infinite; }
.dot:nth-child(2) { animation-delay: .2s; }
.dot:nth-child(3) { animation-delay: .4s; }
@keyframes dotPulse { 0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }
</style>
