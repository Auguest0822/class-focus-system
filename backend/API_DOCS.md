# 课堂专注管理系统 — 接口文档

> ⚠️ 说明：本仓库**以代码为准**，本文档是代码中接口的同步整理。
> 如果你在 Swagger UI (`http://localhost:8000/docs`) 里看到的字段与本文档不一致，请以 Swagger UI 为准，并反馈补充本文档。
> 响应外层统一包装：`ApiResponse<T> = { code, message, data: T }`。本文档只写 `data` 部分的结构。

## 1. 基础约定

- Base URL：`http://<host>:<port>`（开发默认 `http://localhost:8000`）
- 认证：需要登录的接口在请求头中携带 `Authorization: Bearer <token>`
- 响应外层：`{ "code": 0, "message": "ok", "data": {...} }`（`code=0` 表示业务成功）
- 时间字段：ISO 8601 字符串，例如 `2026-07-06T08:00:00`，UTC 不带时区后缀或按需处理
- 课堂状态：`waiting`（未开始） / `running`（进行中） / `finished`（已结束）

## 2. 接口总览

| 模块     | Method | Path                                   | 必填角色                                  | 说明                                             |
| -------- | ------ | -------------------------------------- | ----------------------------------------- | ------------------------------------------------ |
| 认证     | POST   | `/api/auth/register`                   | -                                         | 注册账号，成功即返回 JWT                         |
| 认证     | POST   | `/api/auth/login`                      | -                                         | 登录，返回 JWT                                   |
| 认证     | GET    | `/api/auth/me`                         | 已登录                                    | 获取当前登录用户信息                             |
| 老师     | GET    | `/api/teacher/courses`                 | teacher                                   | 按课程分组的课堂列表（推荐使用）                 |
| 老师     | GET    | `/api/teacher/classrooms`              | teacher                                   | 平铺列出当前老师创建的全部课堂                   |
| 老师     | POST   | `/api/teacher/classrooms`              | teacher                                   | 创建课堂（自动生成 6 位加入码）                  |
| 老师     | POST   | `/api/teacher/classrooms/{id}/start`   | teacher                                   | 开始课堂（状态 → `running` 并记录 `started_at`） |
| 老师     | POST   | `/api/teacher/classrooms/{id}/end`     | teacher                                   | 结束课堂（状态 → `finished` 并记录 `ended_at`）  |
| 老师     | GET    | `/api/teacher/classrooms/{id}/members` | teacher                                   | 查看已加入学生 + 每人的使用情况汇总              |
| 老师     | GET    | `/api/teacher/classrooms/{id}/report`  | teacher                                   | 生成 / 查询课堂整体报告（首次访问会自动生成）    |
| 学生     | POST   | `/api/student/classrooms/join`         | student                                   | 用 6 位课堂码加入课堂                            |
| 学生     | GET    | `/api/student/classrooms`              | student                                   | 我已加入的课堂列表                               |
| 学生     | POST   | `/api/student/usages`                  | student                                   | 批量上传使用记录（秒）                           |
| 学生     | GET    | `/api/student/classrooms/{id}/usages`  | student                                   | 查询我在该课堂自己上传过的记录                   |
| 通用报告 | GET    | `/api/report/classrooms/{id}`          | 已登录（老师看自己创建 / 学生看自己加入） | 通用报告查询入口；只读；没报告时 404             |

## 3. 详细接口

### 3.1 认证模块 `/api/auth/*`

#### 用户注册

POST `/api/auth/register` — 

请求体：

| 字段       | 类型   | 必填     | 说明                                           |
| ---------- | ------ | -------- | ---------------------------------------------- |
| username   | string | 是       | 登录账号（全局唯一）                           |
| password   | string | 是       | 登录密码（明文传输，服务端用 bcrypt 哈希存储） |
| role       | string | 是       | 角色：`teacher` 或 `student`                   |
| name       | string | 是       | 真实姓名 / 显示名                              |
| student_no | string | 学生必填 | 学号（学生账号必填，老师账号传空或不传）       |
| teacher_no | string | 老师必填 | 工号（老师账号必填，学生账号传空或不传）       |

响应 data：`TokenResponse`

