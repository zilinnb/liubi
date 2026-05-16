<template>
	<view class="page-search">
		<!-- 顶部搜索栏 -->
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack">
					<text class="back-arrow">‹</text>
				</view>
				<view class="search-box" :class="{ 'search-box-focus': inputFocus }">
					<image class="search-icon" src="/static/icons/search.png" mode="aspectFit" />
					<input
						class="search-input"
						v-model="keyword"
						placeholder="搜索用户、笔记"
						confirm-type="search"
						:focus="autoFocus"
						@focus="inputFocus = true"
						@blur="inputFocus = false"
						@confirm="doSearch"
					/>
					<view class="clear-btn" v-if="keyword" @tap="resetSearch">
						<text class="clear-x">✕</text>
					</view>
				</view>
				<view class="nav-search-btn" @tap="doSearch">
					<text class="nav-search-text">搜索</text>
				</view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<!-- 搜索结果页 -->
		<view v-if="searched" class="result-page">
			<!-- 类型切换：笔记 / 用户 -->
			<view class="type-tabs">
				<view class="type-tab" :class="{ 'type-tab-on': searchType === 'posts' }" @tap="searchType='posts';doSearch()">
					<text class="type-text" :class="{ 'type-text-on': searchType === 'posts' }">笔记</text>
					<view class="type-line" v-if="searchType === 'posts'"></view>
				</view>
				<view class="type-tab" :class="{ 'type-tab-on': searchType === 'users' }" @tap="searchType='users';doSearch()">
					<text class="type-text" :class="{ 'type-text-on': searchType === 'users' }">用户</text>
					<view class="type-line" v-if="searchType === 'users'"></view>
				</view>
			</view>

			<!-- 笔记结果 -->
			<scroll-view v-if="searchType === 'posts'" scroll-y class="result-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
				<!-- 筛选栏 -->
				<view class="filter-bar">
					<view class="filter-chip" :class="{ 'filter-on': sortBy === 'default' }" @tap="sortBy='default';doSearch()">
						<text class="filter-text" :class="{ 'filter-text-on': sortBy === 'default' }">综合</text>
					</view>
					<view class="filter-chip" :class="{ 'filter-on': sortBy === 'latest' }" @tap="sortBy='latest';doSearch()">
						<text class="filter-text" :class="{ 'filter-text-on': sortBy === 'latest' }">最新</text>
					</view>
					<view class="filter-chip" :class="{ 'filter-on': sortBy === 'hot' }" @tap="sortBy='hot';doSearch()">
						<text class="filter-text" :class="{ 'filter-text-on': sortBy === 'hot' }">最热</text>
					</view>
					<view class="filter-chip" :class="{ 'filter-on': sortBy === 'most_liked' }" @tap="sortBy='most_liked';doSearch()">
						<text class="filter-text" :class="{ 'filter-text-on': sortBy === 'most_liked' }">最多赞</text>
					</view>
				</view>

				<!-- 内容类型筛选 -->
				<view class="content-filter" v-if="posts.length">
					<view class="cf-chip" :class="{ 'cf-on': contentFilter === 'all' }" @tap="contentFilter='all'">
						<text class="cf-text" :class="{ 'cf-text-on': contentFilter === 'all' }">全部</text>
					</view>
					<view class="cf-chip" :class="{ 'cf-on': contentFilter === 'image' }" @tap="contentFilter='image'">
						<text class="cf-text" :class="{ 'cf-text-on': contentFilter === 'image' }">图文</text>
					</view>
					<view class="cf-chip" :class="{ 'cf-on': contentFilter === 'text' }" @tap="contentFilter='text'">
						<text class="cf-text" :class="{ 'cf-text-on': contentFilter === 'text' }">文字</text>
					</view>
				</view>

				<waterfall v-if="filteredPosts.length" :list="filteredPosts" :colNum="2" class="fall-area">
					<template #item="{ item }">
						<post-card :item="item" />
					</template>
				</waterfall>
				<view class="empty-wrap" v-if="!loading && !filteredPosts.length">
					<view class="empty-icon-wrap"><text class="empty-icon-text">🔍</text></view>
					<text class="empty-main-text">未找到相关笔记</text>
					<text class="empty-sub-text">换个关键词试试吧</text>
				</view>
				<view class="feed-end">
					<view class="loading-dots" v-if="loading">
						<view class="dot" v-for="i in 3" :key="i"></view>
					</view>
					<text class="feed-end-text" v-else-if="noMore && filteredPosts.length">— 到底啦 —</text>
				</view>
			</scroll-view>

			<!-- 用户结果 -->
			<scroll-view v-if="searchType === 'users'" scroll-y class="result-scroll user-scroll" :show-scrollbar="false">
				<view class="user-list" v-if="users.length">
					<view class="user-card" v-for="u in users" :key="u.id" @tap="goUserProfile(u)" :class="{ 'card-anim': true }">
						<view class="user-av" :style="{ background: avColor(u.id) }">
							<image v-if="u.avatar" class="av-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
							<text v-else class="av-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
						</view>
						<view class="user-info">
							<text class="user-name">{{ u.nickname || u.username }}</text>
							<text class="user-id">留笔号：{{ u.username }}</text>
						</view>
						<view class="user-go"><text class="go-text">›</text></view>
					</view>
				</view>
				<view class="empty-wrap" v-if="!users.length">
					<view class="empty-icon-wrap"><text class="empty-icon-text">👤</text></view>
					<text class="empty-main-text">未找到相关用户</text>
					<text class="empty-sub-text">换个关键词试试吧</text>
				</view>
			</scroll-view>
		</view>

		<!-- 搜索首页 -->
		<scroll-view v-else scroll-y class="home-scroll" :show-scrollbar="false">
			<!-- 搜索历史 -->
			<view class="section anim-section" v-if="history.length">
				<view class="sec-head">
					<text class="sec-title">搜索历史</text>
					<view class="sec-action" @tap="clearHistory">
						<text class="sec-action-text">清空</text>
					</view>
				</view>
				<view class="tag-list">
					<view class="tag-item" v-for="(h, i) in history" :key="i" @tap="keyword=h;doSearch()">
						<text class="tag-text">{{ h }}</text>
					</view>
				</view>
			</view>

			<!-- 热搜关键词 -->
			<view class="section anim-section" v-if="hotKeywords.length">
				<view class="sec-head">
					<text class="sec-title">🔥 热搜榜</text>
				</view>
				<view class="hot-list">
					<view class="hot-item" v-for="(kw, i) in hotKeywords" :key="i" @tap="keyword=kw.keyword;doSearch()">
						<view class="hot-rank" :class="{ 'rank-1': i===0, 'rank-2': i===1, 'rank-3': i===2 }">
							<text class="hot-rank-text">{{ i + 1 }}</text>
						</view>
						<text class="hot-keyword">{{ kw.keyword }}</text>
						<view class="hot-heat">
							<text class="hot-heat-text">{{ fmtHotCount(kw.count) }}</text>
						</view>
					</view>
				</view>
			</view>

			<!-- 榜单 -->
			<view class="section anim-section">
				<view class="sec-head">
					<view class="trending-tabs">
						<view class="ttab" :class="{ 'ttab-on': trendingTab === 'hot' }" @tap="switchTrending('hot')">
							<text class="ttab-text" :class="{ 'ttab-text-on': trendingTab === 'hot' }">🔥 热门榜</text>
							<view class="ttab-line" v-if="trendingTab === 'hot'"></view>
						</view>
						<view class="ttab" :class="{ 'ttab-on': trendingTab === 'latest' }" @tap="switchTrending('latest')">
							<text class="ttab-text" :class="{ 'ttab-text-on': trendingTab === 'latest' }">✨ 最新榜</text>
							<view class="ttab-line" v-if="trendingTab === 'latest'"></view>
						</view>
					</view>
				</view>
				<view class="trending-list" v-if="trendingList.length">
					<view class="trend-card" v-for="(p, i) in trendingList" :key="p.id" @tap="goDetail(p)">
						<view class="trend-left">
							<view class="trend-rank" :class="{ 'rank-1': i===0, 'rank-2': i===1, 'rank-3': i===2 }">
								<text class="trend-rank-num">{{ i + 1 }}</text>
							</view>
						</view>
						<view class="trend-cover-wrap" v-if="p.cover">
							<image class="trend-cover" :src="coverUrl(p.cover)" mode="aspectFill" />
						</view>
						<view class="trend-cover-wrap" v-else>
							<view class="trend-cover-empty" :style="{ background: trendBg(i) }">
								<text class="trend-cover-letter">{{ (p.title||'?').slice(0,1) }}</text>
							</view>
						</view>
						<view class="trend-info">
							<text class="trend-title">{{ p.title }}</text>
							<view class="trend-meta">
								<text class="trend-author">{{ p.nickname || '匿名' }}</text>
								<text class="trend-cat" v-if="p.category_name">{{ p.category_name }}</text>
							</view>
							<view class="trend-stats">
								<text class="trend-stat">👁 {{ fmtNum(p.views_count||0) }}</text>
								<text class="trend-stat">❤ {{ fmtNum(p.likes_count||0) }}</text>
								<text class="trend-stat">⭐ {{ fmtNum(p.collects_count||0) }}</text>
							</view>
						</view>
					</view>
				</view>
				<view class="empty-wrap" v-else-if="!trendingLoading">
					<text class="empty-main-text">暂无榜单数据</text>
				</view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { request, BASE_URL } from '@/utils/request.js'
