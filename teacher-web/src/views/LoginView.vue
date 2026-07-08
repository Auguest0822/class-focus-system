<script setup>
import { reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useRouter } from 'vue-router'
import { login, register } from '@/api/userApi'

const router = useRouter()
const loginLoading = ref(false)
const registerLoading = ref(false)
const isRegisterMode = ref(false)

const loginForm = reactive({
  username: '',
  password: '',
})

const registerForm = reactive({
  name: '',
  username: '',
  password: '',
  confirmPassword: '',
})

const validateRegisterForm = () => {
  if (!registerForm.name.trim()) {
    ElMessage.warning('请输入老师姓名')
    return false
  }

  if (!registerForm.username.trim()) {
    ElMessage.warning('请输入账号')
    return false
  }

  if (!registerForm.password) {
    ElMessage.warning('请输入密码')
    return false
  }

  if (registerForm.password !== registerForm.confirmPassword) {
    ElMessage.warning('两次输入的密码不一致')
    return false
  }

  return true
}

const handleLogin = async () => {
  loginLoading.value = true

  try {
    await login(loginForm)
    router.push('/dashboard')
  } finally {
    loginLoading.value = false
  }
}

const handleRegister = async () => {
  if (!validateRegisterForm()) return

  registerLoading.value = true

  try {
    await register(registerForm)
    await login({
      username: registerForm.username,
      password: registerForm.password,
    })
    ElMessage.success('注册成功')
    router.push('/dashboard')
  } finally {
    registerLoading.value = false
  }
}
</script>

<template>
  <main class="login-page">
    <section class="intro-panel">
      <p class="eyebrow">Teacher Web Console</p>
      <h1>课堂专注<br />管理系统</h1>
      <p class="intro-text">
        面向大学课堂的手机使用统计与专注管理工具，帮助老师创建课堂、查看学生加入情况和课堂报告。
      </p>

      <div class="visual-card" aria-hidden="true">
        <div class="chart-box">
          <div class="donut"></div>
          <span class="bar teal"></span>
          <span class="bar green"></span>
        </div>
        <div class="metric-box">
          <span class="mini-bar blue"></span>
          <span class="mini-bar teal"></span>
          <span class="mini-bar green"></span>
          <strong>86%</strong>
          <small>班级平均专注率</small>
        </div>
      </div>
    </section>

    <section class="login-card">
      <h2>{{ isRegisterMode ? '老师注册' : '老师登录' }}</h2>
      <p>
        {{ isRegisterMode ? '创建老师账号后，即可进入后台创建课堂。' : '进入老师端后台，创建课堂并查看专注报告。' }}
      </p>

      <el-form v-if="!isRegisterMode" label-position="top" :model="loginForm" @submit.prevent>
        <el-form-item label="账号">
          <el-input v-model="loginForm.username" size="large" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="loginForm.password" size="large" type="password" show-password />
        </el-form-item>
        <el-button class="login-button" type="primary" size="large" :loading="loginLoading" @click="handleLogin">
          登录系统
        </el-button>
      </el-form>

      <el-form v-else label-position="top" :model="registerForm" @submit.prevent>
        <el-form-item label="姓名">
          <el-input v-model="registerForm.name" size="large" />
        </el-form-item>
        <el-form-item label="账号">
          <el-input v-model="registerForm.username" size="large" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="registerForm.password" size="large" type="password" show-password />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="registerForm.confirmPassword" size="large" type="password" show-password />
        </el-form-item>
        <el-button class="login-button" type="primary" size="large" :loading="registerLoading" @click="handleRegister">
          注册并登录
        </el-button>
      </el-form>

      <el-button class="mode-button" link type="primary" @click="isRegisterMode = !isRegisterMode">
        {{ isRegisterMode ? '已有账号，去登录' : '没有账号，注册老师账号' }}
      </el-button>
    </section>
  </main>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) 430px;
  align-items: center;
  gap: 70px;
  padding: 70px 100px;
  background: #f4f8fb;
}

.eyebrow {
  margin: 0 0 18px;
  color: #00aeca;
  font-size: 18px;
  font-weight: 800;
}

h1 {
  margin: 0;
  color: #12355b;
  font-size: 58px;
  line-height: 1.02;
  letter-spacing: 0;
}

.intro-text {
  max-width: 640px;
  margin: 24px 0 56px;
  color: #5f7894;
  font-size: 24px;
  line-height: 1.7;
}

.visual-card {
  position: relative;
  width: 720px;
  max-width: 100%;
  min-height: 258px;
  border: 1px solid #cbe7f3;
  border-radius: 22px;
  background: linear-gradient(120deg, #eaf7ff, #effcf5);
  box-shadow: 0 22px 48px rgba(18, 53, 91, 0.08);
}

.chart-box,
.metric-box {
  position: absolute;
  bottom: -15px;
  border: 1px solid #c8deee;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.82);
  box-shadow: 0 18px 38px rgba(18, 53, 91, 0.08);
}

.chart-box {
  left: 36px;
  width: 372px;
  height: 236px;
  padding: 25px;
}

.metric-box {
  right: 36px;
  width: 250px;
  height: 236px;
  padding: 38px 25px;
}

.donut {
  width: 116px;
  height: 116px;
  margin-bottom: 22px;
  border-radius: 50%;
  background: conic-gradient(#2563eb 0 14%, #08b5c8 14% 40%, #d8ebf5 40% 100%);
}

.donut::after {
  content: '';
  display: block;
  width: 88px;
  height: 88px;
  margin: 14px;
  border-radius: 50%;
  background: #ffffff;
}

.bar,
.mini-bar {
  display: block;
  height: 10px;
  border-radius: 999px;
  background: #dceaf3;
}

.bar {
  margin-top: 14px;
}

.bar.teal {
  width: 90%;
  background: linear-gradient(90deg, #08b5c8 72%, #dceaf3 72%);
}

.bar.green {
  width: 90%;
  background: linear-gradient(90deg, #12b981 44%, #dceaf3 44%);
}

.mini-bar {
  margin-bottom: 14px;
}

.mini-bar.blue {
  width: 86%;
  background: linear-gradient(90deg, #2563eb 84%, #dceaf3 84%);
}

.mini-bar.teal {
  width: 80%;
  background: linear-gradient(90deg, #08b5c8 64%, #dceaf3 64%);
}

.mini-bar.green {
  width: 72%;
  background: linear-gradient(90deg, #12b981 55%, #dceaf3 55%);
}

.metric-box strong {
  display: block;
  margin-top: 36px;
  color: #12355b;
  font-size: 34px;
  letter-spacing: 0;
}

.metric-box small {
  color: #5f7894;
}

.login-card {
  padding: 42px 40px 34px;
  border: 1px solid #d5e5f2;
  border-radius: 22px;
  background: #ffffff;
  box-shadow: 0 26px 56px rgba(18, 53, 91, 0.1);
}

h2 {
  margin: 0;
  color: #12355b;
  font-size: 30px;
}

.login-card p {
  margin: 14px 0 28px;
  color: #5f7894;
}

.login-button {
  width: 100%;
  margin-top: 4px;
  font-weight: 800;
}

.mode-button {
  width: 100%;
  margin-top: 18px;
  font-weight: 800;
}

@media (max-width: 1060px) {
  .login-page {
    grid-template-columns: 1fr;
    padding: 44px 24px;
  }

  .login-card {
    max-width: 460px;
  }
}
</style>
