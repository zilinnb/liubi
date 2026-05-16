<template>
	<view class="page-home">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner" :style="{ transform: 'scale(' + navScale + ')', opacity: navOpacity, transition: navTransition }">
				<view class="nav-tabs">
					<view class="ntab" :class="{ 'ntab-on': topTab === 'follow' }" @tap="switchTab('follow')">
						<text class="ntab-text" :class="{ 'ntab-text-on': topTab === 'follow' }">关注</text>
						<view class="ntab-line" v-if="topTab === 'follow'"></view>
					</view>
					<view class="ntab" :class="{ 'ntab-on': topTab === 'discover' }" @tap="switchTab('discover')">
						<text class="ntab-text" :class="{ 'ntab-text-on': topTab === 'discover' }">发现</text>
						<view class="ntab-line" v-if="topTab === 'discover'"></view>
					</view>
				</view>
				<view class="nav-right" @tap="onSearch">
					<image class="search-btn" src="/static/icons/search.png" mode="aspectFit" />
				</view>
			</view>
		</view>

		<view class="cate-bar" v-if="topTab === 'discover'" :style="{ top: navBarH + 'px', transform: 'translateY(' + cateTranslateY + 'px)', opacity: cateOpacity, transition: cateTransition }">
			<scroll-view scroll-x class="cate-scroll" :show-scrollbar="false" scroll-with-animation :scroll-left="cateScrollLeft">
				<view
					class="cate-chip"
					:class="{ 'cate-chip-on': currentCateIdx === idx }"
					v-for="(tab, idx) in cateTabs"
					:key="tab.id"
					:id="'cate-' + idx"
					@tap="selectCate(idx)"
				>
					<text class="cate-label" :class="{ 'cate-label-on': currentCateIdx === idx }">{{ tab.name }}</text>
				</view>
			</scroll-view>
			<view class="sort-tag" :class="{ 'sort-bounce': sortBounce }" @tap="onToggleSort">
				<text class="sort-tag-text">{{ sortLabel }}</text>
				<text class="sort-tag-arrow">▾</text>
			</view>
		</view>

		<view class="feed-area" :style="{ paddingTop: feedPaddingTop + 'px', transition: feedTransition }">
			<scroll-view
				v-show="topTab === 'follow'"
				scroll-y
				class="feed-scroll"
				:show-scrollbar="false"
				:scroll-top="followScrollTop"
				refresher-enabled
				:refresher-triggered="followPulling"
				:refresher-threshold="80"
				refresher-background="#f5f5f5"
				@refresherrefresh="onFollowRefresh"
				@scrolltolower="onFollowBottom"
				@scroll="onFollowScroll"
			>
				<view v-if="!userStore.isLoggedIn" class="empty-state">
					<view class="empty-icon-circle"><text class="empty-icon-text">!</text></view>
					<text class="empty-text">登录后查看关注动态</text>
					<view class="empty-btn" @tap="goLogin"><text class="empty-btn-text">去登录</text></view>
				</view>
				<view v-else-if="!postStore.posts.length && !postStore.loading" class="empty-state">
					<view class="empty-icon-circle"><text class="empty-icon-text">~</text></view>
					<text class="empty-text">还没有关注的人，去发现页看看吧</text>
				</view>
				<template v-else>
					<waterfall :list="postStore.posts" :colNum="2">
						<template #item="{ item }">
							<post-card :item="item" />
						</template>
					</waterfall>
					<view class="feed-end">
						<view class="loading-dots" v-if="postStore.loading">
							<view class="dot" v-for="i in 3" :key="i"></view>
						</view>
						<text class="feed-end-text" v-else-if="followNoMore">— 到底啦 —</text>
					</view>
				</template>
			</scroll-view>

			<scroll-view
				v-show="topTab === 'discover'"
				scroll-y
				class="feed-scroll"
				:show-scrollbar="false"
				:scroll-top="discoverScrollTop"
				refresher-enabled
				:refresher-triggered="discoverPulling"
				:refresher-threshold="80"
				refresher-background="#f5f5f5"
				@refresherrefresh="onDiscoverRefresh"
				@scrolltolower="onDiscoverBottom"
				@scroll="onDiscoverScroll"
				@touchstart="onTouchStart"
				@touchmove="onTouchMove"
				@touchend="onTouchEnd"
			>
				<view class="cate-content" :key="'cate-' + currentCateIdx + '-' + renderKey" :class="slideClass">
					<view v-if="!currentCatePosts.length && !currentCateLoading" class="empty-state">
						<view class="empty-icon-circle"><text class="empty-icon-text">~</text></view>
						<text class="empty-text">暂无内容，下拉刷新试试</text>
					</view>
					<template v-else>
						<waterfall :list="currentCatePosts" :colNum="2">
							<template #item="{ item }">
								<post-card :item="item" />
							</template>
						</waterfall>
						<view class="feed-end">
							<view class="loading-dots" v-if="currentCateLoading">
								<view class="dot" v-for="i in 3" :key="i"></view>
							</view>
							<text class="feed-end-text" v-else-if="currentCateNoMore">— 到底啦 —</text>
						</view>
					</template>
				</view>
			</scroll-view>
		</view>

		<custom-tabbar :current="0" />
		<update-dialog :visible="showUpdate" :info="updateInfo" @close="onUpdateClose" @update="onUpdateDone" />

		<view class="back-top-btn" v-if="showBackTop" @tap="scrollToTop">
			<image class="bt-icon" src="/static/icons/top.png" mode="aspectFit" />
		</view>
	</view>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { usePostStore } from '@/store/quote.js'
