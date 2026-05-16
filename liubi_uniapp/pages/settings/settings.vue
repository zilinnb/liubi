<template>
	<view class="page-settings">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">设置</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="settings-body" :show-scrollbar="false">
			<view class="section-title"><text class="section-title-text">账号与安全</text></view>
			<view class="setting-group">
				<view class="s-item" @tap="goEditProfile">
					<text class="s-label">编辑资料</text>
					<text class="s-arrow">›</text>
				</view>
				<view class="s-item" @tap="goEditProfile">
					<text class="s-label">留笔号</text>
					<view class="s-right"><text class="s-value">{{ userInfo.username || '' }}</text><text class="s-arrow">›</text></view>
				</view>
				<view class="s-item" @tap="goEditProfile">
					<text class="s-label">邮箱</text>
					<view class="s-right"><text class="s-value" :class="{ 's-value-empty': !userInfo.email }">{{ userInfo.email ? maskEmail(userInfo.email) : '未绑定' }}</text><text class="s-arrow">›</text></view>
				</view>
				<view class="s-item" @tap="goEditProfile">
					<text class="s-label">密码</text>
					<view class="s-right"><text class="s-value">••••••</text><text class="s-arrow">›</text></view>
				</view>
			</view>

			<view class="section-title"><text class="section-title-text">通知与隐私</text></view>
			<view class="setting-group">
				<view class="s-item">
					<text class="s-label">推送通知</text>
					<switch :checked="settings.pushNotify" @change="onToggle('pushNotify', $event)" color="#ff2442" />
				</view>
				<view class="s-item">
					<text class="s-label">私信通知</text>
					<switch :checked="settings.chatNotify" @change="onToggle('chatNotify', $event)" color="#ff2442" />
				</view>
				<view class="s-item">
					<text class="s-label">关注列表私密</text>
					<switch :checked="settings.privacyFollows" @change="onToggle('privacyFollows', $event)" color="#ff2442" />
				</view>
				<view class="s-item">
					<text class="s-label">粉丝列表私密</text>
					<switch :checked="settings.privacyFans" @change="onToggle('privacyFans', $event)" color="#ff2442" />
				</view>
				<view class="s-item" style="border-bottom: none;">
					<text class="s-label">赞过列表私密</text>
					<switch :checked="settings.privacyLikes" @change="onToggle('privacyLikes', $event)" color="#ff2442" />
				</view>
			</view>

			<view class="section-title"><text class="section-title-text">通用</text></view>
			<view class="setting-group">
				<view class="s-item" @tap="onClearCache">
					<text class="s-label">清除缓存</text>
					<view class="s-right"><text class="s-value">{{ cacheSize }}</text><text class="s-arrow">›</text></view>
				</view>
				<view class="s-item" @tap="onCheckUpdate">
					<text class="s-label">检查更新</text>
					<view class="s-right"><text class="s-value">{{ currentVersion }}</text><text class="s-arrow">›</text></view>
				</view>
				<view class="s-item" style="border-bottom: none;">
					<text class="s-label">图片加载质量</text>
					<view class="s-right">
						<text class="s-value">{{ imgQualityLabel }}</text>
						<text class="s-arrow">›</text>
					</view>
				</view>
			</view>

			<view class="section-title"><text class="section-title-text">关于</text></view>
			<view class="setting-group">
				<view class="s-item" @tap="goPage('user-agreement')">
					<text class="s-label">用户协议</text>
					<text class="s-arrow">›</text>
				</view>
				<view class="s-item" @tap="goPage('privacy-policy')">
					<text class="s-label">隐私政策</text>
					<text class="s-arrow">›</text>
				</view>
				<view class="s-item" style="border-bottom: none;" @tap="goPage('about-us')">
					<text class="s-label">关于留笔</text>
					<view class="s-right"><text class="s-value">标记我的生活</text><text class="s-arrow">›</text></view>
				</view>
			</view>

			<view class="s-item admin-entry" v-if="isAdmin" @tap="goAdmin">
				<text class="s-label admin-label">管理中心</text>
				<text class="s-arrow">›</text>
			</view>

			<view style="height: 40rpx;"></view>
		</scroll-view>

		<update-dialog :visible="showUpdate" :info="updateInfo" @close="onUpdateClose" @update="onUpdated" />
	</view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useUserStore } from '@/store/user.js'
import { request } from '@/utils/request.js'
import { showModal } from '@/utils/modal.js'
import { checkUpdate, getStoredUpdateInfo, clearStoredUpdateInfo } from '@/utils/update.js'
import updateDialog from '@/components/update-dialog/update-dialog.vue'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const userInfo = computed(() => userStore.userInfo || {})
const isAdmin = computed(() => userInfo.value.role === 1)

const settings = ref({
	pushNotify: true,
	chatNotify: true,
	privacyFollows: false,
	privacyFans: false,
	privacyLikes: false,
	imgQuality: 'high'
})

const cacheSize = ref('计算中...')
const currentVersion = ref('v1.0.0')
const showUpdate = ref(false)
const updateInfo = ref({})

