# 部署说明

本目录包含 Docker Compose 与 Kubernetes 清单，用于在本地或集群中运行「定位共享」全栈（PostgreSQL、Redis、EMQX、Rust API、Admin Web、User Web）。

## 目录结构

```
deploy/
├── README.md                 # 本文件
├── docker/
│   ├── docker-compose.yml    # 一键编排
│   ├── Dockerfile.backend    # Rust API 镜像
│   ├── Dockerfile.admin      # 管理端静态资源 + Nginx
│   ├── Dockerfile.web        # 用户 Web 静态资源 + Nginx
│   ├── nginx-admin.conf      # Admin：反向代理 /api → backend
│   ├── nginx-web.conf        # Web：同上
│   └── .env.example          # JWT 等环境变量示例
├── k8s/
│   ├── namespace.yaml
│   ├── secrets.example.yaml  # 复制为 secrets.yaml 后修改（勿提交）
│   ├── kustomization.yaml     # kubectl apply -k
│   ├── ingress.example.yaml  # Ingress 示例
│   ├── postgres/             # Deployment（hostPath 数据卷）+ NodePort Service
│   ├── redis/
│   ├── emqx/
│   ├── backend/
│   ├── admin/
│   └── web/
└── scripts/
    ├── build-images.ps1      # Windows（PowerShell）构建镜像
    └── build-images.sh       # Ubuntu / Linux / macOS（bash）构建镜像
```

## Docker Compose

**前提**：仓库根目录执行命令；已安装 Docker 与 Docker Compose v2。

```powershell
cd E:\work\test\location_sharing
docker compose -f deploy/docker/docker-compose.yml up -d --build
```

- 后端 `DATABASE_URL` / `REDIS_URL` / `MQTT_*` 已在 compose 中按服务名写死，一般无需改。
- 自定义 JWT：复制 `deploy/docker/.env.example` 为 `deploy/docker/.env` 并修改变量。

**本地数据目录（绑定挂载）**

| 服务 | 宿主机路径（相对仓库根） | 容器内路径 |
|------|-------------------------|------------|
| PostgreSQL | `data/postgres` | `/var/lib/postgresql/data` |
| EMQX | `data/emqx/data`、`data/emqx/log` | `/opt/emqx/data`、`/opt/emqx/log` |

首次启动前可手动创建目录；Compose 也会在首次写入时创建。`data/` 下内容已加入 `.gitignore`。

**宿主机端口（全部映射）**

| 服务 | 宿主机端口 |
|------|------------|
| PostgreSQL | 5432 |
| Redis | 6379 |
| EMQX | 1883, 8883, 8083, 8084, 18083, 18084 |
| Backend API | 8080 |
| Admin Web | 3001 |
| User Web | 3000 |

构建说明：

- `backend` 构建上下文为 `backend/`，使用 `deploy/docker/Dockerfile.backend`。
- `admin` / `web` 构建上下文为仓库根目录，使用 `deploy/docker/Dockerfile.admin` / `Dockerfile.web`。

一键构建三个镜像：

- **Ubuntu / Linux / macOS**：`chmod +x deploy/scripts/build-images.sh && ./deploy/scripts/build-images.sh`
- **Windows**：`.\deploy\scripts\build-images.ps1`

## Kubernetes

1. 创建命名空间与 Secret（**必须先有 `secrets.yaml`**）：

   ```bash
   kubectl apply -f deploy/k8s/secrets.yaml
   ```

   `secrets.yaml` 由 `secrets.example.yaml` 复制而来，务必修改 `database-url` 中的密码、`jwt-secret`、`jwt-admin-secret` 等。

2. 部署全部组件：

   ```bash
   kubectl apply -k deploy/k8s/
   ```

3. 默认使用镜像名 `location-sharing-backend:latest`、`location-sharing-admin:latest`、`location-sharing-web:latest`，需在集群可访问的节点上存在（或推送到私有仓库后修改 Deployment 与 `kustomization.yaml` 的 `images` 覆盖）。

4. **对外访问（仅 Kubernetes）**：以下 **NodePort** 为集群节点上对外访问端口，均为 **4xxxx**；与 Docker Compose / 本地 Vite 的 **3000、3001** 等无关。  
   **重要**：Kubernetes 默认仅允许 NodePort 落在 **30000–32767**。若 `kubectl apply` 报 NodePort 无效，请在 **kube-apiserver** 增加参数：  
   `--service-node-port-range=40000-42767`（或包含该范围的区间），并重启控制平面后再应用。

| 服务 | 集群内端口 | NodePort（宿主机） |
|------|------------|-------------------|
| postgres | 5432 | 40432 |
| redis | 6379 | 40379 |
| emqx | 1883 / 8883 / 8083 / 8084 / 18083 / 18084 | 41883 / 40883 / 40803 / 40804 / 41805 / 41806 |
| backend | 8080 | 40808 |
| admin | 80 | 40081 |
| web | 80 | 40080 |

5. **节点本地磁盘**：PostgreSQL、EMQX 使用 **hostPath**（需在每台运行 Pod 的节点上存在可写目录）：

   - `/data/location-sharing/postgres`
   - `/data/location-sharing/emqx-data`
   - `/data/location-sharing/emqx-log`

6. 若使用云厂商负载均衡或域名，可再配置 `ingress.example.yaml`。

## Kubernetes 重启

命名空间：`location-sharing`。

| 场景 | 命令 |
|------|------|
| 滚动重启后端 / 管理端 / 用户 Web | `kubectl rollout restart deployment/backend -n location-sharing`（将 `backend` 换成 `admin` 或 `web`） |
| 滚动重启 **PostgreSQL** | `kubectl rollout restart deployment/postgres -n location-sharing` |
| 滚动重启 **Redis** | `kubectl rollout restart deployment/redis -n location-sharing` |
| 滚动重启 **EMQX** | `kubectl rollout restart deployment/emqx -n location-sharing` |
| 重启命名空间内**所有** Deployment | `kubectl rollout restart deployment --all -n location-sharing`（含 postgres、redis、emqx，生产慎用） |
| 查看某 Deployment 滚动进度 | `kubectl rollout status deployment/postgres -n location-sharing`（资源名可换） |
| 删除 Pod 强制重建 | `kubectl delete pod -l app=postgres -n location-sharing`（`app` 可取 `postgres` / `redis` / `emqx` / `backend` 等，与清单中 `spec.selector` 一致） |

**注意**：PostgreSQL 重启会短暂断连，数据在节点 **hostPath** 上保留。Redis 本清单未挂持久卷，重启后内存数据会丢失。EMQX 重启会短暂影响 MQTT。更新业务镜像时通常只需重启 `backend`、`admin`、`web`；中间件仅在改配置或排障时再重启。

## 后端健康检查

API 暴露 `GET /health`（返回纯文本 `ok`），供 Docker Compose / K8s 探针使用。
