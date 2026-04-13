# 在仓库根目录执行：构建本地镜像（供 Docker Compose / kind 加载）
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root

Write-Host "Building backend..."
docker build -f deploy/docker/Dockerfile.backend -t location-sharing-backend:latest backend

Write-Host "Building admin..."
docker build -f deploy/docker/Dockerfile.admin -t location-sharing-admin:latest .

Write-Host "Building web..."
docker build -f deploy/docker/Dockerfile.web -t location-sharing-web:latest .

Write-Host "Done. Images: location-sharing-backend, location-sharing-admin, location-sharing-web"