import { useUserStore } from '@/store/user.js'
import waterfall from '@/components/waterfall/waterfall.vue'
import postCard from '@/components/quote-card/quote-card.vue'
import customTabbar from '@/components/custom-tabbar/custom-tabbar.vue'
import updateDialog from '@/components/update-dialog/update-dialog.vue'
import { checkUpdate, getStoredUpdateInfo, clearStoredUpdateInfo } from '@/utils/update.js'

const postStore = usePostStore()
const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const navBarH = statusBarH + 44
const cateBarH = 50

const topTab = ref('discover')
const currentCateIdx = ref(0)

const cateTabs = computed(() => {
	const list = [{ id: 0, name: '推荐' }]
	if (postStore.categories && postStore.categories.length) {
		postStore.categories.forEach(c => {
			list.push({ id: c.id, name: c.name })
		})
	}
	return list
})

const currentCateId = computed(() => {
	const tab = cateTabs.value[currentCateIdx.value]
	return tab ? tab.id : 0
})

const currentCatePosts = computed(() => {
	const key = String(currentCateId.value)
	return postStore.categoryPosts[key] || []
})

const currentCateLoading = computed(() => {
	const key = String(currentCateId.value)
	return postStore.categoryLoading[key] || false
})

const currentCateNoMore = computed(() => {
	const key = String(currentCateId.value)
	return postStore.categoryNoMore[key] || false
})

const followPulling = ref(false)
const discoverPulling = ref(false)
const followScrollTop = ref(0)
const discoverScrollTop = ref(0)
const followNoMore = ref(false)

const mounted = ref(false)
const showUpdate = ref(false)
const updateInfo = ref({})
const showBackTop = ref(false)
const collapseY = ref(0)
const cateScrollLeft = ref(0)
const slideClass = ref('')
const sortBounce = ref(false)
const renderKey = ref(0)

const SORT_CYCLE = ['latest', 'hot', 'random']
const SORT_LABELS = ['最新', '最热', '随机']
const sortIdx = ref(0)
const sortLabel = computed(() => SORT_LABELS[sortIdx.value])
const currentSort = computed(() => SORT_CYCLE[sortIdx.value])

