<script setup>
defineProps({
  classes: {
    type: Array,
    default: () => [],
  },
})

const emit = defineEmits(['view-detail', 'view-report'])

const tagType = (status) => {
  if (status === 'running') return 'primary'
  if (status === 'ended') return 'success'
  return 'info'
}
</script>

<template>
  <div class="table-card">
    <div class="table-card-header">
      <h2>最近课堂</h2>
      <el-button>刷新</el-button>
    </div>

    <el-table :data="classes" class="clean-table">
      <el-table-column prop="courseNo" label="课号" min-width="96" />
      <el-table-column prop="courseName" label="课程名称" min-width="126" />
      <el-table-column prop="className" label="课次" min-width="106" />
      <el-table-column prop="startTime" label="开课时间" min-width="154" />
      <el-table-column prop="code" label="课堂码" min-width="106" />
      <el-table-column prop="duration" label="课堂时长" min-width="126" />
      <el-table-column label="状态" min-width="92">
        <template #default="{ row }">
          <el-tag :type="tagType(row.status)" round effect="light">{{ row.statusText }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" min-width="150" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="emit('view-detail', row)">查看详情</el-button>
          <el-button v-if="row.status === 'ended'" link type="primary" @click="emit('view-report', row)">
            查看报告
          </el-button>
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>

<style scoped>
.table-card {
  overflow: hidden;
  border: 1px solid #d5e5f2;
  border-radius: 18px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
}

.table-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 86px;
  padding: 0 24px;
  border-bottom: 1px solid #d5e5f2;
}

h2 {
  margin: 0;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.clean-table {
  --el-table-header-text-color: #12355b;
  --el-table-text-color: #47617f;
  --el-table-border-color: #e5eef6;
  --el-table-header-bg-color: #fbfdff;
}
</style>
