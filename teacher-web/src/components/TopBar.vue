<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { teacher } from '@/mock/classData'

const route = useRoute()

const title = computed(() => route.meta.title || '课堂专注管理系统')
const subtitle = computed(() => route.meta.subtitle || 'Teacher Web Console')
</script>

<template>
  <header class="topbar">
    <div>
      <h1>{{ title }}</h1>
      <p>{{ subtitle }}</p>
    </div>

    <div class="topbar-right">
      <slot name="actions"></slot>
      <div class="teacher">
        <span class="avatar">{{ teacher.avatarText }}</span>
        <span>{{ teacher.name }}</span>
      </div>
    </div>
  </header>
</template>

<style scoped>
.topbar {
  max-width: 1120px;
  margin: 0 auto 22px;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 24px;
}

h1 {
  margin: 0;
  color: #12355b;
  font-size: 34px;
  line-height: 1.12;
  letter-spacing: 0;
}

p {
  margin: 10px 0 0;
  color: #5f7894;
  font-size: 16px;
}

.topbar-right {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 48px;
}

.teacher {
  display: flex;
  align-items: center;
  gap: 10px;
  color: #48627d;
  font-size: 14px;
  white-space: nowrap;
}

.avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border-radius: 50%;
  color: #12355b;
  background: #e8f6ff;
  font-weight: 800;
}

@media (max-width: 720px) {
  .topbar {
    flex-direction: column;
  }

  h1 {
    font-size: 28px;
  }
}
</style>