const isAnimating = ref(false)
const SMOOTH_CURVE = 'cubic-bezier(0.25, 0.1, 0.25, 1)'
const SPRING_CURVE = 'cubic-bezier(0.34, 1.56, 0.64, 1)'
const SNAP_CURVE = 'cubic-bezier(0.22, 0.61, 0.36, 1)'

const navTransition = computed(() => isAnimating.value ? `transform .35s ${SNAP_CURVE}, opacity .35s ${SNAP_CURVE}` : 'none')
const cateTransition = computed(() => isAnimating.value ? `transform .35s ${SNAP_CURVE}, opacity .3s ${SNAP_CURVE}` : 'none')
const feedTransition = computed(() => isAnimating.value ? `padding-top .35s ${SNAP_CURVE}` : 'none')

const navScale = computed(() => 1 - 0.12 * (collapseY.value / cateBarH))
const navOpacity = computed(() => 1 - 0.2 * (collapseY.value / cateBarH))
const cateTranslateY = computed(() => -collapseY.value)
const cateOpacity = computed(() => Math.max(0, 1 - collapseY.value / cateBarH))
const feedPaddingTop = computed(() => {
	if (topTab.value === 'discover') return navBarH + cateBarH - collapseY.value
	return navBarH
})

let lastScrollTop = 0
let lastScrollDelta = 0
let scrollAnimTimer = null
let snapTimer = null
let cateInited = {}
let velocityAccum = 0
let lastScrollTime = 0

let touchStartX = 0
let touchStartY = 0
let touchStartTime = 0
let isSwiping = false

function smoothAnimateTo(target) {
	const clamped = Math.max(0, Math.min(cateBarH, target))
	if (Math.abs(collapseY.value - clamped) < 0.5) {
		collapseY.value = clamped
		isAnimating.value = false
		return
	}
	isAnimating.value = true
	collapseY.value = clamped
	setTimeout(() => { isAnimating.value = false }, 380)
}

async function ensureCateData(idx) {
	const tab = cateTabs.value[idx]
	if (!tab) return
	const key = String(tab.id)
	const storedSort = postStore.categorySort[key] || ''
	if (!cateInited[key] || storedSort !== currentSort.value) {
		cateInited[key] = true
		await postStore.fetchCategoryPosts(tab.id, true, currentSort.value)
	}
}

function selectCate(idx) {
	if (currentCateIdx.value === idx) return
	sortIdx.value = 0
	renderKey.value++
	const direction = idx > currentCateIdx.value ? 'left' : 'right'
	currentCateIdx.value = idx
	slideClass.value = direction === 'left' ? 'slide-in-right' : 'slide-in-left'
	setTimeout(() => { slideClass.value = '' }, 300)
	scrollCateToActive(idx)
	ensureCateData(idx)
	smoothAnimateTo(0)
	showBackTop.value = false
}

function scrollCateToActive(idx) {
	nextTick(() => {
		const query = uni.createSelectorQuery().in(getCurrentInstance())
		query.select('#cate-' + idx).boundingClientRect()
		query.select('.cate-scroll').scrollOffset()
		query.exec((res) => {
			if (res[0] && res[1]) {
				const targetLeft = res[0].left
				const currentScroll = res[1].scrollLeft
				const screenWidth = sys.windowWidth
				const offset = targetLeft + currentScroll - screenWidth / 2 + res[0].width / 2
				cateScrollLeft.value = offset
			}
		})
	})
}

function onTouchStart(e) {
	if (e.touches && e.touches.length > 0) {
		touchStartX = e.touches[0].clientX
		touchStartY = e.touches[0].clientY
		touchStartTime = Date.now()
		isSwiping = false
	}
}

function onTouchMove(e) {
	if (e.touches && e.touches.length > 0) {
		const moveX = e.touches[0].clientX - touchStartX
		const moveY = e.touches[0].clientY - touchStartY
		if (Math.abs(moveX) > 30 && Math.abs(moveX) > Math.abs(moveY) * 1.5) {
			isSwiping = true
		}
	}
}

