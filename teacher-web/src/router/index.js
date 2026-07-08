import { createRouter, createWebHistory } from 'vue-router'

import TeacherLayout from '@/layouts/TeacherLayout.vue'
import LoginView from '@/views/LoginView.vue'
import DashboardView from '@/views/DashboardView.vue'
import CreateClassView from '@/views/CreateClassView.vue'
import ClassDetailView from '@/views/ClassDetailView.vue'
import ClassReportView from '@/views/ClassReportView.vue'

const routes = [
  {
    path: '/',
    redirect: '/dashboard',
  },
  {
    path: '/login',
    name: 'login',
    component: LoginView,
  },
  {
    path: '/',
    component: TeacherLayout,
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: DashboardView,
        meta: {
          title: '课堂列表',
          subtitle: '查看已创建课堂，快速进入详情或报告。',
        },
      },
      {
        path: 'create-class',
        name: 'create-class',
        component: CreateClassView,
        meta: {
          title: '创建课堂',
          subtitle: '设置课堂基础信息和课堂时长，生成课堂码。',
        },
      },
      {
        path: 'class-detail/:id?',
        name: 'class-detail',
        component: ClassDetailView,
        meta: {
          title: '课程详情',
          subtitle: '按课号查看课程下的历史课次与课堂数据。',
        },
      },
      {
        path: 'class-report/:id?',
        name: 'class-report',
        component: ClassReportView,
        meta: {
          title: '课堂报告',
          subtitle: '按课号选择具体课次，查看该次课堂的专注报告。',
        },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
