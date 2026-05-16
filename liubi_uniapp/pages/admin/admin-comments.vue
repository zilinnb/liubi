<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">评论管理</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="list-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="list-inner">
				<view class="comment-card" v-for="c in list" :key="c.id">
					<view class="comment-head">
						<view class="comment-av" :style="{ background: avColor(c.user_id) }">
							<text class="av-text">{{ (c.nickname||'?').slice(0,1) }}</text>
						</view>
						<view class="comment-meta">
							<text class="comment-name">{{ c.nickname || '用户' }}</text>
							<text class="comment-time">{{ fmtDate(c.created_at) }}</text>
						</view>
					</view>
					<text class="comment-text">{{ c.content }}</text>
					<image v-if="c.image_url" class="comment-img" :src="fullUrl(c.image_url)" mode="widthFix" />
					<view class="comment-footer">
						<text class="comment-post">帖子ID：{{ c.post_id }}</text>
						<view class="act-btn act-del" @tap="deleteComment(c.id)"><text class="act-text">删除</text></view>
					</view>
				</view>
				<view class="list-end" v-if="!list.length"><text class="list-end-text">暂无评论</text></view>
				<view class="list-end" v-else-if="noMore"><text class="list-end-text">～ 到底啦 ～</text></view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { request, BASE_URL } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const list = ref([])
const page = ref(1)
const noMore = ref(false)

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function avColor(id) { return COLORS[id % COLORS.length] }
function fmtDate(d) { if (!d) return ''; return new Date(d).toLocaleDateString('zh-CN') }
function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api','') + url }

async function loadData(reset) {
	if (reset) { page.value = 1; noMore.value = false }
	const res = await request({ url: '/admin/comments', data: { page: page.value, pageSize: 30 } })
	if (res.code === 200) {
		const rows = res.data.list || res.data
		list.value = reset ? rows : [...list.value, ...rows]
		if (rows.length < 30) noMore.value = true
	}
}

function loadMore() { if (noMore.value) return; page.value++; loadData() }

async function deleteComment(id) {
	uni.showModal({ title: '确认删除', content: '删除后不可恢复', confirmColor: '#ff2442', success: async (r) => {
		if (r.confirm) {
			const res = await request({ url: '/admin/comments/' + id, method: 'DELETE' })
			if (res.code === 200) { list.value = list.value.filter(c => c.id !== id); uni.showToast({ title: '已删除', icon: 'none' }) }
		}
	}})
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

.list-scroll { height: calc(100vh - 140rpx); }
.list-inner { padding: 16rpx 28rpx; }
.comment-card { background: #fff; border-radius: 12rpx; padding: 24rpx; margin-bottom: 12rpx; }
.comment-head { display: flex; align-items: center; margin-bottom: 12rpx; }
.comment-av { width: 56rpx; height: 56rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 14rpx; }
.av-text { font-size: 22rpx; color: #fff; font-weight: 600; }
.comment-meta { flex: 1; }
.comment-name { font-size: 26rpx; color: #333; font-weight: 500; display: block; }
.comment-time { font-size: 20rpx; color: #ccc; display: block; }
.comment-text { font-size: 28rpx; color: #333; line-height: 1.6; display: block; word-break: break-all; }
.comment-img { width: 300rpx; border-radius: 8rpx; margin-top: 12rpx; }
.comment-footer { display: flex; align-items: center; justify-content: space-between; margin-top: 16rpx; padding-top: 12rpx; border-top: 1rpx solid #f8f8f8; }
.comment-post { font-size: 22rpx; color: #999; }
.act-del { padding: 6rpx 20rpx; border-radius: 16rpx; background: #fff0f0; }
.act-text { font-size: 22rpx; color: #ff2442; }
.list-end { padding: 40rpx 0; text-align: center; }
.list-end-text { font-size: 24rpx; color: #ccc; }
</style>
