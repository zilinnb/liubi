<template>
	<view class="page-new-chat">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">新对话</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<!-- Tab: 私聊 / 群聊 -->
		<view class="mode-tabs">
			<view class="mode-tab" :class="{ 'mode-on': mode === 'private' }" @tap="mode='private'">
				<text class="mode-text" :class="{ 'mode-text-on': mode === 'private' }">私聊</text>
			</view>
			<view class="mode-tab" :class="{ 'mode-on': mode === 'group' }" @tap="mode='group'">
				<text class="mode-text" :class="{ 'mode-text-on': mode === 'group' }">群聊</text>
			</view>
		</view>

		<!-- 私聊：搜索用户 -->
		<view v-if="mode === 'private'" class="private-section">
			<view class="search-box">
				<image class="search-icon" src="/static/icons/search.png" mode="aspectFit" />
				<input class="search-input" v-model="keyword" placeholder="搜索用户昵称或留笔号" confirm-type="search" @confirm="searchUsers" @input="onPrivateInput" />
				<view class="search-btn" v-if="keyword.trim()" @tap="searchUsers"><text class="search-btn-text">搜索</text></view>
			</view>
			<view class="user-list" v-if="searchResults.length">
				<view class="user-row" v-for="u in searchResults" :key="u.id" @tap="startPrivateChat(u)">
					<image v-if="u.avatar" class="user-av-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
					<view v-else class="user-av" :style="{ background: avColor(u.id) }">
						<text class="av-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
					</view>
					<view class="user-info">
						<text class="user-name">{{ u.nickname || u.username }}</text>
						<text class="user-id">留笔号：{{ u.username }}</text>
					</view>
					<view class="user-action">
						<text class="action-text">发消息</text>
					</view>
				</view>
			</view>
			<view class="empty-hint" v-else-if="searched && !searchResults.length">
				<text class="empty-text">未找到用户</text>
			</view>
			<view class="empty-hint" v-else>
				<text class="empty-text">输入昵称或留笔号搜索</text>
			</view>
		</view>

		<!-- 群聊：创建群 -->
		<view v-if="mode === 'group'" class="group-section">
			<view class="group-name-box">
				<text class="group-label">群名称</text>
				<input class="group-name-input" v-model="groupName" placeholder="请输入群名称" />
			</view>

			<view class="search-box">
				<image class="search-icon" src="/static/icons/search.png" mode="aspectFit" />
				<input class="search-input" v-model="groupKeyword" placeholder="搜索添加群成员" confirm-type="search" @confirm="searchGroupUsers" @input="onGroupInput" />
				<view class="search-btn" v-if="groupKeyword.trim()" @tap="searchGroupUsers"><text class="search-btn-text">搜索</text></view>
			</view>

			<!-- 已选成员 -->
			<view class="selected-area" v-if="selectedMembers.length">
				<scroll-view scroll-x class="selected-scroll" :show-scrollbar="false">
					<view class="selected-list">
						<view class="selected-item" v-for="u in selectedMembers" :key="u.id">
							<image v-if="u.avatar" class="sel-av-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
							<view v-else class="sel-av" :style="{ background: avColor(u.id) }">
								<text class="av-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
							</view>
							<text class="sel-name">{{ (u.nickname||u.username).slice(0,4) }}</text>
							<view class="sel-remove" @tap="removeMember(u.id)"><text class="remove-x">✕</text></view>
						</view>
					</view>
				</scroll-view>
			</view>

			<!-- 搜索结果 -->
			<view class="user-list" v-if="groupSearchResults.length">
				<view class="user-row" v-for="u in groupSearchResults" :key="u.id" @tap="toggleMember(u)">
					<image v-if="u.avatar" class="user-av-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
					<view v-else class="user-av" :style="{ background: avColor(u.id) }">
						<text class="av-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
					</view>
					<view class="user-info">
						<text class="user-name">{{ u.nickname || u.username }}</text>
						<text class="user-id">留笔号：{{ u.username }}</text>
					</view>
					<view class="check-box" :class="{ 'checked': isSelected(u.id) }">
						<text class="check-mark" v-if="isSelected(u.id)">✓</text>
					</view>
				</view>
			</view>
			<view class="empty-hint" v-else-if="groupSearched && !groupSearchResults.length">
				<text class="empty-text">未找到用户</text>
			</view>
			<view class="empty-hint" v-else>
				<text class="empty-text">搜索添加群成员</text>
			</view>

			<view class="create-btn-row">
				<view class="create-btn" :class="{ 'create-active': groupName.trim() && selectedMembers.length }" @tap="createGroup">
					<text class="create-text">创建群聊（{{ selectedMembers.length }}人）</text>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref } from 'vue'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL } from '@/utils/request.js'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const mode = ref('private')

