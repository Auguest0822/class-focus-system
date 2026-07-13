# 课堂专注管理系统

面向大学课堂的专注管理系统。学生端记录课堂期间的 App 使用情况，老师端查看课堂状态、学生使用记录和课堂报告，帮助师生了解课堂中的手机使用情况。

> 📷 **建议配图：** 在这里放一张系统首页拼图，左侧为学生端，右侧为老师端。

## 项目简介

系统由 Android 学生端、Vue 老师端和 FastAPI 后端组成。老师创建课堂后，学生通过课堂码加入；课堂结束后，系统汇总 App 使用时长并生成报告。

## 功能特点

### 学生端

- 注册、登录及服务器地址设置
- 通过 6 位课堂码加入课堂
- 查看课堂阶段、倒计时和老师信息
- 采集并上传课堂期间的 App 使用记录
- 查看个人课堂报告
- 修改昵称和头像

> 📷 **建议配图：** 学生端“加入课堂—课堂倒计时—个人报告—个人资料”四张页面截图。

### 老师端

- 创建课程和课次，自动生成课堂码
- 开始、结束课堂并查看当前课堂
- 查看学生加入情况和 App 使用明细
- 查看应用分类占比、应用排行和学生统计
- 导出 Excel 课堂报告
- 修改昵称和头像

> 📷 **建议配图：** 老师端“创建课堂—当前课堂—报告详情”三张页面截图。

## 技术栈

| 模块 | 主要技术 |
| --- | --- |
| 学生端 | Flutter、Dart、Kotlin、Dio |
| 老师端 | Vue 3、Vite、Element Plus、Axios |
| 后端 | Python、FastAPI、SQLAlchemy、JWT |
| 数据与存储 | MySQL、Redis、MinIO |

## 系统架构

> 📷 **建议配图：** 放系统架构图：`学生端 / 老师端 → FastAPI 后端 → MySQL、Redis、MinIO`。学生端与老师端通过 HTTP 接口访问后端，Android 系统使用情况由 Kotlin 代码读取后交给 Flutter。

## 项目结构

```text
class-focus-system/
├── backend/          # FastAPI 后端与接口
├── teacher-web/      # Vue 老师端
├── student_app/      # Flutter 学生端
├── database/         # 数据库相关文件
└── README.md
```

## 环境要求

- Python 3.12+
- Node.js 22.18+（或 24.12+）
- Flutter（Dart SDK 3.12+）
- MySQL 5.7+ / 8.0+
- Redis
- MinIO
- Android 设备或模拟器

## 后端运行方式

1. 在 `backend/.env` 中填写 MySQL、Redis、MinIO 和 JWT 配置。
2. 安装依赖并启动服务：

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

启动后可访问：`http://127.0.0.1:8000/docs`。

## 教师端运行方式

```powershell
cd teacher-web
npm install
npm run dev:remote
```

后端地址在 `teacher-web/.env.remote` 中设置。

## 学生端运行方式

```powershell
cd student_app
flutter pub get
flutter run
```

首次使用时，在登录页或个人资料页填写后端地址。真机测试时应填写电脑的局域网 IP，例如 `http://192.168.1.10:8000`。

> 📷 **建议配图：** 放学生端“服务器地址设置”页面，并标出地址填写位置。

## 使用流程

1. 老师注册并创建课堂，获得 6 位课堂码。
2. 学生登录 App，输入课堂码加入课堂。
3. 老师开始课堂，学生端显示当前阶段和倒计时。
4. 学生端记录课堂期间的 App 使用情况。
5. 课堂结束后上传数据，老师查看或导出报告。

> 📷 **建议配图：** 放一张流程图：`创建课堂 → 输入课堂码 → 开始课堂 → 记录使用情况 → 生成报告`。

## 主要接口

| 方法 | 接口 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/register` | 用户注册 |
| POST | `/api/auth/login` | 用户登录 |
| PUT | `/api/auth/profile` | 修改昵称 |
| POST | `/api/auth/avatar` | 上传头像 |
| POST | `/api/teacher/classrooms` | 创建课堂 |
| POST | `/api/teacher/classrooms/{id}/start` | 开始课堂 |
| POST | `/api/teacher/classrooms/{id}/end` | 结束课堂 |
| GET | `/api/teacher/classrooms/{id}/members` | 查看课堂成员 |
| GET | `/api/teacher/classrooms/{id}/report` | 查看课堂报告 |
| GET | `/api/teacher/classrooms/{id}/report/export` | 导出 Excel 报告 |
| POST | `/api/student/classrooms/join` | 学生加入课堂 |
| POST | `/api/student/usages` | 上传 App 使用记录 |
| GET | `/api/student/classrooms/{id}/phase` | 查询课堂阶段 |

完整接口和调试入口见后端 Swagger：`http://127.0.0.1:8000/docs`。

## 数据库设计

| 数据表 | 用途 |
| --- | --- |
| `users` | 老师、学生账号及个人资料 |
| `classrooms` | 课程、课次、课堂码和课堂状态 |
| `classroom_members` | 学生加入课堂的记录 |
| `app_usages` | 学生 App 使用记录及应用分类 |
| `classroom_reports` | 已生成的课堂报告 |

> 📷 **建议配图：** 放数据库 E-R 图，重点表示用户、课堂、课堂成员和使用记录之间的关系。

## 测试情况

- 已完成注册登录、创建课堂、加入课堂、课堂倒计时、数据上传和报告查看等主要流程测试。
- 学生端包含基础页面测试；老师端和后端目前以接口调试、页面联调为主。
- Android 的 App 使用记录功能需要在真机上授权后测试。

> 📷 **建议配图：** 放 Swagger 接口测试结果和 Android 使用情况访问权限页面。

## 项目不足与优化方向

- 增加更多自动化测试。
- 完善 Redis 缓存和网络异常处理。
- 继续补充应用分类规则，提高统计准确度。
- 优化报告图表和多课堂数据对比。
- 完善部署配置与使用说明。
