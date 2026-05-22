<template>
	<view class="page-sub">
		<view class="top-nav" :style="{ paddingTop: statusBarH + 'px' }">
			<view class="nav-inner">
				<view class="nav-left" @tap="goBack"><text class="back-arrow">‹</text></view>
				<text class="nav-title">分类管理</text>
				<view class="nav-right"></view>
			</view>
		</view>
		<view :style="{ height: (statusBarH + 44) + 'px' }"></view>

		<scroll-view scroll-y class="list-scroll" :show-scrollbar="false">
			<view class="list-inner">
				<view class="cate-card" v-for="c in list" :key="c.id">
					<view class="cate-icon-box" :style="{ background: c.color || cateColor(c.id) }">
						<image v-if="c.cover" class="cate-cover-thumb" :src="fullUrl(c.cover)" mode="aspectFill" />
						<text v-else class="cate-icon">{{ c.icon || c.name?.slice(0,1) }}</text>
					</view>
					<view class="cate-info">
						<text class="cate-name">{{ c.name }}</text>
						<text class="cate-sub">{{ c.description || '暂无介绍' }}</text>
						<text class="cate-sub">排序：{{ c.sort_order }} · 帖子：{{ c.post_count || 0 }} · {{ c.status === 1 ? '启用' : '禁用' }}<text class="official-tag" v-if="c.publish_restriction === 1">官方</text><text class="level-tag" v-if="c.min_level > 0">Lv.{{ c.min_level }}</text></text>
					</view>
					<view class="cate-actions">
						<view class="act-btn act-edit" @tap="editCategory(c)"><text class="act-text">编辑</text></view>
						<view class="act-btn act-del" @tap="deleteCategory(c.id)"><text class="act-text">删除</text></view>
					</view>
				</view>

				<view class="add-section">
					<text class="add-title">添加新分类</text>
					<view class="add-row">
						<view class="add-field"><text class="add-label">名称</text><input class="add-input" v-model="newName" placeholder="分类名称" /></view>
						<view class="add-field"><text class="add-label">图标</text><input class="add-input add-input-short" v-model="newIcon" placeholder="📁" /></view>
						<view class="add-field"><text class="add-label">排序</text><input class="add-input add-input-short" v-model="newSort" placeholder="0" type="number" /></view>
					</view>
					<view class="add-row">
						<view class="add-field"><text class="add-label">颜色</text><input class="add-input" v-model="newColor" placeholder="#ff2442" /></view>
					</view>
					<view class="add-field-full"><text class="add-label">描述</text><input class="add-input" v-model="newDesc" placeholder="分类介绍" /></view>
					<view class="add-btn" @tap="addCategory"><text class="add-btn-text">添加分类</text></view>
				</view>
			</view>
		</scroll-view>

		<view class="overlay" v-if="showModal" @tap="showModal=false">
			<view class="modal" @tap.stop>
				<text class="modal-title">编辑分类</text>
				<view class="modal-field"><text class="field-label">名称</text><input class="modal-input" v-model="editForm.name" /></view>
				<view class="modal-field"><text class="field-label">图标</text><input class="modal-input" v-model="editForm.icon" /></view>
				<view class="modal-field"><text class="field-label">颜色</text><input class="modal-input" v-model="editForm.color" placeholder="#ff2442" /></view>
				<view class="modal-field"><text class="field-label">排序</text><input class="modal-input" v-model="editForm.sort_order" type="number" /></view>
				<view class="modal-field"><text class="field-label">描述</text><input class="modal-input" v-model="editForm.description" /></view>
				<view class="modal-field"><text class="field-label">封面</text><input class="modal-input" v-model="editForm.cover" placeholder="图片URL" /></view>
				<view class="modal-field">
					<text class="field-label">状态</text>
					<view class="toggle-row">
						<view class="toggle-opt" :class="{ 'toggle-on': editForm.status === 1 }" @tap="editForm.status=1"><text class="toggle-text">启用</text></view>
						<view class="toggle-opt" :class="{ 'toggle-on': editForm.status === 0 }" @tap="editForm.status=0"><text class="toggle-text">禁用</text></view>
					</view>
				</view>
				<view class="modal-field">
					<text class="field-label">发布</text>
					<view class="toggle-row">
						<view class="toggle-opt" :class="{ 'toggle-on': editForm.publish_restriction === 0 }" @tap="editForm.publish_restriction=0"><text class="toggle-text">所有人</text></view>
						<view class="toggle-opt" :class="{ 'toggle-on': editForm.publish_restriction === 1 }" @tap="editForm.publish_restriction=1"><text class="toggle-text">仅管理员</text></view>
					</view>
				</view>
				<view class="modal-field">
					<text class="field-label">等级限制</text>
					<view class="toggle-row" style="flex-wrap: wrap; gap: 8rpx;">
						<view class="toggle-opt" :class="{ 'toggle-on': editForm.min_level === 0 }" @tap="editForm.min_level=0"><text class="toggle-text">无限制</text></view>
						<view class="toggle-opt" :class="{ 'toggle-on': editForm.min_level === lv }" v-for="lv in [3,5,7,10]" :key="lv" @tap="editForm.min_level=lv"><text class="toggle-text">Lv.{{ lv }}</text></view>
					</view>
				</view>
				<view class="modal-btns">
					<view class="modal-btn modal-cancel" @tap="showModal=false"><text class="modal-btn-text">取消</text></view>
					<view class="modal-btn modal-confirm" @tap="saveCategory"><text class="modal-btn-text-confirm">保存</text></view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { request, BASE_URL } from '@/utils/request.js'

