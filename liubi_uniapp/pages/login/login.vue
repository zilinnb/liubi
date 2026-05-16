<template>
	<view class="page-login">
		<view class="login-bg">
			<view class="bg-circle bg-c1"></view>
			<view class="bg-circle bg-c2"></view>
			<view class="bg-circle bg-c3"></view>
		</view>

		<view class="login-header" :style="{ paddingTop: (statusBarH + 60) + 'px' }">
			<view class="logo-wrap">
				<view class="logo-icon">
					<text class="logo-text">留</text>
				</view>
			</view>
			<text class="brand-name">留笔</text>
			<text class="brand-slogan">标记我的生活</text>
		</view>

		<view class="form-area">
			<view class="tab-row">
				<view class="tab" :class="{ 'tab-on': mode === 'login' }" @tap="switchMode('login')">
					<text class="tab-text" :class="{ 'tab-text-on': mode === 'login' }">登录</text>
					<view class="tab-line" v-if="mode === 'login'"></view>
				</view>
				<view class="tab" :class="{ 'tab-on': mode === 'register' }" @tap="switchMode('register')">
					<text class="tab-text" :class="{ 'tab-text-on': mode === 'register' }">注册</text>
					<view class="tab-line" v-if="mode === 'register'"></view>
				</view>
			</view>

			<view v-if="mode === 'login'" class="form-panel">
				<view class="login-type-row">
					<view class="lt-btn" :class="{ 'lt-on': loginType === 'code' }" @tap="loginType='code'">
						<text class="lt-text" :class="{ 'lt-text-on': loginType === 'code' }">验证码登录</text>
					</view>
					<view class="lt-btn" :class="{ 'lt-on': loginType === 'password' }" @tap="loginType='password'">
						<text class="lt-text" :class="{ 'lt-text-on': loginType === 'password' }">密码登录</text>
					</view>
				</view>

				<view v-if="loginType === 'code'" class="form-box">
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">✉</text></view>
						<input class="field-input" v-model="loginForm.email" placeholder="请输入邮箱或留笔号" type="text" />
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">⑂</text></view>
						<input class="field-input code-input" v-model="loginForm.code" placeholder="请输入验证码" type="number" maxlength="6" />
						<view class="code-btn" :class="{ 'code-btn-off': loginCooldown > 0 || loginSending }" @tap="onSendLoginCode">
							<text class="code-btn-text" v-if="loginSending">发送中...</text>
							<text class="code-btn-text" v-else-if="loginCooldown > 0">{{ loginCooldown }}s后重发</text>
							<text class="code-btn-text" v-else>获取验证码</text>
						</view>
					</view>
					<button class="submit-btn" @tap="onLoginByCode" :disabled="loading">
						<text class="btn-text">{{ loading ? '登录中...' : '登录' }}</text>
					</button>
				</view>

				<view v-else class="form-box">
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">✉</text></view>
						<input class="field-input" v-model="pwdForm.email" placeholder="请输入邮箱或留笔号" type="text" />
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">⊛</text></view>
						<input class="field-input" v-model="pwdForm.password" placeholder="请输入密码" :password="!showPwd" />
						<view class="pwd-eye" @tap="showPwd=!showPwd">
							<text class="pwd-eye-text">{{ showPwd ? '◉' : '○' }}</text>
						</view>
					</view>
					<button class="submit-btn" @tap="onLoginByPwd" :disabled="loading">
						<text class="btn-text">{{ loading ? '登录中...' : '登录' }}</text>
					</button>
					<view class="link-row">
						<text class="link-text" @tap="switchMode('forgot')">忘记密码？</text>
					</view>
				</view>
			</view>

			<view v-if="mode === 'register'" class="form-panel">
				<view class="form-box">
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">✉</text></view>
						<input class="field-input" v-model="regForm.email" placeholder="请输入邮箱地址" type="text" />
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">⑂</text></view>
						<input class="field-input code-input" v-model="regForm.code" placeholder="请输入验证码" type="number" maxlength="6" />
						<view class="code-btn" :class="{ 'code-btn-off': regCooldown > 0 || regSending }" @tap="onSendRegCode">
							<text class="code-btn-text" v-if="regSending">发送中...</text>
							<text class="code-btn-text" v-else-if="regCooldown > 0">{{ regCooldown }}s后重发</text>
							<text class="code-btn-text" v-else>获取验证码</text>
						</view>
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">☻</text></view>
						<input class="field-input" v-model="regForm.nickname" placeholder="设置昵称（选填）" maxlength="20" />
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">⊛</text></view>
						<input class="field-input" v-model="regForm.password" placeholder="设置密码（至少6位）" :password="true" />
					</view>
					<button class="submit-btn" @tap="onRegister" :disabled="loading">
						<text class="btn-text">{{ loading ? '注册中...' : '注册' }}</text>
					</button>
					<view class="hint-row">
						<text class="hint-text">注册即自动生成9位数字账号，登录后可查看</text>
					</view>
				</view>
			</view>

			<view v-if="mode === 'forgot'" class="form-panel">
				<view class="forgot-header">
					<text class="forgot-title">重置密码</text>
					<text class="forgot-desc">通过邮箱验证码重置你的密码</text>
				</view>
				<view class="form-box">
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">✉</text></view>
						<input class="field-input" v-model="forgotForm.email" placeholder="请输入注册邮箱" type="text" />
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">⑂</text></view>
						<input class="field-input code-input" v-model="forgotForm.code" placeholder="请输入验证码" type="number" maxlength="6" />
						<view class="code-btn" :class="{ 'code-btn-off': forgotCooldown > 0 || forgotSending }" @tap="onSendForgotCode">
							<text class="code-btn-text" v-if="forgotSending">发送中...</text>
							<text class="code-btn-text" v-else-if="forgotCooldown > 0">{{ forgotCooldown }}s后重发</text>
							<text class="code-btn-text" v-else>获取验证码</text>
						</view>
					</view>
					<view class="field">
						<view class="field-icon-wrap"><text class="field-icon-svg">⊛</text></view>
						<input class="field-input" v-model="forgotForm.newPassword" placeholder="设置新密码（至少6位）" :password="true" />
					</view>
					<button class="submit-btn" @tap="onResetPassword" :disabled="loading">
						<text class="btn-text">{{ loading ? '提交中...' : '重置密码' }}</text>
					</button>
					<view class="link-row">
						<text class="link-text" @tap="switchMode('login')">← 返回登录</text>
					</view>
				</view>
			</view>
		</view>

		<view class="login-footer">
			<text class="footer-text">登录即代表同意</text>
			<text class="footer-link">《用户协议》</text>
			<text class="footer-text">和</text>
			<text class="footer-link">《隐私政策》</text>
		</view>
	</view>