// 私聊
const keyword = ref('')
const searchResults = ref([])
const searched = ref(false)

// 群聊
const groupName = ref('')
const groupKeyword = ref('')
const groupSearchResults = ref([])
const groupSearched = ref(false)
const selectedMembers = ref([])

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function avColor(id) { return COLORS[id % COLORS.length] }

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

let privateTimer = null
function onPrivateInput() {
	clearTimeout(privateTimer)
	privateTimer = setTimeout(() => {
		if (keyword.value.trim()) searchUsers()
	}, 500)
}

let groupTimer = null
function onGroupInput() {
	clearTimeout(groupTimer)
	groupTimer = setTimeout(() => {
		if (groupKeyword.value.trim()) searchGroupUsers()
	}, 500)
}

async function searchUsers() {
	if (!keyword.value.trim()) return
	const res = await request({ url: '/users/search?keyword=' + encodeURIComponent(keyword.value.trim()) })
	if (res.code === 200) {
		searchResults.value = (res.data || []).filter(u => u.id !== userStore.userInfo?.id)
	} else {
		searchResults.value = []
	}
	searched.value = true
}

async function startPrivateChat(u) {
	const res = await request({
		url: '/chat/conversation/private',
		method: 'POST',
		data: { user_id: u.id }
	})
	if (res.code === 200) {
		uni.redirectTo({ url: '/pages/chat/chat?conversationId=' + res.data.conversation_id })
	}
}

async function searchGroupUsers() {
	if (!groupKeyword.value.trim()) return
	const res = await request({ url: '/users/search?keyword=' + encodeURIComponent(groupKeyword.value.trim()) })
	if (res.code === 200) {
		groupSearchResults.value = (res.data || []).filter(u => u.id !== userStore.userInfo?.id)
	} else {
		groupSearchResults.value = []
	}
	groupSearched.value = true
}

function isSelected(id) { return selectedMembers.value.some(m => m.id === id) }

function toggleMember(u) {
	const idx = selectedMembers.value.findIndex(m => m.id === u.id)
	if (idx >= 0) {
		selectedMembers.value.splice(idx, 1)
	} else {
		selectedMembers.value.push(u)
	}
}

function removeMember(id) {
	selectedMembers.value = selectedMembers.value.filter(m => m.id !== id)
}

async function createGroup() {
	if (!groupName.value.trim()) return uni.showToast({ title: '请输入群名称', icon: 'none' })
	if (!selectedMembers.value.length) return uni.showToast({ title: '请选择成员', icon: 'none' })

	const res = await request({
		url: '/chat/conversation/group',
		method: 'POST',
		data: {
			name: groupName.value.trim(),
			member_ids: selectedMembers.value.map(m => m.id)
		}
	})
	if (res.code === 200) {
		uni.redirectTo({ url: '/pages/chat/chat?conversationId=' + res.data.conversation_id })
	} else {
		uni.showToast({ title: res.msg || '创建失败', icon: 'none' })
	}
}

function goBack() { uni.navigateBack() }
</script>

<style lang="scss" scoped>
.page-new-chat { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 20rpx; }
.nav-left { padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }

