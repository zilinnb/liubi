<template>
	<view class="page-publish">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="close-icon">✕</text></view>
				<text class="nav-center">{{ isEdit ? '编辑笔记' : '发布笔记' }}</text>
				<view class="nav-right">
					<view class="pub-btn" :class="{ 'pub-ready': canPublish }" @tap="onPublish">
						<text class="pub-btn-text" :class="{ 'pub-btn-text-ready': canPublish }">{{ publishing ? '提交中...' : (isEdit ? '保存' : '发布') }}</text>
					</view>
				</view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="pub-body" :show-scrollbar="false">
			<view class="field-section">
				<input class="title-field" v-model="form.title" placeholder="填写标题会有更多赞哦～" maxlength="30" />
			</view>

			<view class="topic-row" @tap="onTopic">
				<text class="topic-row-hash">#</text>
				<text class="topic-row-name" v-if="form.categoryName">{{ form.categoryName }}</text>
				<text class="topic-row-placeholder" v-else>选择话题（必选）</text>
				<text class="topic-row-arrow">›</text>
			</view>

			<view class="blocks-editor">
				<view class="block-item" v-for="(block, idx) in blocks" :key="idx">
					<view class="block-text" v-if="block.type === 'text'">
						<textarea class="block-textarea" v-model="block.content" placeholder="写点什么..." maxlength="2000" :auto-height="true" />
					</view>

					<view class="block-image" v-else-if="block.type === 'image'">
						<view class="block-head">
							<text class="block-type-label">图片</text>
							<view class="layout-opts">
								<view class="layout-opt" :class="{ 'layout-on': block.layout === 'grid' }" @tap="block.layout='grid'"><text class="layout-opt-text" :class="{ 'layout-on': block.layout === 'grid' }">九宫格</text></view>
								<view class="layout-opt" :class="{ 'layout-on': block.layout === 'double' }" @tap="block.layout='double'"><text class="layout-opt-text" :class="{ 'layout-on': block.layout === 'double' }">双列</text></view>
								<view class="layout-opt" :class="{ 'layout-on': block.layout === 'stack' }" @tap="block.layout='stack'"><text class="layout-opt-text" :class="{ 'layout-on': block.layout === 'stack' }">堆叠</text></view>
								<view class="layout-opt" :class="{ 'layout-on': block.layout === 'full' }" @tap="block.layout='full'"><text class="layout-opt-text" :class="{ 'layout-on': block.layout === 'full' }">大图</text></view>
							</view>
							<view class="block-del" @tap="removeBlock(idx)"><text class="block-del-x">✕</text></view>
						</view>
						<view class="block-img-grid" :class="{ 'grid-double': block.layout === 'double' }" v-if="block.layout === 'grid' || block.layout === 'double'">
							<view class="img-grid-item" v-for="(img, i) in block.images" :key="i">
								<image class="img-grid-img" :src="img.thumb" mode="aspectFill" @tap="previewBlockImage(idx, i)" />
								<view class="img-del-btn" @tap="removeBlockImage(idx, i)"><text class="del-x">✕</text></view>
							</view>
							<view class="img-grid-add" v-if="block.images.length < 9" @tap="pickBlockImage(idx)">
								<text class="add-icon">+</text>
							</view>
						</view>
						<view class="block-img-stack" v-else-if="block.layout === 'stack'">
							<view class="stack-wrap" :style="{ height: Math.min(400, 200 + block.images.length * 40) + 'rpx' }">
								<view class="stack-card" v-for="(img, i) in block.images" :key="i" :style="{ transform: 'translateX(' + (i*16) + 'rpx) translateY(' + (i*8) + 'rpx)', zIndex: block.images.length - i }">
									<image class="stack-img" :src="img.thumb" mode="aspectFill" />
								</view>
							</view>
							<view class="stack-actions">
								<view class="stack-add" v-if="block.images.length < 9" @tap="pickBlockImage(idx)"><text class="stack-add-text">+ 添加</text></view>
								<view class="stack-del" v-if="block.images.length" @tap="removeBlockImage(idx, block.images.length-1)"><text class="stack-del-text">移除最后</text></view>
							</view>
						</view>
						<view class="block-img-full" v-else-if="block.layout === 'full'">
							<view class="img-full-item" v-for="(img, i) in block.images" :key="i">
								<image class="img-full-img" :src="img.thumb" mode="widthFix" @tap="previewBlockImage(idx, i)" />
								<view class="img-del-btn" @tap="removeBlockImage(idx, i)"><text class="del-x">✕</text></view>
							</view>
							<view class="img-add-full" v-if="block.images.length < 9" @tap="pickBlockImage(idx)">
								<text class="add-icon-sm">+ 添加图片</text>
							</view>
						</view>
					</view>

					<view class="block-voice" v-else-if="block.type === 'voice'">
						<view class="block-head">
							<text class="block-type-label">语音</text>
							<view class="block-del" @tap="removeBlock(idx)"><text class="block-del-x">✕</text></view>
						</view>
						<!-- 未录音状态：显示占位，点击开始录音 -->
						<view class="voice-block-inner voice-block-empty" v-if="!block.tempPath && !block.isRecording" @tap="startRecordForBlock(idx)">
							<view class="voice-record-hint">
								<view class="rec-hint-icon">
									<view class="rec-hint-dot"></view>
								</view>
								<text class="rec-hint-text">点击开始录音</text>
							</view>
						</view>
						<!-- 录音中状态 -->
						<view class="voice-block-inner voice-block-recording" v-else-if="block.isRecording" @tap="stopRecordForBlock(idx)">
							<view class="rec-live-wave">
								<view class="rec-live-bar" v-for="i in 12" :key="i" :style="{ animationDelay: (i * 80) + 'ms', height: recWaveH(i) }"></view>
							</view>
							<text class="rec-live-text">录音中，点击停止</text>
							<text class="rec-live-time">{{ recordingSec }}"</text>
						</view>
						<!-- 已录音状态：显示播放界面 -->
						<view class="voice-block-inner" v-else @tap="playBlockVoice(idx)">
							<view class="voice-play-btn" :class="{ 'voice-playing': playingBlockIdx === idx }">
								<view class="voice-play-bar" v-for="b in 3" :key="b" :class="{ 'bar-anim': playingBlockIdx === idx }"></view>
							</view>
							<view class="voice-wave">
								<view class="wave-bar" v-for="i in 24" :key="i" :class="{ 'wave-active': playingBlockIdx === idx }" :style="{ height: waveHeight(i), animationDelay: (i * 40) + 'ms' }"></view>
							</view>
							<text class="voice-time">{{ fmtVoiceTime(block.duration) }}</text>
						</view>
					</view>
				</view>

				<view class="editor-toolbar">
					<view class="tb-btn" @tap="addBlockAtEnd('text')">
						<view class="tb-icon tb-icon-text"><text class="tb-letter">T</text></view>
						<text class="tb-label">文字</text>
					</view>
					<view class="tb-btn" @tap="addBlockAtEnd('image')">
						<view class="tb-icon tb-icon-img"><image class="tb-img" src="/static/icons/images.png" mode="aspectFit" /></view>
						<text class="tb-label">图片</text>
					</view>
					<view class="tb-btn" @tap="addBlockAtEnd('voice')">
						<view class="tb-icon tb-icon-voice">
							<view class="tb-voice-bars"><view class="tvb-bar" v-for="i in 3" :key="i"></view></view>
						</view>
						<text class="tb-label">语音</text>
					</view>
				</view>
			</view>

			<view class="pub-tools">
				<view class="tool-row" @tap="onLinkPanel">
					<image class="tool-icon" src="/static/icons/link.png" mode="aspectFit" />
					<text class="tool-val" v-if="form.link">已添加链接</text>
					<text class="tool-placeholder" v-else>添加链接</text>
					<text class="tool-del" v-if="form.link" @tap.stop="form.link=''">✕</text>
					<text class="tool-arrow" v-else>›</text>
				</view>
			</view>
		</scroll-view>

		<view class="overlay" v-if="showTopicPanel" @tap="showTopicPanel=false">
			<view class="bottom-popup" @tap.stop>
				<view class="popup-handle"></view>
				<view class="topic-search-bar">
					<view class="topic-search-wrap">
						<text class="topic-search-hash">#</text>
						<input class="topic-search-input" v-model="topicKeyword" placeholder="搜索话题" :focus="true" @input="searchTopics" />
					</view>
					<view class="topic-cancel" @tap="showTopicPanel=false"><text class="cancel-text">取消</text></view>
				</view>
				<scroll-view scroll-y class="topic-list" :show-scrollbar="false">
					<view class="topic-item" v-for="c in filteredCategories" :key="c.id" :class="{ 'topic-selected': form.categoryId === c.id }" @tap="selectTopic(c)">
						<text class="topic-hash">#</text>
						<text class="topic-name">{{ c.name }}</text>
						<text class="topic-check" v-if="form.categoryId === c.id">✓</text>
					</view>
				</scroll-view>
			</view>
		</view>

		<view class="overlay" v-if="showVoiceSheet" @tap="showVoiceSheet=false">
			<view class="bottom-popup voice-popup" @tap.stop>
				<view class="popup-handle"></view>
				<view class="voice-popup-title"><text class="voice-popup-title-text">添加语音</text></view>
				<view class="voice-popup-opts">
					<view class="voice-opt" @tap="startRecording">
						<view class="voice-opt-icon voice-opt-rec">
							<view class="rec-circle">
								<view class="rec-mic-bar" v-for="i in 3" :key="i"></view>
							</view>
						</view>
						<text class="voice-opt-label">录音</text>
						<text class="voice-opt-desc">最长60秒</text>
					</view>
					<view class="voice-opt" @tap="chooseAudioFile">
						<view class="voice-opt-icon voice-opt-file">
							<view class="file-box">
								<view class="file-line"></view>
								<view class="file-line-sm"></view>
							</view>
						</view>
						<text class="voice-opt-label">从手机选择</text>
						<text class="voice-opt-desc">相册/文件管理器</text>
					</view>
					<view class="voice-opt" @tap="inputAudioPath">
						<view class="voice-opt-icon" style="background:#f0f0f0;">
							<text style="font-size:32rpx;color:#666;">#</text>
						</view>
						<text class="voice-opt-label">手动输入</text>
						<text class="voice-opt-desc">输入文件路径</text>
					</view>
				</view>
				<view class="voice-popup-cancel" @tap="showVoiceSheet=false"><text class="voice-cancel-text">取消</text></view>
			</view>
		</view>

		<view class="overlay" v-if="showLinkPanel" @tap="showLinkPanel=false">
			<view class="bottom-popup" @tap.stop>
				<view class="popup-handle"></view>
				<view class="link-panel-head"><text class="link-panel-title">添加链接</text></view>
				<input class="link-panel-input" v-model="linkInput" placeholder="输入链接地址" :focus="true" />
				<view class="link-panel-actions">
					<view class="link-panel-cancel" @tap="showLinkPanel=false"><text class="link-cancel-text">取消</text></view>
					<view class="link-panel-confirm" @tap="confirmLink"><text class="link-confirm-text">添加</text></view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, computed, onBeforeUnmount } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { usePostStore } from '@/store/quote.js'