function onTouchEnd(e) {
	if (!isSwiping) return
	if (!e.changedTouches || e.changedTouches.length === 0) return
	const endX = e.changedTouches[0].clientX
	const endY = e.changedTouches[0].clientY
	const deltaX = endX - touchStartX
	const deltaY = endY - touchStartY
	const duration = Date.now() - touchStartTime

	if (Math.abs(deltaX) > 60 && Math.abs(deltaX) > Math.abs(deltaY) * 1.5 && duration < 600) {
		if (deltaX < 0) {
			if (currentCateIdx.value < cateTabs.value.length - 1) {
				selectCate(currentCateIdx.value + 1)
			}
		} else {
			if (currentCateIdx.value > 0) {
				selectCate(currentCateIdx.value - 1)
			}
		}
	}
	isSwiping = false
}

function switchTab(tab) {
	if (topTab.value === tab) return
	topTab.value = tab
	if (tab === 'follow') {
		postStore.setFeedType('follow')
	} else {
		ensureCateData(currentCateIdx.value)
	}
	smoothAnimateTo(0)
	showBackTop.value = false
	lastScrollTop = 0
}

async function onFollowRefresh() {
	followPulling.value = true
	smoothAnimateTo(0)
	lastScrollTop = 0
	try {
		await postStore.fetchPosts(true)
	} catch (e) {
		console.error('follow refresh error:', e)
	}
	followNoMore.value = false
	await nextTick()
	setTimeout(() => { followPulling.value = false }, 80)
}

async function onFollowBottom() {
	if (postStore.loading || followNoMore.value) return
	if (postStore.posts.length >= postStore.total && postStore.total > 0) {
		followNoMore.value = true
		return
	}
	postStore.page++
	await postStore.fetchPosts()
	if (postStore.posts.length >= postStore.total) followNoMore.value = true
}

function onFollowScroll(e) {
	const st = e.detail.scrollTop || 0
	lastScrollTop = st
	if (st > 600) {
		if (!showBackTop.value) showBackTop.value = true
	} else {
		if (showBackTop.value) showBackTop.value = false
	}
}

async function onDiscoverRefresh() {
	discoverPulling.value = true
	smoothAnimateTo(0)
	if (sortIdx.value < 2) sortIdx.value++
	renderKey.value++
	sortBounce.value = true
	setTimeout(() => { sortBounce.value = false }, 350)
	try {
		await postStore.fetchCategoryPosts(currentCateId.value, true, currentSort.value)
	} catch (e) {
		console.error('discover refresh error:', e)
	} finally {
		await nextTick()
		setTimeout(() => { discoverPulling.value = false }, 100)
	}
}

function onToggleSort() {
	if (sortIdx.value < 2) sortIdx.value++
	renderKey.value++
	sortBounce.value = true
	setTimeout(() => { sortBounce.value = false }, 350)
	postStore.fetchCategoryPosts(currentCateId.value, true, currentSort.value)
}

async function onDiscoverBottom() {
	const key = String(currentCateId.value)
	if (postStore.categoryLoading[key] || postStore.categoryNoMore[key]) return
	await postStore.loadMoreCategoryPosts(currentCateId.value)
}

function onDiscoverScroll(e) {
	const st = e.detail.scrollTop || 0
	const now = Date.now()
	lastScrollTop = st

	if (st > 600) {
		if (!showBackTop.value) showBackTop.value = true
	} else {
		if (showBackTop.value) showBackTop.value = false
	}

	isAnimating.value = false

	const delta = st - (onDiscoverScroll._lastSt || 0)
	onDiscoverScroll._lastSt = st
	if (Math.abs(delta) < 0.5) return

	const dt = now - (lastScrollTime || now)
	lastScrollTime = now
	const velocity = dt > 0 ? Math.abs(delta / dt) : 0

	const dampingFactor = 0.65
	const adjustedDelta = delta * dampingFactor

	if (delta > 0 && st > 10) {
		lastScrollDelta = delta
		velocityAccum = velocity
		collapseY.value = Math.min(collapseY.value + adjustedDelta, cateBarH)
	} else if (delta < 0) {
		lastScrollDelta = delta
		velocityAccum = velocity
		const expandSpeed = velocity > 0.5 ? 1.3 : 1.0
		collapseY.value = Math.max(collapseY.value + adjustedDelta * expandSpeed, 0)
	}
	if (st <= 0) collapseY.value = 0

	if (snapTimer) clearTimeout(snapTimer)
	snapTimer = setTimeout(snapHeader, 120)
}

