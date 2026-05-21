<template>
  <div class="conversations-page">
    <div class="card">
      <div class="toolbar">
        <el-radio-group v-model="typeFilter" @change="handleFilterChange">
          <el-radio-button label="">全部</el-radio-button>
          <el-radio-button label="1">私聊</el-radio-button>
          <el-radio-button label="2">群聊</el-radio-button>
        </el-radio-group>
      </div>

      <el-table :data="conversations" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="类型" width="90">
          <template #default="{ row }">
            <el-tag :type="row.type === 2 || row.type === 'group' ? '' : 'success'" size="small">{{ row.type === 2 || row.type === 'group' ? '群聊' : '私聊' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" min-width="150" show-overflow-tooltip />
        <el-table-column prop="memberCount" label="成员数" width="90" />
        <el-table-column prop="group_code" label="群聊号" width="120">
          <template #default="{ row }">{{ row.group_code || row.groupCode || '-' }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="160" show-overflow-tooltip>
          <template #default="{ row }">{{ formatDate(row.created_at || row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.type === 2 || row.type === 'group'" type="primary" text size="small" @click="handleEditCode(row)">编辑群聊号</el-button>
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
          @current-change="loadConversations"
          @size-change="loadConversations"
        />
      </div>
    </div>

    <!-- 编辑群聊号弹窗 -->
    <el-dialog v-model="codeDialogVisible" title="编辑群聊号" width="440px" destroy-on-close>
      <el-form :model="codeForm" label-width="80px">
        <el-form-item label="群聊号">
          <el-input v-model="codeForm.group_code" placeholder="请输入群聊号" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="codeDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="codeLoading" @click="submitCode">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getConversations, updateGroupCode, deleteConversation } from '../api/admin'

const loading = ref(false)
const codeLoading = ref(false)
const conversations = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const typeFilter = ref('')

const codeDialogVisible = ref(false)
const codeForm = reactive({ id: null, group_code: '' })

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleString('zh-CN')
}

const handleFilterChange = () => {
  page.value = 1
  loadConversations()
}

const loadConversations = async () => {
  loading.value = true
  try {
    const params = { page: page.value, pageSize: pageSize.value }
    if (typeFilter.value) params.type = Number(typeFilter.value)
    const res = await getConversations(params)
    if (res.code === 200) {
      conversations.value = res.data?.list || res.data?.conversations || []
      total.value = res.data?.total || 0
    }
  } catch {} finally {
    loading.value = false
  }
}

const handleEditCode = (row) => {
  codeForm.id = row.id
  codeForm.group_code = row.group_code || row.groupCode || ''
  codeDialogVisible.value = true
}

const submitCode = async () => {
  codeLoading.value = true
  try {
    const res = await updateGroupCode(codeForm.id, { group_code: codeForm.group_code })
    if (res.code === 200) {
      ElMessage.success('更新成功')
      codeDialogVisible.value = false
      loadConversations()
    }
  } catch {} finally {
    codeLoading.value = false
  }
}

const handleDelete = async (row) => {
  await ElMessageBox.confirm('确定删除该会话？此操作不可恢复', '警告', { type: 'error' })
  const res = await deleteConversation(row.id)
  if (res.code === 200) {
    ElMessage.success('删除成功')
    loadConversations()
  }
}

onMounted(loadConversations)
</script>

<style scoped>
.card {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.toolbar {
  margin-bottom: 20px;
}
.pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}
</style>
