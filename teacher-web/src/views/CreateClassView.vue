<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useRouter } from 'vue-router'
import { createClass, getClasses } from '@/api/classApi'
import ClassCodeCard from '@/components/ClassCodeCard.vue'
import TimeTemplateCard from '@/components/TimeTemplateCard.vue'
import TopBar from '@/components/TopBar.vue'

const router = useRouter()
const loading = ref(false)
const coursesLoading = ref(false)
const generatedCode = ref('')
const historyClasses = ref([])

const form = reactive({
  courseNo: '',
  courseName: '',
  className: '',
  startTime: '',
  focusOne: 45,
  breakTime: 5,
  focusTwo: 45,
})

const range = (start, end) =>
  Array.from({ length: Math.max(end - start + 1, 0) }, (_, index) => start + index)

const parseLessonNumber = (lessonName = '') => {
  const match = lessonName.toString().match(/第\s*(\d+)\s*次课|(\d+)/)
  return Number(match?.[1] || match?.[2] || 0)
}

const parseDateTimeText = (value) => {
  if (!value) return null

  const match = value.toString().match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/)
  if (!match) return null

  const [, year, month, day, hour, minute] = match
  return new Date(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), 0, 0)
}

const toNativeDate = (value) => {
  if (!value) return null
  if (value instanceof Date) return value
  if (typeof value.toDate === 'function') return value.toDate()

  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

const isSameDate = (left, right) =>
  left &&
  right &&
  left.getFullYear() === right.getFullYear() &&
  left.getMonth() === right.getMonth() &&
  left.getDate() === right.getDate()

const isBeforeToday = (date) => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return date.getTime() < today.getTime()
}

const disabledStartDate = (date) => isBeforeToday(date)

const disabledStartHours = (_role, comparingDate) => {
  const selectedDate = toNativeDate(comparingDate)
  const now = new Date()

  if (!isSameDate(selectedDate, now)) return []

  return range(0, now.getHours() - 1)
}

const disabledStartMinutes = (hour, _role, comparingDate) => {
  const selectedDate = toNativeDate(comparingDate)
  const now = new Date()

  if (!isSameDate(selectedDate, now) || hour !== now.getHours()) return []

  return range(0, now.getMinutes())
}

const disabledStartSeconds = (hour, minute, _role, comparingDate) => {
  const selectedDate = toNativeDate(comparingDate)
  const now = new Date()

  if (!isSameDate(selectedDate, now) || hour !== now.getHours() || minute !== now.getMinutes()) return []

  return range(0, now.getSeconds())
}

const isValidFutureStartTime = () => {
  const startTime = parseDateTimeText(form.startTime)
  return !startTime || startTime.getTime() > Date.now()
}

const handleStartTimeChange = () => {
  if (isValidFutureStartTime()) return

  form.startTime = ''
  ElMessage.warning('开课时间不能早于当前时间')
}

const getNextLessonName = (lessons = []) => {
  const maxLessonNo = lessons.reduce((max, item) => Math.max(max, parseLessonNumber(item.className)), 0)
  return `第 ${maxLessonNo + 1} 次课`
}

const courseOptions = computed(() => {
  const courseMap = historyClasses.value.reduce((map, item) => {
    const courseNo = item.courseNo || ''
    const courseName = item.courseName || ''
    const key = courseNo || courseName

    if (!key) return map

    if (!map.has(key)) {
      map.set(key, {
        value: courseNo,
        courseNo,
        courseName,
        lessons: [],
      })
    }

    map.get(key).lessons.push(item)
    return map
  }, new Map())

  return Array.from(courseMap.values()).map((item) => ({
    ...item,
    nextClassName: getNextLessonName(item.lessons),
  }))
})

const queryCourseNoSuggestions = (query, callback) => {
  const keyword = query.trim().toLowerCase()
  const suggestions = keyword
    ? courseOptions.value.filter((item) => {
        const courseNo = item.courseNo.toLowerCase()
        const courseName = item.courseName.toLowerCase()
        return courseNo.includes(keyword) || courseName.includes(keyword)
      })
    : courseOptions.value

  callback(suggestions)
}

const handleCourseNoSelect = (item) => {
  form.courseNo = item.courseNo
  form.courseName = item.courseName
  form.className = item.nextClassName
}

const loadCourseHistory = async () => {
  coursesLoading.value = true
  try {
    historyClasses.value = await getClasses()
  } catch (error) {
    historyClasses.value = []
    console.error('Failed to load course history:', error)
  } finally {
    coursesLoading.value = false
  }
}

const handleClassNameBlur = () => {
  const value = (form.className || '').trim()
  if (value && /^\d+$/.test(value)) {
    form.className = `第 ${value} 次课`
  }
}

