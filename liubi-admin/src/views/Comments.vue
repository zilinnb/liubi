<template>
  <div class="comments-page">
    <div class="card">
      <el-table :data="comments" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="userName" label="评论者" width="120" show-overflow-tooltip />
        <el-table-column prop="postTitle" label="帖子标题" min-width="180" show-overflow-tooltip />
        <el-table-column label="内容" min-width="250" show-overflow-tooltip>
          <template #default="{ row }">
            <el-tooltip :content="row.content" placement="top" :disabled="!row.content || row.content.length <= 40">
              <span>{{ row.content || '-' }}</span>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column prop="likeCount" label="点赞" width="70" />
        <el-table-column label="创建时间" width="160" show-overflow-tooltip>
          <template #default="{ row }">{{ formatDate(row.created_at || row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
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
          @current-change="loadComments"
          @size-change="loadComments"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getComments, deleteComment } from '../api/admin'

const loading = ref(false)
const comments = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleString('zh-CN')
}

const loadComments = async () => {
  loading.value = true
  try {
    const res = await getComments({ page: page.value, pageSize: pageSize.value })
    if (res.code === 200) {
      comments.value = res.data?.list || res.data?.comments || []
      total.value = res.data?.total || 0
    }
  } catch {} finally {
    loading.value = false
  }
}

const handleDelete = async (row) => {
  await ElMessageBox.confirm('确定删除该评论？此操作不可恢复', '警告', { type: 'error' })
  const res = await deleteComment(row.id)
  if (res.code === 200) {
    ElMessage.success('删除成功')
    loadComments()
  }
}

onMounted(loadComments)
</script>

<style scoped>
.card {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}
</style>
