import request from './request'

const statusTextMap = {
  pending: '未开始',
  waiting: '未开始',
  running: '进行中',
  ended: '已结束',
  finished: '已结束',
}

const toPageStatus = (status) => {
  if (status === 'finished') return 'ended'
  if (status === 'waiting') return 'pending'
  return status || 'pending'
}

const toDateTimeText = (value) => {
  if (!value) return ''

  const text = value.toString()
  if (text.length >= 16) {
    return text.slice(0, 16).replace('T', ' ')
  }

  return text
}

const durationText = (item = {}) => {
  const focusOne = item.focus1_minutes ?? item.focus_one_minutes ?? item.focusOne
  const breakTime = item.break_minutes ?? item.breakTime
  const focusTwo = item.focus2_minutes ?? item.focus_two_minutes ?? item.focusTwo

  if (focusOne || breakTime || focusTwo) {
    return `${focusOne || 0} + ${breakTime || 0} + ${focusTwo || 0}`
  }

  if (item.duration_minutes) {
    return `${item.duration_minutes} 分钟`
  }

  return ''
}

const normalizeClassroom = (item = {}) => {
  const status = toPageStatus(item.status)

  return {
    ...item,
    id: item.id,
    courseNo: item.course_no ?? item.courseNo ?? '',
    courseName: item.course_name ?? item.courseName ?? '',
    className: item.lesson_name ?? item.className ?? item.name ?? '',
    code: item.code ?? item.classroom_code ?? '',
    startTime: toDateTimeText(item.scheduled_start_at ?? item.started_at ?? item.startTime),
    endTime: toDateTimeText(item.ended_at ?? item.endTime),
    duration: item.duration ?? durationText(item),
    status,
    statusText: statusTextMap[status] || statusTextMap[item.status] || '未开始',
    joinedCount: item.joined_count ?? item.member_count ?? item.joinedCount ?? 0,
  }
}

const normalizeStudent = (item = {}) => ({
  ...item,
  id: item.student_no ?? item.username ?? item.id,
  name: item.name ?? item.student_name ?? item.username ?? '',
  joinTime: toDateTimeText(item.joined_at ?? item.joinTime),
  status: item.has_uploaded_usage ? '数据已上传' : item.status || '已加入',
  statusType: item.has_uploaded_usage ? 'success' : item.statusType || 'primary',
  focusRate: item.focus_rate ? `${item.focus_rate}%` : item.focusRate || '--',
})

const groupByCourse = (classes) => {
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

const buildDashboardStats = (classes) => {
  const courses = new Set(classes.map((item) => item.courseNo || item.courseName).filter(Boolean))
  const studentCount = classes.reduce((total, item) => total + Number(item.joinedCount || 0), 0)

  return [
    { label: '累计课程', value: String(courses.size) },
    { label: '累计课堂', value: String(classes.length) },
    { label: '累计参与学生', value: String(studentCount) },
    { label: '近期平均专注率', value: '--' },
  ]
}

const currentOrFirstClass = (classes, id) =>
  classes.find((item) => String(item.id) === String(id) || item.code === id) || classes[0] || {}

const normalizeReportSummary = (report = {}) => [
  { label: '参与学生', value: String(report.total_students ?? '--') },
  { label: '平均专注率', value: report.focus_score == null ? '--' : `${report.focus_score}%` },
  {
    label: '平均分心时长',
    value: report.average_usage_seconds == null ? '--' : `${Math.round(report.average_usage_seconds / 60)}m`,
  },
  { label: '主要分心类型', value: report.main_distract_type ?? '--' },
]

const createPayload = (form) => ({
  course_no: form.courseNo,
  course_name: form.courseName,
  lesson_name: form.className,
  scheduled_start_at: form.startTime,
  focus1_minutes: Number(form.focusOne),
  break_minutes: Number(form.breakTime),
  focus2_minutes: Number(form.focusTwo),
  duration_minutes: Number(form.focusOne) + Number(form.breakTime) + Number(form.focusTwo),
})

export const getDashboard = async () => {
  const classes = await getClasses()

  return {
    stats: buildDashboardStats(classes),
    classes,
  }
}

export const getClasses = async () => {
  const groups = await request.get('/teacher/courses')
  // 后端按课程返回 CourseGroupInfo[];前端内部统一成 "单个课次" 的扁平列表,
  // 以便下游 normalizeClassroom / DashboardView / ClassDetailView / ClassReportView
  // 继续按 "某一次课堂" 来处理。
  const list = Array.isArray(groups) ? groups.flatMap((g) => (g.classrooms || []).map((c) => ({
    ...c,
    course_no: g.course_no,
    course_name: g.course_name,
  }))) : []
  return list.map(normalizeClassroom)
}

export const createClass = async (form) => {
  const data = await request.post('/teacher/classrooms', createPayload(form))
  return normalizeClassroom(data)
}

/**
 * 拉取某一次课堂的已加入学生成员 + 使用情况。
 * 对应后端: GET /api/teacher/classrooms/{id}/members。
 * 在 ClassDetailView / ClassReportView 里，每切换一次课次都应该调用一次。
 */
export const getMembers = async (classroomId) => {
  if (!classroomId) return []
  const list = await request.get(`/teacher/classrooms/${classroomId}/members`)
  return (Array.isArray(list) ? list : []).map(normalizeStudent)
}

export const getClassDetail = async (id) => {
  const classes = await getClasses()
  const classInfo = currentOrFirstClass(classes, id)
  const students = classInfo.id ? await getMembers(classInfo.id) : []

  return {
    classInfo,
    courses: groupByCourse(classes),
    students,
  }
}

export const getClassReport = async (id) => {
  const classes = await getClasses()
  const classInfo = currentOrFirstClass(classes, id)
  const report = classInfo.id ? await request.get(`/report/classrooms/${classInfo.id}`) : {}

  return {
    classInfo,
    courses: groupByCourse(classes),
    summary: normalizeReportSummary(report),
    studentStats: report.student_stats || report.studentStats || [],
    appUsage: report.app_usage || report.appUsage || [],
  }
}
