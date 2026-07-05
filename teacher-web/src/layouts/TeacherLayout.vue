<script setup>
import SidebarMenu from '@/components/SidebarMenu.vue'
</script>

<template>
  <div class="teacher-layout">
    <SidebarMenu />
    <main class="layout-main">
      <section class="page-shell">
        <router-view />
      </section>
    </main>
  </div>
</template>

<style scoped>
.teacher-layout {
  min-height: 100vh;
  display: flex;
  background: #f4f8fb;
}

.layout-main {
  flex: 1;
  min-width: 0;
  padding: 34px 42px 54px;
}

.page-shell {
  max-width: 1120px;
  margin: 0 auto;
}

@media (max-width: 900px) {
  .teacher-layout {
    flex-direction: column;
  }

  .layout-main {
    padding: 24px 18px 40px;
  }
}
</style>