import { useUserStore } from '@/store/user.js'
import waterfall from '@/components/waterfall/waterfall.vue'
import postCard from '@/components/quote-card/quote-card.vue'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const keyword = ref('')
const searched = ref(false)
const searchType = ref('posts')
const sortBy = ref('default')
const contentFilter = ref('all')
const autoFocus = ref(true)
const inputFocus = ref(false)

// 笔记结果
const posts = ref([])
const page = ref(1)
const noMore = ref(false)
const loading = ref(false)

// 用户结果
const users = ref([])

// 历史
const history = ref([])
const hotKeywords = ref([])

// 榜单
const trendingTab = ref('hot')
const trendingList = ref([])
const trendingLoading = ref(false)

const filteredPosts = computed(() => {
	if (contentFilter.value === 'image') return posts.value.filter(p => p.images && p.images.length)
	if (contentFilter.value === 'text') return posts.value.filter(p => !p.images || !p.images.length)
	return posts.value
})

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function avColor(id) { return COLORS[id % COLORS.length] }

const BG_LIST = [
	'linear-gradient(135deg, #fff5f5, #ffe8e8)',
	'linear-gradient(135deg, #f0f5ff, #e0eaff)',
	'linear-gradient(135deg, #f0fff4, #d9f7be)',
	'linear-gradient(135deg, #fff7e6, #ffe7ba)',
	'linear-gradient(135deg, #f9f0ff, #efdbff)',
	'linear-gradient(135deg, #e6fffb, #b5f5ec)'
]
function trendBg(i) { return BG_LIST[i % BG_LIST.length] }

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function coverUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function fmtNum(n) {
	if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
	if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
	return String(n || 0)
}
function fmtHotCount(n) {
	if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
	if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
	return (n || 0) + ''
}

