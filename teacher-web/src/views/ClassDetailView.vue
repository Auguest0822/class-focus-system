<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { getClassDetail, getClassroomPhase, getMembers, startClassroom, endClassroom } from '@/api/classApi'
import ClassCodeCard from '@/components/ClassCodeCard.vue'
import StudentTable from '@/components/StudentTable.vue'
import TopBar from '@/components/TopBar.vue'

const route = useRoute()
const router = useRouter()
const classInfo = ref({})
const courses = ref([])
const expandedCourseNo = ref('')
const selectedLessonId = ref('')
const students = ref([])

// ── 倒计时相关状态 ──
const phaseInfo = ref(null)       // { phase, phase_name, remaining_seconds, total_phase_seconds, classroom_status, server_time }
const countdownDisplay = ref('')  // MM:SS 格式
const countdownEnding = ref(false) // 最后 60 秒闪烁警告
const localRemaining = ref(0)     // 本地 1 秒更新的剩余秒数(驱动进度条平滑动画)
const isRunning = ref(false)
let countdownTimer = null         // 1 秒本地倒计时
let syncTimer = null              // 30 秒后端校准
let localEndTime = null           // 本地阶段结束时间戳(毫秒), = Date.now() + remainingSeconds*1000

// ── 格式化剩余秒数为 MM:SS ──
const formatRemaining = (seconds) => {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

// ── 当前阶段进度百分比(用本地剩余秒数,每秒平滑更新) ──
const phaseProgress = computed(() => {
  if (!phaseInfo.value || phaseInfo.value.total_phase_seconds === 0) return 0
  const used = phaseInfo.value.total_phase_seconds - localRemaining.value
  return Math.min(100, Math.round((used / phaseInfo.value.total_phase_seconds) * 100))
})

// ── 阶段颜色 ──
const phaseColor = computed(() => {
  if (!phaseInfo.value) return '#2563eb'
  return phaseInfo.value.phase === 'break' ? '#f97316' : '#2563eb'
})

// ── 判断某个阶段是否已完成 ──
const phaseOrder = ['第一专注段', '课间休息', '第二专注段']
const phaseDone = (name) => {
  const currentIdx = phaseOrder.indexOf(phaseInfo.value?.phase_name)
  const thisIdx = phaseOrder.indexOf(name)
  return currentIdx > thisIdx
}

// ── 本地 1 秒倒计时刷新(纯本地计算,不发起网络请求) ──
const tickLocalCountdown = () => {
  if (localEndTime === null) return
  const remaining = Math.max(0, Math.ceil((localEndTime - Date.now()) / 1000))
  localRemaining.value = remaining
  countdownDisplay.value = formatRemaining(remaining)
  countdownEnding.value = remaining > 0 && remaining <= 60
  // 本地倒计时归零 → 立刻向后端同步,获取下一阶段
  if (remaining <= 0 && isRunning.value) {
    syncFromBackend()
  }
}

// ── 向后端校准(阶段信息 + 重置 localEndTime) ──
const syncFromBackend = async () => {
  try {
    const data = await getClassroomPhase(selectedLessonId.value)
    const prevPhase = phaseInfo.value?.phase
    phaseInfo.value = data
    isRunning.value = data.classroom_status === 'running' && data.phase !== 'finished'

    // 用后端返回的剩余秒数重新锚定本地结束时间
    localEndTime = Date.now() + data.remaining_seconds * 1000
    tickLocalCountdown()

    if (!isRunning.value) stopAllTimers()
  } catch {
    // 校准失败不中断,本地倒计时继续跑
  }
}

// ── 启动所有定时器 ──
const startTimers = () => {
  if (countdownTimer) return
  syncFromBackend()  // 立即首次同步
  countdownTimer = setInterval(tickLocalCountdown, 1000)   // 每秒刷新显示
  syncTimer = setInterval(syncFromBackend, 30_000)          // 每 30 秒校准
}

// ── 停止所有定时器 ──
const stopAllTimers = () => {
  if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null }
  if (syncTimer) { clearInterval(syncTimer); syncTimer = null }
  countdownEnding.value = false
  localEndTime = null
}

// ── 刷新课堂数据 ──
const refreshClassData = async () => {
  const data = await getClassDetail(route.params.id)
  classInfo.value = data.classInfo
  courses.value = data.courses
  students.value = data.students
}

