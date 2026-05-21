<template>
  <div class="ai-config-page">
    <!-- AI对话配置 -->
    <div class="card" style="margin-bottom: 20px;">
      <div class="card-header">
        <span>AI对话配置</span>
        <el-tag :type="chatConfig.enabled ? 'success' : 'info'" size="small">{{ chatConfig.enabled ? '已启用' : '未启用' }}</el-tag>
      </div>
      <el-form :model="chatConfig" label-width="120px" v-loading="chatLoading">
        <el-form-item label="启用">
          <el-switch v-model="chatConfig.enabled" :active-value="1" :inactive-value="0" active-text="启用" inactive-text="禁用" />
        </el-form-item>
        <el-form-item label="API地址">
          <el-input v-model="chatConfig.api_url" placeholder="请输入API地址" />
        </el-form-item>
        <el-form-item label="API Key">
          <el-input v-model="chatConfig.api_key" placeholder="请输入API Key" show-password />
        </el-form-item>
        <el-form-item label="模型名">
          <el-input v-model="chatConfig.model_name" placeholder="请输入模型名称" />
        </el-form-item>
        <el-form-item label="系统提示词">
          <el-input v-model="chatConfig.system_prompt" type="textarea" :rows="5" placeholder="请输入系统提示词" />
        </el-form-item>
      </el-form>
    </div>

    <!-- AI绘画配置 -->
    <div class="card" style="margin-bottom: 20px;">
      <div class="card-header">
        <span>AI绘画配置</span>
        <el-tag :type="imageConfig.enabled ? 'success' : 'info'" size="small">{{ imageConfig.enabled ? '已启用' : '未启用' }}</el-tag>
      </div>
      <el-form :model="imageConfig" label-width="120px" v-loading="imageLoading">
        <el-form-item label="启用">
          <el-switch v-model="imageConfig.enabled" :active-value="1" :inactive-value="0" active-text="启用" inactive-text="禁用" />
        </el-form-item>
        <el-form-item label="API地址">
          <el-input v-model="imageConfig.api_url" placeholder="请输入API地址" />
        </el-form-item>
        <el-form-item label="API Key">
          <el-input v-model="imageConfig.api_key" placeholder="请输入API Key" show-password />
        </el-form-item>
        <el-form-item label="模型名">
          <el-input v-model="imageConfig.model_name" placeholder="请输入模型名称" />
        </el-form-item>
      </el-form>
    </div>

    <div class="actions">
      <el-button type="primary" size="large" @click="saveAll" :loading="saving">保存全部配置</el-button>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getAIConfig, updateAIConfig, getAIImageConfig, updateAIImageConfig } from '../api/admin'

const chatLoading = ref(false)
const imageLoading = ref(false)
const saving = ref(false)

const chatConfig = reactive({
  enabled: 0,
  api_url: '',
  api_key: '',
  model_name: '',
  system_prompt: ''
})

const imageConfig = reactive({
  enabled: 0,
  api_url: '',
  api_key: '',
  model_name: ''
})

const loadChatConfig = async () => {
  chatLoading.value = true
  try {
    const res = await getAIConfig()
    if (res.code === 200 && res.data) {
      Object.assign(chatConfig, res.data)
    }
  } catch {} finally {
    chatLoading.value = false
  }
}

const loadImageConfig = async () => {
  imageLoading.value = true
  try {
    const res = await getAIImageConfig()
    if (res.code === 200 && res.data) {
      Object.assign(imageConfig, res.data)
    }
  } catch {} finally {
    imageLoading.value = false
  }
}

const saveAll = async () => {
  saving.value = true
  try {
    const [chatRes, imageRes] = await Promise.all([
      updateAIConfig(chatConfig),
      updateAIImageConfig(imageConfig)
    ])
    if (chatRes.code === 200 && imageRes.code === 200) {
      ElMessage.success('保存成功')
    }
  } catch {} finally {
    saving.value = false
  }
}

onMounted(() => {
  loadChatConfig()
  loadImageConfig()
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
  justify-content: space-between;
}
.actions {
  display: flex;
  justify-content: center;
}
</style>