import { useUserStore } from '@/store/user.js'
import { uploadFile, request, BASE_URL } from '@/utils/request.js'

const postStore = usePostStore()
const userStore = useUserStore()
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const publishing = ref(false)
const isEdit = ref(false)
const editId = ref(null)

const blocks = ref([{ type: 'text', content: '' }])

const showTopicPanel = ref(false)
const topicKeyword = ref('')
const catList = ref([])
const showVoiceSheet = ref(false)
const voiceBlockIdx = ref(-1)
const showLinkPanel = ref(false)
const linkInput = ref('')

const isRecording = ref(false)
const recordingSec = ref(0)
const recordStartTime = ref(0)
const playingBlockIdx = ref(-1)
let recorderManager = null
let innerAudioContext = null
let recTimer = null

const form = ref({ title: '', content: '', link: '', categoryId: null, categoryName: '' })

const canPublish = computed(() => {
	if (!form.value.title.trim()) return false
	if (!form.value.categoryId) return false
	return blocks.value.some(b => (b.type === 'text' && b.content.trim()) || (b.type === 'image' && b.images && b.images.length) || (b.type === 'voice' && b.tempPath))
})

const filteredCategories = computed(() => {
	const isAdmin = userStore.userInfo && userStore.userInfo.role === 1
	const available = isAdmin ? catList.value : catList.value.filter(c => c.publish_restriction !== 1)
	const kw = topicKeyword.value.trim().toLowerCase()
	if (!kw) return available
	return available.filter(c => c.name.toLowerCase().includes(kw))
})

