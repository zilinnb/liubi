<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">帖子审核</text>
				<view class="nav-right"><text class="pending-count" v-if="list.length">{{ list.length }}条待审</text></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="list-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="list-inner">
			<view class="review-card" v-for="p in list" :key="p.id">
				<view class="card-head">
					<view class="card-av" :style="{ background: avColor(p.user_id) }">
						<text class="av-text">{{ (p.nickname||p.username||'?').slice(0,1) }}</text>
					</view>
					<view class="card-user">
						<text class="card-name">{{ p.nickname || p.username }}</text>
						<text class="card-time">{{ fmtDate(p.created_at) }}</text>
					</view>
				</view>
				<view class="card-body">
					<text class="card-title">{{ p.title }}</text>
					<text class="card-content">{{ (p.content||'').slice(0, 150) }}</text>
				</view>
				<view class="card-actions">
					<view class="act-btn act-reject" @tap="reviewPost(p.id, 0)"><text class="act-text">拒绝</text></view>
					<view class="act-btn act-approve" @tap="reviewPost(p.id, 1)"><text class="act-text">通过</text></view>
				</view>
			</view>
			<view class="list-end" v-if="!list.length"><text class="list-end-icon">✅</text><text class="list-end-text">没有待审核帖子</text></view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { request } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const list = ref([])
const page = ref(1)
const noMore = ref(false)

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function avColor(id) { return COLORS[id % COLORS.length] }
function fmtDate(d) { if (!d) return ''; return new Date(d).toLocaleDateString('zh-CN') }

async function loadData(reset) {
	if (reset) { page.value = 1; noMore.value = false }
	const res = await request({ url: '/admin/posts', data: { page: page.value, pageSize: 20, status: 2 } })
	if (res.code === 200) {
		const rows = res.data.list || res.data
		list.value = reset ? rows : [...list.value, ...rows]
		if (rows.length < 20) noMore.value = true
	}
}

function loadMore() { if (noMore.value) return; page.value++; loadData() }

async function reviewPost(id, status) {
	const res = await request({ url: '/admin/posts/' + id + '/status', method: 'PUT', data: { status } })
	if (res.code === 200) {
		list.value = list.value.filter(p => p.id !== id)
		uni.showToast({ title: status === 1 ? '已通过' : '已拒绝', icon: 'none' })
	}
}

function goBack() { uni.navigateBack() }
onMounted(() => loadData(true))
</script>

<style lang="scss" scoped>
.page-sub { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 28rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }
.pending-count { font-size: 24rpx; color: #ff2442; font-weight: 600; }

.list-scroll { height: calc(100vh - 140rpx); }
.list-inner { padding: 16rpx 28rpx; }
.review-card { background: #fff; border-radius: 12rpx; padding: 24rpx; margin-bottom: 16rpx; }
.card-head { display: flex; align-items: center; margin-bottom: 16rpx; }
.card-av { width: 64rpx; height: 64rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 16rpx; }
.av-text { font-size: 24rpx; color: #fff; font-weight: 600; }
.card-name { font-size: 26rpx; color: #333; font-weight: 500; display: block; }
.card-time { font-size: 22rpx; color: #ccc; display: block; margin-top: 2rpx; }
.card-body { margin-bottom: 20rpx; }
.card-title { font-size: 30rpx; color: #222; font-weight: 600; display: block; margin-bottom: 8rpx; }
.card-content { font-size: 26rpx; color: #666; line-height: 1.6; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 4; overflow: hidden; }
.card-actions { display: flex; gap: 16rpx; justify-content: flex-end; }
.act-btn { padding: 12rpx 40rpx; border-radius: 24rpx; transition: opacity .15s; }
.act-btn:active { opacity: 0.7; }
.act-reject { background: #fff0f0; }
.act-approve { background: #ff2442; }
.act-text { font-size: 26rpx; font-weight: 600; }
.act-reject .act-text { color: #ff2442; }
.act-approve .act-text { color: #fff; }
.list-end { display: flex; flex-direction: column; align-items: center; padding: 120rpx 0; }
.list-end-icon { font-size: 64rpx; }
.list-end-text { font-size: 26rpx; color: #ccc; margin-top: 16rpx; }
</style>