const handleCreate = async () => {
  if (!isValidFutureStartTime()) {
    ElMessage.warning('开课时间不能早于当前时间')
    return
  }

  if (!form.courseNo.trim()) {
    ElMessage.warning('请输入课号')
    return
  }

  if (!form.courseName.trim()) {
    ElMessage.warning('请输入课程名称')
    return
  }

  loading.value = true
  try {
    const created = await createClass(form)
    generatedCode.value = created.code
    ElMessage.success('课堂创建成功')
    router.push(`/class-detail/${created.id || created.code}`)
  } catch (error) {
    ElMessage.error(error.message || '创建失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

onMounted(loadCourseHistory)
</script>

<template>
  <TopBar />

  <div class="create-grid">
    <section class="panel form-panel">
      <h2>基础信息</h2>
      <el-form label-position="top" :model="form">
        <el-row :gutter="18">
          <el-col :span="8">
            <el-form-item label="课号">
              <el-autocomplete
                v-model="form.courseNo"
                :fetch-suggestions="queryCourseNoSuggestions"
                :trigger-on-focus="true"
                :loading="coursesLoading"
                clearable
                size="large"
                placeholder="输入或选择课号"
                @select="handleCourseNoSelect"
              >
                <template #default="{ item }">
                  <div class="course-option">
                    <span class="course-option__no">{{ item.courseNo }}</span>
                    <span class="course-option__name">{{ item.courseName }}</span>
                    <span class="course-option__lesson">{{ item.nextClassName }}</span>
                  </div>
                </template>
              </el-autocomplete>
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="课程名称">
              <el-input v-model="form.courseName" size="large" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="课次">
              <el-input v-model="form.className" size="large" @blur="handleClassNameBlur" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="开课时间">
              <el-date-picker
                v-model="form.startTime"
                type="datetime"
                format="YYYY-MM-DD HH:mm"
                value-format="YYYY-MM-DD HH:mm"
                placeholder="选择开课时间"
                :disabled-date="disabledStartDate"
                :disabled-hours="disabledStartHours"
                :disabled-minutes="disabledStartMinutes"
                :disabled-seconds="disabledStartSeconds"
                size="large"
                @change="handleStartTimeChange"
              />
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>

      <TimeTemplateCard :model="form" />

      <div class="form-actions">
        <el-button type="primary" size="large" :loading="loading" @click="handleCreate">创建课堂</el-button>
        <el-button size="large" @click="router.back()">返回</el-button>
      </div>
    </section>

    <aside class="panel preview-panel">
      <h2>课堂预览</h2>
      <div class="chips">
        <span>专注 {{ form.focusOne }}</span>
        <span class="break">休息 {{ form.breakTime }}</span>
        <span>专注 {{ form.focusTwo }}</span>
      </div>
      <ClassCodeCard :code="generatedCode" hint="创建成功后展示课堂码" />
      <dl class="preview-list">
        <div>
          <dt>课程批次</dt>
          <dd>{{ form.courseNo }}</dd>
        </div>
        <div>
          <dt>课堂</dt>
          <dd>{{ form.courseName }} {{ form.className }}</dd>
        </div>
        <div>
          <dt>课堂时间</dt>
          <dd>{{ form.startTime || '待设置' }}</dd>
        </div>
        <div>
          <dt>总时长</dt>
          <dd>{{ form.focusOne + form.breakTime + form.focusTwo }} 分钟</dd>
        </div>
      </dl>
      <p>结束时间由开课时间和课堂时长自动计算，学生使用本次课堂码加入。</p>
    </aside>
  </div>
</template>

<style scoped>
.create-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 390px;
  gap: 26px;
}

.panel {
  border: 1px solid #d5e5f2;
  border-radius: 20px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
}

.form-panel {
  padding: 28px 28px 24px;
}

.preview-panel {
  padding: 28px;
}

h2 {
  margin: 0 0 18px;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.chips {
  display: grid;
  grid-template-columns: 1fr 72px 1fr;
  gap: 12px;
  margin-bottom: 22px;
}

.chips span {
  display: grid;
  place-items: center;
  min-height: 64px;
  border-radius: 14px;
  color: #2563eb;
  background: #e8f6ff;
  font-weight: 800;
}

.chips .break {
  color: #f97316;
  background: #fff3e6;
}

.preview-panel p {
  margin: 22px 0 0;
  color: #516987;
  line-height: 1.7;
}

.preview-list {
  display: grid;
  gap: 16px;
  margin: 22px 0 0;
}

.preview-list div {
  display: flex;
  justify-content: space-between;
  gap: 18px;
}

.preview-list dt {
  color: #516987;
}

.preview-list dd {
  margin: 0;
  color: #052b55;
  font-weight: 800;
  text-align: right;
}

.form-actions {
  display: flex;
  gap: 12px;
  margin-top: 34px;
}

:deep(.el-autocomplete),
:deep(.el-date-editor.el-input) {
  width: 100%;
}

.course-option {
  display: grid;
  grid-template-columns: 82px minmax(0, 1fr) auto;
  align-items: center;
  gap: 12px;
  width: 100%;
}

.course-option__no {
  color: #052b55;
  font-weight: 800;
}

.course-option__name {
  overflow: hidden;
  color: #516987;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.course-option__lesson {
  color: #2563eb;
  font-size: 13px;
}

@media (max-width: 1060px) {
  .create-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 760px) {
  :deep(.el-col) {
    max-width: 100%;
    flex: 0 0 100%;
  }

  .form-panel,
  .preview-panel {
    padding: 22px;
  }
}
</style>
