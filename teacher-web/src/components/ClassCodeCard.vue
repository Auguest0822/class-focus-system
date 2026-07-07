<script setup>
defineProps({
  code: {
    type: String,
    default: '',
  },
  hint: {
    type: String,
    default: '学生输入课堂码加入',
  },
})
</script>

<template>
  <section class="code-card">
    <strong>{{ code || '待生成' }}</strong>
    <span>{{ hint }}</span>
  </section>
</template>

<style scoped>
.code-card {
  min-height: 186px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 18px;
  padding: 28px;
  border: 1px solid #bfe4ee;
  border-radius: 18px;
  background: linear-gradient(135deg, #eaf7ff 0%, #e8fbf2 100%);
}

strong {
  color: #12355b;
  font-size: 62px;
  line-height: 1;
  letter-spacing: 6px;
}

span {
  color: #5f7894;
  font-size: 14px;
}

@media (max-width: 520px) {
  strong {
    font-size: 42px;
    letter-spacing: 4px;
  }
}
</style>
