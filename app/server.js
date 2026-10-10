const express = require('express');
const mysql = require('mysql2/promise');
const client = require('prom-client');

const app = express();
app.use(express.json());

// ---------- Metrics (Prometheus se doc o buoc 4) ----------
client.collectDefaultMetrics();
const httpTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Tong so request HTTP',
  labelNames: ['method', 'route', 'status'],
});
const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Thoi gian xu ly request',
  labelNames: ['method', 'route'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2],
});

// ---------- Log JSON ra stdout (Loki se doc o buoc 5) ----------
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    if (req.path === '/metrics' || req.path === '/health') return;
    const sec = Number(process.hrtime.bigint() - start) / 1e9;
    const route = req.route ? req.baseUrl + req.route.path : 'other';
    httpTotal.inc({ method: req.method, route, status: res.statusCode });
    httpDuration.observe({ method: req.method, route }, sec);
    console.log(JSON.stringify({
      time: new Date().toISOString(),
      level: res.statusCode >= 500 ? 'error' : 'info',
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      ms: Math.round(sec * 1000),
      ip: req.headers['x-forwarded-for'] || req.ip,
    }));
  });
  next();
});

app.use(express.static('public'));

// ---------- Ket noi MySQL ----------
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  charset: 'utf8mb4',
});

const wrap = (fn) => (req, res) =>
  fn(req, res).catch((err) => {
    console.error(JSON.stringify({
      time: new Date().toISOString(), level: 'error', msg: err.message, code: err.code,
    }));
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Du lieu bi trung (ma da ton tai)' });
    if (err.code === 'ER_NO_REFERENCED_ROW_2') return res.status(400).json({ error: 'Lop hoac sinh vien khong ton tai' });
    if (err.code === 'ER_CHECK_CONSTRAINT_VIOLATED') return res.status(400).json({ error: 'Diem phai tu 0 den 10' });
    res.status(500).json({ error: 'Loi may chu' });
  });

// ---------- Sinh ra 4 thao tac CRUD cho moi bang ----------
function crud(name, table, fields, listSql) {
  const base = '/api/' + name;

  app.get(base, wrap(async (req, res) => {
    const [rows] = await pool.query(listSql);
    res.json(rows);
  }));

  app.post(base, wrap(async (req, res) => {
    const vals = fields.map((f) => req.body[f]);
    if (vals.some((v) => v === undefined || v === '' || v === null)) {
      return res.status(400).json({ error: 'Thieu du lieu' });
    }
    const sql = 'INSERT INTO ' + table + ' (' + fields.join(',') + ') VALUES (' + fields.map(() => '?').join(',') + ')';
    const [r] = await pool.query(sql, vals);
    res.status(201).json({ id: r.insertId });
  }));

  app.put(base + '/:id', wrap(async (req, res) => {
    const vals = fields.map((f) => req.body[f]);
    if (vals.some((v) => v === undefined || v === '' || v === null)) {
      return res.status(400).json({ error: 'Thieu du lieu' });
    }
    const sql = 'UPDATE ' + table + ' SET ' + fields.map((f) => f + '=?').join(',') + ' WHERE id=?';
    const [r] = await pool.query(sql, [...vals, req.params.id]);
    if (r.affectedRows === 0) return res.status(404).json({ error: 'Khong tim thay' });
    res.json({ ok: true });
  }));

  app.delete(base + '/:id', wrap(async (req, res) => {
    const [r] = await pool.query('DELETE FROM ' + table + ' WHERE id=?', [req.params.id]);
    if (r.affectedRows === 0) return res.status(404).json({ error: 'Khong tim thay' });
    res.json({ ok: true });
  }));
}

crud('lop', 'lop', ['ma_lop', 'ten_lop'],
  'SELECT * FROM lop ORDER BY id');

crud('sinhvien', 'sinh_vien', ['ma_sv', 'ho_ten', 'email', 'lop_id'],
  'SELECT s.*, l.ten_lop FROM sinh_vien s LEFT JOIN lop l ON l.id = s.lop_id ORDER BY s.id');

crud('diem', 'diem', ['sinh_vien_id', 'mon_hoc', 'diem'],
  'SELECT d.*, s.ma_sv, s.ho_ten FROM diem d JOIN sinh_vien s ON s.id = d.sinh_vien_id ORDER BY d.id');

// ---------- Health + Metrics ----------
app.get('/health', wrap(async (req, res) => {
  await pool.query('SELECT 1');
  res.json({ status: 'ok' });
}));

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(3000, '0.0.0.0', () => {
  console.log(JSON.stringify({ time: new Date().toISOString(), level: 'info', msg: 'Server dang chay o cong 3000' }));
});