| 字段         | 类型   | 说明                                              |
| ------------ | ------ | ------------------------------------------------- |
| access_token | string | JWT，后续接口使用 `Authorization: Bearer <token>` |
| token_type   | string | 固定为 `bearer`                                   |
| user_id      | int    | 用户 ID                                           |
| username     | string | 登录账号                                          |
| role         | string | `teacher` / `student`                             |
| name         | string | 显示名                                            |

典型错误：`400` 账号已存在 / 必填字段缺失



#### 用户登录

POST `/api/auth/login` — 

请求体：

| 字段     | 类型   | 必填 | 说明     |
| -------- | ------ | ---- | -------- |
| username | string | 是   | 登录账号 |
| password | string | 是   | 登录密码 |

响应 data：`TokenResponse`（同上）

典型错误：`401` 账号或密码错误



#### 获取当前登录用户信息

GET `/api/auth/me` — 

需登录。

响应 data：`UserInfo`

| 字段       | 类型           | 说明                  |
| ---------- | -------------- | --------------------- |
| id         | int            | 用户 ID               |
| username   | string         | 登录账号              |
| role       | string         | `teacher` / `student` |
| name       | string         | 显示名                |
| student_no | string \| null | 学号（学生有）        |
| teacher_no | string \| null | 工号（老师有）        |
| created_at | string \| null | 注册时间（ISO 8601）  |

---

### 3.2 老师模块 `/api/teacher/*`

需 `Authorization: Bearer <token>`，且当前用户 `role=teacher`。



#### 查询按课程分组的课堂列表

GET `/api/teacher/courses` — 

说明：按 `(course_no, course_name)` 聚合，把同一个课程的多节课组织在 `classrooms[]` 中，是老师端"课程列表页 / 课程详情页"推荐使用的接口。

响应 data：`CourseGroupInfo[]`

`CourseGroupInfo`：

| 字段         | 类型                  | 说明                     |
| ------------ | --------------------- | ------------------------ |
| course_no    | string                | 课号，如 `100001`        |
| course_name  | string                | 课程名称，如 `高等数学`  |
| lesson_count | int                   | 该课程下已创建的课次总数 |
| classrooms   | `ClassroomInCourse[]` | 课次列表，按创建时间倒序 |

`ClassroomInCourse`（一个课次的精简信息）：

| 字段               | 类型           | 说明                                |
| ------------------ | -------------- | ----------------------------------- |
| id                 | int            | 课堂（课次）ID                      |
| lesson_name        | string         | 课次名，如 `第 1 次课`              |
| code               | string         | 6 位课堂加入码                      |
| duration_minutes   | int            | 课堂时长（分钟）                    |
| status             | string         | `waiting` / `running` / `finished`  |
| scheduled_start_at | string \| null | 计划开课时间（ISO 8601）            |
| started_at         | string \| null | 实际开始时间（老师点 start 那一刻） |
| ended_at           | string \| null | 实际结束时间（老师点 end 那一刻）   |





#### 创建课堂

POST `/api/teacher/classrooms` — 

说明：创建一个新的课堂；系统自动生成一个 6 位加入码（`code`）。

请求体 `ClassroomCreate`：

| 字段               | 类型   | 必填 | 说明                                      |
| ------------------ | ------ | ---- | ----------------------------------------- |
| course_no          | string | 是   | 课号，如 `100001`                         |
| course_name        | string | 是   | 课程名称，如 `高等数学`                   |
| lesson_name        | string | 是   | 课次名，如 `第 1 次课`                    |
| duration_minutes   | int    | 否   | 课堂时长（分钟），默认 `45`               |
| scheduled_start_at | string | 否   | 计划开课时间（ISO 8601），不传则为 `null` |

示例：

```json
{
  "course_no": "100001",
  "course_name": "高等数学",
  "lesson_name": "第 1 次课",
  "duration_minutes": 95,
  "scheduled_start_at": "2026-07-06T08:00:00"
}
```

响应 data：`ClassroomInfo`（结构见上），返回刚创建的课堂，包含自动生成的 `code`。

#### 开始课堂

POST `/api/teacher/classrooms/{id}/start` — 

说明：把课堂状态改成 `running`，并记录 `started_at`。重复调用（已经是 `running` 或 `finished`）不会报错，但只在 `waiting → running` 时记录开始时间。

路径参数：`classroom_id = id`（课堂 ID）

