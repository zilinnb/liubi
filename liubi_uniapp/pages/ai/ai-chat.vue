<template>
	<view class="ai-page">
		<view class="ai-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack">
					<image class="back-icon" src="/static/icons/back.png" mode="aspectFit" />
				</view>
				<view class="nav-center">
					<view class="nav-ai-avatar">
						<text class="nav-ai-text">Ai</text>
					</view>
					<text class="nav-title">AI 助手</text>
				</view>
				<view class="nav-right" @tap="clearChat">
					<view class="nav-clear-icon">
						<view class="clear-line clear-l1"></view>
						<view class="clear-line clear-l2"></view>
					</view>
				</view>
			</view>
		</view>

		<scroll-view
			scroll-y
			class="chat-scroll"
			:scroll-top="scrollTopVal"
			:scroll-with-animation="true"
			:show-scrollbar="false"
		>
			<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

			<view v-if="!messages.length" class="welcome-area">
				<view class="welcome-avatar">
					<text class="welcome-ai-text">Ai</text>
				</view>
				<text class="welcome-title">AI 助手</text>
				<text class="welcome-sub">有什么我可以帮助你的？</text>
				<view class="suggest-list">
					<view class="suggest-item" v-for="(s, i) in suggestions" :key="i" @tap="useSuggestion(s.text)">
						<view class="suggest-dot"></view>
						<text class="suggest-text">{{ s.text }}</text>
					</view>
				</view>
			</view>

			<view v-for="(msg, idx) in messages" :key="idx" class="msg-row" :class="msg.role === 'user' ? 'msg-right' : 'msg-left'">
				<view v-if="msg.role === 'assistant'" class="msg-avatar ai-av">
					<text class="av-ai-text">Ai</text>
				</view>

				<view class="msg-body">
					<view class="msg-bubble" :class="msg.role === 'user' ? 'bubble-user' : 'bubble-ai'">
						<text v-if="msg.role === 'user'" class="msg-text text-user" selectable>{{ msg.content }}</text>
						<md-render v-else :content="msg.content" />
					</view>
					<view v-if="msg.role === 'assistant' && msg.content" class="msg-actions">
						<view class="act-btn" @tap="copyMsg(msg.content)">
							<image class="act-icon-img" src="/static/icons/copy.png" mode="aspectFit" />
							<text class="act-label">{{ copiedIdx === idx ? '已复制' : '复制' }}</text>
						</view>
						<view class="act-btn" @tap="regenerateMsg(idx)">
							<image class="act-icon-img" src="/static/icons/res.png" mode="aspectFit" />
							<text class="act-label">重新生成</text>
						</view>
					</view>
				</view>

				<view v-if="msg.role === 'user'" class="msg-avatar user-av">
					<image v-if="userAvatar" class="av-img" :src="userAvatar" mode="aspectFill" />
					<text v-else class="av-letter">{{ userLetter }}</text>
				</view>
			</view>

			<view v-if="isTyping" class="generating-card">
				<view class="gen-spinner">
					<view class="gen-ring"></view>
				</view>
				<view class="gen-info">
					<text class="gen-title">正在生成</text>
					<text class="gen-sub">{{ genStatus }}</text>
				</view>
			</view>

			<view style="height: 32rpx;"></view>
		</scroll-view>

		<view class="input-bar" :style="{ paddingBottom: Math.max(safeBottom, keyboardH) + 'px' }">
			<view class="input-row">
				<view class="input-wrap">
					<textarea
						class="chat-input"
						v-model="inputText"
						placeholder="输入消息..."
						placeholder-class="ph"
						:auto-height="true"
						:maxlength="-1"
						:adjust-position="false"
						:cursor-spacing="20"
						@focus="onInputFocus"
						@blur="onInputBlur"
						:disabled="isTyping"
					/>
				</view>
				<view v-if="inputText.trim() && !isTyping" class="send-btn send-on" @tap="sendMessage">
					<text class="send-text">发送</text>
				</view>
				<view v-else class="send-btn send-off">
					<text class="send-text-off">发送</text>
				</view>
			</view>
		</view>

		<custom-modal
			:visible="modalData.visible"
			:title="modalData.title"
			:content="modalData.content"
			:showCancel="modalData.showCancel"
			:cancelText="modalData.cancelText"
			:confirmText="modalData.confirmText"
			@confirm="onModalConfirm"
			@cancel="onModalCancel"
		/>
	</view>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { BASE_URL } from '@/utils/request.js'
import { useUserStore } from '@/store/user.js'
import mdRender from '@/components/md-render/md-render.vue'
import customModal from '@/components/custom-modal/custom-modal.vue'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const safeBottom = sys.safeAreaInsets?.bottom || 0