function loadHistory() {
	try {
		const h = uni.getStorageSync('search_history')
		if (h) history.value = JSON.parse(h)
	} catch {}
}
function saveHistory(kw) {
	if (!kw.trim()) return
	let arr = history.value.filter(h => h !== kw.trim())
	arr.unshift(kw.trim())
	if (arr.length > 15) arr = arr.slice(0, 15)
	history.value = arr
	uni.setStorageSync('search_history', JSON.stringify(arr))
}
function clearHistory() {
	history.value = []
	uni.removeStorageSync('search_history')
	uni.showToast({ title: '已清空', icon: 'none' })
}

function resetSearch() {
	keyword.value = ''
	searched.value = false
	posts.value = []
	users.value = []
	sortBy.value = 'default'
	contentFilter.value = 'all'
}

async function doSearch() {
	if (!keyword.value.trim()) return
	searched.value = true
	saveHistory(keyword.value.trim())

	if (searchType.value === 'posts') {
		page.value = 1
		noMore.value = false
		posts.value = []
		await fetchPosts()
	} else {
		await fetchUsers()
	}
}

async function fetchPosts() {
	loading.value = true
	const res = await request({
		url: '/posts/search',
		data: {
			keyword: keyword.value.trim(),
			page: page.value,
			pageSize: 20,
			sort: sortBy.value
		}
	})
	if (res.code === 200) {
		const list = res.data.list || []
		posts.value = page.value === 1 ? list : [...posts.value, ...list]
		if (posts.value.length >= res.data.total) noMore.value = true
	}
	loading.value = false
}

