<template>
	<view class="page-discover">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<text class="nav-title">发现</text>
			</view>
		</view>

		<scroll-view scroll-y class="discover-scroll" :show-scrollbar="false" @scroll="onScroll" :scroll-top="scrollTopVal">
			<view :style="{ height: navBarH + 'px' }"></view>

			<view class="search-section">
				<view class="search-box" @tap="onSearch">
					<image class="search-icon" src="/static/icons/search.png" mode="aspectFit" />
					<text class="search-hint">大家都在搜</text>
				</view>
			</view>

			<view class="section anim-section">
				<view class="sec-head"><text class="sec-title">热门分类</text></view>
				<view class="cate-grid">
					<view class="cate-card" v-for="c in postStore.categories" :key="c.id" @tap="goCategory(c)">
						<view class="cate-icon" :style="{ background: c.color || '#f0f0f0' }">
							<image v-if="c.cover" class="cate-icon-img" :src="fullUrl(c.cover)" mode="aspectFill" />
							<text v-else class="cate-emoji">{{ c.icon || c.name?.slice(0,1) }}</text>
						</view>
						<text class="cate-name">{{ c.name }}</text>
					</view>
				</view>
			</view>

			<view class="section anim-section" v-if="recUsers.length">
				<view class="sec-head"><text class="sec-title">推荐关注</text></view>
				<scroll-view scroll-x class="rec-scroll" :show-scrollbar="false">
					<view class="rec-list">
						<view class="rec-card" v-for="u in recUsers" :key="u.id" @tap="goUserProfile(u.id)">
							<view class="rec-avatar" :style="{ background: recColor(u.id) }">
								<image v-if="u.avatar" class="rec-avatar-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
								<text v-else class="rec-avatar-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
							</view>
							<text class="rec-name">{{ u.nickname || u.username }}</text>
							<text class="rec-fans">{{ u.fans_count||0 }}粉丝</text>
							<view class="rec-follow" :class="{ followed: u.is_followed }" @tap.stop="onFollow(u)">
								<text class="rec-follow-text">{{ followLabel(u) }}</text>
							</view>
						</view>
					</view>
				</scroll-view>
			</view>

			<view class="section anim-section">
				<view class="sec-head">
					<text class="sec-title">🔥 热门榜单</text>
					<view class="sec-more" @tap="goSearch">
						<text class="sec-more-text">查看更多 ›</text>
					</view>
				</view>
				<view class="trend-list" v-if="trendList.length">
					<view class="trend-item" v-for="(p, i) in trendList" :key="p.id" @tap="goDetail(p)">
						<view class="trend-rank" :class="{ 'rank-1': i===0, 'rank-2': i===1, 'rank-3': i===2 }">
							<text class="trend-rank-text">{{ i + 1 }}</text>
						</view>
						<view class="trend-info">
							<text class="trend-title">{{ p.title }}</text>
							<text class="trend-meta">{{ p.nickname || '匿名' }} · {{ fmtNum(p.views_count||0) }}浏览 · {{ fmtNum(p.likes_count||0) }}赞</text>
						</view>
					</view>
				</view>
				<view class="trend-empty" v-else>
					<text class="trend-empty-text">暂无数据</text>
				</view>
			</view>

			<view style="height: 120rpx;"></view>
		</scroll-view>

		<view class="back-top-btn" v-if="showBackTop" @tap="scrollToTop">
			<image class="bt-icon" src="/static/icons/top.png" mode="aspectFit" />
		</view>

		<custom-tabbar :current="1" />
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { onShow, onPullDownRefresh } from '@dcloudio/uni-app'
import { usePostStore } from '@/store/quote.js'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL } from '@/utils/request.js'
import customTabbar from '@/components/custom-tabbar/custom-tabbar.vue'

const postStore = usePostStore()
const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const navBarH = statusBarH + 44

const recUsers = ref([])
const trendList = ref([])
const showBackTop = ref(false)
const scrollTopVal = ref(0)

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function recColor(id) { return COLORS[id % COLORS.length] }

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function fmtNum(n) {
	if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
	if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
	return String(n || 0)
}

async function loadRecUsers() {
	if (!userStore.isLoggedIn) return
	const res = await request({ url: '/users/recommend' })
	if (res.code === 200) recUsers.value = res.data || []
}

async function loadTrending() {
	const res = await request({ url: '/posts/trending', data: { type: 'hot' } })
	if (res.code === 200) trendList.value = (res.data || []).slice(0, 5)
}

function goCategory(c) { uni.navigateTo({ url: '/pages/category/category?id=' + c.id }) }
function onSearch() { uni.navigateTo({ url: '/pages/search/search' }) }
function goSearch() { uni.navigateTo({ url: '/pages/search/search' }) }
function goDetail(p) { uni.navigateTo({ url: '/pages/detail/detail?id=' + p.id }) }
function followLabel(u) {
	if (u.is_followed && u.is_fan) return '互相关注'
	if (u.is_followed) return '已关注'
	if (u.is_fan) return '回关'
	return '+ 关注'
}
function goUserProfile(id) { uni.navigateTo({ url: '/pages/user-profile/user-profile?userId=' + id }) }

async function onFollow(u) {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const res = await userStore.followUser(u.id)
	if (res?.code === 200) { u.is_followed = res.data.followed; u.is_fan = res.data.is_fan }
}

let lastScrollTop = 0
let scrollAnimTimer = null

