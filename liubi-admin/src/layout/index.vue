<template>
  <div class="layout">
    <div class="sidebar" :class="{ collapsed: isCollapsed }">
      <div class="logo-area">
        <span class="logo-icon">📝</span>
        <span class="logo-text" v-show="!isCollapsed">留笔管理后台</span>
      </div>
      <el-menu
        :default-active="activeMenu"
        router
        class="sidebar-menu"
        :collapse="isCollapsed"
        :collapse-transition="true"
        background-color="#fff"
        text-color="#555"
        active-text-color="#FF2442"
      >
        <el-menu-item index="/admin/dashboard">
          <el-icon><DataAnalysis /></el-icon>
          <template #title>仪表盘</template>
        </el-menu-item>
        <el-menu-item index="/admin/users">
          <el-icon><User /></el-icon>
          <template #title>用户管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/posts">
          <el-icon><Document /></el-icon>
          <template #title>帖子管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/comments">
          <el-icon><ChatLineSquare /></el-icon>
          <template #title>评论管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/categories">
          <el-icon><Menu /></el-icon>
          <template #title>分类管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/conversations">
          <el-icon><ChatDotRound /></el-icon>
          <template #title>会话管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/coins">
          <el-icon><Coin /></el-icon>
          <template #title>留币管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/level-config">
          <el-icon><Trophy /></el-icon>
          <template #title>等级配置</template>
        </el-menu-item>
        <el-menu-item index="/admin/ai-config">
          <el-icon><MagicStick /></el-icon>
          <template #title>AI配置</template>
        </el-menu-item>
        <el-menu-item index="/admin/version">
          <el-icon><Upload /></el-icon>
          <template #title>版本管理</template>
        </el-menu-item>
        <el-menu-item index="/admin/system">
          <el-icon><Setting /></el-icon>
          <template #title>系统设置</template>
        </el-menu-item>
      </el-menu>
      <div class="collapse-btn" @click="isCollapsed = !isCollapsed">
        <el-icon :size="18">
          <DArrowLeft v-if="!isCollapsed" />
          <DArrowRight v-else />
        </el-icon>
      </div>
    </div>
    <div class="main">
      <div class="header">
        <div class="header-left">
          <el-icon :size="20" color="#999"><Fold /></el-icon>
          <span class="header-title">{{ currentTitle }}</span>
        </div>
        <div class="header-right">
          <el-dropdown @command="handleCommand">
            <div class="admin-info">
              <el-avatar :size="32" style="background: #FF2442;">{{ adminName.charAt(0) }}</el-avatar>
              <span class="admin-name">{{ adminName }}</span>
              <el-icon><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout">
                  <el-icon><SwitchButton /></el-icon>退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
      <div class="content">
        <router-view />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'

const route = useRoute()
const router = useRouter()
const isCollapsed = ref(false)

const activeMenu = computed(() => route.path)
const currentTitle = computed(() => route.meta?.title || '仪表盘')
const adminName = computed(() => {
  try {
    const user = JSON.parse(localStorage.getItem('admin_user') || '{}')
    return user.nickname || user.email || '管理员'
  } catch {
    return '管理员'
  }
})

const handleCommand = (command) => {
  if (command === 'logout') {
    ElMessageBox.confirm('确定退出登录？', '提示', { type: 'warning' }).then(() => {
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_user')
      router.push('/admin/login')
    }).catch(() => {})
  }
}
</script>

<style scoped>
.layout {
  display: flex;
  height: 100%;
}
.sidebar {
  width: 220px;
  background: #fff;
  border-right: 1px solid #e8e8e8;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  transition: width 0.3s ease;
  overflow: hidden;
}
.sidebar.collapsed {
  width: 64px;
}
.logo-area {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;
  overflow: hidden;
  white-space: nowrap;
}
.logo-icon {
  font-size: 24px;
  flex-shrink: 0;
}
.logo-text {
  font-size: 16px;
  font-weight: 700;
  color: #FF2442;
  transition: opacity 0.3s ease;
}
.sidebar.collapsed .logo-text {
  opacity: 0;
  width: 0;
}
.sidebar-menu {
  border-right: none;
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
}
.sidebar-menu:not(.el-menu--collapse) {
  width: 220px;
}
.sidebar-menu .el-menu-item {
  height: 50px;
  line-height: 50px;
}
.sidebar-menu .el-menu-item.is-active {
  background-color: #fff1f3 !important;
  font-weight: 600;
}
.sidebar-menu .el-menu-item:hover {
  background-color: #fafafa !important;
}
.collapse-btn {
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-top: 1px solid #f0f0f0;
  cursor: pointer;
  color: #999;
  flex-shrink: 0;
  transition: background 0.2s;
}
.collapse-btn:hover {
  background: #f5f5f5;
  color: #FF2442;
}
.main {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-width: 0;
}
.header {
  height: 60px;
  background: #fff;
  border-bottom: 1px solid #e8e8e8;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  flex-shrink: 0;
}
.header-left {
  display: flex;
  align-items: center;
  gap: 8px;
}
.header-title {
  font-size: 16px;
  font-weight: 600;
  color: #333;
}
.header-right {
  display: flex;
  align-items: center;
}
.admin-info {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 6px;
  transition: background 0.2s;
}
.admin-info:hover {
  background: #f5f5f5;
}
.admin-name {
  font-size: 14px;
  color: #333;
  font-weight: 500;
}
.content {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
  background: #f5f6f7;
}
</style>
