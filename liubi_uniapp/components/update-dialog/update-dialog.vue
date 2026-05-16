<template>
	<view class="update-mask" :class="{ 'mask-show': visible && animIn }" v-if="visible" @tap="onMaskTap">
		<view class="update-dialog" :class="{ 'dialog-show': animIn }" @tap.stop>
			<view class="update-header">
				<view class="header-bg">
					<view class="header-circle"></view>
					<view class="header-circle c2"></view>
					<view class="header-circle c3"></view>
				</view>
				<view class="header-content">
					<text class="update-badge">NEW</text>
					<text class="update-title">发现新版本</text>
					<text class="update-version">v{{ info.versionName }}</text>
				</view>
			</view>

			<view class="update-body">
				<view class="update-features" v-if="info.updateContent && info.updateContent.length">
					<view class="feature-item" v-for="(item, idx) in info.updateContent" :key="idx">
						<view class="feature-dot"></view>
						<text class="feature-text">{{ item }}</text>
					</view>
				</view>
				<view class="update-meta" v-if="info.packageSize">
					<text class="meta-text">安装包大小：{{ info.packageSize }}</text>
				</view>
			</view>

			<view class="update-footer">
				<view class="btn-skip" v-if="!info.forceUpdate && !browserOpened" @tap="onSkip">
					<text class="btn-skip-text">稍后再说</text>
				</view>
				<view class="btn-update" :class="{ 'btn-full': info.forceUpdate || browserOpened }" @tap="onUpdate">
					<text class="btn-update-text">{{ btnText }}</text>
				</view>
			</view>

			<view class="progress-bar" v-if="downloading">
				<view class="progress-fill" :style="{ width: progress + '%' }"></view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'

const props = defineProps({
	visible: { type: Boolean, default: false },
	info: { type: Object, default: () => ({}) }
})

const emit = defineEmits(['close', 'update'])

const downloading = ref(false)
const progress = ref(0)
const animIn = ref(false)
const browserOpened = ref(false)

const btnText = computed(() => {
	if (downloading.value) return '下载中 ' + progress.value + '%'
	if (browserOpened.value) return '已跳转浏览器，安装后重开'
	return '立即更新'
})

watch(() => props.visible, (val) => {
	if (val) {
		browserOpened.value = false
		downloading.value = false
		progress.value = 0
		nextTick(() => {
			setTimeout(() => { animIn.value = true }, 30)
		})
	} else {
		animIn.value = false
	}
})

function close() {
	if (props.info.forceUpdate) return
	animIn.value = false
	setTimeout(() => { emit('close') }, 250)
}

function onMaskTap() {
	if (!props.info.forceUpdate && !downloading.value && !browserOpened.value) {
		close()
	}
}

function onSkip() {
	if (downloading.value || browserOpened.value) return
	close()
}

function onUpdate() {
	if (downloading.value) return

	if (props.info.updateType === 1) {
		plus.runtime.openURL(props.info.downloadUrl, (err) => {
			uni.showToast({ title: '无法打开链接', icon: 'none' })
		})
		if (props.info.forceUpdate) {
			browserOpened.value = true
		} else {
			close()
		}
	} else {
		startDownload()
	}
}

function startDownload() {
	downloading.value = true
	progress.value = 0

	const dtask = plus.downloader.createDownload(
		props.info.downloadUrl,
		{ filename: '_doc/update/liubi.apk' },
		(download, status) => {
			downloading.value = false
			if (status === 200) {
				progress.value = 100
				plus.runtime.install(download.filename, { force: true }, () => {
					emit('update')
				}, (err) => {
					uni.showToast({ title: '安装失败', icon: 'none' })
				})
			} else {
				uni.showToast({ title: '下载失败，请重试', icon: 'none' })
			}
		}
	)

	dtask.addEventListener('statechanged', (task) => {
		if (task.state === 3 && task.totalSize > 0) {
			progress.value = Math.floor((task.downloadedSize / task.totalSize) * 100)
		}
	})

	dtask.start()
}
</script>

