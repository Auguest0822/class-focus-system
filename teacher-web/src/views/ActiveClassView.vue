<script setup>
import { computed, onActivated, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getClassDetail, getClassroomPhase, getMembers, startClassroom, endClassroom } from '@/api/classApi'
import ClassCodeCard from '@/components/ClassCodeCard.vue'
import StudentTable from '@/components/StudentTable.vue'
import TopBar from '@/components/TopBar.vue'

const route = useRoute()
const router = useRouter()
const classInfo = ref({})
const students = ref([])

// ── 倒计时相关状态 ──
const phaseInfo = ref(null)
const countdownDisplay = ref('')
const countdownEnding = ref(false)
const localRemaining = ref(0)
const isRunning = ref(false)
let countdownTimer = null
let syncTimer = null
let membersTimer = null
let localEndTime = null

const formatRemaining = (seconds) => {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

const phaseProgress = computed(() => {
  if (!phaseInfo.value || phaseInfo.value.total_phase_seconds === 0) return 0
  const used = phaseInfo.value.total_phase_seconds - localRemaining.value
  return Math.min(100, Math.round((used / phaseInfo.value.total_phase_seconds) * 100))
})

const phaseColor = computed(() => {
  if (!phaseInfo.value) return '#2563eb'
  return phaseInfo.value.phase === 'break' ? '#f97316' : '#2563eb'
})

const phaseOrder = ['第一专注段', '课间休息', '第二专注段']
const phaseDone = (name) => {
  const currentIdx = phaseOrder.indexOf(phaseInfo.value?.phase_name)
  const thisIdx = phaseOrder.indexOf(name)
  return currentIdx > thisIdx
}

// ── 1 秒本地倒计时 ──
const tickLocalCountdown = () => {
  if (localEndTime === null) return
  const remaining = Math.max(0, Math.ceil((localEndTime - Date.now()) / 1000))
  localRemaining.value = remaining
  countdownDisplay.value = formatRemaining(remaining)
  countdownEnding.value = remaining > 0 && remaining <= 60
  if (remaining <= 0 && isRunning.value) {
    syncFromBackend()
  }
}

// ── 后端校准 ──
const syncFromBackend = async () => {
  if (!classInfo.value.id) return
  try {
    const data = await getClassroomPhase(classInfo.value.id)
    phaseInfo.value = data
    isRunning.value = data.classroom_status === 'running' && data.phase !== 'finished'
    localEndTime = Date.now() + data.remaining_seconds * 1000
    tickLocalCountdown()
    if (!isRunning.value) stopAllTimers()
  } catch { /* 校准失败不中断 */ }
}

// ── 定时器 ──
const startTimers = () => {
  if (countdownTimer) return
  syncFromBackend()
  countdownTimer = setInterval(tickLocalCountdown, 1000)
  syncTimer = setInterval(syncFromBackend, 30_000)
}

const stopAllTimers = () => {
  if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null }
  if (syncTimer) { clearInterval(syncTimer); syncTimer = null }
  countdownEnding.value = false
  localEndTime = null
}

// ── 学生列表 5 秒轮询 ──
const startMembersPolling = () => {
  if (membersTimer) return
  membersTimer = setInterval(async () => {
    if (!classInfo.value.id) return
    try {
      students.value = await getMembers(classInfo.value.id)
    } catch { /* 静默 */ }
  }, 5000)
}

const stopMembersPolling = () => {
  if (membersTimer) { clearInterval(membersTimer); membersTimer = null }
}

// ── 刷新数据 ──
const refreshClassData = async () => {
  const data = await getClassDetail(classInfo.value.id)
  classInfo.value = data.classInfo
  students.value = data.students
}

// ── 开始课堂 ──
const handleStartClass = async () => {
  try {
    const updated = await startClassroom(classInfo.value.id)
    classInfo.value = { ...classInfo.value, ...updated }
    isRunning.value = true
    startTimers()
    ElMessage.success('课堂已开始')
  } catch (error) {
    ElMessage.error(error.message || '开始课堂失败')
  }
}

