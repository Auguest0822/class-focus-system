<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { getDashboard } from '@/api/classApi'
import ClassTable from '@/components/ClassTable.vue'
import StatCard from '@/components/StatCard.vue'
import TopBar from '@/components/TopBar.vue'

const router = useRouter()
const stats = ref([])
const classes = ref([])

onMounted(async () => {
  const data = await getDashboard()
  stats.value = data.stats
  classes.value = data.classes
})

const goDetail = (row) => router.push(`/class-detail/${row.id}`)
const goReport = (row) => router.push(`/class-report/${row.id}`)
</script>

<template>
  <TopBar>
    <template #actions>
      <el-button type="primary" size="large" @click="router.push('/create-class')">创建课堂</el-button>
    </template>
  </TopBar>

  <section class="stats-grid">
    <StatCard v-for="item in stats" :key="item.label" :value="item.value" :label="item.label" />
  </section>

  <ClassTable :classes="classes" @view-detail="goDetail" @view-report="goReport" />
</template>

<style scoped>
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px;
  margin-bottom: 22px;
}

@media (max-width: 1100px) {
  .stats-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
}
</style>
