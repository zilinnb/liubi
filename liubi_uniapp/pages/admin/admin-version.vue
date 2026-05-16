<template>
	<view class="page-version">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">版本管理</text>
				<view class="nav-right" @tap="onAddNew"><text class="add-text">发布</text></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="ver-body" :show-scrollbar="false">
			<view class="ver-body-inner">
			<view v-if="!list.length" class="empty-state">
				<text class="empty-text">暂无版本记录</text>
			</view>
			<view class="ver-card" v-for="item in list" :key="item.id">
				<view class="ver-header">
					<view class="ver-name-wrap">
						<text class="ver-name">v{{ item.version_name }}</text>
						<view class="ver-badge" :class="item.platform === 'ios' ? 'badge-ios' : 'badge-android'">
							<text class="ver-badge-text">{{ item.platform === 'ios' ? 'iOS' : 'Android' }}</text>
						</view>
						<view class="ver-badge badge-type" v-if="item.update_type === 2">
							<text class="ver-badge-text">直链</text>
						</view>
						<view class="ver-badge badge-force" v-if="item.force_update === 1">
							<text class="ver-badge-text">强制</text>
						</view>
					</view>
					<view class="ver-status" :class="item.status === 1 ? 'status-on' : 'status-off'">
						<text class="ver-status-text">{{ item.status === 1 ? '启用' : '禁用' }}</text>
					</view>
				</view>
				<view class="ver-url">
					<text class="ver-url-text">{{ item.download_url }}</text>
				</view>
				<view class="ver-content" v-if="item.update_content">
					<text class="ver-content-text">{{ item.update_content }}</text>
				</view>
				<view class="ver-footer">
					<text class="ver-time">{{ item.created_at }}</text>
					<view class="ver-actions">
						<view class="act-btn act-edit" @tap="onEdit(item)">
							<text class="act-text act-edit-text">编辑</text>
						</view>
						<view class="act-btn" @tap="toggleStatus(item)">
							<text class="act-text">{{ item.status === 1 ? '禁用' : '启用' }}</text>
						</view>
						<view class="act-btn act-del" @tap="onDelete(item)">
							<text class="act-text act-del-text">删除</text>
						</view>
					</view>
				</view>
			</view>
			</view>
		</scroll-view>

		<view class="add-mask" v-if="showAdd" @tap="showAdd = false">
			<view class="add-dialog" @tap.stop>
				<view class="add-header">
					<text class="add-title">{{ editingId ? '编辑版本' : '发布新版本' }}</text>
					<view class="add-close" @tap="closeForm"><text class="close-x">x</text></view>
				</view>
				<scroll-view scroll-y class="add-form">
					<view class="form-item">
						<text class="form-label">版本号(数字)</text>
						<input class="form-input" v-model="form.version_code" type="number" placeholder="如 200" />
					</view>
					<view class="form-item">
						<text class="form-label">版本名</text>
						<input class="form-input" v-model="form.version_name" placeholder="如 1.1.0" />
					</view>
					<view class="form-item">
						<text class="form-label">平台</text>
						<view class="form-switch-row">
							<view class="switch-opt" :class="{ 'switch-on': form.platform === 'android' }" @tap="form.platform = 'android'">
								<text class="switch-opt-text">Android</text>
							</view>
							<view class="switch-opt" :class="{ 'switch-on': form.platform === 'ios' }" @tap="form.platform = 'ios'">
								<text class="switch-opt-text">iOS</text>
							</view>
						</view>
					</view>
					<view class="form-item">
						<text class="form-label">更新方式</text>
						<view class="form-switch-row">
							<view class="switch-opt" :class="{ 'switch-on': form.update_type === 1 }" @tap="form.update_type = 1">
								<text class="switch-opt-text">浏览器跳转</text>
							</view>
							<view class="switch-opt" :class="{ 'switch-on': form.update_type === 2 }" @tap="form.update_type = 2">
								<text class="switch-opt-text">直链静默更新</text>
							</view>
						</view>
					</view>
					<view class="form-item">
						<text class="form-label">强制更新</text>
						<switch :checked="form.force_update === 1" @change="form.force_update = $event.detail.value ? 1 : 0" color="#ff2442" />
					</view>
					<view class="form-item">
						<text class="form-label">下载地址</text>
						<input class="form-input" v-model="form.download_url" placeholder="网盘链接或APK直链" />
					</view>
					<view class="form-item">
						<text class="form-label">安装包大小</text>
						<input class="form-input" v-model="form.package_size" placeholder="如 23.5MB" />
					</view>
					<view class="form-item">
						<text class="form-label">更新内容(每行一条)</text>
						<textarea class="form-textarea" v-model="form.update_content" placeholder="1. 新增功能&#10;2. 修复bug&#10;3. 优化性能" />
					</view>
				</scroll-view>
				<view class="add-footer">
					<view class="btn-cancel" @tap="closeForm"><text class="btn-cancel-text">取消</text></view>
					<view class="btn-submit" @tap="onSubmit"><text class="btn-submit-text">{{ editingId ? '保存' : '发布' }}</text></view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { request } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const list = ref([])
