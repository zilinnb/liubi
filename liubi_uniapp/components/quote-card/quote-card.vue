<template>
	<view class="post-card" @tap="goDetail">
		<view class="card-cover" v-if="item.images && item.images.length">
			<image class="cover-img" :src="fullUrl(firstImgUrl)" mode="aspectFill" lazy-load :style="{ height: coverHeight + 'rpx' }" />
			<view class="views-badge" v-if="item.views_count">
				<image class="views-icon" src="/static/icons/liulan.png" mode="aspectFit" />
				<text class="views-badge-text">{{ fmtViews(item.views_count) }}</text>
			</view>
			<view class="img-count" v-if="item.images.length > 1">
				<text class="img-count-text">{{ item.images.length }}图</text>
			</view>
			<view class="voice-badge" v-if="item.voice_url">
				<view class="voice-badge-bars">
					<view class="vb-bar" v-for="i in 3" :key="i"></view>
				</view>
				<text class="voice-badge-text">{{ fmtTime(item.voice_duration) }}</text>
			</view>
		</view>

		<view class="card-text-cover" v-else-if="item.post_type === 1" :style="{ background: tplBg }">
			<text class="text-cover-content" :style="{ color: tplColor }">{{ item.content }}</text>
			<view class="views-badge-corner" v-if="item.views_count">
				<image class="views-icon" src="/static/icons/liulan.png" mode="aspectFit" />
				<text class="views-badge-text">{{ fmtViews(item.views_count) }}</text>
			</view>
		</view>

		<view class="card-voice-cover" v-else-if="item.voice_url">
			<view class="voice-play-icon">
				<view class="vpi-bar" v-for="i in 3" :key="i"></view>
			</view>
			<view class="voice-wave">
				<view class="vw-bar" v-for="i in 16" :key="i" :style="{ height: waveH(i) }"></view>
			</view>
			<text class="voice-dur">{{ fmtTime(item.voice_duration) }}</text>
			<view class="views-badge-corner" v-if="item.views_count">
				<image class="views-icon" src="/static/icons/liulan.png" mode="aspectFit" />
				<text class="views-badge-text">{{ fmtViews(item.views_count) }}</text>
			</view>
		</view>

		<view class="card-text-cover card-text-fallback" v-else :style="{ background: cardBg }">
			<text class="text-cover-content text-fallback">{{ item.content }}</text>
			<view class="views-badge-corner" v-if="item.views_count">
				<image class="views-icon" src="/static/icons/liulan.png" mode="aspectFit" />
				<text class="views-badge-text">{{ fmtViews(item.views_count) }}</text>
			</view>
		</view>

		<view class="card-body">
			<text class="card-title" v-if="item.title">{{ item.title }}</text>
			<view class="card-footer">
				<view class="card-user">
					<image v-if="item.avatar" class="user-av-img" :src="fullUrl(item.avatar)" mode="aspectFill" />
					<view v-else class="user-av" :style="{ background: userColor }">
						<text class="av-letter">{{ (item.nickname||item.username||'?').charAt(0) }}</text>
					</view>
					<text class="user-name">{{ item.nickname || item.username }}</text>
				</view>
				<view class="card-like" @tap.stop="onLike">
					<view class="like-icon-wrap">
						<image class="like-icon" :class="{ 'like-bounce': likeBouncing }" :src="item.isLiked ? '/static/icons/like-active.png' : '/static/icons/like.png'" mode="aspectFit" />
						<view class="like-particles" v-if="likeBouncing">
							<view class="lp" v-for="i in 6" :key="i" :style="{ transform: 'rotate(' + (i * 60) + 'deg)' }">
								<view class="lp-dot"></view>
							</view>
						</view>
					</view>
					<text class="like-num" :class="{ 'num-bounce': likeBouncing }">{{ fmtNum(item.likes_count) }}</text>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { computed, ref } from 'vue'
import { usePostStore } from '@/store/quote.js'
import { useUserStore } from '@/store/user.js'
import { BASE_URL } from '@/utils/request.js'

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2','#eb2f96','#fa541c']

const props = defineProps({
	item: { type: Object, required: true }
})

const postStore = usePostStore()
const userStore = useUserStore()
const likeBouncing = ref(false)

const firstImgUrl = computed(() => {
	if (!props.item.images || !props.item.images.length) return ''
	const first = props.item.images[0]
	return typeof first === 'object' ? first.url : first
})