// ── 开始课堂 ──
const handleStartClass = async () => {
  const updated = await startClassroom(selectedLessonId.value)
  // 更新当前选中课堂的状态
  const idx = selectedLesson.value ? allLessons.value.indexOf(selectedLesson.value) : -1
  if (idx >= 0) allLessons.value[idx] = updated
  classInfo.value = { ...classInfo.value, ...updated }
  isRunning.value = true
  startTimers()
}

// ── 提前结束课堂 ──
const handleEndClass = async () => {
  try {
    await ElMessageBox.confirm('确认提前结束课堂？结束后将生成课堂报告。', '结束课堂', {
      confirmButtonText: '确认结束',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch {
    return // 用户取消
  }
  await endClassroom(selectedLessonId.value)
  stopAllTimers()
  isRunning.value = false
  phaseInfo.value = null
  await refreshClassData()
}

// ── 组件卸载时清理定时器 ──
onBeforeUnmount(() => stopAllTimers())

const loadClassroomMembers = async (classroomId) => {
  if (!classroomId) {
    students.value = []
    return
  }
  students.value = await getMembers(classroomId)
}

onMounted(async () => {
  const data = await getClassDetail(route.params.id)
  classInfo.value = data.classInfo
  courses.value = data.courses
  expandedCourseNo.value = data.classInfo.courseNo
  selectedLessonId.value = data.classInfo.id
  students.value = data.students

  // 如果课堂已经在运行中（老师刷新了页面），自动恢复倒计时
  if (data.classInfo.status === 'running') {
    isRunning.value = true
    startTimers()
  }
})

const allLessons = computed(() => courses.value.flatMap((course) => course.lessons))

const selectedLesson = computed(
  () => allLessons.value.find((lesson) => lesson.id === selectedLessonId.value) || classInfo.value,
)

const isSelectedInCourse = (course) => course.lessons.some((lesson) => lesson.id === selectedLessonId.value)

const toggleCourse = (course) => {
  if (expandedCourseNo.value === course.courseNo) {
    expandedCourseNo.value = ''
    return
  }
  expandedCourseNo.value = course.courseNo
}

const selectLesson = async (course, lesson) => {
  // 切换课次时停止旧定时器
  stopAllTimers()
  isRunning.value = false
  phaseInfo.value = null

  expandedCourseNo.value = course.courseNo
  selectedLessonId.value = lesson.id
  await loadClassroomMembers(lesson.id)

  // 如果切到的课次正在运行中，启动轮询
  if (lesson.status === 'running') {
    isRunning.value = true
    startTimers()
  }
}

const formatLessonTime = (lesson) => {
  if (!lesson.startTime || !lesson.endTime) return '未设置时间'
  const startDate = lesson.startTime.slice(0, 10)
  const endDate = lesson.endTime.slice(0, 10)
  const endTime = lesson.endTime.slice(11)
  if (startDate === endDate) return `${lesson.startTime}-${endTime}`
  return `${lesson.startTime}-${lesson.endTime}`
}

const tagType = (status) => {
  if (status === 'running') return 'primary'
  if (status === 'ended') return 'success'
  return 'info'
}
</script>

<template>
  <TopBar>
    <template #actions>
      <!-- waiting → 开始课堂按钮 -->
      <el-button
        v-if="selectedLesson.status === 'waiting' || selectedLesson.status === 'pending'"
        type="primary"
        size="large"
        @click="handleStartClass"
      >
        开始课堂
      </el-button>

      <!-- running → 倒计时 + 结束按钮 -->
      <div v-else-if="isRunning && phaseInfo" class="countdown-bar">
        <span class="phase-tag" :style="{ background: phaseColor }">
          {{ phaseInfo.phase_name }}
        </span>
        <span class="timer" :class="{ ending: countdownEnding }">
          {{ countdownDisplay || '--:--' }}
        </span>
        <el-progress
          :percentage="phaseProgress"
          :stroke-width="6"
          :color="phaseColor"
          :show-text="false"
          style="width: 100px"
        />
        <el-button type="danger" size="default" @click="handleEndClass">
          提前结束
        </el-button>
      </div>

      <!-- finished → 查看报告 -->
      <el-button
        v-else-if="selectedLesson.status === 'ended' || selectedLesson.status === 'finished'"
        type="primary"
        size="large"
        @click="router.push(selectedLesson.id ? `/class-report/${selectedLesson.id}` : '/class-report')"
      >
        查看报告
      </el-button>
    </template>
  </TopBar>

  <section class="course-stack">
    <article v-for="course in courses" :key="course.courseNo" class="course-card">
      <button type="button" class="course-header" @click="toggleCourse(course)">
        <span>
          <strong>{{ course.courseName }}</strong>
          <em>课号：{{ course.courseNo }}</em>
        </span>
        <span class="course-meta">
          <el-tag type="primary" effect="light" round>已创建 {{ course.lessons.length }} 次课</el-tag>
          <i :class="{ open: expandedCourseNo === course.courseNo }">⌄</i>
        </span>
      </button>

      <div v-if="expandedCourseNo === course.courseNo" class="lesson-list">
        <button
          v-for="lesson in course.lessons"
          :key="lesson.id"
          type="button"
          class="lesson-row"
          :class="{ active: selectedLessonId === lesson.id }"
          @click="selectLesson(course, lesson)"
        >
          <span class="lesson-name">{{ lesson.className }}</span>
          <span class="lesson-time">{{ formatLessonTime(lesson) }}</span>
          <el-tag :type="tagType(lesson.status)" effect="light" round>{{ lesson.statusText }}</el-tag>
        </button>

        <div v-if="isSelectedInCourse(course)" class="lesson-detail">
          <section class="lesson-info">
            <h2>本次课堂信息</h2>
            <ClassCodeCard :code="selectedLesson.code" />

            <dl class="info-list">
              <div>
                <dt>课次</dt>
                <dd>{{ selectedLesson.className }}</dd>
              </div>
              <div>
                <dt>课堂时长</dt>
                <dd>{{ selectedLesson.duration }}</dd>
              </div>
              <div>
                <dt>加入人数</dt>
                <!--
                  优先用后端返回的 joinedCount；
                  如果后端没返回该字段（例如 CourseGroupInfo 里只有 classroom 基础字段），
                  退而用 "当前成员列表长度"，避免显示 "0 人已加入" 导致老师以为没人进来。
                -->
                <dd>
                  {{
                    selectedLesson.joinedCount != null && selectedLesson.joinedCount > 0
                      ? `${selectedLesson.joinedCount} 人`
                      : `${students.length || 0} 人`
                  }}
                </dd>
              </div>
              <div>
                <dt>课堂状态</dt>
                <dd>{{ selectedLesson.statusText }}</dd>
              </div>
            </dl>

            <!-- 倒计时面板：仅 running 状态显示 -->
            <div v-if="isRunning && phaseInfo" class="phase-panel">
              <div class="phase-display">
                <span class="phase-label" :style="{ color: phaseColor }">
                  {{ phaseInfo.phase_name }}
                </span>
                <span class="phase-timer" :class="{ ending: countdownEnding }">
                  {{ countdownDisplay }}
                </span>
              </div>
              <el-progress
                :percentage="phaseProgress"
                :stroke-width="8"
                :color="phaseColor"
                :show-text="false"
              />
              <div class="phase-sequence">
                <span
                  class="phase-step"
                  :class="{ active: phaseInfo.phase_name === '第一专注段', done: phaseDone('第一专注段') }"
                >第一专注段</span>
                <span class="phase-arrow">→</span>
                <span
                  class="phase-step"
                  :class="{ active: phaseInfo.phase_name === '课间休息', done: phaseDone('课间休息') }"
                >课间休息</span>
                <span class="phase-arrow">→</span>
                <span
                  class="phase-step"
                  :class="{ active: phaseInfo.phase_name === '第二专注段', done: phaseDone('第二专注段') }"
                >第二专注段</span>
              </div>
            </div>
          </section>

          <section class="students-panel">
            <div class="panel-title">
              <h2>学生加入情况</h2>
              <el-tag type="primary" effect="light" round>{{ students.length || 0 }} 人已加入</el-tag>
            </div>
            <StudentTable :students="students" />
          </section>
        </div>
      </div>
    </article>
  </section>
</template>

<style scoped>
.course-stack {
  display: grid;
  gap: 18px;
}

.course-card {
  overflow: hidden;
  border: 1px solid #d5e5f2;
  border-radius: 18px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
}

.course-header {
  width: 100%;
  min-height: 92px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 22px 28px;
  border: 0;
  background: #ffffff;
  color: #12355b;
  text-align: left;
  cursor: pointer;
}

.course-header strong,
.course-header em {
  display: block;
  letter-spacing: 0;
}

.course-header strong {
  font-size: 25px;
  line-height: 1.2;
}

.course-header em {
  margin-top: 8px;
  color: #5f7894;
  font-style: normal;
  font-weight: 700;
}

.course-meta {
  display: inline-flex;
  align-items: center;
  gap: 14px;
  flex: 0 0 auto;
}

.course-meta i {
  display: inline-grid;
  place-items: center;
  width: 30px;
  height: 30px;
  color: #2563eb;
  font-style: normal;
  font-size: 22px;
  transition: transform 0.2s ease;
}

.course-meta i.open {
  transform: rotate(180deg);
}

.lesson-list {
  display: grid;
  gap: 10px;
  padding: 0 28px 28px;
}

.lesson-row {
  min-height: 54px;
  display: grid;
  grid-template-columns: minmax(110px, 180px) minmax(220px, 1fr) 86px;
  align-items: center;
  gap: 16px;
  padding: 0 16px;
  border: 1px solid #e5eef6;
  border-radius: 10px;
  background: #fbfdff;
  color: #516987;
  text-align: left;
  cursor: pointer;
}

.lesson-row.active {
  border-color: #bfe4ee;
  background: #eaf7ff;
}

.lesson-name {
  color: #12355b;
  font-weight: 800;
}

.lesson-time {
  font-weight: 700;
}

.lesson-detail {
  display: grid;
  grid-template-columns: 380px minmax(0, 1fr);
  gap: 24px;
  margin-top: 12px;
  padding-top: 18px;
}

.lesson-info,
.students-panel {
  overflow: hidden;
  border: 1px solid #d5e5f2;
  border-radius: 18px;
  background: #ffffff;
}

.lesson-info {
  padding: 28px;
}

.panel-title {
  min-height: 52px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 20px 24px 12px;
}

h2 {
  margin: 0;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.info-list {
  display: grid;
  gap: 16px;
  margin: 26px 0 0;
}

.info-list div {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
}

dt {
  color: #516987;
}

dd {
  margin: 0;
  color: #12355b;
  font-weight: 800;
}

/* ── 倒计时 TopBar 条 ── */
.countdown-bar {
  display: flex;
  align-items: center;
  gap: 14px;
}

.phase-tag {
  padding: 6px 14px;
  border-radius: 999px;
  color: #ffffff;
  font-weight: 800;
  font-size: 14px;
  white-space: nowrap;
}

.timer {
  font-size: 32px;
  font-weight: 900;
  font-variant-numeric: tabular-nums;
  color: #12355b;
  min-width: 90px;
}

.timer.ending {
  color: #dc2626;
  animation: pulse 0.8s ease-in-out infinite alternate;
}

@keyframes pulse {
  from { opacity: 1; }
  to { opacity: 0.4; }
}

/* ── 课堂信息区内的倒计时面板 ── */
.phase-panel {
  margin-top: 22px;
  padding: 20px;
  border: 1px solid #bfe4ee;
  border-radius: 16px;
  background: linear-gradient(135deg, #eaf7ff, #f0faf5);
}

.phase-display {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 14px;
}

.phase-label {
  font-size: 18px;
  font-weight: 800;
}

.phase-timer {
  font-size: 42px;
  font-weight: 900;
  font-variant-numeric: tabular-nums;
  color: #12355b;
}

.phase-timer.ending {
  color: #dc2626;
  animation: pulse 0.8s ease-in-out infinite alternate;
}

.phase-sequence {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 16px;
}

.phase-step {
  padding: 6px 14px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 700;
  color: #5f7894;
  background: #e5eef6;
}

.phase-step.active {
  color: #ffffff;
  background: #2563eb;
}

.phase-step.done {
  color: #00966d;
  background: #e2f8ee;
}

.phase-arrow {
  color: #bccddb;
  font-size: 14px;
}

@media (max-width: 1060px) {
  .lesson-detail {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 760px) {
  .course-header,
  .lesson-row {
    align-items: flex-start;
    grid-template-columns: 1fr;
  }

  .course-header {
    flex-direction: column;
  }

  .course-meta {
    width: 100%;
    justify-content: space-between;
  }
}
</style>
