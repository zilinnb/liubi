<template>
	<view class="page-edit">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">编辑资料</text>
				<view class="nav-right" @tap="onSave"><text class="save-text" :class="{ 'save-active': changed }">保存</text></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="edit-body" :show-scrollbar="false">
			<!-- 头像 -->
			<view class="avatar-section" @tap="changeAvatar">
				<view class="avatar-row">
					<text class="avatar-label">头像</text>
					<view class="avatar-right">
						<image v-if="form.avatar" class="avatar-img" :src="fullUrl(form.avatar)" mode="aspectFill" />
						<view v-else class="avatar-placeholder" :style="{ background: avatarBg }">
							<text class="avatar-letter">{{ avatarLetter }}</text>
						</view>
						<text class="arrow">›</text>
					</view>
				</view>
			</view>

			<!-- 背景图 -->
			<view class="avatar-section" @tap="changeBgImage">
				<view class="avatar-row">
					<text class="avatar-label">背景图</text>
					<view class="avatar-right">
						<image v-if="form.bg_image" class="bg-thumb" :src="fullUrl(form.bg_image)" mode="aspectFill" />
						<view v-else class="bg-placeholder"><text class="bg-placeholder-text">+</text></view>
						<text class="arrow">›</text>
					</view>
				</view>
			</view>

			<!-- 昵称 -->
			<view class="field-section">
				<view class="field-row">
					<text class="field-label">昵称</text>
					<input class="field-input" v-model="form.nickname" placeholder="设置昵称" maxlength="20" />
				</view>
			</view>

			<!-- 性别 -->
			<view class="field-section" @tap="onGenderTap">
				<view class="field-row">
					<text class="field-label">性别</text>
					<view class="field-right">
						<text class="field-value" :class="{ 'field-value-empty': !form.gender }">{{ genderText }}</text>
						<text class="arrow">›</text>
					</view>
				</view>
			</view>

			<!-- 生日 -->
			<view class="field-section">
				<view class="field-row">
					<text class="field-label">生日</text>
					<picker mode="date" :value="form.birthday" @change="onBirthdayChange">
						<view class="field-right">
							<text class="field-value" :class="{ 'field-value-empty': !form.birthday }">{{ form.birthday || '选择生日' }}</text>
							<text class="arrow">›</text>
						</view>
					</picker>
				</view>
			</view>

			<!-- 简介 -->
			<view class="field-section">
				<view class="field-col">
					<text class="field-label">简介</text>
					<textarea class="field-textarea" v-model="form.bio" placeholder="介绍一下自己吧" maxlength="200" :auto-height="true" />
				</view>
			</view>

			<!-- 隐私设置 -->
			<view class="section-title"><text class="section-title-text">隐私设置</text></view>

			<view class="field-section">
				<view class="field-row">
					<text class="field-label">关注列表</text>
					<switch :checked="form.privacy_follows === 1" @change="v => form.privacy_follows = v.detail.value ? 1 : 0" color="#ff2442" />
				</view>
				<view class="field-row">
					<text class="field-label">粉丝列表</text>
					<switch :checked="form.privacy_fans === 1" @change="v => form.privacy_fans = v.detail.value ? 1 : 0" color="#ff2442" />
				</view>
				<view class="field-row" style="border-bottom: none;">
					<text class="field-label">赞过列表</text>
					<switch :checked="form.privacy_likes === 1" @change="v => form.privacy_likes = v.detail.value ? 1 : 0" color="#ff2442" />
				</view>
			</view>
			<view class="privacy-hint"><text class="privacy-hint-text">开启后仅自己可见</text></view>

			<!-- 留笔号 -->
			<view class="field-section" @tap="onChangeUsername">
				<view class="field-row">
					<text class="field-label">留笔号</text>
					<view class="field-right">
						<text class="field-value">{{ userInfo.username }}</text>
						<text class="field-hint" v-if="!userInfo.username_changed_at">可修改</text>
						<text class="field-hint" v-else>{{ usernameHint }}</text>
						<text class="arrow">›</text>
					</view>
				</view>
			</view>

			<!-- 邮箱 -->
			<view class="field-section" @tap="onEmailTap">
				<view class="field-row">
					<text class="field-label">邮箱</text>
					<view class="field-right">
						<text class="field-value" :class="{ 'field-value-empty': !userInfo.email }">{{ userInfo.email ? maskEmail(userInfo.email) : '未绑定' }}</text>
						<text class="field-hint" v-if="!userInfo.email">去绑定</text>
						<text class="arrow">›</text>
					</view>
				</view>
			</view>

			<!-- 修改密码 -->
			<view class="field-section" @tap="onChangePassword">
				<view class="field-row">
					<text class="field-label">密码</text>
					<view class="field-right">
						<text class="field-value">••••••</text>
						<text class="arrow">›</text>
					</view>
				</view>
			</view>

			<view style="height: 20rpx;"></view>

			<view class="logout-section" @tap="onLogout">
				<text class="logout-text">退出登录</text>
			</view>

			<view style="height: 40rpx;"></view>
		</scroll-view>

		<!-- 修改用户名弹窗 -->
		<view class="overlay" v-if="showUsernameModal" @tap="showUsernameModal=false">
			<view class="modal" @tap.stop>
				<text class="modal-title">修改留笔号</text>
				<text class="modal-desc">90天只能修改一次，请谨慎操作</text>
				<view class="modal-field">
					<input class="modal-input" v-model="newUsername" placeholder="英文、数字、符号 _ . - @" type="text" maxlength="30" />
				</view>
				<view class="modal-btns">
					<view class="modal-btn modal-cancel" @tap="showUsernameModal=false"><text class="modal-btn-text">取消</text></view>
					<view class="modal-btn modal-confirm" @tap="doChangeUsername"><text class="modal-btn-text-confirm">确认修改</text></view>
				</view>
			</view>
		</view>

		<!-- 修改密码弹窗 -->
		<view class="overlay" v-if="showPwdModal" @tap="showPwdModal=false">
			<view class="modal" @tap.stop>
				<text class="modal-title">重置密码</text>
				<text class="modal-desc" v-if="userInfo.email">验证码将发送至 {{ maskEmail(userInfo.email) }}</text>
				<text class="modal-desc" v-else>请先绑定邮箱</text>
				<view class="modal-field" v-if="userInfo.email">
					<input class="modal-input" v-model="pwdForm.code" placeholder="验证码" type="number" maxlength="6" />
					<view class="modal-code-btn" :class="{ 'code-btn-disabled': pwdCooldown > 0, 'code-btn-sending': pwdSending }" @tap="onSendPwdCode">
						<text class="modal-code-text" v-if="pwdSending">发送中...</text>
						<text class="modal-code-text" v-else-if="pwdCooldown > 0">{{ pwdCooldown }}s</text>
						<text class="modal-code-text" v-else>获取验证码</text>
					</view>
				</view>
				<view class="modal-field" v-if="userInfo.email">
					<input class="modal-input" v-model="pwdForm.newPassword" placeholder="新密码（至少6位）" :password="true" />
				</view>
				<view class="modal-btns">
					<view class="modal-btn modal-cancel" @tap="showPwdModal=false"><text class="modal-btn-text">取消</text></view>
					<view class="modal-btn modal-confirm" v-if="userInfo.email" @tap="doChangePassword"><text class="modal-btn-text-confirm">确认修改</text></view>
					<view class="modal-btn modal-confirm" v-else @tap="showPwdModal=false; showBindEmailModal=true"><text class="modal-btn-text-confirm">去绑定邮箱</text></view>
				</view>
			</view>
		</view>

		<!-- 绑定邮箱弹窗 -->
		<view class="overlay" v-if="showBindEmailModal" @tap="showBindEmailModal=false">
			<view class="modal" @tap.stop>
				<text class="modal-title">绑定邮箱</text>
				<text class="modal-desc">绑定后可使用验证码登录和找回密码</text>
				<view class="modal-field">
					<input class="modal-input" v-model="bindEmailForm.email" placeholder="请输入邮箱地址" type="text" />
				</view>
				<view class="modal-field">
					<input class="modal-input" v-model="bindEmailForm.code" placeholder="验证码" type="number" maxlength="6" />
					<view class="modal-code-btn" :class="{ 'code-btn-disabled': bindCooldown > 0, 'code-btn-sending': bindSending }" @tap="onSendBindCode">
						<text class="modal-code-text" v-if="bindSending">发送中...</text>
						<text class="modal-code-text" v-else-if="bindCooldown > 0">{{ bindCooldown }}s</text>
						<text class="modal-code-text" v-else>获取验证码</text>
					</view>
				</view>
				<view class="modal-btns">
					<view class="modal-btn modal-cancel" @tap="showBindEmailModal=false"><text class="modal-btn-text">取消</text></view>
					<view class="modal-btn modal-confirm" @tap="doBindEmail"><text class="modal-btn-text-confirm">确认绑定</text></view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useUserStore } from '@/store/user.js'
