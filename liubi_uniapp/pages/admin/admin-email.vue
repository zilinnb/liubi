<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">邮箱设置</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="body-scroll" :show-scrollbar="false">
			<view class="body-inner">
				<view class="form-card">
					<view class="form-header">
						<text class="form-icon">📧</text>
						<text class="form-title">SMTP邮件配置</text>
					</view>

					<view class="field-group">
						<view class="field">
							<text class="field-label">SMTP服务器</text>
							<input class="field-input" v-model="config.host" placeholder="如 smtp.qq.com" />
						</view>
						<view class="field">
							<text class="field-label">端口</text>
							<input class="field-input" v-model="config.port" placeholder="465" type="number" />
						</view>
						<view class="field">
							<text class="field-label">邮箱账号</text>
							<input class="field-input" v-model="config.user" placeholder="your@qq.com" />
						</view>
						<view class="field">
							<text class="field-label">授权码</text>
							<input class="field-input" v-model="config.pass" placeholder="SMTP授权码" :password="true" />
						</view>
						<view class="field">
							<text class="field-label">发件人</text>
							<input class="field-input" v-model="config.from" placeholder="留笔 <your@qq.com>" />
						</view>
					</view>

					<view class="save-btn" @tap="saveConfig"><text class="save-btn-text">保存配置</text></view>
					<text class="form-hint">配置保存后需重启后端服务生效</text>
				</view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { request } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const config = ref({ host: '', port: '465', user: '', pass: '', from: '' })

async function loadConfig() {
	const res = await request({ url: '/admin/email-config' })
	if (res.code === 200 && res.data) config.value = { ...config.value, ...res.data }
}

async function saveConfig() {
	const res = await request({ url: '/admin/email-config', method: 'PUT', data: config.value })
	if (res.code === 200) uni.showToast({ title: '保存成功，需重启后端', icon: 'none' })
	else uni.showToast({ title: res.msg || '保存失败', icon: 'none' })
}

function goBack() { uni.navigateBack() }
onMounted(() => loadConfig())
</script>

<style lang="scss" scoped>
.page-sub { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 28rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }

.body-scroll { height: calc(100vh - 140rpx); }
.body-inner { padding: 20rpx 28rpx; }
.form-card { background: #fff; border-radius: 16rpx; padding: 32rpx; }
.form-header { display: flex; align-items: center; gap: 12rpx; margin-bottom: 32rpx; padding-bottom: 24rpx; border-bottom: 1rpx solid #f0f0f0; }
.form-icon { font-size: 32rpx; }
.form-title { font-size: 30rpx; font-weight: 600; color: #222; }
.field-group { margin-bottom: 24rpx; }
.field { margin-bottom: 24rpx; }
.field-label { font-size: 26rpx; color: #333; display: block; margin-bottom: 10rpx; }
.field-input { height: 80rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; padding: 0 20rpx; font-size: 28rpx; width: 100%; box-sizing: border-box; }
.save-btn { height: 88rpx; border-radius: 44rpx; background: #ff2442; display: flex; align-items: center; justify-content: center; transition: opacity .15s; }
.save-btn:active { opacity: 0.8; }
.save-btn-text { font-size: 30rpx; color: #fff; font-weight: 600; }
.form-hint { font-size: 22rpx; color: #ccc; display: block; text-align: center; margin-top: 20rpx; }
</style>