function onScroll(e) {
	const st = e.detail.scrollTop || 0
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
	await Promise.all([loadRecUsers(), loadTrending()])
	uni.stopPullDownRefresh()
})

onMounted(() => {
	postStore.fetchCategories()
	loadRecUsers()
	loadTrending()
})
onShow(() => { uni.hideTabBar({ animation: false }) })
</script>

<style lang="scss" scoped>
.page-discover { height: 100vh; background: #f5f5f5; display: flex; flex-direction: column; overflow: hidden; }

.top-nav {
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	z-index: 999;
	background: #fff;
	box-shadow: 0 2rpx 12rpx rgba(0,0,0,0.06);
}
.nav-inner {
	height: 44px;
	display: flex;
	align-items: center;
	justify-content: center;
}
.nav-title { font-size: 34rpx; font-weight: 700; color: #222; }

.discover-scroll { flex: 1; height: 100vh; }

.search-section { padding: 16rpx 24rpx 8rpx; }
.search-box { display: flex; align-items: center; background: #fff; border-radius: 32rpx; padding: 16rpx 24rpx; box-shadow: 0 2rpx 12rpx rgba(0,0,0,0.06); transition: all .2s; }
.search-box:active { background: #fafafa; }
.search-icon { width: 28rpx; height: 28rpx; margin-right: 12rpx; flex-shrink: 0; }
.search-hint { font-size: 26rpx; color: #bbb; }

.section { background: #fff; margin: 16rpx 16rpx 0; padding: 24rpx; border-radius: 16rpx; }
.sec-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20rpx; }
.sec-title { font-size: 30rpx; font-weight: 700; color: #222; }
.sec-more { padding: 4rpx 8rpx; }
.sec-more-text { font-size: 24rpx; color: #999; }

.cate-grid { display: flex; flex-wrap: wrap; gap: 16rpx; }
.cate-card { width: calc(25% - 12rpx); display: flex; flex-direction: column; align-items: center; padding: 16rpx 0; transition: all .2s; }
.cate-card:active { transform: scale(0.95); }
.cate-icon { width: 88rpx; height: 88rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; overflow: hidden; margin-bottom: 8rpx; box-shadow: 0 4rpx 12rpx rgba(0,0,0,0.08); }
.cate-icon-img { width: 88rpx; height: 88rpx; }
.cate-emoji { font-size: 36rpx; color: #fff; font-weight: 700; }
.cate-name { font-size: 24rpx; color: #333; }

.rec-scroll { white-space: nowrap; }
.rec-list { display: flex; padding-bottom: 16rpx; }
.rec-card { display: inline-flex; flex-direction: column; align-items: center; width: 160rpx; margin-right: 20rpx; }
.rec-avatar { width: 96rpx; height: 96rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; overflow: hidden; }
.rec-avatar-img { width: 96rpx; height: 96rpx; }
.rec-avatar-text { font-size: 32rpx; color: #fff; font-weight: 600; }
.rec-name { font-size: 22rpx; color: #333; margin-top: 10rpx; max-width: 140rpx; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rec-fans { font-size: 20rpx; color: #bbb; margin-top: 4rpx; }
.rec-follow { margin-top: 12rpx; padding: 6rpx 24rpx; border-radius: 20rpx; background: #ff2442; transition: all .2s cubic-bezier(0.34, 1.56, 0.64, 1); }
.rec-follow:active { transform: scale(0.95); }
.followed { background: #f5f5f5; border: 1rpx solid #e8e8e8; }
.rec-follow-text { font-size: 22rpx; color: #fff; font-weight: 500; }
.followed .rec-follow-text { color: #999; font-weight: 400; }

.trend-item { display: flex; align-items: center; padding: 16rpx 0; border-bottom: 1rpx solid #f8f8f8; transition: background .15s; }
.trend-item:active { background: #fafafa; }
.trend-item:last-child { border-bottom: none; }
.trend-rank { width: 44rpx; height: 44rpx; border-radius: 10rpx; background: #f0f0f0; display: flex; align-items: center; justify-content: center; margin-right: 16rpx; flex-shrink: 0; }
.rank-1 { background: linear-gradient(135deg, #ff2442, #ff6b81); }
.rank-2 { background: linear-gradient(135deg, #ff6b2e, #ffad42); }
.rank-3 { background: linear-gradient(135deg, #faad14, #ffd666); }
.trend-rank-text { font-size: 24rpx; font-weight: 700; color: #999; }
.rank-1 .trend-rank-text, .rank-2 .trend-rank-text, .rank-3 .trend-rank-text { color: #fff; }
.trend-info { flex: 1; overflow: hidden; }
.trend-title { font-size: 28rpx; color: #222; font-weight: 500; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 1; overflow: hidden; }
.trend-meta { font-size: 22rpx; color: #999; display: block; margin-top: 6rpx; }
.trend-empty { padding: 40rpx 0; text-align: center; }
.trend-empty-text { font-size: 24rpx; color: #ccc; }

.anim-section { animation: sectionIn .35s ease both; }
.anim-section:nth-child(2) { animation-delay: 0s; }
.anim-section:nth-child(3) { animation-delay: .08s; }
.anim-section:nth-child(4) { animation-delay: .16s; }
@keyframes sectionIn { from { opacity: 0; transform: translateY(24rpx); } to { opacity: 1; transform: translateY(0); } }

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