const coverHeight = computed(() => {
	if (!props.item.images || !props.item.images.length) return 340
	const first = props.item.images[0]
	const wRatio = (typeof first === 'object' ? (first.ratio || 1.2) : 1.2)
	const hRatio = 1 / wRatio
	return Math.round(340 * Math.min(Math.max(hRatio, 0.65), 1.5))
})

const TEXT_TPLS = [
	{ bg: 'linear-gradient(145deg, #fff5f5, #ffe0e0)', color: '#c41d3a' },
	{ bg: 'linear-gradient(145deg, #f0f5ff, #d6e4ff)', color: '#1d39c4' },
	{ bg: 'linear-gradient(145deg, #f6ffed, #d9f7be)', color: '#389e0d' },
	{ bg: 'linear-gradient(145deg, #1a1a2e, #16213e)', color: '#e8e8e8' },
	{ bg: 'linear-gradient(145deg, #fff8e1, #ffecb3)', color: '#ad6800' },
	{ bg: 'linear-gradient(145deg, #f9f0ff, #efdbff)', color: '#531dab' },
	{ bg: 'linear-gradient(145deg, #e6fffb, #b5f5ec)', color: '#08979c' },
	{ bg: 'linear-gradient(145deg, #fff1f0, #ffccc7)', color: '#cf1322' }
]
const BG_LIST = [
	'linear-gradient(145deg, #fafafa, #f0f0f0)',
	'linear-gradient(145deg, #fff5f5, #ffe8e8)',
	'linear-gradient(145deg, #f0f5ff, #e0eaff)',
	'linear-gradient(145deg, #f6ffed, #d9f7be)',
	'linear-gradient(145deg, #fff8e1, #ffe7ba)',
	'linear-gradient(145deg, #f9f0ff, #efdbff)'
]

const cardBg = computed(() => BG_LIST[(props.item.user_id || props.item.id) % BG_LIST.length])
const userColor = computed(() => COLORS[(props.item.user_id || props.item.id) % COLORS.length])
const tplBg = computed(() => { const i = props.item.text_template || 0; return TEXT_TPLS[i % TEXT_TPLS.length].bg })
const tplColor = computed(() => { const i = props.item.text_template || 0; return TEXT_TPLS[i % TEXT_TPLS.length].color })

function fullUrl(url) {
	if (!url) return ''
	if (typeof url === 'object') url = url.url || ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function goDetail() { uni.navigateTo({ url: `/pages/detail/detail?id=${props.item.id}` }) }
async function onLike() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const wasLiked = props.item.isLiked
	const res = await postStore.toggleLike(props.item.id)
	if (res?.code === 200 && !wasLiked) {
		likeBouncing.value = true
		setTimeout(() => { likeBouncing.value = false }, 600)
	}
}
function fmtNum(n) {
	if (!n) return ''
	if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
	if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
	return String(n)
}
function fmtViews(n) {
	if (!n) return ''
	if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
	if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
	return String(n)
}
function waveH(i) { return Math.max(6, 16 + Math.sin(i * 1.1) * 12) + 'rpx' }
function fmtTime(s) { s = s || 0; const m = Math.floor(s / 60); return m > 0 ? m + ':' + String(s % 60).padStart(2, '0') : s + '"' }
</script>

<style lang="scss" scoped>
.post-card {
	background: #fff;
	border-radius: 16rpx;
	overflow: hidden;
	margin-bottom: 0;
}
.post-card:active { opacity: 0.92; }

