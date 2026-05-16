<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">用户管理</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<view class="search-bar">
			<view class="search-inner">
				<image class="search-icon" src="/static/icons/search.png" mode="aspectFit" />
				<input class="search-input" v-model="keyword" placeholder="搜索昵称或留笔号" confirm-type="search" @confirm="loadData(true)" />
			</view>
		</view>

		<scroll-view scroll-y class="list-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="list-inner">
			<view class="user-card" v-for="u in list" :key="u.id" @tap="showDetail(u)">
				<image v-if="u.avatar" class="user-av-img" :src="fullUrl(u.avatar)" mode="aspectFill" />
				<view v-else class="user-av" :style="{ background: avColor(u.id) }">
					<text class="av-text">{{ (u.nickname||u.username||'?').slice(0,1) }}</text>
				</view>
				<view class="user-main">
					<view class="user-top">
						<text class="user-name">{{ u.nickname || u.username }}</text>
						<view class="status-tag" :class="statusClass(u)">
							<text class="status-text">{{ statusLabel(u) }}</text>
						</view>
					</view>
					<text class="user-id">留笔号：{{ u.username }}</text>
					<text class="user-email" v-if="u.email">{{ u.email }}</text>
					<view class="user-stats">
						<text class="stat-item">粉丝 {{ u.fans_count||0 }}</text>
						<text class="stat-item">关注 {{ u.follow_count||0 }}</text>
						<text class="stat-item">获赞 {{ u.like_count||0 }}</text>
					</view>
				</view>
			</view>
			<view class="list-end" v-if="!list.length"><text class="list-end-text">暂无用户</text></view>
			<view class="list-end" v-else-if="noMore"><text class="list-end-text">～ 到底啦 ～</text></view>
			</view>
		</scroll-view>

		<view class="overlay" v-if="showModal" @tap="showModal=false">
			<view class="detail-modal" @tap.stop>
				<view class="modal-head">
					<image v-if="detail.avatar" class="modal-av-img" :src="fullUrl(detail.avatar)" mode="aspectFill" />
					<view v-else class="modal-av" :style="{ background: avColor(detail.id) }">
						<text class="modal-av-text">{{ (detail.nickname||detail.username||'?').slice(0,1) }}</text>
					</view>
					<view class="modal-name-area">
						<text class="modal-name">{{ detail.nickname || detail.username }}</text>
						<text class="modal-id">留笔号：{{ detail.username }}</text>
					</view>
				</view>
				<view class="modal-info">
					<view class="info-row"><text class="info-label">邮箱</text><text class="info-value">{{ detail.email || '未绑定' }}</text></view>
					<view class="info-row"><text class="info-label">简介</text><text class="info-value">{{ detail.bio || '无' }}</text></view>
					<view class="info-row">
						<text class="info-label">状态</text>
						<text class="info-value" :style="{ color: detail.status === 1 ? '#52c41a' : '#ff2442' }">{{ statusLabel(detail) }}</text>
					</view>
					<view class="info-row" v-if="detail.mute_until">
						<text class="info-label">禁言至</text>
						<text class="info-value" style="color:#faad14">{{ fmtDate(detail.mute_until) }}</text>
					</view>
					<view class="info-row"><text class="info-label">粉丝</text><text class="info-value">{{ detail.fans_count||0 }}</text></view>
					<view class="info-row"><text class="info-label">关注</text><text class="info-value">{{ detail.follow_count||0 }}</text></view>
					<view class="info-row"><text class="info-label">获赞</text><text class="info-value">{{ detail.like_count||0 }}</text></view>
					<view class="info-row"><text class="info-label">注册</text><text class="info-value">{{ fmtDate(detail.created_at) }}</text></view>
				</view>
				<view class="modal-actions">
					<view class="act-row">
						<view class="modal-act-btn btn-edit" @tap="showEdit(detail)"><text class="modal-act-text">编辑信息</text></view>
						<view class="modal-act-btn" :class="detail.status===1?'btn-ban':'btn-ok'" @tap="toggleStatus">
							<text class="modal-act-text">{{ detail.status === 1 ? '封禁账号' : '解封账号' }}</text>
						</view>
					</view>
					<view class="act-row">
						<view class="modal-act-btn btn-mute" @tap="showMutePanel=true">
							<text class="modal-act-text">{{ detail.mute_until ? '修改禁言' : '禁言用户' }}</text>
						</view>
						<view class="modal-act-btn btn-unmute" v-if="detail.mute_until" @tap="unmuteUser">
							<text class="modal-act-text">解除禁言</text>
						</view>
					</view>
				</view>
				<view class="modal-close" @tap="showModal=false"><text class="modal-close-text">关闭</text></view>
			</view>
		</view>

		<view class="overlay" v-if="showEditPanel" @tap="showEditPanel=false">
			<view class="edit-modal" @tap.stop>
				<view class="edit-head"><text class="edit-title">编辑用户信息</text></view>
				<view class="edit-field">
					<text class="edit-label">昵称</text>
					<input class="edit-input" v-model="editForm.nickname" placeholder="输入昵称" />
				</view>
				<view class="edit-field">
					<text class="edit-label">邮箱</text>
					<input class="edit-input" v-model="editForm.email" placeholder="输入邮箱" />
				</view>
				<view class="edit-field">
					<text class="edit-label">简介</text>
					<input class="edit-input" v-model="editForm.bio" placeholder="输入简介" />
				</view>
				<view class="edit-field">
					<text class="edit-label">角色</text>
					<view class="edit-role">
						<view class="role-opt" :class="{ 'role-on': editForm.role === 0 }" @tap="editForm.role = 0">
							<text class="role-text" :class="{ 'role-text-on': editForm.role === 0 }">普通用户</text>
						</view>
						<view class="role-opt" :class="{ 'role-on': editForm.role === 1 }" @tap="editForm.role = 1">
							<text class="role-text" :class="{ 'role-text-on': editForm.role === 1 }">管理员</text>
						</view>
					</view>
				</view>
				<view class="edit-btns">
					<view class="edit-cancel" @tap="showEditPanel=false"><text class="edit-cancel-text">取消</text></view>
					<view class="edit-confirm" @tap="saveEdit"><text class="edit-confirm-text">保存</text></view>
				</view>
			</view>
		</view>

		<view class="overlay" v-if="showMutePanel" @tap="showMutePanel=false">
			<view class="mute-modal" @tap.stop>
				<view class="mute-head"><text class="mute-title">禁言用户</text></view>
				<text class="mute-hint">选择禁言时长，到期后自动解除</text>
				<view class="mute-options">
					<view class="mute-opt" :class="{ 'mute-on': muteDays === 1 }" @tap="muteDays=1">
						<text class="mute-opt-text" :class="{ 'mute-opt-on': muteDays === 1 }">1天</text>
					</view>
					<view class="mute-opt" :class="{ 'mute-on': muteDays === 3 }" @tap="muteDays=3">
						<text class="mute-opt-text" :class="{ 'mute-opt-on': muteDays === 3 }">3天</text>
					</view>
					<view class="mute-opt" :class="{ 'mute-on': muteDays === 7 }" @tap="muteDays=7">
						<text class="mute-opt-text" :class="{ 'mute-opt-on': muteDays === 7 }">7天</text>
					</view>
					<view class="mute-opt" :class="{ 'mute-on': muteDays === 30 }" @tap="muteDays=30">
						<text class="mute-opt-text" :class="{ 'mute-opt-on': muteDays === 30 }">30天</text>
					</view>
					<view class="mute-opt" :class="{ 'mute-on': muteDays === 365 }" @tap="muteDays=365">
						<text class="mute-opt-text" :class="{ 'mute-opt-on': muteDays === 365 }">永久</text>
					</view>
				</view>
				<view class="mute-btns">
					<view class="mute-cancel" @tap="showMutePanel=false"><text class="mute-cancel-text">取消</text></view>
					<view class="mute-confirm" @tap="muteUser"><text class="mute-confirm-text">确认禁言</text></view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { request, BASE_URL } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const keyword = ref('')