<style lang="scss" scoped>
.update-mask {
	position: fixed; top: 0; left: 0; right: 0; bottom: 0;
	background: rgba(0,0,0,0); z-index: 10000;
	display: flex; align-items: center; justify-content: center;
	transition: background 0.3s ease;
}
.update-mask.mask-show {
	background: rgba(0,0,0,0.55);
}

.update-dialog {
	width: 600rpx; max-width: 85vw; margin: 0 40rpx; background: #fff; border-radius: 32rpx; overflow: hidden;
	position: relative;
	opacity: 0;
	transform: scale(0.75) translateY(40rpx);
	transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.update-dialog.dialog-show {
	opacity: 1;
	transform: scale(1) translateY(0);
}

.update-header {
	position: relative; height: 260rpx; overflow: hidden;
	background: linear-gradient(135deg, #ff2442, #ff6b81);
}
.header-bg { position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
.header-circle {
	position: absolute; border-radius: 50%; background: rgba(255,255,255,.12);
	width: 200rpx; height: 200rpx; top: -60rpx; right: -40rpx;
	animation: circleFloat 6s ease-in-out infinite;
}
.header-circle.c2 {
	width: 140rpx; height: 140rpx; top: auto; bottom: -30rpx; left: 30rpx; right: auto;
	animation-delay: -2s;
}
.header-circle.c3 {
	width: 80rpx; height: 80rpx; top: 30rpx; left: 160rpx; right: auto; background: rgba(255,255,255,.08);
	animation-delay: -4s;
}
@keyframes circleFloat {
	0%, 100% { transform: translateY(0); }
	50% { transform: translateY(-12rpx); }
}

.header-content {
	position: relative; z-index: 1; padding: 50rpx 40rpx 0;
	display: flex; flex-direction: column; align-items: flex-start;
}
.update-badge {
	font-size: 22rpx; color: #ff2442; background: #fff;
	padding: 4rpx 16rpx; border-radius: 16rpx; font-weight: 700;
	letter-spacing: 2rpx; margin-bottom: 16rpx;
}
.update-title { font-size: 40rpx; color: #fff; font-weight: 700; }
.update-version { font-size: 26rpx; color: rgba(255,255,255,.8); margin-top: 8rpx; }

.update-body { padding: 32rpx 40rpx 24rpx; }
.update-features { margin-bottom: 16rpx; }
.feature-item { display: flex; align-items: flex-start; margin-bottom: 14rpx; }
.feature-dot {
	width: 12rpx; height: 12rpx; border-radius: 50%; background: #ff2442;
	margin-top: 12rpx; margin-right: 16rpx; flex-shrink: 0;
}
.feature-text { font-size: 26rpx; color: #555; line-height: 1.6; flex: 1; }
.update-meta { margin-top: 8rpx; }
.meta-text { font-size: 22rpx; color: #bbb; }

.update-footer {
	display: flex; padding: 0 40rpx 36rpx; gap: 20rpx;
}
.btn-skip {
	flex: 1; height: 80rpx; border-radius: 40rpx;
	border: 1rpx solid #e0e0e0; display: flex; align-items: center; justify-content: center;
	transition: all .2s;
}
.btn-skip:active { background: #f5f5f5; }
.btn-skip-text { font-size: 28rpx; color: #999; }

.btn-update {
	flex: 1; height: 80rpx; border-radius: 40rpx;
	background: linear-gradient(135deg, #ff2442, #ff6b81);
	display: flex; align-items: center; justify-content: center;
	box-shadow: 0 6rpx 20rpx rgba(255,36,66,.3);
	transition: all .2s;
}
.btn-update:active { transform: scale(.96); box-shadow: 0 2rpx 8rpx rgba(255,36,66,.2); }
.btn-update-text { font-size: 28rpx; color: #fff; font-weight: 600; }
.btn-full { flex: 2; }

.progress-bar {
	position: absolute; bottom: 0; left: 0; right: 0; height: 6rpx; background: #f0f0f0;
}
.progress-fill {
	height: 100%; background: linear-gradient(90deg, #ff2442, #ff6b81);
	transition: width .3s ease; border-radius: 3rpx;
}
</style>