import { uploadFile, BASE_URL } from '@/utils/request.js'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const userInfo = computed(() => userStore.userInfo || {})

const form = ref({ nickname: '', bio: '', avatar: '', bg_image: '', gender: 0, birthday: '', privacy_follows: 0, privacy_fans: 0, privacy_likes: 0 })
const showUsernameModal = ref(false)
const showPwdModal = ref(false)
const showBindEmailModal = ref(false)
const newUsername = ref('')
const pwdForm = ref({ code: '', newPassword: '' })
const pwdCooldown = ref(0)
const pwdSending = ref(false)
const bindEmailForm = ref({ email: '', code: '' })
const bindCooldown = ref(0)
const bindSending = ref(false)

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
const avatarBg = computed(() => COLORS[(userInfo.value.id||0) % COLORS.length])
const avatarLetter = computed(() => (form.value.nickname || userInfo.value.username || '?').slice(0,1))

const genderText = computed(() => {
	return { 0: '未设置', 1: '男', 2: '女' }[form.value.gender] || '未设置'
})

const usernameHint = computed(() => {
	if (!userInfo.value.username_changed_at) return '可修改'
	const daysSince = (Date.now() - new Date(userInfo.value.username_changed_at).getTime()) / (1000*60*60*24)
	if (daysSince >= 90) return '可修改'
	return Math.ceil(90 - daysSince) + '天后可改'
})

