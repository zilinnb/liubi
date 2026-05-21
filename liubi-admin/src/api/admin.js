import request from '../utils/request'

// 登录
export const login = (data) => request.post('/api/auth/login', data)

// 仪表盘
export const getStats = () => request.get('/api/admin/stats')
export const getOverview = () => request.get('/api/stats/overview')

// 用户管理
export const getUsers = (params) => request.get('/api/admin/users', { params })
export const updateUser = (id, data) => request.put(`/api/admin/users/${id}`, data)
export const updateUserStatus = (id, data) => request.put(`/api/admin/users/${id}/status`, data)
export const muteUser = (id, data) => request.put(`/api/admin/users/${id}/mute`, data)

// 帖子管理
export const getPosts = (params) => request.get('/api/admin/posts', { params })
export const updatePostStatus = (id, data) => request.put(`/api/admin/posts/${id}/status`, data)
export const deletePost = (id) => request.delete(`/api/admin/posts/${id}`)

// 评论管理
export const getComments = (params) => request.get('/api/admin/comments', { params })
export const deleteComment = (id) => request.delete(`/api/admin/comments/${id}`)

// 分类管理
export const getCategories = () => request.get('/api/admin/categories')
export const createCategory = (data) => request.post('/api/admin/categories', data)
export const updateCategory = (id, data) => request.put(`/api/admin/categories/${id}`, data)
export const deleteCategory = (id) => request.delete(`/api/admin/categories/${id}`)

// 会话管理
export const getConversations = (params) => request.get('/api/admin/conversations', { params })
export const updateGroupCode = (id, data) => request.put(`/api/admin/conversations/${id}/group-code`, data)
export const deleteConversation = (id) => request.delete(`/api/admin/conversations/${id}`)

// 留币管理
export const getCoinUsers = (params) => request.get('/api/coins/admin/users', { params })
export const adjustCoins = (data) => request.post('/api/coins/admin/adjust', data)
export const adjustExp = (data) => request.post('/api/coins/admin/adjust-exp', data)
export const getLevelConfig = () => request.get('/api/coins/level-config')
export const getCoinConfig = () => request.get('/api/coins/config')
export const updateCoinConfig = (data) => request.put('/api/coins/config', data)

// AI配置
export const getAIConfig = () => request.get('/api/admin/ai-config')
export const updateAIConfig = (data) => request.put('/api/admin/ai-config', data)
export const getAIImageConfig = () => request.get('/api/admin/ai-image-config')
export const updateAIImageConfig = (data) => request.put('/api/admin/ai-image-config', data)

// 邮件配置
export const getEmailConfig = () => request.get('/api/admin/email-config')
export const updateEmailConfig = (data) => request.put('/api/admin/email-config', data)

// 版本管理
export const getVersions = () => request.get('/api/version/list')
export const createVersion = (data) => request.post('/api/version', data)
export const updateVersion = (id, data) => request.put(`/api/version/${id}`, data)
export const deleteVersion = (id) => request.delete(`/api/version/${id}`)
