import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { request } from '@/utils/request.js'

export const useUserStore = defineStore('user', () => {
	const token = ref(uni.getStorageSync('token') || '')
	const userInfo = ref(uni.getStorageSync('userInfo') ? JSON.parse(uni.getStorageSync('userInfo')) : null)
	const isLoggedIn = computed(() => !!token.value)

	async function sendCode(email, type) {
		const res = await request({ url: '/auth/send-code', method: 'POST', data: { email, type } })
		return res
	}

	async function register(email, code, password, nickname) {
		const res = await request({ url: '/auth/register', method: 'POST', data: { email, code, password, nickname } })
		if (res.code === 200) {
			token.value = res.data.token
			userInfo.value = res.data.user
			uni.setStorageSync('token', res.data.token)
			uni.setStorageSync('userInfo', JSON.stringify(res.data.user))
		}
		return res
	}

	async function loginByCode(email, code) {
		const res = await request({ url: '/auth/login-code', method: 'POST', data: { email, code } })
		if (res.code === 200) {
			token.value = res.data.token
			userInfo.value = res.data.user
			uni.setStorageSync('token', res.data.token)
			uni.setStorageSync('userInfo', JSON.stringify(res.data.user))
		}
		return res
	}

	async function login(email, password) {
		const res = await request({ url: '/auth/login', method: 'POST', data: { email, password } })
		if (res.code === 200) {
			token.value = res.data.token
			userInfo.value = res.data.user
			uni.setStorageSync('token', res.data.token)
			uni.setStorageSync('userInfo', JSON.stringify(res.data.user))
		}
		return res
	}

	async function fetchProfile() {
		const res = await request({ url: '/auth/profile' })
		if (res.code === 200) {
			userInfo.value = res.data
			uni.setStorageSync('userInfo', JSON.stringify(res.data))
		}
		return res
	}

	async function updateProfile(data) {
		const res = await request({ url: '/auth/profile', method: 'PUT', data })
		if (res.code === 200) await fetchProfile()
		return res
	}

	async function changePassword(email, code, newPassword) {
		const res = await request({ url: '/auth/change-password', method: 'POST', data: { email, code, new_password: newPassword } })
		return res
	}

	async function changeUsername(newUsername) {
		const res = await request({ url: '/auth/change-username', method: 'POST', data: { new_username: newUsername } })
		if (res.code === 200) await fetchProfile()
		return res
	}

	async function bindEmail(email, code) {
		const res = await request({ url: '/auth/bind-email', method: 'POST', data: { email, code } })
		if (res.code === 200) await fetchProfile()
		return res
	}

	async function followUser(userId) {
		const res = await request({ url: '/users/' + userId + '/follow', method: 'POST' })
		return res
	}

	async function fetchMessages(type) {
		const url = type ? '/messages?type=' + type : '/messages'
		const res = await request({ url })
		return res.code === 200 ? res.data : []
	}

	async function fetchUnreadCount() {
		const res = await request({ url: '/messages/unread' })
		return res.code === 200 ? res.data.count : 0
	}

	async function markMessagesRead() {
		await request({ url: '/messages/read', method: 'PUT' })
	}

	function logout() {
		token.value = ''
		userInfo.value = null
		uni.removeStorageSync('token')
		uni.removeStorageSync('userInfo')
	}

	return {
		token, userInfo, isLoggedIn,
		sendCode, register, login, loginByCode,
		fetchProfile, updateProfile,
		changePassword, changeUsername, bindEmail,
		followUser, fetchMessages, fetchUnreadCount, markMessagesRead, logout
	}
})
