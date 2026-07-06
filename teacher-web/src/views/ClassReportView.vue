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
const appUsage = ref([])

onMounted(async () => {
  const data = await getClassReport(route.params.id)
  classInfo.value = data.classInfo
  courses.value = data.courses
  expandedCourseNo.value = data.classInfo.courseNo
  selectedLessonId.value = data.classInfo.id
  summary.value = data.summary
  studentStats.value = data.studentStats
  appUsage.value = data.appUsage
})

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
  selectedLessonId.value = lesson.id
}

const formatLessonTime = (lesson) => {
  if (!lesson.startTime || !lesson.endTime) return '未设置时间'
  const startDate = lesson.startTime.slice(0, 10)
  const endDate = lesson.endTime.slice(0, 10)
  const endTime = lesson.endTime.slice(11)

  if (startDate === endDate) {
    return `${lesson.startTime}-${endTime}`
  }
  return `${lesson.startTime}-${lesson.endTime}`
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
                <el-table :data="studentStats" class="report-table">
                  <el-table-column prop="name" label="学生" min-width="110" />
                  <el-table-column label="专注时长" min-width="140">
                    <template #default="{ row }">{{ row.focusMinutes }} 分钟</template>
                  </el-table-column>
                  <el-table-column label="分心时长" min-width="140">
                    <template #default="{ row }">{{ row.distractMinutes }} 分钟</template>
                  </el-table-column>
                  <el-table-column prop="focusRate" label="专注率" min-width="120" />
                  <el-table-column prop="mainDistractType" label="主要分心类型" min-width="150" />
                </el-table>
              </section>

              <section class="panel app-panel">
                <h2>App 类型使用概览</h2>
                <div class="usage-list">
                  <div v-for="item in appUsage" :key="item.name" class="usage-item">
                    <span class="usage-name">{{ item.name }}</span>
                    <div class="usage-track">
                      <i :style="{ width: `${item.percent}%`, background: item.color }"></i>
                    </div>
                    <strong>{{ item.percent }}%</strong>
                  </div>
                </div>
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
