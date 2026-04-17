#!/bin/sh
docker save -o backend.tar location-sharing-backend:latest
ctr -n k8s.io images import backend.tar
rm backend.tar

docker save -o admin.tar location-sharing-admin:latest
ctr -n k8s.io images import admin.tar
rm admin.tar

docker save -o web.tar location-sharing-web:latest
ctr -n k8s.io images import web.tar
rm web.tar

docker save -o postgres.tar postgres:18.3-alpine
ctr -n k8s.io images import postgres.tar
rm postgres.tar

docker save -o redis.tar redis:8.6.2
ctr -n k8s.io images import redis.tar
rm redis.tar

docker save -o emqx.tar emqx/emqx:5.8.8
ctr -n k8s.io images import emqx.tar
rm emqx.tar