function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api', '') + url }
function waveHeight(i) { return Math.max(6, 10 + Math.sin(i * 0.6) * 8 + Math.sin(i * 1.3 + 2) * 6) + 'rpx' }
function recWaveH(i) { return Math.max(8, 12 + Math.sin(i * 0.7) * 10) + 'rpx' }
function fmtVoiceTime(s) { s = s || 0; const m = Math.floor(s / 60); const sec = s % 60; return m > 0 ? m + "'" + (sec < 10 ? '0' : '') + sec + '"' : sec + '"' }

function onTopic() { topicKeyword.value = ''; showTopicPanel.value = true }
function searchTopics() {}
function selectTopic(c) { form.value.categoryId = c.id; form.value.categoryName = c.name; showTopicPanel.value = false }

function addBlockAtEnd(type) {
	if (type === 'text') {
		blocks.value.push({ type: 'text', content: '' })
	} else if (type === 'image') {
		blocks.value.push({ type: 'image', images: [], layout: 'grid' })
	} else if (type === 'voice') {
		showVoiceSheet.value = true
	}
}

function removeBlock(idx) { if (blocks.value.length <= 1) return; blocks.value.splice(idx, 1) }

function pickBlockImage(blockIdx) {
	const block = blocks.value[blockIdx]
	const remaining = 9 - (block.images ? block.images.length : 0)
	if (remaining <= 0) return uni.showToast({ title: '最多9张图片', icon: 'none' })
	uni.chooseImage({
		count: remaining, sizeType: ['compressed'], sourceType: ['album', 'camera'],
		success: (res) => {
			if (!block.images) block.images = []
			res.tempFilePaths.forEach(path => {
				uni.getImageInfo({
					src: path,
					success: (info) => {
						const ratio = info.width && info.height ? (info.width / info.height) : 1.2
						block.images.push({ thumb: path, tempImagePath: path, existingUrl: '', ratio: Math.round(ratio * 100) / 100 })
					},
					fail: () => { block.images.push({ thumb: path, tempImagePath: path, existingUrl: '', ratio: 1.2 }) }
				})
			})
		}
	})
}

function removeBlockImage(blockIdx, imgIdx) { blocks.value[blockIdx].images.splice(imgIdx, 1) }
function previewBlockImage(blockIdx, imgIdx) { const urls = blocks.value[blockIdx].images.map(m => m.thumb); uni.previewImage({ urls, current: urls[imgIdx] }) }

