<template>
  <div class="level-config-page">
    <!-- 等级配置 -->
    <div class="card" style="margin-bottom: 20px;">
      <div class="card-header">
        等级配置
        <span style="font-size:12px;color:#999;font-weight:normal;margin-left:8px">修改"升级所需经验"后自动重算所有累计值</span>
      </div>
      <el-table :data="levelList" stripe style="width: 100%;">
        <el-table-column label="等级" width="100">
          <template #default="{ row }">
            <el-tag type="warning" size="large" effect="dark">Lv.{{ row.level }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="称号" min-width="140">
          <template #default="{ row }">
            <el-input v-model="row.title" size="default" placeholder="输入称号" @change="handleUpdateLevel(row)" />
          </template>
        </el-table-column>
        <el-table-column label="升级所需经验" width="220">
          <template #default="{ row }">
            <template v-if="row.level < maxLevel">
              <el-input-number
                v-model="row.exp_to_next"
                size="default"
                :min="0"
                :step="50"
                controls-position="right"
                @change="handleUpdateLevel(row)"
              />
              <div style="font-size:12px;color:#999;margin-top:4px">
                Lv.{{ row.level }} → Lv.{{ row.level + 1 }} 需要 {{ row.exp_to_next }} 经验
              </div>
            </template>
            <el-tag v-else type="info" size="small">已满级</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="累计经验阈值" width="140">
          <template #default="{ row }">
            <span style="color:#999;font-size:14px">{{ row.exp }}</span>
          </template>
        </el-table-column>
        <el-table-column label="升级进度示意" min-width="200">
          <template #default="{ row }">
            <template v-if="row.level < maxLevel && row.exp_to_next > 0">
              <div class="level-progress-bar">
                <div class="level-progress-fill" :style="{ width: '0%' }"></div>
                <span class="level-progress-text">0 / {{ row.exp_to_next }}</span>
              </div>
            </template>
            <span v-else style="color:#ccc">-</span>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 经验任务配置 -->
    <div class="card" style="margin-bottom: 20px;">
      <div class="card-header">
        经验任务配置
        <span style="font-size:12px;color:#999;font-weight:normal;margin-left:8px">配置各操作获得的经验值和每日上限</span>
      </div>
      <el-table :data="taskList" stripe style="width: 100%;">
        <el-table-column prop="type" label="类型ID" width="80" />
        <el-table-column label="任务名称" min-width="140">
          <template #default="{ row }">
            <el-input v-model="row.name" size="default" @change="handleUpdateTask(row)" />
          </template>
        </el-table-column>
        <el-table-column label="奖励经验" width="180">
          <template #default="{ row }">
            <el-input-number v-model="row.exp" size="default" :min="0" controls-position="right" @change="handleUpdateTask(row)" />
          </template>
        </el-table-column>
        <el-table-column label="每日上限" width="200">
          <template #default="{ row }">
            <el-input-number v-model="row.daily_limit" size="default" :min="0" controls-position="right" @change="handleUpdateTask(row)" />
            <span style="margin-left:6px;color:#999;font-size:12px">0=无限</span>
          </template>
        </el-table-column>
        <el-table-column label="启用" width="80">
          <template #default="{ row }">
            <el-switch v-model="row.is_active" :active-value="1" :inactive-value="0" @change="handleUpdateTask(row)" />
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 等级总览 -->
    <div class="card">
      <div class="card-header">等级总览</div>
      <div class="level-overview">
        <div v-for="row in levelList" :key="row.level" class="level-item">
          <div class="level-badge">Lv.{{ row.level }}</div>
          <div class="level-info">
            <div class="level-title">{{ row.title }}</div>
            <div class="level-exp">累计 {{ row.exp }} 经验{{ row.exp_to_next > 0 ? ' · 升级需 ' + row.exp_to_next : '' }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getAdminLevelConfig, updateLevelConfig, getExpTaskConfig, updateExpTaskConfig } from '../api/admin'

const levelList = ref([])
const taskList = ref([])
const maxLevel = ref(12)

const loadLevelConfig = async () => {
  try {
    const res = await getAdminLevelConfig()
    if (res.code === 200) {
      const list = res.data?.list || res.data || []
      levelList.value = list
      if (list.length > 0) maxLevel.value = list[list.length - 1].level
    }
  } catch {}
}

const loadTaskConfig = async () => {
  try {
    const res = await getExpTaskConfig()
    if (res.code === 200) {
      taskList.value = res.data?.list || res.data || []
    }
  } catch {}
}

const handleUpdateLevel = async (row) => {
  try {
    await updateLevelConfig(row.level, { title: row.title, exp_to_next: row.exp_to_next })
    ElMessage.success(`Lv.${row.level} 配置已更新`)
    loadLevelConfig()
  } catch {}
}

const handleUpdateTask = async (row) => {
  try {
    await updateExpTaskConfig(row.type, {
      name: row.name,
      exp: row.exp,
      daily_limit: row.daily_limit,
      is_active: row.is_active
    })
    ElMessage.success('任务配置已更新')
  } catch {}
}

onMounted(() => {
  loadLevelConfig()
  loadTaskConfig()
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
  display: flex;
  align-items: center;
}
.level-progress-bar {
  position: relative;
  height: 24px;
  background: #f5f5f5;
  border-radius: 12px;
  overflow: hidden;
}
.level-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #ff9800, #ff5722);
  border-radius: 12px;
  transition: width 0.3s;
}
.level-progress-text {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 11px;
  color: #666;
  white-space: nowrap;
}
.level-overview {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 12px;
}
.level-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: #fafafa;
  border-radius: 10px;
  border: 1px solid #f0f0f0;
  transition: all 0.2s;
}
.level-item:hover {
  border-color: #ff9800;
  background: #fff8f0;
}
.level-badge {
  background: linear-gradient(135deg, #ff9800, #ff5722);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  padding: 4px 10px;
  border-radius: 6px;
  white-space: nowrap;
}
.level-info {
  flex: 1;
  min-width: 0;
}
.level-title {
  font-size: 14px;
  font-weight: 600;
  color: #333;
}
.level-exp {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}
</style>
