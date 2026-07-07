import request from './request'

const normalizeTeacher = (data = {}) => {
  const name = data.name || data.username || 'Teacher'

  return {
    ...data,
    name,
    avatarText: data.avatarText || name.slice(0, 1),
  }
}

export const login = async (payload) => {
  const data = await request.post('/auth/login', payload)
  const token = data?.access_token || data?.token || data?.accessToken

  if (token) {
    localStorage.setItem('teacher_token', token)
  }

  return data
}

export const register = async (payload) => {
  const data = await request.post('/auth/register', {
    username: payload.username,
    password: payload.password,
    role: 'teacher',
    name: payload.name,
    teacher_no: payload.username,
  })
  const token = data?.access_token || data?.token || data?.accessToken

  if (token) {
    localStorage.setItem('teacher_token', token)
  }

  return data
}

export const getCurrentTeacher = async () => {
  const data = await request.get('/auth/me')
  return normalizeTeacher(data)
}