响应 data：`ClassroomInfo`

典型错误：`404` 课堂不存在 / 不是该老师创建

#### 结束课堂

POST `/api/teacher/classrooms/{id}/end` — 

说明：把课堂状态改成 `finished`，并记录 `ended_at`。

响应 data：`ClassroomInfo`

#### 查看已加入学生 + 每人使用情况

GET `/api/teacher/classrooms/{id}/members` — 

说明：返回已加入的学生列表，并聚合出每个人在本课堂上报的 App 使用秒数以及最常用的应用。用于老师端"课堂详情 / 学生专注分布"页。

响应 data：`StudentSummary[]`

`StudentSummary`：

| 字段          | 类型           | 说明                                                         |
| ------------- | -------------- | ------------------------------------------------------------ |
| student_id    | int            | 学生 ID                                                      |
| student_name  | string         | 学生姓名                                                     |
| student_no    | string \| null | 学号                                                         |
| total_seconds | int            | 该学生在本课堂内上报的手机使用总秒数                         |
| top_apps      | array          | 最常使用的应用列表；每项形如 `{ "app": "微信", "package": "com.tencent.mm", "seconds": 120 }`，按秒数倒序取前若干名 |

#### 生成 / 查询课堂报告

GET `/api/teacher/classrooms/{id}/report` — 

说明：返回该课堂的整体专注度评分、高频应用以及建议文案。
**首次访问 / 还没报告时，后端会基于已有的使用记录实时生成一份，并写入数据库**；因此首次调用可能稍慢。如果想强制刷新，让学生端再调用一次「上传使用记录」即可（学生端上传会清掉旧报告）。

响应 data：`ClassroomReportInfo`

| 字段                  | 类型           | 说明                                 |
| --------------------- | -------------- | ------------------------------------ |
| id                    | int            | 报告 ID                              |
| classroom_id          | int            | 课堂 ID                              |
| total_students        | int            | 加入课堂的学生总数                   |
| average_usage_seconds | float          | 人均 App 使用秒数                    |
| top_apps              | string \| null | 高频应用 JSON 字符串，见下方格式说明 |
| focus_score           | float          | 专注度评分（0–100，越高越专注）      |
| suggestions           | string \| null | 系统生成的课堂建议（中文文案）       |
| generated_at          | string \| null | 报告生成时间（ISO 8601）             |

`top_apps` 字段是 JSON 字符串（后端用 TEXT 存），前端直接 `JSON.parse(topApps)` 即可：

```json
[
  { "app": "微信", "package": "com.tencent.mm", "seconds": 320 },
  { "app": "抖音", "package": "com.ss.android.ugc.aweme", "seconds": 180 }
]
```

---

### 3.3 学生模块 `/api/student/*`

需 `Authorization: Bearer <token>`，且当前用户 `role=student`。

#### 加入课堂

POST `/api/student/classrooms/join` — 

请求体：

| 字段 | 类型   | 必填 | 说明                           |
| ---- | ------ | ---- | ------------------------------ |
| code | string | 是   | 6 位课堂加入码（不区分大小写） |

示例：

```json
{ "code": "3K9P2A" }
```

响应 data：`ClassroomInfo`（与老师端返回的课堂结构一致，字段说明见 3.2 中的 `ClassroomInfo` 表）

典型错误：

| 状态码 | 场景                   |
| ------ | ---------------------- |
| 403    | 当前用户不是 `student` |
| 404    | 课堂码无效（不存在）   |

> 重复调用同一个课堂码不会报错，视为「已加入」，直接返回该课堂信息。

#### 我已加入的课堂

GET `/api/student/classrooms` — 

响应 data：`ClassroomInfo[]`（课堂结构同上）

#### 批量上传使用记录

POST `/api/student/usages` — 

说明：上报"在本课堂使用了哪些 App、各用了多少秒"。为了让老师端报告更准确，建议在课堂结束前或结束后调用一次。
本接口调用成功后，该课堂的旧报告会被后端清空，老师端下次访问报告接口时会重新生成最新一份。

请求体 `AppUsageBatch`：

| 字段         | 类型               | 必填 | 说明         |
| ------------ | ------------------ | ---- | ------------ |
| classroom_id | int                | 是   | 课堂 ID      |
| records      | `AppUsageCreate[]` | 是   | 使用记录列表 |

