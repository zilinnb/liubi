<template>
	<view class="page-msg">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<text class="nav-title">消息</text>
				<view class="nav-right">
					<view class="nav-icon" @tap="onNewChat"><text class="add-text">+</text></view>
					<view v-if="isAdmin" class="nav-icon" @tap="showGroupActions"><text class="add-text">群</text></view>
				</view>
			</view>
		</view>

		<scroll-view
			scroll-y
			class="main-scroll"
			:show-scrollbar="false"
			@scroll="onScroll"
			:scroll-top="scrollTopVal"
		>
			<view :style="{ height: navBarH + 'px' }"></view>

			<view v-if="!userStore.isLoggedIn" class="empty-box">
				<view class="empty-illustration"><text class="empty-icon-text">留笔</text></view>
				<text class="empty-hint">登录后查看消息</text>
				<view class="login-btn" @tap="goLogin"><text class="login-btn-text">去登录</text></view>
			</view>

			<view v-else class="msg-body">
				<view class="notify-row">
					<view class="notify-card" @tap="goNotify('1,6')">
						<view class="card-icon like-bg">
							<image class="card-icon-img" src="/static/icons/dianzan.png" mode="aspectFit" />
							<view class="card-badge" v-if="unread.like > 0">
								<text class="badge-num">{{ unread.like > 99 ? '99+' : unread.like }}</text>
							</view>
						</view>
						<text class="card-label">赞和收藏</text>
					</view>
					<view class="notify-card" @tap="goNotify('3')">
						<view class="card-icon follow-bg">
							<image class="card-icon-img" src="/static/icons/guanzhu_1.png" mode="aspectFit" />
							<view class="card-badge" v-if="unread.follow > 0">
								<text class="badge-num">{{ unread.follow > 99 ? '99+' : unread.follow }}</text>
							</view>
						</view>
						<text class="card-label">新增关注</text>
					</view>
					<view class="notify-card" @tap="goNotify('2,5')">
						<view class="card-icon comment-bg">
							<image class="card-icon-img" src="/static/icons/pinglun.png" mode="aspectFit" />
							<view class="card-badge" v-if="unread.comment > 0">
								<text class="badge-num">{{ unread.comment > 99 ? '99+' : unread.comment }}</text>
							</view>
						</view>
						<text class="card-label">评论和@</text>
					</view>
				</view>

				<view class="ai-pinned" @tap="goAiChat">
					<view class="ai-pinned-avatar">
						<text class="ai-av-letter">Ai</text>
					</view>
					<view class="ai-pinned-content">
						<view class="ai-pinned-header">
							<text class="ai-pinned-name">AI 助手</text>
							<view class="ai-pinned-tag"><text class="ai-tag-text">智能</text></view>
						</view>
						<text class="ai-pinned-desc">随时为你解答问题、创作内容</text>
					</view>
					<view class="ai-pinned-arrow">
						<text class="arrow-text">›</text>
					</view>
				</view>

				<view v-if="conversations.length" class="conv-list">
					<view class="conv-row" v-for="c in conversations" :key="c.id" @tap="goChat(c)">
						<view v-if="c.type === 1" class="conv-avatar-wrap">
							<view class="conv-avatar" :style="{ background: convColor(c) }">
								<image v-if="convAvatar(c)" class="avatar-img" :src="fullUrl(convAvatar(c))" mode="aspectFill" />
								<text v-else class="avatar-text">{{ (c.name||'私').slice(0,1) }}</text>
							</view>
							<view class="conv-unread" v-if="c.unread_count > 0">
								<text class="conv-unread-num">{{ c.unread_count > 99 ? '99+' : c.unread_count }}</text>
							</view>
						</view>
						<view v-else class="conv-avatar-wrap">
							<view class="conv-avatar-group">
								<view class="group-grid">
									<view class="grid-cell" v-for="(item, idx) in groupAvatars(c)" :key="idx">
										<image v-if="item.avatar" class="grid-av-img" :src="fullUrl(item.avatar)" mode="aspectFill" />
										<view v-else class="grid-av-placeholder" :style="{ background: item.color }">
											<text class="grid-av-text">{{ (item.name||'用').slice(0,1) }}</text>
										</view>
									</view>
								</view>
							</view>
							<view class="conv-unread" v-if="c.unread_count > 0">
								<text class="conv-unread-num">{{ c.unread_count > 99 ? '99+' : c.unread_count }}</text>
							</view>
						</view>
						<view class="conv-content">
							<view class="conv-header">
								<view class="conv-name-wrap">
									<text class="conv-name">{{ c.name || '私聊' }}</text>
									<text v-if="c.type === 2" class="group-tag">群聊</text>
								</view>
								<text class="conv-time">{{ fmtTime(c.last_time || c.updated_at) }}</text>
							</view>
							<view class="conv-sub">
								<text v-if="c.type === 2 && c.group_code" class="conv-group-code">群号：{{ c.group_code }}</text>
								<text v-if="c.type === 2 && c.member_count" class="conv-member-count">{{ c.member_count }}人</text>
								<text class="conv-preview">{{ c.last_message || '' }}</text>
							</view>
						</view>
					</view>
				</view>
				<view v-else-if="loaded" class="empty-chat">
					<text class="empty-chat-text">暂无私信</text>
				</view>
			</view>
			<view style="height: 180rpx;"></view>
		</scroll-view>

		<view v-if="showGroupModal" class="modal-mask" @tap="closeGroupModal">
			<view class="modal-content" @tap.stop>
				<view class="modal-item" @tap="openJoinGroup">
					<text class="modal-item-text">加入群聊</text>
				</view>
				<view class="modal-cancel" @tap="closeGroupModal">
					<text class="modal-cancel-text">取消</text>
				</view>
			</view>
		</view>

		<view v-if="showCreateModal" class="modal-mask" @tap="closeCreateModal">
			<view class="modal-content modal-create" @tap.stop>
				<view class="modal-title">创建群聊</view>
				<input class="modal-input" v-model="createName" placeholder="请输入群聊名称" />
				<view class="modal-btns">
					<view class="modal-btn modal-btn-cancel" @tap="closeCreateModal">
						<text class="modal-btn-text">取消</text>
					</view>
					<view class="modal-btn modal-btn-confirm" @tap="createGroup">
						<text class="modal-btn-text modal-btn-confirm-text">创建</text>
					</view>
				</view>
			</view>
		</view>

		<view v-if="showJoinModal" class="modal-mask" @tap="closeJoinModal">
			<view class="modal-content modal-create" @tap.stop>
				<view class="modal-title">加入群聊</view>
				<input class="modal-input" v-model="joinCode" placeholder="请输入群聊号" />
				<view class="modal-btns">
					<view class="modal-btn modal-btn-cancel" @tap="closeJoinModal">
						<text class="modal-btn-text">取消</text>
					</view>
					<view class="modal-btn modal-btn-confirm" @tap="joinGroup">
						<text class="modal-btn-text modal-btn-confirm-text">加入</text>
					</view>
				</view>
			</view>
		</view>

		<custom-tabbar :current="2" />
	</view>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { onShow, onPullDownRefresh } from '@dcloudio/uni-app'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL } from '@/utils/request.js'
