<script setup>
defineProps({
  value: {
    type: [String, Number],
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
})
</script>

<template>
  <article class="stat-card">
    <strong>{{ value }}</strong>
    <span>{{ label }}</span>
  </article>
</template>

<style scoped>
.stat-card {
  min-height: 118px;
  padding: 26px 24px;
  border: 1px solid #d5e5f2;
  border-radius: 16px;
  background: #ffffff;
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.06);
}

strong {
  display: block;
  color: #12355b;
  font-size: 38px;
  line-height: 1;
  letter-spacing: 0;
}

span {
  display: block;
  margin-top: 14px;
  color: #516987;
  font-size: 14px;
}
</style>
