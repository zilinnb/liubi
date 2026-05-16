<template>
	<view class="page-detail">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><image class="nav-back-img" src="/static/icons/back.png" mode="aspectFit" /></view>
				<view class="nav-right" @tap="onMore"><text class="more-dots">···</text></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<view v-if="post">
			<scroll-view scroll-y class="detail-scroll" :show-scrollbar="false" :style="{ height: scrollH + 'px' }">
					<view class="author-bar">
					<view class="author-left" @tap="goAuthorProfile">
						<image v-if="post.avatar" class="author-av-img" :src="fullUrl(post.avatar)" mode="aspectFill" />
						<view v-else class="author-av" :style="{ background: avatarColor }">
							<text class="av-letter">{{ (post.nickname||post.username||'?').slice(0,1) }}</text>
						</view>
						<view class="author-meta">
							<text class="author-name">{{ post.nickname || post.username }}</text>
							<text class="author-time">{{ fmtTime(post.created_at) }}</text>
						</view>
					</view>
					<view class="follow-btn" :class="{ followed: isFollowed }" @tap="onFollow">
						<text class="follow-label">{{ isFollowed ? '已关注' : '+ 关注' }}</text>
					</view>
				</view>

				<rich-text class="detail-title" :nodes="renderContent(post.title)" user-select></rich-text>

				<view v-if="parsedBlocks && parsedBlocks.length">
					<view v-if="displayStyle === 'texttpl'" class="text-tpl-card" :style="{ background: tplBg }">
						<view class="tpl-content-wrap">
							<rich-text class="tpl-content-text" :nodes="renderContent(post.content)" :style="{ color: tplColor }" user-select></rich-text>
						</view>
						<view class="tpl-bottom-bar">
							<view class="tpl-views">
								<image class="tpl-views-icon" src="/static/icons/liulan.png" mode="aspectFit" />
								<text class="tpl-views-text" :style="{ color: tplColor }">{{ post.views_count || 0 }}</text>
							</view>
						</view>
					</view>

					<view v-else class="block-render">
						<view v-for="(block, bIdx) in parsedBlocks" :key="bIdx" class="render-block">
							<view v-if="block && block.type === 'text' && block.content && block.content.trim()" class="render-text-block">
								<rich-text class="render-text-rt" :nodes="renderContent(block.content)" user-select></rich-text>
							</view>
							<view v-else-if="block && block.type === 'image' && block.images && block.images.length" class="render-img-block">
							<view v-if="block.layout === 'grid'" class="r-grid">
									<view class="r-grid-item" v-for="(img, i) in block.images" :key="i" @tap="previewBlockImg(block, i)">
										<image class="r-grid-img" :src="fullUrl(img.url)" mode="aspectFill" />
									</view>
								</view>
								<view v-else-if="block.layout === 'double'" class="r-double">
									<view class="r-double-item" v-for="(img, i) in block.images" :key="i" @tap="previewBlockImg(block, i)">
										<image class="r-double-img" :src="fullUrl(img.url)" mode="aspectFill" />
									</view>
								</view>
								<view v-else-if="block.layout === 'stack'" class="r-stack">
									<view class="r-stack-wrap" :style="{ height: Math.min(400, 200 + block.images.length * 40) + 'rpx' }">
										<view class="r-stack-card" v-for="(img, i) in block.images" :key="i" :style="{ transform: 'translateX(' + (i*16) + 'rpx) translateY(' + (i*8) + 'rpx)', zIndex: block.images.length - i }" @tap="previewBlockImg(block, i)">
											<image class="r-stack-img" :src="fullUrl(img.url)" mode="aspectFill" />
										</view>
									</view>
								</view>
								<view v-else class="r-full">
									<view class="r-full-item" v-for="(img, i) in block.images" :key="i" @tap="previewBlockImg(block, i)">
										<image class="r-full-img" :src="fullUrl(img.url)" mode="widthFix" />
									</view>
								</view>
							</view>
							<view v-else-if="block && block.type === 'voice' && block.url" class="render-voice-block" @tap="playArticleVoice(bIdx)">
								<view class="voice-inner">
									<view class="voice-play-btn" :class="{ 'voice-playing': articleVoiceIdx === bIdx }">
										<view class="voice-play-bar" v-for="b in 3" :key="b" :class="{ 'bar-anim': articleVoiceIdx === bIdx }"></view>
									</view>
									<view class="voice-wave">
										<view class="v-wave-bar" v-for="i in 24" :key="i" :class="{ 'v-wave-active': articleVoiceIdx === bIdx }" :style="{ height: vWaveH(i), animationDelay: (i*40)+'ms' }"></view>
									</view>
									<text class="voice-dur">{{ fmtVoiceTime(block.duration || 0) }}</text>
								</view>
							</view>
						</view>
					</view>
				</view>

				<view v-if="post.link" class="link-box" @tap="openLink">
					<image class="link-ico-img" src="/static/icons/link.png" mode="aspectFit" />
					<view class="link-card-info">
						<text class="link-card-title">外部链接</text>
						<text class="link-url">{{ post.link }}</text>
					</view>
					<text class="link-arrow">›</text>
				</view>

				<view class="tag-row">
					<text class="tag tag-clickable" v-if="post.category_name" @tap="goTopicPage">#{{ post.category_name }}</text>
				</view>

				<view class="date-row"><text class="date-text">{{ fmtTime(post.created_at) }} {{ post.location ? '· IP属地 '+post.location : '' }}</text></view>
				<view class="interact-row">
					<text class="interact-text">{{ post.views_count||0 }} 浏览</text>
				</view>
				<view class="gap-line"></view>

				<view class="comment-area">
					<view class="comment-header">
						<text class="comment-title">共 {{ comments.length }} 条评论</text>
					</view>
					<view v-if="comments.length">
						<view class="cmt" v-for="c in comments" :key="c.id">
							<image v-if="c.avatar" class="cmt-av-img" :src="fullUrl(c.avatar)" mode="aspectFill" />
							<view v-else class="cmt-av" :style="{ background: cmtColor(c) }"><text class="cmt-av-text">{{ (c.nickname||'?').slice(0,1) }}</text></view>
							<view class="cmt-main">
								<view class="cmt-name-row">
									<text class="cmt-name" @tap="goCmtProfile(c.user_id)">{{ c.nickname }}</text>
									<text class="cmt-author-badge" v-if="c.user_id === (post?.user_id)">作者</text>
									<view v-if="c.is_pinned" class="cmt-pin-tag">
										<text class="cmt-pin-tag-text">作者置顶</text>
									</view>
								</view>
								<text class="cmt-text">{{ c.content }}</text>
								<image v-if="c.image_url" class="cmt-img" :src="fullUrl(c.image_url)" mode="widthFix" @tap="previewCmtImg(c.image_url)" />
								<view class="cmt-bar">
									<view class="cmt-bar-left">
										<text class="cmt-time">{{ fmtTime(c.created_at) }}</text>
										<text class="cmt-location" v-if="c.location">{{ c.location }}</text>
									</view>
									<view class="cmt-acts">
										<text class="cmt-act-text" @tap="startReply(c)">回复</text>
										<text class="cmt-act-text cmt-act-del" v-if="canDeleteComment(c)" @tap="onDeleteComment(c)">删除</text>
										<text class="cmt-act-text cmt-act-pin" v-if="canPinComment()" @tap="onPinComment(c)">{{ c.is_pinned ? '取消置顶' : '置顶' }}</text>
										<view class="cmt-like-row" @tap="onLikeComment(c)">
										<view class="cmt-like-wrap">
											<image class="cmt-like-img" :class="{ 'like-bounce': c._likeBouncing }" :src="c.isLiked ? '/static/icons/like-active.png' : '/static/icons/like.png'" mode="aspectFit" />
										</view>
										<text class="cmt-like-num" :class="{ 'cmt-like-on': c.isLiked, 'num-bounce': c._likeBouncing }">{{ c.likes_count||0 }}</text>
									</view>
									</view>
								</view>
								<view class="sub-list" v-if="c.subComments && c.subComments.length">
									<view class="sub" v-for="sc in c.subComments" :key="sc.id">
										<view class="sub-row">
											<image v-if="sc.avatar" class="sub-av-img" :src="fullUrl(sc.avatar)" mode="aspectFill" />
											<view v-else class="sub-av" :style="{ background: cmtColor(sc) }"><text class="sub-av-text">{{ (sc.nickname||'?').slice(0,1) }}</text></view>
											<view class="sub-main">
												<text class="sub-name" @tap="goCmtProfile(sc.user_id)">{{ sc.nickname }}</text>
												<text class="sub-text">{{ sc.content }}</text>
												<image v-if="sc.image_url" class="cmt-img sub-cmt-img" :src="fullUrl(sc.image_url)" mode="widthFix" @tap="previewCmtImg(sc.image_url)" />
												<view class="sub-bar">
													<text class="sub-time">{{ fmtTime(sc.created_at) }}</text>
													<text class="sub-location" v-if="sc.location">{{ sc.location }}</text>
													<text class="sub-act" @tap="startReply(c, sc)">回复</text>
													<text class="sub-act sub-act-del" v-if="canDeleteComment(sc)" @tap="onDeleteComment(sc, c)">删除</text>
												</view>
											</view>
										</view>
									</view>
								</view>
							</view>
						</view>
					</view>
					<view v-else class="cmt-empty"><text class="cmt-empty-text">还没有评论，来说点什么吧～</text></view>
				</view>
				<view style="height: 160rpx;"></view>
			</scroll-view>

			<view class="bottom-bar safe-area-bottom" @tap="openCommentPopup">
				<view class="stat-bar">
					<view class="stat-item" @tap.stop="onLike">
						<view class="like-icon-wrap">
							<image class="stat-icon" :class="{ 'like-bounce': likeBouncing }" :src="post.isLiked ? '/static/icons/like-active.png' : '/static/icons/like.png'" mode="aspectFit" />
							<view class="like-particles" v-if="likeBouncing">
								<view class="lp" v-for="i in 6" :key="i" :style="{ transform: 'rotate(' + (i * 60) + 'deg)' }">
									<view class="lp-dot"></view>
								</view>
							</view>
						</view>
						<text class="stat-num" :class="{ 'stat-on': post.isLiked, 'num-bounce': likeBouncing }">{{ post.likes_count||0 }}</text>
					</view>
					<view class="stat-item" @tap.stop="onCollect">
						<view class="like-icon-wrap">
							<image class="stat-icon" :class="{ 'like-bounce': collectBouncing }" :src="post.isCollected ? '/static/icons/collect-active.png' : '/static/icons/collect.png'" mode="aspectFit" />
						</view>
						<text class="stat-num" :class="{ 'stat-on': post.isCollected, 'num-bounce': collectBouncing }">{{ post.collects_count||0 }}</text>
					</view>
					<view class="stat-item" @tap.stop="openCommentPopup">
						<image class="stat-icon" src="/static/icons/ping.png" mode="aspectFit" />
						<text class="stat-num">{{ post.comments_count||0 }}</text>
					</view>
					<view class="stat-input-trigger" @tap.stop="openCommentPopup">
						<text class="stat-input-text">说点什么...</text>
					</view>
				</view>
			</view>

			<view class="comment-popup-mask" :class="{ 'popup-show': commentPopupShow }" @tap="closeCommentPopup">
				<view class="comment-popup" :style="{ bottom: keyboardHeight + 'px' }" @tap.stop>
					<view class="reply-hint" v-if="replyTarget">
						<text class="reply-hint-text">回复 {{ replyTarget.nickname }}</text>
						<text class="reply-cancel" @tap="cancelReply">✕</text>
					</view>
					<view class="popup-input-row">
						<view class="popup-input-area">
							<textarea class="popup-textarea" v-model="commentText" :placeholder="replyTarget ? '回复 '+replyTarget.nickname+'...' : '留下你的想法吧'" :focus="inputFocus" :adjust-position="false" :auto-height="true" :maxlength="-1" @focus="onInputFocus" @blur="onInputBlur" />
						</view>
						<view class="cmt-img-preview" v-if="cmtImgThumb" @tap="removeCmtImg">
							<image class="cmt-img-thumb" :src="cmtImgThumb" mode="aspectFill" />
							<view class="cmt-img-del"><text class="cmt-img-del-x">✕</text></view>
						</view>
						<view class="popup-send-btn" :class="{ 'popup-send-active': commentText.trim() || cmtImgTempPath }" @tap="onSend">
							<text class="popup-send-text">发送</text>
						</view>
					</view>
					<view class="popup-toolbar">
						<view class="toolbar-icon" @tap="pickCmtImage"><image class="toolbar-icon-img" src="/static/icons/images.png" mode="aspectFit" /></view>
						<view class="toolbar-icon" @tap="insertAt"><text class="toolbar-icon-at">@</text></view>
						<view class="toolbar-icon" @tap="toggleEmoji">
							<image v-if="!showEmoji" class="toolbar-icon-img" src="/static/icons/emjo.png" mode="aspectFit" />
							<view v-else class="toolbar-keyboard-icon">
								<view class="tkb-line" v-for="i in 3" :key="i"></view>
							</view>
						</view>
					</view>
					<view class="emoji-panel" v-if="showEmoji" @tap.stop>
						<scroll-view scroll-x class="emoji-scroll-h" :show-scrollbar="false">
							<view class="emoji-grid-h">
								<view class="emoji-item-h" v-for="(e, i) in emojiList" :key="i" @tap="insertEmoji(e)"><text class="emoji-char-h">{{ e }}</text></view>
							</view>
						</scroll-view>
					</view>
				</view>
			</view>
		</view>
		<custom-modal
			:visible="modalVisible"
			:title="modalTitle"
			:content="modalContent"
			:confirmText="modalConfirmText"
			:showCancel="true"
			@confirm="onModalConfirm"
			@cancel="onModalCancel"
		/>
	</view>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { usePostStore } from '@/store/quote.js'