function startRecording() {
	showVoiceSheet.value = false
	blocks.value.push({ type: 'voice', tempPath: '', serverUrl: '', duration: 0, isRecording: false })
}

function startRecordForBlock(idx) {
	if (isRecording.value) {
		uni.showToast({ title: '请先停止当前录音', icon: 'none' })
		return
	}
	voiceBlockIdx.value = idx
	blocks.value[idx].isRecording = true
	recordStartTime.value = Date.now()
	recordingSec.value = 0
	recorderManager.start({ format: 'mp3', duration: 60000, sampleRate: 44100, numberOfChannels: 1, encodeBitRate: 128000 })
	isRecording.value = true
	recTimer = setInterval(() => {
		recordingSec.value = Math.round((Date.now() - recordStartTime.value) / 1000)
		if (recordingSec.value >= 60) recorderManager.stop()
	}, 1000)
}

function stopRecordForBlock(idx) {
	if (!isRecording.value) return
	recorderManager.stop()
}

function doStartRecording(idx) {
	recordStartTime.value = Date.now(); recordingSec.value = 0
	recorderManager.start({ format: 'mp3', duration: 60000, sampleRate: 44100, numberOfChannels: 1, encodeBitRate: 128000 })
	isRecording.value = true
	recTimer = setInterval(() => { recordingSec.value = Math.round((Date.now() - recordStartTime.value) / 1000); if (recordingSec.value >= 60) recorderManager.stop() }, 1000)
}

function toggleRecord() { if (isRecording.value) recorderManager.stop() }

function chooseAudioFile() {
	showVoiceSheet.value = false
	const idx = blocks.value.length
	blocks.value.push({ type: 'voice', tempPath: '', serverUrl: '', duration: 0 })
	voiceBlockIdx.value = idx
	// #ifdef APP-PLUS
	// App端：先尝试使用chooseFile，失败则提示用户
	uni.chooseFile({
		count: 1,
		type: 'all',
		success: (res) => {
			if (res.tempFilePaths && res.tempFilePaths.length) {
				setAudioFile(idx, res.tempFilePaths[0])
			}
		},
		fail: (err) => {
			console.log('chooseFile fail:', err)
			// 如果失败，删除刚添加的空块
			blocks.value.splice(idx, 1)
			voiceBlockIdx.value = -1
			const errMsg = err && err.errMsg ? err.errMsg : '未知错误'
			uni.showModal({
				title: '选择文件失败',
				content: '错误信息：' + errMsg + '\n\n是否手动输入文件路径？',
				confirmColor: '#ff2442',
				success: (r) => {
					if (r.confirm) {
						inputAudioPath()
					}
				}
			})
		}
	})
	// #endif
	// #ifndef APP-PLUS
	uni.chooseMessageFile({
		count: 1,
		type: 'file',
		extension: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'],
		success: (res) => {
			if (res.tempFiles && res.tempFiles.length) {
				setAudioFile(idx, res.tempFiles[0].path, res.tempFiles[0].size)
			}
		},
		fail: () => {
			uni.showToast({ title: '请选择音频文件', icon: 'none' })
		}
	})
	// #endif
}

function inputAudioPath() {
	showVoiceSheet.value = false
	const idx = blocks.value.length
	blocks.value.push({ type: 'voice', tempPath: '', serverUrl: '', duration: 0 })
	voiceBlockIdx.value = idx
	uni.showModal({
		title: '输入音频路径',
		editable: true,
		placeholderText: '如: /storage/emulated/0/Music/xxx.mp3',
		confirmColor: '#ff2442',
		success: (r) => {
			if (r.confirm && r.content && r.content.trim()) {
				const path = r.content.trim()
				if (!path.match(/\.(mp3|wav|aac|m4a|ogg|flac)$/i)) {
					uni.showToast({ title: '请选择音频格式文件', icon: 'none' })
					return
				}
				setAudioFile(idx, path)
			}
		}
	})
}

function setAudioFile(idx, filePath, fileSize) {
	const block = blocks.value[idx]
	block.tempPath = filePath; block.duration = 0
	const audio = uni.createInnerAudioContext()
	audio.src = filePath
	audio.onCanplay(() => { block.duration = Math.round(audio.duration) || 0; audio.destroy() })
	audio.onError(() => { if (fileSize) block.duration = Math.max(1, Math.round(fileSize / 16000)); audio.destroy() })
}

function playBlockVoice(idx) {
	if (playingBlockIdx.value === idx) { if (innerAudioContext) innerAudioContext.stop(); playingBlockIdx.value = -1; return }
	const block = blocks.value[idx]
	if (!block || !block.tempPath) return
	if (innerAudioContext) innerAudioContext.stop()
	innerAudioContext = uni.createInnerAudioContext()
	innerAudioContext.src = block.tempPath
	innerAudioContext.onPlay(() => { playingBlockIdx.value = idx })
	innerAudioContext.onEnded(() => { playingBlockIdx.value = -1 })
	innerAudioContext.onError(() => { playingBlockIdx.value = -1 })
	innerAudioContext.play()
}

function onLinkPanel() { linkInput.value = form.value.link || ''; showLinkPanel.value = true }
function confirmLink() { if (linkInput.value.trim()) form.value.link = linkInput.value.trim(); showLinkPanel.value = false }
function goBack() { uni.navigateBack() }

