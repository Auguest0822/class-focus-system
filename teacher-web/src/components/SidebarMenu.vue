<script setup>
const menuItems = [
  { label: '课堂列表', path: '/dashboard' },
  { label: '创建课堂', path: '/create-class' },
  { label: '课堂详情', path: '/class-detail/PY2025' },
  { label: '课堂报告', path: '/class-report/PY2025' },
]
</script>

<template>
  <aside class="sidebar">
    <div class="brand">
      <strong>课堂专注<br />管理系统</strong>
      <span>Teacher Console</span>
    </div>

    <nav class="menu">
      <router-link v-for="item in menuItems" :key="item.path" :to="item.path" class="menu-item">
        <span class="dot"></span>
        <span>{{ item.label }}</span>
      </router-link>
    </nav>
  </aside>
</template>

<style scoped>
.sidebar {
  width: 236px;
  padding: 32px 22px;
  background: #ffffff;
  border-right: 1px solid #d5e5f2;
}

.brand strong {
  display: block;
  color: #12355b;
  font-size: 22px;
  line-height: 1.16;
  letter-spacing: 0;
}

.brand span {
  display: block;
  margin-top: 8px;
  color: #00aeca;
  font-size: 13px;
  font-weight: 700;
}

.menu {
  display: grid;
  gap: 12px;
  margin-top: 36px;
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 46px;
  padding: 0 14px;
  color: #53687f;
  border-radius: 8px;
  text-decoration: none;
  font-weight: 700;
}

.menu-item.router-link-active {
  color: #2563eb;
  background: #e6f4ff;
}

.dot {
  width: 10px;
  height: 10px;
  flex: 0 0 10px;
  border-radius: 50%;
  background: #728197;
}

.router-link-active .dot {
  background: #2563eb;
}

@media (max-width: 900px) {
  .sidebar {
    width: 100%;
    padding: 20px;
    border-right: 0;
    border-bottom: 1px solid #d5e5f2;
  }

  .menu {
    display: flex;
    gap: 10px;
    overflow-x: auto;
    margin-top: 18px;
  }

  .menu-item {
    white-space: nowrap;
  }
}
</style>
