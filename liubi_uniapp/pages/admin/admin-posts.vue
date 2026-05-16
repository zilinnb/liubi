<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">帖子管理</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<!-- 状态筛选 -->
		<view class="filter-bar">
			<view class="filter-chip" :class="{ 'chip-on': filter === '' }" @tap="filter=''"><text class="chip-text" :class="{ 'chip-text-on': filter === '' }">全部</text></view>
			<view class="filter-chip" :class="{ 'chip-on': filter === '1' }" @tap="filter='1'"><text class="chip-text" :class="{ 'chip-text-on': filter === '1' }">正常</text></view>
			<view class="filter-chip" :class="{ 'chip-on': filter === '2' }" @tap="filter='2'"><text class="chip-text" :class="{ 'chip-text-on': filter === '2' }">审核中</text></view>
			<view class="filter-chip" :class="{ 'chip-on': filter === '0' }" @tap="filter='0'"><text class="chip-text" :class="{ 'chip-text-on': filter === '0' }">已下架</text></view>
		</view>

		<scroll-view scroll-y class="list-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="list-inner">
			<view class="post-card" v-for="p in list" :key="p.id" @tap="goDetail(p.id)">
				<view class="post-cover" v-if="p.images && p.images.length">
					<image class="post-img" :src="fullUrl(p.images[0])" mode="aspectFill" />
				</view>
				<view class="post-text-cover" v-else :style="{ background: cardBg(p.id) }">
					<text class="post-preview">{{ (p.content||'').slice(0, 60) }}</text>
				</view>
				<view class="post-info">
					<view class="post-title-row">
						<text class="post-title">{{ p.title }}</text>
						<view class="status-tag" :class="statusClass(p.status)">
							<text class="status-text">{{ statusLabel(p.status) }}</text>
						</view>
					</view>
					<text class="post-author">by {{ p.nickname || p.username || '未知' }}</text>
					<view class="post-stats">
						<text class="stat-item">👁 {{ p.views_count||0 }}</text>
						<text class="stat-item">♡ {{ p.likes_count||0 }}</text>
						<text class="stat-item">⭐ {{ p.collects_count||0 }}</text>
						<text class="stat-item">💬 {{ p.comments_count||0 }}</text>
					</view>
				</view>
				<view class="post-actions">
					<view class="act-btn" :class="p.status === 1 ? 'act-ban' : 'act-ok'" @tap.stop="togglePost(p)" v-if="p.status !== 2">
						<text class="act-text">{{ p.status === 1 ? '下架' : '上架' }}</text>
					</view>
					<view class="act-btn act-del" @tap.stop="deletePost(p.id)"><text class="act-text">删除</text></view>
				</view>
			</view>
			<view class="list-end" v-if="!list.length"><text class="list-end-text">暂无帖子</text></view>
			<view class="list-end" v-else-if="noMore"><text class="list-end-text">～ 到底啦 ～</text></view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { request, BASE_URL } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const filter = ref('')
const list = ref([])
const page = ref(1)
const noMore = ref(false)

