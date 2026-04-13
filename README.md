# 定位共享 (Location Sharing)

一款面向家庭成员的实时位置共享与防走失系统，支持 Web、Android、iOS、HarmonyOS 多端访问。

## 核心功能

| # | 功能 | 说明 |
|---|------|------|
| 1 | **实时定位** | GPS/北斗/基站/WiFi 多模融合定位，精度 <10 米，刷新间隔 1-60 秒可调 |
| 2 | **位置共享** | 家庭成员/指定联系人相互授权共享位置，手机号搜索添加，创建家庭组 |
| 3 | **历史轨迹** | 查看 30 天内移动轨迹，时间筛选，速度/停留点标注，轨迹回放 |
| 4 | **地图显示** | 高德地图集成，实时标记/轨迹动画/一键导航（步行/驾车/公交） |
| 5 | **后台运行** | App 关闭后持续上报定位，智能功耗优化（静止延长间隔、低电降频） |
| 6 | **多端支持** | App 端完整功能 + Web 端查看定位/轨迹（不上报） |
| 7 | **语音通话** | 一键拨打绑定成员，支持自动接听模式（老人无需操作） |
| 8 | **隐私控制** | 双方同意才共享，可暂停/撤销/设置可见时段，数据加密传输存储 |
| 9 | **通知中心** | 位置异常/共享请求/权限变更/系统通知推送，自定义铃声震动 |
| 10 | **管理后台** | Admin Web 管理高德地图 Key、短信 Key、用户管理、系统配置 |

## 技术栈

### 后端
- **语言/框架**: Rust + Axum (workspace, 10 个 crate)
- **数据库**: PostgreSQL 16
- **缓存**: Redis 7
- **实时推送**: EMQX 5 (MQTT Broker)
- **认证**: JWT (access + refresh token) + 手机号验证码登录
- **部署**: Docker / Kubernetes

### 前端 — Admin 管理端
- React 18 + TypeScript + Vite + MUI (Material UI)
- Zustand 状态管理

### 前端 — 用户 Web 端
- React 18 + TypeScript + Vite + MUI
- 高德地图 JS API 2.0
- MQTT.js (WebSocket)
- Zustand 状态管理

### 移动端 — Android / iOS
- Flutter 3.x + Dart
- 高德地图 Flutter 插件
- mqtt_client + dio
- Riverpod 状态管理

### 移动端 — HarmonyOS
- ArkTS (HarmonyOS NEXT)
- 高德地图鸿蒙 SDK
- MQTT 协议
- 鸿蒙 ContinuousTask 后台定位

## 项目结构

```
location_sharing/
├── README.md                 # 本文件
├── backend/                  # Rust 后端 (Axum workspace)
│   ├── Cargo.toml           # workspace 配置
│   ├── .env.example         # 环境变量模板
│   ├── migrations/          # 数据库迁移
│   │   └── 001_initial.sql
│   └── crates/
│       ├── api/             # HTTP 入口 (main binary)
│       ├── auth/            # 认证 (JWT/验证码/中间件)
│       ├── user/            # 用户/家庭组/共享权限
│       ├── location/        # 位置上报与查询
│       ├── trajectory/      # 历史轨迹
│       ├── notification/    # 通知管理
│       ├── admin/           # 管理后台
│       ├── sms/             # 短信服务 (阿里云/腾讯云)
│       ├── mqtt/            # MQTT 桥接
│       └── common/          # 公共模块 (错误/模型/响应/配置)
├── admin/                    # Admin 管理端 (React + MUI)
│   ├── package.json
│   └── src/
│       ├── pages/           # Login, Dashboard, Users, Configs
│       ├── api/             # 接口封装
│       ├── components/      # Layout 组件
│       └── store/           # 状态管理
├── web/                      # 用户 Web 端 (React + MUI + AMap)
│   ├── package.json
│   └── src/
│       ├── pages/           # Login, Map, Family, Trajectory, ...
│       ├── api/             # 接口封装
│       ├── components/      # 地图/标记/轨迹组件
│       ├── hooks/           # useAuth, useMqtt, ...
│       ├── mqtt/            # MQTT 客户端
│       └── store/           # 状态管理
├── mobile/                   # Flutter App (Android + iOS)
│   ├── pubspec.yaml
│   └── lib/
│       ├── screens/         # 各页面
│       ├── api/             # dio 封装
│       ├── services/        # 定位/MQTT/通知服务
│       ├── providers/       # Riverpod 状态管理
│       └── models/          # 数据模型
├── harmony/                  # HarmonyOS 鸿蒙端 (ArkTS)
│   └── entry/src/main/ets/
│       ├── pages/           # 各页面
│       ├── api/             # HTTP 封装
│       ├── services/        # 定位/MQTT 服务
│       └── models/          # 数据模型
└── deploy/                   # 部署配置
    ├── docker/
    ├── k8s/                 # Kubernetes 编排
    │   ├── backend/
    │   ├── admin/
    │   ├── web/
    │   ├── postgres/
    │   ├── redis/
    │   └── emqx/
    └── scripts/
```

