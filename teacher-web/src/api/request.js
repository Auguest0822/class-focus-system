import axios from 'axios'

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 8000,
})

request.interceptors.request.use((config) => {
  const token = localStorage.getItem('teacher_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

request.interceptors.response.use(
  (response) => {
    const body = response.data

    if (body && typeof body === 'object' && 'code' in body && 'data' in body) {
      if (body.code === 0 || body.code === '0') {
        return body.data
      }

      return Promise.reject(new Error(body.message || 'Request failed'))
    }

    return body
  },
  (error) => {
    // 401 → token 过期或无效，清空登录态并跳转登录页
    if (error.response?.status === 401) {
      localStorage.removeItem('teacher_token')
      window.location.href = '/login?expired=1'
      return Promise.reject(new Error('登录已过期，请重新登录'))
    }

    // 网络不通 / 超时（无响应）
    if (!error.response) {
      return Promise.reject(new Error('网络连接失败，请检查网络设置'))
    }

    const message =
      error.response?.data?.detail || error.response?.data?.message || error.message || '请求失败'
    return Promise.reject(new Error(message))
  },
)

export default request
