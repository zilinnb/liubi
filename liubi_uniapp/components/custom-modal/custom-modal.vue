<template>
	<view v-if="visible" class="modal-mask" @tap="onMaskTap">
		<view class="modal-box" :class="{ 'modal-in': animShow }" @tap.stop>
			<view v-if="title" class="modal-header">
				<text class="modal-title">{{ title }}</text>
			</view>
			<view class="modal-body">
				<text class="modal-content">{{ content }}</text>
			</view>
			<view class="modal-footer">
				<view v-if="showCancel" class="modal-btn btn-cancel" @tap="onCancel">
					<text class="btn-text btn-cancel-text">{{ cancelText }}</text>
				</view>
				<view class="modal-btn btn-confirm" @tap="onConfirm">
					<text class="btn-text btn-confirm-text">{{ confirmText }}</text>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'

const props = defineProps({
	visible: { type: Boolean, default: false },
	title: { type: String, default: '' },
	content: { type: String, default: '' },
	showCancel: { type: Boolean, default: true },
	cancelText: { type: String, default: '取消' },
	confirmText: { type: String, default: '确定' },
	maskClose: { type: Boolean, default: false }
})

const emit = defineEmits(['confirm', 'cancel', 'update:visible'])

const animShow = ref(false)

watch(() => props.visible, (val) => {
	if (val) {
		nextTick(() => { animShow.value = true })
	} else {
		animShow.value = false
	}
})

function onMaskTap() {
	if (props.maskClose) {
		emit('update:visible', false)
		emit('cancel')
	}
}

function onCancel() {
	animShow.value = false
	setTimeout(() => {
		emit('update:visible', false)
		emit('cancel')
	}, 200)
}

function onConfirm() {
	animShow.value = false
	setTimeout(() => {
		emit('update:visible', false)
		emit('confirm')
	}, 200)
}
</script>

<style lang="scss" scoped>
.modal-mask { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.45); z-index: 10000; display: flex; align-items: center; justify-content: center; animation: maskIn .2s ease; }
@keyframes maskIn { from { opacity: 0; } to { opacity: 1; } }

.modal-box { width: 580rpx; background: #fff; border-radius: 28rpx; overflow: hidden; transform: scale(0.85); opacity: 0; transition: all .25s cubic-bezier(0.34, 1.56, 0.64, 1); }
.modal-in { transform: scale(1); opacity: 1; }

.modal-header { padding: 40rpx 40rpx 0; text-align: center; }
.modal-title { font-size: 32rpx; font-weight: 700; color: #222; }

.modal-body { padding: 28rpx 40rpx 36rpx; text-align: center; }
.modal-content { font-size: 28rpx; color: #666; line-height: 1.6; }

.modal-footer { display: flex; border-top: 1rpx solid #f0f0f0; }
.modal-btn { flex: 1; height: 100rpx; display: flex; align-items: center; justify-content: center; transition: background .1s; }
.modal-btn:active { background: #f5f5f5; }
.btn-cancel { border-right: 1rpx solid #f0f0f0; }
.btn-text { font-size: 30rpx; font-weight: 500; }
.btn-cancel-text { color: #999; }
.btn-confirm-text { color: #ff2442; font-weight: 600; }
</style>