每条 `records[]` 的 `AppUsageCreate`：

| 字段          | 类型   | 必填 | 说明                                          |
| ------------- | ------ | ---- | --------------------------------------------- |
| app_package   | string | 是   | App 包名，如 `com.tencent.mm`                 |
| app_name      | string | 否   | App 显示名，如 `微信`（建议传，方便报告阅读） |
| usage_seconds | int    | 是   | 在课堂中使用该应用的秒数                      |
| start_time    | string | 否   | 可选：开始使用时间（ISO 8601）                |
| end_time      | string | 否   | 可选：结束使用时间（ISO 8601）                |

示例：

```json
{
  "classroom_id": 1,
  "records": [
    { "app_package": "com.tencent.mm", "app_name": "微信", "usage_seconds": 120 },
    { "app_package": "com.ss.android.ugc.aweme", "app_name": "抖音", "usage_seconds": 320 }
  ]
}
```

响应 data：`number` —— 本次成功插入的记录条数。

典型错误：

| 状态码 | 场景               |
| ------ | ------------------ |
| 403    | 该学生未加入该课堂 |
| 404    | 课堂不存在         |

#### 查询我自己在本课堂中上传过的记录

GET `/api/student/classrooms/{id}/usages` — 

说明：仅返回"我自己"在本课堂中通过上一个接口上报的明细，用于展示学生本人的"专注数据回顾"。

响应 data：`AppUsageInfo[]`

| 字段          | 类型           | 说明         |
| ------------- | -------------- | ------------ |
| id            | int            | 记录 ID      |
| classroom_id  | int            | 课堂 ID      |
| student_id    | int            | 学生 ID      |
| app_package   | string         | 应用包名     |
| app_name      | string \| null | 应用显示名   |
| usage_seconds | int            | 使用秒数     |
| start_time    | string \| null | 开始使用时间 |
| end_time      | string \| null | 结束使用时间 |
| created_at    | string \| null | 上报时间     |

---

### 3.4 通用报告模块 `/api/report/*`

#### 通用课堂报告查询

GET `/api/report/classrooms/{id}` — 

说明：通用课堂报告查询接口。根据当前登录角色自动做权限判断：

- 老师：只能查看自己创建的课堂
- 学生：只能查看自己已加入的课堂

如果报告尚未生成，会返回 `404`，提示"请先由老师端在课堂报告接口（`GET /api/teacher/classrooms/{id}/report`）中触发生成一次，或上传使用记录后再试"。

响应 data：`ClassroomReportInfo`（结构同 3.2 中同名表）

---

## 4. 数据库表结构（供联调参考）

| 表                  | 核心字段                                                     | 说明                                                   |
| ------------------- | ------------------------------------------------------------ | ------------------------------------------------------ |
| `users`             | `id`, `username`（唯一）, `password_hash`, `role`, `student_no`（唯一）, `teacher_no`（唯一）, `name`, `created_at` | 账号表（老师 + 学生共用）                              |
| `classrooms`        | `id`, `teacher_id`, `course_no`, `course_name`, `lesson_name`, `code`（唯一）, `duration_minutes`, `status`, `scheduled_start_at`, `started_at`, `ended_at`, `created_at` | 课堂表（"一个课堂 = 一次课次"）；不再使用 `title` 字段 |
| `classroom_members` | `id`, `classroom_id`, `student_id`, `joined_at`；`(classroom_id, student_id)` 唯一 | 学生 - 课堂 中间表                                     |
| `app_usages`        | `id`, `classroom_id`, `student_id`, `app_package`, `app_name`, `usage_seconds`, `start_time`, `end_time`, `created_at` | 使用记录明细；报告数据源于此表                         |
| `classroom_reports` | `id`, `classroom_id`（唯一）, `total_students`, `average_usage_seconds`, `top_apps`（JSON 文本）, `focus_score`, `suggestions`, `generated_at` | 课堂整体报告                                           |

> 字段映射：API 中的 `ClassroomInfo / CourseGroupInfo / ClassroomReportInfo / AppUsageInfo / StudentSummary` 全部由上述表经 `JOIN` / `GROUP BY` 聚合后再序列化返回；`ClassroomCreate` 则直连写入 `classrooms`。