const messages = ref([])
const inputText = ref('')
const isTyping = ref(false)
const scrollTopVal = ref(0)
const keyboardH = ref(0)
const genStatus = ref('思考中...')
const copiedIdx = ref(-1)
const modalData = ref({
	visible: false,
	title: '',
	content: '',
	showCancel: true,
	cancelText: '取消',
	confirmText: '确定',
	_resolve: null
})

const genStatusList = ['思考中...', '组织语言...', '生成回答...', '即将完成...']
let genStatusTimer = null

const suggestions = [
	{ text: '帮我写一段文艺的文案' },
	{ text: '推荐一些好听的歌' },
	{ text: '讲一个有趣的故事' },
	{ text: '用Python写一个快速排序' }
]

const userAvatar = computed(() => {
	const info = userStore.userInfo
	if (info && info.avatar) {
		const url = info.avatar
		if (url.startsWith('http')) return url
		return BASE_URL.replace('/api', '') + url
	}
	return ''
})

const userLetter = computed(() => {
	const name = userStore.userInfo?.nickname || userStore.userInfo?.username || '我'
	return name.slice(0, 1)
})

function goBack() { uni.navigateBack() }

function scrollToBottom() {
	nextTick(() => { scrollTopVal.value = scrollTopVal.value + 9999 })
}

let scrollTimer = null
function startAutoScroll() {
	if (scrollTimer) return
	scrollTimer = setInterval(() => { scrollTopVal.value = scrollTopVal.value + 300 }, 60)
}
function stopAutoScroll() {
	if (scrollTimer) { clearInterval(scrollTimer); scrollTimer = null }
}

function startGenStatus() {
	let idx = 0
	genStatus.value = genStatusList[0]
	genStatusTimer = setInterval(() => {
		idx = (idx + 1) % genStatusList.length
		genStatus.value = genStatusList[idx]
	}, 2000)
}

function stopGenStatus() {
	if (genStatusTimer) { clearInterval(genStatusTimer); genStatusTimer = null }
}

function onInputFocus() {}
function onInputBlur() {}

function copyMsg(content) {
	uni.setClipboardData({
		data: content,
		success: () => {
			const idx = messages.value.findIndex(m => m.role === 'assistant' && m.content === content)
			copiedIdx.value = idx
			setTimeout(() => { copiedIdx.value = -1 }, 2000)
		}
	})
}

async function regenerateMsg(idx) {
	if (isTyping.value) return

	let userMsgIdx = idx - 1
	while (userMsgIdx >= 0 && messages.value[userMsgIdx].role !== 'user') {
		userMsgIdx--
	}
	if (userMsgIdx < 0) return

	const userContent = messages.value[userMsgIdx].content

	messages.value.splice(idx, 1)

	isTyping.value = true
	startAutoScroll()
	startGenStatus()

	try {
		const token = uni.getStorageSync('token') || ''
		const history = messages.value.map(m => ({ role: m.role, content: m.content }))

		const res = await new Promise((resolve, reject) => {
			uni.request({
				url: BASE_URL + '/ai/chat',
				method: 'POST',
				data: JSON.stringify({ messages: history, userMessage: userContent }),
				header: {
					'Content-Type': 'application/json',
					'Authorization': token ? 'Bearer ' + token : ''
				},
				success: (r) => {
					if (r.statusCode === 200) resolve(r.data)
					else reject(new Error('HTTP ' + r.statusCode))
				},
				fail: (e) => reject(new Error(e.errMsg || '请求失败'))
			})
		})

		stopGenStatus()
		if (res.code === 200 && res.data && res.data.content) {
			await typewriterEffect(res.data.content)
		} else {
			messages.value.push({ role: 'assistant', content: res.msg || '抱歉，暂时无法回答，请稍后再试。' })
		}
	} catch (e) {
		stopGenStatus()
		messages.value.push({ role: 'assistant', content: '网络似乎出了点问题，请检查后重试。' })
	}

	isTyping.value = false
	stopAutoScroll()
	scrollToBottom()
}

function onKeyboardHeightChange(e) {
	keyboardH.value = e.height || 0
	if (keyboardH.value > 0) {
		scrollToBottom()
	}
}

function useSuggestion(text) {
	inputText.value = text
	sendMessage()
}

