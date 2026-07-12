<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { getClassReport } from '@/api/classApi'
import ReportSummaryCard from '@/components/ReportSummaryCard.vue'
import TopBar from '@/components/TopBar.vue'

const route = useRoute()
const classInfo = ref({})
const courses = ref([])
const expandedCourseNo = ref('')
const selectedLessonId = ref('')
const summary = ref([])
const studentStats = ref([])
const appTypeOverview = ref([])
const appRanking = ref([])

const loadReport = async (lessonId) => {
  const data = await getClassReport(lessonId)
  classInfo.value = data.classInfo
  courses.value = data.courses
  expandedCourseNo.value = data.classInfo.courseNo
  selectedLessonId.value = data.classInfo.id
  summary.value = data.summary
  studentStats.value = data.studentStats
  appTypeOverview.value = data.appTypeOverview
  appRanking.value = data.appRanking
}

onMounted(() => loadReport(route.params.id))

const allLessons = computed(() => courses.value.flatMap((course) => course.lessons))

const selectedLesson = computed(
  () => allLessons.value.find((lesson) => lesson.id === selectedLessonId.value) || classInfo.value,
)

const selectedLessonEnded = computed(() => selectedLesson.value?.status === 'ended')

const isSelectedInCourse = (course) => course.lessons.some((lesson) => lesson.id === selectedLessonId.value)

const generatedReportCount = (course) => course.lessons.filter((lesson) => lesson.status === 'ended').length

const toggleCourse = (course) => {
  if (expandedCourseNo.value === course.courseNo) {
    expandedCourseNo.value = ''
    return
  }

  expandedCourseNo.value = course.courseNo
}

const selectLesson = (course, lesson) => {
  expandedCourseNo.value = course.courseNo
  loadReport(lesson.id)
}

const formatLessonTime = (lesson) => {
  const startTime = lesson.startTime
  if (!startTime) return '未设置时间'

  if (lesson.endTime) {
    const startDate = startTime.slice(0, 10)
    const endDate = lesson.endTime.slice(0, 10)
    const endTime = lesson.endTime.slice(11)
    if (startDate === endDate) return `${startTime}-${endTime}`
    return `${startTime}-${lesson.endTime}`
  }

  // 课堂未结束 → 用 计划开始时间 + 课堂时长 计算预计结束时间
  const totalMin = lesson.duration_minutes
    ?? lesson.focus1_minutes + lesson.break_minutes + lesson.focus2_minutes
    ?? 0
  if (totalMin <= 0) return startTime

  const m = startTime.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/)
  if (!m) return startTime

  const d = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5])
  d.setMinutes(d.getMinutes() + totalMin)
  const pad = (n) => String(n).padStart(2, '0')
  const endStr = `${pad(d.getHours())}:${pad(d.getMinutes())}`

  const startDate = startTime.slice(0, 10)
  const endDate = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  if (startDate === endDate) return `${startTime}-${endStr}`
  return `${startTime}-${endDate} ${endStr}`
}

const reportStatusText = (lesson) => {
  if (lesson.status === 'ended') return '已生成报告'
  if (lesson.status === 'running') return '进行中'
  return '未开始'
}

const tagType = (status) => {
  if (status === 'ended') return 'success'
  if (status === 'running') return 'primary'
  return 'info'
}

const emptyReportText = computed(() => {
  if (selectedLesson.value?.status === 'running') return '课堂进行中，报告将在结束后生成'
  return '课堂未开始，暂无报告'
})
</script>