function onSearch() { uni.navigateTo({ url: '/pages/search/search' }) }
function goLogin() { uni.navigateTo({ url: '/pages/login/login' }) }
function onUpdateClose() {
	if (updateInfo.value && updateInfo.value.forceUpdate) return
	showUpdate.value = false
}
function onUpdateDone() {
	clearStoredUpdateInfo()
	showUpdate.value = false
}

function scrollToTop() {
	if (scrollAnimTimer) {
		clearInterval(scrollAnimTimer)
		scrollAnimTimer = null
	}
	const scrollTopRef = topTab.value === 'discover' ? discoverScrollTop : followScrollTop
	const start = lastScrollTop
	if (start <= 0) {
		scrollTopRef.value = 0
		showBackTop.value = false
		smoothAnimateTo(0)
		return
	}
	const duration = 400
	const startTime = Date.now()
	scrollAnimTimer = setInterval(() => {
		const elapsed = Date.now() - startTime
		const progress = Math.min(elapsed / duration, 1)
		const eased = 1 - Math.pow(1 - progress, 3)
		scrollTopRef.value = Math.round(start * (1 - eased))
		if (progress >= 1) {
			clearInterval(scrollAnimTimer)
			scrollAnimTimer = null
			scrollTopRef.value = 0
			lastScrollTop = 0
		}
	}, 16)
	showBackTop.value = false
	smoothAnimateTo(0)
}

function snapHeader() {
	if (collapseY.value > 0 && collapseY.value < cateBarH) {
		const threshold = velocityAccum > 0.8 ? 0.2 : 0.35
		const target = collapseY.value > cateBarH * threshold ? cateBarH : 0
		smoothAnimateTo(target)
	}
	velocityAccum = 0
}

watch(cateTabs, (newTabs) => {
	if (newTabs.length && currentCateIdx.value >= newTabs.length) {
		currentCateIdx.value = 0
	}
	if (!cateInited['0']) {
		cateInited['0'] = true
		postStore.fetchCategoryPosts(0, true, currentSort.value)
	}
}, { immediate: true })

onMounted(() => {
	mounted.value = true
	postStore.fetchCategories()
	uni.$on('app-update', (info) => {
		updateInfo.value = info
		showUpdate.value = true
	})
	const stored = getStoredUpdateInfo()
	if (stored && !showUpdate.value) {
		updateInfo.value = stored
		showUpdate.value = true
	}
})

onShow(() => {
	uni.hideTabBar({ animation: false })
	const stored = getStoredUpdateInfo()
	if (stored && !showUpdate.value) {
		updateInfo.value = stored
		showUpdate.value = true
	}
	if (mounted.value) {
		if (topTab.value === 'follow') {
			postStore.fetchPosts(true)
		} else {
			postStore.fetchCategoryPosts(currentCateId.value, true, currentSort.value)
		}
	}
})
</script>