const list = ref([])
const page = ref(1)
const noMore = ref(false)
const showModal = ref(false)
const showEditPanel = ref(false)
const showMutePanel = ref(false)
const detail = ref({})
const editForm = reactive({ nickname: '', email: '', bio: '', role: 0 })
const muteDays = ref(1)

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function avColor(id) { return COLORS[id % COLORS.length] }
function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api','') + url }
function fmtDate(d) { if (!d) return ''; return new Date(d).toLocaleDateString('zh-CN') }

function statusLabel(u) {
	if (u.status === 0) return '已封禁'
	if (u.mute_until && new Date(u.mute_until) > new Date()) return '禁言中'
	return '正常'
}
function statusClass(u) {
	if (u.status === 0) return 'tag-ban'
	if (u.mute_until && new Date(u.mute_until) > new Date()) return 'tag-mute'
	return 'tag-ok'
}

async function loadData(reset) {
	if (reset) { page.value = 1; noMore.value = false }
	const res = await request({ url: '/admin/users', data: { page: page.value, pageSize: 30, keyword: keyword.value || undefined } })
	if (res.code === 200) {
		const rows = res.data.list || res.data
		list.value = reset ? rows : [...list.value, ...rows]
		if (rows.length < 30) noMore.value = true
	}
}

function loadMore() {
	if (noMore.value) return
	page.value++
	loadData()
}

