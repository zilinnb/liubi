<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">会话管理</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<view class="type-tabs">
			<view class="type-tab" :class="{ 'tab-on': chatType === 1 }" @tap="chatType=1; loadData(true)">
				<text class="tab-text" :class="{ 'tab-text-on': chatType === 1 }">私聊</text>
			</view>
			<view class="type-tab" :class="{ 'tab-on': chatType === 2 }" @tap="chatType=2; loadData(true)">
				<text class="tab-text" :class="{ 'tab-text-on': chatType === 2 }">群聊</text>
			</view>
		</view>

		<scroll-view scroll-y class="list-scroll" :show-scrollbar="false" @scrolltolower="loadMore">
			<view class="list-inner">
				<view class="chat-card" v-for="c in list" :key="c.id">
					<view class="chat-icon-box" :style="{ background: chatColor(c.id) }">
						<text class="chat-icon">{{ chatType === 2 ? '👥' : '💬' }}</text>
					</view>
					<view class="chat-info">
						<text class="chat-name" v-if="chatType === 2">{{ c.name || '群聊#' + c.id }}</text>
						<text class="chat-name" v-else>{{ c.members ? c.members.map(m => m.nickname || m.username).join(' & ') : '私聊#' + c.id }}</text>
						<text v-if="chatType === 2 && c.group_code" class="chat-code">群号：{{ c.group_code }}</text>
						<text class="chat-sub">{{ c.members ? c.members.length : 0 }}人 · {{ c.msg_count || 0 }}条消息</text>
						<text class="chat-msg" v-if="c.last_message">最近：{{ (c.last_message||'').slice(0, 30) }}</text>
					</view>
					<view class="chat-actions">
						<view v-if="chatType === 2" class="act-btn act-edit" @tap="editGroupCode(c)"><text class="act-text">编辑群号</text></view>
						<view class="act-btn act-del" @tap="deleteConv(c.id)"><text class="act-text">{{ chatType === 2 ? '解散' : '删除' }}</text></view>
					</view>
				</view>
				<view class="list-end" v-if="!list.length"><text class="list-end-text">暂无{{ chatType === 2 ? '群聊' : '私聊' }}会话</text></view>
			</view>
		</scroll-view>

		<!-- 编辑群号弹窗 -->
		<view v-if="showEditModal" class="modal-mask" @tap="showEditModal = false">
			<view class="modal-content" @tap.stop>
				<view class="modal-title">编辑群号</view>
				<input class="modal-input" v-model="editCode" placeholder="请输入群聊号" />
				<view class="modal-btns">
					<view class="modal-btn modal-btn-cancel" @tap="showEditModal = false">
						<text class="modal-btn-text">取消</text>
					</view>
					<view class="modal-btn modal-btn-confirm" @tap="saveGroupCode">
						<text class="modal-btn-text modal-btn-confirm-text">保存</text>
					</view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { request } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const chatType = ref(1)
const list = ref([])
const page = ref(1)
const noMore = ref(false)
const showEditModal = ref(false)
const editCode = ref('')
const editConvId = ref(null)

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function chatColor(id) { return COLORS[id % COLORS.length] }

async function loadData(reset) {
	if (reset) { page.value = 1; noMore.value = false }
	const res = await request({ url: '/admin/conversations', data: { type: chatType.value, page: page.value, pageSize: 30 } })
	if (res.code === 200) {
		const rows = res.data.list || res.data
		list.value = reset ? rows : [...list.value, ...rows]
		if (rows.length < 30) noMore.value = true
	}
}

function loadMore() { if (noMore.value) return; page.value++; loadData() }

function editGroupCode(c) {
	editConvId.value = c.id
	editCode.value = c.group_code || ''
	showEditModal.value = true
}

