#!/usr/bin/env bash
# Tao tai khoan rieng cho mysqld-exporter, quyen toi thieu, toi da 3 ket noi
set -e
cd "$(dirname "$0")/.."
ROOT_PW=$(grep '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2-)
EXP_PW=$(grep '^EXPORTER_PASSWORD=' .env | cut -d= -f2-)

docker compose exec -T -e MYSQL_PWD="$ROOT_PW" db mysql -uroot <<SQL
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '${EXP_PW}' WITH MAX_USER_CONNECTIONS 3;
ALTER USER 'exporter'@'%' IDENTIFIED BY '${EXP_PW}' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
SQL
echo "Da tao tai khoan exporter"