## 快速启动

### 前置依赖

- Rust 1.75+ (rustup)
- Node.js 20+ & pnpm
- Flutter 3.x (移动端开发)
- DevEco Studio 5.x (鸿蒙开发)
- PostgreSQL 16
- Redis 7
- EMQX 5

### 1. 后端

```bash
cd backend
cp .env.example .env
# 编辑 .env 配置数据库和 Redis 地址
cargo run --bin location-sharing-api
# 服务启动于 http://localhost:8080
```

### 2. Admin 管理端

```bash
cd admin
pnpm install
pnpm dev
# 访问 http://localhost:3001
# 默认管理员: admin / admin123
```

### 3. 用户 Web 端

```bash
cd web
pnpm install
pnpm dev
# 访问 http://localhost:3000
```

### 4. Flutter App

```bash
cd mobile
flutter pub get
flutter run          # Android
flutter run -d ios   # iOS
```

### 5. HarmonyOS 鸿蒙端

使用 DevEco Studio 打开 harmony/ 目录，连接设备后运行。

## API 接口概览

所有接口基础路径: POST/GET/PUT/DELETE /api/v1/...

### 认证
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /auth/send-code | 发送短信验证码 |
| POST | /auth/verify-code | 验证码登录，返回 JWT |
| POST | /auth/refresh | 刷新 access token |

### 用户
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /users/profile | 获取个人资料 |
| PUT | /users/profile | 更新个人资料 |

### 家庭组
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /groups | 创建家庭组 |
| GET | /groups | 我的家庭组列表 |
| DELETE | /groups/:id | 删除家庭组 |
| POST | /groups/:id/members | 添加成员 |
| DELETE | /groups/:id/members/:uid | 移除成员 |

### 位置共享
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /sharing | 请求共享 |
| GET | /sharing | 共享列表 |
| PUT | /sharing/:id | 更新共享设置 |
| PUT | /sharing/:id/respond | 同意/拒绝 |
| DELETE | /sharing/:id | 撤销共享 |

### 位置
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /location/upload | 上报位置 |
| GET | /location/latest | 查询最新位置 |
| GET | /location/shared/:uid | 查询共享用户位置 |
| GET | /location/family/:gid | 查询家庭组位置 |

### 轨迹
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /trajectory?user_id=&start_time=&end_time= | 历史轨迹查询 |

### 通知
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /notifications | 通知列表 |
| PUT | /notifications/:id/read | 标记已读 |
| PUT | /notifications/read-all | 全部已读 |

### 管理后台
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /admin/login | 管理员登录 |
| GET | /admin/users | 用户列表 |
| GET | /admin/stats | 仪表盘统计 |
| GET | /admin/configs | 配置列表 |
| PUT | /admin/configs/:key | 更新配置 |

## MQTT Topic 设计

| Topic | 方向 | 说明 |
|-------|------|------|
| location/{user_id}/update | App -> Server | 位置上报 |
| location/{user_id}/realtime | Server -> Client | 实时位置推送 |
| 
otification/{user_id} | Server -> Client | 通知推送 |

## 部署

详细说明见 `deploy/README.md`。

### Docker Compose（本地/联调）

在仓库根目录执行（需已安装 Docker 与 Docker Compose）：

```bash
cp deploy/docker/.env.example deploy/docker/.env   # 可选：自定义 JWT
docker compose -f deploy/docker/docker-compose.yml up -d --build
```

- 用户 Web：`http://localhost:3000`
- 管理后台：`http://localhost:3001`（默认账号见后端迁移/seed）
- 后端 API：`http://localhost:8080`，健康检查：`GET /health`
- EMQX Dashboard：`http://localhost:18083`（默认用户名 `admin`，首次启动请按容器日志设置密码）

### Kubernetes（生产）

1. 复制 `deploy/k8s/secrets.example.yaml` 为 `deploy/k8s/secrets.yaml`，修改 `database-url`（密码需与 `postgres-password` 一致）、JWT 等。
2. 构建并推送镜像（或加载到本地集群）：`location-sharing-backend`、`location-sharing-admin`、`location-sharing-web`（见 `deploy/docker/Dockerfile.*`）。
3. 应用：

```bash
kubectl apply -f deploy/k8s/secrets.yaml
kubectl apply -k deploy/k8s/
```

可选：按 `deploy/k8s/ingress.example.yaml` 配置 Ingress 与域名。

## 隐私与合规

- 位置共享必须双方同意
- 用户可随时暂停/撤销授权
- 支持可见时段设置
- 所有数据加密传输 (TLS)
- 后台定位需明确用户授权并说明用途
- 隐私政策中明确告知后台定位用途并提供关闭方式
- 遵循最小权限原则

## License

MIT