onLoad(async (query) => {
	if (!userStore.isLoggedIn) { uni.showToast({ title: '请先登录', icon: 'none' }); setTimeout(() => uni.navigateTo({ url: '/pages/login/login' }), 1000); return }
	await postStore.fetchCategories(); catList.value = postStore.categories

	recorderManager = uni.getRecorderManager()
	recorderManager.onStop((res) => {
		const idx = voiceBlockIdx.value >= 0 ? voiceBlockIdx.value : blocks.value.findIndex(b => b.type === 'voice')
		if (idx >= 0 && blocks.value[idx]) {
			blocks.value[idx].tempPath = res.tempFilePath
			blocks.value[idx].duration = Math.max(1, Math.round((Date.now() - recordStartTime.value) / 1000))
			blocks.value[idx].isRecording = false
		}
		isRecording.value = false; clearInterval(recTimer); recordingSec.value = 0; voiceBlockIdx.value = -1
	})
	recorderManager.onError(() => {
		const idx = voiceBlockIdx.value >= 0 ? voiceBlockIdx.value : -1
		if (idx >= 0 && blocks.value[idx]) blocks.value[idx].isRecording = false
		isRecording.value = false; clearInterval(recTimer); recordingSec.value = 0; voiceBlockIdx.value = -1
		uni.showToast({ title: '录音失败', icon: 'none' })
	})

	if (query.id) {
		isEdit.value = true; editId.value = query.id
		const res = await request({ url: '/posts/' + query.id })
		if (res.code === 200 && res.data) {
			const p = res.data
			form.value.title = p.title || ''; form.value.content = p.content || ''; form.value.link = p.link || ''
			form.value.categoryId = p.category_id || null; form.value.categoryName = p.category_name || ''
			if (p.content_blocks && Array.isArray(p.content_blocks)) {
				blocks.value = p.content_blocks
			} else {
				const newBlocks = []
				if (p.content) newBlocks.push({ type: 'text', content: p.content })
				if (p.images && p.images.length) newBlocks.push({ type: 'image', images: p.images.map(img => { const url = typeof img === 'object' ? img.url : img; return { thumb: fullUrl(url), tempImagePath: '', existingUrl: url, ratio: (typeof img === 'object' ? img.ratio : 1.2) || 1.2 } }), layout: 'grid' })
				if (p.voice_url) newBlocks.push({ type: 'voice', tempPath: fullUrl(p.voice_url), serverUrl: p.voice_url, duration: p.voice_duration || 0 })
				if (!newBlocks.length) newBlocks.push({ type: 'text', content: '' })
				blocks.value = newBlocks
			}
		}
	}
})

onBeforeUnmount(() => { if (innerAudioContext) { innerAudioContext.stop(); innerAudioContext = null }; clearInterval(recTimer); if (isRecording.value && recorderManager) recorderManager.stop() })

async function onPublish() {
	if (!canPublish.value) return uni.showToast({ title: '请填写必要内容', icon: 'none' })
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	if (publishing.value) return
	publishing.value = true; uni.showLoading({ title: '发布中...', mask: true })

	const contentBlocks = []
	let allText = ''
	let allImages = []
	let voiceUrl = '', voiceDur = 0

	for (const block of blocks.value) {
		if (block.type === 'text' && block.content && block.content.trim()) {
			allText += block.content + '\n'
			contentBlocks.push({ type: 'text', content: block.content })
		} else if (block.type === 'image' && block.images && block.images.length) {
			const uploadedImgs = []
			for (const img of block.images) {
				if (img.existingUrl) { uploadedImgs.push({ url: img.existingUrl, ratio: img.ratio || 1.2 }); allImages.push({ url: img.existingUrl, type: 'image', video_url: '', ratio: img.ratio || 1.2 }); continue }
				if (!img.tempImagePath) continue
				try { const imgRes = await uploadFile('/upload/single', img.tempImagePath); if (imgRes.code === 200 && imgRes.data && imgRes.data.url) { uploadedImgs.push({ url: imgRes.data.url, ratio: img.ratio || 1.2 }); allImages.push({ url: imgRes.data.url, type: 'image', video_url: '', ratio: img.ratio || 1.2 }) } } catch (e) {}
			}
			contentBlocks.push({ type: 'image', images: uploadedImgs, layout: block.layout || 'grid' })
		} else if (block.type === 'voice' && block.tempPath) {
			let vUrl = block.serverUrl || ''
			if (!vUrl && !block.tempPath.startsWith('http')) {
				try { const vRes = await uploadFile('/upload/single', block.tempPath); if (vRes.code === 200 && vRes.data && vRes.data.url) vUrl = vRes.data.url } catch (e) {}
			} else if (!vUrl && block.tempPath.startsWith('http')) { vUrl = block.tempPath }
			if (vUrl) { voiceUrl = vUrl; voiceDur = block.duration || 0 }
			contentBlocks.push({ type: 'voice', url: vUrl, duration: block.duration || 0 })
		}
	}

	let postType = 3
	if (!allImages.length && !allText.trim() && voiceUrl) postType = 2
	else if (!allImages.length && !voiceUrl) postType = 1

	const postData = {
		title: form.value.title.trim(), content: allText.trim(), content_blocks: contentBlocks,
		category_id: form.value.categoryId,
		post_type: postType, link: form.value.link || '', text_template: 0,
		voice_url: voiceUrl, voice_duration: voiceDur, images: allImages
	}

	let res = isEdit.value ? await postStore.updatePost(editId.value, postData) : await postStore.createPost(postData)
	uni.hideLoading(); publishing.value = false
	if (res && res.code === 200) { uni.showToast({ title: isEdit.value ? '保存成功' : '发布成功', icon: 'success' }); setTimeout(() => uni.navigateBack(), 1500) }
	else { uni.showToast({ title: (res && res.msg) || '操作失败', icon: 'none', duration: 3000 }) }
}
</script>