async function saveGroupCode() {
	if (!editCode.value.trim()) return uni.showToast({ title: '请输入群聊号', icon: 'none' })
	uni.showLoading({ title: '保存中...' })
	try {
		const res = await request({
			url: '/admin/conversations/' + editConvId.value + '/group-code',
			method: 'PUT',
			data: { group_code: editCode.value.trim() }
		})
		uni.hideLoading()
		if (res.code === 200) {
			showEditModal.value = false
			const idx = list.value.findIndex(c => c.id === editConvId.value)
			if (idx >= 0) list.value[idx].group_code = editCode.value.trim()
			uni.showToast({ title: '保存成功', icon: 'success' })
		} else {
			uni.showToast({ title: res.msg || '保存失败', icon: 'none' })
		}
	} catch (e) {
		uni.hideLoading()
		console.error('编辑群号失败:', e)
		uni.showToast({ title: e.message || '网络错误', icon: 'none' })
	}
}

async function deleteConv(id) {
	const label = chatType.value === 2 ? '解散' : '删除'
	uni.showModal({ title: '确认' + label, content: label + '后消息将全部清除', confirmColor: '#ff2442', success: async (r) => {
		if (r.confirm) {
			const res = await request({ url: '/admin/conversations/' + id, method: 'DELETE' })
			if (res.code === 200) { list.value = list.value.filter(c => c.id !== id); uni.showToast({ title: '已' + label, icon: 'none' }) }
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

.type-tabs { display: flex; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.type-tab { flex: 1; display: flex; justify-content: center; padding: 24rpx 0 18rpx; position: relative; }
.tab-on::after { content: ''; position: absolute; bottom: 0; left: 50%; transform: translateX(-50%); width: 48rpx; height: 4rpx; background: #ff2442; border-radius: 2rpx; }
.tab-text { font-size: 28rpx; color: #999; }
.tab-text-on { color: #222; font-weight: 600; }

.list-scroll { height: calc(100vh - 200rpx); }
.list-inner { padding: 16rpx 28rpx; }
.chat-card { display: flex; align-items: center; background: #fff; border-radius: 12rpx; padding: 24rpx; margin-bottom: 12rpx; }
.chat-icon-box { width: 72rpx; height: 72rpx; border-radius: 16rpx; display: flex; align-items: center; justify-content: center; margin-right: 20rpx; flex-shrink: 0; }
.chat-icon { font-size: 28rpx; }
.chat-info { flex: 1; overflow: hidden; }
.chat-name { font-size: 28rpx; color: #222; font-weight: 500; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.chat-code { font-size: 22rpx; color: #ff2442; display: block; margin-top: 4rpx; font-weight: 600; }
.chat-sub { font-size: 22rpx; color: #999; display: block; margin-top: 4rpx; }
.chat-msg { font-size: 22rpx; color: #bbb; display: block; margin-top: 4rpx; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.chat-actions { flex-shrink: 0; margin-left: 12rpx; display: flex; flex-direction: column; gap: 8rpx; }
.act-del { padding: 8rpx 20rpx; border-radius: 16rpx; background: #fff0f0; }
.act-edit { padding: 8rpx 20rpx; border-radius: 16rpx; background: #f0f5ff; }
.act-edit .act-text { color: #1890ff; }
.act-text { font-size: 24rpx; color: #ff2442; }
.list-end { padding: 40rpx 0; text-align: center; }
.list-end-text { font-size: 24rpx; color: #ccc; }

/* 弹窗 */
.modal-mask { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,.5); z-index: 9999; display: flex; align-items: center; justify-content: center; }
.modal-content { width: 80%; background: #fff; border-radius: 24rpx; padding: 40rpx 32rpx 32rpx; }
.modal-title { font-size: 34rpx; font-weight: 700; color: #222; text-align: center; margin-bottom: 32rpx; }
.modal-input { width: 100%; height: 80rpx; background: #f5f5f5; border-radius: 12rpx; padding: 0 24rpx; font-size: 30rpx; color: #222; margin-bottom: 32rpx; box-sizing: border-box; }
.modal-btns { display: flex; gap: 24rpx; }
.modal-btn { flex: 1; height: 80rpx; border-radius: 12rpx; display: flex; align-items: center; justify-content: center; }
.modal-btn-cancel { background: #f5f5f5; }
.modal-btn-confirm { background: #ff2442; }
.modal-btn-text { font-size: 30rpx; font-weight: 600; }
.modal-btn-cancel .modal-btn-text { color: #666; }
.modal-btn-confirm-text { color: #fff; }
</style>
