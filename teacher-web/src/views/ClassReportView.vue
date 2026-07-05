<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { getClassReport } from '@/api/classApi'
import ReportSummaryCard from '@/components/ReportSummaryCard.vue'
import SuggestionCard from '@/components/SuggestionCard.vue'
import TopBar from '@/components/TopBar.vue'

const route = useRoute()
const summary = ref([])
const studentStats = ref([])
const appUsage = ref([])
const suggestions = ref([])

onMounted(async () => {
  const data = await getClassReport(route.params.id)
  summary.value = data.summary
  studentStats.value = data.studentStats
  appUsage.value = data.appUsage
  suggestions.value = data.suggestions
})
</script>

<template>
  <TopBar>
    <template #actions>
      <el-button size="large">导出报告</el-button>
    </template>
  </TopBar>

  <section class="summary-grid">
    <ReportSummaryCard v-for="item in summary" :key="item.label" :value="item.value" :label="item.label" />
  </section>

  <div class="report-grid">
    <div class="left-stack">
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

    <aside class="panel suggestion-panel">
      <h2>课堂分析建议</h2>
      <SuggestionCard v-for="item in suggestions" :key="item.text" :suggestion="item" />
    </aside>
  </div>
</template>

<style scoped>
.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px;
  margin-bottom: 22px;
}

.report-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 328px;
  gap: 22px;
}

.left-stack {
  display: grid;
  gap: 22px;
}

.panel {
  overflow: hidden;
  border: 1px solid #d5e5f2;
  border-radius: 18px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
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

.app-panel,
.suggestion-panel {
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

.suggestion-panel {
  display: grid;
  align-content: start;
  gap: 16px;
}

@media (max-width: 1100px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .report-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 560px) {
  .summary-grid {
    grid-template-columns: 1fr;
  }
}
</style>
