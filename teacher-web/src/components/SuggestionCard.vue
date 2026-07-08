<script setup>
defineProps({
  suggestion: {
    type: Object,
    required: true,
  },
})
</script>

<template>
  <article class="suggestion-card" :class="suggestion.tone">
    {{ suggestion.text }}
  </article>
</template>

<style scoped>
.suggestion-card {
  padding: 22px 20px;
  border-radius: 16px;
  color: #12355b;
  line-height: 1.72;
  border: 1px solid #bfdef0;
  background: #e8f6ff;
}

.suggestion-card.success {
  border-color: #c5eadb;
  background: #e8fbf2;
}
</style>
