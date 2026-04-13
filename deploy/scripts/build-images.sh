#!/usr/bin/env bash
# 在 Ubuntu / Linux / macOS 上构建 Docker 镜像（供 Docker Compose、kind、k3s 等使用）
# 用法（仓库根目录）:
#   chmod +x deploy/scripts/build-images.sh
#   ./deploy/scripts/build-images.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "Building backend..."
docker build -f deploy/docker/Dockerfile.backend -t location-sharing-backend:latest backend

echo "Building admin..."
docker build -f deploy/docker/Dockerfile.admin -t location-sharing-admin:latest .

echo "Building web..."
docker build -f deploy/docker/Dockerfile.web -t location-sharing-web:latest .

echo "Done. Images: location-sharing-backend:latest, location-sharing-admin:latest, location-sharing-web:latest"