const changed = computed(() => {
	return form.value.nickname !== (userInfo.value.nickname || '') ||
		form.value.bio !== (userInfo.value.bio || '') ||
		form.value.avatar !== (userInfo.value.avatar || '') ||
		form.value.bg_image !== (userInfo.value.bg_image || '') ||
		form.value.gender !== (userInfo.value.gender || 0) ||
		form.value.birthday !== (userInfo.value.birthday || '') ||
		form.value.privacy_follows !== (userInfo.value.privacy_follows || 0) ||
		form.value.privacy_fans !== (userInfo.value.privacy_fans || 0) ||
		form.value.privacy_likes !== (userInfo.value.privacy_likes || 0)
})

function fullUrl(url) {
	if (!url) return ''
	if (url.startsWith('http')) return url
	return BASE_URL.replace('/api', '') + url
}

function maskEmail(email) {
	if (!email) return '未绑定'
	const [name, domain] = email.split('@')
	if (!domain) return email
	const masked = name.length > 2 ? name[0] + '***' + name.slice(-1) : name[0] + '***'
	return masked + '@' + domain
}

function onGenderTap() {
	uni.showActionSheet({
		itemList: ['未设置', '男', '女'],
		success: (res) => { form.value.gender = res.tapIndex }
	})
}

function onBirthdayChange(e) {
	form.value.birthday = e.detail.value
}

