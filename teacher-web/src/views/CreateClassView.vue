<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { createClass } from '@/api/classApi'
import ClassCodeCard from '@/components/ClassCodeCard.vue'
import TimeTemplateCard from '@/components/TimeTemplateCard.vue'
import TopBar from '@/components/TopBar.vue'

const router = useRouter()
const loading = ref(false)
const generatedCode = ref('')

const form = reactive({
  courseNo: '',
  courseName: '',
  className: '',
  startTime: '',
  mode: '默认模板',
  focusOne: 50,
  breakTime: 5,
  focusTwo: 40,
  template: 'default',
})

const handleCreate = async () => {
  loading.value = true
  const created = await createClass(form)
  generatedCode.value = created.code
  loading.value = false
  router.push(`/class-detail/${created.id}`)
}
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
              <el-input v-model="form.courseNo" size="large" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="课程名称">
              <el-input v-model="form.courseName" size="large" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="课次">
              <el-input v-model="form.className" size="large" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="开课时间">
              <el-input v-model="form.startTime" size="large" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="课堂模式">
              <el-select v-model="form.mode" size="large">
                <el-option label="默认模板" value="默认模板" />
                <el-option label="讨论课模板" value="讨论课模板" />
                <el-option label="实验课模板" value="实验课模板" />
              </el-select>
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
          <dd>待设置</dd>
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