const sys = uni.getSystemInfoSync()
const statusBarH = sys.statusBarHeight || 20

const list = ref([])
const newName = ref('')
const newIcon = ref('')
const newSort = ref('0')
const newColor = ref('')
const newDesc = ref('')
const showModal = ref(false)
const editForm = ref({ id: null, name: '', icon: '', color: '', description: '', cover: '', sort_order: 0, status: 1, publish_restriction: 0, min_level: 0 })

const COLORS = ['#ff2442','#1890ff','#52c41a','#faad14','#722ed1','#13c2c2']
function cateColor(id) { return COLORS[id % COLORS.length] }
function fullUrl(url) { if (!url) return ''; if (url.startsWith('http')) return url; return BASE_URL.replace('/api','') + url }

async function loadData() {
	const res = await request({ url: '/admin/categories' })
	if (res.code === 200) list.value = res.data
}

async function addCategory() {
	if (!newName.value.trim()) return uni.showToast({ title: '请输入分类名', icon: 'none' })
	const res = await request({ url: '/admin/categories', method: 'POST', data: {
		name: newName.value.trim(), icon: newIcon.value, sort_order: Number(newSort.value) || 0,
		color: newColor.value, description: newDesc.value
	}})
	if (res.code === 200) { newName.value = ''; newIcon.value = ''; newSort.value = '0'; newColor.value = ''; newDesc.value = ''; loadData(); uni.showToast({ title: '添加成功', icon: 'none' }) }
	else uni.showToast({ title: res.msg || '添加失败', icon: 'none' })
}

function editCategory(c) {
	editForm.value = { id: c.id, name: c.name, icon: c.icon, color: c.color || '', description: c.description || '', cover: c.cover || '', sort_order: c.sort_order, status: c.status, publish_restriction: c.publish_restriction || 0, min_level: c.min_level || 0 }
	showModal.value = true
}

async function saveCategory() {
	const f = editForm.value
	const res = await request({ url: '/admin/categories/' + f.id, method: 'PUT', data: {
		name: f.name, icon: f.icon, color: f.color, description: f.description, cover: f.cover,
		sort_order: Number(f.sort_order) || 0, status: f.status, publish_restriction: f.publish_restriction, min_level: Number(f.min_level) || 0
	}})
	if (res.code === 200) { showModal.value = false; loadData(); uni.showToast({ title: '保存成功', icon: 'none' }) }
	else uni.showToast({ title: res.msg || '保存失败', icon: 'none' })
}

async function deleteCategory(id) {
	uni.showModal({ title: '确认删除', content: '删除分类后帖子将无分类', confirmColor: '#ff2442', success: async (r) => {
		if (r.confirm) {
			const res = await request({ url: '/admin/categories/' + id, method: 'DELETE' })
			if (res.code === 200) { loadData(); uni.showToast({ title: '已删除', icon: 'none' }) }
		}
	}})
}

function goBack() { uni.navigateBack() }
onMounted(() => loadData())
</script>

