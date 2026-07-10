<script setup>
import SidebarMenu from '@/components/SidebarMenu.vue'
</script>

<template>
  <div class="teacher-layout">
    <SidebarMenu />
    <main class="layout-main">
      <section class="page-shell">
        <router-view v-slot="{ Component, route: r }">
          <keep-alive>
            <component :is="Component" :key="r.name" />
          </keep-alive>
        </router-view>
      </section>
    </main>
  </div>
</template>

<style scoped>
.teacher-layout {
  height: 100vh;
  display: flex;
  overflow: hidden;
  background: #f4f8fb;
}

.layout-main {
  flex: 1;
  min-width: 0;
  height: 100vh;
  overflow-y: auto;
  padding: 34px 42px 54px;
}

.page-shell {
  max-width: 1120px;
  margin: 0 auto;
}

@media (max-width: 900px) {
  .teacher-layout {
    height: auto;
    min-height: 100vh;
    flex-direction: column;
    overflow: visible;
  }

  .layout-main {
    height: auto;
    overflow: visible;
    padding: 24px 18px 40px;
  }
}
</style>
