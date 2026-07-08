<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useRoute, useRouter } from 'vue-router'
import { getCurrentTeacher } from '@/api/userApi'

const route = useRoute()
const router = useRouter()
const profileVisible = ref(false)
const teacher = ref({
  name: '张老师',
  avatarText: '张',
})
const profileForm = reactive({
  name: '',
})

const title = computed(() => route.meta.title || '课堂专注管理系统')
const subtitle = computed(() => route.meta.subtitle || 'Teacher Web Console')
const previewAvatarText = computed(() => profileForm.name.trim().slice(0, 1) || teacher.value.avatarText || '师')

const syncProfileForm = () => {
  profileForm.name = teacher.value.name || ''
}

onMounted(async () => {
  teacher.value = await getCurrentTeacher()
  syncProfileForm()
})

const openProfileDialog = () => {
  syncProfileForm()
  profileVisible.value = true
}

const saveProfile = () => {
  const name = profileForm.name.trim()

  if (!name) {
    ElMessage.warning('请输入老师姓名')
    return
  }

  teacher.value = {
    ...teacher.value,
    name,
    avatarText: name.slice(0, 1),
  }
  profileVisible.value = false
  ElMessage.success('资料已更新')
}

const handleUserCommand = (command) => {
  if (command === 'profile') {
    openProfileDialog()
    return
  }

  if (command === 'logout') {
    localStorage.removeItem('teacher_token')
    router.push('/login')
  }
}
</script>

<template>
  <header class="topbar">
    <div>
      <h1>{{ title }}</h1>
      <p>{{ subtitle }}</p>
    </div>

    <div class="topbar-right">
      <slot name="actions"></slot>
      <el-dropdown trigger="click" popper-class="teacher-dropdown" @command="handleUserCommand">
        <button type="button" class="teacher">
          <span class="avatar">{{ teacher.avatarText }}</span>
          <span>{{ teacher.name }}</span>
          <span class="caret">⌄</span>
        </button>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="profile">修改资料</el-dropdown-item>
            <el-dropdown-item divided command="logout">退出登录</el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </header>

  <el-dialog v-model="profileVisible" width="420px" class="profile-dialog" title="修改资料">
    <div class="profile-editor">
      <div class="profile-avatar">{{ previewAvatarText }}</div>
      <div class="profile-copy">
        <strong>{{ profileForm.name || teacher.name }}</strong>
        <span>头像将根据姓名首字自动生成</span>
      </div>
    </div>

    <el-form label-position="top" :model="profileForm">
      <el-form-item label="姓名">
        <el-input v-model="profileForm.name" size="large" maxlength="20" />
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button size="large" @click="profileVisible = false">取消</el-button>
      <el-button type="primary" size="large" @click="saveProfile">保存</el-button>
    </template>
  </el-dialog>
</template>

<style scoped>
.topbar {
  max-width: 1120px;
  margin: 0 auto 22px;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 24px;
}

h1 {
  margin: 0;
  color: #12355b;
  font-size: 34px;
  line-height: 1.12;
  letter-spacing: 0;
}

p {
  margin: 10px 0 0;
  color: #5f7894;
  font-size: 16px;
}

.topbar-right {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 48px;
}

.teacher {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 48px;
  padding: 0 12px 0 6px;
  border: 1px solid transparent;
  border-radius: 14px;
  background: transparent;
  color: #48627d;
  font-size: 14px;
  white-space: nowrap;
  cursor: pointer;
}

.teacher:hover {
  border-color: #d5e5f2;
  background: #ffffff;
  box-shadow: 0 10px 22px rgba(18, 53, 91, 0.06);
}

.avatar,
.profile-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #12355b;
  background: #e8f6ff;
  font-weight: 800;
}

.avatar {
  width: 42px;
  height: 42px;
}

.caret {
  color: #7e91a8;
  font-size: 16px;
  line-height: 1;
}

.profile-editor {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 18px;
  margin-bottom: 20px;
  border: 1px solid #d5e5f2;
  border-radius: 16px;
  background: #f4f8fb;
}

.profile-avatar {
  width: 56px;
  height: 56px;
  flex: 0 0 auto;
  font-size: 20px;
}

.profile-copy {
  display: grid;
  gap: 6px;
}

.profile-copy strong {
  color: #12355b;
  font-size: 18px;
}

.profile-copy span {
  color: #5f7894;
  font-size: 13px;
}

:deep(.profile-dialog) {
  border-radius: 18px;
}

:deep(.profile-dialog .el-dialog__header) {
  padding: 24px 24px 12px;
}

:deep(.profile-dialog .el-dialog__title) {
  color: #12355b;
  font-size: 22px;
  font-weight: 800;
}

:deep(.profile-dialog .el-dialog__body) {
  padding: 8px 24px 6px;
}

:deep(.profile-dialog .el-dialog__footer) {
  padding: 10px 24px 24px;
}

@media (max-width: 720px) {
  .topbar {
    flex-direction: column;
  }

  h1 {
    font-size: 28px;
  }
}
</style>

<style>
.teacher-dropdown {
  border: 1px solid #d5e5f2;
  border-radius: 10px;
  box-shadow: 0 16px 36px rgba(18, 53, 91, 0.12);
}

.teacher-dropdown .el-dropdown-menu {
  padding: 6px;
}

.teacher-dropdown .el-dropdown-menu__item {
  min-width: 104px;
  border-radius: 8px;
  color: #12355b;
  font-weight: 700;
}

.teacher-dropdown .el-dropdown-menu__item:not(.is-disabled):focus,
.teacher-dropdown .el-dropdown-menu__item:not(.is-disabled):hover {
  color: #2563eb;
  background: #e8f6ff;
}
</style>
