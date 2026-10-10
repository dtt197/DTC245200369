#!/usr/bin/env bash
# Doi mat khau yeu thanh mat khau ngau nhien manh (24 ky tu). Khong in mat khau ra man hinh.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "Khong thay file .env"; exit 1; }
cp .env .env.bak

get() { grep "^$1=" .env | cut -d= -f2-; }
gen() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24; }

OLD_ROOT=$(get MYSQL_ROOT_PASSWORD)
APP_USER=$(get MYSQL_USER)
NEW_ROOT=$(gen)
NEW_APP=$(gen)
NEW_GRAFANA=$(gen)

echo "==> Doi mat khau trong MySQL"
docker compose exec -T -e MYSQL_PWD="$OLD_ROOT" db mysql -uroot <<SQL
ALTER USER IF EXISTS 'root'@'localhost' IDENTIFIED BY '${NEW_ROOT}';
ALTER USER IF EXISTS 'root'@'%' IDENTIFIED BY '${NEW_ROOT}';
ALTER USER IF EXISTS '${APP_USER}'@'%' IDENTIFIED BY '${NEW_APP}';
FLUSH PRIVILEGES;
SQL

echo "==> Doi mat khau admin Grafana"
docker compose exec -T grafana grafana cli admin reset-admin-password "${NEW_GRAFANA}" >/dev/null

echo "==> Ghi mat khau moi vao .env"
sed -i "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${NEW_ROOT}|" .env
sed -i "s|^MYSQL_PASSWORD=.*|MYSQL_PASSWORD=${NEW_APP}|" .env
sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${NEW_GRAFANA}|" .env

echo "==> Tao lai container de nhan mat khau moi"
docker compose up -d
echo "Xong. Mat khau moi nam trong .env (KHONG commit). Ban sao cu: .env.bak"
