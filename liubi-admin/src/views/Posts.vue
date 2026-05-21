<template>
  <div class="posts-page">
    <div class="card">
      <div class="toolbar">
        <el-tabs v-model="statusFilter" @tab-change="handleFilterChange">
          <el-tab-pane label="全部" name="" />
          <el-tab-pane label="正常" name="1" />
          <el-tab-pane label="待审核" name="0" />
          <el-tab-pane label="已下架" name="2" />
        </el-tabs>
      </div>

      <el-table :data="posts" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="authorName" label="作者" width="110" show-overflow-tooltip />
        <el-table-column label="标题" min-width="200" show-overflow-tooltip>
          <template #default="{ row }">
            <el-link type="primary" @click="handleViewDetail(row)">{{ row.title }}</el-link>
          </template>
        </el-table-column>
        <el-table-column prop="categoryName" label="分类" width="100" show-overflow-tooltip />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMap[row.status]?.type || 'info'" size="small">{{ statusMap[row.status]?.label || '未知' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="likeCount" label="点赞" width="70" />
        <el-table-column prop="commentCount" label="评论" width="70" />
        <el-table-column label="创建时间" width="160" show-overflow-tooltip>
          <template #default="{ row }">{{ formatDate(row.created_at || row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 0" type="success" text size="small" @click="handleApprove(row)">审核通过</el-button>
            <el-button v-if="row.status === 1" type="warning" text size="small" @click="handleOffShelf(row)">下架</el-button>
            <el-button v-if="row.status === 2" type="success" text size="small" @click="handleRecover(row)">恢复</el-button>
            <el-button type="danger" text size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination">
        <el-pagination
          background
          layout="total, sizes, prev, pager, next"
          :total="total"
          :page-sizes="[10, 20, 50]"
          :page-size="pageSize"
          v-model:current-page="page"
          v-model:page-size="pageSize"
          @current-change="loadPosts"
          @size-change="loadPosts"
        />
      </div>
    </div>

    <!-- 帖子详情抽屉 -->
    <el-drawer v-model="drawerVisible" title="帖子详情" size="500px">
      <div class="post-detail" v-if="currentPost">
        <div class="detail-item">
          <span class="detail-label">ID</span>
          <span>{{ currentPost.id }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">作者</span>
          <span>{{ currentPost.authorName || '-' }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">标题</span>
          <span>{{ currentPost.title }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">分类</span>
          <span>{{ currentPost.categoryName || '-' }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">状态</span>
          <el-tag :type="statusMap[currentPost.status]?.type || 'info'" size="small">{{ statusMap[currentPost.status]?.label || '未知' }}</el-tag>
        </div>
        <div class="detail-item">
          <span class="detail-label">点赞</span>
          <span>{{ currentPost.likeCount || 0 }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">评论</span>
          <span>{{ currentPost.commentCount || 0 }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">创建时间</span>
          <span>{{ formatDate(currentPost.created_at || currentPost.createdAt) }}</span>
        </div>
        <div class="detail-content">
          <span class="detail-label">内容</span>
          <div class="content-box" v-html="currentPost.content || '暂无内容'"></div>
        </div>
      </div>
    </el-drawer>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getPosts, updatePostStatus, deletePost } from '../api/admin'

const loading = ref(false)
const posts = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const statusFilter = ref('')

const drawerVisible = ref(false)
const currentPost = ref(null)

const statusMap = {
  0: { label: '待审核', type: 'warning' },
  1: { label: '正常', type: 'success' },
  2: { label: '已下架', type: 'danger' }
}

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleString('zh-CN')
}

const handleFilterChange = () => {
  page.value = 1
  loadPosts()
}

const loadPosts = async () => {
  loading.value = true
  try {
    const params = { page: page.value, pageSize: pageSize.value }
    if (statusFilter.value !== '') params.status = Number(statusFilter.value)
    const res = await getPosts(params)
    if (res.code === 200) {
      posts.value = res.data?.list || res.data?.posts || []
      total.value = res.data?.total || 0
    }
  } catch {} finally {
    loading.value = false
  }
}

const handleViewDetail = (row) => {
  currentPost.value = row
  drawerVisible.value = true
}

const handleApprove = async (row) => {
  await ElMessageBox.confirm(`确定审核通过帖子「${row.title}」？`, '提示', { type: 'info' })
  const res = await updatePostStatus(row.id, { status: 1 })
  if (res.code === 200) {
    ElMessage.success('审核通过')
    loadPosts()
  }
}

const handleOffShelf = async (row) => {
  await ElMessageBox.confirm(`确定下架帖子「${row.title}」？`, '提示', { type: 'warning' })
  const res = await updatePostStatus(row.id, { status: 2 })
  if (res.code === 200) {
    ElMessage.success('已下架')
    loadPosts()
  }
}

const handleRecover = async (row) => {
  await ElMessageBox.confirm(`确定恢复帖子「${row.title}」？`, '提示', { type: 'info' })
  const res = await updatePostStatus(row.id, { status: 1 })
  if (res.code === 200) {
    ElMessage.success('已恢复')
    loadPosts()
  }
}

const handleDelete = async (row) => {
  await ElMessageBox.confirm(`确定删除帖子「${row.title}」？此操作不可恢复`, '警告', { type: 'error' })
  const res = await deletePost(row.id)
  if (res.code === 200) {
    ElMessage.success('删除成功')
    loadPosts()
  }
}

onMounted(loadPosts)
</script>

<style scoped>
.card {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.toolbar {
  margin-bottom: 4px;
}
.toolbar :deep(.el-tabs__header) {
  margin-bottom: 0;
}
.pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}
.post-detail {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.detail-item {
  display: flex;
  gap: 12px;
  align-items: center;
}
.detail-label {
  font-size: 14px;
  color: #999;
  min-width: 70px;
  flex-shrink: 0;
}
.detail-content {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.content-box {
  background: #fafafa;
  border-radius: 8px;
  padding: 16px;
  font-size: 14px;
  line-height: 1.8;
  color: #333;
  max-height: 400px;
  overflow-y: auto;
}
</style>
