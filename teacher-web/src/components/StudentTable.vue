<script setup>
import { computed } from 'vue'

const props = defineProps({
  students: {
    type: Array,
    default: () => [],
  },
})

const apiBase = import.meta.env.VITE_API_BASE_URL || '/api'
const baseUrl = apiBase.endsWith('/api') ? apiBase.slice(0, -4) : apiBase

const resolveAvatarUrl = (raw) => {
  if (!raw) return null
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw
  return `${baseUrl}/api/auth/avatar-file/${raw}`
}

const displayName = (student) => {
  return (student.nickname && student.nickname !== '') ? student.nickname : student.name
}
</script>

<template>
  <el-table :data="students" class="student-table" row-class-name="student-row">
    <!-- 头像 -->
    <el-table-column label="" width="60" align="center">
      <template #default="{ row }">
        <el-avatar
          :size="36"
          :src="resolveAvatarUrl(row.avatarUrl)"
        >
          {{ (row.nickname || row.name || '学').charAt(0) }}
        </el-avatar>
      </template>
    </el-table-column>

    <!-- 姓名 -->
    <el-table-column label="姓名">
      <template #default="{ row }">
        <span class="student-name">{{ displayName(row) }}</span>
        <span v-if="row.nickname && row.nickname !== ''" class="student-real-name">
          {{ row.name }}
        </span>
      </template>
    </el-table-column>

    <!-- 学号 -->
    <el-table-column prop="id" label="学号" />

    <!-- 加入时间 -->
    <el-table-column prop="joinTime" label="加入时间" />
  </el-table>
</template>

<style scoped>
.student-table {
  --el-table-header-text-color: #12355b;
  --el-table-text-color: #47617f;
  --el-table-border-color: #e5eef6;
  --el-table-header-bg-color: #fbfdff;
}

.student-avatar {
  flex-shrink: 0;
}

.student-name {
  font-weight: 800;
  color: #12355b;
}

.student-real-name {
  margin-left: 8px;
  font-size: 12px;
  color: #94a3b8;
}
</style>