onMounted(() => {
	if (userInfo.value) {
		form.value.nickname = userInfo.value.nickname || ''
		form.value.bio = userInfo.value.bio || ''
		form.value.avatar = userInfo.value.avatar || ''
		form.value.bg_image = userInfo.value.bg_image || ''
		form.value.gender = userInfo.value.gender || 0
		form.value.birthday = formatDate(userInfo.value.birthday) || ''
		form.value.privacy_follows = userInfo.value.privacy_follows || 0
		form.value.privacy_fans = userInfo.value.privacy_fans || 0
		form.value.privacy_likes = userInfo.value.privacy_likes || 0
	}
})

function formatDate(d) {
	if (!d) return ''
	const date = new Date(d)
	if (isNaN(date.getTime())) return ''
	const y = date.getFullYear()
	const m = String(date.getMonth() + 1).padStart(2, '0')
	const day = String(date.getDate()).padStart(2, '0')
	return `${y}-${m}-${day}`
}

function changeAvatar() {
	uni.chooseImage({
		count: 1,
		sizeType: ['compressed'],
		success: async (res) => {
			const uploadRes = await uploadFile('/upload/single', res.tempFilePaths[0])
			if (uploadRes.code === 200 && uploadRes.data.url) {
				form.value.avatar = uploadRes.data.url
			} else {
				uni.showToast({ title: '上传失败', icon: 'none' })
			}
		}
	})
}

function changeBgImage() {
	uni.chooseImage({
		count: 1,
		sizeType: ['compressed'],
		success: async (res) => {
			const uploadRes = await uploadFile('/upload/single', res.tempFilePaths[0])
			if (uploadRes.code === 200 && uploadRes.data.url) {
				form.value.bg_image = uploadRes.data.url
			} else {
				uni.showToast({ title: '上传失败', icon: 'none' })
			}
		}
	})
}

async function onSave() {
	if (!changed.value) return goBack()
	const res = await userStore.updateProfile({
		nickname: form.value.nickname.trim(),
		bio: form.value.bio.trim(),
		avatar: form.value.avatar,
		bg_image: form.value.bg_image,
		gender: form.value.gender,
		birthday: form.value.birthday,
		privacy_follows: form.value.privacy_follows,
		privacy_fans: form.value.privacy_fans,
		privacy_likes: form.value.privacy_likes
	})
	if (res.code === 200) {
		uni.showToast({ title: '保存成功', icon: 'success' })
		setTimeout(() => uni.navigateBack(), 800)
	} else {
		uni.showToast({ title: res.msg || '保存失败', icon: 'none' })
	}
}

function onChangeUsername() {
	if (userInfo.value.username_changed_at) {
		const daysSince = (Date.now() - new Date(userInfo.value.username_changed_at).getTime()) / (1000*60*60*24)
		if (daysSince < 90) {
			return uni.showToast({ title: Math.ceil(90-daysSince) + '天后才能修改', icon: 'none' })
		}
	}
	newUsername.value = ''
	showUsernameModal.value = true
}

async function doChangeUsername() {
	if (newUsername.value.length < 3 || newUsername.value.length > 30) {
		return uni.showToast({ title: '用户名长度需在3-30位之间', icon: 'none' })
	}
	if (!/^[a-zA-Z0-9_.\-@]+$/.test(newUsername.value)) {
		return uni.showToast({ title: '只能包含英文、数字和符号 _ . - @', icon: 'none' })
	}
	const res = await userStore.changeUsername(newUsername.value)
	if (res.code === 200) {
		showUsernameModal.value = false
		uni.showToast({ title: '修改成功', icon: 'success' })
	} else {
		uni.showToast({ title: res.msg || '修改失败', icon: 'none' })
	}
}

function onEmailTap() {
	if (userInfo.value.email) {
		uni.showActionSheet({
			itemList: ['更换邮箱绑定'],
			success: () => {
				bindEmailForm.value = { email: '', code: '' }
				showBindEmailModal.value = true
			}
		})
	} else {
		bindEmailForm.value = { email: '', code: '' }
		showBindEmailModal.value = true
	}
}

