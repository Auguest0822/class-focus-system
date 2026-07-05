<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getClassDetail } from '@/api/classApi'
import ClassCodeCard from '@/components/ClassCodeCard.vue'
import StudentTable from '@/components/StudentTable.vue'
import TopBar from '@/components/TopBar.vue'

const route = useRoute()
const router = useRouter()
const classInfo = ref({})
const students = ref([])

onMounted(async () => {
  const data = await getClassDetail(route.params.id)
  classInfo.value = data.classInfo
  students.value = data.students
})
</script>

<template>
  <TopBar>
    <template #actions>
      <el-button type="primary" size="large" @click="router.push(`/class-report/${classInfo.id || 'PY2025'}`)">
        查看报告
      </el-button>
    </template>
  </TopBar>

  <div class="detail-grid">
    <section class="panel info-panel">
      <h2>课堂信息</h2>
      <ClassCodeCard :code="classInfo.code" />

      <dl class="info-list">
        <div>
          <dt>课程名称</dt>
          <dd>{{ classInfo.courseName }}</dd>
        </div>
        <div>
          <dt>课堂名称</dt>
          <dd>{{ classInfo.className }}</dd>
        </div>
        <div>
          <dt>课堂时长</dt>
          <dd>{{ classInfo.duration }}</dd>
        </div>
        <div>
          <dt>课堂状态</dt>
          <dd>{{ classInfo.statusText }}</dd>
        </div>
        <div>
          <dt>加入人数</dt>
          <dd>{{ classInfo.joinedCount }} 人</dd>
        </div>
      </dl>
    </section>

    <section class="panel students-panel">
      <div class="panel-title">
        <h2>学生加入情况</h2>
        <el-tag type="primary" effect="light" round>{{ classInfo.joinedCount || 36 }} 人已加入</el-tag>
      </div>
      <StudentTable :students="students" />
    </section>
  </div>
</template>

<style scoped>
.detail-grid {
  display: grid;
  grid-template-columns: 380px minmax(0, 1fr);
  gap: 24px;
}

.panel {
  overflow: hidden;
  border: 1px solid #d5e5f2;
  border-radius: 18px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
}

.info-panel {
  padding: 28px;
}

.students-panel {
  padding-top: 20px;
}

.panel-title {
  min-height: 52px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 0 24px 12px;
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
  .detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>
