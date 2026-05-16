<template>
	<view class="page-admin">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">管理中心</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<view v-if="!isAdmin" class="no-auth">
			<view class="no-auth-icon-wrap">
				<text class="no-auth-icon-text">!</text>
			</view>
			<text class="no-auth-text">无权访问管理中心</text>
		</view>

		<scroll-view v-else scroll-y class="admin-body" :show-scrollbar="false">
			<view class="admin-body-inner">
			<view class="stat-cards">
				<view class="stat-card">
					<text class="stat-num">{{ stats.users }}</text>
					<text class="stat-label">用户</text>
				</view>
				<view class="stat-card">
					<text class="stat-num">{{ stats.posts }}</text>
					<text class="stat-label">帖子</text>
				</view>
				<view class="stat-card">
					<text class="stat-num">{{ stats.comments }}</text>
					<text class="stat-label">评论</text>
				</view>
				<view class="stat-card accent">
					<text class="stat-num">{{ stats.pending }}</text>
					<text class="stat-label">待审核</text>
				</view>
			</view>

			<view class="admin-section">
				<text class="section-title">内容管理</text>
				<view class="admin-item" @tap="go('/pages/admin/admin-users')">
					<view class="item-dot dot-blue"></view>
					<text class="item-label">用户管理</text>
					<text class="item-desc">{{ stats.users }}位用户</text>
					<text class="item-arrow">›</text>
				</view>
				<view class="admin-item" @tap="go('/pages/admin/admin-posts')">
					<view class="item-dot dot-green"></view>
					<text class="item-label">帖子管理</text>
					<text class="item-desc">{{ stats.posts }}篇</text>
					<text class="item-arrow">›</text>
				</view>
				<view class="admin-item" @tap="go('/pages/admin/admin-review')">
					<view class="item-dot dot-orange"></view>
					<text class="item-label">帖子审核</text>
					<view class="item-badge" v-if="stats.pending > 0"><text class="badge-num">{{ stats.pending }}</text></view>
					<text class="item-arrow">›</text>
				</view>
				<view class="admin-item" @tap="go('/pages/admin/admin-comments')">
					<view class="item-dot dot-purple"></view>
					<text class="item-label">评论管理</text>
					<text class="item-desc">{{ stats.comments }}条</text>
					<text class="item-arrow">›</text>
				</view>
				<view class="admin-item" @tap="go('/pages/admin/admin-categories')">
					<view class="item-dot dot-cyan"></view>
					<text class="item-label">分类管理</text>
					<text class="item-arrow">›</text>
				</view>
			</view>

			<view class="admin-section">
				<text class="section-title">会话管理</text>
				<view class="admin-item" @tap="go('/pages/admin/admin-chats')">
					<view class="item-dot dot-teal"></view>
					<text class="item-label">会话管理</text>
					<text class="item-arrow">›</text>
				</view>
			</view>

			<view class="admin-section">
				<text class="section-title">系统设置</text>
				<view class="admin-item" @tap="go('/pages/admin/admin-ai')">
					<view class="item-dot dot-violet"></view>
					<text class="item-label">AI 助手配置</text>
					<text class="item-arrow">›</text>
				</view>
				<view class="admin-item" @tap="go('/pages/admin/admin-email')">
					<view class="item-dot dot-amber"></view>
					<text class="item-label">邮箱设置</text>
					<text class="item-arrow">›</text>
				</view>
				<view class="admin-item" @tap="go('/pages/admin/admin-version')">
					<view class="item-dot dot-red"></view>
					<text class="item-label">版本管理</text>
					<text class="item-desc">远程更新</text>
					<text class="item-arrow">›</text>
				</view>
			</view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useUserStore } from '@/store/user.js'
import { request } from '@/utils/request.js'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const isAdmin = computed(() => userStore.userInfo?.role === 1)
const stats = ref({ users: 0, posts: 0, comments: 0, pending: 0 })

async function loadStats() {
	const res = await request({ url: '/admin/stats' })
	if (res.code === 200) stats.value = res.data
}

function go(url) { uni.navigateTo({ url }) }
function goBack() { uni.navigateBack() }

onMounted(() => { if (isAdmin.value) loadStats() })
</script>

<style lang="scss" scoped>
.page-admin { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 28rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }

.no-auth { display: flex; flex-direction: column; align-items: center; padding-top: 200rpx; }
.no-auth-icon-wrap { width: 80rpx; height: 80rpx; border-radius: 50%; background: #f0f0f0; display: flex; align-items: center; justify-content: center; }
.no-auth-icon-text { font-size: 40rpx; color: #ccc; font-weight: 700; }
.no-auth-text { font-size: 28rpx; color: #ccc; margin-top: 16rpx; }

.admin-body { height: calc(100vh - 44px - 40px); }
.admin-body-inner { padding: 20rpx 28rpx 40rpx; }

.stat-cards { display: flex; gap: 12rpx; margin-bottom: 24rpx; }
.stat-card { flex: 1; background: #fff; border-radius: 12rpx; padding: 24rpx 16rpx; text-align: center; box-shadow: 0 1rpx 4rpx rgba(0,0,0,0.04); }
.stat-num { font-size: 36rpx; font-weight: 700; color: #222; display: block; }
.stat-label { font-size: 22rpx; color: #999; display: block; margin-top: 6rpx; }
.accent { background: #fff0f0; }
.accent .stat-num { color: #ff2442; }

.admin-section { background: #fff; border-radius: 12rpx; margin-bottom: 16rpx; overflow: hidden; }
.section-title { font-size: 24rpx; color: #999; padding: 20rpx 24rpx 0; display: block; }
.admin-item { display: flex; align-items: center; padding: 28rpx 24rpx; border-bottom: 1rpx solid #f8f8f8; transition: background .15s; }
.admin-item:active { background: #f8f8f8; }
.admin-item:last-child { border-bottom: none; }
.item-dot { width: 16rpx; height: 16rpx; border-radius: 50%; margin-right: 16rpx; flex-shrink: 0; }
.dot-blue { background: #1890ff; }
.dot-green { background: #52c41a; }
.dot-orange { background: #faad14; }
.dot-purple { background: #722ed1; }
.dot-cyan { background: #13c2c2; }
.dot-teal { background: #20b2aa; }
.dot-amber { background: #fa8c16; }
.dot-red { background: #ff2442; }
.dot-violet { background: #9945FF; }
.item-label { flex: 1; font-size: 28rpx; color: #333; }
.item-desc { font-size: 24rpx; color: #ccc; margin-right: 8rpx; }
.item-arrow { font-size: 28rpx; color: #ccc; }
.item-badge { background: #ff2442; border-radius: 14rpx; min-width: 28rpx; height: 28rpx; display: flex; align-items: center; justify-content: center; padding: 0 8rpx; margin-right: 12rpx; }
.badge-num { font-size: 18rpx; color: #fff; font-weight: 600; }
</style>