async function fetchUsers() {
	loading.value = true
	const res = await request({
		url: '/users/search',
		data: { keyword: keyword.value.trim() }
	})
	if (res.code === 200) {
		users.value = res.data || []
	}
	loading.value = false
}

function loadMore() {
	if (loading.value || noMore.value || searchType.value !== 'posts') return
	page.value++
	fetchPosts()
}

async function loadHotKeywords() {
	const res = await request({ url: '/posts/trending', data: { type: 'keywords' } })
	if (res.code === 200) hotKeywords.value = res.data || []
}

async function loadTrending() {
	trendingLoading.value = true
	const res = await request({ url: '/posts/trending', data: { type: trendingTab.value } })
	if (res.code === 200) trendingList.value = res.data || []
	trendingLoading.value = false
}

function switchTrending(tab) {
	if (trendingTab.value === tab) return
	trendingTab.value = tab
	trendingList.value = []
	loadTrending()
}

function goDetail(p) { uni.navigateTo({ url: '/pages/detail/detail?id=' + p.id }) }
function goUserProfile(u) { uni.navigateTo({ url: '/pages/user-profile/user-profile?userId=' + u.id }) }
function goBack() { uni.navigateBack() }

onMounted(() => {
	loadHistory()
	loadHotKeywords()
	loadTrending()
})
</script>