async function toggleStatus() {
	const newStatus = detail.value.status === 1 ? 0 : 1
	const action = newStatus === 0 ? '封禁' : '解封'
	uni.showModal({
		title: '确认操作',
		content: `确定要${action}用户「${detail.value.nickname || detail.value.username}」吗？`,
		confirmColor: '#ff2442',
		success: async (r) => {
			if (!r.confirm) return
			const res = await request({ url: '/admin/users/' + detail.value.id + '/status', method: 'PUT', data: { status: newStatus } })
			if (res.code === 200) {
				detail.value.status = newStatus
				const idx = list.value.findIndex(u => u.id === detail.value.id)
				if (idx >= 0) list.value[idx].status = newStatus
				uni.showToast({ title: `${action}成功`, icon: 'none' })
			}
		}
	})
}

function showDetail(u) {
	detail.value = { ...u }
	showModal.value = true
}

function showEdit(u) {
	editForm.nickname = u.nickname || ''
	editForm.email = u.email || ''
	editForm.bio = u.bio || ''
	editForm.role = u.role || 0
	showEditPanel.value = true
}

async function saveEdit() {
	const res = await request({
		url: '/admin/users/' + detail.value.id,
		method: 'PUT',
		data: { nickname: editForm.nickname, email: editForm.email, bio: editForm.bio, role: editForm.role }
	})
	if (res.code === 200) {
		detail.value.nickname = editForm.nickname
		detail.value.email = editForm.email
		detail.value.bio = editForm.bio
		detail.value.role = editForm.role
		const idx = list.value.findIndex(u => u.id === detail.value.id)
		if (idx >= 0) {
			list.value[idx].nickname = editForm.nickname
			list.value[idx].email = editForm.email
			list.value[idx].role = editForm.role
		}
		showEditPanel.value = false
		uni.showToast({ title: '保存成功', icon: 'none' })
	}
}

async function muteUser() {
	const until = new Date(Date.now() + muteDays.value * 86400000).toISOString().slice(0, 19).replace('T', ' ')
	const res = await request({
		url: '/admin/users/' + detail.value.id + '/mute',
		method: 'PUT',
		data: { mute_until: until }
	})
	if (res.code === 200) {
		detail.value.mute_until = until
		const idx = list.value.findIndex(u => u.id === detail.value.id)
		if (idx >= 0) list.value[idx].mute_until = until
		showMutePanel.value = false
		uni.showToast({ title: '禁言成功', icon: 'none' })
	}
}