</template>

<script setup>
import { ref } from 'vue'
import { useUserStore } from '@/store/user.js'

const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const mode = ref('login')
const loginType = ref('code')
const loading = ref(false)
const showPwd = ref(false)

const loginForm = ref({ email: '', code: '' })
const pwdForm = ref({ email: '', password: '' })
const regForm = ref({ email: '', code: '', nickname: '', password: '' })
const forgotForm = ref({ email: '', code: '', newPassword: '' })

const loginCooldown = ref(0)
const regCooldown = ref(0)
const forgotCooldown = ref(0)
const loginSending = ref(false)
const regSending = ref(false)
const forgotSending = ref(false)

function startCooldown(timerRef, seconds = 60) {
	timerRef.value = seconds
	const interval = setInterval(() => {
		timerRef.value--
		if (timerRef.value <= 0) clearInterval(interval)
	}, 1000)
}

function switchMode(m) {
	mode.value = m
	loading.value = false
}

async function sendCodeWithFeedback(email, type, cooldownRef, sendingRef) {
	if (cooldownRef.value > 0 || sendingRef.value) return
	if (!email) {
		uni.showToast({ title: type === 1 ? '请输入邮箱' : '请输入邮箱或留笔号', icon: 'none' })
		return
	}
	sendingRef.value = true
	try {
		const res = await userStore.sendCode(email, type)
		if (res.code === 200) {
			uni.showToast({ title: '验证码已发送', icon: 'success' })
			startCooldown(cooldownRef, 60)
		} else {
			uni.showToast({ title: res.msg || '发送失败', icon: 'none', duration: 2500 })
		}
	} catch (e) {
		uni.showToast({ title: '网络错误，请重试', icon: 'none', duration: 2500 })
	} finally {
		sendingRef.value = false
	}
}

async function onSendLoginCode() { await sendCodeWithFeedback(loginForm.value.email, 2, loginCooldown, loginSending) }
async function onSendRegCode() { await sendCodeWithFeedback(regForm.value.email, 1, regCooldown, regSending) }
async function onSendForgotCode() { await sendCodeWithFeedback(forgotForm.value.email, 3, forgotCooldown, forgotSending) }

