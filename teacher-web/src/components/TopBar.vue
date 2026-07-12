<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useRoute, useRouter } from 'vue-router'
import { getCurrentTeacher } from '@/api/userApi'
import request from '@/api/request'

const route = useRoute()
const router = useRouter()
const profileVisible = ref(false)
const uploading = ref(false)
const saving = ref(false)

const teacher = ref({ name: '', nickname: '', avatarUrl: null })

const apiBase = import.meta.env.VITE_API_BASE_URL || '/api'
const baseUrl = apiBase.endsWith('/api') ? apiBase.slice(0, -4) : apiBase

const resolveAvatarUrl = (raw) => {
  if (!raw) return null
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw
  return `${baseUrl}/api/auth/avatar-file/${raw}`
}

const displayName = computed(() =>
  (teacher.value.nickname && teacher.value.nickname !== '')
    ? teacher.value.nickname
    : teacher.value.name || '老师'
)

const profileForm = reactive({ nickname: '' })

const title = computed(() => route.meta.title || '课堂专注管理系统')
const subtitle = computed(() => route.meta.subtitle || 'Teacher Web Console')

const loadTeacher = async () => {
  try {
    const data = await getCurrentTeacher()
    teacher.value = {
      name: data.name || '',
      nickname: data.nickname || '',
      avatarUrl: data.avatar_url || null,
    }
  } catch { /* 静默 */ }
}

const openProfileDialog = () => {
  profileForm.nickname = teacher.value.nickname || ''
  profileVisible.value = true
}

const handleAvatarUpload = async (e) => {
  const file = e.target?.files?.[0] || e.raw
  if (!file) return
  uploading.value = true
  try {
    const form = new FormData()
    form.append('file', file)
    const data = await request.post('/auth/avatar', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    teacher.value.avatarUrl = data.avatar_url || null
    ElMessage.success('头像已更新')
  } catch (err) {
    ElMessage.error(err.message || '上传失败')
  } finally {
    uploading.value = false
  }
}

const saveProfile = async () => {
  saving.value = true
  try {
    const data = await request.put('/auth/profile', {
      nickname: profileForm.nickname.trim() || null,
    })
    teacher.value.nickname = data.nickname || ''
    teacher.value.avatarUrl = data.avatar_url || null
    profileVisible.value = false
    ElMessage.success('资料已更新')
  } catch (err) {
    ElMessage.error(err.message || '保存失败')
  } finally {
    saving.value = false
  }
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

onMounted(loadTeacher)
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
          <el-avatar
            :size="38"
            :src="resolveAvatarUrl(teacher.avatarUrl)"
            class="teacher-avatar"
          >
            {{ (teacher.nickname || teacher.name || '师').charAt(0) }}
          </el-avatar>
          <span>{{ displayName }}</span>
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

  <!-- ── 修改资料弹窗 ── -->
  <el-dialog v-model="profileVisible" width="420px" class="profile-dialog" title="修改资料" :close-on-click-modal="false">
    <div class="profile-editor">
      <div class="avatar-wrap">
        <el-avatar :size="72" :src="resolveAvatarUrl(teacher.avatarUrl)" class="profile-avatar">
          {{ (teacher.nickname || teacher.name || '师').charAt(0) }}
        </el-avatar>
        <label class="avatar-upload-mask" :class="{ disabled: uploading }">
          {{ uploading ? '...' : '换' }}
          <input type="file" accept="image/*" hidden @change="handleAvatarUpload" :disabled="uploading" />
        </label>
      </div>
      <div class="profile-copy">
        <strong>{{ teacher.name }}</strong>
        <span class="profile-hint">点击头像更换图片，支持 jpg/png/gif</span>
      </div>
    </div>

    <el-form label-position="top" :model="profileForm">
      <el-form-item label="昵称">
        <el-input v-model="profileForm.nickname" size="large" maxlength="20" placeholder="留空则显示真实姓名" />
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button size="large" @click="profileVisible = false">取消</el-button>
      <el-button type="primary" size="large" :loading="saving" @click="saveProfile">保存</el-button>
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
  gap: 8px;
  min-height: 46px;
  padding: 0 10px 0 4px;
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

.teacher-avatar {
  flex-shrink: 0;
}

.caret {
  color: #7e91a8;
  font-size: 16px;
  line-height: 1;
}

/* ── 弹窗 ── */
.profile-editor {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 18px;
  margin-bottom: 20px;
  border: 1px solid #d5e5f2;
  border-radius: 16px;
  background: #f4f8fb;
}

.avatar-wrap {
  position: relative;
  flex-shrink: 0;
}

.profile-avatar {
  flex-shrink: 0;
}

.avatar-upload-mask {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.45);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
  opacity: 0;
  cursor: pointer;
  transition: opacity 0.15s;
}

.avatar-wrap:hover .avatar-upload-mask {
  opacity: 1;
}

.avatar-upload-mask.disabled {
  opacity: 1;
  cursor: default;
}

.profile-copy strong {
  display: block;
  color: #12355b;
  font-size: 18px;
}

.profile-hint {
  display: block;
  margin-top: 4px;
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
