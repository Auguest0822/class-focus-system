import request from './request'
import {
  appUsage,
  classes,
  dashboardStats,
  reportSummary,
  students,
  suggestions,
  teacher,
} from '@/mock/classData'

const wait = (data, delay = 180) =>
  new Promise((resolve) => {
    window.setTimeout(() => resolve(JSON.parse(JSON.stringify(data))), delay)
  })

export const login = async (payload) => {
  localStorage.setItem('teacher_token', `mock-token-${payload.username || 'teacher'}`)
  return wait({ teacher, token: localStorage.getItem('teacher_token') })
}

export const getDashboard = () =>
  wait({
    stats: dashboardStats,
    classes,
  })

export const getClasses = () => wait(classes)

export const createClass = (form) => {
  const codePrefix = (form.courseName || 'PY').slice(0, 2).toUpperCase()
  const code = `${codePrefix}${Math.floor(1000 + Math.random() * 9000)}`
  const createdClass = {
    id: code,
    code,
    status: 'running',
    statusText: '进行中',
    joinedCount: 36,
    ...form,
    duration: `${form.focusOne || 50} + ${form.breakTime || 5} + ${form.focusTwo || 40}`,
  }

  return wait(createdClass)
}

export const getClassDetail = (id = 'PY2025') => {
  const currentClass = classes.find((item) => item.id === id || item.code === id) || classes[0]
  return wait({
    classInfo: currentClass,
    students,
  })
}

export const getClassReport = (id = 'PY2025') => {
  const currentClass = classes.find((item) => item.id === id || item.code === id) || classes[0]
  return wait({
    classInfo: currentClass,
    summary: reportSummary,
    studentStats: students.filter((item) => item.focusRate !== '--'),
    appUsage,
    suggestions,
  })
}

export const fetchRemoteClasses = () => request.get('/classes')