async function sendMessage() {
	const text = inputText.value.trim()
	if (!text || isTyping.value) return

	messages.value.push({ role: 'user', content: text })
	inputText.value = ''
	scrollToBottom()

	isTyping.value = true
	startAutoScroll()
	startGenStatus()

	try {
		const token = uni.getStorageSync('token') || ''
		const history = messages.value.map(m => ({ role: m.role, content: m.content }))

		const res = await new Promise((resolve, reject) => {
			uni.request({
				url: BASE_URL + '/ai/chat',
				method: 'POST',
				data: JSON.stringify({ messages: history, userMessage: text }),
				header: {
					'Content-Type': 'application/json',
					'Authorization': token ? 'Bearer ' + token : ''
				},
				success: (r) => {
					if (r.statusCode === 200) resolve(r.data)
					else reject(new Error('HTTP ' + r.statusCode))
				},
				fail: (e) => reject(new Error(e.errMsg || '请求失败'))
			})
		})

		stopGenStatus()
		if (res.code === 200 && res.data && res.data.content) {
			await typewriterEffect(res.data.content)
		} else {
			messages.value.push({ role: 'assistant', content: res.msg || '抱歉，暂时无法回答，请稍后再试。' })
		}
	} catch (e) {
		stopGenStatus()
		messages.value.push({ role: 'assistant', content: '网络似乎出了点问题，请检查后重试。' })
	}

	isTyping.value = false
	stopAutoScroll()
	scrollToBottom()
}

async function typewriterEffect(fullText) {
	const aiMsg = { role: 'assistant', content: '' }
	messages.value.push(aiMsg)

	const len = fullText.length
	let pos = 0

	while (pos < len) {
		const step = Math.min(2, len - pos)
		aiMsg.content = fullText.slice(0, pos + step)
		pos += step
		scrollToBottom()
		await new Promise(r => setTimeout(r, 20))
	}
}

function clearChat() {
	if (isTyping.value) return
	modalData.value = {
		visible: true,
		title: '清空对话',
		content: '确定要清空所有对话记录吗？',
		showCancel: true,
		cancelText: '取消',
		confirmText: '清空',
		_resolve: null
	}
}

function onModalConfirm() {
	modalData.value.visible = false
	if (modalData.value.title === '清空对话') {
		doClearChat()
	}
}

function onModalCancel() {
	modalData.value.visible = false
}

async function doClearChat() {
	messages.value = []
	try {
		const token = uni.getStorageSync('token') || ''
		await new Promise((resolve, reject) => {
			uni.request({
				url: BASE_URL + '/ai/history',
				method: 'DELETE',
				header: { 'Authorization': token ? 'Bearer ' + token : '' },
				success: (r) => resolve(r.data),
				fail: (e) => reject(e)
			})
		})
	} catch (e) {}
	uni.showToast({ title: '已清空', icon: 'success' })
}

async function loadChat() {
	try {
		const token = uni.getStorageSync('token') || ''
		const res = await new Promise((resolve, reject) => {
			uni.request({
				url: BASE_URL + '/ai/history?limit=50',
				method: 'GET',
				header: { 'Authorization': token ? 'Bearer ' + token : '' },
				success: (r) => {
					if (r.statusCode === 200) resolve(r.data)
					else reject(new Error('HTTP ' + r.statusCode))
				},
				fail: (e) => reject(e)
			})
		})
		if (res.code === 200 && res.data && res.data.length) {
			messages.value = res.data.map(m => ({ role: m.role, content: m.content }))
			nextTick(() => scrollToBottom())
		}
	} catch (e) {
		try {
			const saved = uni.getStorageSync('ai_chat_history')
			if (saved) {
				messages.value = JSON.parse(saved)
				nextTick(() => scrollToBottom())
			}
		} catch (e2) {}
	}
}

onMounted(() => {
	loadChat()
	uni.onKeyboardHeightChange(onKeyboardHeightChange)
})

onBeforeUnmount(() => {
	uni.offKeyboardHeightChange(onKeyboardHeightChange)
	stopAutoScroll()
	stopGenStatus()
})
</script>

