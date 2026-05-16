<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">AI 助手配置</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="body-scroll" :show-scrollbar="false">
			<view class="body-inner">
				<view class="form-card">
					<view class="form-header">
						<text class="form-icon">✦</text>
						<text class="form-title">AI 模型配置</text>
					</view>

					<view class="field-group">
						<view class="field">
							<view class="field-label-row">
								<text class="field-label">API 接口地址</text>
								<text class="field-required">*</text>
							</view>
							<input class="field-input" v-model="config.api_url" placeholder="https://api.deepseek.com/v1/chat/completions" />
							<text class="field-hint">支持 DeepSeek / OpenAI / 通义千问等兼容接口</text>
						</view>
						<view class="field">
							<view class="field-label-row">
								<text class="field-label">API Key</text>
								<text class="field-required">*</text>
							</view>
							<input class="field-input" v-model="config.api_key" placeholder="sk-xxxxxxxxxxxxxxxx" :password="!showKey" />
							<view class="field-extra">
								<view class="toggle-eye" @tap="showKey = !showKey">
									<text class="eye-text">{{ showKey ? '隐藏' : '显示' }}</text>
								</view>
							</view>
						</view>
						<view class="field">
							<view class="field-label-row">
								<text class="field-label">模型名称</text>
								<text class="field-required">*</text>
							</view>
							<input class="field-input" v-model="config.model_name" placeholder="deepseek-chat" />
							<text class="field-hint">如：deepseek-chat / gpt-3.5-turbo / qwen-turbo</text>
						</view>
						<view class="field">
							<text class="field-label">系统提示词</text>
							<textarea class="field-textarea" v-model="config.system_prompt" placeholder="设置AI助手的角色和行为风格..." :maxlength="-1" />
							<text class="field-hint">留空使用默认提示词</text>
						</view>
						<view class="field">
							<view class="switch-row">
								<view class="switch-info">
									<text class="field-label">启用 AI 助手</text>
									<text class="switch-desc">关闭后将使用本地预设回复</text>
								</view>
								<view class="switch-track" :class="{ 'track-on': config.enabled }" @tap="config.enabled = config.enabled ? 0 : 1">
									<view class="switch-thumb" :class="{ 'thumb-on': config.enabled }"></view>
								</view>
							</view>
						</view>
					</view>

					<view class="save-btn" @tap="saveConfig"><text class="save-btn-text">保存配置</text></view>
				</view>

				<view class="form-card" style="margin-top: 24rpx;">
					<view class="form-header">
						<text class="form-icon">📋</text>
						<text class="form-title">常用接口参考</text>
					</view>
					<view class="preset-list">
						<view class="preset-item" @tap="applyPreset('deepseek')">
							<view class="preset-info">
								<text class="preset-name">DeepSeek</text>
								<text class="preset-url">api.deepseek.com</text>
							</view>
							<text class="preset-apply">使用</text>
						</view>
						<view class="preset-item" @tap="applyPreset('openai')">
							<view class="preset-info">
								<text class="preset-name">OpenAI</text>
								<text class="preset-url">api.openai.com</text>
							</view>
							<text class="preset-apply">使用</text>
						</view>
						<view class="preset-item" @tap="applyPreset('qwen')">
							<view class="preset-info">
								<text class="preset-name">通义千问</text>
								<text class="preset-url">dashscope.aliyuncs.com</text>
							</view>
							<text class="preset-apply">使用</text>
						</view>
					</view>
				</view>

				<view class="status-card" :class="{ 'status-on': config.enabled && config.api_key }">
					<view class="status-dot" :class="{ 'dot-on': config.enabled && config.api_key }"></view>
					<text class="status-text">{{ statusText }}</text>
				</view>
			</view>
		</scroll-view>
	</view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { request } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const config = ref({
	api_url: 'https://api.deepseek.com/v1/chat/completions',
	api_key: '',
	model_name: 'deepseek-chat',
	system_prompt: '',
	enabled: 1
})
const showKey = ref(false)

const statusText = computed(() => {
	if (!config.value.enabled) return 'AI 助手已关闭，使用本地预设回复'
	if (!config.value.api_key) return '未配置 API Key，将使用本地预设回复'
	return 'AI 助手已启用 — ' + config.value.model_name
})

async function loadConfig() {
	try {
		const res = await request({ url: '/admin/ai-config' })
		if (res.code === 200 && res.data) {
			config.value = { ...config.value, ...res.data }
		}
	} catch (e) {}
}