.mode-tabs { display: flex; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.mode-tab { flex: 1; display: flex; justify-content: center; padding: 24rpx 0 18rpx; position: relative; }
.mode-on::after { content: ''; position: absolute; bottom: 0; left: 50%; transform: translateX(-50%); width: 48rpx; height: 4rpx; background: #ff2442; border-radius: 2rpx; }
.mode-text { font-size: 28rpx; color: #999; }
.mode-text-on { color: #222; font-weight: 600; }

.search-box { display: flex; align-items: center; margin: 20rpx 24rpx; background: #f5f5f5; border-radius: 32rpx; padding: 0 20rpx; height: 64rpx; }
.search-icon { width: 28rpx; height: 28rpx; margin-right: 12rpx; flex-shrink: 0; }
.search-input { flex: 1; font-size: 26rpx; height: 64rpx; }
.search-btn { padding: 0 20rpx; height: 48rpx; background: #ff2442; border-radius: 24rpx; display: flex; align-items: center; justify-content: center; margin-left: 12rpx; flex-shrink: 0; }
.search-btn-text { font-size: 24rpx; color: #fff; font-weight: 500; }

.user-list { background: #fff; margin: 0 0 20rpx; }
.user-row { display: flex; align-items: center; padding: 20rpx 24rpx; border-bottom: 1rpx solid #f8f8f8; transition: background .15s; }
.user-row:active { background: #f8f8f8; }
.user-av { width: 72rpx; height: 72rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 20rpx; }
.user-av-img { width: 72rpx; height: 72rpx; border-radius: 50%; flex-shrink: 0; margin-right: 20rpx; }
.av-text { font-size: 26rpx; color: #fff; font-weight: 600; }
.user-info { flex: 1; overflow: hidden; }
.user-name { font-size: 28rpx; color: #222; font-weight: 500; display: block; }
.user-id { font-size: 22rpx; color: #999; display: block; margin-top: 4rpx; }
.user-action { padding: 8rpx 20rpx; background: #ff2442; border-radius: 20rpx; }
.action-text { font-size: 24rpx; color: #fff; }

.empty-hint { text-align: center; padding: 100rpx 0; }
.empty-text { font-size: 26rpx; color: #ccc; }

/* 群聊 */
.group-name-box { display: flex; align-items: center; padding: 20rpx 24rpx; background: #fff; margin-bottom: 2rpx; }
.group-label { font-size: 28rpx; color: #333; margin-right: 16rpx; flex-shrink: 0; }
.group-name-input { flex: 1; font-size: 26rpx; height: 56rpx; }

.selected-area { background: #fff; padding: 16rpx 24rpx; margin-bottom: 2rpx; }
.selected-scroll { white-space: nowrap; }
.selected-list { display: inline-flex; gap: 16rpx; }
.selected-item { display: flex; flex-direction: column; align-items: center; position: relative; }
.sel-av { width: 72rpx; height: 72rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.sel-av-img { width: 72rpx; height: 72rpx; border-radius: 50%; }
.sel-name { font-size: 20rpx; color: #666; margin-top: 6rpx; max-width: 80rpx; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sel-remove { position: absolute; top: -6rpx; right: -6rpx; width: 28rpx; height: 28rpx; border-radius: 50%; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; }
.remove-x { font-size: 16rpx; color: #fff; }

.check-box { width: 40rpx; height: 40rpx; border-radius: 50%; border: 2rpx solid #ddd; display: flex; align-items: center; justify-content: center; }
.checked { background: #ff2442; border-color: #ff2442; }
.check-mark { font-size: 22rpx; color: #fff; font-weight: 700; }

.create-btn-row { padding: 24rpx; }
.create-btn { height: 80rpx; border-radius: 40rpx; background: #e8e8e8; display: flex; align-items: center; justify-content: center; transition: background .2s; }
.create-active { background: #ff2442; }
.create-text { font-size: 28rpx; color: #fff; font-weight: 600; }
.create-btn:not(.create-active) .create-text { color: #999; }
</style>
