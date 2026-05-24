import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/admin/login', component: () => import('../views/Login.vue') },
  {
    path: '/admin',
    component: () => import('../layout/index.vue'),
    redirect: '/admin/dashboard',
    children: [
      { path: 'dashboard', component: () => import('../views/Dashboard.vue'), meta: { title: '仪表盘', icon: 'DataAnalysis' } },
      { path: 'users', component: () => import('../views/Users.vue'), meta: { title: '用户管理', icon: 'User' } },
      { path: 'posts', component: () => import('../views/Posts.vue'), meta: { title: '帖子管理', icon: 'Document' } },
      { path: 'comments', component: () => import('../views/Comments.vue'), meta: { title: '评论管理', icon: 'ChatLineSquare' } },
      { path: 'categories', component: () => import('../views/Categories.vue'), meta: { title: '分类管理', icon: 'Menu' } },
      { path: 'conversations', component: () => import('../views/Conversations.vue'), meta: { title: '会话管理', icon: 'ChatDotRound' } },
      { path: 'coins', component: () => import('../views/Coins.vue'), meta: { title: '留币管理', icon: 'Coin' } },
      { path: 'level-config', component: () => import('../views/LevelConfig.vue'), meta: { title: '等级配置', icon: 'Trophy' } },
      { path: 'ai-config', component: () => import('../views/AIConfig.vue'), meta: { title: 'AI配置', icon: 'MagicStick' } },
      { path: 'version', component: () => import('../views/Version.vue'), meta: { title: '版本管理', icon: 'Upload' } },
      { path: 'system', component: () => import('../views/System.vue'), meta: { title: '系统设置', icon: 'Setting' } },
    ]
  }
]

const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('admin_token')
  if (to.path !== '/admin/login' && !token) next('/admin/login')
  else next()
})

export default router