<style lang="scss" scoped>
.page-sub { min-height: 100vh; background: #f5f5f5; }
.top-nav { position: fixed; top: 0; left: 0; right: 0; z-index: 999; background: #fff; border-bottom: 1rpx solid #f0f0f0; }
.nav-inner { height: 44px; display: flex; align-items: center; justify-content: center; position: relative; padding: 0 28rpx; }
.nav-left { position: absolute; left: 0; padding: 8rpx 16rpx; }
.back-arrow { font-size: 44rpx; color: #222; font-weight: 300; line-height: 1; }
.nav-title { font-size: 30rpx; font-weight: 600; color: #222; }

.list-scroll { height: calc(100vh - 140rpx); }
.list-inner { padding: 16rpx 28rpx; }
.cate-card { display: flex; align-items: center; background: #fff; border-radius: 12rpx; padding: 24rpx; margin-bottom: 12rpx; }
.cate-icon-box { width: 72rpx; height: 72rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 20rpx; overflow: hidden; }
.cate-cover-thumb { width: 72rpx; height: 72rpx; }
.cate-icon { font-size: 32rpx; color: #fff; font-weight: 700; }
.cate-info { flex: 1; }
.cate-name { font-size: 28rpx; color: #222; font-weight: 500; display: block; }
.cate-sub { font-size: 22rpx; color: #999; display: block; margin-top: 4rpx; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 360rpx; }
.cate-actions { display: flex; gap: 12rpx; }
.act-btn { padding: 8rpx 20rpx; border-radius: 16rpx; }
.act-edit { background: #e8f4fd; }
.act-del { background: #fff0f0; }
.act-text { font-size: 24rpx; }
.act-edit .act-text { color: #1890ff; }
.act-del .act-text { color: #ff2442; }

.add-section { background: #fff; border-radius: 12rpx; padding: 24rpx; margin-top: 16rpx; }
.add-title { font-size: 28rpx; font-weight: 600; color: #222; display: block; margin-bottom: 20rpx; }
.add-row { display: flex; gap: 16rpx; margin-bottom: 12rpx; }
.add-field { flex: 1; }
.add-field-full { margin-bottom: 12rpx; }
.add-label { font-size: 22rpx; color: #999; display: block; margin-bottom: 6rpx; }
.add-input { height: 64rpx; border: 1rpx solid #e8e8e8; border-radius: 8rpx; padding: 0 16rpx; font-size: 26rpx; }
.add-input-short { width: 100rpx; }
.add-btn { height: 72rpx; border-radius: 36rpx; background: #ff2442; display: flex; align-items: center; justify-content: center; margin-top: 12rpx; }
.add-btn:active { opacity: 0.8; }
.add-btn-text { font-size: 28rpx; color: #fff; font-weight: 600; }

.overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.4); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.modal { width: 620rpx; max-height: 80vh; overflow-y: auto; background: #fff; border-radius: 20rpx; padding: 40rpx 32rpx; }
.modal-title { font-size: 32rpx; font-weight: 600; color: #222; display: block; text-align: center; margin-bottom: 28rpx; }
.modal-field { display: flex; align-items: center; margin-bottom: 16rpx; }
.field-label { font-size: 26rpx; color: #666; width: 80rpx; flex-shrink: 0; }
.modal-input { flex: 1; height: 72rpx; border: 1rpx solid #e8e8e8; border-radius: 8rpx; padding: 0 16rpx; font-size: 26rpx; }
.toggle-row { display: flex; gap: 12rpx; }
.toggle-opt { padding: 8rpx 24rpx; border-radius: 16rpx; background: #f5f5f5; }
.toggle-on { background: #ff2442; }
.toggle-text { font-size: 24rpx; color: #666; }
.toggle-on .toggle-text { color: #fff; }
.modal-btns { display: flex; gap: 20rpx; margin-top: 24rpx; }
.modal-btn { flex: 1; height: 76rpx; border-radius: 38rpx; display: flex; align-items: center; justify-content: center; }
.modal-cancel { background: #f5f5f5; }
.modal-btn-text { font-size: 28rpx; color: #666; }
.modal-confirm { background: #ff2442; }
.modal-btn-text-confirm { font-size: 28rpx; color: #fff; font-weight: 600; }
.official-tag { font-size: 20rpx; color: #ff2442; background: #fff0f0; padding: 2rpx 10rpx; border-radius: 6rpx; margin-left: 8rpx; font-weight: 600; }
.level-tag { font-size: 20rpx; color: #722ed1; background: #f9f0ff; padding: 2rpx 10rpx; border-radius: 6rpx; margin-left: 8rpx; font-weight: 600; }
</style>