.card-cover { position: relative; width: 100%; overflow: hidden; }
.cover-img { width: 100%; display: block; }
.views-badge {
	position: absolute; left: 12rpx; top: 12rpx;
	background: rgba(0,0,0,.45); border-radius: 20rpx;
	padding: 4rpx 12rpx;
	display: flex; align-items: center; gap: 4rpx;
}
.views-badge-corner {
	position: absolute; right: 12rpx; top: 12rpx;
	background: rgba(0,0,0,.35); border-radius: 20rpx;
	padding: 4rpx 12rpx;
	display: flex; align-items: center; gap: 4rpx;
}
.views-icon { width: 20rpx; height: 20rpx; }
.views-badge-text { font-size: 18rpx; color: #fff; font-weight: 500; }
.img-count {
	position: absolute; right: 12rpx; top: 12rpx;
	background: rgba(0,0,0,.45); border-radius: 20rpx;
	padding: 4rpx 14rpx;
}
.img-count-text { font-size: 20rpx; color: #fff; font-weight: 500; }

.voice-badge {
	position: absolute; left: 12rpx; bottom: 12rpx;
	background: rgba(0,0,0,.55); border-radius: 20rpx;
	padding: 4rpx 14rpx;
	display: flex; align-items: center; gap: 6rpx;
}
.voice-badge-bars { display: flex; align-items: center; gap: 2rpx; }
.vb-bar { width: 3rpx; background: #fff; border-radius: 2rpx; }
.vb-bar:nth-child(1) { height: 8rpx; }
.vb-bar:nth-child(2) { height: 14rpx; }
.vb-bar:nth-child(3) { height: 8rpx; }
.voice-badge-text { font-size: 18rpx; color: #fff; font-weight: 500; }

.card-text-cover {
	min-height: 200rpx; max-height: 280rpx;
	padding: 32rpx 28rpx;
	display: flex; align-items: center;
	border-radius: 0; position: relative;
}
.text-cover-content {
	font-size: 28rpx; line-height: 1.8;
	display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 5; overflow: hidden;
}
.text-fallback { font-size: 26rpx; color: #555; }

.card-voice-cover {
	min-height: 160rpx; padding: 32rpx 28rpx;
	display: flex; align-items: center; justify-content: center; gap: 16rpx;
	background: linear-gradient(145deg, #fff5f5, #ffe8e8);
	position: relative;
}
.voice-play-icon {
	width: 48rpx; height: 48rpx; border-radius: 50%;
	background: #ff2442; display: flex; align-items: center; justify-content: center; gap: 3rpx; flex-shrink: 0;
}
.vpi-bar { width: 4rpx; background: #fff; border-radius: 2rpx; }
.vpi-bar:nth-child(1) { height: 10rpx; }
.vpi-bar:nth-child(2) { height: 18rpx; }
.vpi-bar:nth-child(3) { height: 10rpx; }
.voice-wave { display: flex; align-items: center; gap: 4rpx; flex: 1; }
.vw-bar { width: 5rpx; background: #ff2442; border-radius: 3rpx; min-height: 6rpx; opacity: 0.6; }
.voice-dur { font-size: 26rpx; color: #ff2442; font-weight: 600; flex-shrink: 0; }

.card-body { padding: 16rpx 20rpx 20rpx; }
.card-title {
	font-size: 26rpx; font-weight: 600; color: #222; line-height: 1.5;
	display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; overflow: hidden;
	margin-bottom: 14rpx;
}

.card-footer { display: flex; align-items: center; justify-content: space-between; }
.card-user { display: flex; align-items: center; flex: 1; overflow: hidden; }
.user-av {
	width: 36rpx; height: 36rpx; border-radius: 50%;
	display: flex; align-items: center; justify-content: center;
	flex-shrink: 0;
}
.user-av-img {
	width: 36rpx; height: 36rpx; border-radius: 50%;
	flex-shrink: 0;
}
.av-letter { font-size: 20rpx; color: #fff; font-weight: 600; }
.user-name {
	font-size: 22rpx; color: #999; margin-left: 10rpx;
	overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}

.card-like { display: flex; align-items: center; gap: 6rpx; position: relative; }
.like-icon-wrap { position: relative; display: flex; align-items: center; justify-content: center; }
.like-bounce { animation: likeBounce .5s cubic-bezier(0.17, 0.89, 0.32, 1.49); }
@keyframes likeBounce {
	0% { transform: scale(1); }
	20% { transform: scale(1.4); }
	50% { transform: scale(0.85); }
	75% { transform: scale(1.1); }
	100% { transform: scale(1); }
}
.num-bounce { animation: numBounce .4s cubic-bezier(0.17, 0.89, 0.32, 1.49); }
@keyframes numBounce {
	0% { transform: scale(1); }
	30% { transform: scale(1.25); }
	100% { transform: scale(1); }
}
.like-particles { position: absolute; top: 50%; left: 50%; width: 0; height: 0; z-index: 2; }
.lp { position: absolute; top: 0; left: 0; }
.lp-dot {
	width: 6rpx; height: 6rpx; border-radius: 50%;
	background: #ff2442; animation: particleFly .5s ease-out forwards;
}
@keyframes particleFly {
	0% { transform: translateY(0); opacity: 1; }
	100% { transform: translateY(-28rpx); opacity: 0; }
}
.like-icon { width: 28rpx; height: 28rpx; }
.like-num { font-size: 22rpx; color: #bbb; margin-left: 6rpx; }
</style>