<style lang="scss" scoped>
.page-search { min-height: 100vh; background: #f5f5f5; }

/* 顶部导航 */
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; box-shadow: 0 1rpx 6rpx rgba(0,0,0,0.04); }
.nav-inner { height: 44px; display: flex; align-items: center; padding: 0 16rpx; gap: 12rpx; }
.nav-left { padding: 4rpx 8rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.search-box { flex: 1; display: flex; align-items: center; background: #f5f5f5; border-radius: 32rpx; padding: 0 16rpx; height: 64rpx; transition: all .25s ease; border: 2rpx solid transparent; }
.search-box-focus { background: #fff; border-color: #ff2442; box-shadow: 0 0 0 4rpx rgba(255,36,66,0.08); }
.search-icon { width: 28rpx; height: 28rpx; margin-right: 10rpx; flex-shrink: 0; }
.search-input { flex: 1; font-size: 26rpx; height: 64rpx; }
.clear-btn { width: 36rpx; height: 36rpx; border-radius: 50%; background: #d0d0d0; display: flex; align-items: center; justify-content: center; flex-shrink: 0; transition: background .2s; }
.clear-btn:active { background: #bbb; }
.clear-x { font-size: 18rpx; color: #fff; }
.nav-search-btn { padding: 0 16rpx; flex-shrink: 0; }
.nav-search-text { font-size: 28rpx; color: #ff2442; font-weight: 600; }

/* 类型切换 */
.type-tabs { display: flex; background: #fff; border-bottom: 1rpx solid #f0f0f0; position: relative; }
.type-tab { flex: 1; display: flex; flex-direction: column; align-items: center; padding: 20rpx 0 0; position: relative; }
.type-text { font-size: 28rpx; color: #999; transition: all .2s; }
.type-text-on { color: #222; font-weight: 700; }
.type-line { width: 40rpx; height: 4rpx; background: #ff2442; border-radius: 2rpx; margin-top: 12rpx; animation: lineIn .2s ease; }
@keyframes lineIn { from { width: 0; } to { width: 40rpx; } }

/* 筛选栏 */
.filter-bar { display: flex; background: #fff; padding: 16rpx 20rpx; gap: 16rpx; border-bottom: 1rpx solid #f8f8f8; }
.filter-chip { padding: 8rpx 24rpx; border-radius: 24rpx; background: #f5f5f5; transition: all .2s; }
.filter-on { background: #ff2442; }
.filter-text { font-size: 24rpx; color: #666; }
.filter-text-on { color: #fff; font-weight: 600; }

/* 内容筛选 */
.content-filter { display: flex; background: #fff; padding: 8rpx 20rpx 16rpx; gap: 16rpx; }
.cf-chip { padding: 4rpx 16rpx; border-radius: 16rpx; border: 1rpx solid #e8e8e8; transition: all .2s; }
.cf-on { border-color: #ff2442; background: rgba(255,36,66,0.05); }
.cf-text { font-size: 22rpx; color: #999; }
.cf-text-on { color: #ff2442; }

.result-scroll { height: calc(100vh - 44px - var(--status-bar-height, 20px) - 80rpx); background: #f5f5f5; padding: 0 12rpx; }
.user-scroll { height: calc(100vh - 44px - var(--status-bar-height, 20px) - 80rpx); }
.fall-area { padding-top: 12rpx; }

/* 用户卡片 */
.user-list { padding: 12rpx 20rpx; }
.user-card { display: flex; align-items: center; background: #fff; border-radius: 16rpx; padding: 24rpx; margin-bottom: 12rpx; transition: transform .15s, box-shadow .15s; }
.user-card:active { transform: scale(0.98); box-shadow: 0 2rpx 12rpx rgba(0,0,0,0.06); }
.user-av { width: 88rpx; height: 88rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 20rpx; overflow: hidden; }
.av-img { width: 88rpx; height: 88rpx; }
.av-text { font-size: 32rpx; color: #fff; font-weight: 600; }
.user-info { flex: 1; overflow: hidden; }
.user-name { font-size: 30rpx; color: #222; font-weight: 600; display: block; }
.user-id { font-size: 22rpx; color: #999; display: block; margin-top: 4rpx; }
.user-go { padding: 0 8rpx; }
.go-text { font-size: 36rpx; color: #ccc; }

/* 搜索首页 */
.home-scroll { height: calc(100vh - 44px - var(--status-bar-height, 20px)); }
.section { background: #fff; margin: 16rpx 16rpx 0; padding: 24rpx; border-radius: 16rpx; }
.section:first-child { margin-top: 12rpx; }
.sec-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20rpx; }
.sec-title { font-size: 30rpx; font-weight: 700; color: #222; }
.sec-action { padding: 4rpx 12rpx; }
.sec-action-text { font-size: 24rpx; color: #999; }

/* 历史标签 */
.tag-list { display: flex; flex-wrap: wrap; gap: 12rpx; }
.tag-item { padding: 10rpx 24rpx; background: #f5f5f5; border-radius: 24rpx; transition: all .15s; }
.tag-item:active { background: #e8e8e8; transform: scale(0.95); }
.tag-text { font-size: 24rpx; color: #666; }

/* 热搜 */
.hot-list {}
.hot-item { display: flex; align-items: center; padding: 18rpx 0; border-bottom: 1rpx solid #f8f8f8; transition: background .15s; }
.hot-item:active { background: #fafafa; }
.hot-item:last-child { border-bottom: none; }
.hot-rank { width: 44rpx; height: 44rpx; border-radius: 10rpx; background: #f0f0f0; display: flex; align-items: center; justify-content: center; margin-right: 16rpx; flex-shrink: 0; }
.rank-1 { background: linear-gradient(135deg, #ff2442, #ff6b81); }
.rank-2 { background: linear-gradient(135deg, #ff6b2e, #ffad42); }
.rank-3 { background: linear-gradient(135deg, #faad14, #ffd666); }
.hot-rank-text { font-size: 24rpx; font-weight: 700; color: #999; }
.rank-1 .hot-rank-text, .rank-2 .hot-rank-text, .rank-3 .hot-rank-text { color: #fff; }
.hot-keyword { flex: 1; font-size: 28rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: 500; }
.hot-heat { flex-shrink: 0; margin-left: 12rpx; }
.hot-heat-text { font-size: 22rpx; color: #ccc; }

/* 榜单tabs */
.trending-tabs { display: flex; gap: 36rpx; }
.ttab { padding: 4rpx 0; position: relative; display: flex; flex-direction: column; align-items: center; }
.ttab-text { font-size: 30rpx; color: #999; transition: all .2s; }
.ttab-text-on { color: #222; font-weight: 700; }
.ttab-line { width: 36rpx; height: 4rpx; background: #ff2442; border-radius: 2rpx; margin-top: 8rpx; animation: lineIn .2s ease; }

/* 榜单卡片 */
.trending-list {}
.trend-card { display: flex; align-items: center; padding: 18rpx 0; border-bottom: 1rpx solid #f8f8f8; transition: background .15s; }
.trend-card:active { background: #fafafa; }
.trend-card:last-child { border-bottom: none; }
.trend-left { margin-right: 16rpx; flex-shrink: 0; }
.trend-rank { width: 44rpx; height: 44rpx; border-radius: 10rpx; background: #f0f0f0; display: flex; align-items: center; justify-content: center; }
.trend-rank-num { font-size: 24rpx; font-weight: 700; color: #999; }
.rank-1 .trend-rank-num { color: #fff; }
.rank-2 .trend-rank-num { color: #fff; }
.rank-3 .trend-rank-num { color: #fff; }
.trend-cover-wrap { margin-right: 16rpx; flex-shrink: 0; }
.trend-cover { width: 88rpx; height: 88rpx; border-radius: 12rpx; }
.trend-cover-empty { width: 88rpx; height: 88rpx; border-radius: 12rpx; display: flex; align-items: center; justify-content: center; }
.trend-cover-letter { font-size: 32rpx; color: #666; font-weight: 600; }
.trend-info { flex: 1; overflow: hidden; }
.trend-title { font-size: 28rpx; color: #222; font-weight: 500; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 1; overflow: hidden; }
.trend-meta { display: flex; align-items: center; gap: 12rpx; margin-top: 8rpx; }
.trend-author { font-size: 22rpx; color: #999; }
.trend-cat { font-size: 20rpx; color: #bbb; background: #f5f5f5; padding: 2rpx 12rpx; border-radius: 8rpx; }
.trend-stats { display: flex; gap: 16rpx; margin-top: 8rpx; }
.trend-stat { font-size: 20rpx; color: #ccc; }

/* 空状态 */
.empty-wrap { text-align: center; padding: 120rpx 0 80rpx; }
.empty-icon-wrap { margin-bottom: 20rpx; }
.empty-icon-text { font-size: 64rpx; }
.empty-main-text { font-size: 28rpx; color: #999; display: block; }
.empty-sub-text { font-size: 24rpx; color: #ccc; display: block; margin-top: 8rpx; }

/* 加载动画 */
.feed-end { padding: 32rpx 0 48rpx; text-align: center; }
.feed-end-text { font-size: 22rpx; color: #ccc; }
.loading-dots { display: flex; justify-content: center; gap: 12rpx; }
.dot { width: 12rpx; height: 12rpx; border-radius: 50%; background: #ccc; animation: dotPulse 1.2s ease infinite; }
.dot:nth-child(2) { animation-delay: .2s; }
.dot:nth-child(3) { animation-delay: .4s; }
@keyframes dotPulse { 0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }

/* 动画 */
.anim-section { animation: sectionIn .35s ease both; }
.anim-section:nth-child(1) { animation-delay: 0s; }
.anim-section:nth-child(2) { animation-delay: .08s; }
.anim-section:nth-child(3) { animation-delay: .16s; }
@keyframes sectionIn { from { opacity: 0; transform: translateY(24rpx); } to { opacity: 1; transform: translateY(0); } }

.card-anim { animation: cardIn .3s ease both; }
@keyframes cardIn { from { opacity: 0; transform: translateX(-16rpx); } to { opacity: 1; transform: translateX(0); } }
</style>
