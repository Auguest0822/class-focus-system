import { teacher } from '@/mock/classData'

const wait = (data, delay = 180) =>
  new Promise((resolve) => {
    window.setTimeout(() => resolve(JSON.parse(JSON.stringify(data))), delay)
  })

export const login = async (payload) => {
  localStorage.setItem('teacher_token', `mock-token-${payload.username || 'teacher'}`)
  return wait({ teacher, token: localStorage.getItem('teacher_token') })
}

export const register = async (payload) => {
  localStorage.setItem('teacher_token', `mock-token-${payload.username || 'teacher'}`)
  return wait({
    teacher: {
      ...teacher,
      name: payload.name || teacher.name,
      avatarText: (payload.name || teacher.name).slice(0, 1),
    },
    token: localStorage.getItem('teacher_token'),
  })
}

export const getCurrentTeacher = () => wait(teacher)