import { useUserStore } from '@/store/user.js'
import { request, BASE_URL, uploadFile } from '@/utils/request.js'
import customModal from '@/components/custom-modal/custom-modal.vue'

const postStore = usePostStore()
const userStore = useUserStore()

const likeBouncing = ref(false)
const collectBouncing = ref(false)
const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20
const scrollH = sys.windowHeight - (statusBarH + 44) - 60

const postId = ref(null)
const post = ref(null)
const comments = ref([])
const commentText = ref('')
const inputFocus = ref(false)
const isFollowed = ref(false)
const playingLive = ref(-1)
const replyTarget = ref(null)
const replyParentId = ref(null)
const cmtImgThumb = ref('')
const cmtImgTempPath = ref('')
const showEmoji = ref(false)
const commentPopupShow = ref(false)
const keyboardHeight = ref(0)
const modalVisible = ref(false)
const modalTitle = ref('')
const modalContent = ref('')
const modalConfirmText = ref('确定')
let modalResolve = null
const emojiList = ['😀','😁','😂','🤣','😃','','😅','😆','😉','😊','😋','😎','😍','🥰','😘','😗','😙','😚','🙂','🤗','🤔','','😑','😶','🙄','😏','😣','😥','😮','🤐','😯','😪','😫','😴','😌','😛','😜','😝','🤤','😒','','😔','😕','🙃','🤑','😲','🙁','','😞','😟','😤','😢','😭','😦','😧','😨','😩','🤯','😬','😰','😱','🥵','','😳','🤪','😵','😡','😠','🤬','','🤒','🤕','','🤮','🥴','😇','🥳','🥺','🤠','🤡','❤','🧡','','💚','💙','💜','🖤','🤍','💔','💕','👍','👎','','🙏','🤝','','🤞','🤟','','💪','🎉','🎊','💯','🔥','⭐','✨','💫','🌟','💖','']

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
const avatarColor = computed(() => post.value ? COLORS[(post.value.user_id || post.value.id) % COLORS.length] : '#ff2442')
function cmtColor(cmt) { return COLORS[(cmt.user_id || cmt.id) % COLORS.length] }
function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api', '') + url }

