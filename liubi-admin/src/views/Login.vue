<template>
  <div class="login-page">
    <div class="login-card">
      <div class="login-logo">
        <span class="logo-emoji">📝</span>
        <span>留笔管理后台</span>
      </div>
      <el-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleLogin">
        <el-form-item prop="email">
          <el-input v-model="form.email" placeholder="请输入邮箱" prefix-icon="Message" size="large" />
        </el-form-item>
        <el-form-item prop="password">
          <el-input v-model="form.password" type="password" placeholder="请输入密码" prefix-icon="Lock" size="large" show-password />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" size="large" :loading="loading" class="login-btn" @click="handleLogin">登 录</el-button>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { login } from '../api/admin'

const router = useRouter()
const formRef = ref(null)
const loading = ref(false)

const form = reactive({
  email: '',
  password: ''
})

const rules = {
  email: [{ required: true, message: '请输入邮箱', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

const handleLogin = async () => {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  loading.value = true
  try {
    const res = await login(form)
    if (res.code === 200) {
      const { token, user } = res.data
      if (user.role !== 1 && user.role !== 2) {
        ElMessage.error('非管理员账号，无法登录')
        return
      }
      localStorage.setItem('admin_token', token)
      localStorage.setItem('admin_user', JSON.stringify(user))
      ElMessage.success('登录成功')
      router.push('/admin/dashboard')
    } else {
      ElMessage.error(res.msg || '登录失败')
    }
  } catch {
    // error handled by interceptor
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #f5f6f7 0%, #e8ecf1 100%);
}
.login-card {
  width: 420px;
  padding: 48px 40px 32px;
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 8px 40px rgba(0, 0, 0, 0.08);
}
.login-logo {
  text-align: center;
  font-size: 24px;
  font-weight: 700;
  color: #FF2442;
  margin-bottom: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.logo-emoji {
  font-size: 32px;
}
.login-btn {
  width: 100%;
  background: linear-gradient(135deg, #FF2442, #ff6b81);
  border: none;
  font-size: 16px;
  height: 44px;
  border-radius: 8px;
}
.login-btn:hover {
  background: linear-gradient(135deg, #e6203c, #ff5269);
}
</style>
