<template>
  <div class="version-page">
    <div class="card">
      <div class="toolbar">
        <el-button type="primary" @click="handleAdd">
          <el-icon><Plus /></el-icon>发布新版本
        </el-button>
      </div>

      <el-table :data="versions" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="version_code" label="版本号" width="120">
          <template #default="{ row }">{{ row.version_code || row.version || '-' }}</template>
        </el-table-column>
        <el-table-column prop="version_name" label="版本名" min-width="150" show-overflow-tooltip>
          <template #default="{ row }">{{ row.version_name || row.name || '-' }}</template>
        </el-table-column>
        <el-table-column label="平台" width="100">
          <template #default="{ row }">
            <el-tag size="small">{{ platformMap[row.platform] || row.platform }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="更新类型" width="100">
          <template #default="{ row }">
            <el-tag :type="updateTypeMap[row.update_type ?? row.updateType]?.type || 'info'" size="small">{{ updateTypeMap[row.update_type ?? row.updateType]?.label || '未知' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="强制更新" width="100">
          <template #default="{ row }">
            <el-tag :type="(row.force_update ?? row.forceUpdate) ? 'danger' : 'info'" size="small">{{ (row.force_update ?? row.forceUpdate) ? '是' : '否' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="download_url" label="下载地址" min-width="200" show-overflow-tooltip>
          <template #default="{ row }">{{ row.download_url || row.downloadUrl || '-' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small">{{ row.status === 1 ? '已发布' : '草稿' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleEdit(row)">编辑</el-button>
            <el-button type="danger" text size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 发布/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑版本' : '发布新版本'" width="560px" destroy-on-close>
      <el-form ref="formRef" :model="form" :rules="formRules" label-width="100px">
        <el-form-item label="版本号" prop="version_code">
          <el-input v-model="form.version_code" placeholder="例如：1.0.0" />
        </el-form-item>
        <el-form-item label="版本名" prop="version_name">
          <el-input v-model="form.version_name" placeholder="请输入版本名称" />
        </el-form-item>
        <el-form-item label="平台" prop="platform">
          <el-select v-model="form.platform" style="width: 100%;">
            <el-option label="Android" value="android" />
            <el-option label="iOS" value="ios" />
            <el-option label="全平台" value="all" />
          </el-select>
        </el-form-item>
        <el-form-item label="更新类型" prop="update_type">
          <el-select v-model="form.update_type" style="width: 100%;">
            <el-option label="功能更新" :value="1" />
            <el-option label="Bug修复" :value="2" />
            <el-option label="安全更新" :value="3" />
          </el-select>
        </el-form-item>
        <el-form-item label="强制更新">
          <el-switch v-model="form.force_update" :active-value="1" :inactive-value="0" active-text="强制" inactive-text="可选" />
        </el-form-item>
        <el-form-item label="下载地址">
          <el-input v-model="form.download_url" placeholder="请输入下载地址" />
        </el-form-item>
        <el-form-item label="更新内容">
          <el-input v-model="form.update_content" type="textarea" :rows="4" placeholder="请输入更新内容" />
        </el-form-item>
        <el-form-item label="包大小">
          <el-input v-model="form.package_size" placeholder="例如：24.7MB" />
        </el-form-item>
        <el-form-item label="状态" v-if="isEdit">
          <el-select v-model="form.status" style="width: 100%;">
            <el-option label="草稿" :value="0" />
            <el-option label="已发布" :value="1" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitLoading" @click="submitForm">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getVersions, createVersion, updateVersion, deleteVersion } from '../api/admin'

const loading = ref(false)
const submitLoading = ref(false)
const versions = ref([])
const dialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const platformMap = { android: 'Android', ios: 'iOS', all: '全平台' }
const updateTypeMap = {
  1: { label: '功能更新', type: 'primary' },
  2: { label: 'Bug修复', type: 'warning' },
  3: { label: '安全更新', type: 'danger' }
}

const form = reactive({
  id: null,
  version_code: '',
  version_name: '',
  platform: 'android',
  update_type: 1,
  force_update: 0,
  download_url: '',
  update_content: '',
  package_size: '',
  status: 0
})

const formRules = {
  version_code: [{ required: true, message: '请输入版本号', trigger: 'blur' }],
  version_name: [{ required: true, message: '请输入版本名', trigger: 'blur' }],
  platform: [{ required: true, message: '请选择平台', trigger: 'change' }],
  update_type: [{ required: true, message: '请选择更新类型', trigger: 'change' }]
}

const resetForm = () => {
  form.id = null
  form.version_code = ''
  form.version_name = ''
  form.platform = 'android'
  form.update_type = 1
  form.force_update = 0
  form.download_url = ''
  form.update_content = ''
  form.package_size = 0
  form.status = 0
}

const loadVersions = async () => {
  loading.value = true
  try {
    const res = await getVersions()
    if (res.code === 200) {
      versions.value = res.data?.list || res.data || []
    }
  } catch {} finally {
    loading.value = false
  }
}

const handleAdd = () => {
  resetForm()
  isEdit.value = false
  dialogVisible.value = true
}

const handleEdit = (row) => {
  form.id = row.id
  form.version_code = row.version_code || row.version || ''
  form.version_name = row.version_name || row.name || ''
  form.platform = row.platform || 'android'
  form.update_type = row.update_type ?? row.updateType ?? 1
  form.force_update = row.force_update ?? row.forceUpdate ?? 0
  form.download_url = row.download_url || row.downloadUrl || ''
  form.update_content = row.update_content || ''
  form.package_size = row.package_size ? String(row.package_size) : ''
  form.status = row.status ?? 0
  isEdit.value = true
  dialogVisible.value = true
}

const submitForm = async () => {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  submitLoading.value = true
  try {
    const data = {
      version_code: form.version_code,
      version_name: form.version_name,
      platform: form.platform,
      update_type: form.update_type,
      force_update: form.force_update,
      download_url: form.download_url,
      update_content: form.update_content,
      package_size: form.package_size
    }
    if (isEdit.value) data.status = form.status
    const res = isEdit.value ? await updateVersion(form.id, data) : await createVersion(data)
    if (res.code === 200) {
      ElMessage.success(isEdit.value ? '更新成功' : '发布成功')
      dialogVisible.value = false
      loadVersions()
    }
  } catch {} finally {
    submitLoading.value = false
  }
}

const handleDelete = async (row) => {
  await ElMessageBox.confirm(`确定删除版本 ${row.version_code || row.version}？此操作不可恢复`, '警告', { type: 'error' })
  const res = await deleteVersion(row.id)
  if (res.code === 200) {
    ElMessage.success('删除成功')
    loadVersions()
  }
}

onMounted(loadVersions)
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
</style>