const showAdd = ref(false)
const editingId = ref(null)
const originalStatus = ref(1)
const form = ref({
	version_code: '',
	version_name: '',
	platform: 'android',
	update_type: 1,
	force_update: 0,
	download_url: '',
	update_content: '',
	package_size: ''
})

onMounted(() => { loadList() })

async function loadList() {
	const res = await request({ url: '/version/list' })
	if (res.code === 200) list.value = res.data
}

async function onSubmit() {
	const f = form.value
	if (!f.version_code || !f.version_name || !f.download_url) {
		return uni.showToast({ title: '请填写必填项', icon: 'none' })
	}
	if (editingId.value) {
		const res = await request({ url: '/version/' + editingId.value, method: 'PUT', data: { ...f, version_code: parseInt(f.version_code), status: originalStatus.value } })
		if (res.code === 200) {
			uni.showToast({ title: '保存成功', icon: 'success' })
			closeForm()
			loadList()
		} else {
			uni.showToast({ title: res.msg || '保存失败', icon: 'none' })
		}
	} else {
		const res = await request({ url: '/version', method: 'POST', data: { ...f, version_code: parseInt(f.version_code) } })
		if (res.code === 200) {
			uni.showToast({ title: '发布成功', icon: 'success' })
			closeForm()
			loadList()
		} else {
			uni.showToast({ title: res.msg || '发布失败', icon: 'none' })
		}
	}
}

function onEdit(item) {
	editingId.value = item.id
	originalStatus.value = item.status
	form.value = {
		version_code: String(item.version_code),
		version_name: item.version_name,
		platform: item.platform || 'android',
		update_type: item.update_type || 1,
		force_update: item.force_update || 0,
		download_url: item.download_url || '',
		update_content: item.update_content || '',
		package_size: item.package_size || ''
	}
	showAdd.value = true
}

function closeForm() {
	showAdd.value = false
	editingId.value = null
	form.value = { version_code: '', version_name: '', platform: 'android', update_type: 1, force_update: 0, download_url: '', update_content: '', package_size: '' }
}

async function toggleStatus(item) {
	await request({ url: '/version/' + item.id, method: 'PUT', data: { ...item, status: item.status === 1 ? 0 : 1 } })
	loadList()
}

function onDelete(item) {
	uni.showModal({
		title: '确认删除',
		content: '删除版本 v' + item.version_name + '？',
		confirmColor: '#ff2442',
		success: async (res) => {
			if (res.confirm) {
				await request({ url: '/version/' + item.id, method: 'DELETE' })
				loadList()
			}
		}
	})
}

function goBack() { uni.navigateBack() }

function onAddNew() {
	editingId.value = null
	form.value = { version_code: '', version_name: '', platform: 'android', update_type: 1, force_update: 0, download_url: '', update_content: '', package_size: '' }
	showAdd.value = true
}
</script>

