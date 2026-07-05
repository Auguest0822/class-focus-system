<script setup>
const props = defineProps({
  model: {
    type: Object,
    required: true,
  },
})

const useDefault = () => {
  props.model.template = 'default'
  props.model.focusOne = 50
  props.model.breakTime = 5
  props.model.focusTwo = 40
}

const useCustom = () => {
  props.model.template = 'custom'
}
</script>

<template>
  <section>
    <h3>课堂时长设置</h3>
    <div class="template-grid">
      <button
        type="button"
        class="template-option"
        :class="{ active: model.template === 'default' }"
        @click="useDefault"
      >
        <strong>默认模板</strong>
        <span>50 + 5 + 40</span>
      </button>
      <button
        type="button"
        class="template-option"
        :class="{ active: model.template === 'custom' }"
        @click="useCustom"
      >
        <strong>自定义时长</strong>
        <span>按课程实际设置</span>
      </button>
    </div>

    <el-row :gutter="18" class="time-form">
      <el-col :span="12">
        <label>第一专注段</label>
        <el-input-number v-model="model.focusOne" :min="10" :max="120" controls-position="right" />
      </el-col>
      <el-col :span="12">
        <label>休息时间</label>
        <el-input-number v-model="model.breakTime" :min="0" :max="30" controls-position="right" />
      </el-col>
      <el-col :span="12">
        <label>第二专注段</label>
        <el-input-number v-model="model.focusTwo" :min="10" :max="120" controls-position="right" />
      </el-col>
    </el-row>
  </section>
</template>

<style scoped>
h3 {
  margin: 34px 0 16px;
  color: #12355b;
  font-size: 24px;
  letter-spacing: 0;
}

.template-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.template-option {
  min-height: 72px;
  padding: 16px 18px;
  text-align: left;
  border: 1px solid #d5e5f2;
  border-radius: 12px;
  background: #ffffff;
  color: #12355b;
  cursor: pointer;
}

.template-option.active {
  border-color: #94d4ff;
  background: #e8f6ff;
}

.template-option strong,
.template-option span {
  display: block;
  font-size: 16px;
}

.template-option span {
  margin-top: 4px;
  color: #2563eb;
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

@media (max-width: 700px) {
  .template-grid {
    grid-template-columns: 1fr;
  }
}
</style>
