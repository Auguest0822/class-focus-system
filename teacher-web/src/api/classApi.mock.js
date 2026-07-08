import { appUsage, classes, dashboardStats, reportSummary, students } from '@/mock/classData'

const wait = (data, delay = 180) =>
  new Promise((resolve) => {
    window.setTimeout(() => resolve(JSON.parse(JSON.stringify(data))), delay)
  })

const getCourseGroups = () => {
  const courseMap = classes.reduce((map, item) => {
    const courseKey = item.courseNo || item.courseName
    if (!map.has(courseKey)) {
      map.set(courseKey, {
        courseNo: item.courseNo,
        courseName: item.courseName,
        lessons: [],
      })
    }
    map.get(courseKey).lessons.push(item)
    return map
  }, new Map())

  return Array.from(courseMap.values()).map((course) => ({
    ...course,
    lessons: course.lessons.sort((a, b) => (a.startTime || '').localeCompare(b.startTime || '')),
  }))
}

export const getDashboard = () =>
  wait({
    stats: dashboardStats,
    classes,
  })

export const getClasses = () => {
  // 与后端保持一致:先按课程分组(groups),再拍平成单个课次的列表。
  // 这样 DashboardView / ClassDetailView / ClassReportView 都只需要消费 "单个课次" 列表。
  const groups = classes.reduce((acc, item) => {
    const key = `${item.courseNo || ''}-${item.courseName || ''}`
    if (!acc.map.has(key)) {
      acc.map.set(key, { courseNo: item.courseNo, courseName: item.courseName, classrooms: [] })
      acc.list.push(acc.map.get(key))
    }
    acc.map.get(key).classrooms.push(item)
    return acc
  }, { map: new Map(), list: [] }).list

  const flat = groups.flatMap((g) => (g.classrooms || []).map((c) => ({
    ...c,
    course_no: g.courseNo,
    course_name: g.courseName,
  })))
  return wait(flat)
}

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

export const getMembers = async (classroomId) => {
  // mock: 统一返回 students;如果你的数据里想区分不同课次的成员，
  // 可以在这里按 classroomId 过滤再返回。
  return wait([...students])
}

export const getClassDetail = (id = 'PY2025') => {
  const currentClass = classes.find((item) => item.id === id || item.code === id) || classes[0]
  return wait({
    classInfo: currentClass,
    courses: getCourseGroups(),
    students,
  })
}

export const getClassReport = (id) => {
  const currentClass =
    classes.find((item) => item.id === id || item.code === id) ||
    classes.find((item) => item.status === 'ended') ||
    classes[0]
  return wait({
    classInfo: currentClass,
    courses: getCourseGroups(),
    summary: reportSummary,
    studentStats: students.filter((item) => item.focusRate !== '--'),
    appUsage,
  })
}

export const startClassroom = (id) => {
  const item = classes.find((c) => c.id === id || c.code === id)
  if (item) {
    item.status = 'running'
    item.statusText = '进行中'
  }
  return wait(item || classes[0])
}

export const endClassroom = (id) => {
  const item = classes.find((c) => c.id === id || c.code === id)
  if (item) {
    item.status = 'ended'
    item.statusText = '已结束'
  }
  return wait(item || classes[0])
}

export const getClassroomPhase = () => wait({
  phase: 'focus1',
  phase_name: '第一专注段',
  remaining_seconds: 1800,
  total_phase_seconds: 3000,
  classroom_status: 'running',
  focus1_minutes: 50,
  break_minutes: 5,
  focus2_minutes: 40,
})