import customTabbar from '@/components/custom-tabbar/custom-tabbar.vue'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const navBarH = statusBarH + 44

const conversations = ref([])
const loaded = ref(false)
const unread = reactive({ like: 0, comment: 0, follow: 0 })
const scrollTopVal = ref(0)

const isAdmin = computed(() => userStore.userInfo?.role === 1)

const showGroupModal = ref(false)
const showCreateModal = ref(false)
const showJoinModal = ref(false)
const createName = ref('')
const joinCode = ref('')

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function convColor(c) { return COLORS[(c.other_user_id || c.id || 0) % COLORS.length] }
function convAvatar(c) { return c.avatar || '' }

function groupAvatars(c) {
	const avatars = c.member_avatars || []
	const names = c.member_names || []
	const ids = c.member_ids || []
	const result = []
	for (let i = 0; i < 4; i++) {
		result.push({
			avatar: avatars[i] || '',
			name: names[i] || '',
			color: COLORS[(ids[i] || 0) % COLORS.length]
		})
	}
	return result
}

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function fmtTime(d) {
	if (!d) return ''
	const now = Date.now(), t = new Date(d).getTime(), diff = (now - t) / 1000
	if (diff < 60) return '刚刚'
	if (diff < 3600) return Math.floor(diff / 60) + '分钟前'
	if (diff < 86400) return Math.floor(diff / 3600) + '小时前'
	return Math.floor(diff / 86400) + '天前'
}

