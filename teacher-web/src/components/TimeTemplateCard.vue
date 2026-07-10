<script setup>
defineProps({
  model: {
    type: Object,
    required: true,
  },
})
</script>

<template>
  <section>
    <h3>课堂时长设置</h3>
    <el-row :gutter="18" class="time-form">
      <el-col :span="8">
        <label>第一专注段</label>
        <el-input-number v-model="model.focusOne" :min="10" :max="120" controls-position="right" />
      </el-col>
      <el-col :span="8">
        <label>休息时间</label>
        <el-input-number v-model="model.breakTime" :min="0" :max="30" controls-position="right" />
      </el-col>
      <el-col :span="8">
        <label>第二专注段</label>
        <el-input-number v-model="model.focusTwo" :min="10" :max="120" controls-position="right" />
      </el-col>
    </el-row>
  </section>
</template>

<style scoped>
h3 {
  margin: 20px 0 16px;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.time-form {
  margin-top: 18px;
}

label {
  display: block;
  margin: 0 0 8px;
  color: #12355b;
  font-weight: 700;
}

:deep(.el-input-number) {
  width: 100%;
}

</style>
