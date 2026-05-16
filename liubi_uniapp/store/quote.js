import { defineStore } from 'pinia'
import { ref } from 'vue'
import { BASE_URL } from '@/utils/request.js'

export const usePostStore = defineStore('post', () => {
	const posts = ref([])
	const total = ref(0)
	const page = ref(1)
	const currentCategory = ref(0)
	const feedType = ref('discover')
	const categories = ref([])
	const loading = ref(false)
	const fetchError = ref('')

	const categoryPosts = ref({})
	const categoryPage = ref({})
	const categoryTotal = ref({})
	const categoryLoading = ref({})
	const categoryNoMore = ref({})

	function rawRequest(url, method, data) {
		const token = uni.getStorageSync('token') || ''
		return new Promise((resolve, reject) => {
			const isPost = method === 'POST' || method === 'PUT'
			const sendData = isPost && data ? JSON.stringify(data) : (data || null)
			uni.request({
				url: BASE_URL + url,
				method: method || 'GET',
				data: sendData,
				header: {
					'Content-Type': 'application/json',
					'Authorization': token ? 'Bearer ' + token : ''
				},
				success: (res) => {
					if (res.statusCode === 200) {
						resolve(res.data)
					} else if (res.statusCode === 401) {
						uni.removeStorageSync('token')
						uni.removeStorageSync('userInfo')
						resolve({ code: 401, msg: '请先登录' })
					} else {
						const msg = (res.data && res.data.msg) ? res.data.msg : 'HTTP ' + res.statusCode
						resolve({ code: res.statusCode, msg })
					}
				},
				fail: (err) => {
					reject(new Error(err.errMsg || '网络请求失败'))
				}
			})
		})
	}

	async function fetchCategories() {
		try {
			const res = await rawRequest('/categories')
			if (res.code === 200) categories.value = res.data
		} catch (e) {
			fetchError.value = 'fetchCategories: ' + e.message
		}
	}

	async function fetchPosts(reset = false) {
		if (loading.value && !reset) return
		if (reset) {
			page.value = 1
			posts.value = []
		}
		loading.value = true
		fetchError.value = ''

		let query = 'page=' + page.value + '&pageSize=20'
		if (currentCategory.value) query += '&category_id=' + currentCategory.value
		if (feedType.value === 'follow') query += '&following=1'

		try {
			const res = await rawRequest('/posts?' + query)
			if (res.code === 200 && res.data) {
				const list = res.data.list || []
				if (reset || page.value === 1) {
					posts.value = list
				} else {
					posts.value = posts.value.concat(list)
				}
				total.value = res.data.total || 0
			} else {
				fetchError.value = 'API code:' + (res ? res.code : 'null')
			}
		} catch (e) {
			fetchError.value = 'fetchPosts: ' + e.message
		}
		loading.value = false
	}

	async function fetchCategoryPosts(catId, reset = false, sort) {
		const key = String(catId)
		if (categoryLoading.value[key] && !reset) return
		if (reset || !categoryPosts.value[key]) {
			categoryPage.value[key] = 1
			categoryPosts.value[key] = []
			categoryNoMore.value[key] = false
		}
		categoryLoading.value[key] = true

		const sortParam = sort || 'latest'
		let query = 'page=' + categoryPage.value[key] + '&pageSize=20&sort=' + sortParam
		if (catId) query += '&category_id=' + catId

		try {
			const res = await rawRequest('/posts?' + query)
			if (res.code === 200 && res.data) {
				const list = res.data.list || []
				if (reset || categoryPage.value[key] === 1) {
					categoryPosts.value[key] = list
				} else {
					categoryPosts.value[key] = categoryPosts.value[key].concat(list)
				}
				categoryTotal.value[key] = res.data.total || 0
				if (list.length < 20) categoryNoMore.value[key] = true
			}
		} catch (e) {
			fetchError.value = e.message
		}
		categoryLoading.value[key] = false
	}

	async function loadMoreCategoryPosts(catId) {
		const key = String(catId)
		if (categoryLoading.value[key] || categoryNoMore.value[key]) return
		categoryPage.value[key] = (categoryPage.value[key] || 1) + 1
		await fetchCategoryPosts(catId)
	}

	async function fetchPostById(id) {
		try {
			const res = await rawRequest('/posts/' + id)
			return res.code === 200 ? res.data : null
		} catch (e) {
			return null
		}
	}

	async function createPost(data) {
		try {
			return await rawRequest('/posts', 'POST', data)
		} catch (e) {
			return { code: 500, msg: e.message || '发布失败' }
		}
	}

	async function updatePost(id, data) {
		try {
			return await rawRequest('/posts/' + id, 'PUT', data)
		} catch (e) {
			return { code: 500, msg: e.message || '保存失败' }
		}
	}

	async function toggleLike(postId) {
		try {
			const res = await rawRequest('/posts/' + postId + '/like', 'POST')
			if (res.code === 200) {
				const liked = res.data.liked
				const delta = liked ? 1 : -1
				const updatePost = (post) => {
					post.isLiked = liked
					post.likes_count = (post.likes_count || 0) + delta
				}
				const idx = posts.value.findIndex(p => p.id === postId)
				if (idx !== -1) updatePost(posts.value[idx])
				for (const key in categoryPosts.value) {
					const ci = categoryPosts.value[key].findIndex(p => p.id === postId)
					if (ci !== -1) updatePost(categoryPosts.value[key][ci])
				}
			}
			return res
		} catch (e) {
			return { code: 500, msg: e.message }
		}
	}

	async function toggleCollect(postId) {
		try {
			const res = await rawRequest('/posts/' + postId + '/collect', 'POST')
			if (res.code === 200) {
				const collected = res.data.collected
				const delta = collected ? 1 : -1
				const updatePost = (post) => {
					post.isCollected = collected
					post.collects_count = (post.collects_count || 0) + delta
				}
				const idx = posts.value.findIndex(p => p.id === postId)
				if (idx !== -1) updatePost(posts.value[idx])
				for (const key in categoryPosts.value) {
					const ci = categoryPosts.value[key].findIndex(p => p.id === postId)
					if (ci !== -1) updatePost(categoryPosts.value[key][ci])
				}
			}
			return res
		} catch (e) {
			return { code: 500, msg: e.message }
		}
	}

	async function fetchComments(postId) {
		try {
			const res = await rawRequest('/comments/post/' + postId)
			return res.code === 200 ? res.data : []
		} catch (e) {
			return []
		}
	}

	async function addComment(postId, content, parentId, imageUrl) {
		return await rawRequest('/comments', 'POST', { post_id: postId, content, parent_id: parentId || null, image_url: imageUrl || '' })
	}

	function setCategory(id) {
		currentCategory.value = id
		fetchPosts(true)
	}

	function setFeedType(type) {
		feedType.value = type
		fetchPosts(true)
	}

	return {
		posts, total, page, currentCategory, feedType, categories, loading, fetchError,
		categoryPosts, categoryPage, categoryTotal, categoryLoading, categoryNoMore,
		fetchCategories, fetchPosts, fetchCategoryPosts, loadMoreCategoryPosts,
		fetchPostById, createPost, updatePost,
		toggleLike, toggleCollect, fetchComments, addComment, setCategory, setFeedType
	}
})