const imgQualityLabel = computed(() => {
	const map = { high: '高清', medium: '标准', low: '省流' }
	return map[settings.value.imgQuality] || '高清'
})

onMounted(() => {
	loadSettings()
	calcCache()
	loadVersion()
})

function loadVersion() {
	try {
		if (typeof plus !== 'undefined') {
			plus.runtime.getProperty(plus.runtime.appid || '__UNI__F1B7E9E', (info) => {
				currentVersion.value = 'v' + (info.version || '1.0.0')
			})
		}
	} catch {}
}

async function onCheckUpdate() {
	uni.showLoading({ title: '检查中...' })
	const info = await checkUpdate(false)
	uni.hideLoading()
	if (info) {
		updateInfo.value = info
		showUpdate.value = true
	}
}

function onUpdated() {
	clearStoredUpdateInfo()
	showUpdate.value = false
}

function onUpdateClose() {
	if (updateInfo.value && updateInfo.value.forceUpdate) return
	showUpdate.value = false
}

function loadSettings() {
	const saved = uni.getStorageSync('app_settings')
	if (saved) {
		try { Object.assign(settings.value, JSON.parse(saved)) } catch {}
	}
	if (userInfo.value.privacy_follows !== undefined) settings.value.privacyFollows = userInfo.value.privacy_follows === 1
	if (userInfo.value.privacy_fans !== undefined) settings.value.privacyFans = userInfo.value.privacy_fans === 1
	if (userInfo.value.privacy_likes !== undefined) settings.value.privacyLikes = userInfo.value.privacy_likes === 1
}

async function onToggle(key, e) {
	settings.value[key] = e.detail.value
	uni.setStorageSync('app_settings', JSON.stringify(settings.value))

	if (key.startsWith('privacy')) {
		const fieldMap = { privacyFollows: 'privacy_follows', privacyFans: 'privacy_fans', privacyLikes: 'privacy_likes' }
		const field = fieldMap[key]
		if (field) {
			await request({ url: '/auth/profile', method: 'PUT', data: { [field]: e.detail.value ? 1 : 0 } })
			userStore.fetchProfile()
		}
	}
}

function calcCache() {
	try {
		const res = uni.getStorageInfoSync()
		const kb = res.currentSize || 0
		cacheSize.value = kb > 1024 ? (kb / 1024).toFixed(1) + ' MB' : kb + ' KB'
	} catch {
		cacheSize.value = '0 KB'
	}
}

async function onClearCache() {
	const confirmed = await showModal({
		title: '清除缓存',
		content: '将清除本地缓存数据，不会影响账号信息',
		confirmText: '清除'
	})
	if (confirmed) {
		const token = uni.getStorageSync('token')
		const userInfo = uni.getStorageSync('userInfo')
		uni.clearStorageSync()
		if (token) uni.setStorageSync('token', token)
		if (userInfo) uni.setStorageSync('userInfo', userInfo)
		uni.setStorageSync('app_settings', JSON.stringify(settings.value))
		cacheSize.value = '0 KB'
		uni.showToast({ title: '缓存已清除', icon: 'success' })
	}
}

function maskEmail(email) {
	if (!email) return ''
	const [name, domain] = email.split('@')
	return name.slice(0, 2) + '***@' + domain
}

function goEditProfile() { uni.navigateTo({ url: '/pages/edit-profile/edit-profile' }) }
function goAdmin() { uni.navigateTo({ url: '/pages/admin/admin' }) }
function goBack() { uni.navigateBack() }
function goPage(page) { uni.showToast({ title: '开发中', icon: 'none' }) }
</script>

<style lang="scss" scoped>
.page-settings { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 20rpx; }
.nav-left { padding: 8rpx 12rpx; }
.back-arrow { font-size: 40rpx; color: #333; font-weight: 300; }
.nav-title { font-size: 32rpx; font-weight: 600; color: #222; }
.nav-right { width: 60rpx; }

.settings-body { padding-bottom: 40rpx; }

.section-title { padding: 28rpx 32rpx 12rpx; }
.section-title-text { font-size: 24rpx; color: #999; }

.setting-group { background: #fff; margin: 0 24rpx; border-radius: 16rpx; overflow: hidden; }
.s-item { display: flex; align-items: center; justify-content: space-between; padding: 28rpx 28rpx; border-bottom: 1rpx solid #f8f8f8; transition: background .15s; }
.s-item:active { background: #fafafa; }
.s-item:last-child { border-bottom: none; }
.s-label { font-size: 28rpx; color: #333; }
.s-right { display: flex; align-items: center; gap: 8rpx; }
.s-value { font-size: 26rpx; color: #999; }
.s-value-empty { color: #ccc; }
.s-arrow { font-size: 28rpx; color: #ccc; }

.admin-entry { background: #fff; margin: 24rpx 24rpx 0; border-radius: 16rpx; }
.admin-label { color: #ff2442; font-weight: 600; }
</style>
