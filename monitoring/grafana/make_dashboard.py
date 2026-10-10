import json, os

DS = {"type": "prometheus", "uid": "prometheus"}
panels, n = [], 0


def panel(kind, title, exprs, x, y, w, h, unit="short"):
    global n
    n += 1
    p = {
        "id": n, "type": kind, "title": title, "datasource": DS,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": [
            {"datasource": DS, "expr": e, "legendFormat": l, "refId": chr(65 + i)}
            for i, (e, l) in enumerate(exprs)
        ],
        "fieldConfig": {"defaults": {"unit": unit}, "overrides": []},
    }
    if kind == "stat":
        p["options"] = {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False}}
    panels.append(p)


# Hang 1: tong quan
panel("stat", "Target dang UP", [("sum(up)", "")], 0, 0, 4, 4)
panel("stat", "MySQL up", [("mysql_up", "")], 4, 0, 4, 4)
panel("stat", "Nginx up", [("nginx_up", "")], 8, 0, 4, 4)
panel("stat", "Ket noi MySQL", [("mysql_global_status_threads_connected", "")], 12, 0, 4, 4)
panel("stat", "Nginx ket noi active", [("nginx_connections_active", "")], 16, 0, 4, 4)
panel("stat", "Container dang chay",
      [('count(container_memory_working_set_bytes{name!=""})', "")], 20, 0, 4, 4)

# Hang 2: may chu (node-exporter)
panel("timeseries", "CPU may chu (%)",
      [('100 - avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100', "CPU")],
      0, 4, 8, 8, "percent")
panel("timeseries", "RAM may chu (%)",
      [("100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)", "RAM")],
      8, 4, 8, 8, "percent")
panel("timeseries", "Dia da dung (%)",
      [('100 - 100 * node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}', "/")],
      16, 4, 8, 8, "percent")

# Hang 3: tung container (cAdvisor)
panel("timeseries", "CPU tung container (%)",
      [('sum by (name) (rate(container_cpu_usage_seconds_total{name!=""}[2m])) * 100', "{{name}}")],
      0, 12, 12, 8, "percent")
panel("timeseries", "RAM tung container",
      [('sum by (name) (container_memory_working_set_bytes{name!=""})', "{{name}}")],
      12, 12, 12, 8, "bytes")

# Hang 4: MySQL va Nginx
panel("timeseries", "MySQL: truy van moi giay",
      [("rate(mysql_global_status_queries[2m])", "queries/s")], 0, 20, 8, 8, "ops")
panel("timeseries", "MySQL: ket noi hien tai va toi da",
      [("mysql_global_status_threads_connected", "dang ket noi"),
       ("mysql_global_variables_max_connections", "toi da")], 8, 20, 8, 8)
panel("timeseries", "Nginx: request moi giay",
      [("rate(nginx_http_requests_total[2m])", "requests/s")], 16, 20, 8, 8, "reqps")

# Hang 5: ung dung
panel("timeseries", "App: request theo ma trang thai",
      [("sum by (status) (rate(http_requests_total[2m]))", "{{status}}")], 0, 28, 12, 8, "reqps")
panel("timeseries", "App: do tre p95",
      [("histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))", "p95")],
      12, 28, 12, 8, "s")

dash = {
    "uid": "sinhvien-overview",
    "title": "Quan ly sinh vien - Tong quan",
    "tags": ["sinhvien"],
    "timezone": "browser",
    "schemaVersion": 39,
    "version": 1,
    "refresh": "15s",
    "time": {"from": "now-30m", "to": "now"},
    "panels": panels,
}

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dashboards", "sinhvien-overview.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(dash, f, ensure_ascii=False, indent=2)
print("Da tao", out, "-", len(panels), "panel")
