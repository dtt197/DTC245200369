# Hệ thống Quản lý Sinh viên — DTC245200369

Đề 2: website quản lý **lớp, sinh viên, điểm số** (CRUD), triển khai hoàn toàn bằng **Docker Compose**
(12 container): MySQL + phpMyAdmin, Nginx reverse proxy HTTPS, Prometheus + Grafana, Loki + Promtail, hardening.

## Kiến trúc
Trình duyệt
| HTTPS :8443 (HTTP :8090 -> 301 -> HTTPS)
v
[ nginx ] TLS, security headers, rate limit
|-- / -> app:3000 -> mysql-db:3306
|-- /phpmyadmin/ -> phpmyadmin -> mysql-db:3306
|-- /grafana/ -> grafana:3000 -> prometheus, loki

Metrics: app/metrics, cadvisor, node-exporter, mysqld-exporter, nginx-exporter --> prometheus
Log: promtail (docker.sock) --> loki --> grafana

| Thành phần | Công nghệ |
|---|---|
| Ứng dụng | Node.js 22 + Express (REST API + giao diện web) |
| CSDL | MySQL 8.0 + phpMyAdmin 5.2 |
| Reverse proxy | Nginx 1.27 (HTTPS tự ký, security headers, rate limiting) |
| Giám sát | Prometheus 3.2 + Grafana 11.5 + cAdvisor, node-exporter, mysqld-exporter, nginx-exporter |
| Log tập trung | Loki 3.4 + Promtail 3.4 (LogQL) |

Ba mạng Docker: `db_net` (internal, không ra Internet), `web_net`, `monitor_net`.
Bốn volume bền vững: `mysql_data`, `prometheus_data`, `grafana_data`, `loki_data`.

## Yêu cầu

- Docker Engine + Docker Compose v2, `git`, `openssl`, `python3`, `curl`
- Các cổng trống: **8443**, **8090**, **9099**
- RAM tối thiểu khoảng 4 GB

## Chạy nhanh

```bash
git clone git@github.com:dtt197/DTC245200369.git
cd DTC245200369
./scripts/setup.sh          # tạo .env (mật khẩu ngẫu nhiên), chứng chỉ SSL, dựng hệ thống (3-5 phút)
./scripts/demo-check.sh     # kiểm tra toàn hệ thống, in PASS/FAIL từng mục
```

Cách chạy thủ công (tương đương `setup.sh`):

```bash
cp .env.example .env        # rồi đổi toàn bộ mật khẩu trong .env
./nginx/gen-cert.sh
docker compose up -d --build
./db/create-exporter-user.sh
docker compose restart mysqld-exporter
```

## Truy cập

| Dịch vụ | Địa chỉ | Tài khoản |
|---|---|---|
| Website | https://localhost:8443 | không cần |
| phpMyAdmin | https://localhost:8443/phpmyadmin/ | `root` / `MYSQL_ROOT_PASSWORD` trong `.env` |
| Grafana | https://localhost:8443/grafana/ | `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` trong `.env` |
| Prometheus | http://localhost:9099 | không cần (chỉ nghe trên 127.0.0.1) |

Trình duyệt sẽ cảnh báo "Not secure" vì chứng chỉ **tự ký**: bấm *Advanced → Continue to localhost*.
Dữ liệu vẫn được mã hóa; chỉ là không có CA nào bảo lãnh danh tính.

## Dashboard Grafana

Nạp tự động từ file, nằm trong thư mục **Sinh vien**:

- **Quan ly sinh vien - Tong quan**: CPU/RAM máy chủ và từng container, MySQL, Nginx, độ trễ ứng dụng.
- **Quan ly sinh vien - Log tap trung**: log app và Nginx từ Loki.

## Truy vấn LogQL mẫu

Vào Grafana → **Explore** → nguồn **Loki** → chế độ **Code**:

```logql
{service="app"}
{service="nginx", status=~"[45].."}
{service="app"} |= "error"
{service="nginx", status="429"}
sum by (service) (rate({service=~".+"}[1m]))
```

## Hardening đã áp dụng

| Biện pháp | Chi tiết |
|---|---|
| Container không chạy root | app `node`, Grafana `grafana`, Prometheus `nobody` |
| Cô lập mạng | MySQL ở mạng `internal`, không mở cổng, không ra Internet; chỉ Nginx mở cổng ra máy |
| Security headers | HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, COOP |
| TLS | Chỉ TLS 1.2 và 1.3; ẩn phiên bản Nginx; `/metrics` bị chặn từ bên ngoài |
| Rate limiting | 30 request/giây mỗi IP (burst 60), vượt quá trả `429` |
| Mật khẩu | Ngẫu nhiên 24 ký tự (`scripts/rotate-passwords.sh`), `.env` không đưa lên Git |
| Khóa container app | `read_only`, `cap_drop: ALL`, `no-new-privileges`, giới hạn tiến trình |
| Giới hạn tài nguyên | `mem_limit` và `cpus` cho mọi container |
| Tài khoản DB tối thiểu | `exporter` chỉ có PROCESS, REPLICATION CLIENT, SELECT, tối đa 3 kết nối |

cAdvisor là ngoại lệ có chủ ý: cần `privileged: true` để đọc cgroup của container khác;
được giảm rủi ro bằng cách không mở cổng, chỉ nằm trong `monitor_net` và mọi thư mục gắn `:ro`.

## Cấu trúc thư mục
app/ Express: server.js, Dockerfile, public/index.html
db/ init.sql, create-exporter-user.sh
nginx/ conf.d/, snippets/, gen-cert.sh (certs/ tạo khi cài, không đưa lên Git)
monitoring/ prometheus/, grafana/ (provisioning + dashboards), loki/, promtail/
scripts/ setup.sh, demo-check.sh, rotate-passwords.sh
docker-compose.yml, .env.example

## Lệnh thường dùng

```bash
docker compose ps                         # trạng thái 12 container
docker compose logs -f --tail 50 app      # xem log một dịch vụ
docker compose down                       # dừng (giữ dữ liệu)
docker compose down -v                    # dừng và XÓA dữ liệu
./scripts/rotate-passwords.sh             # đổi mật khẩu ngẫu nhiên
```

## Lỗi thường gặp

| Triệu chứng | Cách xử lý |
|---|---|
| `port is already allocated` | Đóng ứng dụng đang giữ cổng 8443, 8090 hoặc 9099 |
| cAdvisor không thấy tên container, log báo `client version 1.41 is too old` | Docker 29 từ chối API cũ. Tạm thời đặt `DOCKER_MIN_API_VERSION=1.24` cho dịch vụ Docker rồi khởi động lại (chỉ phù hợp môi trường lab) |
| `mysql_up = 0` hoặc target `mysql` bị down | Chạy lại `./db/create-exporter-user.sh` rồi `docker compose restart mysqld-exporter` |
| Grafana báo sai mật khẩu | Dùng `GRAFANA_ADMIN_PASSWORD` trong `.env`, không phải `admin/admin` |
| Sửa `db/init.sql` mà dữ liệu không đổi | Script chỉ chạy lần đầu; muốn nạp lại: `docker compose down -v` rồi chạy lại |

## Tác giả

- Mã sinh viên: **DTC245200369**
- GitHub: https://github.com/dtt197/DTC245200369