const TEXT_TEMPLATES = [
	{ bg: '#ffffff', color: '#222222' },
	{ bg: 'linear-gradient(135deg, #fff8e1, #ffecb3)', color: '#5d4037' },
	{ bg: 'linear-gradient(135deg, #e8f5e9, #c8e6c9)', color: '#2e7d32' },
	{ bg: 'linear-gradient(135deg, #1a1a2e, #16213e)', color: '#e0e0e0' },
	{ bg: 'linear-gradient(135deg, #fce4ec, #f8bbd0)', color: '#880e4f' },
	{ bg: 'linear-gradient(135deg, #e3f2fd, #bbdefb)', color: '#1565c0' },
	{ bg: 'linear-gradient(135deg, #efebe9, #d7ccc8)', color: '#3e2723' },
	{ bg: 'linear-gradient(135deg, #f3e5f5, #e1bee7)', color: '#6a1b9a' }
]
const tplBg = computed(() => { const i = post.value?.text_template || 0; return TEXT_TEMPLATES[i % TEXT_TEMPLATES.length].bg })
const tplColor = computed(() => { const i = post.value?.text_template || 0; return TEXT_TEMPLATES[i % TEXT_TEMPLATES.length].color })

const isVoicePlaying = ref(false)
let voiceAudioCtx = null

const parsedBlocks = computed(() => {
	if (!post.value) return null
	// 优先使用 content_blocks
	if (post.value.content_blocks != null) {
		let blocks = post.value.content_blocks
		// 如果是字符串，尝试解析
		if (typeof blocks === 'string') {
			try { blocks = JSON.parse(blocks) } catch { blocks = null }
		}
		// 确保是数组
		if (Array.isArray(blocks)) {
			// 过滤掉null/undefined元素，保留有效块
			const validBlocks = blocks.filter(b => b != null)
			return validBlocks
		}
	}
	// 降级使用传统字段合成
	const p = post.value
	const synthetic = []
	if (p.content && p.content.trim()) synthetic.push({ type: 'text', content: p.content })
	if (p.images && p.images.length) synthetic.push({ type: 'image', images: p.images.map(img => ({ url: typeof img === 'object' ? img.url : img, ratio: (typeof img === 'object' ? img.ratio : 1.2) || 1.2 })), layout: 'grid' })
	if (p.voice_url) synthetic.push({ type: 'voice', url: p.voice_url, duration: p.voice_duration || 0 })
	console.log('parsedBlocks synthetic:', JSON.stringify(synthetic))
	return synthetic.length ? synthetic : null
})

const displayStyle = computed(() => {
	if (!parsedBlocks.value || !parsedBlocks.value.length) return 'legacy'
	if (post.value?.post_type === 1) return 'texttpl'
	return 'blocks'
})

const articleVoiceIdx = ref(-1)
let articleVoiceCtx = null

function playArticleVoice(idx) {
	const block = parsedBlocks.value?.[idx]
	if (!block || block.type !== 'voice' || !block.url) return
	if (articleVoiceIdx.value === idx) {
		if (articleVoiceCtx) articleVoiceCtx.stop()
		articleVoiceIdx.value = -1
		return
	}
	if (articleVoiceCtx) articleVoiceCtx.stop()
	articleVoiceCtx = uni.createInnerAudioContext()
	articleVoiceCtx.src = fullUrl(block.url)
	articleVoiceCtx.onPlay(() => { articleVoiceIdx.value = idx })
	articleVoiceCtx.onEnded(() => { articleVoiceIdx.value = -1 })
	articleVoiceCtx.onError(() => { articleVoiceIdx.value = -1 })
	articleVoiceCtx.play()
}

