<template>
	<view class="md-root">
		<template v-for="(block, i) in blocks" :key="i">
			<view v-if="block.type === 'code'" class="code-block">
				<view class="code-header">
					<view class="code-dots">
						<view class="dot dot-red"></view>
						<view class="dot dot-yellow"></view>
						<view class="dot dot-green"></view>
					</view>
					<text class="code-lang">{{ block.lang || 'code' }}</text>
					<view class="code-copy" @tap="copyCode(block.content)">
						<text class="copy-text">{{ copied === i ? '已复制' : '复制' }}</text>
					</view>
				</view>
				<scroll-view scroll-x class="code-body-scroll" :show-scrollbar="false">
					<text class="code-content" selectable>{{ block.content }}</text>
				</scroll-view>
			</view>

			<view v-else-if="block.type === 'h1'" class="md-h1"><text class="h1-text">{{ block.text }}</text></view>
			<view v-else-if="block.type === 'h2'" class="md-h2"><text class="h2-text">{{ block.text }}</text></view>
			<view v-else-if="block.type === 'h3'" class="md-h3"><text class="h3-text">{{ block.text }}</text></view>

			<view v-else-if="block.type === 'ul'" class="md-ul">
				<view class="ul-item" v-for="(li, j) in block.items" :key="j">
					<view class="ul-dot-wrap"><view class="ul-dot"></view></view>
					<text class="ul-text"><text v-for="(seg, k) in li" :key="k" :class="seg.cls">{{ seg.text }}</text></text>
				</view>
			</view>

			<view v-else-if="block.type === 'ol'" class="md-ol">
				<view class="ol-item" v-for="(li, j) in block.items" :key="j">
					<text class="ol-num">{{ j + 1 }}.</text>
					<text class="ol-text"><text v-for="(seg, k) in li" :key="k" :class="seg.cls">{{ seg.text }}</text></text>
				</view>
			</view>

			<view v-else-if="block.type === 'quote'" class="md-quote">
				<view class="quote-bar"></view>
				<text class="quote-text"><text v-for="(seg, k) in block.segs" :key="k" :class="seg.cls">{{ seg.text }}</text></text>
			</view>

			<view v-else-if="block.type === 'hr'" class="md-hr"></view>

			<view v-else class="md-p">
				<text class="p-text"><text v-for="(seg, k) in block.segs" :key="k" :class="seg.cls">{{ seg.text }}</text></text>
			</view>
		</template>
	</view>
</template>

<script setup>
import { ref, watch, computed } from 'vue'

const props = defineProps({ content: { type: String, default: '' } })
const copied = ref(-1)

function parseInline(text) {
	const segs = []
	const regex = /(`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*)/g
	let last = 0
	let m
	while ((m = regex.exec(text)) !== null) {
		if (m.index > last) {
			segs.push({ text: text.slice(last, m.index), cls: '' })
		}
		if (m[2] !== undefined) {
			segs.push({ text: m[2], cls: 'inline-code' })
		} else if (m[3] !== undefined) {
			segs.push({ text: m[3], cls: 'bold' })
		} else if (m[4] !== undefined) {
			segs.push({ text: m[4], cls: 'italic' })
		}
		last = regex.lastIndex
	}
	if (last < text.length) {
		segs.push({ text: text.slice(last), cls: '' })
	}
	return segs.length ? segs : [{ text, cls: '' }]
}

function parseMd(src) {
	if (!src) return []
	const blocks = []
	const lines = src.split('\n')
	let i = 0
	while (i < lines.length) {
		const line = lines[i]
		if (line.trim().startsWith('```')) {
			const lang = line.trim().slice(3).trim()
			const codeLines = []
			i++
			while (i < lines.length && !lines[i].trim().startsWith('```')) {
				codeLines.push(lines[i])
				i++
			}
			i++
			blocks.push({ type: 'code', lang, content: codeLines.join('\n') })
			continue
		}
		if (line.startsWith('### ')) { blocks.push({ type: 'h3', text: line.slice(4).trim() }); i++; continue }
		if (line.startsWith('## ')) { blocks.push({ type: 'h2', text: line.slice(3).trim() }); i++; continue }
		if (line.startsWith('# ')) { blocks.push({ type: 'h1', text: line.slice(2).trim() }); i++; continue }
		if (line.trim() === '---' || line.trim() === '***') { blocks.push({ type: 'hr' }); i++; continue }
		if (line.startsWith('> ')) {
			const quoteLines = []
			while (i < lines.length && lines[i].startsWith('> ')) { quoteLines.push(lines[i].slice(2)); i++ }
			blocks.push({ type: 'quote', segs: parseInline(quoteLines.join(' ')) })
			continue
		}
		if (/^[-*]\s/.test(line.trim())) {
			const items = []
			while (i < lines.length && /^[-*]\s/.test(lines[i].trim())) { items.push(parseInline(lines[i].trim().replace(/^[-*]\s/, ''))); i++ }
			blocks.push({ type: 'ul', items })
			continue
		}
		if (/^\d+\.\s/.test(line.trim())) {
			const items = []
			while (i < lines.length && /^\d+\.\s/.test(lines[i].trim())) { items.push(parseInline(lines[i].trim().replace(/^\d+\.\s/, ''))); i++ }
			blocks.push({ type: 'ol', items })
			continue
		}
		if (line.trim()) {
			blocks.push({ type: 'p', segs: parseInline(line) })
		}
		i++
	}
	return blocks
}

