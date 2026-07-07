import request from './request'

export const login = async (payload) => {
  const data = await request.post('/auth/login', payload)
  const token = data?.token || data?.accessToken

  if (token) {
    localStorage.setItem('teacher_token', token)
  }

  return data
}

export const getCurrentTeacher = () => request.get('/teacher/me')