<style lang="scss" scoped>
.page-version { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 28rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }
.add-text { font-size: 28rpx; color: #ff2442; font-weight: 600; padding: 8rpx 12rpx; }

.ver-body { height: calc(100vh - 140rpx); }
.ver-body-inner { padding: 16rpx 28rpx 40rpx; }
.empty-state { padding: 120rpx 0; text-align: center; }
.empty-text { font-size: 28rpx; color: #ccc; }

.ver-card { background: #fff; border-radius: 16rpx; padding: 24rpx 28rpx; margin-bottom: 16rpx; }
.ver-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12rpx; }
.ver-name-wrap { display: flex; align-items: center; gap: 10rpx; flex: 1; overflow: hidden; }
.ver-name { font-size: 32rpx; font-weight: 700; color: #222; }
.ver-badge { padding: 2rpx 12rpx; border-radius: 8rpx; }
.badge-android { background: #e8f5e9; }
.badge-ios { background: #e3f2fd; }
.badge-type { background: #fff3e0; }
.badge-force { background: #fce4ec; }
.ver-badge-text { font-size: 20rpx; font-weight: 600; }
.badge-android .ver-badge-text { color: #2e7d32; }
.badge-ios .ver-badge-text { color: #1565c0; }
.badge-type .ver-badge-text { color: #e65100; }
.badge-force .ver-badge-text { color: #c62828; }

.ver-status { padding: 4rpx 16rpx; border-radius: 12rpx; }
.status-on { background: #e8f5e9; }
.status-off { background: #f5f5f5; }
.ver-status-text { font-size: 22rpx; font-weight: 500; }
.status-on .ver-status-text { color: #2e7d32; }
.status-off .ver-status-text { color: #999; }

.ver-url { margin-bottom: 8rpx; }
.ver-url-text { font-size: 22rpx; color: #1890ff; word-break: break-all; }
.ver-content { margin-bottom: 12rpx; }
.ver-content-text { font-size: 24rpx; color: #666; line-height: 1.6; }
.ver-footer { display: flex; align-items: center; justify-content: space-between; }
.ver-time { font-size: 22rpx; color: #ccc; }
.ver-actions { display: flex; gap: 16rpx; }
.act-btn { padding: 6rpx 20rpx; border-radius: 8rpx; border: 1rpx solid #e0e0e0; }
.act-text { font-size: 22rpx; color: #666; }
.act-edit { border-color: #bbdefb; }
.act-edit-text { color: #1565c0; }
.act-del { border-color: #ffcdd2; }
.act-del-text { color: #ff2442; }

.add-mask { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,.5); z-index: 1000; display: flex; align-items: flex-end; }
.add-dialog { width: 100%; background: #fff; border-radius: 32rpx 32rpx 0 0; max-height: 85vh; display: flex; flex-direction: column; box-sizing: border-box; }
.add-header { display: flex; align-items: center; justify-content: space-between; padding: 28rpx 32rpx; border-bottom: 1rpx solid #f0f0f0; }
.add-title { font-size: 32rpx; font-weight: 700; color: #222; }
.add-close { padding: 8rpx; }
.close-x { font-size: 32rpx; color: #999; }
.add-form { padding: 20rpx 32rpx; max-height: 60vh; }
.form-item { margin-bottom: 20rpx; }
.form-label { font-size: 24rpx; color: #999; margin-bottom: 8rpx; display: block; }
.form-input { height: 72rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; padding: 0 20rpx; font-size: 28rpx; color: #333; }
.form-textarea { width: 100%; min-height: 160rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; padding: 16rpx 20rpx; font-size: 28rpx; color: #333; box-sizing: border-box; }
.form-switch-row { display: flex; gap: 12rpx; }
.switch-opt { flex: 1; height: 64rpx; border: 1rpx solid #e8e8e8; border-radius: 12rpx; display: flex; align-items: center; justify-content: center; transition: all .2s; }
.switch-on { border-color: #ff2442; background: #fff0f3; }
.switch-opt-text { font-size: 26rpx; color: #666; }
.switch-on .switch-opt-text { color: #ff2442; font-weight: 600; }

.add-footer { display: flex; gap: 16rpx; padding: 20rpx 32rpx 40rpx; border-top: 1rpx solid #f0f0f0; }
.btn-cancel { flex: 1; height: 80rpx; border-radius: 40rpx; border: 1rpx solid #e0e0e0; display: flex; align-items: center; justify-content: center; }
.btn-cancel-text { font-size: 28rpx; color: #999; }
.btn-submit { flex: 2; height: 80rpx; border-radius: 40rpx; background: #ff2442; display: flex; align-items: center; justify-content: center; }
.btn-submit-text { font-size: 28rpx; color: #fff; font-weight: 600; }
</style>