async function onSendBindCode() {
	if (bindCooldown.value > 0) return
	if (!bindEmailForm.value.email) return uni.showToast({ title: '请输入邮箱', icon: 'none' })
	bindSending.value = true
	try {
		const res = await userStore.sendCode(bindEmailForm.value.email, 4)
		if (res.code === 200) {
			startCooldown(bindCooldown)
			uni.showToast({ title: '验证码已发送', icon: 'success' })
		} else {
			uni.showToast({ title: res.msg || '发送失败', icon: 'none', duration: 2500 })
		}
	} catch (e) {
		uni.showToast({ title: '网络错误，请重试', icon: 'none' })
	} finally {
		bindSending.value = false
	}
}

async function doBindEmail() {
	if (!bindEmailForm.value.email || !bindEmailForm.value.code) return uni.showToast({ title: '请填写完整', icon: 'none' })
	const res = await userStore.bindEmail(bindEmailForm.value.email, bindEmailForm.value.code)
	if (res.code === 200) {
		showBindEmailModal.value = false
		uni.showToast({ title: '绑定成功', icon: 'success' })
	} else {
		uni.showToast({ title: res.msg || '绑定失败', icon: 'none' })
	}
}

function onChangePassword() {
	pwdForm.value = { code: '', newPassword: '' }
	showPwdModal.value = true
}

async function onSendPwdCode() {
	if (pwdCooldown.value > 0) return
	if (!userInfo.value.email) return uni.showToast({ title: '请先绑定邮箱', icon: 'none' })
	pwdSending.value = true
	try {
		const res = await userStore.sendCode(userInfo.value.email, 3)
		if (res.code === 200) {
			startCooldown(pwdCooldown)
			uni.showToast({ title: '验证码已发送', icon: 'success' })
		} else {
			uni.showToast({ title: res.msg || '发送失败', icon: 'none', duration: 2500 })
		}
	} catch (e) {
		uni.showToast({ title: '网络错误，请重试', icon: 'none' })
	} finally {
		pwdSending.value = false
	}
}

function startCooldown(timerRef, seconds = 60) {
	timerRef.value = seconds
	const interval = setInterval(() => {
		timerRef.value--
		if (timerRef.value <= 0) clearInterval(interval)
	}, 1000)
}

async function doChangePassword() {
	if (!pwdForm.value.code || !pwdForm.value.newPassword) return uni.showToast({ title: '请填写完整', icon: 'none' })
	if (pwdForm.value.newPassword.length < 6) return uni.showToast({ title: '密码至少6位', icon: 'none' })
	const res = await userStore.changePassword(userInfo.value.email, pwdForm.value.code, pwdForm.value.newPassword)
	if (res.code === 200) {
		showPwdModal.value = false
		uni.showToast({ title: '密码修改成功', icon: 'success' })
	} else {
		uni.showToast({ title: res.msg || '修改失败', icon: 'none' })
	}
}

function goBack() { uni.navigateBack() }

function onLogout() {
	uni.showModal({
		title: '提示',
		content: '确定退出登录吗？',
		confirmColor: '#ff2442',
		success: (res) => {
			if (res.confirm) {
				userStore.logout()
				uni.showToast({ title: '已退出', icon: 'none' })
				setTimeout(() => { uni.navigateBack() }, 1000)
			}
		}
	})
}
</script>

