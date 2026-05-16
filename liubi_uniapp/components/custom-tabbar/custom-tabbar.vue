<template>
	<view class="tabbar-wrap">
		<view class="tabbar">
			<view class="tab-item" @tap="switchTo(0)">
				<text class="tab-text" :class="{ 'tab-on': current === 0 }">首页</text>
			</view>
			<view class="tab-item" @tap="switchTo(1)">
				<text class="tab-text" :class="{ 'tab-on': current === 1 }">发现</text>
			</view>
			<view class="tab-item tab-center" @tap="goPublish">
				<view class="center-btn">
					<text class="center-plus">＋</text>
				</view>
			</view>
			<view class="tab-item" @tap="switchTo(2)">
				<view class="tab-msg-wrap">
					<text class="tab-text" :class="{ 'tab-on': current === 2 }">消息</text>
					<view class="tab-badge" v-if="msgUnread > 0">
						<text class="tab-badge-num">{{ msgUnread > 99 ? '99+' : msgUnread }}</text>
					</view>
				</view>
			</view>
			<view class="tab-item" @tap="switchTo(3)">
				<text class="tab-text" :class="{ 'tab-on': current === 3 }">我</text>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useUserStore } from '@/store/user.js'
import { request } from '@/utils/request.js'

const props = defineProps({ current: { type: Number, default: 0 } })
const userStore = useUserStore()
const msgUnread = ref(0)

const urls = [
	'/pages/index/index',
	'/pages/discover/discover',
	'/pages/message/message',
	'/pages/mine/mine'
]

function switchTo(i) {
	if (props.current === i) return
	uni.switchTab({ url: urls[i] })
}

function goPublish() {
	uni.navigateTo({ url: '/pages/publish/publish' })
}

async function fetchUnread() {
	if (!userStore.isLoggedIn) { msgUnread.value = 0; return }
	try {
		const [notifyRes, chatRes] = await Promise.all([
			request({ url: '/notifications/unread' }),
			request({ url: '/chat/unread' })
		])
		let total = 0
		if (notifyRes.code === 200) {
			total += Number(notifyRes.data.like_count || 0) + Number(notifyRes.data.comment_count || 0) + Number(notifyRes.data.follow_count || 0)
		}
		if (chatRes.code === 200) {
			total += Number(chatRes.data.count || 0)
		}
		msgUnread.value = total
	} catch (e) {}
}

onMounted(() => { fetchUnread() })
onShow(() => { fetchUnread() })
</script>

<style lang="scss" scoped>
.tabbar-wrap {
	position: fixed;
	bottom: 0; left: 0; right: 0;
	z-index: 999;
	background: #fff;
}
.tabbar {
	display: flex;
	align-items: center;
	height: 50px;
	padding-bottom: constant(safe-area-inset-bottom);
	padding-bottom: env(safe-area-inset-bottom);
	border-top: 0.5px solid #eee;
}
.tab-item {
	flex: 1;
	display: flex;
	align-items: center;
	justify-content: center;
	height: 50px;
}
.tab-text {
	font-size: 13px;
	color: #999;
	transition: all .15s ease;
}
.tab-on {
	color: #222;
	font-weight: 600;
	font-size: 14px;
}
.tab-msg-wrap {
	position: relative;
	display: flex;
	align-items: center;
}
.tab-badge {
	position: absolute;
	top: -8px;
	right: -28px;
	min-width: 16px;
	height: 16px;
	border-radius: 8px;
	background: #ff2442;
	display: flex;
	align-items: center;
	justify-content: center;
	padding: 0 4px;
}
.tab-badge-num {
	font-size: 10px;
	color: #fff;
	font-weight: 700;
}
.tab-center {
	display: flex;
	align-items: center;
	justify-content: center;
}
.center-btn {
	width: 40px;
	height: 28px;
	border-radius: 14px;
	background: linear-gradient(135deg, #ff2442, #ff5a6e);
	display: flex;
	align-items: center;
	justify-content: center;
	box-shadow: 0 2px 8px rgba(255, 36, 66, 0.3);
}
.center-btn:active {
	transform: scale(0.9);
}
.center-plus {
	font-size: 20px;
	color: #fff;
	font-weight: 400;
	line-height: 1;
	margin-top: -1px;
}
</style>
