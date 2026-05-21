<template>
  <div class="users-page">
    <div class="card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-input v-model="keyword" placeholder="搜索昵称/邮箱" clearable style="width: 240px;" @keyup.enter="handleSearch" @clear="handleSearch">
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
          <el-select v-model="roleFilter" placeholder="角色筛选" clearable style="width: 140px;" @change="handleSearch">
            <el-option label="普通用户" :value="0" />
            <el-option label="管理员" :value="1" />
            <el-option label="超级管理员" :value="2" />
          </el-select>
          <el-select v-model="statusFilter" placeholder="状态筛选" clearable style="width: 140px;" @change="handleSearch">
            <el-option label="正常" :value="1" />
            <el-option label="禁用" :value="0" />
          </el-select>
          <el-button type="primary" @click="handleSearch">搜索</el-button>
        </div>
      </div>

      <el-table :data="users" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="头像" width="70">
          <template #default="{ row }">
            <el-avatar :size="36" :src="row.avatar">{{ row.nickname?.[0] || '?' }}</el-avatar>
          </template>
        </el-table-column>
        <el-table-column prop="nickname" label="昵称" min-width="110" show-overflow-tooltip />
        <el-table-column prop="email" label="邮箱" min-width="170" show-overflow-tooltip />
        <el-table-column label="角色" width="110">
          <template #default="{ row }">
            <el-tag :type="roleMap[row.role]?.type || 'info'" size="small">{{ roleMap[row.role]?.label || '未知' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="coins" label="留币" width="80" />
        <el-table-column label="等级" width="80">
          <template #default="{ row }">
            <el-tag type="warning" size="small">Lv.{{ row.level || 0 }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">{{ row.status === 1 ? '正常' : '禁用' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="注册时间" width="160" show-overflow-tooltip>
          <template #default="{ row }">{{ formatDate(row.created_at || row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleEdit(row)">编辑</el-button>
            <el-button v-if="row.status === 1" type="danger" text size="small" @click="handleToggleStatus(row)">禁用</el-button>
            <el-button v-else type="success" text size="small" @click="handleToggleStatus(row)">启用</el-button>
            <el-button type="warning" text size="small" @click="handleMute(row)">禁言</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination">
        <el-pagination
          background
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          :page-sizes="[10, 20, 50, 100]"
          :page-size="pageSize"
          v-model:current-page="page"
          v-model:page-size="pageSize"
          @current-change="loadUsers"
          @size-change="loadUsers"
        />
      </div>
    </div>

    <!-- 编辑弹窗 -->
    <el-dialog v-model="editDialogVisible" title="编辑用户" width="500px" destroy-on-close>
      <el-form ref="editFormRef" :model="editForm" :rules="editRules" label-width="80px">
        <el-form-item label="昵称" prop="nickname">
          <el-input v-model="editForm.nickname" placeholder="请输入昵称" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="editForm.email" placeholder="请输入邮箱" />
        </el-form-item>
        <el-form-item label="简介">
          <el-input v-model="editForm.bio" type="textarea" :rows="3" placeholder="请输入简介" />
        </el-form-item>
        <el-form-item label="角色" prop="role">
          <el-select v-model="editForm.role" style="width: 100%;">
            <el-option label="普通用户" :value="0" />
            <el-option label="管理员" :value="1" />
            <el-option label="超级管理员" :value="2" />
          </el-select>
        </el-form-item>
        <el-form-item label="头像URL">
          <el-input v-model="editForm.avatar" placeholder="请输入头像URL" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="editLoading" @click="submitEdit">保存</el-button>
      </template>
    </el-dialog>

    <!-- 禁言弹窗 -->
    <el-dialog v-model="muteDialogVisible" title="禁言设置" width="440px" destroy-on-close>
      <el-form :model="muteForm" label-width="80px">
        <el-form-item label="用户">
          <span>{{ muteForm.nickname }}</span>
        </el-form-item>
        <el-form-item label="禁言到期">
          <el-date-picker
            v-model="muteForm.mute_until"
            type="datetime"
            placeholder="选择禁言到期时间"
            style="width: 100%;"
            :disabled-date="(date) => date < new Date()"
          />
        </el-form-item>
        <el-form-item>
          <div class="quick-mute">
            <el-button size="small" @click="setMuteUntil(1)">1小时</el-button>
            <el-button size="small" @click="setMuteUntil(6)">6小时</el-button>
            <el-button size="small" @click="setMuteUntil(24)">1天</el-button>
            <el-button size="small" @click="setMuteUntil(168)">7天</el-button>
            <el-button size="small" @click="setMuteUntil(720)">30天</el-button>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="muteDialogVisible = false">取消</el-button>
        <el-button type="danger" :loading="muteLoading" @click="submitMute">确定禁言</el-button>
        <el-button type="warning" @click="submitUnmute">解除禁言</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getUsers, updateUser, updateUserStatus, muteUser } from '../api/admin'

const loading = ref(false)
const editLoading = ref(false)
const muteLoading = ref(false)
const users = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const keyword = ref('')
const roleFilter = ref(undefined)
const statusFilter = ref(undefined)

const roleMap = {
  0: { label: '普通', type: 'info' },
  1: { label: '管理员', type: 'danger' },
  2: { label: '超管', type: '' }
}

const editDialogVisible = ref(false)
const editFormRef = ref(null)
const editForm = reactive({
  id: null,
  nickname: '',
  email: '',
  bio: '',
  role: 0,
  avatar: ''
})

const editRules = {
  nickname: [{ required: true, message: '请输入昵称', trigger: 'blur' }],
  email: [{ required: true, message: '请输入邮箱', trigger: 'blur' }],
  role: [{ required: true, message: '请选择角色', trigger: 'change' }]
}

const muteDialogVisible = ref(false)
const muteForm = reactive({
  userId: null,
  nickname: '',
  mute_until: null
})

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleString('zh-CN')
}

const handleSearch = () => {
  page.value = 1
  loadUsers()
}

const loadUsers = async () => {
  loading.value = true
  try {
    const params = { page: page.value, pageSize: pageSize.value }
    if (keyword.value) params.keyword = keyword.value
    if (roleFilter.value !== undefined && roleFilter.value !== null) params.role = roleFilter.value
    if (statusFilter.value !== undefined && statusFilter.value !== null) params.status = statusFilter.value
    const res = await getUsers(params)
    if (res.code === 200) {
      users.value = res.data?.list || res.data?.users || []
      total.value = res.data?.total || 0
    }
  } catch {} finally {
    loading.value = false
  }
}

const handleEdit = (row) => {
  editForm.id = row.id
  editForm.nickname = row.nickname || ''
  editForm.email = row.email || ''
  editForm.bio = row.bio || ''
  editForm.role = row.role
  editForm.avatar = row.avatar || ''
  editDialogVisible.value = true
}

const submitEdit = async () => {
  const valid = await editFormRef.value.validate().catch(() => false)
  if (!valid) return
  editLoading.value = true
  try {
    const res = await updateUser(editForm.id, {
      nickname: editForm.nickname,
      email: editForm.email,
      bio: editForm.bio,
      role: editForm.role,
      avatar: editForm.avatar
    })
    if (res.code === 200) {
      ElMessage.success('更新成功')
      editDialogVisible.value = false
      loadUsers()
    }
  } catch {} finally {
    editLoading.value = false
  }
}

const handleToggleStatus = async (row) => {
  const action = row.status === 1 ? '禁用' : '启用'
  await ElMessageBox.confirm(`确定${action}用户「${row.nickname}」？`, '提示', { type: 'warning' })
  const res = await updateUserStatus(row.id, { status: row.status === 1 ? 0 : 1 })
  if (res.code === 200) {
    ElMessage.success(`${action}成功`)
    loadUsers()
  }
}

const handleMute = (row) => {
  muteForm.userId = row.id
  muteForm.nickname = row.nickname
  muteForm.mute_until = null
  muteDialogVisible.value = true
}

const setMuteUntil = (hours) => {
  const date = new Date()
  date.setHours(date.getHours() + hours)
  muteForm.mute_until = date
}

const submitMute = async () => {
  if (!muteForm.mute_until) {
    ElMessage.warning('请选择禁言到期时间')
    return
  }
  muteLoading.value = true
  try {
    const dateStr = muteForm.mute_until instanceof Date
      ? muteForm.mute_until.toISOString().slice(0, 10)
      : muteForm.mute_until
    const res = await muteUser(muteForm.userId, { mute_until: dateStr })
    if (res.code === 200) {
      ElMessage.success('禁言成功')
      muteDialogVisible.value = false
      loadUsers()
    }
  } catch {} finally {
    muteLoading.value = false
  }
}

const submitUnmute = async () => {
  muteLoading.value = true
  try {
    const res = await muteUser(muteForm.userId, { mute_until: null })
    if (res.code === 200) {
      ElMessage.success('已解除禁言')
      muteDialogVisible.value = false
      loadUsers()
    }
  } catch {} finally {
    muteLoading.value = false
  }
}

onMounted(loadUsers)
</script>

<style scoped>
.card {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.toolbar-left {
  display: flex;
  gap: 12px;
  align-items: center;
}
.pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}
.quick-mute {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
</style>