<style lang="scss" scoped>
.page-publish { min-height: 100vh; background: #fff; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 20rpx; position: relative; }
.nav-left { padding: 8rpx 12rpx; min-width: 60rpx; }
.close-icon { font-size: 30rpx; color: #333; }
.nav-center { font-size: 30rpx; font-weight: 600; color: #222; position: absolute; left: 50%; transform: translateX(-50%); }
.nav-right { min-width: 60rpx; display: flex; justify-content: flex-end; }
.pub-btn { padding: 8rpx 28rpx; border-radius: 28rpx; background: #f5f5f5; transition: background .2s; }
.pub-ready { background: #ff2442; }
.pub-btn-text { font-size: 26rpx; color: #999; }
.pub-btn-text-ready { color: #fff; font-weight: 600; }

.field-section { padding: 20rpx 28rpx; border-bottom: 1rpx solid #f5f5f5; }
.title-field { font-size: 34rpx; font-weight: 600; color: #222; }

.topic-row { display: flex; align-items: center; padding: 20rpx 28rpx; border-bottom: 1rpx solid #f5f5f5; }
.topic-row:active { background: #fafafa; }
.topic-row-hash { font-size: 32rpx; color: #ff2442; font-weight: 700; margin-right: 8rpx; }
.topic-row-name { font-size: 28rpx; color: #ff2442; font-weight: 500; flex: 1; }
.topic-row-placeholder { font-size: 28rpx; color: #ccc; flex: 1; }
.topic-row-arrow { font-size: 28rpx; color: #ccc; }

.blocks-editor { padding: 16rpx 28rpx; }
.block-item { margin-bottom: 8rpx; }
.block-text { position: relative; }
.block-textarea { font-size: 28rpx; color: #333; line-height: 1.8; min-height: 120rpx; width: 100%; }
.block-del { position: absolute; top: 0; right: 0; width: 44rpx; height: 44rpx; display: flex; align-items: center; justify-content: center; }
.block-del-x { font-size: 22rpx; color: #333; }

.block-image, .block-voice { background: #fafafa; border-radius: 12rpx; padding: 16rpx; }
.block-head { display: flex; align-items: center; margin-bottom: 12rpx; gap: 8rpx; position: relative; }
.block-type-label { font-size: 22rpx; color: #999; font-weight: 500; margin-right: 8rpx; }
.layout-opts { display: flex; gap: 6rpx; flex: 1; }
.layout-opt { padding: 4rpx 12rpx; border-radius: 12rpx; background: #f0f0f0; }
.layout-on { background: #fff0f0; border: 1rpx solid #ff2442; }
.layout-opt-text { font-size: 20rpx; color: #999; }
.layout-opt-text.layout-on { color: #ff2442; }

.block-img-grid { display: flex; flex-wrap: wrap; gap: 8rpx; }
.grid-double .img-grid-item { width: calc(50% - 4rpx); }
.grid-double .img-grid-add { width: calc(50% - 4rpx); }
.img-grid-item { position: relative; width: calc(33.33% - 6rpx); aspect-ratio: 1; border-radius: 8rpx; overflow: hidden; }
.img-grid-img { width: 100%; height: 100%; }
.img-grid-add { width: calc(33.33% - 6rpx); aspect-ratio: 1; border-radius: 8rpx; border: 2rpx dashed #ddd; display: flex; align-items: center; justify-content: center; }
.add-icon { font-size: 48rpx; color: #ccc; }
.add-icon-sm { font-size: 26rpx; color: #ccc; }
.img-del-btn { position: absolute; top: 4rpx; right: 4rpx; width: 32rpx; height: 32rpx; border-radius: 50%; background: rgba(0,0,0,0.55); display: flex; align-items: center; justify-content: center; z-index: 2; }
.del-x { font-size: 16rpx; color: #fff; }

.block-img-stack { position: relative; }
.stack-wrap { position: relative; margin: 0 auto; width: 80%; }
.stack-card { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border-radius: 12rpx; overflow: hidden; box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.1); }
.stack-img { width: 100%; height: 100%; }
.stack-actions { display: flex; gap: 16rpx; justify-content: center; margin-top: 16rpx; }
.stack-add, .stack-del { padding: 8rpx 24rpx; border-radius: 20rpx; }
.stack-add { background: #fff0f0; }
.stack-del { background: #f0f0f0; }
.stack-add-text { font-size: 24rpx; color: #ff2442; }
.stack-del-text { font-size: 24rpx; color: #999; }

.block-img-full { display: flex; flex-direction: column; gap: 8rpx; }
.img-full-item { position: relative; border-radius: 8rpx; overflow: hidden; }
.img-full-img { width: 100%; }
.img-add-full { padding: 20rpx; border: 2rpx dashed #ddd; border-radius: 8rpx; text-align: center; }

.voice-block-inner { display: flex; align-items: center; padding: 8rpx 0; }
.voice-block-empty { justify-content: center; padding: 24rpx 0; }
.voice-record-hint { display: flex; align-items: center; gap: 12rpx; }
.rec-hint-icon { width: 48rpx; height: 48rpx; border-radius: 50%; background: #fff0f0; display: flex; align-items: center; justify-content: center; }
.rec-hint-dot { width: 16rpx; height: 16rpx; border-radius: 50%; background: #ff2442; animation: hintPulse 1.5s ease infinite; }
@keyframes hintPulse { 0%,100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.3); opacity: 0.7; } }
.rec-hint-text { font-size: 28rpx; color: #ff2442; font-weight: 500; }
.voice-block-recording { background: #fff0f0; border-radius: 12rpx; padding: 16rpx 24rpx; margin: 4rpx 0; }
.rec-live-wave { display: flex; align-items: center; gap: 4rpx; margin-right: 16rpx; }
.rec-live-bar { width: 4rpx; background: #ff2442; border-radius: 2rpx; min-height: 8rpx; animation: liveWave 0.6s ease-in-out infinite alternate; }
@keyframes liveWave { 0% { transform: scaleY(0.5); opacity: 0.5; } 100% { transform: scaleY(1); opacity: 1; } }
.rec-live-text { font-size: 26rpx; color: #666; flex: 1; }
.rec-live-time { font-size: 28rpx; color: #ff2442; font-weight: 600; }
.voice-play-btn { width: 48rpx; height: 48rpx; border-radius: 50%; background: #ff2442; display: flex; align-items: center; justify-content: center; gap: 3rpx; margin-right: 12rpx; flex-shrink: 0; }
.voice-play-bar { width: 4rpx; background: #fff; border-radius: 2rpx; }
.voice-play-bar:nth-child(1) { height: 10rpx; }
.voice-play-bar:nth-child(2) { height: 18rpx; }
.voice-play-bar:nth-child(3) { height: 10rpx; }
.bar-anim { animation: barBounce 0.5s ease-in-out infinite alternate; }
.voice-play-bar:nth-child(1).bar-anim { animation-delay: 0s; }
.voice-play-bar:nth-child(2).bar-anim { animation-delay: 0.15s; }
.voice-play-bar:nth-child(3).bar-anim { animation-delay: 0.3s; }
@keyframes barBounce { 0% { transform: scaleY(0.5); } 100% { transform: scaleY(1.5); } }
.voice-playing { animation: voicePulse 1s ease infinite; }
@keyframes voicePulse { 0%,100% { transform: scale(1); } 50% { transform: scale(1.08); } }
.voice-wave { display: flex; align-items: center; gap: 3rpx; flex: 1; }
.wave-bar { width: 4rpx; background: #ff2442; border-radius: 2rpx; min-height: 4rpx; opacity: 0.6; }
.wave-active { animation: waveAnim 0.6s ease-in-out infinite alternate; }
@keyframes waveAnim { 0% { opacity: 0.3; transform: scaleY(0.6); } 100% { opacity: 1; transform: scaleY(1); } }
.voice-time { font-size: 24rpx; color: #666; margin-left: 12rpx; flex-shrink: 0; }

.editor-toolbar { display: flex; align-items: center; justify-content: center; gap: 40rpx; padding: 24rpx 0 16rpx; border-top: 1rpx solid #f0f0f0; margin-top: 12rpx; }
.tb-btn { display: flex; flex-direction: column; align-items: center; gap: 6rpx; }
.tb-btn:active { opacity: 0.7; }
.tb-icon { width: 72rpx; height: 72rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.tb-icon-text { background: #fff7e6; }
.tb-letter { font-size: 32rpx; color: #faad14; font-weight: 700; }
.tb-icon-img { background: #e6f7ff; }
.tb-img { width: 36rpx; height: 36rpx; }
.tb-icon-voice { background: #fff0f0; }
.tb-voice-bars { display: flex; align-items: center; gap: 4rpx; }
.tvb-bar { width: 5rpx; background: #ff2442; border-radius: 2rpx; }
.tvb-bar:nth-child(1) { height: 12rpx; }
.tvb-bar:nth-child(2) { height: 20rpx; }
.tvb-bar:nth-child(3) { height: 12rpx; }
.tb-label { font-size: 22rpx; color: #666; }

.pub-tools { padding: 8rpx 28rpx 24rpx; border-top: 1rpx solid #f5f5f5; }
.tool-row { display: flex; align-items: center; padding: 16rpx 0; border-bottom: 1rpx solid #f8f8f8; }
.tool-row:active { background: #fafafa; }
.tool-icon { width: 32rpx; height: 32rpx; margin-right: 12rpx; }
.tool-val { flex: 1; font-size: 26rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tool-placeholder { flex: 1; font-size: 26rpx; color: #ccc; }
.tool-del { font-size: 24rpx; color: #333; padding: 4rpx 12rpx; }
.tool-arrow { font-size: 28rpx; color: #ccc; }

.overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.4); z-index: 1000; display: flex; align-items: flex-end; }
.bottom-popup { width: 100%; background: #fff; border-radius: 24rpx 24rpx 0 0; padding: 20rpx 24rpx; padding-bottom: constant(safe-area-inset-bottom); padding-bottom: env(safe-area-inset-bottom); animation: slideUp .3s cubic-bezier(0.32,0.72,0,1); }
@keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
.popup-handle { width: 64rpx; height: 8rpx; border-radius: 4rpx; background: #e0e0e0; margin: 0 auto 20rpx; }

.topic-search-bar { display: flex; align-items: center; gap: 12rpx; margin-bottom: 16rpx; }
.topic-search-wrap { flex: 1; display: flex; align-items: center; background: #f5f5f5; border-radius: 36rpx; padding: 0 20rpx; height: 72rpx; }
.topic-search-hash { font-size: 30rpx; color: #ff2442; font-weight: 700; margin-right: 8rpx; }
.topic-search-input { flex: 1; font-size: 28rpx; height: 72rpx; }
.topic-cancel { padding: 8rpx 12rpx; }
.cancel-text { font-size: 28rpx; color: #999; }
.topic-list { max-height: 50vh; }
.topic-item { display: flex; align-items: center; padding: 20rpx 16rpx; border-bottom: 1rpx solid #f8f8f8; }
.topic-item:active { background: #fafafa; }
.topic-hash { font-size: 30rpx; color: #ff2442; font-weight: 700; margin-right: 8rpx; }
.topic-name { font-size: 28rpx; color: #333; flex: 1; }
.topic-check { font-size: 28rpx; color: #ff2442; font-weight: 700; }
.topic-selected { background: #fff0f0; }

.link-panel-head { margin-bottom: 12rpx; }

.voice-popup { padding-bottom: 40rpx; }
.voice-popup-title { text-align: center; margin-bottom: 32rpx; }
.voice-popup-title-text { font-size: 32rpx; font-weight: 600; color: #222; }
.voice-popup-opts { display: flex; gap: 32rpx; margin-bottom: 32rpx; padding: 0 40rpx; }
.voice-opt { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 12rpx; padding: 32rpx 0; background: #f8f9fa; border-radius: 20rpx; }
.voice-opt:active { background: #f0f1f3; }
.voice-opt-icon { width: 80rpx; height: 80rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.voice-opt-rec { background: #fff0f0; }
.rec-circle { width: 36rpx; height: 36rpx; border-radius: 50%; background: #ff2442; display: flex; align-items: center; justify-content: center; gap: 3rpx; }
.rec-mic-bar { width: 4rpx; background: #fff; border-radius: 2rpx; }
.rec-mic-bar:nth-child(1) { height: 12rpx; }
.rec-mic-bar:nth-child(2) { height: 18rpx; }
.rec-mic-bar:nth-child(3) { height: 12rpx; }
.voice-opt-file { background: #e6f7ff; }
.file-box { width: 32rpx; height: 36rpx; background: #1890ff; border-radius: 4rpx; position: relative; }
.file-box::before { content: ''; position: absolute; top: 0; right: 0; width: 10rpx; height: 10rpx; background: #e6f7ff; border-bottom-left-radius: 4rpx; }
.file-line { position: absolute; top: 14rpx; left: 6rpx; right: 6rpx; height: 4rpx; background: #fff; border-radius: 2rpx; }
.file-line-sm { position: absolute; top: 22rpx; left: 6rpx; width: 12rpx; height: 4rpx; background: #fff; border-radius: 2rpx; }
.voice-opt-label { font-size: 28rpx; color: #222; font-weight: 500; }
.voice-opt-desc { font-size: 22rpx; color: #999; }
.voice-popup-cancel { text-align: center; padding: 16rpx; }
.voice-cancel-text { font-size: 28rpx; color: #999; }
.link-panel-title { font-size: 30rpx; font-weight: 600; color: #222; }
.link-panel-input { width: 100%; height: 80rpx; background: #f5f5f5; border-radius: 12rpx; padding: 0 24rpx; font-size: 28rpx; box-sizing: border-box; margin-bottom: 16rpx; }
.link-panel-actions { display: flex; gap: 16rpx; }
.link-panel-cancel { flex: 1; height: 72rpx; border-radius: 36rpx; background: #f5f5f5; display: flex; align-items: center; justify-content: center; }
.link-cancel-text { font-size: 28rpx; color: #666; }
.link-panel-confirm { flex: 1; height: 72rpx; border-radius: 36rpx; background: #ff2442; display: flex; align-items: center; justify-content: center; }
.link-confirm-text { font-size: 28rpx; color: #fff; font-weight: 600; }
</style>
