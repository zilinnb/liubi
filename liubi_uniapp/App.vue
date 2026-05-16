<script>
	import { checkUpdate } from '@/utils/update.js'

	export default {
		onLaunch() {
			uni.hideTabBar({ animation: false })
			const sysInfo = uni.getSystemInfoSync()
			uni.$statusBarHeight = sysInfo.statusBarHeight || 20
			uni.$windowWidth = sysInfo.windowWidth || 375

			// #ifdef APP-PLUS
			setTimeout(() => {
				this.silentCheckUpdate()
			}, 2000)
			// #endif
		},
		onShow() {
			uni.hideTabBar({ animation: false })

			// #ifdef APP-PLUS
			this.silentCheckUpdate()
			// #endif
		},
		onHide() {},
		methods: {
			async silentCheckUpdate() {
				try {
					const info = await checkUpdate(true)
					if (info) {
						uni.$emit('app-update', info)
					}
				} catch (e) {
					console.error('checkUpdate error:', e)
				}
			}
		}
	}
</script>

<style lang="scss">
	@import './uni.scss';

	page {
		background-color: $bg-page;
		font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Helvetica Neue', 'Microsoft YaHei', sans-serif;
		font-size: 28rpx;
		color: $text-primary;
		-webkit-font-smoothing: antialiased;
	}

	view, text, image {
		box-sizing: border-box;
	}

	::-webkit-scrollbar {
		display: none;
		width: 0;
		height: 0;
	}

	uni-tabbar,
	.uni-tabbar,
	.uni-tabbar-bottom {
		display: none !important;
		height: 0 !important;
		overflow: hidden !important;
	}
</style>