// ── 提前结束 ──
const handleEndClass = async () => {
  try {
    await ElMessageBox.confirm('确认提前结束课堂？结束后将生成课堂报告。', '结束课堂', {
      confirmButtonText: '确认结束',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await endClassroom(classInfo.value.id)
    stopAllTimers()
    isRunning.value = false
    phaseInfo.value = null
    await refreshClassData()
    ElMessage.success('课堂已结束')
  } catch (error) {
    ElMessage.error(error.message || '结束课堂失败')
  }
}

// ── 查看报告 ──
const goToReport = () => {
  router.push(`/class-report/${classInfo.value.id}`)
}

onBeforeUnmount(() => {
  stopAllTimers()
  stopMembersPolling()
})

const loadClassData = async (id) => {
  stopAllTimers()
  stopMembersPolling()
  isRunning.value = false
  phaseInfo.value = null

  const data = await getClassDetail(id)
  classInfo.value = data.classInfo
  students.value = data.students

  if (data.classInfo.status === 'running') {
    isRunning.value = true
    startTimers()
  }

  startMembersPolling()
}

let _activeReady = false
onMounted(async () => {
  await loadClassData(route.params.id)
  _activeReady = true
})

// 从缓存恢复时刷新（仅在非首次激活时）
onActivated(() => {
  if (!_activeReady) return
  stopAllTimers()
  stopMembersPolling()
  isRunning.value = false
  phaseInfo.value = null
  // 仅当路由带有具体 ID 时重新加载，否则保持缓存数据
  if (route.params.id) {
    loadClassData(route.params.id)
  } else {
    startMembersPolling()
    if (classInfo.value.status === 'running') {
      isRunning.value = true
      startTimers()
    }
  }
})

// 路由参数变化时重新加载（新创建课堂重定向到 /active-class/{newId}）
watch(() => route.params.id, (newId, oldId) => {
  if (newId && newId !== oldId) {
    loadClassData(newId)
  }
})
</script>

<template>
  <TopBar>
    <template #actions>
      <!-- 等待中 → 开始课堂按钮 -->
      <el-button
        v-if="classInfo.status === 'pending' || classInfo.status === 'waiting'"
        type="primary"
        size="large"
        @click="handleStartClass"
      >
        开始课堂
      </el-button>

      <!-- 进行中 → 倒计时条 + 提前结束 -->
      <div v-if="isRunning && phaseInfo" class="topbar-phase">
        <span class="phase-tag" :style="{ background: phaseColor }">
          {{ phaseInfo.phase_name }}
        </span>
        <span class="phase-countdown" :class="{ ending: countdownEnding }">
          {{ countdownDisplay }}
        </span>
        <div class="phase-mini-bar">
          <span :style="{ width: `${phaseProgress}%`, background: phaseColor }"></span>
        </div>
        <el-button type="danger" size="small" plain @click="handleEndClass">提前结束</el-button>
      </div>

      <!-- 已结束 → 查看报告 -->
      <el-button
        v-if="classInfo.status === 'ended' || classInfo.status === 'finished'"
        type="primary"
        size="large"
        @click="goToReport"
      >
        查看报告
      </el-button>
    </template>
  </TopBar>

  <div class="active-grid">
    <!-- ── 左列：课堂信息 ── -->
    <section class="panel info-panel">
      <h2>课堂信息</h2>
      <ClassCodeCard :code="classInfo.code" :hint="classInfo.code ? '学生使用此码加入课堂' : '创建课堂后生成'" />

      <dl class="info-list">
        <div><dt>课程批次</dt><dd>{{ classInfo.courseNo }}</dd></div>
        <div><dt>课程名称</dt><dd>{{ classInfo.courseName }}</dd></div>
        <div><dt>课次</dt><dd>{{ classInfo.className }}</dd></div>
        <div><dt>课堂时长</dt><dd>{{ classInfo.duration }}</dd></div>
        <div><dt>课堂状态</dt><dd class="status-text">{{ classInfo.statusText || '未开始' }}</dd></div>
      </dl>

      <!-- 进行中 → 倒计时区域 -->
      <div v-if="isRunning && phaseInfo" class="phase-panel">
        <span class="phase-label" :style="{ color: phaseColor }">{{ phaseInfo.phase_name }}</span>
        <span class="phase-timer" :style="{ color: countdownEnding ? '#e53e3e' : '#12355b' }">
          {{ countdownDisplay }}
        </span>

        <div class="phase-bar-wrap">
          <span class="phase-bar">
            <span :style="{ width: `${phaseProgress}%`, background: phaseColor }"></span>
          </span>
        </div>

        <div class="phase-steps">
          <span
            v-for="name in phaseOrder"
            :key="name"
            :class="{
              active: phaseInfo.phase_name === name,
              done: phaseDone(name),
            }"
          >{{ name }}</span>
        </div>
      </div>
    </section>

    <!-- ── 右列：学生列表 ── -->
    <section class="panel students-panel">
      <div class="panel-header">
        <h2>学生加入情况</h2>
        <el-tag type="primary" effect="plain" round>{{ students.length }} 人已加入</el-tag>
      </div>
      <StudentTable :students="students" />
    </section>
  </div>
</template>

<style scoped>
.active-grid {
  display: grid;
  grid-template-columns: minmax(0, 380px) minmax(0, 1fr);
  gap: 22px;
}

.panel {
  border: 1px solid #d5e5f2;
  border-radius: 20px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
}

.info-panel {
  padding: 26px 24px;
}

.info-panel h2 {
  margin: 0 0 18px;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.info-list {
  display: grid;
  gap: 12px;
  margin: 20px 0 0;
}

.info-list div {
  display: flex;
  justify-content: space-between;
  gap: 16px;
}

.info-list dt {
  color: #5f7894;
}

.info-list dd {
  margin: 0;
  color: #12355b;
  font-weight: 800;
  text-align: right;
}

.status-text {
  color: #2563eb !important;
}

.students-panel {
  display: flex;
  flex-direction: column;
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  min-height: 74px;
  padding: 0 24px;
  border-bottom: 1px solid #d5e5f2;
}

.panel-header h2 {
  margin: 0;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

/* ── 倒计时面板 ── */
.phase-panel {
  margin-top: 22px;
  padding-top: 20px;
  border-top: 1px solid #e5eef6;
  text-align: center;
}

.phase-label {
  display: block;
  font-size: 20px;
  font-weight: 800;
}

.phase-timer {
  display: block;
  margin: 6px 0 14px;
  font-size: 48px;
  font-weight: 900;
  font-variant-numeric: tabular-nums;
  transition: color 0.3s;
}

.phase-bar-wrap {
  padding: 0 2px;
}

.phase-bar {
  display: block;
  height: 8px;
  overflow: hidden;
  border-radius: 999px;
  background: #e2edf5;
}

.phase-bar span {
  display: block;
  height: 100%;
  border-radius: inherit;
  transition: width 1s linear;
}

/* 三阶段指示器 */
.phase-steps {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
  margin-top: 14px;
}

.phase-steps span {
  display: grid;
  place-items: center;
  min-height: 36px;
  padding: 6px 4px;
  border-radius: 8px;
  background: #f1f5f9;
  color: #5f7894;
  font-weight: 700;
  font-size: 13px;
}

.phase-steps span.active {
  background: #2563eb;
  color: #ffffff;
}

.phase-steps span.done {
  background: #12b981;
  color: #ffffff;
}

/* ── TopBar 操作区 ── */
.topbar-phase {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 6px 0;
}

.phase-tag {
  padding: 4px 14px;
  border-radius: 999px;
  color: #ffffff;
  font-weight: 800;
  font-size: 14px;
  white-space: nowrap;
}

.phase-countdown {
  font-size: 32px;
  font-weight: 900;
  font-variant-numeric: tabular-nums;
  color: #12355b;
  transition: color 0.3s;
  min-width: 110px;
  text-align: center;
}

.phase-countdown.ending {
  color: #e53e3e;
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.phase-mini-bar {
  width: 100px;
  height: 6px;
  overflow: hidden;
  border-radius: 999px;
  background: #e2edf5;
}

.phase-mini-bar span {
  display: block;
  height: 100%;
  border-radius: inherit;
  transition: width 1s linear;
}

@media (max-width: 900px) {
  .active-grid {
    grid-template-columns: 1fr;
  }

  .topbar-phase {
    flex-wrap: wrap;
    gap: 8px;
  }
}
</style>