const blocks = computed(() => parseMd(props.content))

function copyCode(code) {
	uni.setClipboardData({
		data: code,
		success: () => {
			copied.value = blocks.value.findIndex(b => b.content === code)
			setTimeout(() => { copied.value = -1 }, 2000)
		}
	})
}
</script>

<style lang="scss" scoped>
.md-root { }

.md-h1 { margin: 20rpx 0 12rpx; }
.h1-text { font-size: 34rpx; font-weight: 700; color: #222; }
.md-h2 { margin: 18rpx 0 10rpx; }
.h2-text { font-size: 30rpx; font-weight: 700; color: #333; }
.md-h3 { margin: 14rpx 0 8rpx; }
.h3-text { font-size: 28rpx; font-weight: 600; color: #444; }

.md-p { margin: 8rpx 0; line-height: 1.8; }
.p-text { font-size: 28rpx; color: #333; line-height: 1.8; }

.md-ul { margin: 8rpx 0; }
.ul-item { display: flex; align-items: flex-start; margin: 6rpx 0; }
.ul-dot-wrap { width: 32rpx; flex-shrink: 0; display: flex; justify-content: center; padding-top: 14rpx; }
.ul-dot { width: 8rpx; height: 8rpx; border-radius: 50%; background: #ff2442; }
.ul-text { font-size: 28rpx; color: #333; line-height: 1.8; flex: 1; }

.md-ol { margin: 8rpx 0; }
.ol-item { display: flex; align-items: flex-start; margin: 6rpx 0; }
.ol-num { font-size: 28rpx; color: #ff2442; font-weight: 600; width: 40rpx; flex-shrink: 0; }
.ol-text { font-size: 28rpx; color: #333; line-height: 1.8; flex: 1; }

.md-quote { display: flex; margin: 12rpx 0; padding: 12rpx 16rpx; background: #fafafa; border-radius: 8rpx; }
.quote-bar { width: 6rpx; background: #ff2442; border-radius: 3rpx; margin-right: 16rpx; flex-shrink: 0; }
.quote-text { font-size: 26rpx; color: #666; line-height: 1.7; flex: 1; }

.md-hr { height: 1rpx; background: #eee; margin: 20rpx 0; }

.code-block { margin: 16rpx 0; border-radius: 16rpx; overflow: hidden; background: #1e1e1e; }
.code-header { display: flex; align-items: center; padding: 16rpx 20rpx; background: #2d2d2d; }
.code-dots { display: flex; gap: 10rpx; }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.dot-red { background: #ff5f57; }
.dot-yellow { background: #febc2e; }
.dot-green { background: #28c840; }
.code-lang { flex: 1; font-size: 22rpx; color: #888; margin-left: 16rpx; }
.code-copy { padding: 6rpx 16rpx; background: rgba(255,255,255,0.08); border-radius: 8rpx; }
.copy-text { font-size: 22rpx; color: #ccc; }
.code-body-scroll { padding: 16rpx 20rpx; max-height: 600rpx; }
.code-content { font-size: 24rpx; color: #d4d4d4; font-family: Menlo, Monaco, 'Courier New', monospace; line-height: 1.6; white-space: pre; }

.bold { font-weight: 700; color: #222; }
.italic { font-style: italic; }
.inline-code { background: #f0f0f0; color: #ff2442; padding: 2rpx 8rpx; border-radius: 6rpx; font-size: 24rpx; font-family: Menlo, Monaco, 'Courier New', monospace; }
</style>
