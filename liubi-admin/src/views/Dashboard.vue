<template>
  <div class="dashboard">
    <div class="stat-cards">
      <div class="stat-card" v-for="item in statCards" :key="item.label">
        <div class="stat-icon" :style="{ background: item.bgColor, color: item.color }">
          <el-icon :size="28"><component :is="item.icon" /></el-icon>
        </div>
        <div class="stat-info">
          <div class="stat-value">{{ animatedValues[item.key] || 0 }}</div>
          <div class="stat-label">{{ item.label }}</div>
        </div>
      </div>
    </div>

    <div class="chart-section">
      <div class="card">
        <div class="card-header">
          <span>注册趋势（最近7天）</span>
          <el-tag type="info" size="small">自动刷新</el-tag>
        </div>
        <div ref="chartRef" class="chart-container"></div>
      </div>
    </div>

    <div class="info-section">
      <div class="card">
        <div class="card-header">系统信息</div>
        <div class="info-grid">
          <div class="info-item">
            <span class="info-label">Node.js版本</span>
            <span class="info-value">{{ sysInfo.node_version || '-' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">数据库状态</span>
            <span class="info-value" :style="{ color: sysInfo.db_status === '正常' || sysInfo.db_status === 'connected' ? '#52c41a' : '#ff4d4f' }">{{ sysInfo.db_status || '-' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">在线人数</span>
            <span class="info-value">{{ sysInfo.online_count || 0 }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">服务器时间</span>
            <span class="info-value">{{ sysInfo.server_time || '-' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">运行时长</span>
            <span class="info-value">{{ sysInfo.uptime || '-' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">总分类数</span>
            <span class="info-value">{{ sysInfo.total_categories || 0 }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { getStats, getOverview } from '../api/admin'

const chartRef = ref(null)
let chartInstance = null
let refreshTimer = null

const stats = reactive({
  totalUsers: 0,
  totalPosts: 0,
  totalComments: 0,
  pendingCount: 0,
  todayNew: 0
})

const sysInfo = reactive({
  node_version: '-',
  db_status: '-',
  online_count: 0,
  server_time: '-',
  uptime: '-',
  total_categories: 0
})

const animatedValues = reactive({
  totalUsers: 0,
  totalPosts: 0,
  totalComments: 0,
  todayNew: 0
})

const statCards = [
  { key: 'totalUsers', label: '总用户', icon: 'User', color: '#1890ff', bgColor: '#e8f4fd' },
  { key: 'totalPosts', label: '总帖子', icon: 'Document', color: '#FF2442', bgColor: '#fff1f3' },
  { key: 'totalComments', label: '总评论', icon: 'ChatLineSquare', color: '#52c41a', bgColor: '#f0f9eb' },
  { key: 'todayNew', label: '今日新增', icon: 'TrendCharts', color: '#faad14', bgColor: '#fff8e6' }
]

const animateNumber = (key, target) => {
  const current = animatedValues[key]
  const diff = target - current
  if (diff === 0) return
  const steps = 30
  const increment = diff / steps
  let step = 0
  const timer = setInterval(() => {
    step++
    if (step >= steps) {
      animatedValues[key] = target
      clearInterval(timer)
    } else {
      animatedValues[key] = Math.round(current + increment * step)
    }
  }, 20)
}

const fetchData = async () => {
  try {
    const res = await getStats()
    if (res.code === 200 && res.data) {
      const d = res.data
      if (d.totalUsers !== undefined) { stats.totalUsers = d.totalUsers; animateNumber('totalUsers', d.totalUsers) }
      if (d.totalPosts !== undefined) { stats.totalPosts = d.totalPosts; animateNumber('totalPosts', d.totalPosts) }
      if (d.totalComments !== undefined) { stats.totalComments = d.totalComments; animateNumber('totalComments', d.totalComments) }
      if (d.pendingCount !== undefined) stats.pendingCount = d.pendingCount
      if (d.todayNew !== undefined) { stats.todayNew = d.todayNew; animateNumber('todayNew', d.todayNew) }
      if (d.registerTrend) updateChart(d.registerTrend)
    }
  } catch {}
  try {
    const res = await getOverview()
    if (res.code === 200 && res.data) {
      const d = res.data
      if (d.total_users !== undefined) { stats.totalUsers = d.total_users; animateNumber('totalUsers', d.total_users) }
      if (d.total_posts !== undefined) { stats.totalPosts = d.total_posts; animateNumber('totalPosts', d.total_posts) }
      if (d.total_comments !== undefined) { stats.totalComments = d.total_comments; animateNumber('totalComments', d.total_comments) }
      if (d.today_new !== undefined) { stats.todayNew = d.today_new; animateNumber('todayNew', d.today_new) }
      if (d.node_version) sysInfo.node_version = d.node_version
      if (d.db_status) sysInfo.db_status = d.db_status
      if (d.online_count !== undefined) sysInfo.online_count = d.online_count
      if (d.server_time) sysInfo.server_time = d.server_time
      if (d.uptime) sysInfo.uptime = d.uptime
      if (d.total_categories !== undefined) sysInfo.total_categories = d.total_categories
    }
  } catch {}
}

const updateChart = (trend) => {
  if (!chartInstance) return
  const days = trend.map(t => t.date || t.day)
  const values = trend.map(t => t.count || t.value || 0)
  chartInstance.setOption({
    xAxis: { data: days },
    series: [{ data: values }]
  })
}

const initChart = () => {
  if (!chartRef.value) return
  chartInstance = echarts.init(chartRef.value)
  const days = []
  const values = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    days.push(`${d.getMonth() + 1}/${d.getDate()}`)
    values.push(0)
  }
  chartInstance.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: days, boundaryGap: false },
    yAxis: { type: 'value', minInterval: 1 },
    series: [{
      name: '注册人数',
      type: 'line',
      smooth: true,
      data: values,
      areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
        { offset: 0, color: 'rgba(255,36,66,0.25)' },
        { offset: 1, color: 'rgba(255,36,66,0.02)' }
      ])},
      lineStyle: { color: '#FF2442', width: 2 },
      itemStyle: { color: '#FF2442' }
    }]
  })
}

const handleResize = () => chartInstance?.resize()

onMounted(async () => {
  await fetchData()
  initChart()
  window.addEventListener('resize', handleResize)
  refreshTimer = setInterval(fetchData, 30000)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  chartInstance?.dispose()
  if (refreshTimer) clearInterval(refreshTimer)
})
</script>

<style scoped>
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.stat-cards {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.stat-card {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
  transition: transform 0.2s, box-shadow 0.2s;
}
.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
}
.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: #333;
}
.stat-label {
  font-size: 14px;
  color: #999;
  margin-top: 4px;
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
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.chart-container {
  height: 320px;
}
.info-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}
.info-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 18px;
  background: #fafafa;
  border-radius: 8px;
}
.info-label {
  font-size: 14px;
  color: #666;
}
.info-value {
  font-size: 14px;
  color: #333;
  font-weight: 500;
}
</style>