async function onLoginByCode() {
	if (!loginForm.value.email || !loginForm.value.code) return uni.showToast({ title: '请填写账号和验证码', icon: 'none' })
	loading.value = true
	try {
		const res = await userStore.loginByCode(loginForm.value.email, loginForm.value.code)
		if (res.code === 200) {
			uni.showToast({ title: '登录成功', icon: 'success' })
			setTimeout(() => uni.switchTab({ url: '/pages/index/index' }), 800)
		} else {
			uni.showToast({ title: res.msg || '登录失败', icon: 'none', duration: 2500 })
		}
	} catch (e) { uni.showToast({ title: '网络错误', icon: 'none' }) }
	finally { loading.value = false }
}

async function onLoginByPwd() {
	if (!pwdForm.value.email || !pwdForm.value.password) return uni.showToast({ title: '请填写账号和密码', icon: 'none' })
	loading.value = true
	try {
		const res = await userStore.login(pwdForm.value.email, pwdForm.value.password)
		if (res.code === 200) {
			uni.showToast({ title: '登录成功', icon: 'success' })
			setTimeout(() => uni.switchTab({ url: '/pages/index/index' }), 800)
		} else {
			uni.showToast({ title: res.msg || '登录失败', icon: 'none', duration: 2500 })
		}
	} catch (e) { uni.showToast({ title: '网络错误', icon: 'none' }) }
	finally { loading.value = false }
}

async function onRegister() {
	if (!regForm.value.email || !regForm.value.code || !regForm.value.password) return uni.showToast({ title: '请填写完整信息', icon: 'none' })
	if (regForm.value.password.length < 6) return uni.showToast({ title: '密码至少6位', icon: 'none' })
	loading.value = true
	try {
		const res = await userStore.register(regForm.value.email, regForm.value.code, regForm.value.password, regForm.value.nickname)
		if (res.code === 200) {
			uni.showToast({ title: '注册成功', icon: 'success' })
			setTimeout(() => uni.switchTab({ url: '/pages/index/index' }), 800)
		} else {
			uni.showToast({ title: res.msg || '注册失败', icon: 'none', duration: 2500 })
		}
	} catch (e) { uni.showToast({ title: '网络错误', icon: 'none' }) }
	finally { loading.value = false }
}

async function onResetPassword() {
	if (!forgotForm.value.email || !forgotForm.value.code || !forgotForm.value.newPassword) return uni.showToast({ title: '请填写完整信息', icon: 'none' })
	if (forgotForm.value.newPassword.length < 6) return uni.showToast({ title: '密码至少6位', icon: 'none' })
	loading.value = true
	try {
		const res = await userStore.changePassword(forgotForm.value.email, forgotForm.value.code, forgotForm.value.newPassword)
		if (res.code === 200) {
			uni.showToast({ title: '密码重置成功', icon: 'success' })
			setTimeout(() => {
				mode.value = 'login'
				loginType.value = 'password'
				pwdForm.value.email = forgotForm.value.email
				forgotForm.value = { email: '', code: '', newPassword: '' }
			}, 800)
		} else {
			uni.showToast({ title: res.msg || '重置失败', icon: 'none', duration: 2500 })
		}
	} catch (e) { uni.showToast({ title: '网络错误', icon: 'none' }) }
	finally { loading.value = false }
}
</script>