<style lang="scss" scoped>
.ai-page { height: 100vh; background: #fff; display: flex; flex-direction: column; overflow: hidden; }

.ai-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 28rpx; }
.nav-left, .nav-right { width: 72rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.back-icon { width: 40rpx; height: 40rpx; }
.nav-center { display: flex; align-items: center; gap: 10rpx; }
.nav-ai-avatar { width: 36rpx; height: 36rpx; border-radius: 50%; background: #ff2442; display: flex; align-items: center; justify-content: center; }
.nav-ai-text { font-size: 18rpx; color: #fff; font-weight: 700; }
.nav-title { font-size: 30rpx; color: #222; font-weight: 600; }
.nav-clear-icon { width: 28rpx; height: 28rpx; position: relative; }
.clear-line { width: 20rpx; height: 3rpx; background: #999; border-radius: 2rpx; position: absolute; top: 50%; left: 50%; }
.clear-l1 { transform: translate(-50%, -50%) rotate(45deg); }
.clear-l2 { transform: translate(-50%, -50%) rotate(-45deg); }

.chat-scroll { flex: 1; height: 0; background: #fafafa; }

.welcome-area { display: flex; flex-direction: column; align-items: center; padding: 100rpx 48rpx 40rpx; }
.welcome-avatar { width: 120rpx; height: 120rpx; border-radius: 50%; background: #ff2442; display: flex; align-items: center; justify-content: center; margin-bottom: 32rpx; }
.welcome-ai-text { font-size: 48rpx; color: #fff; font-weight: 700; }
.welcome-title { font-size: 38rpx; color: #222; font-weight: 700; margin-bottom: 10rpx; }
.welcome-sub { font-size: 26rpx; color: #999; margin-bottom: 56rpx; }
.suggest-list { width: 100%; }
.suggest-item { display: flex; align-items: center; gap: 16rpx; padding: 24rpx 28rpx; background: #fff; border-radius: 16rpx; margin-bottom: 16rpx; border: 1rpx solid #f0f0f0; transition: all .15s; }
.suggest-item:active { background: #fff5f6; border-color: #ffccd5; }
.suggest-dot { width: 8rpx; height: 8rpx; border-radius: 50%; background: #ff2442; flex-shrink: 0; }
.suggest-text { font-size: 26rpx; color: #555; }

.msg-row { display: flex; align-items: flex-start; padding: 20rpx 28rpx; animation: msgFade .25s ease; }
.msg-left { justify-content: flex-start; }
.msg-right { justify-content: flex-end; }
@keyframes msgFade { from { opacity: 0; transform: translateY(12rpx); } to { opacity: 1; transform: translateY(0); } }

.msg-avatar { width: 64rpx; height: 64rpx; border-radius: 50%; flex-shrink: 0; display: flex; align-items: center; justify-content: center; overflow: hidden; }
.ai-av { background: #ff2442; margin-right: 16rpx; }
.av-ai-text { font-size: 24rpx; color: #fff; font-weight: 700; }
.user-av { background: #ff2442; margin-left: 16rpx; }
.av-img { width: 100%; height: 100%; }
.av-letter { font-size: 26rpx; color: #fff; font-weight: 600; }

.msg-body { max-width: 78%; }
.msg-bubble { border-radius: 20rpx; padding: 20rpx 24rpx; }
.bubble-user { background: #ff2442; border-top-right-radius: 6rpx; }
.bubble-ai { background: #fff; border: 1rpx solid #f0f0f0; border-top-left-radius: 6rpx; }

.msg-text { font-size: 28rpx; line-height: 1.7; word-break: break-word; }
.text-user { color: #fff; }

.msg-actions { display: flex; gap: 16rpx; margin-top: 12rpx; padding-left: 4rpx; }
.act-btn { display: flex; align-items: center; gap: 6rpx; padding: 8rpx 16rpx; background: #f5f5f5; border-radius: 16rpx; transition: all .15s; }
.act-btn:active { background: #eee; transform: scale(0.95); }
.act-icon-img { width: 24rpx; height: 24rpx; }
.act-label { font-size: 22rpx; color: #888; }

.generating-card { display: flex; align-items: center; margin: 16rpx 28rpx; padding: 20rpx 24rpx; background: #fff; border-radius: 16rpx; border: 1rpx solid #f0f0f0; animation: genPulse 2s ease infinite; }
.gen-spinner { margin-right: 16rpx; flex-shrink: 0; }
.gen-ring { width: 36rpx; height: 36rpx; border-radius: 50%; border: 3rpx solid #f0f0f0; border-top-color: #ff2442; animation: genSpin .8s linear infinite; }
@keyframes genSpin { to { transform: rotate(360deg); } }
@keyframes genPulse { 0%, 100% { border-color: #f0f0f0; } 50% { border-color: #ffccd5; } }
.gen-info { display: flex; flex-direction: column; gap: 4rpx; }
.gen-title { font-size: 26rpx; color: #222; font-weight: 600; }
.gen-sub { font-size: 22rpx; color: #999; animation: genFade 2s ease infinite; }
@keyframes genFade { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }

.input-bar { background: #f7f7f7; border-top: 1rpx solid #e5e5e5; }
.input-row { display: flex; align-items: flex-end; padding: 12rpx 16rpx; }
.input-wrap { flex: 1; background: #fff; border-radius: 12rpx; padding: 12rpx 16rpx; min-height: 72rpx; max-height: 240rpx; border: 1rpx solid #e5e5e5; }
.chat-input { font-size: 28rpx; min-height: 40rpx; max-height: 200rpx; line-height: 1.5; width: 100%; }
.ph { color: #ccc; }
.send-btn { height: 72rpx; border-radius: 12rpx; display: flex; align-items: center; justify-content: center; padding: 0 24rpx; margin-left: 12rpx; flex-shrink: 0; transition: all .15s; }
.send-on { background: #ff2442; }
.send-off { background: #e5e5e5; }
.send-text { font-size: 28rpx; color: #fff; font-weight: 600; }
.send-text-off { font-size: 28rpx; color: #bbb; font-weight: 500; }
</style>