function previewBlockImg(block, i) {
	const urls = block.images.map(img => fullUrl(img.url))
	uni.previewImage({ urls, current: i })
}

function playPostVoice() {
	if (!post.value?.voice_url) return
	if (isVoicePlaying.value) { if (voiceAudioCtx) voiceAudioCtx.stop(); isVoicePlaying.value = false; return }
	voiceAudioCtx = uni.createInnerAudioContext()
	voiceAudioCtx.src = fullUrl(post.value.voice_url)
	voiceAudioCtx.onPlay(() => { isVoicePlaying.value = true })
	voiceAudioCtx.onEnded(() => { isVoicePlaying.value = false })
	voiceAudioCtx.onError(() => { isVoicePlaying.value = false })
	voiceAudioCtx.play()
}
function vWaveH(i) { return Math.max(8, 16 + Math.sin(i * 0.7) * 14) + 'rpx' }
function fmtVoiceTime(s) { s = s || 0; const m = Math.floor(s / 60); const sec = s % 60; return m > 0 ? m + "'" + (sec < 10 ? '0' : '') + sec + '"' : sec + '"' }
function openLink() { if (post.value?.link) uni.navigateTo({ url: '/pages/webview/webview?url=' + encodeURIComponent(post.value.link) + '&title=' + encodeURIComponent(post.value.link) }) }

function getImgUrl(img) { if (typeof img === 'object') return img.url || ''; return img }
function getVideoUrl(img) { if (typeof img === 'object') return img.video_url || ''; return '' }
function isLive(img) { return typeof img === 'object' && img.type === 'live' }
function fmtTime(d) { if (!d) return ''; const now = Date.now(), t = new Date(d).getTime(), diff = (now-t)/1000; if (diff<60) return '刚刚'; if (diff<3600) return Math.floor(diff/60)+'分钟前'; if (diff<86400) return Math.floor(diff/3600)+'小时前'; if (diff<604800) return Math.floor(diff/86400)+'天前'; return new Date(d).toLocaleDateString('zh-CN') }

