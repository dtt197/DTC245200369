import json, os

DS = {"type": "loki", "uid": "loki"}
panels, n = [], 0


def panel(kind, title, expr, x, y, w, h, legend=""):
    global n
    n += 1
    p = {
        "id": n, "type": kind, "title": title, "datasource": DS,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": [{"datasource": DS, "expr": expr, "legendFormat": legend,
                     "queryType": "range", "refId": "A"}],
        "fieldConfig": {"defaults": {}, "overrides": []},
    }
    if kind == "logs":
        p["options"] = {"showTime": True, "wrapLogMessage": True,
                        "sortOrder": "Descending", "enableLogDetails": True}
    panels.append(p)


panel("timeseries", "Toc do log moi dich vu (dong/giay)",
      'sum by (service) (rate({service=~".+"}[1m]))', 0, 0, 12, 8, "{{service}}")
panel("timeseries", "Nginx: so request theo ma trang thai",
      'sum by (status) (count_over_time({service="nginx"}[1m]))', 12, 0, 12, 8, "{{status}}")
panel("logs", "App: log JSON", '{service="app"}', 0, 8, 12, 10)
panel("logs", "Nginx: request loi 4xx/5xx", '{service="nginx", status=~"[45].."}', 12, 8, 12, 10)
panel("logs", "App: log muc error", '{service="app", level="error"}', 0, 18, 24, 8)

dash = {
    "uid": "sinhvien-logs",
    "title": "Quan ly sinh vien - Log tap trung",
    "tags": ["sinhvien", "loki"],
    "timezone": "browser",
    "schemaVersion": 39,
    "version": 1,
    "refresh": "15s",
    "time": {"from": "now-30m", "to": "now"},
    "panels": panels,
}

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dashboards", "sinhvien-logs.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(dash, f, ensure_ascii=False, indent=2)
print("Da tao", out, "-", len(panels), "panel")