<template>
  <TopBar>
    <template #actions>
      <el-button size="large" :disabled="!selectedLessonEnded">导出报告</el-button>
    </template>
  </TopBar>

  <section class="course-stack">
    <article v-for="course in courses" :key="course.courseNo" class="course-card">
      <div role="button" tabindex="0" class="course-header" @click="toggleCourse(course)" @keyup.enter="toggleCourse(course)">
        <span>
          <strong>{{ course.courseName }}</strong>
          <em>课号：{{ course.courseNo }}</em>
        </span>
        <span class="course-meta">
          <el-tag type="primary" effect="light" round>
            已生成 {{ generatedReportCount(course) }} 份报告 / 共 {{ course.lessons.length }} 次课
          </el-tag>
          <i :class="{ open: expandedCourseNo === course.courseNo }">⌄</i>
        </span>
      </div>

      <div v-if="expandedCourseNo === course.courseNo" class="lesson-list">
        <div
          v-for="lesson in course.lessons"
          :key="lesson.id"
          role="button"
          tabindex="0"
          class="lesson-row"
          :class="{ active: selectedLessonId === lesson.id }"
          @click="selectLesson(course, lesson)"
          @keyup.enter="selectLesson(course, lesson)"
        >
          <span class="lesson-name">{{ lesson.className }}</span>
          <span class="lesson-time">{{ formatLessonTime(lesson) }}</span>
          <el-tag :type="tagType(lesson.status)" effect="light" round>{{ reportStatusText(lesson) }}</el-tag>
        </div>

        <div v-if="isSelectedInCourse(course)" class="report-content">
          <template v-if="selectedLessonEnded">
            <section class="summary-grid">
              <ReportSummaryCard v-for="item in summary" :key="item.label" :value="item.value" :label="item.label" />
            </section>

            <div class="report-grid">
              <section class="panel">
                <div class="panel-title">
                  <h2>学生专注统计</h2>
                  <el-tag type="success" effect="light" round>已生成</el-tag>
                </div>
                <div class="panel-body">
                  <el-empty v-if="!studentStats.length" description="暂无学生数据" />
                  <el-collapse v-else>
                    <el-collapse-item v-for="(student, index) in studentStats" :key="index" :name="index">
                      <template #title>
                        <div class="student-collapse-title">
                          <span class="student-name">{{ student.name }}</span>
                          <span class="student-no" v-if="student.studentNo">{{ student.studentNo }}</span>
                          <el-tag type="warning" size="small" effect="plain" round>
                            分心 {{ student.distractMinutes }} 分钟
                          </el-tag>
                        </div>
                      </template>
                      <el-table v-if="student.apps.length" :data="student.apps" size="small" class="app-detail-table">
                        <el-table-column prop="name" label="应用" />
                        <el-table-column label="使用时长" width="150">
                          <template #default="{ row }">
                            {{ Math.floor(row.seconds / 60) }} 分 {{ row.seconds % 60 }} 秒
                          </template>
                        </el-table-column>
                      </el-table>
                      <p v-else class="no-apps-text">暂无使用记录</p>
                    </el-collapse-item>
                  </el-collapse>
                </div>
              </section>

              <section class="panel app-panel">
                <h2>App 类型使用概览</h2>
                <div class="usage-list">
                  <div v-for="item in appTypeOverview" :key="item.category" class="usage-item">
                    <span class="usage-name">{{ item.category }}</span>
                    <div class="usage-track">
                      <i :style="{ width: `${item.percent}%`, background: item.color }"></i>
                    </div>
                    <strong>{{ item.percent }}%</strong>
                  </div>
                </div>
                <el-empty v-if="!appTypeOverview.length" description="暂无应用使用数据" :image-size="60" />
              </section>

              <section class="panel app-ranking-panel">
                <h2>App 使用排行</h2>
                <p class="panel-subtitle">所有学生各应用总时长排行</p>
                <el-table v-if="appRanking.length" :data="appRanking" size="small" class="ranking-table" stripe>
                  <el-table-column type="index" label="#" width="50" />
                  <el-table-column prop="name" label="应用" min-width="140" />
                  <el-table-column label="使用时长" width="150">
                    <template #default="{ row }">
                      {{ Math.floor(row.totalSeconds / 60) }} 分 {{ row.totalSeconds % 60 }} 秒
                    </template>
                  </el-table-column>
                  <el-table-column label="使用人数" width="100">
                    <template #default="{ row }">
                      {{ row.studentCount }} 人
                    </template>
                  </el-table-column>
                </el-table>
                <el-empty v-else description="暂无应用使用数据" :image-size="60" />
              </section>
            </div>
          </template>

          <section v-else class="panel empty-report">
            <h2>{{ emptyReportText }}</h2>
            <p>请在课堂结束并完成学生数据上传后查看本次课堂报告。</p>
          </section>
        </div>
      </div>
    </article>
  </section>
</template>

<style>
.course-stack {
  display: grid;
  gap: 18px;
}

.course-card,
.panel {
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

.course-header:focus-visible,
.lesson-row:focus-visible {
  outline: 2px solid #94d4ff;
  outline-offset: 2px;
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
  grid-template-columns: minmax(110px, 180px) minmax(220px, 1fr) 112px;
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

.report-content {
  display: grid;
  gap: 22px;
  margin-top: 12px;
  padding-top: 18px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px;
}

.report-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 22px;
}

@media (min-width: 1200px) {
  .report-grid {
    grid-template-columns: 1fr 1fr;
  }

  .app-ranking-panel {
    grid-column: 1 / -1;
  }
}

.panel-title {
  min-height: 74px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 0 24px;
  border-bottom: 1px solid #d5e5f2;
}

h2 {
  margin: 0;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.report-table {
  --el-table-header-text-color: #12355b;
  --el-table-text-color: #47617f;
  --el-table-border-color: #e5eef6;
  --el-table-header-bg-color: #fbfdff;
}

.app-panel {
  padding: 26px 24px;
}

.usage-list {
  display: grid;
  gap: 18px;
  margin-top: 22px;
}

.usage-item {
  display: grid;
  grid-template-columns: 86px minmax(0, 1fr) 54px;
  align-items: center;
  gap: 20px;
}

.usage-name {
  color: #516987;
}

.usage-track {
  height: 10px;
  overflow: hidden;
  border-radius: 999px;
  background: #e2edf5;
}

.usage-track i {
  display: block;
  height: 100%;
  border-radius: inherit;
}

.usage-item strong {
  color: #516987;
}

.empty-report {
  padding: 28px;
}

.empty-report p {
  margin: 10px 0 0;
  color: #5f7894;
}

.app-ranking-panel {
  padding: 26px 24px;
}

.app-ranking-panel .panel-subtitle {
  margin: 6px 0 16px;
  color: #5f7894;
  font-size: 14px;
}

.ranking-table {
  --el-table-header-bg-color: #fbfdff;
  --el-table-header-text-color: #12355b;
  --el-table-text-color: #47617f;
}

.panel-body {
  padding: 20px 24px;
}

.student-collapse-title {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
}

.student-name {
  font-weight: 800;
  color: #12355b;
}

.student-no {
  color: #5f7894;
  font-size: 13px;
}

.app-detail-table {
  margin-top: 4px;
  --el-table-header-bg-color: #fbfdff;
}

.no-apps-text {
  padding: 12px 0;
  margin: 0;
  color: #9ca3af;
  font-size: 14px;
}

@media (max-width: 1100px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
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

@media (max-width: 560px) {
  .summary-grid {
    grid-template-columns: 1fr;
  }
}
</style>
