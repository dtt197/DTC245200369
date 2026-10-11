#!/usr/bin/env bash
# Cai dat lan dau: tao .env (mat khau ngau nhien), chung chi SSL, dung he thong, tao tai khoan exporter
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  for k in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD GRAFANA_ADMIN_PASSWORD EXPORTER_PASSWORD; do
    sed -i "s|^$k=.*|$k=$(openssl rand -hex 12)|" .env
  done
  echo "==> Da tao .env voi mat khau ngau nhien"
else
  echo "==> Giu nguyen .env hien co"
fi

[ -f nginx/certs/server.crt ] || ./nginx/gen-cert.sh

echo "==> Dung he thong (lan dau mat 3-5 phut)"
docker compose up -d --build

echo "==> Cho MySQL san sang"
for i in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' sv-mysql-db 2>/dev/null)" = healthy ] && break
  sleep 5
done

./db/create-exporter-user.sh
docker compose up -d
docker compose restart mysqld-exporter >/dev/null
echo "==> Xong. Mo https://localhost:8443"
