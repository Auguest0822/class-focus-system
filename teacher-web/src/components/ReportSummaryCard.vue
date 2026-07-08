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
  <article class="summary-card">
    <strong>{{ value }}</strong>
    <span>{{ label }}</span>
  </article>
</template>

<style scoped>
.summary-card {
  min-height: 118px;
  padding: 26px 24px;
  border: 1px solid #d5e5f2;
  border-radius: 16px;
  background: #ffffff;
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
}
</style>
