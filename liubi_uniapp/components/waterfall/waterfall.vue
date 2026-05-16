<template>
	<view class="waterfall-wrap">
		<view class="waterfall-col" v-for="(col, idx) in columns" :key="idx">
			<view class="waterfall-item" v-for="item in col" :key="item.id">
				<slot name="item" :item="item"></slot>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'

const props = defineProps({
	list: { type: Array, default: () => [] },
	colNum: { type: Number, default: 2 }
})

const columns = ref([])
const listVersion = ref(0)

function estimateHeight(item) {
	let h = 10

	if (item.images && item.images.length) {
		const first = item.images[0]
		let wRatio = 1.2
		if (typeof first === 'object') {
			wRatio = first.ratio || first.width_ratio || 1.2
		} else if (typeof first === 'string') {
			wRatio = 1.2
		}
		const hRatio = 1 / wRatio
		const coverH = Math.round(340 * Math.min(Math.max(hRatio, 0.65), 1.5))
		h += coverH
	} else if (item.cover) {
		h += 340
	} else if (item.post_type === 1) {
		h += 240
	} else if (item.voice_url && !item.content) {
		h += 160
	} else {
		h += 240
	}

	if (item.title) {
		const tLen = item.title.length
		h += tLen > 14 ? 68 : 44
	}

	h += 72

	return h
}

function distribute() {
	if (!props.list.length) {
		columns.value = Array.from({ length: props.colNum }, () => [])
		return
	}

	const cols = Array.from({ length: props.colNum }, () => [])
	const heights = Array(props.colNum).fill(0)

	props.list.forEach(item => {
		const minH = Math.min(...heights)
		const i = heights.indexOf(minH)
		cols[i].push(item)
		heights[i] += estimateHeight(item)
	})

	columns.value = cols
}

watch(() => [props.list, props.list.length, listVersion.value], distribute, { deep: true, immediate: true })

function forceUpdate() {
	listVersion.value++
}

defineExpose({ forceUpdate })
</script>

<style lang="scss" scoped>
.waterfall-wrap {
	display: flex;
	padding: 0 8rpx;
}
.waterfall-col {
	flex: 1;
	padding: 0 4rpx;
}
.waterfall-item {
	margin-bottom: 10rpx;
}
</style>