const BG_LIST = ['linear-gradient(135deg,#fff5f5,#ffe8e8)','linear-gradient(135deg,#f0f5ff,#e0eaff)','linear-gradient(135deg,#f0fff4,#d9f7be)','linear-gradient(135deg,#fff7e6,#ffe7ba)','linear-gradient(135deg,#f9f0ff,#efdbff)','linear-gradient(135deg,#e6fffb,#b5f5ec)']
function cardBg(id) { return BG_LIST[id % BG_LIST.length] }
function fullUrl(url) { if (!url) return ''; if (typeof url === 'object') url = url.url || ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api','') + url }
function statusLabel(s) { return s === 1 ? '正常' : s === 2 ? '审核中' : '已下架' }
function statusClass(s) { return s === 1 ? 'tag-ok' : s === 2 ? 'tag-pending' : 'tag-ban' }

async function loadData(reset) {
	if (reset) { page.value = 1; noMore.value = false }
	const data = { page: page.value, pageSize: 20 }
	if (filter.value !== '') data.status = filter.value
	const res = await request({ url: '/admin/posts', data })
	if (res.code === 200) {
		const rows = res.data.list || res.data
		list.value = reset ? rows : [...list.value, ...rows]
		if (rows.length < 20) noMore.value = true
	}
}

function loadMore() { if (noMore.value) return; page.value++; loadData() }
watch(filter, () => loadData(true))

async function togglePost(p) {
	const newStatus = p.status === 1 ? 0 : 1
	const res = await request({ url: '/admin/posts/' + p.id + '/status', method: 'PUT', data: { status: newStatus } })
	if (res.code === 200) { p.status = newStatus; uni.showToast({ title: newStatus === 1 ? '已上架' : '已下架', icon: 'none' }) }
}

async function deletePost(id) {
	uni.showModal({ title: '确认删除', content: '删除后不可恢复', confirmColor: '#ff2442', success: async (r) => {
		if (r.confirm) {
			const res = await request({ url: '/admin/posts/' + id, method: 'DELETE' })
			if (res.code === 200) { loadData(true); uni.showToast({ title: '已删除', icon: 'none' }) }
		}
	}})
}

function goDetail(id) { uni.navigateTo({ url: '/pages/detail/detail?id=' + id }) }
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

.filter-bar { display: flex; gap: 12rpx; padding: 16rpx 24rpx; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.filter-chip { padding: 8rpx 24rpx; border-radius: 20rpx; background: #f5f5f5; transition: background .2s; }
.chip-on { background: #ff2442; }
.chip-text { font-size: 24rpx; color: #666; }
.chip-text-on { color: #fff; font-weight: 600; }

.list-scroll { height: calc(100vh - 180rpx); }
.list-inner { padding: 12rpx 28rpx; }
.post-card { background: #fff; border-radius: 12rpx; overflow: hidden; margin-bottom: 16rpx; }
.post-cover { height: 300rpx; }
.post-img { width: 100%; height: 100%; }
.post-text-cover { height: 160rpx; padding: 20rpx; display: flex; align-items: center; }
.post-preview { font-size: 24rpx; color: #888; line-height: 1.6; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 4; overflow: hidden; }
.post-info { padding: 16rpx 20rpx; }
.post-title-row { display: flex; align-items: center; justify-content: space-between; }
.post-title { font-size: 28rpx; color: #222; font-weight: 500; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.status-tag { padding: 2rpx 12rpx; border-radius: 10rpx; flex-shrink: 0; margin-left: 12rpx; }
.tag-ok { background: #e8f8e8; }
.tag-pending { background: #fff7e6; }
.tag-ban { background: #fff0f0; }
.status-text { font-size: 20rpx; font-weight: 600; }
.tag-ok .status-text { color: #52c41a; }
.tag-pending .status-text { color: #faad14; }
.tag-ban .status-text { color: #ff2442; }
.post-author { font-size: 22rpx; color: #999; display: block; margin-top: 6rpx; }
.post-stats { display: flex; gap: 16rpx; margin-top: 8rpx; }
.stat-item { font-size: 22rpx; color: #bbb; }
.post-actions { display: flex; gap: 12rpx; padding: 0 20rpx 16rpx; }
.act-btn { padding: 8rpx 24rpx; border-radius: 16rpx; }
.act-ban { background: #fff0f0; }
.act-ok { background: #e8f8e8; }
.act-del { background: #f5f5f5; }
.act-text { font-size: 24rpx; }
.act-ban .act-text { color: #ff2442; }
.act-ok .act-text { color: #52c41a; }
.act-del .act-text { color: #999; }
.list-end { padding: 40rpx 0; text-align: center; }
.list-end-text { font-size: 24rpx; color: #ccc; }
</style>