async function unmuteUser() {
	const res = await request({
		url: '/admin/users/' + detail.value.id + '/mute',
		method: 'PUT',
		data: { mute_until: null }
	})
	if (res.code === 200) {
		detail.value.mute_until = null
		const idx = list.value.findIndex(u => u.id === detail.value.id)
		if (idx >= 0) list.value[idx].mute_until = null
		uni.showToast({ title: '已解除禁言', icon: 'none' })
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

.search-bar { padding: 16rpx 28rpx; background: #fff; }
.search-inner { display: flex; align-items: center; background: #f5f5f5; border-radius: 28rpx; padding: 0 20rpx; height: 60rpx; }
.search-icon { width: 28rpx; height: 28rpx; margin-right: 10rpx; flex-shrink: 0; }
.search-input { flex: 1; font-size: 24rpx; height: 60rpx; }

.list-scroll { height: calc(100vh - 180rpx); }
.list-inner { padding: 12rpx 28rpx; }
.user-card { display: flex; align-items: center; background: #fff; border-radius: 12rpx; padding: 24rpx; margin-bottom: 12rpx; }
.user-av { width: 80rpx; height: 80rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 20rpx; }
.user-av-img { width: 80rpx; height: 80rpx; border-radius: 50%; flex-shrink: 0; margin-right: 20rpx; }
.av-text { font-size: 28rpx; color: #fff; font-weight: 600; }
.user-main { flex: 1; overflow: hidden; }
.user-top { display: flex; align-items: center; gap: 10rpx; }
.user-name { font-size: 28rpx; color: #222; font-weight: 500; }
.status-tag { padding: 2rpx 12rpx; border-radius: 10rpx; }
.tag-ok { background: #e8f8e8; }
.tag-ban { background: #fff0f0; }
.tag-mute { background: #fff7e6; }
.status-text { font-size: 20rpx; font-weight: 600; }
.tag-ok .status-text { color: #52c41a; }
.tag-ban .status-text { color: #ff2442; }
.tag-mute .status-text { color: #faad14; }
.user-id { font-size: 22rpx; color: #999; display: block; margin-top: 4rpx; }
.user-email { font-size: 22rpx; color: #bbb; display: block; margin-top: 2rpx; }
.user-stats { display: flex; gap: 16rpx; margin-top: 6rpx; }
.stat-item { font-size: 20rpx; color: #999; }
.list-end { padding: 40rpx 0; text-align: center; }
.list-end-text { font-size: 24rpx; color: #ccc; }

.overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.4); z-index: 1000; display: flex; align-items: center; justify-content: center; animation: fadeIn .2s; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

.detail-modal { width: 660rpx; background: #fff; border-radius: 20rpx; padding: 36rpx 32rpx; animation: scaleIn .25s ease; max-height: 85vh; overflow-y: auto; }
@keyframes scaleIn { from { transform: scale(0.9); opacity: 0; } to { transform: scale(1); opacity: 1; } }
.modal-head { display: flex; align-items: center; margin-bottom: 24rpx; padding-bottom: 20rpx; border-bottom: 1rpx solid #f0f0f0; }
.modal-av { width: 80rpx; height: 80rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 20rpx; }
.modal-av-img { width: 80rpx; height: 80rpx; border-radius: 50%; margin-right: 20rpx; }
.modal-av-text { font-size: 28rpx; color: #fff; font-weight: 600; }
.modal-name { font-size: 32rpx; font-weight: 600; color: #222; display: block; }
.modal-id { font-size: 22rpx; color: #999; display: block; margin-top: 4rpx; }
.modal-info { margin-bottom: 20rpx; }
.info-row { display: flex; justify-content: space-between; padding: 12rpx 0; border-bottom: 1rpx solid #f8f8f8; }
.info-label { font-size: 26rpx; color: #999; }
.info-value { font-size: 26rpx; color: #333; }

.modal-actions { margin-bottom: 16rpx; }
.act-row { display: flex; gap: 16rpx; margin-bottom: 16rpx; }
.modal-act-btn { flex: 1; height: 72rpx; border-radius: 36rpx; display: flex; align-items: center; justify-content: center; }
.modal-act-text { font-size: 26rpx; font-weight: 600; }
.btn-edit { background: #e6f7ff; }
.btn-edit .modal-act-text { color: #1890ff; }
.btn-ban { background: #fff0f0; }
.btn-ban .modal-act-text { color: #ff2442; }
.btn-ok { background: #e8f8e8; }
.btn-ok .modal-act-text { color: #52c41a; }
.btn-mute { background: #fff7e6; }
.btn-mute .modal-act-text { color: #faad14; }
.btn-unmute { background: #f5f5f5; }
.btn-unmute .modal-act-text { color: #666; }
.modal-close { height: 72rpx; border-radius: 36rpx; background: #f5f5f5; display: flex; align-items: center; justify-content: center; }
.modal-close-text { font-size: 28rpx; color: #666; }

.edit-modal { width: 620rpx; background: #fff; border-radius: 20rpx; padding: 36rpx 32rpx; animation: scaleIn .25s ease; }
.edit-head { margin-bottom: 24rpx; }
.edit-title { font-size: 30rpx; font-weight: 600; color: #222; }
.edit-field { margin-bottom: 20rpx; }
.edit-label { font-size: 24rpx; color: #999; display: block; margin-bottom: 8rpx; }
.edit-input { width: 100%; height: 72rpx; background: #f5f5f5; border-radius: 12rpx; padding: 0 20rpx; font-size: 28rpx; box-sizing: border-box; }
.edit-role { display: flex; gap: 16rpx; }
.role-opt { flex: 1; height: 64rpx; border-radius: 12rpx; background: #f5f5f5; display: flex; align-items: center; justify-content: center; border: 2rpx solid transparent; }
.role-on { border-color: #ff2442; background: #fff0f0; }
.role-text { font-size: 26rpx; color: #999; }
.role-text-on { color: #ff2442; font-weight: 600; }
.edit-btns { display: flex; gap: 16rpx; margin-top: 28rpx; }
.edit-cancel { flex: 1; height: 72rpx; border-radius: 36rpx; background: #f5f5f5; display: flex; align-items: center; justify-content: center; }
.edit-cancel-text { font-size: 28rpx; color: #666; }
.edit-confirm { flex: 1; height: 72rpx; border-radius: 36rpx; background: #ff2442; display: flex; align-items: center; justify-content: center; }
.edit-confirm-text { font-size: 28rpx; color: #fff; font-weight: 600; }

.mute-modal { width: 620rpx; background: #fff; border-radius: 20rpx; padding: 36rpx 32rpx; animation: scaleIn .25s ease; }
.mute-head { margin-bottom: 8rpx; }
.mute-title { font-size: 30rpx; font-weight: 600; color: #222; }
.mute-hint { font-size: 24rpx; color: #999; display: block; margin-bottom: 24rpx; }
.mute-options { display: flex; flex-wrap: wrap; gap: 16rpx; margin-bottom: 28rpx; }
.mute-opt { padding: 16rpx 32rpx; border-radius: 28rpx; background: #f5f5f5; border: 2rpx solid transparent; }
.mute-on { border-color: #faad14; background: #fff7e6; }
.mute-opt-text { font-size: 26rpx; color: #666; }
.mute-opt-on { color: #faad14; font-weight: 600; }
.mute-btns { display: flex; gap: 16rpx; }
.mute-cancel { flex: 1; height: 72rpx; border-radius: 36rpx; background: #f5f5f5; display: flex; align-items: center; justify-content: center; }
.mute-cancel-text { font-size: 28rpx; color: #666; }
.mute-confirm { flex: 1; height: 72rpx; border-radius: 36rpx; background: #faad14; display: flex; align-items: center; justify-content: center; }
.mute-confirm-text { font-size: 28rpx; color: #fff; font-weight: 600; }
</style>
