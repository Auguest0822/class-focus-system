<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getClassDetail } from '@/api/classApi'
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

onMounted(async () => {
  const data = await getClassDetail(route.params.id)
  classInfo.value = data.classInfo
  courses.value = data.courses
  expandedCourseNo.value = data.classInfo.courseNo
  selectedLessonId.value = data.classInfo.id
  students.value = data.students
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

const tagType = (status) => {
  if (status === 'running') return 'primary'
  if (status === 'ended') return 'success'
  return 'info'
}
</script>

<template>
  <TopBar>
    <template #actions>
      <el-button
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
                <dd>{{ selectedLesson.joinedCount }} 人</dd>
              </div>
              <div>
                <dt>课堂状态</dt>
                <dd>{{ selectedLesson.statusText }}</dd>
              </div>
            </dl>
          </section>

          <section class="students-panel">
            <div class="panel-title">
              <h2>学生加入情况</h2>
              <el-tag type="primary" effect="light" round>{{ selectedLesson.joinedCount || 0 }} 人已加入</el-tag>
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
