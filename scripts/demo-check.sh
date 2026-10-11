#!/usr/bin/env bash
# Kiem tra toan he thong, in PASS/FAIL tung muc. Dung de demo va chup anh bang chung.
cd "$(dirname "$0")/.."
export H=https://localhost:8443
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "  [PASS] $desc"; PASS=$((PASS+1))
  else echo "  [FAIL] $desc"; FAIL=$((FAIL+1)); fi
}

q()  { curl -s -G http://localhost:9099/api/v1/query --data-urlencode "query=$1" \
       | python3 -c 'import sys,json; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else "")'; }
eq() { [ "$(q "$1")" = "$2" ]; }
ge() { local v; v=$(q "$1"); [ -n "$v" ] && python3 -c "import sys; sys.exit(0 if float('$v') >= $2 else 1)"; }

http_code()  { curl -ks -o /dev/null -w '%{http_code}' "$@"; }
has_header() { curl -ksI "$H/" | grep -qi "^$1:"; }
tls_ok()     { echo | openssl s_client -connect localhost:8443 2>/dev/null | grep -qE 'TLSv1\.[23]'; }
running12()  { [ "$(docker compose ps --status running -q | wc -l)" -ge 12 ]; }
db_healthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' sv-mysql-db)" = healthy ]; }
targets_up() { curl -s http://localhost:9099/api/v1/targets | python3 -c 'import sys,json; t=json.load(sys.stdin)["data"]["activeTargets"]; sys.exit(0 if len(t)>=6 and all(x["health"]=="up" for x in t) else 1)'; }

crud_test() {
  local ma="T$(date +%s)" id
  id=$(curl -ksf -X POST "$H/api/sinhvien" -H 'Content-Type: application/json' \
       -d "{\"ma_sv\":\"$ma\",\"ho_ten\":\"Test CRUD\",\"email\":\"t@e.com\",\"lop_id\":1}" \
       | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])') || return 1
  curl -ksf -X PUT "$H/api/sinhvien/$id" -H 'Content-Type: application/json' \
       -d "{\"ma_sv\":\"$ma\",\"ho_ten\":\"Test Sua\",\"email\":\"t@e.com\",\"lop_id\":1}" >/dev/null || return 1
  curl -ks "$H/api/sinhvien" | grep -q "Test Sua" || return 1
  curl -ksf -X DELETE "$H/api/sinhvien/$id" >/dev/null
}

GP=$(grep '^GRAFANA_ADMIN_PASSWORD=' .env | cut -d= -f2-)
gf_has() { curl -ks -u "admin:$GP" "$H/grafana/api/$1" | grep -q "$2"; }

loki_ready() { for i in 1 2 3 4 5 6; do docker compose exec -T prometheus wget -qO- http://loki:3100/ready 2>/dev/null | grep -qx ready && return 0; sleep 5; done; return 1; }
loki_label() { docker compose exec -T prometheus wget -qO- http://loki:3100/loki/api/v1/label/service/values | grep -q "\"$1\""; }
loki_query() { docker compose exec -T prometheus wget -qO- 'http://loki:3100/loki/api/v1/query_range?limit=1&query=%7Bservice%3D%22nginx%22%7D' | grep -q '"stream"'; }

no_public_ports() { [ "$(docker ps --format '{{.Names}} {{.Ports}}' | grep '^sv-' | grep '0.0.0.0' | grep -v '^sv-nginx ' | wc -l)" -eq 0 ]; }

echo "Dang tao luu luong mau (de Prometheus va Loki co du lieu)..."
for i in $(seq 1 15); do curl -ks "$H/api/sinhvien" >/dev/null; curl -ks "$H/api/diem" >/dev/null; done
curl -ks "$H/khong-ton-tai" >/dev/null
sleep 25

echo
echo "=== 1. Ha tang Docker Compose ==="
check "Du 12 container dang chay" running12
check "MySQL o trang thai healthy" db_healthy

echo "=== 2. Ung dung + Database + phpMyAdmin ==="
check "Website tra ve 200 qua HTTPS" test "$(http_code "$H/health")" = 200
check "API doc duoc du lieu tu MySQL" bash -c 'curl -ks "$H/api/sinhvien" | grep -q ma_sv'
check "CRUD: them - sua - xoa sinh vien" crud_test
check "phpMyAdmin truy cap duoc" bash -c 'curl -ks -o /dev/null -w "%{http_code}" "$H/phpmyadmin/" | grep -qE "^(200|302)$"'

echo "=== 3. Nginx reverse proxy + HTTPS ==="
check "HTTP (cong 8090) chuyen huong 301 sang HTTPS" bash -c 'curl -sI http://localhost:8090/ | head -1 | grep -q 301'
check "TLS 1.2 hoac 1.3" tls_ok
check "Header Strict-Transport-Security" has_header Strict-Transport-Security
check "Header Content-Security-Policy" has_header Content-Security-Policy
check "Header X-Frame-Options" has_header X-Frame-Options
check "Header X-Content-Type-Options" has_header X-Content-Type-Options
check "Khong lo X-Powered-By" bash -c '! curl -ksI "$H/" | grep -qi x-powered-by'
check "/metrics bi chan tu ben ngoai (404)" test "$(http_code "$H/metrics")" = 404

echo "=== 4. Prometheus + Grafana ==="
check "6 target Prometheus deu UP" targets_up
check "mysql_up = 1" eq mysql_up 1
check "nginx_up = 1" eq nginx_up 1
check "cAdvisor thay ten container (>= 9)" ge 'count(container_memory_working_set_bytes{name!=""})' 9
check "App co metrics request" ge 'sum(http_requests_total)' 1
check "Grafana co dashboard 'Quan ly sinh vien'" gf_has "search?query=Quan" sinhvien
check "Grafana co datasource Prometheus" gf_has datasources Prometheus
check "Grafana co datasource Loki" gf_has datasources Loki

echo "=== 5. Loki + Promtail ==="
check "Loki san sang" loki_ready
check "Loki co log cua dich vu app" loki_label app
check "Loki co log cua dich vu nginx" loki_label nginx
check "Truy van LogQL {service=\"nginx\"} tra ve log" loki_query

echo "=== 6. Hardening ==="
check "App chay bang user thuong (khong phai root)" bash -c '[ "$(docker exec sv-app id -u)" != 0 ]'
check "App: he thong file chi doc" bash -c '[ "$(docker inspect -f "{{.HostConfig.ReadonlyRootfs}}" sv-app)" = true ]'
check "App co gioi han RAM" bash -c '[ "$(docker inspect -f "{{.HostConfig.Memory}}" sv-app)" -gt 0 ]'
check "MySQL khong mo cong ra may" bash -c '[ -z "$(docker port sv-mysql-db)" ]'
check "MySQL khong ra duoc Internet" bash -c '! docker exec sv-mysql-db timeout 5 bash -c "cat < /dev/null > /dev/tcp/8.8.8.8/53"'
check "Chi co Nginx mo cong 0.0.0.0" no_public_ports
check "Cong cu 3200 cua app da dong" bash -c '! curl -s --max-time 3 http://localhost:3200/health'
check "Khong con mat khau mau trong .env" bash -c '! grep -q DoiMatKhau .env'
check ".env khong nam trong Git" bash -c '! git ls-files | grep -qE "(^|/)\.env$"'

echo "=== 7. GitHub ==="
check "Co it nhat 3 commit" bash -c '[ "$(git rev-list --count HEAD)" -ge 3 ]'

echo
echo "================ TONG KET: $PASS PASS / $FAIL FAIL ================"
[ "$FAIL" -eq 0 ]
