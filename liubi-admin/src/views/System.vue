<template>
  <div class="system-page">
    <div class="card">
      <div class="card-header">邮件SMTP配置</div>
      <el-form ref="formRef" :model="form" :rules="formRules" label-width="120px" v-loading="loading">
        <el-form-item label="SMTP主机" prop="smtp_host">
          <el-input v-model="form.smtp_host" placeholder="例如：smtp.qq.com" />
        </el-form-item>
        <el-form-item label="SMTP端口" prop="smtp_port">
          <el-input-number v-model="form.smtp_port" :min="1" :max="65535" />
        </el-form-item>
        <el-form-item label="安全连接">
          <el-switch v-model="form.smtp_secure" active-value="true" inactive-value="false" active-text="SSL/TLS" inactive-text="无" />
        </el-form-item>
        <el-form-item label="用户名" prop="smtp_user">
          <el-input v-model="form.smtp_user" placeholder="请输入SMTP用户名" />
        </el-form-item>
        <el-form-item label="密码/授权码" prop="smtp_pass">
          <el-input v-model="form.smtp_pass" placeholder="请输入SMTP密码或授权码" show-password />
        </el-form-item>
        <el-form-item label="发件人邮箱" prop="smtp_from">
          <el-input v-model="form.smtp_from" placeholder="请输入发件人邮箱" />
        </el-form-item>
        <el-form-item label="发件人名称">
          <el-input v-model="form.smtp_from_name" placeholder="例如：留笔" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" size="large" @click="saveConfig" :loading="saving">
            <el-icon><Check /></el-icon> 保存配置
          </el-button>
        </el-form-item>
      </el-form>
    </div>

    <div class="card" style="margin-top:16px">
      <div class="card-header">测试发送</div>
      <el-form label-width="120px">
        <el-form-item label="收件邮箱">
          <el-input v-model="testEmail" placeholder="请输入收件人邮箱地址" style="max-width:400px" />
        </el-form-item>
        <el-form-item>
          <el-button type="success" size="large" @click="testSend" :loading="testing" :disabled="!testEmail">
            <el-icon><Message /></el-icon> 发送测试邮件
          </el-button>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Check, Message } from '@element-plus/icons-vue'
import { getEmailConfig, updateEmailConfig } from '../api/admin'
import request from '../utils/request'

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)
const formRef = ref(null)
const testEmail = ref('')

const form = reactive({
  smtp_host: '',
  smtp_port: 465,
  smtp_secure: 'true',
  smtp_user: '',
  smtp_pass: '',
  smtp_from: '',
  smtp_from_name: '留笔'
})

const formRules = {
  smtp_host: [{ required: true, message: '请输入SMTP主机', trigger: 'blur' }],
  smtp_port: [{ required: true, message: '请输入SMTP端口', trigger: 'blur' }],
  smtp_user: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  smtp_pass: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  smtp_from: [{ required: true, message: '请输入发件人邮箱', trigger: 'blur' }]
}

const loadConfig = async () => {
  loading.value = true
  try {
    const res = await getEmailConfig()
    if (res.code === 200 && res.data) {
      const d = res.data
      form.smtp_host = d.smtp_host || ''
      form.smtp_port = parseInt(d.smtp_port) || 465
      form.smtp_secure = d.smtp_secure || 'true'
      form.smtp_user = d.smtp_user || ''
      form.smtp_pass = d.smtp_pass || ''
      form.smtp_from = d.smtp_from || ''
      form.smtp_from_name = d.smtp_from_name || '留笔'
    }
  } catch {} finally {
    loading.value = false
  }
}

const saveConfig = async () => {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  saving.value = true
  try {
    const res = await updateEmailConfig({ ...form })
    if (res.code === 200) {
      ElMessage.success('保存成功')
      await loadConfig()
    } else {
      ElMessage.error(res.msg || '保存失败')
    }
  } catch {} finally {
    saving.value = false
  }
}

const testSend = async () => {
  if (!testEmail.value) {
    ElMessage.warning('请输入收件邮箱')
    return
  }
  testing.value = true
  try {
    const res = await request.post('/api/admin/email-test', { to: testEmail.value })
    if (res.code === 200) {
      ElMessage.success('测试邮件已发送，请检查收件箱')
    } else {
      ElMessage.error(res.msg || '测试发送失败')
    }
  } catch {} finally {
    testing.value = false
  }
}

onMounted(loadConfig)
</script>

<style scoped>
.system-page {
  padding: 20px;
}
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
  padding-bottom: 12px;
  border-bottom: 1px solid #f0f0f0;
}
</style>