<style lang="scss" scoped>
.page-home { background: #f5f5f5; height: 100vh; display: flex; flex-direction: column; overflow: hidden; }

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
	position: relative;
	transform-origin: center top;
	will-change: transform, opacity;
}
.nav-tabs { display: flex; align-items: center; gap: 52rpx; }
.ntab { position: relative; padding: 8rpx 0; display: flex; flex-direction: column; align-items: center; }
.ntab-line { width: 32rpx; height: 6rpx; background: #ff2442; border-radius: 3rpx; margin-top: 6rpx; animation: lineGrow .2s ease; }
@keyframes lineGrow { from { width: 0; } to { width: 32rpx; } }
.ntab-text { font-size: 30rpx; color: #aaa; transition: all .2s; }
.ntab-text-on { font-size: 34rpx; color: #222; font-weight: 700; }
.nav-right { position: absolute; right: 28rpx; top: 50%; transform: translateY(-50%); padding: 8rpx; }
.search-btn { width: 36rpx; height: 36rpx; }

.cate-bar {
	position: fixed;
	left: 0;
	right: 0;
	z-index: 998;
	background: #fff;
	border-bottom: 1rpx solid #f5f5f5;
	will-change: transform, opacity;
	display: flex;
	align-items: center;
}
.cate-scroll { flex: 1; background: #fff; white-space: nowrap; padding: 16rpx 20rpx 20rpx; }
.sort-tag {
	flex-shrink: 0; padding: 8rpx 20rpx; margin-right: 16rpx;
	background: #fff0f3; border-radius: 20rpx;
	display: flex; align-items: center; justify-content: center;
}
.sort-tag-text { font-size: 22rpx; color: #ff2442; font-weight: 600; }
	.sort-tag-arrow { font-size: 18rpx; color: #ff2442; margin-left: 4rpx; transition: transform .3s; }
	.sort-tag:active { transform: scale(0.92); }
	.sort-bounce { animation: sortPop .35s cubic-bezier(0.34, 1.56, 0.64, 1); }
	@keyframes sortPop {
		0% { transform: scale(1); }
		40% { transform: scale(1.18); }
		100% { transform: scale(1); }
	}
.cate-chip {
	display: inline-block;
	padding: 10rpx 28rpx;
	border-radius: 28rpx;
	background: #f5f5f5;
	margin-right: 14rpx;
	transition: all .25s cubic-bezier(0.34, 1.56, 0.64, 1);
	vertical-align: middle;
}
.cate-chip-on { background: #ff2442; box-shadow: 0 4rpx 16rpx rgba(255,36,66,0.25); transform: scale(1.05); }
.cate-label { font-size: 24rpx; color: #888; transition: color .25s; }
.cate-label-on { color: #fff; font-weight: 600; }

.feed-area { flex: 1; overflow: hidden; position: relative; }
.feed-scroll { height: 100%; padding-top: 16rpx; }

.cate-content {
	min-height: 100%;
}

.slide-in-right {
	animation: slideInRight 0.28s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.slide-in-left {
	animation: slideInLeft 0.28s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
@keyframes slideInRight {
	from { opacity: 0.3; transform: translateX(120rpx); }
	to { opacity: 1; transform: translateX(0); }
}
@keyframes slideInLeft {
	from { opacity: 0.3; transform: translateX(-120rpx); }
	to { opacity: 1; transform: translateX(0); }
}

.feed-end { padding: 32rpx 0 120rpx; text-align: center; }
.feed-end-text { font-size: 22rpx; color: #ccc; }
.loading-dots { display: flex; justify-content: center; gap: 12rpx; }
.dot { width: 12rpx; height: 12rpx; border-radius: 50%; background: #ccc; animation: dotPulse 1.2s ease infinite; }
.dot:nth-child(2) { animation-delay: .2s; }
.dot:nth-child(3) { animation-delay: .4s; }
@keyframes dotPulse { 0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }

.empty-state { display: flex; flex-direction: column; align-items: center; padding-top: 200rpx; }
.empty-icon-circle { width: 80rpx; height: 80rpx; border-radius: 50%; background: #f0f0f0; display: flex; align-items: center; justify-content: center; }
.empty-icon-text { font-size: 36rpx; color: #ccc; }
.empty-text { font-size: 28rpx; color: #999; margin-top: 20rpx; }
.empty-btn { margin-top: 30rpx; padding: 16rpx 48rpx; background: #ff2442; border-radius: 36rpx; }
.empty-btn-text { font-size: 28rpx; color: #fff; font-weight: 600; }

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
