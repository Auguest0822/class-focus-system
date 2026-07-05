export const teacher = {
  name: '张老师',
  avatarText: '张',
}

export const dashboardStats = [
  { label: '累计课堂', value: '12' },
  { label: '进行中课堂', value: '3' },
  { label: '累计参与学生', value: '428' },
  { label: '近期平均专注率', value: '82%' },
]

export const classes = [
  {
    id: 'PY2025',
    className: '第 1 次课',
    courseName: 'Python 基础',
    code: 'PY2025',
    duration: '50 + 5 + 40',
    teacherName: '张老师',
    status: 'ended',
    statusText: '已结束',
    joinedCount: 36,
  },
  {
    id: 'PY3078',
    className: '列表与字典',
    courseName: 'Python 基础',
    code: 'PY3078',
    duration: '45 + 10 + 40',
    teacherName: '张老师',
    status: 'running',
    statusText: '进行中',
    joinedCount: 36,
  },
  {
    id: 'PY4812',
    className: '函数基础',
    courseName: 'Python 基础',
    code: 'PY4812',
    duration: '50 + 5 + 40',
    teacherName: '张老师',
    status: 'pending',
    statusText: '未开始',
    joinedCount: 0,
  },
  {
    id: 'CS6201',
    className: '循环结构',
    courseName: '程序设计',
    code: 'CS6201',
    duration: '40 + 10 + 40',
    teacherName: '张老师',
    status: 'ended',
    statusText: '已结束',
    joinedCount: 28,
  },
]

export const students = [
  {
    id: '20240101',
    name: '李明',
    joinTime: '08:02',
    status: '数据已上传',
    statusType: 'success',
    focusRate: '92%',
    focusMinutes: 82,
    distractMinutes: 5,
    mainDistractType: '社交',
  },
  {
    id: '20240102',
    name: '王可',
    joinTime: '08:03',
    status: '已加入',
    statusType: 'primary',
    focusRate: '--',
    focusMinutes: 0,
    distractMinutes: 0,
    mainDistractType: '--',
  },
  {
    id: '20240103',
    name: '陈雨',
    joinTime: '08:04',
    status: '数据已上传',
    statusType: 'success',
    focusRate: '84%',
    focusMinutes: 76,
    distractMinutes: 9,
    mainDistractType: '短视频',
  },
  {
    id: '20240104',
    name: '赵然',
    joinTime: '08:05',
    status: '未上传数据',
    statusType: 'warning',
    focusRate: '--',
    focusMinutes: 0,
    distractMinutes: 0,
    mainDistractType: '--',
  },
  {
    id: '20240105',
    name: '周宁',
    joinTime: '08:05',
    status: '数据已上传',
    statusType: 'success',
    focusRate: '78%',
    focusMinutes: 70,
    distractMinutes: 14,
    mainDistractType: '游戏',
  },
]

export const reportSummary = [
  { label: '参与学生', value: '36' },
  { label: '平均专注率', value: '84%' },
  { label: '平均分心时长', value: '12m' },
  { label: '主要分心类型', value: '社交' },
]

export const appUsage = [
  { name: '学习类', percent: 76, color: '#12b981' },
  { name: '社交类', percent: 32, color: '#f97316' },
  { name: '娱乐类', percent: 18, color: '#2563eb' },
  { name: '锁屏', percent: 64, color: '#08b5c8' },
]

export const suggestions = [
  {
    tone: 'info',
    text: '本节课整体专注情况较好，但第二专注段后半段分心时长增加，建议在后半段加入提问或互动。',
  },
  {
    tone: 'success',
    text: '社交类应用使用相对较多，建议下次开课前强调课堂手机使用边界。',
  },
]