async function saveConfig() {
	if (!config.value.api_url.trim()) {
		return uni.showToast({ title: '请填写API接口地址', icon: 'none' })
	}
	uni.showLoading({ title: '保存中...' })
	try {
		const res = await request({ url: '/admin/ai-config', method: 'PUT', data: config.value })
		uni.hideLoading()
		if (res.code === 200) {
			uni.showToast({ title: '保存成功', icon: 'success' })
		} else {
			uni.showToast({ title: res.msg || '保存失败', icon: 'none' })
		}
	} catch (e) {
		uni.hideLoading()
		uni.showToast({ title: '网络错误', icon: 'none' })
	}
}

function applyPreset(type) {
	const presets = {
		deepseek: { api_url: 'https://api.deepseek.com/v1/chat/completions', model_name: 'deepseek-chat' },
		openai: { api_url: 'https://api.openai.com/v1/chat/completions', model_name: 'gpt-3.5-turbo' },
		qwen: { api_url: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', model_name: 'qwen-turbo' }
	}
	const preset = presets[type]
	if (preset) {
		config.value.api_url = preset.api_url
		config.value.model_name = preset.model_name
		uni.showToast({ title: '已填入预设配置', icon: 'none' })
	}
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
.body-inner { padding: 20rpx 28rpx; padding-bottom: 120rpx; }
.form-card { background: #fff; border-radius: 16rpx; padding: 32rpx; }
.form-header { display: flex; align-items: center; gap: 12rpx; margin-bottom: 32rpx; padding-bottom: 24rpx; border-bottom: 1rpx solid #f0f0f0; }
.form-icon { font-size: 32rpx; }
.form-title { font-size: 30rpx; font-weight: 600; color: #222; }

.field-group { margin-bottom: 24rpx; }
.field { margin-bottom: 28rpx; }
.field-label-row { display: flex; align-items: center; gap: 4rpx; margin-bottom: 10rpx; }
.field-label { font-size: 26rpx; color: #333; font-weight: 500; }
.field-required { font-size: 26rpx; color: #ff2442; }
.field-input { height: 80rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; padding: 0 20rpx; font-size: 28rpx; width: 100%; box-sizing: border-box; }
.field-textarea { width: 100%; height: 200rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; padding: 20rpx; font-size: 28rpx; box-sizing: border-box; line-height: 1.6; }
.field-hint { font-size: 22rpx; color: #bbb; display: block; margin-top: 8rpx; }
.field-extra { position: relative; }
.toggle-eye { position: absolute; right: 20rpx; top: -56rpx; padding: 8rpx 12rpx; }
.eye-text { font-size: 24rpx; color: #9945FF; }

.switch-row { display: flex; align-items: center; justify-content: space-between; }
.switch-info { display: flex; flex-direction: column; gap: 4rpx; }
.switch-desc { font-size: 22rpx; color: #bbb; }
.switch-track { width: 96rpx; height: 52rpx; border-radius: 26rpx; background: #e0e0e0; position: relative; transition: background .25s; }
.track-on { background: #9945FF; }
.switch-thumb { width: 44rpx; height: 44rpx; border-radius: 50%; background: #fff; position: absolute; top: 4rpx; left: 4rpx; transition: transform .25s cubic-bezier(0.34, 1.56, 0.64, 1); box-shadow: 0 2rpx 8rpx rgba(0,0,0,0.15); }
.thumb-on { transform: translateX(44rpx); }

.save-btn { height: 88rpx; border-radius: 44rpx; background: linear-gradient(135deg, #9945FF, #14F195); display: flex; align-items: center; justify-content: center; transition: opacity .15s; }
.save-btn:active { opacity: 0.8; }
.save-btn-text { font-size: 30rpx; color: #fff; font-weight: 600; }

.preset-list { }
.preset-item { display: flex; align-items: center; justify-content: space-between; padding: 24rpx 0; border-bottom: 1rpx solid #f5f5f5; }
.preset-item:last-child { border-bottom: none; }
.preset-info { display: flex; flex-direction: column; gap: 4rpx; }
.preset-name { font-size: 28rpx; color: #222; font-weight: 600; }
.preset-url { font-size: 22rpx; color: #999; }
.preset-apply { font-size: 26rpx; color: #9945FF; font-weight: 600; padding: 8rpx 20rpx; border: 1rpx solid #9945FF; border-radius: 20rpx; }
.preset-apply:active { background: rgba(153,69,255,0.1); }

.status-card { display: flex; align-items: center; gap: 12rpx; margin-top: 24rpx; padding: 24rpx 28rpx; background: #fff; border-radius: 16rpx; border-left: 6rpx solid #ccc; }
.status-on { border-left-color: #14F195; }
.status-dot { width: 16rpx; height: 16rpx; border-radius: 50%; background: #ccc; flex-shrink: 0; }
.dot-on { background: #14F195; box-shadow: 0 0 12rpx rgba(20,241,149,0.4); }
.status-text { font-size: 24rpx; color: #666; }
</style>
