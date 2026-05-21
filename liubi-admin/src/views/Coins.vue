<template>
  <div class="coins-page">
    <!-- 用户留币 -->
    <div class="card" style="margin-bottom: 20px;">
      <div class="card-header">用户留币管理</div>
      <div class="toolbar">
        <el-input v-model="keyword" placeholder="搜索昵称" clearable style="width: 240px;" @keyup.enter="handleSearch" @clear="handleSearch">
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>
        <el-button type="primary" @click="handleSearch">搜索</el-button>
      </div>
      <el-table :data="coinUsers" v-loading="loading" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="头像" width="70">
          <template #default="{ row }">
            <el-avatar :size="36" :src="row.avatar">{{ row.nickname?.[0] || '?' }}</el-avatar>
          </template>
        </el-table-column>
        <el-table-column prop="nickname" label="昵称" min-width="120" show-overflow-tooltip />
        <el-table-column prop="coins" label="留币余额" width="110" />
        <el-table-column label="等级" width="80">
          <template #default="{ row }">
            <el-tag type="warning" size="small">Lv.{{ row.level || 0 }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="exp" label="经验值" width="100" />
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleAdjustCoins(row)">调整留币</el-button>
            <el-button type="warning" text size="small" @click="handleAdjustExp(row)">调整经验</el-button>
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
          @current-change="loadCoinUsers"
          @size-change="loadCoinUsers"
        />
      </div>
    </div>

    <!-- 等级配置 -->
    <div class="card" style="margin-bottom: 20px;">
      <div class="card-header">等级配置</div>
      <el-table :data="levelConfig" stripe style="width: 100%;">
        <el-table-column prop="level" label="等级" width="100">
          <template #default="{ row }">
            <el-tag type="warning" size="small">Lv.{{ row.level }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" min-width="150" />
        <el-table-column prop="minExp" label="所需经验值" width="150">
          <template #default="{ row }">{{ row.minExp ?? row.min_exp ?? '-' }}</template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 签到配置 -->
    <div class="card">
      <div class="card-header">签到配置</div>
      <el-form :model="coinConfigForm" label-width="140px" v-loading="configLoading">
        <el-form-item v-for="item in coinConfigList" :key="item.key" :label="item.description || item.key">
          <el-input-number v-model="coinConfigForm[item.key]" :min="0" v-if="typeof item.value === 'number'" />
          <el-input v-model="coinConfigForm[item.key]" v-else />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="savingConfig" @click="saveCoinConfig">保存配置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- 调整留币弹窗 -->
    <el-dialog v-model="coinsDialogVisible" title="调整留币" width="440px" destroy-on-close>
      <el-form :model="adjustForm" label-width="80px">
        <el-form-item label="用户">
          <span>{{ adjustForm.nickname }}</span>
        </el-form-item>
        <el-form-item label="调整数量">
          <el-input-number v-model="adjustForm.amount" :step="1" />
          <span style="margin-left: 8px; color: #999; font-size: 12px;">正数增加，负数减少</span>
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="adjustForm.description" placeholder="请输入调整说明" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="coinsDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="adjustLoading" @click="submitAdjustCoins">确定</el-button>
      </template>
    </el-dialog>

    <!-- 调整经验弹窗 -->
    <el-dialog v-model="expDialogVisible" title="调整经验值" width="440px" destroy-on-close>
      <el-form :model="expForm" label-width="80px">
        <el-form-item label="用户">
          <span>{{ expForm.nickname }}</span>
        </el-form-item>
        <el-form-item label="调整数量">
          <el-input-number v-model="expForm.amount" :step="1" />
          <span style="margin-left: 8px; color: #999; font-size: 12px;">正数增加，负数减少</span>
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="expForm.description" placeholder="请输入调整说明" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="expDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="expLoading" @click="submitAdjustExp">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getCoinUsers, adjustCoins, adjustExp, getLevelConfig, getCoinConfig, updateCoinConfig } from '../api/admin'

const loading = ref(false)
const configLoading = ref(false)
const savingConfig = ref(false)
const adjustLoading = ref(false)
const expLoading = ref(false)
const coinUsers = ref([])
const levelConfig = ref([])
const coinConfigList = ref([])
const coinConfigForm = reactive({})
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const keyword = ref('')

const coinsDialogVisible = ref(false)
const adjustForm = reactive({ userId: null, nickname: '', amount: 1, description: '' })

const expDialogVisible = ref(false)
const expForm = reactive({ userId: null, nickname: '', amount: 1, description: '' })

const handleSearch = () => {
  page.value = 1
  loadCoinUsers()
}

const loadCoinUsers = async () => {
  loading.value = true
  try {
    const params = { page: page.value, pageSize: pageSize.value }
    if (keyword.value) params.nickname = keyword.value
    const res = await getCoinUsers(params)
    if (res.code === 200) {
      coinUsers.value = res.data?.list || res.data?.users || []
      total.value = res.data?.total || 0
    }
  } catch {} finally {
    loading.value = false
  }
}

const loadLevelConfig = async () => {
  try {
    const res = await getLevelConfig()
    if (res.code === 200) {
      levelConfig.value = res.data?.list || res.data || []
    }
  } catch {}
}

const loadCoinConfig = async () => {
  configLoading.value = true
  try {
    const res = await getCoinConfig()
    if (res.code === 200 && res.data) {
      const list = Array.isArray(res.data) ? res.data : []
      coinConfigList.value = list
      list.forEach(item => {
        const val = isNaN(Number(item.value)) ? item.value : Number(item.value)
        coinConfigForm[item.key] = val
      })
    }
  } catch {} finally {
    configLoading.value = false
  }
}

const saveCoinConfig = async () => {
  savingConfig.value = true
  try {
    for (const item of coinConfigList.value) {
      await updateCoinConfig({ key: item.key, value: String(coinConfigForm[item.key]) })
    }
    ElMessage.success('保存成功')
  } catch {} finally {
    savingConfig.value = false
  }
}

const handleAdjustCoins = (row) => {
  adjustForm.userId = row.id
  adjustForm.nickname = row.nickname
  adjustForm.amount = 1
  adjustForm.description = ''
  coinsDialogVisible.value = true
}

const submitAdjustCoins = async () => {
  if (adjustForm.amount === 0) {
    ElMessage.warning('调整数量不能为0')
    return
  }
  adjustLoading.value = true
  try {
    const res = await adjustCoins({
      user_id: adjustForm.userId,
      amount: adjustForm.amount,
      description: adjustForm.description
    })
    if (res.code === 200) {
      ElMessage.success('调整成功')
      coinsDialogVisible.value = false
      loadCoinUsers()
    }
  } catch {} finally {
    adjustLoading.value = false
  }
}

const handleAdjustExp = (row) => {
  expForm.userId = row.id
  expForm.nickname = row.nickname
  expForm.amount = 1
  expForm.description = ''
  expDialogVisible.value = true
}

const submitAdjustExp = async () => {
  if (expForm.amount === 0) {
    ElMessage.warning('调整数量不能为0')
    return
  }
  expLoading.value = true
  try {
    const res = await adjustExp({
      user_id: expForm.userId,
      exp: expForm.amount
    })
    if (res.code === 200) {
      ElMessage.success('调整成功')
      expDialogVisible.value = false
      loadCoinUsers()
    }
  } catch {} finally {
    expLoading.value = false
  }
}

onMounted(() => {
  loadCoinUsers()
  loadLevelConfig()
  loadCoinConfig()
})
</script>

<style scoped>
.card {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}
.card-header {
  font-size: 16px;
  font-weight: 600;
  color: #333;
  margin-bottom: 20px;
}
.toolbar {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
}
.pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}
</style>
