<script setup>
defineProps({
  students: {
    type: Array,
    default: () => [],
  },
})
</script>

<template>
  <el-table :data="students" class="student-table">
    <el-table-column prop="id" label="学号" min-width="132" />
    <el-table-column prop="name" label="姓名" min-width="90" />
    <el-table-column prop="joinTime" label="加入时间" min-width="110" />
    <el-table-column prop="focusRate" label="专注率" min-width="100" />
    <el-table-column label="操作" min-width="110">
      <template #default>
        <el-button link type="primary">个人记录</el-button>
      </template>
    </el-table-column>
  </el-table>
</template>

<style scoped>
.student-table {
  --el-table-header-text-color: #12355b;
  --el-table-text-color: #47617f;
  --el-table-border-color: #e5eef6;
  --el-table-header-bg-color: #fbfdff;
}
</style>