onLoad(async (o) => {
	postId.value = o.id
	await loadPost()
	await loadComments()
	uni.onKeyboardHeightChange(res => {
		if (res.height > 0) {
			keyboardHeight.value = res.height
		} else {
			keyboardHeight.value = 0
		}
	})
})
async function loadPost() { 
	const res = await request({ url: '/posts/' + postId.value }); 
	if (res.code === 200) {
		post.value = res.data
	}
}
async function loadComments() { const res = await request({ url: '/comments/post/' + postId.value }); if (res.code === 200) comments.value = res.data }
function goBack() { uni.navigateBack() }
function renderContent(text) {
	if (!text) return ''
	let html = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
	html = html.replace(/#([^#\s]+)#/g, '<span style="color:#3378e5;font-weight:500;">#$1#</span>')
	html = html.replace(/@(\S+)/g, '<span style="color:#3378e5;font-weight:500;">@$1</span>')
	return html
}
function goAuthorProfile() { if (post.value?.user_id) uni.navigateTo({ url: "/pages/user-profile/user-profile?userId=" + post.value.user_id }) }
function goCmtProfile(userId) { if (userId) uni.navigateTo({ url: '/pages/user-profile/user-profile?userId=' + userId }) }
function goTopicPage() { if (post.value?.category_id) uni.navigateTo({ url: '/pages/category/category?id=' + post.value.category_id }) }

async function onLike() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const res = await postStore.toggleLike(postId.value)
	if (res?.code === 200) {
		post.value = { ...post.value, isLiked: res.data.liked, likes_count: (post.value.likes_count || 0) + (res.data.liked ? 1 : -1) }
		if (res.data.liked) triggerBounce('like')
	}
}
async function onCollect() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const res = await postStore.toggleCollect(postId.value)
	if (res?.code === 200) {
		post.value = { ...post.value, isCollected: res.data.collected, collects_count: (post.value.collects_count || 0) + (res.data.collected ? 1 : -1) }
		if (res.data.collected) triggerBounce('collect')
	}
}
async function onFollow() { if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' }); if (!post.value) return; const res = await userStore.followUser(post.value.user_id); if (res?.code===200) isFollowed.value = res.data.followed }

function triggerBounce(type) {
	if (type === 'like') {
		likeBouncing.value = true
		setTimeout(() => { likeBouncing.value = false }, 600)
	} else if (type === 'collect') {
		collectBouncing.value = true
		setTimeout(() => { collectBouncing.value = false }, 600)
	}
}

async function onMore() {
	const isOwner = post.value && userStore.userInfo && post.value.user_id === userStore.userInfo.id
	const isAdmin = userStore.userInfo && userStore.userInfo.role === 1
	const isPinned = post.value && post.value.is_pinned === 1
	const items = []
	if (isOwner) {
		items.push('编辑笔记')
	}
	if (isAdmin) {
		items.push(isPinned ? '取消置顶' : '置顶帖子')
	}
	if (isOwner) {
		items.push('删除笔记')
	} else if (isAdmin) {
		items.push('删除帖子')
	}
	if (!isOwner && !isAdmin) {
		items.push('不感兴趣', '举报')
	}
	uni.showActionSheet({ itemList: items, success: async (res) => {
		const tap = items[res.tapIndex]
		if (tap === '编辑笔记') uni.navigateTo({ url: '/pages/publish/publish?id=' + postId.value })
		else if (tap === '置顶帖子' || tap === '取消置顶') onPinPost()
		else if (tap === '删除笔记' || tap === '删除帖子') { const confirmed = await customShowModal({ title: '确认删除', content: '删除后不可恢复', confirmText: '删除' }); if (confirmed) { const dr = await request({ url: '/posts/' + postId.value, method: 'DELETE' }); if (dr.code === 200) { uni.showToast({ title: '已删除', icon: 'success' }); setTimeout(() => uni.navigateBack(), 1500) } } }
	} })
}

async function onPinPost() {
	if (!post.value?.category_id) return uni.showToast({ title: '该帖子无分类', icon: 'none' })
	const res = await request({ url: '/posts/' + postId.value + '/pin', method: 'POST', data: { category_id: post.value.category_id } })
	if (res.code === 200) {
		post.value.is_pinned = res.data.pinned ? 1 : 0
		uni.showToast({ title: res.msg, icon: 'success' })
	} else {
		uni.showToast({ title: res.msg || '操作失败', icon: 'none' })
	}
}

function onImgTap(img, i) { if (isLive(img)) { playingLive.value = playingLive.value === i ? -1 : i } else { preview(i) } }
function onImgLongPress(img, i) { if (isLive(img)) { playingLive.value = i } else { preview(i) } }
function preview(i) { if (!post.value?.images) return; const urls = post.value.images.map(img => fullUrl(getImgUrl(img))); uni.previewImage({ urls, current: i }) }
function previewCmtImg(url) { uni.previewImage({ urls: [fullUrl(url)] }) }

function startReply(comment, subComment) {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	if (subComment) { replyTarget.value = { id: subComment.id, nickname: subComment.nickname }; replyParentId.value = comment.id }
	else { replyTarget.value = { id: comment.id, nickname: comment.nickname }; replyParentId.value = comment.id }
	showEmoji.value = false
	commentPopupShow.value = true
	nextTick(() => { inputFocus.value = true })
}
function cancelReply() { replyTarget.value = null; replyParentId.value = null }

function customShowModal(options = {}) {
	return new Promise((resolve) => {
		modalTitle.value = options.title || '提示'
		modalContent.value = options.content || ''
		modalConfirmText.value = options.confirmText || '确定'
		modalResolve = resolve
		modalVisible.value = true
	})
}
function onModalConfirm() {
	modalVisible.value = false
	if (modalResolve) { modalResolve(true); modalResolve = null }
}
function onModalCancel() {
	modalVisible.value = false
	if (modalResolve) { modalResolve(false); modalResolve = null }
}

function canDeleteComment(cmt) {
	if (!userStore.userInfo) return false
	const isSelf = cmt.user_id === userStore.userInfo.id
	const isPostOwner = post.value && post.value.user_id === userStore.userInfo.id
	return isSelf || isPostOwner
}

function canPinComment() {
	if (!userStore.userInfo || !post.value) return false
	return post.value.user_id === userStore.userInfo.id
}

async function onDeleteComment(comment, parentComment) {
	const confirmed = await customShowModal({ title: '删除评论', content: '确定要删除这条评论吗？', confirmText: '删除' })
	if (!confirmed) return
	const res = await request({ url: '/comments/' + comment.id, method: 'DELETE' })
	if (res.code === 200) {
		uni.showToast({ title: '已删除', icon: 'none' })
		if (parentComment && parentComment.subComments) {
			const idx = parentComment.subComments.findIndex(sc => sc.id === comment.id)
			if (idx >= 0) parentComment.subComments.splice(idx, 1)
		} else {
			const idx = comments.value.findIndex(c => c.id === comment.id)
			if (idx >= 0) comments.value.splice(idx, 1)
		}
		if (post.value) post.value.comments_count = Math.max((post.value.comments_count || 1) - 1, 0)
	}
}

async function onPinComment(cmt) {
	const res = await request({ url: '/comments/' + cmt.id + '/pin', method: 'POST' })
	if (res.code === 200) {
		uni.showToast({ title: res.msg, icon: 'none' })
		if (res.data && res.data.pinned !== undefined) {
			comments.value.forEach(c => {
				if (res.data.pinned) {
					c.is_pinned = c.id === cmt.id ? 1 : 0
				} else {
					if (c.id === cmt.id) c.is_pinned = 0
				}
			})
		}
		await loadComments()
	}
}

async function onLikeComment(c) {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	try {
		const res = await request({ url: '/comments/' + c.id + '/like', method: 'POST' })
		if (res.code === 200) {
			c.isLiked = res.data.liked
			c.likes_count = (c.likes_count || 0) + (res.data.liked ? 1 : -1)
			if (res.data.liked) {
				c._likeBouncing = true
				setTimeout(() => { c._likeBouncing = false }, 500)
			}
		} else {
			uni.showToast({ title: res.msg || '操作失败', icon: 'none' })
		}
	} catch (e) {
		console.error('like comment error:', e)
	}
}

function onInputFocus() { showEmoji.value = false }
let blurTimer = null
function onInputBlur() {
	blurTimer = setTimeout(() => {
		if (!showEmoji.value) {
			closeCommentPopup()
		}
	}, 200)
}
function openCommentPopup() {
	if (blurTimer) { clearTimeout(blurTimer); blurTimer = null }
	commentPopupShow.value = true
	nextTick(() => { inputFocus.value = true })
}
function closeCommentPopup() {
	commentPopupShow.value = false
	inputFocus.value = false
	showEmoji.value = false
	keyboardHeight.value = 0
}
function focusInput() {
	if (showEmoji.value) {
		showEmoji.value = false
	}
	inputFocus.value = true
}
function toggleEmoji() {
	if (blurTimer) { clearTimeout(blurTimer); blurTimer = null }
	if (showEmoji.value) {
		showEmoji.value = false
		inputFocus.value = true
	} else {
		inputFocus.value = false
		keyboardHeight.value = 0
		nextTick(() => { showEmoji.value = true })
	}
}
function insertEmoji(e) { commentText.value += e }
function insertAt() {
	if (blurTimer) { clearTimeout(blurTimer); blurTimer = null }
	commentText.value += '@'
	inputFocus.value = true
	showEmoji.value = false
}

function pickCmtImage() {
	if (blurTimer) { clearTimeout(blurTimer); blurTimer = null }
	uni.chooseImage({
		count: 1,
		sizeType: ['compressed'],
		sourceType: ['album', 'camera'],
		success: (res) => {
			cmtImgThumb.value = res.tempFilePaths[0]
			cmtImgTempPath.value = res.tempFilePaths[0]
		}
	})
}
function removeCmtImg() { cmtImgThumb.value = ''; cmtImgTempPath.value = '' }

async function onSend() {
	if (!userStore.isLoggedIn) return uni.navigateTo({ url: '/pages/login/login' })
	const text = commentText.value.trim()
	if (!text && !cmtImgTempPath.value) return
	let imageUrl = ''
	if (cmtImgTempPath.value) { const imgRes = await uploadFile('/upload/single', cmtImgTempPath.value); if (imgRes.code === 200 && imgRes.data.url) imageUrl = imgRes.data.url }
	const res = await postStore.addComment(Number(postId.value), text, replyParentId.value, imageUrl)
	if (res?.code === 200) {
		const newCmt = {
			id: res.data?.id || Date.now(),
			user_id: userStore.userInfo?.id,
			nickname: userStore.userInfo?.nickname || '我',
			avatar: userStore.userInfo?.avatar || '',
			content: text,
			image_url: imageUrl,
			likes_count: 0,
			isLiked: false,
			location: res.data?.location || '',
			created_at: new Date().toISOString(),
			subComments: []
		}
		if (replyParentId.value) {
			const parent = comments.value.find(c => c.id === replyParentId.value)
			if (parent) {
				if (!parent.subComments) parent.subComments = []
				parent.subComments.push(newCmt)
			}
		} else {
			comments.value.push(newCmt)
		}
		commentText.value = ''; inputFocus.value = false; replyTarget.value = null; replyParentId.value = null; cmtImgThumb.value = ''; cmtImgTempPath.value = ''; showEmoji.value = false; commentPopupShow.value = false
		uni.showToast({ title: '评论成功', icon: 'none' })
		await loadPost()
	}
}
</script>

<style lang="scss" scoped>
.page-detail { min-height: 100vh; background: #fff; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(12rpx); } to { opacity: 1; transform: translateY(0); } }
@keyframes imgFadeIn { from { opacity: 0; } to { opacity: 1; } }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 20rpx; }
.nav-left { padding: 8rpx 16rpx; }
.nav-back-img { width: 40rpx; height: 40rpx; }
.nav-right { padding: 8rpx 16rpx; }
.more-dots { font-size: 28rpx; color: #222; letter-spacing: 2rpx; }
.author-bar { display: flex; align-items: center; justify-content: space-between; padding: 16rpx 24rpx; animation: fadeIn .3s ease; }
.author-left { display: flex; align-items: center; }
.author-av { width: 72rpx; height: 72rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.author-av-img { width: 72rpx; height: 72rpx; border-radius: 50%; }
.av-letter { font-size: 28rpx; color: #fff; font-weight: 600; }
.author-meta { margin-left: 14rpx; }
.author-name { font-size: 28rpx; font-weight: 600; color: #222; display: block; }
.author-time { font-size: 22rpx; color: #bbb; display: block; margin-top: 4rpx; }
.follow-btn { padding: 10rpx 24rpx; border-radius: 24rpx; background: linear-gradient(135deg, #ff2442, #ff5a6e); transition: all .2s; box-shadow: 0 4rpx 12rpx rgba(255,36,66,0.2); }
.followed { background: #f5f5f5; box-shadow: none; border: 1rpx solid #e8e8e8; }
.follow-label { font-size: 24rpx; color: #fff; font-weight: 600; }
.followed .follow-label { color: #999; font-weight: 400; }
.detail-title { font-size: 34rpx; font-weight: 700; color: #222; line-height: 1.5; padding: 8rpx 24rpx 0; display: block; animation: fadeIn .35s ease .05s both; user-select: text; -webkit-user-select: text; }
.detail-body { font-size: 28rpx; color: #333; line-height: 1.8; padding: 12rpx 24rpx 0; display: block; animation: fadeIn .35s ease .1s both; }

.block-render { animation: fadeIn .35s ease .08s both; }
.render-block { margin-bottom: 4rpx; }
.render-text-block { padding: 8rpx 24rpx; }
.render-text-rt { font-size: 30rpx; color: #333; line-height: 2; user-select: text; -webkit-user-select: text; }
.render-img-block { padding: 8rpx 24rpx; }
.r-grid { display: flex; flex-wrap: wrap; gap: 6rpx; border-radius: 12rpx; overflow: hidden; }
.r-grid-item { width: calc(33.33% - 4rpx); aspect-ratio: 1; overflow: hidden; }
.r-grid-img { width: 100%; height: 100%; animation: imgFadeIn .5s ease both; }
.r-double { display: flex; flex-wrap: wrap; gap: 6rpx; border-radius: 12rpx; overflow: hidden; }
.r-double-item { width: calc(50% - 3rpx); aspect-ratio: 1; overflow: hidden; }
.r-double-img { width: 100%; height: 100%; animation: imgFadeIn .5s ease both; }
.r-stack { padding: 8rpx 0; }
.r-stack-wrap { position: relative; margin: 0 auto; width: 85%; }
.r-stack-card { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border-radius: 12rpx; overflow: hidden; box-shadow: 0 4rpx 16rpx rgba(0,0,0,0.1); }
.r-stack-img { width: 100%; height: 100%; animation: imgFadeIn .5s ease both; }
.r-full { display: flex; flex-direction: column; gap: 8rpx; }
.r-full-item { border-radius: 12rpx; overflow: hidden; }
.r-full-img { width: 100%; animation: imgFadeIn .5s ease both; }
.render-voice-block { margin: 8rpx 24rpx; background: #f5f5f5; border-radius: 24rpx; padding: 24rpx 28rpx; }
.render-voice-block:active { background: #eee; }

.text-tpl-card {
	margin: 20rpx 24rpx; border-radius: 28rpx;
	min-height: 420rpx; position: relative; overflow: hidden;
	display: flex; flex-direction: column;
	box-shadow: 0 8rpx 32rpx rgba(0,0,0,0.1);
	animation: tplCardIn .5s cubic-bezier(0.34, 1.56, 0.64, 1);
}
@keyframes tplCardIn {
	from { opacity: 0; transform: scale(0.96) translateY(16rpx); }
	to { opacity: 1; transform: scale(1) translateY(0); }
}
.tpl-content-wrap {
	flex: 1; display: flex; align-items: center; justify-content: center;
	padding: 56rpx 48rpx 40rpx;
}
.tpl-content-text {
	font-size: 36rpx; line-height: 2.2; text-align: center;
	letter-spacing: 3rpx; display: block;
	user-select: text; -webkit-user-select: text;
}
.tpl-bottom-bar {
	padding: 20rpx 36rpx 28rpx;
	display: flex; align-items: center; justify-content: center;
}
.tpl-views {
	display: flex; align-items: center; gap: 8rpx;
	opacity: 0.5;
}
.tpl-views-icon { width: 24rpx; height: 24rpx; }
.tpl-views-text { font-size: 22rpx; }

.voice-box { margin: 16rpx 24rpx; background: #f5f5f5; border-radius: 24rpx; padding: 24rpx 28rpx; animation: fadeIn .4s ease .12s both; }
.voice-box:active { background: #eee; }
.voice-inner { display: flex; align-items: center; }
.voice-play-btn { width: 56rpx; height: 56rpx; border-radius: 50%; background: #ff2442; display: flex; align-items: center; justify-content: center; gap: 4rpx; margin-right: 16rpx; flex-shrink: 0; }
.voice-play-bar { width: 4rpx; background: #fff; border-radius: 2rpx; }
.voice-play-bar:nth-child(1) { height: 12rpx; }
.voice-play-bar:nth-child(2) { height: 20rpx; }
.voice-play-bar:nth-child(3) { height: 12rpx; }
.bar-anim { animation: barBounce 0.5s ease-in-out infinite alternate; }
.voice-play-bar:nth-child(1).bar-anim { animation-delay: 0s; }
.voice-play-bar:nth-child(2).bar-anim { animation-delay: 0.15s; }
.voice-play-bar:nth-child(3).bar-anim { animation-delay: 0.3s; }
@keyframes barBounce { 0% { transform: scaleY(0.5); } 100% { transform: scaleY(1.5); } }
.voice-playing { animation: voicePulse 1s ease infinite; }
@keyframes voicePulse { 0%,100% { transform: scale(1); } 50% { transform: scale(1.08); } }
.voice-wave { display: flex; align-items: center; gap: 4rpx; flex: 1; }
.v-wave-bar { width: 6rpx; background: #ff2442; border-radius: 3rpx; min-height: 8rpx; opacity: 0.5; }
.v-wave-active { animation: vWaveAnim 0.6s ease-in-out infinite alternate; }
@keyframes vWaveAnim { 0% { opacity: 0.3; transform: scaleY(0.5); } 100% { opacity: 1; transform: scaleY(1.2); } }
.voice-dur { font-size: 24rpx; color: #666; margin-left: 16rpx; flex-shrink: 0; }

.link-box { margin: 12rpx 24rpx; display: flex; align-items: center; background: #f5f7fa; border-radius: 12rpx; padding: 18rpx 24rpx; border: 1rpx solid #e8ecf0; animation: fadeIn .4s ease .14s both; }
.link-box:active { background: #eee; }
.link-ico-img { width: 32rpx; height: 32rpx; margin-right: 12rpx; }
.link-card-info { flex: 1; overflow: hidden; }
.link-card-title { font-size: 24rpx; color: #333; font-weight: 500; display: block; }
.link-url { font-size: 20rpx; color: #999; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.link-arrow { font-size: 24rpx; color: #ccc; margin-left: 8rpx; }
.tag-loc-img { width: 24rpx; height: 24rpx; vertical-align: middle; margin-right: 4rpx; }
.cmt-like-img { width: 24rpx; height: 24rpx; vertical-align: middle; }
.detail-imgs { padding: 16rpx 24rpx; animation: fadeIn .4s ease .15s both; }
.detail-img-wrap { position: relative; margin-bottom: 12rpx; }
.detail-img { width: 100%; border-radius: 12rpx; }
.detail-video { width: 100%; border-radius: 12rpx; min-height: 400rpx; }
.img-live-badge { position: absolute; left: 12rpx; top: 12rpx; background: rgba(0,0,0,0.6); border-radius: 8rpx; padding: 4rpx 14rpx; }
.img-live-text { font-size: 20rpx; color: #fff; font-weight: 700; letter-spacing: 1rpx; }
.live-hint { position: absolute; bottom: 16rpx; left: 50%; transform: translateX(-50%); background: rgba(0,0,0,0.45); border-radius: 16rpx; padding: 4rpx 18rpx; }
.live-hint-text { font-size: 20rpx; color: rgba(255,255,255,0.9); }
.tag-row { padding: 12rpx 24rpx; display: flex; gap: 16rpx; }
.tag { font-size: 24rpx; color: #3378e5; }
.tag-clickable { cursor: pointer; }
.tag-clickable:active { opacity: 0.6; }
.date-row { padding: 4rpx 24rpx; }
.date-text { font-size: 22rpx; color: #bbb; }
.interact-row { padding: 8rpx 24rpx 8rpx; }
.interact-text { font-size: 22rpx; color: #bbb; }
.article-interact-bar { display: flex; align-items: center; justify-content: center; padding: 16rpx 24rpx; gap: 60rpx; }
.interact-stat { display: flex; align-items: center; gap: 8rpx; }
.interact-stat-icon { width: 44rpx; height: 44rpx; }
.interact-stat-num { font-size: 28rpx; color: #333; font-weight: 500; }
.interact-stat-on { color: #ff2442; }
.interact-stat-comment .interact-stat-icon { width: 40rpx; height: 40rpx; }
.gap-line { height: 16rpx; background: #f5f5f5; }

.comment-area { padding: 24rpx; }
.comment-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20rpx; }
.comment-title { font-size: 28rpx; font-weight: 600; color: #222; display: block; }
.cmt { display: flex; margin-bottom: 28rpx; }
.cmt-av { width: 68rpx; height: 68rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 16rpx; }
.cmt-av-img { width: 68rpx; height: 68rpx; border-radius: 50%; flex-shrink: 0; margin-right: 16rpx; }
.cmt-av-text { font-size: 24rpx; color: #fff; }
.cmt-main { flex: 1; padding-right: 16rpx; }
.cmt-name-row { display: flex; align-items: center; flex-wrap: wrap; gap: 8rpx; }
.cmt-name { font-size: 24rpx; color: #666; font-weight: 500; }
.cmt-author-badge { font-size: 18rpx; color: #ff2442; background: #fff0f3; padding: 2rpx 8rpx; border-radius: 6rpx; font-weight: 500; }
.cmt-pin-tag { display: inline-flex; align-items: center; padding: 2rpx 10rpx; background: #fff0f3; border-radius: 4rpx; margin-left: 12rpx; vertical-align: middle; }
.cmt-pin-tag-text { font-size: 18rpx; color: #ff2442; font-weight: 500; }
.cmt-text { font-size: 28rpx; color: #333; line-height: 1.7; display: block; margin-top: 8rpx; user-select: text; -webkit-user-select: text; }
.cmt-img { width: 240rpx; border-radius: 12rpx; margin-top: 12rpx; }
.sub-cmt-img { width: 180rpx; }
.cmt-bar { display: flex; justify-content: space-between; align-items: center; margin-top: 12rpx; }
.cmt-bar-left { display: flex; align-items: center; gap: 12rpx; }
.cmt-time { font-size: 20rpx; color: #bbb; }
.cmt-location { font-size: 18rpx; color: #ccc; }
.cmt-acts { display: flex; align-items: center; gap: 24rpx; }
.cmt-act-text { font-size: 22rpx; color: #999; margin-right: 16rpx; }
.cmt-act-text:active { opacity: 0.6; }
.cmt-act-del { color: #ff6b6b; }
.cmt-act-pin { color: #ff2442; }
.cmt-like-row { display: flex; align-items: center; gap: 6rpx; }
.cmt-like-img { width: 28rpx; height: 28rpx; }
.cmt-like-num { font-size: 22rpx; color: #999; }
.cmt-like-on { color: #ff2442; }

.sub-list { background: #f5f5f5; border-radius: 12rpx; padding: 14rpx 18rpx; margin-top: 12rpx; }
.sub { margin-bottom: 14rpx; }
.sub:last-child { margin-bottom: 0; }
.sub-row { display: flex; }
.sub-av { width: 40rpx; height: 40rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-right: 10rpx; }
.sub-av-img { width: 40rpx; height: 40rpx; border-radius: 50%; flex-shrink: 0; margin-right: 10rpx; }
.sub-av-text { font-size: 16rpx; color: #fff; }
.sub-main { flex: 1; }
.sub-name { font-size: 22rpx; color: #3378e5; font-weight: 500; }
.sub-text { font-size: 24rpx; color: #333; user-select: text; -webkit-user-select: text; }
.sub-bar { display: flex; gap: 20rpx; margin-top: 6rpx; align-items: center; }
.sub-time { font-size: 18rpx; color: #ccc; }
.sub-location { font-size: 16rpx; color: #ddd; }
.sub-act { font-size: 18rpx; color: #999; }
.sub-act-del { color: #ff6b6b; }

.cmt-empty { padding: 60rpx 0; text-align: center; }
.cmt-empty-text { font-size: 26rpx; color: #ccc; }

.bottom-bar { position: fixed; left: 0; right: 0; bottom: 0; background: #fff; border-top: 1rpx solid #f0f0f0; z-index: 999; }
.stat-bar { display: flex; align-items: center; padding: 16rpx 24rpx; gap: 8rpx; }
.stat-item { display: flex; align-items: center; gap: 6rpx; padding: 8rpx 16rpx; }
.stat-icon { width: 40rpx; height: 40rpx; }
.stat-num { font-size: 24rpx; color: #333; transition: color .2s; }
.stat-on { color: #ff2442; }
.like-icon-wrap { position: relative; display: flex; align-items: center; justify-content: center; }
.cmt-like-wrap { position: relative; display: flex; align-items: center; justify-content: center; }
.like-bounce { animation: likeBounce .5s cubic-bezier(0.17, 0.89, 0.32, 1.49); }
@keyframes likeBounce {
	0% { transform: scale(1); }
	20% { transform: scale(1.35); }
	50% { transform: scale(0.9); }
	75% { transform: scale(1.1); }
	100% { transform: scale(1); }
}
.num-bounce { animation: numBounce .4s cubic-bezier(0.17, 0.89, 0.32, 1.49); }
@keyframes numBounce {
	0% { transform: scale(1); }
	30% { transform: scale(1.2); }
	100% { transform: scale(1); }
}
.like-particles { position: absolute; top: 50%; left: 50%; width: 0; height: 0; z-index: 2; }
.lp { position: absolute; top: 0; left: 0; }
.lp-dot {
	width: 8rpx; height: 8rpx; border-radius: 50%;
	background: #ff2442; animation: particleFly .5s ease-out forwards;
}
.lp:nth-child(1) .lp-dot { animation-delay: 0s; }
.lp:nth-child(2) .lp-dot { animation-delay: .03s; }
.lp:nth-child(3) .lp-dot { animation-delay: .06s; }
.lp:nth-child(4) .lp-dot { animation-delay: .03s; }
.lp:nth-child(5) .lp-dot { animation-delay: .06s; }
.lp:nth-child(6) .lp-dot { animation-delay: 0s; }
@keyframes particleFly {
	0% { transform: translateY(0); opacity: 1; }
	100% { transform: translateY(-36rpx); opacity: 0; }
}
.stat-input-trigger { flex: 1; background: #f5f5f5; border-radius: 28rpx; height: 56rpx; display: flex; align-items: center; padding: 0 24rpx; margin-left: 8rpx; }
.stat-input-text { font-size: 24rpx; color: #999; }

.comment-popup-mask { position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1000; background: rgba(0,0,0,0.5); opacity: 0; transition: opacity 0.25s ease; pointer-events: none; }
.popup-show { opacity: 1; pointer-events: auto; }
.comment-popup { position: fixed; left: 0; right: 0; background: #fff; border-radius: 24rpx 24rpx 0 0; z-index: 1001; transform: translateY(100%); transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1), bottom 0.25s ease; padding-bottom: env(safe-area-inset-bottom); }
.popup-show .comment-popup { transform: translateY(0); }
.reply-hint { display: flex; align-items: center; justify-content: space-between; padding: 12rpx 24rpx; background: #f5f5f5; border-bottom: 1rpx solid #e8e8e8; }
.reply-hint-text { font-size: 24rpx; color: #666; }
.reply-cancel { font-size: 28rpx; color: #999; padding: 4rpx 8rpx; }
.popup-input-row { display: flex; align-items: flex-end; padding: 20rpx 24rpx 16rpx; gap: 16rpx; }
.popup-input-area { flex: 1; background: #f5f5f5; border-radius: 12rpx; padding: 0 20rpx; min-height: 64rpx; max-height: 200rpx; display: flex; align-items: flex-start; }
.popup-textarea { width: 100%; font-size: 28rpx; background: transparent; min-height: 64rpx; max-height: 200rpx; line-height: 1.5; padding: 16rpx 0; box-sizing: content-box; }
.cmt-img-preview { position: relative; width: 64rpx; height: 64rpx; flex-shrink: 0; }
.cmt-img-thumb { width: 64rpx; height: 64rpx; border-radius: 8rpx; }
.cmt-img-del { position: absolute; top: -8rpx; right: -8rpx; width: 28rpx; height: 28rpx; border-radius: 50%; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; }
.cmt-img-del-x { font-size: 16rpx; color: #fff; }
.popup-send-btn { padding: 0 32rpx; height: 64rpx; border-radius: 32rpx; background: #ffb3c0; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.popup-send-active { background: #ff2442; }
.popup-send-text { font-size: 28rpx; color: #fff; font-weight: 600; }
.popup-toolbar { display: flex; align-items: center; justify-content: space-around; padding: 12rpx 24rpx 16rpx; border-bottom: 1rpx solid #f5f5f5; }
.toolbar-icon { display: flex; align-items: center; justify-content: center; width: 56rpx; height: 56rpx; }
.toolbar-icon-img { width: 40rpx; height: 40rpx; }
.toolbar-icon-at { font-size: 36rpx; color: #666; font-weight: 500; }
.toolbar-icon-plus { font-size: 36rpx; color: #666; }
.toolbar-keyboard-icon { width: 36rpx; height: 36rpx; border-radius: 8rpx; background: #f0f0f0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4rpx; padding: 6rpx; box-sizing: border-box; }
.tkb-line { width: 100%; height: 3rpx; background: #666; border-radius: 2rpx; }
.emoji-panel { background: #fff; border-top: 1rpx solid #f0f0f0; padding: 16rpx 0; }
.emoji-scroll-h { height: 120rpx; white-space: nowrap; }
.emoji-grid-h { display: inline-flex; padding: 0 20rpx; gap: 0; }
.emoji-item-h { width: 80rpx; height: 80rpx; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.emoji-char-h { font-size: 44rpx; }
</style>