<style lang="scss" scoped>
.page-edit { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 20rpx; }
.nav-left { padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }
.save-text { font-size: 28rpx; color: #ccc; transition: color .2s; }
.save-active { color: #ff2442; font-weight: 600; }

.edit-body { padding: 0; }

.avatar-section { background: #fff; margin-bottom: 16rpx; }
.avatar-row { display: flex; align-items: center; justify-content: space-between; padding: 28rpx 24rpx; }
.avatar-label { font-size: 28rpx; color: #333; }
.avatar-right { display: flex; align-items: center; gap: 12rpx; }
.avatar-img { width: 96rpx; height: 96rpx; border-radius: 50%; }
.avatar-placeholder { width: 96rpx; height: 96rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.avatar-letter { font-size: 36rpx; color: #fff; font-weight: 700; }
.bg-thumb { width: 96rpx; height: 54rpx; border-radius: 8rpx; }
.bg-placeholder { width: 96rpx; height: 54rpx; border-radius: 8rpx; background: #f0f0f0; display: flex; align-items: center; justify-content: center; }
.bg-placeholder-text { font-size: 32rpx; color: #ccc; }
.arrow { font-size: 28rpx; color: #ccc; }

.field-section { background: #fff; margin-bottom: 16rpx; padding: 0 24rpx; }
.field-row { display: flex; align-items: center; justify-content: space-between; padding: 28rpx 0; border-bottom: 1rpx solid #f8f8f8; }
.field-label { font-size: 28rpx; color: #333; flex-shrink: 0; width: 120rpx; }
.field-input { flex: 1; text-align: right; font-size: 28rpx; color: #222; }
.field-right { display: flex; align-items: center; gap: 8rpx; }
.field-value { font-size: 28rpx; color: #222; }
.field-value-empty { color: #ccc; }
.field-hint { font-size: 22rpx; color: #ff2442; }
.field-col { padding: 24rpx 0; }
.field-textarea { font-size: 28rpx; color: #222; line-height: 1.6; min-height: 120rpx; width: 100%; margin-top: 16rpx; }

.section-title { padding: 24rpx 24rpx 8rpx; }
.section-title-text { font-size: 26rpx; color: #999; }
.privacy-hint { padding: 0 24rpx 8rpx; }
.privacy-hint-text { font-size: 22rpx; color: #ccc; }

/* 弹窗 */
.overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.4); z-index: 1000; display: flex; align-items: center; justify-content: center; animation: overlayIn .2s ease; }
@keyframes overlayIn { from { opacity: 0; } to { opacity: 1; } }
.modal { width: 600rpx; background: #fff; border-radius: 20rpx; padding: 40rpx 32rpx; animation: modalIn .25s ease; }
@keyframes modalIn { from { transform: scale(0.9); opacity: 0; } to { transform: scale(1); opacity: 1; } }
.modal-title { font-size: 32rpx; font-weight: 600; color: #222; display: block; text-align: center; }
.modal-desc { font-size: 24rpx; color: #999; display: block; text-align: center; margin-top: 12rpx; }
.modal-field { display: flex; align-items: center; margin-top: 28rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; padding: 0 16rpx; height: 80rpx; transition: border-color .2s; }
.modal-field:focus-within { border-color: #ff2442; }
.modal-input { flex: 1; font-size: 28rpx; color: #222; height: 80rpx; }
.modal-code-btn { flex-shrink: 0; padding: 0 16rpx; min-width: 140rpx; text-align: center; }
.modal-code-text { font-size: 24rpx; color: #ff2442; }
.code-btn-disabled .modal-code-text { color: #ccc; }
.code-btn-sending .modal-code-text { color: #ff8a9e; }
.modal-btns { display: flex; gap: 20rpx; margin-top: 32rpx; }
.modal-btn { flex: 1; height: 76rpx; border-radius: 38rpx; display: flex; align-items: center; justify-content: center; transition: opacity .15s; }
.modal-btn:active { opacity: 0.7; }
.modal-cancel { background: #f5f5f5; }
.modal-btn-text { font-size: 28rpx; color: #666; }
.modal-confirm { background: linear-gradient(135deg, #ff2442, #ff5a6e); box-shadow: 0 4rpx 16rpx rgba(255,36,66,0.2); }
.modal-btn-text-confirm { font-size: 28rpx; color: #fff; font-weight: 600; }
.logout-section { margin: 0 24rpx; background: #fff; border-radius: 16rpx; padding: 28rpx 0; text-align: center; transition: background .15s; }
.logout-section:active { background: #f8f8f8; }
.logout-text { font-size: 28rpx; color: #ff2442; font-weight: 500; }
</style>