async function loadConversations() {
	if (!userStore.isLoggedIn) return
	try {
		const res = await request({ url: '/chat/conversations' })
		if (res.code === 200 && Array.isArray(res.data)) {
			conversations.value = res.data.map(c => ({ ...c, unread_count: Number(c.unread_count) || 0 }))
		} else { conversations.value = [] }
	} catch (e) { conversations.value = [] }
	loaded.value = true
}

async function loadUnread() {
	if (!userStore.isLoggedIn) return
	try {
		const res = await request({ url: '/notifications/unread' })
		if (res.code === 200) {
			unread.like = Number(res.data.like_count) || 0
			unread.comment = Number(res.data.comment_count) || 0
			unread.follow = Number(res.data.follow_count) || 0
		}
	} catch (e) {}
}

onPullDownRefresh(async () => {
	await Promise.all([loadConversations(), loadUnread()])
	uni.stopPullDownRefresh()
})

function onScroll() {}

function goNotify(type) { uni.navigateTo({ url: '/pages/message/notification-list?type=' + type }) }
function goChat(c) { uni.navigateTo({ url: '/pages/chat/chat?conversationId=' + c.id }) }
function goAiChat() { uni.navigateTo({ url: '/pages/ai/ai-chat' }) }
function onNewChat() { uni.navigateTo({ url: '/pages/chat/new-chat' }) }
function goLogin() { uni.navigateTo({ url: '/pages/login/login' }) }

function showGroupActions() { showGroupModal.value = true }
function closeGroupModal() { showGroupModal.value = false }
function openCreateGroup() { showGroupModal.value = false; createName.value = ''; showCreateModal.value = true }
function closeCreateModal() { showCreateModal.value = false }
function openJoinGroup() { showGroupModal.value = false; joinCode.value = ''; showJoinModal.value = true }
function closeJoinModal() { showJoinModal.value = false }

async function createGroup() {
	if (!createName.value.trim()) return uni.showToast({ title: '请输入群聊名称', icon: 'none' })
	uni.showLoading({ title: '创建中...' })
	try {
		const res = await request({ url: '/chat/conversation/group', method: 'POST', data: { name: createName.value.trim(), member_ids: [] } })
		if (res.code === 200) {
			uni.hideLoading()
			uni.showToast({ title: '创建成功', icon: 'success' })
			showCreateModal.value = false
			loadConversations()
			uni.navigateTo({ url: '/pages/chat/chat?conversationId=' + res.data.conversation_id })
		} else { uni.hideLoading(); uni.showToast({ title: res.msg || '创建失败', icon: 'none' }) }
	} catch (e) { uni.hideLoading(); uni.showToast({ title: '网络错误', icon: 'none' }) }
}

