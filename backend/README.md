# 课堂专注管理系统 - Python 后端

基于 **FastAPI + SQLAlchemy + MySQL** 搭建,为 Android 学生端与 Web 老师端提供后端接口服务。

## 目录结构

```
backend/
├── main.py                  # FastAPI 应用入口
├── requirements.txt
├── .env                     # 环境变量(MySQL 账号密码等)
├── run.bat                  # Windows 快捷启动脚本
└── app/
    ├── api/
    │   ├── auth.py          # 注册 / 登录 / 当前用户
    │   ├── teacher.py       # 老师端: 创建课堂 / 开始结束 / 报告
    │   ├── student.py       # 学生端: 加入课堂 / 上传使用记录
    │   └── report.py        # 通用报告查询
    ├── core/
    │   ├── config.py        # 配置(读取 .env)
    │   ├── database.py      # SQLAlchemy 引擎 / Session
    │   ├── security.py      # JWT / 密码哈希
    │   └── deps.py          # 当前用户 / 角色依赖
    ├── models/              # SQLAlchemy ORM 模型
    ├── schemas/             # Pydantic 请求 / 响应模型
    └── utils/               # 课堂码生成等工具
```

## 快速开始

### 1. 环境要求

- Python **3.10+**(项目使用了 Pydantic 2 的泛型语法)
- MySQL **5.7+ 或 8.0+**

### 2. 安装依赖

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows PowerShell / CMD
# source .venv/bin/activate   # macOS / Linux

pip install -r requirements.txt
```

### 3. 配置 MySQL

编辑 `.env` 文件,填入你的 MySQL 账号信息:

```
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=你的密码
MYSQL_DATABASE=classroom_focus
```

> 应用启动时会自动执行 `CREATE DATABASE IF NOT EXISTS`,并自动创建所有数据表。

### 4. 启动服务

```bash
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
# 或 Windows 下直接: run.bat
```

启动成功后:

- API 文档(Swagger): <http://localhost:8000/docs>
- 健康检查: <http://localhost:8000/health>
- 根路径: <http://localhost:8000/>

## 主要 API

所有接口统一响应格式:

```json
{ "code": 0, "message": "ok", "data": {} }
```

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| POST | `/api/auth/register` | 注册(老师 / 学生) |
| POST | `/api/auth/login`    | 登录,返回 JWT |
| GET  | `/api/auth/me`       | 当前用户信息 |
| GET  | `/api/teacher/classrooms` | 老师的课堂列表 |
| POST | `/api/teacher/classrooms` | 老师创建课堂 |
| POST | `/api/teacher/classrooms/{id}/start` | 开始课堂 |
| POST | `/api/teacher/classrooms/{id}/end`   | 结束课堂 |
| GET  | `/api/teacher/classrooms/{id}/members` | 学生加入情况与专注情况 |
| GET  | `/api/teacher/classrooms/{id}/report`  | 生成 / 查看课堂报告 |
| POST | `/api/student/classrooms/join` | 学生通过课堂码加入 |
| GET  | `/api/student/classrooms`      | 学生加入的课堂列表 |
| POST | `/api/student/usages`          | 批量上传 App 使用记录 |
| GET  | `/api/student/classrooms/{id}/usages` | 学生个人使用记录 |
| GET  | `/api/report/classrooms/{id}`   | 通用报告查询 |

## 数据模型

- `users`: 用户(老师 / 学生)
- `classrooms`: 课堂(包含唯一课堂码、时长、状态)
- `classroom_members`: 课堂成员(学生加入记录)
- `app_usages`: App 使用记录(学生端上传)
- `classroom_reports`: 课堂报告(自动生成专注评分 / 建议)

## 常见问题

**Q: 启动时报 `ModuleNotFoundError`?**
A: 确保已激活虚拟环境并安装了 `requirements.txt`。

**Q: 连接 MySQL 报 `caching_sha2_password`?**
A: MySQL 8 默认使用该插件。确保安装了 `cryptography`(`requirements.txt` 中已包含),或在 MySQL 中将用户认证方式改为 `mysql_native_password`。

**Q: 接口返回 401 Unauthorized?**
A: 登录后,请求时需在 Header 中携带 `Authorization: Bearer <access_token>`。