<style lang="scss" scoped>
.page-login { min-height: 100vh; background: #fff; display: flex; flex-direction: column; position: relative; overflow: hidden; }

.login-bg { position: absolute; top: 0; left: 0; right: 0; bottom: 0; z-index: 0; pointer-events: none; }
.bg-circle { position: absolute; border-radius: 50%; opacity: 0.06; }
.bg-c1 { width: 600rpx; height: 600rpx; background: #ff2442; top: -200rpx; right: -200rpx; }
.bg-c2 { width: 400rpx; height: 400rpx; background: #ff5a6e; bottom: 200rpx; left: -150rpx; }
.bg-c3 { width: 300rpx; height: 300rpx; background: #ff8a9e; bottom: -100rpx; right: 100rpx; }

.login-header { display: flex; flex-direction: column; align-items: center; position: relative; z-index: 1; animation: headerIn .6s cubic-bezier(0.34, 1.56, 0.64, 1); }
@keyframes headerIn { from { opacity: 0; transform: translateY(-40rpx); } to { opacity: 1; transform: translateY(0); } }

.logo-wrap { margin-bottom: 20rpx; }
.logo-icon { width: 120rpx; height: 120rpx; border-radius: 32rpx; background: linear-gradient(145deg, #ff2442, #ff5a6e); display: flex; align-items: center; justify-content: center; box-shadow: 0 12rpx 40rpx rgba(255,36,66,0.3); }
.logo-text { font-size: 56rpx; color: #fff; font-weight: 800; }
.brand-name { font-size: 44rpx; font-weight: 800; color: #222; letter-spacing: 4rpx; }
.brand-slogan { font-size: 26rpx; color: #999; margin-top: 8rpx; letter-spacing: 2rpx; }

.form-area { padding: 40rpx 48rpx 0; flex: 1; position: relative; z-index: 1; animation: formIn .4s ease .1s both; }
@keyframes formIn { from { opacity: 0; transform: translateY(20rpx); } to { opacity: 1; transform: translateY(0); } }

.tab-row { display: flex; margin-bottom: 36rpx; }
.tab { flex: 1; display: flex; flex-direction: column; align-items: center; padding-bottom: 16rpx; position: relative; }
.tab-text { font-size: 30rpx; color: #bbb; transition: all .25s; }
.tab-text-on { color: #222; font-weight: 700; font-size: 32rpx; }
.tab-line { width: 48rpx; height: 6rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); border-radius: 3rpx; margin-top: 10rpx; animation: lineGrow .25s ease; }
@keyframes lineGrow { from { width: 0; } to { width: 48rpx; } }

.form-panel { animation: panelIn .3s ease; }
@keyframes panelIn { from { opacity: 0; transform: translateX(16rpx); } to { opacity: 1; transform: translateX(0); } }

.login-type-row { display: flex; background: #f5f5f5; border-radius: 12rpx; padding: 4rpx; margin-bottom: 32rpx; }
.lt-btn { flex: 1; padding: 16rpx 0; display: flex; justify-content: center; border-radius: 10rpx; transition: all .25s; }
.lt-on { background: #fff; box-shadow: 0 2rpx 8rpx rgba(0,0,0,0.06); }
.lt-text { font-size: 26rpx; color: #999; transition: color .2s; }
.lt-text-on { color: #222; font-weight: 600; }

.field { margin-bottom: 24rpx; position: relative; display: flex; align-items: center; background: #f7f7f7; border-radius: 16rpx; padding: 0 20rpx; transition: all .2s; border: 2rpx solid transparent; }
.field:focus-within { background: #fff; border-color: #ff2442; box-shadow: 0 0 0 4rpx rgba(255,36,66,0.08); }
.field-icon-wrap { width: 44rpx; height: 44rpx; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.field-icon-svg { font-size: 28rpx; color: #bbb; }
.field-input { height: 88rpx; border: none; font-size: 28rpx; color: #222; padding: 0 12rpx; flex: 1; background: transparent; }

.code-btn { flex-shrink: 0; padding: 0 24rpx; height: 60rpx; display: flex; align-items: center; justify-content: center; border-radius: 30rpx; background: rgba(255,36,66,0.08); transition: all .2s; }
.code-btn:active { transform: scale(0.95); }
.code-btn-off { background: #f0f0f0; }
.code-btn-text { font-size: 24rpx; color: #ff2442; white-space: nowrap; font-weight: 500; }
.code-btn-off .code-btn-text { color: #ccc; }

.pwd-eye { padding: 12rpx; }
.pwd-eye-text { font-size: 28rpx; color: #bbb; }

.submit-btn { margin-top: 32rpx; height: 88rpx; border-radius: 44rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); border: none; line-height: 88rpx; transition: all .2s; box-shadow: 0 8rpx 28rpx rgba(255,36,66,0.25); }
.submit-btn:active { transform: scale(0.98); box-shadow: 0 4rpx 12rpx rgba(255,36,66,0.2); }
.submit-btn[disabled] { opacity: 0.6; }
.btn-text { color: #fff; font-size: 30rpx; font-weight: 600; }

.link-row { margin-top: 24rpx; display: flex; justify-content: center; }
.link-text { font-size: 26rpx; color: #ff2442; font-weight: 500; }

.hint-row { margin-top: 20rpx; text-align: center; }
.hint-text { font-size: 22rpx; color: #ccc; }

.forgot-header { margin-bottom: 32rpx; }
.forgot-title { font-size: 36rpx; font-weight: 700; color: #222; display: block; }
.forgot-desc { font-size: 26rpx; color: #999; display: block; margin-top: 8rpx; }

.login-footer { padding: 40rpx 0 env(safe-area-inset-bottom); text-align: center; position: relative; z-index: 1; }
.footer-text { font-size: 22rpx; color: #ccc; }
.footer-link { font-size: 22rpx; color: #ff2442; }
</style>