async function joinGroup() {
	if (!joinCode.value.trim()) return uni.showToast({ title: '请输入群聊号', icon: 'none' })
	uni.showLoading({ title: '加入中...' })
	try {
		const res = await request({ url: '/chat/conversation/join', method: 'POST', data: { group_code: joinCode.value.trim() } })
		if (res.code === 200) {
			uni.hideLoading()
			uni.showToast({ title: '加入成功', icon: 'success' })
			showJoinModal.value = false
			loadConversations()
			uni.navigateTo({ url: '/pages/chat/chat?conversationId=' + res.data.conversation_id })
		} else { uni.hideLoading(); uni.showToast({ title: res.msg || '加入失败', icon: 'none' }) }
	} catch (e) { uni.hideLoading(); uni.showToast({ title: '网络错误', icon: 'none' }) }
}

onMounted(() => { loadConversations(); loadUnread() })
onShow(() => { uni.hideTabBar({ animation: false }); loadConversations(); loadUnread() })
</script>

<style lang="scss" scoped>
.page-msg { height: 100vh; background: #f5f5f5; display: flex; flex-direction: column; overflow: hidden; }

.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; box-shadow: 0 2rpx 12rpx rgba(0,0,0,0.06); }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; }
.nav-title { font-size: 36rpx; font-weight: 700; color: #222; }
.nav-right { position: absolute; right: 24rpx; top: 50%; transform: translateY(-50%); display: flex; gap: 8rpx; }
.nav-icon { width: 56rpx; height: 56rpx; display: flex; align-items: center; justify-content: center; }
.add-text { font-size: 44rpx; color: #333; font-weight: 300; }

.main-scroll { flex: 1; height: 100vh; }

.notify-row { display: flex; justify-content: space-around; padding: 24rpx 24rpx 20rpx; background: #fff; }
.notify-card { display: flex; flex-direction: column; align-items: center; transition: transform .15s; }
.notify-card:active { transform: scale(.92); }
.card-icon { width: 100rpx; height: 100rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; position: relative; margin-bottom: 12rpx; box-shadow: 0 4rpx 16rpx rgba(0,0,0,.08); }
.like-bg { background: linear-gradient(135deg, #ff6b81, #ff2442); }
.follow-bg { background: linear-gradient(135deg, #52a8f9, #1890ff); }
.comment-bg { background: linear-gradient(135deg, #67e07a, #13c2c2); }
.card-icon-img { width: 44rpx; height: 44rpx; }
.card-badge { position: absolute; top: -6rpx; right: -6rpx; min-width: 36rpx; height: 36rpx; border-radius: 18rpx; background: #fff; display: flex; align-items: center; justify-content: center; padding: 0 8rpx; border: 2rpx solid #ff2442; }
.badge-num { font-size: 20rpx; color: #ff2442; font-weight: 800; }
.card-label { font-size: 24rpx; color: #333; font-weight: 500; }

.ai-pinned { display: flex; align-items: center; background: #fff; margin-top: 16rpx; padding: 24rpx; border-bottom: 1rpx solid #f5f5f5; transition: background .15s; }
.ai-pinned:active { background: #fafafa; }
.ai-pinned-avatar { width: 96rpx; height: 96rpx; border-radius: 50%; background: #ff2442; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 20rpx; }
.ai-av-letter { font-size: 36rpx; color: #fff; font-weight: 700; }
.ai-pinned-content { flex: 1; overflow: hidden; }
.ai-pinned-header { display: flex; align-items: center; gap: 10rpx; margin-bottom: 6rpx; }
.ai-pinned-name { font-size: 30rpx; color: #222; font-weight: 600; }
.ai-pinned-tag { background: #ff2442; border-radius: 8rpx; padding: 2rpx 10rpx; }
.ai-tag-text { font-size: 18rpx; color: #fff; font-weight: 600; }
.ai-pinned-desc { font-size: 24rpx; color: #999; }
.ai-pinned-arrow { flex-shrink: 0; margin-left: 12rpx; }
.arrow-text { font-size: 40rpx; color: #ccc; font-weight: 300; }

.conv-list { background: #fff; margin-top: 16rpx; }
.conv-row { display: flex; align-items: center; padding: 24rpx; border-bottom: 1rpx solid #f5f5f5; }
.conv-row:active { background: #fafafa; }
.conv-row:last-child { border-bottom: none; }

.conv-avatar-wrap { width: 96rpx; height: 96rpx; flex-shrink: 0; margin-right: 20rpx; position: relative; }
.conv-avatar { width: 100%; height: 100%; border-radius: 16rpx; display: flex; align-items: center; justify-content: center; overflow: hidden; }
.avatar-img { width: 100%; height: 100%; }
.avatar-text { font-size: 34rpx; color: #fff; font-weight: 600; }

.conv-avatar-group { width: 100%; height: 100%; border-radius: 16rpx; background: #e8e8e8; overflow: hidden; padding: 4rpx; }
.group-grid { display: flex; flex-wrap: wrap; width: 100%; height: 100%; gap: 2rpx; }
.grid-cell { width: calc(50% - 1rpx); height: calc(50% - 1rpx); border-radius: 6rpx; overflow: hidden; }
.grid-av-img { width: 100%; height: 100%; }
.grid-av-placeholder { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }
.grid-av-text { font-size: 16rpx; color: #fff; font-weight: 600; }

.conv-unread { position: absolute; top: -6rpx; right: -6rpx; min-width: 32rpx; height: 32rpx; border-radius: 16rpx; background: #ff2442; display: flex; align-items: center; justify-content: center; padding: 0 8rpx; border: 2rpx solid #fff; z-index: 1; }
.conv-unread-num { font-size: 18rpx; color: #fff; font-weight: 700; }

.conv-content { flex: 1; overflow: hidden; }
.conv-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6rpx; }
.conv-name-wrap { display: flex; align-items: center; gap: 8rpx; overflow: hidden; }
.conv-name { font-size: 30rpx; color: #222; font-weight: 600; }
.group-tag { font-size: 18rpx; color: #1890ff; background: rgba(24,144,255,.1); padding: 2rpx 8rpx; border-radius: 4rpx; flex-shrink: 0; }
.conv-time { font-size: 22rpx; color: #bbb; flex-shrink: 0; margin-left: 12rpx; }
.conv-sub { display: flex; align-items: center; gap: 8rpx; }
.conv-group-code { font-size: 22rpx; color: #ff2442; flex-shrink: 0; font-weight: 600; }
.conv-member-count { font-size: 22rpx; color: #bbb; flex-shrink: 0; }
.conv-preview { font-size: 26rpx; color: #999; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; }

.empty-chat { display: flex; justify-content: center; padding-top: 120rpx; }
.empty-chat-text { font-size: 26rpx; color: #ccc; }

.empty-box { display: flex; flex-direction: column; align-items: center; padding-top: 280rpx; }
.empty-illustration { margin-bottom: 32rpx; }
.empty-icon-text { font-size: 60rpx; color: #ff2442; font-weight: 700; }
.empty-hint { font-size: 30rpx; color: #999; margin-bottom: 40rpx; }
.login-btn { padding: 24rpx 90rpx; background: linear-gradient(135deg, #ff2442, #ff6b81); border-radius: 44rpx; box-shadow: 0 10rpx 30rpx rgba(255,36,66,.35); }
.login-btn-text { font-size: 30rpx; color: #fff; font-weight: 600; letter-spacing: 4rpx; }

.modal-mask { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,.5); z-index: 9999; display: flex; align-items: flex-end; justify-content: center; }
.modal-content { width: 100%; background: #fff; border-radius: 24rpx 24rpx 0 0; padding-bottom: env(safe-area-inset-bottom); overflow: hidden; }
.modal-item { padding: 32rpx; text-align: center; border-bottom: 1rpx solid #f0f0f0; }
.modal-item:active { background: #f5f5f5; }
.modal-item-text { font-size: 32rpx; color: #222; }
.modal-cancel { padding: 32rpx; text-align: center; }
.modal-cancel:active { background: #f5f5f5; }
.modal-cancel-text { font-size: 32rpx; color: #999; }

.modal-create { padding: 40rpx 32rpx 32rpx; }
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
