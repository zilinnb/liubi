<template>
  <div class="categories-page">
    <div class="card">
      <div class="toolbar">
        <el-button type="primary" @click="handleAdd">
          <el-icon><Plus /></el-icon>添加分类
        </el-button>
      </div>

      <el-table :data="categories" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="图标" width="80">
          <template #default="{ row }">
            <span v-if="row.icon" style="font-size: 24px;">{{ row.icon }}</span>
            <span v-else style="color: #ccc;">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" min-width="120" />
        <el-table-column prop="description" label="描述" min-width="180" show-overflow-tooltip />
        <el-table-column prop="sort_order" label="排序" width="80">
          <template #default="{ row }">{{ row.sort_order ?? row.sort ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">{{ row.status === 1 ? '启用' : '禁用' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="发帖限制等级" width="120">
          <template #default="{ row }">
            <el-tag v-if="row.publish_restriction" type="warning" size="small">Lv.{{ row.publish_restriction }}</el-tag>
            <span v-else style="color: #ccc;">无限制</span>
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

    <!-- 添加/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑分类' : '添加分类'" width="520px" destroy-on-close>
      <el-form ref="formRef" :model="form" :rules="formRules" label-width="100px">
        <el-form-item label="名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入分类名称" />
        </el-form-item>
        <el-form-item label="图标">
          <el-input v-model="form.icon" placeholder="请输入图标emoji" />
        </el-form-item>
        <el-form-item label="封面">
          <el-input v-model="form.cover" placeholder="请输入封面图URL" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="3" placeholder="请输入分类描述" />
        </el-form-item>
        <el-form-item label="颜色">
          <el-color-picker v-model="form.color" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :min="0" />
        </el-form-item>
        <el-form-item label="状态">
          <el-switch v-model="form.status" :active-value="1" :inactive-value="0" active-text="启用" inactive-text="禁用" />
        </el-form-item>
        <el-form-item label="发帖限制等级">
          <el-input-number v-model="form.publish_restriction" :min="0" :max="99" placeholder="0表示无限制" />
          <span style="margin-left: 8px; color: #999; font-size: 12px;">0为无限制</span>
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
import { getCategories, createCategory, updateCategory, deleteCategory } from '../api/admin'

const loading = ref(false)
const submitLoading = ref(false)
const categories = ref([])
const dialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const form = reactive({
  id: null,
  name: '',
  icon: '',
  cover: '',
  description: '',
  color: '#FF2442',
  sort_order: 0,
  status: 1,
  publish_restriction: 0
})

const formRules = {
  name: [{ required: true, message: '请输入分类名称', trigger: 'blur' }]
}

const resetForm = () => {
  form.id = null
  form.name = ''
  form.icon = ''
  form.cover = ''
  form.description = ''
  form.color = '#FF2442'
  form.sort_order = 0
  form.status = 1
  form.publish_restriction = 0
}

const loadCategories = async () => {
  loading.value = true
  try {
    const res = await getCategories()
    if (res.code === 200) {
      categories.value = res.data?.list || res.data || []
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
  form.name = row.name || ''
  form.icon = row.icon || ''
  form.cover = row.cover || ''
  form.description = row.description || ''
  form.color = row.color || '#FF2442'
  form.sort_order = row.sort_order ?? row.sort ?? 0
  form.status = row.status ?? 1
  form.publish_restriction = row.publish_restriction ?? 0
  isEdit.value = true
  dialogVisible.value = true
}

const submitForm = async () => {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  submitLoading.value = true
  try {
    const data = {
      name: form.name,
      icon: form.icon,
      cover: form.cover,
      description: form.description,
      color: form.color,
      sort_order: form.sort_order,
      status: form.status,
      publish_restriction: form.publish_restriction
    }
    const res = isEdit.value ? await updateCategory(form.id, data) : await createCategory(data)
    if (res.code === 200) {
      ElMessage.success(isEdit.value ? '更新成功' : '添加成功')
      dialogVisible.value = false
      loadCategories()
    }
  } catch {} finally {
    submitLoading.value = false
  }
}

const handleDelete = async (row) => {
  await ElMessageBox.confirm(`确定删除分类「${row.name}」？此操作不可恢复`, '警告', { type: 'error' })
  const res = await deleteCategory(row.id)
  if (res.code === 200) {
    ElMessage.success('删除成功')
    loadCategories()
  }
}

onMounted(loadCategories)
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
