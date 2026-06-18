const express = require('express');
const mysql = require('mysql2/promise');
const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const app = express();
app.use(express.json({ limit: '1mb' }));

// ── File upload setup (proof images) ─────────────────────────────
const UPLOADS_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
  filename: (_req, file, cb) => {
    const safeName = Date.now() + '-' + Math.random().toString(36).slice(2, 8) + path.extname(file.originalname).toLowerCase();
    cb(null, safeName);
  },
});

const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

const upload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE, files: 5 },
  fileFilter: (_req, file, cb) => {
    if (ALLOWED_MIME.includes(file.mimetype)) return cb(null, true);
    cb(new Error(`不支持的文件类型: ${file.mimetype}。仅支持 JPG、PNG、WebP、HEIC`));
  },
});

// Serve uploaded files statically (also served by nginx in production)
app.use('/uploads', express.static(UPLOADS_DIR));

// ── CORS (Android app makes cross-origin requests) ──────────────
app.use((_req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (_req.method === 'OPTIONS') return res.status(204).end();
  next();
});

// ── Simple in-memory token store (survives until server restart) ──
const tokenStore = new Map(); // token -> { userId, role, createdAt }

function createToken(userId, role) {
  const token = 'bnbu-' + crypto.randomUUID();
  tokenStore.set(token, { userId, role, createdAt: Date.now() });
  return token;
}

function verifyPassword(plain, stored) {
  // stored format: "hash:salt:iterations"
  // For legacy plaintext passwords (seed data), compare directly
  if (!stored.includes(':')) {
    return plain === stored;
  }
  const [hash, salt, iterations] = stored.split(':');
  const derived = crypto.pbkdf2Sync(plain, salt, parseInt(iterations), 64, 'sha512').toString('hex');
  return derived === hash;
}

// ── Auth middleware (token-based — supports both legacy demo-token and new tokens) ──
function requireAuth(req, res, next) {
  const auth = (req.headers.authorization || '').replace('Bearer ', '');
  if (!auth) return res.status(401).json({ code: 'AUTH_REQUIRED', message: '未登录' });

  // Support legacy demo-token-{userId} format during transition
  const legacyMatch = auth.match(/^demo-token-(.+)$/);
  if (legacyMatch) {
    req.userId = legacyMatch[1];
    req.userRole = null;
    return next();
  }

  // New token format
  const stored = tokenStore.get(auth);
  if (!stored) return res.status(401).json({ code: 'TOKEN_EXPIRED', message: 'Token 无效或已过期' });
  req.userId = stored.userId;
  req.userRole = stored.role;
  next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    requireAuth(req, res, () => {
      // For legacy demo-tokens, allow all roles (transition period)
      if (!req.userRole) return next();
      if (roles.includes(req.userRole)) return next();
      return res.status(403).json({ code: 'FORBIDDEN', message: '无权访问此资源' });
    });
  };
}

// ── MySQL pool ──────────────────────────────────────────────────
const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || '123_207_5_70_96',
  password: process.env.DB_PASSWORD || 'Bd84EKfpw3XSmheB',
  database: process.env.DB_NAME || '123_207_5_70_96',
  waitForConnections: true,
  connectionLimit: 10,
});

// ── Health ───────────────────────────────────────────────────────
app.get('/api/health', async (_req, res) => {
  try {
    const [rows] = await pool.query('SELECT 1 AS ok');
    res.json({ ok: true, service: 'BNBU Sports API', db: rows.length > 0, time: new Date().toISOString() });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── Upload proof image ──────────────────────────────────────────────
app.post('/api/upload/proof', requireAuth, (req, res) => {
  upload.array('files', 5)(req, res, (err) => {
    if (err) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({ code: 'FILE_TOO_LARGE', message: '文件过大，单张图片不超过 10MB' });
      }
      if (err.code === 'LIMIT_FILE_COUNT') {
        return res.status(413).json({ code: 'TOO_MANY_FILES', message: '一次最多上传 5 张图片' });
      }
      return res.status(400).json({ code: 'UPLOAD_FAILED', message: err.message });
    }
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ code: 'NO_FILE', message: '请选择要上传的图片' });
    }
    const urls = req.files.map((f) => '/uploads/' + f.filename);
    res.json({ urls, count: urls.length });
  });
});

// ── Auth (real password verification, proper tokens) ──────────────
app.post('/api/auth/login', async (req, res) => {
  try {
    const { account, password } = req.body || {};
    if (!account || !password) return res.status(400).json({ code: 'VALIDATION', message: '请输入账号和密码' });

    const [rows] = await pool.query(
      'SELECT id, name, email, role, college, gender, grade_level, status, password FROM users WHERE email = ? OR id = ?',
      [account, account]
    );
    const user = rows[0];
    if (!user) return res.status(401).json({ code: 'AUTH_FAILED', message: '账号或密码错误' });

    if (!verifyPassword(password, user.password)) {
      return res.status(401).json({ code: 'AUTH_FAILED', message: '账号或密码错误' });
    }

    const token = createToken(user.id, user.role);
    const routeMap = { teacher: 'teacher-dashboard', admin: 'admin-dashboard', manager: 'manager-dashboard', student: 'student-dashboard' };
    res.json({
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role, college: user.college || '', gender: user.gender || '', gradeLevel: user.grade_level || '', scope: user.role === 'student' ? user.college : '全校', status: user.status || '正常' },
      defaultRoute: routeMap[user.role] || 'student-dashboard'
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.get('/api/auth/me', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, name, email, role, college, gender, grade_level, status FROM users WHERE id = ?', [req.userId]);
    const user = rows[0];
    if (!user) return res.status(404).json({ code: 'NOT_FOUND', message: '用户不存在' });
    const routeMap = { teacher: ['teacher-dashboard', 'teacher-courses'], admin: ['admin-dashboard'], manager: ['manager-memberships'], student: ['student-dashboard'] };
    res.json({ user: { id: user.id, name: user.name, email: user.email, role: user.role, college: user.college || '', gender: user.gender || '', gradeLevel: user.grade_level || '', scope: user.college || '全校', status: user.status }, routes: routeMap[user.role] || [] });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.post('/api/auth/logout', requireAuth, async (req, res) => {
  const auth = (req.headers.authorization || '').replace('Bearer ', '');
  tokenStore.delete(auth);
  res.json({ ok: true });
});

// ── Teacher: courses ────────────────────────────────────────────
app.get('/api/teacher/courses', requireAuth, async (req, res) => {
  try {
    const teacherId = req.userId;
    let sql, params;
    if (req.userRole === 'admin') {
      // Admin sees all courses with teacher names
      sql = `SELECT c.*, u.name AS teacher, COUNT(sp.student_id) AS actualStudents
             FROM courses c
             LEFT JOIN users u ON c.teacher_id = u.id
             LEFT JOIN student_progress sp ON c.id = sp.course_id
             GROUP BY c.id`;
      params = [];
    } else {
      // Teacher sees only their own courses
      sql = `SELECT c.*, u.name AS teacher, COUNT(sp.student_id) AS actualStudents
             FROM courses c
             LEFT JOIN users u ON c.teacher_id = u.id
             LEFT JOIN student_progress sp ON c.id = sp.course_id
             WHERE c.teacher_id = ?
             GROUP BY c.id`;
      params = [teacherId];
    }
    const [rows] = await pool.query(sql, params);
    const result = rows.map((r) => ({ ...r, students: r.actualStudents || r.students, pending: 0, completion: 63, missing: 0 }));
    res.json(result);
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.get('/api/teacher/courses/:courseId/dashboard', requireAuth, async (req, res) => {
  const [courses] = await pool.query('SELECT * FROM courses WHERE id = ?', [req.params.courseId]);
  const course = courses[0];
  if (!course) return res.status(404).json({ code: 'NOT_FOUND', message: '课程不存在' });
  res.json({ ...course, students: course.students, pending: 24, completion: 63, missing: 19, courseHours: '6.4', generalHours: '8.8', exportState: '待清理' });
});

// ── Teacher: students ───────────────────────────────────────────
app.get('/api/teacher/courses/:courseId/students', requireAuth, async (req, res) => {
  try {
    const { keyword, status } = req.query;
    let sql = `SELECT u.id, u.name, u.college, sp.course_hours AS course, sp.general_hours AS general, sp.exam_score AS exam, sp.attendance_score AS attendance, sp.physical_score AS physical, sp.status FROM student_progress sp JOIN users u ON sp.student_id = u.id WHERE sp.course_id = ?`;
    const params = [req.params.courseId];
    if (keyword) { sql += ' AND (u.name LIKE ? OR u.id LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`); }
    if (status && status !== 'all') {
      const map = { complete: '已完成', incomplete: '未完成', risk: '风险较高' };
      if (map[status]) { sql += ' AND sp.status = ?'; params.push(map[status]); }
    }
    const [rows] = await pool.query(sql, params);
    res.json(rows.map((r) => ({ ...r, rawGeneral: r.general, className: '', organizationCredit: null, source: 'seed' })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: tasks ──────────────────────────────────────────────
app.get('/api/teacher/courses/:courseId/tasks', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT t.*, c.code AS course_code, c.section AS course_section, c.name AS course_name FROM tasks t JOIN courses c ON t.course_id = c.id WHERE t.course_id = ? ORDER BY t.created_at DESC',
      [req.params.courseId]
    );
    res.json(rows.map((r) => ({
      id: r.id, courseId: r.course_id, title: r.title, hours: r.required_hours,
      deadline: r.deadline, proof: '', status: r.status, description: r.description,
      creditType: r.credit_type, courseCode: r.course_code, courseSection: r.course_section
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: reviews ────────────────────────────────────────────
app.get('/api/teacher/courses/:courseId/reviews', requireAuth, async (req, res) => {
  try {
    const { status, keyword } = req.query;
    let sql = `SELECT r.*, sr.proof_files
      FROM reviews r
      LEFT JOIN sport_records sr ON r.record_id = sr.id
      WHERE r.course_id = ?`;
    const params = [req.params.courseId];
    if (status && status !== 'all') {
      const map = { open: '待确认', safe: '可通过', risk: '需复核', closed: '已通过' };
      if (map[status]) { sql += ' AND r.status = ?'; params.push(map[status]); }
    }
    if (keyword) { sql += ' AND (r.name LIKE ? OR r.student_id LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`); }
    const [rows] = await pool.query(sql, params);
    res.json(rows.map((r) => ({
      ...r, applied: Boolean(r.applied),
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.put('/api/teacher/reviews/:reviewId/decision', requireAuth, async (req, res) => {
  try {
    const { decision, approvedHours, comment } = req.body || {};
    const statusMap = { approve: '已通过', reject: '已驳回', supplement: '补材料' };
    const newStatus = statusMap[decision] || '待确认';
    const [result] = await pool.query('UPDATE reviews SET status = ?, approved_hours = ?, comment = ?, applied = ? WHERE id = ?', [newStatus, approvedHours || 0, comment || '', decision === 'approve' ? 1 : 0, req.params.reviewId]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '审核记录不存在' });
    const [rows] = await pool.query('SELECT * FROM reviews WHERE id = ?', [req.params.reviewId]);
    res.json({ review: { ...rows[0], applied: Boolean(rows[0].applied) }, student: { id: rows[0].student_id, name: rows[0].name } });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: scores ─────────────────────────────────────────────
app.put('/api/teacher/courses/:courseId/scores/exam', requireAuth, async (req, res) => {
  try {
    const { rows } = req.body || {};
    if (!rows) return res.status(400).json({ code: 'VALIDATION', message: '缺少 rows' });
    for (const r of rows) {
      const items = Array.isArray(r.examItems) ? r.examItems : [0];
      const avg = items.length ? Math.round(items.reduce((a, b) => a + b, 0) / items.length) : 0;
      await pool.query('UPDATE student_progress SET exam_score = ? WHERE student_id = ? AND course_id = ?', [avg, r.studentId, req.params.courseId]);
    }
    res.json({ savedCount: rows.length, updatedAt: new Date().toISOString() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.put('/api/teacher/courses/:courseId/scores/attendance', requireAuth, async (req, res) => {
  try {
    const { rows } = req.body || {};
    if (!rows) return res.status(400).json({ code: 'VALIDATION', message: '缺少 rows' });
    for (const r of rows) {
      await pool.query('UPDATE student_progress SET attendance_score = ? WHERE student_id = ? AND course_id = ?', [r.score || 0, r.studentId, req.params.courseId]);
    }
    res.json({ savedCount: rows.length, updatedAt: new Date().toISOString() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.put('/api/teacher/courses/:courseId/scores/physical', requireAuth, async (req, res) => {
  try {
    const { rows } = req.body || {};
    if (!rows) return res.status(400).json({ code: 'VALIDATION', message: '缺少 rows' });
    for (const r of rows) {
      await pool.query('UPDATE student_progress SET physical_score = ? WHERE student_id = ? AND course_id = ?', [r.score || 0, r.studentId, req.params.courseId]);
    }
    res.json({ savedCount: rows.length, updatedAt: new Date().toISOString() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: grades ─────────────────────────────────────────────
app.get('/api/teacher/courses/:courseId/grades', requireAuth, async (req, res) => {
  const [rows] = await pool.query(
    `SELECT sp.student_id AS studentId, u.name AS studentName, sp.course_hours, sp.general_hours, sp.exam_score AS exam, sp.attendance_score AS attendance, sp.physical_score AS physical
     FROM student_progress sp JOIN users u ON sp.student_id = u.id WHERE sp.course_id = ?`, [req.params.courseId]
  );
  const gradeRows = rows.map((r) => {
    const checkinScore = Math.min(25, Math.round(((r.course_hours + r.general_hours) / 20) * 25));
    const total = Math.round(checkinScore + (r.exam || 0) * 0.3 + (r.attendance || 0) * 0.2 + (r.physical || 0) * 0.25);
    return { ...r, checkinScore, total, missingItems: [] };
  });
  res.json(gradeRows);
});

// ── Teacher: export ─────────────────────────────────────────────
app.get('/api/teacher/courses/:courseId/export/precheck', requireAuth, async (_req, res) => {
  const [students] = await pool.query('SELECT * FROM student_progress WHERE course_id = ?', [_req.params.courseId]);
  const checkinNotEnough = students.filter((s) => s.course_hours < 10 || s.general_hours < 10);
  const missingPhysical = students.filter((s) => !s.physical_score);
  res.json({ missingPhysical, checkinNotEnough: checkinNotEnough.map((s) => ({ id: s.student_id, name: '', college: '', course: s.course_hours, general: s.general_hours, exam: s.exam_score, attendance: s.attendance_score, physical: s.physical_score, status: s.status })), unresolvedReviews: [], templateMatched: true });
});

// ── Admin: overview ─────────────────────────────────────────────
app.get('/api/admin/overview', requireAuth, async (_req, res) => {
  const [courses] = await pool.query('SELECT * FROM courses');
  res.json(courses.map((c) => ({ course: c, metrics: { students: c.students, pending: 0, completion: 63, missing: 0, courseHours: '6.4', generalHours: '8.8', exportState: '待清理' }, issueCount: 0, health: '正常' })));
});

// ── Admin: sport rules ──────────────────────────────────────────
app.get('/api/admin/sport-rules', requireAuth, (_req, res) => {
  res.json({ version: 'BNBU-SPORT-2026-v1', total: 20, courseRequired: 10, generalRequired: 10, dailyLimit: 2, stackAllowed: '否', organizationOffset: '抵扣其他运动 10h', status: '已发布' });
});

app.put('/api/admin/sport-rules', requireAuth, (req, res) => { res.json(req.body); });

// ── Admin: semesters ────────────────────────────────────────────
app.get('/api/admin/semesters', requireAuth, async (_req, res) => {
  const [rows] = await pool.query('SELECT * FROM semesters');
  res.json(rows);
});

// ── Admin: courses ──────────────────────────────────────────────
app.get('/api/admin/courses', requireAuth, async (_req, res) => {
  const [rows] = await pool.query('SELECT c.*, u.name AS teacher FROM courses c LEFT JOIN users u ON c.teacher_id = u.id');
  res.json(rows);
});

// ── Admin: users ────────────────────────────────────────────────
app.get('/api/admin/users', requireAuth, async (_req, res) => {
  const [rows] = await pool.query('SELECT id, name, email, role, college, status FROM users');
  res.json(rows);
});

// ── Admin: logs ─────────────────────────────────────────────────
app.get('/api/admin/logs', requireAuth, async (_req, res) => {
  const [rows] = await pool.query('SELECT * FROM audit_logs ORDER BY time DESC LIMIT 50');
  res.json({ items: rows });
});

// ── Student: sport summary ───────────────────────────────────────
app.get('/api/sport/summary', requireAuth, async (req, res) => {
  try {
    const studentId = req.userId;
    const [progress] = await pool.query(
      `SELECT sp.student_id, sp.course_id, sp.course_hours, sp.general_hours,
              c.code AS course_code, c.section AS course_section, c.name AS course_name,
              c.teacher_id, u.name AS teacher_name
       FROM student_progress sp
       JOIN courses c ON sp.course_id = c.id
       LEFT JOIN users u ON c.teacher_id = u.id
       WHERE sp.student_id = ?`, [studentId]
    );
    const course = progress.reduce((s, r) => s + Number(r.course_hours || 0), 0);
    const general = progress.reduce((s, r) => s + Number(r.general_hours || 0), 0);
    const [pending] = await pool.query(
      `SELECT COUNT(*) AS cnt FROM sport_records WHERE student_id = ? AND status = '待审核'`, [studentId]
    );
    const rule = { total: 20, courseRequired: 10, generalRequired: 10, dailyLimit: 2 };
    const totalCompleted = Math.min(course, rule.courseRequired) + Math.min(general, rule.generalRequired);

    // Build teacher list from progress rows (deduplicated by teacher_id)
    const teachers = [];
    const seenTeacherIds = new Set();
    for (const r of progress) {
      if (r.teacher_id && !seenTeacherIds.has(r.teacher_id)) {
        seenTeacherIds.add(r.teacher_id);
        teachers.push({ teacherId: r.teacher_id, teacherName: r.teacher_name || '' });
      }
    }

    // Build course list for the student app
    const courses = progress.map((r) => ({
      courseId: r.course_id,
      courseCode: r.course_code,
      courseSection: r.course_section,
      courseName: r.course_name,
      teacherId: r.teacher_id || '',
      teacherName: r.teacher_name || '',
      courseHours: Number(r.course_hours || 0),
      generalHours: Number(r.general_hours || 0)
    }));

    res.json({
      courseHours: course, generalHours: general,
      totalCompleted, totalRequired: rule.total,
      totalRemaining: Math.max(0, rule.total - totalCompleted),
      courseRemaining: Math.max(0, rule.courseRequired - course),
      generalRemaining: Math.max(0, rule.generalRequired - general),
      completed: totalCompleted >= rule.total,
      pendingCount: pending[0]?.cnt || 0, rule,
      teachers, courses
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: submit sport record ─────────────────────────────────
app.post('/api/sport/records', requireAuth, async (req, res) => {
  try {
    const studentId = req.userId;
    const { creditType, courseId, taskId, hours, description, proofFiles } = req.body || {};
    if (!creditType || hours == null) {
      return res.status(400).json({ code: 'VALIDATION', message: '缺少必填字段' });
    }
    if (hours < 0.5 || hours > 2) {
      return res.status(400).json({ code: 'VALIDATION', message: '小时数须在 0.5–2 之间' });
    }

    // Daily limit check (use local date: UTC+8 for BNBU campus)
    const now = new Date();
    const localDate = new Date(now.getTime() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const [todayRows] = await pool.query(
      `SELECT COALESCE(SUM(hours), 0) AS todayHours FROM sport_records
       WHERE student_id = ? AND DATE(submitted_at) = ?`, [studentId, localDate]
    );
    if (Number(todayRows[0].todayHours) + hours > 2) {
      return res.status(400).json({ code: 'DAILY_LIMIT', message: '当日学时已达上限 (2h)' });
    }

    const id = 'sr-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
    await pool.query(
      `INSERT INTO sport_records (id, student_id, course_id, task_id, credit_type, hours, description, proof_files, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, '待审核')`,
      [id, studentId, courseId || null, taskId || null, creditType, hours, description || '', JSON.stringify(proofFiles || [])]
    );

    // Create linked review row for teacher visibility
    const reviewId = 'r-' + id;
    await pool.query(
      `INSERT INTO reviews (id, course_id, student_id, type, hours, status, task, reason, record_id)
       VALUES (?, ?, ?, ?, ?, '待确认', ?, ?, ?)`,
      [reviewId, courseId || 'general', studentId, creditType, hours, taskId || '自主打卡', '学生提交', id]
    );

    // Auto-notification
    const notifId = 'n-' + id;
    await pool.query(
      `INSERT INTO notifications (id, student_id, title, message, category) VALUES (?, ?, ?, ?, '审核反馈')`,
      [notifId, studentId, '打卡已提交', `${creditType} ${hours}h 已提交，等待老师审核`]
    );

    res.json({ id, status: '待审核', submittedAt: new Date().toISOString() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: list sport records ──────────────────────────────────
app.get('/api/sport/records', requireAuth, async (req, res) => {
  try {
    const studentId = req.userId;
    const { status, creditType } = req.query;
    let sql = 'SELECT * FROM sport_records WHERE student_id = ?';
    const params = [studentId];

    if (status && status !== 'all') {
      const map = { pending: '待审核', approved: '已通过', rejected: '已驳回', supplement: '补材料', offset: '系统抵扣' };
      if (map[status]) { sql += ' AND status = ?'; params.push(map[status]); }
    }
    if (creditType && creditType !== 'all') {
      const map = { course_related: '课程相关', general_sport: '其他运动' };
      if (map[creditType]) { sql += ' AND credit_type = ?'; params.push(map[creditType]); }
    }
    sql += ' ORDER BY submitted_at DESC LIMIT 100';

    const [rows] = await pool.query(sql, params);
    res.json(rows.map((r) => ({
      id: r.id, courseId: r.course_id, taskId: r.task_id, creditType: r.credit_type,
      hours: r.hours, approvedHours: r.approved_hours, description: r.description,
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
      status: r.status, reviewComment: r.review_comment, submittedAt: r.submitted_at, reviewedAt: r.reviewed_at
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: single sport record detail ──────────────────────────
app.get('/api/sport/records/:id', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM sport_records WHERE id = ? AND student_id = ?', [req.params.id, req.userId]);
    if (rows.length === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '记录不存在' });
    const r = rows[0];
    res.json({
      id: r.id, courseId: r.course_id, taskId: r.task_id, creditType: r.credit_type,
      hours: r.hours, approvedHours: r.approved_hours, description: r.description,
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
      status: r.status, reviewComment: r.review_comment, submittedAt: r.submitted_at, reviewedAt: r.reviewed_at
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: supplement a rejected record ────────────────────────
app.post('/api/sport/records/:id/supplements', requireAuth, async (req, res) => {
  try {
    const { hours, description, proofFiles } = req.body || {};
    const [existing] = await pool.query('SELECT * FROM sport_records WHERE id = ? AND student_id = ?', [req.params.id, req.userId]);
    if (existing.length === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '记录不存在' });
    const record = existing[0];
    if (record.status !== '已驳回' && record.status !== '补材料') {
      return res.status(400).json({ code: 'INVALID_STATUS', message: '只有被驳回或需补材料的记录才能补充' });
    }

    const oldFiles = typeof record.proof_files === 'string' ? JSON.parse(record.proof_files) : (record.proof_files || []);
    const mergedFiles = [...new Set([...oldFiles, ...(proofFiles || [])])];

    await pool.query(
      `UPDATE sport_records SET hours = ?, description = ?, proof_files = ?, status = '待审核', review_comment = '补充材料已提交，等待复审' WHERE id = ?`,
      [hours || record.hours, description || record.description, JSON.stringify(mergedFiles), req.params.id]
    );

    res.json({ id: req.params.id, status: '待审核', message: '补充材料已提交' });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: sport identity (memberships) ────────────────────────
app.get('/api/sport/identity', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m
       JOIN users u ON m.student_id = u.id
       WHERE m.student_id = ? ORDER BY m.updated_at DESC`, [req.userId]
    );
    res.json(rows.map((r) => ({
      id: r.id, type: r.type, organization: r.organization, studentId: r.student_id,
      studentName: r.student_name || '', status: r.status, validUntil: r.valid_until, offset: r.offset_status,
      comment: r.comment, updatedBy: r.updated_by, updatedAt: r.updated_at
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: notifications ───────────────────────────────────────
app.get('/api/common/notifications', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM notifications WHERE student_id = ? ORDER BY created_at DESC LIMIT 50',
      [req.userId]
    );
    res.json(rows.map((r) => ({
      id: r.id, title: r.title, message: r.message, time: r.created_at,
      category: r.category, isUnread: r.is_read !== 1
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.put('/api/common/notifications/:id/read', requireAuth, async (req, res) => {
  try {
    const [result] = await pool.query(
      'UPDATE notifications SET is_read = 1 WHERE id = ? AND student_id = ?',
      [req.params.id, req.userId]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '通知不存在' });
    res.json({ id: req.params.id, read: true });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: all check-in records for a specific student ──────────
app.get('/api/teacher/students/:id/records', requireRole('teacher','admin'), async (req, res) => {
  try {
    const studentId = req.params.id;

    // Regular sport records
    const [records] = await pool.query(
      `SELECT sr.*, 'student' AS record_source FROM sport_records sr WHERE sr.student_id = ?`,
      [studentId]
    );

    // Membership-based offsets (team/club)
    const [memberships] = await pool.query(
      `SELECT m.*, 'membership' AS record_source FROM memberships m WHERE m.student_id = ?`,
      [studentId]
    );

    // Build unified record list
    const unifiedRecords = records.map((r) => ({
      id: r.id,
      source: r.record_source || 'student',
      creditType: r.credit_type,
      hours: r.hours,
      approvedHours: r.approved_hours,
      description: r.description,
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
      status: r.status,
      reviewComment: r.review_comment,
      submittedAt: r.submitted_at,
      reviewedAt: r.reviewed_at,
      courseId: r.course_id,
      taskId: r.task_id
    }));

    // Add membership offset records
    for (const m of memberships) {
      if (m.offset_status === '可抵扣' && m.status === '认证有效') {
        unifiedRecords.push({
          id: 'offset-' + m.id,
          source: m.type === 'team' ? 'team' : 'club',
          creditType: '其他运动',
          hours: 10.0,
          approvedHours: 10.0,
          description: `${m.organization} 抵扣`,
          proofFiles: [],
          status: '系统抵扣',
          reviewComment: m.comment || '',
          submittedAt: m.updated_at,
          reviewedAt: m.updated_at,
          courseId: null,
          taskId: null
        });
      }
    }

    // Also fetch basic student info
    const [users] = await pool.query(
      'SELECT id, name, gender, grade_level, college FROM users WHERE id = ?',
      [studentId]
    );
    const student = users[0] || null;

    res.json({ student, records: unifiedRecords });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Admin: membership decision ────────────────────────────────────
app.put('/api/admin/memberships/:id/decision', requireRole('admin'), async (req, res) => {
  try {
    const { status, offset, comment } = req.body || {};
    if (!status) return res.status(400).json({ code: 'VALIDATION', message: '缺少审核决定' });

    const [result] = await pool.query(
      'UPDATE memberships SET status = ?, offset_status = ?, comment = ?, updated_by = ?, updated_at = NOW() WHERE id = ?',
      [status, offset || '待确认', comment || '', req.userId, req.params.id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '成员记录不存在' });

    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m JOIN users u ON m.student_id = u.id WHERE m.id = ?`,
      [req.params.id]
    );
    res.json({ membership: rows[0] });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: confirm team/club offset (final say) ─────────────────
app.put('/api/teacher/team-offset/:id/confirm', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { confirmed } = req.body || {};
    const newStatus = confirmed ? '可抵扣' : '不抵扣';

    const [result] = await pool.query(
      'UPDATE memberships SET offset_status = ?, updated_by = ?, updated_at = NOW() WHERE id = ?',
      [newStatus, req.userId, req.params.id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '记录不存在' });

    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m JOIN users u ON m.student_id = u.id WHERE m.id = ?`,
      [req.params.id]
    );
    res.json({ membership: rows[0], confirmedBy: req.userId });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Scoring: endurance run time-to-score conversion ───────────────
app.post('/api/scoring/convert-endurance', requireAuth, async (req, res) => {
  try {
    const { timeSeconds, gender, gradeLevel } = req.body || {};
    if (timeSeconds == null || !gender || !gradeLevel) {
      return res.status(400).json({ code: 'VALIDATION', message: '缺少 timeSeconds, gender, gradeLevel' });
    }

    const gradeGroup = ['freshman','sophomore'].includes(gradeLevel)
      ? 'freshman_sophomore' : 'junior_senior';

    const [rows] = await pool.query(
      `SELECT score, tier, time_seconds_min, time_seconds_max
       FROM endurance_scoring_rules
       WHERE gender = ? AND grade_group = ? AND ? >= time_seconds_min AND ? <= time_seconds_max
       ORDER BY score DESC LIMIT 1`,
      [gender, gradeGroup, timeSeconds, timeSeconds]
    );

    if (rows.length === 0) {
      // Time faster than 100-point standard
      const [best] = await pool.query(
        `SELECT score, tier FROM endurance_scoring_rules
         WHERE gender = ? AND grade_group = ? ORDER BY score DESC LIMIT 1`,
        [gender, gradeGroup]
      );
      if (best.length > 0) {
        return res.json({ score: best[0].score, tier: best[0].tier, timeSeconds, gender, gradeLevel, gradeGroup, note: '成绩优于满分标准' });
      }
      return res.status(404).json({ code: 'NOT_FOUND', message: '未找到匹配的评分规则' });
    }

    const rule = rows[0];
    res.json({
      score: rule.score,
      tier: rule.tier,
      timeSeconds,
      gender,
      gradeLevel,
      gradeGroup,
      range: { min: rule.time_seconds_min, max: rule.time_seconds_max }
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: list my exemptions ────────────────────────────────────
app.get('/api/student/exemptions', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT e.*, u.name AS reviewer_name FROM exemptions e
       LEFT JOIN users u ON e.reviewer_id = u.id
       WHERE e.student_id = ? ORDER BY e.created_at DESC`,
      [req.userId]
    );
    res.json(rows.map((r) => ({
      id: r.id, studentId: r.student_id, type: r.type,
      reason: r.reason, status: r.status,
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
      reviewComment: r.review_comment, reviewerId: r.reviewer_id,
      reviewerName: r.reviewer_name || '',
      createdAt: r.created_at, updatedAt: r.updated_at
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.post('/api/student/exemptions', requireAuth, async (req, res) => {
  try {
    const { type, reason, proofFiles } = req.body || {};
    if (!type) return res.status(400).json({ code: 'VALIDATION', message: '请选择免测类型 (800m / 1000m)' });

    // Check for existing pending application
    const [existing] = await pool.query(
      `SELECT id FROM exemptions WHERE student_id = ? AND type = ? AND status = '待审核'`,
      [req.userId, type]
    );
    if (existing.length > 0) {
      return res.status(409).json({ code: 'DUPLICATE', message: '你已有一份待审核的同类型免测申请，请勿重复提交' });
    }

    const id = 'ex-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
    await pool.query(
      `INSERT INTO exemptions (id, student_id, type, reason, proof_files, status)
       VALUES (?, ?, ?, ?, ?, '待审核')`,
      [id, req.userId, type, reason || '', JSON.stringify(proofFiles || [])]
    );

    res.json({ id, status: '待审核', createdAt: new Date().toISOString() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Teacher: list exemptions for my students ───────────────────────
app.get('/api/teacher/exemptions', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { status } = req.query;
    let sql, params;

    if (req.userRole === 'admin') {
      sql = `SELECT e.*, u.name AS student_name, u.gender, u.grade_level, u.college
             FROM exemptions e JOIN users u ON e.student_id = u.id`;
      params = [];
    } else {
      // Teacher can only see exemptions for students in their courses
      sql = `SELECT DISTINCT e.*, u.name AS student_name, u.gender, u.grade_level, u.college
             FROM exemptions e
             JOIN users u ON e.student_id = u.id
             JOIN student_progress sp ON u.id = sp.student_id
             JOIN courses c ON sp.course_id = c.id
             WHERE c.teacher_id = ?`;
      params = [req.userId];
    }

    if (status && status !== 'all') {
      const statusMap = { pending: '待审核', approved: '已通过', rejected: '已驳回' };
      if (statusMap[status]) { sql += ' AND e.status = ?'; params.push(statusMap[status]); }
    }
    sql += ' ORDER BY e.created_at DESC';

    const [rows] = await pool.query(sql, params);
    res.json(rows.map((r) => ({
      id: r.id, studentId: r.student_id, studentName: r.student_name,
      gender: r.gender, gradeLevel: r.grade_level, college: r.college,
      type: r.type, reason: r.reason, status: r.status,
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
      reviewComment: r.review_comment, reviewerId: r.reviewer_id,
      createdAt: r.created_at, updatedAt: r.updated_at
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.put('/api/teacher/exemptions/:id/decision', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { status, comment } = req.body || {};
    if (!status || !['已通过','已驳回'].includes(status)) {
      return res.status(400).json({ code: 'VALIDATION', message: '审核结果只能为 已通过 或 已驳回' });
    }

    const [result] = await pool.query(
      'UPDATE exemptions SET status = ?, review_comment = ?, reviewer_id = ?, updated_at = NOW() WHERE id = ?',
      [status, comment || '', req.userId, req.params.id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '免测申请不存在' });

    const [rows] = await pool.query(
      `SELECT e.*, u.name AS student_name FROM exemptions e
       JOIN users u ON e.student_id = u.id WHERE e.id = ?`,
      [req.params.id]
    );
    res.json({ exemption: rows[0] });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: my tasks (pending / completed) ────────────────────────
app.get('/api/student/tasks', requireAuth, async (req, res) => {
  try {
    const studentId = req.userId;

    // Get all courses the student is enrolled in
    const [enrollments] = await pool.query(
      'SELECT course_id FROM student_progress WHERE student_id = ?',
      [studentId]
    );
    if (enrollments.length === 0) return res.json({ pending: [], completed: [] });

    const courseIds = enrollments.map((e) => e.course_id);

    // Get tasks for enrolled courses
    const [tasks] = await pool.query(
      `SELECT t.*, c.code AS course_code, c.section AS course_section, c.name AS course_name
       FROM tasks t JOIN courses c ON t.course_id = c.id
       WHERE t.course_id IN (?) AND t.status != '草稿'
       ORDER BY t.deadline ASC`,
      [courseIds]
    );

    // Check completion status: a task is "completed" if the student has an approved sport_record for it
    const [completedRecords] = await pool.query(
      `SELECT task_id FROM sport_records
       WHERE student_id = ? AND task_id IS NOT NULL AND status = '已通过'`,
      [studentId]
    );
    const completedTaskIds = new Set(completedRecords.map((r) => r.task_id));

    const pending = [];
    const completed = [];
    for (const t of tasks) {
      const taskObj = {
        id: t.id, courseId: t.course_id,
        courseCode: t.course_code, courseSection: t.course_section,
        courseName: t.course_name,
        title: t.title, description: t.description,
        creditType: t.credit_type, requiredHours: t.required_hours,
        deadline: t.deadline, status: t.status
      };
      if (completedTaskIds.has(t.id)) {
        completed.push({ ...taskObj, completedAt: null });
      } else {
        pending.push(taskObj);
      }
    }

    res.json({ pending, completed });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Student: profile read ──────────────────────────────────────────
app.get('/api/student/profile', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, email, role, college, gender, grade_level, status FROM users WHERE id = ?',
      [req.userId]
    );
    const user = rows[0];
    if (!user) return res.status(404).json({ code: 'NOT_FOUND', message: '用户不存在' });

    // Get enrolled course count
    const [enrollments] = await pool.query(
      'SELECT COUNT(*) AS cnt FROM student_progress WHERE student_id = ?',
      [req.userId]
    );

    res.json({
      id: user.id, name: user.name, email: user.email,
      role: user.role, college: user.college || '',
      gender: user.gender, gradeLevel: user.grade_level,
      status: user.status,
      enrolledCourses: enrollments[0]?.cnt || 0
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

app.put('/api/student/profile', requireAuth, async (req, res) => {
  try {
    const { gender, gradeLevel } = req.body || {};
    const updates = [];
    const params = [];

    if (gender) {
      if (!['male','female'].includes(gender)) return res.status(400).json({ code: 'VALIDATION', message: '性别只能为 male 或 female' });
      updates.push('gender = ?');
      params.push(gender);
    }
    if (gradeLevel) {
      if (!['freshman','sophomore','junior','senior'].includes(gradeLevel)) return res.status(400).json({ code: 'VALIDATION', message: '无效的年级' });
      updates.push('grade_level = ?');
      params.push(gradeLevel);
    }

    if (updates.length === 0) return res.status(400).json({ code: 'VALIDATION', message: '无有效更新字段' });

    params.push(req.userId);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);

    // Return updated profile
    const [rows] = await pool.query(
      'SELECT id, name, email, role, college, gender, grade_level, status FROM users WHERE id = ?',
      [req.userId]
    );
    res.json({ profile: rows[0] });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Admin: batch import students ────────────────────────────────────
app.post('/api/admin/import-students', requireRole('admin'), async (req, res) => {
  try {
    const { students } = req.body || {};
    if (!students || !Array.isArray(students) || students.length === 0) {
      return res.status(400).json({ code: 'VALIDATION', message: '请提供学生数据数组' });
    }

    let imported = 0;
    let skipped = 0;
    const errors = [];

    for (const s of students) {
      if (!s.id || !s.name) {
        skipped++;
        errors.push(`缺少学号或姓名: ${JSON.stringify(s)}`);
        continue;
      }
      try {
        await pool.query(
          `INSERT INTO users (id, name, email, password, role, college, gender, grade_level, status)
           VALUES (?, ?, ?, 'password123', 'student', ?, ?, ?, '正常')
           ON DUPLICATE KEY UPDATE
             name = VALUES(name), college = VALUES(college),
             gender = VALUES(gender), grade_level = VALUES(grade_level)`,
          [s.id, s.name, `${s.id}@bnbu.edu.cn`, s.college || '', s.gender || null, s.gradeLevel || null]
        );
        imported++;
      } catch (err) {
        skipped++;
        errors.push(`${s.id}: ${err.message}`);
      }
    }

    res.json({ imported, skipped, total: students.length, errors: errors.slice(0, 20) });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ──────────────────────────────────────────────────────────────────
// v4: Supplemental features — hours detail, pending certs, per-second
//     conversion table, course-scoped exemptions, org identity
// ──────────────────────────────────────────────────────────────────

// ── Feature #1A: Student hours detail (aggregated by source type) ──
app.get('/api/teacher/courses/:courseId/students/:studentId/hours-detail', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { courseId, studentId } = req.params;

    // Student-submitted sport records for this course
    const [records] = await pool.query(
      `SELECT sr.*, 'student' AS source_type FROM sport_records sr
       WHERE sr.student_id = ? AND (sr.course_id = ? OR sr.course_id IS NULL)
       ORDER BY sr.submitted_at DESC`,
      [studentId, courseId]
    );

    // Teacher-assigned tasks completed by this student
    const [completedTasks] = await pool.query(
      `SELECT t.*, sr.status AS record_status, sr.approved_hours, sr.submitted_at, sr.reviewed_at
       FROM tasks t
       JOIN sport_records sr ON sr.task_id = t.id AND sr.student_id = ?
       WHERE t.course_id = ?`,
      [studentId, courseId]
    );

    // Team/club membership offsets
    const [memberships] = await pool.query(
      `SELECT m.* FROM memberships m WHERE m.student_id = ?`,
      [studentId]
    );

    // Manual credits from teacher
    const [manualCredits] = await pool.query(
      `SELECT mc.*, u.name AS operator_name FROM manual_credits mc
       LEFT JOIN users u ON mc.operator_id = u.id
       WHERE mc.student_id = ? AND mc.course_id = ?
       ORDER BY mc.created_at DESC`,
      [studentId, courseId]
    );

    // Build unified record list
    const items = [];

    // Source 1: Student self-submitted check-ins
    for (const r of records) {
      items.push({
        sourceType: '学生自提交（课程相关）',
        sourceCategory: 'student_course',
        sportType: r.credit_type || '',
        appliedHours: Number(r.hours || 0),
        approvedHours: Number(r.approved_hours || 0),
        submittedAt: r.submitted_at,
        status: r.status,
        reviewer: r.review_comment || '',
        description: r.description || '',
        proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
        recordId: r.id
      });
    }

    // Source 2: Teacher-assigned task completions
    for (const t of completedTasks) {
      items.push({
        sourceType: '老师任务完成',
        sourceCategory: 'teacher_task',
        sportType: t.credit_type || '',
        appliedHours: Number(t.required_hours || 0),
        approvedHours: Number(t.approved_hours || 0),
        submittedAt: t.submitted_at,
        status: t.record_status || '进行中',
        reviewer: '',
        description: t.title || '',
        proofFiles: [],
        recordId: t.id
      });
    }

    // Source 3: Team/club offsets
    for (const m of memberships) {
      if (m.offset_status === '可抵扣' && m.status === '认证有效') {
        items.push({
          sourceType: m.type === 'team' ? '校队抵扣' : '社团抵扣',
          sourceCategory: m.type === 'team' ? 'team' : 'club',
          sportType: '其他运动',
          appliedHours: Number(m.offset_hours || 10.0),
          approvedHours: Number(m.offset_hours || 10.0),
          submittedAt: m.updated_at,
          status: '系统抵扣',
          reviewer: m.updated_by || '',
          description: `${m.organization} 抵扣`,
          proofFiles: [],
          recordId: 'offset-' + m.id
        });
      }
    }

    // Source 4: Manual credits from teacher
    for (const mc of manualCredits) {
      items.push({
        sourceType: '老师手动加抵',
        sourceCategory: 'manual',
        sportType: mc.credit_type || '',
        appliedHours: Number(mc.hours || 0),
        approvedHours: Number(mc.hours || 0),
        submittedAt: mc.created_at,
        status: '已通过',
        reviewer: mc.operator_name || mc.operator_id || '',
        description: mc.reason || '',
        proofFiles: typeof mc.proof_files === 'string' ? JSON.parse(mc.proof_files) : (mc.proof_files || []),
        recordId: 'manual-' + mc.id
      });
    }

    // Sort by time descending
    items.sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));

    // Aggregate summary
    const summary = {
      studentSubmitted: items.filter(i => i.sourceCategory === 'student_course').reduce((s, i) => s + i.approvedHours, 0),
      teacherTask: items.filter(i => i.sourceCategory === 'teacher_task').reduce((s, i) => s + i.approvedHours, 0),
      teamOffset: items.filter(i => i.sourceCategory === 'team').reduce((s, i) => s + i.approvedHours, 0),
      clubOffset: items.filter(i => i.sourceCategory === 'club').reduce((s, i) => s + i.approvedHours, 0),
      manualCredit: items.filter(i => i.sourceCategory === 'manual').reduce((s, i) => s + i.approvedHours, 0),
      totalApplied: items.reduce((s, i) => s + i.appliedHours, 0),
      totalApproved: items.reduce((s, i) => s + i.approvedHours, 0)
    };

    res.json({ studentId, courseId, items, summary });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #1B: Teacher manual credit entry ─────────────────────
app.post('/api/teacher/courses/:courseId/students/:studentId/manual-credit', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { courseId, studentId } = req.params;
    const { creditType, hours, reason, proofFiles } = req.body || {};

    if (!creditType || !['课程相关','其他运动'].includes(creditType)) {
      return res.status(400).json({ code: 'VALIDATION', message: '抵扣类型只能为 课程相关 或 其他运动' });
    }
    if (!hours || Number(hours) <= 0 || Number(hours) > 20) {
      return res.status(400).json({ code: 'VALIDATION', message: '抵扣小时数须在 0.1–20 之间' });
    }
    if (!reason || !reason.trim()) {
      return res.status(400).json({ code: 'VALIDATION', message: '原因说明为必填项' });
    }

    const id = 'mc-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
    await pool.query(
      `INSERT INTO manual_credits (id, student_id, course_id, credit_type, hours, reason, proof_files, operator_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, studentId, courseId, creditType, Number(hours), reason.trim(), JSON.stringify(proofFiles || []), req.userId]
    );

    // Write audit log
    const logId = 'log-' + id;
    const [student] = await pool.query('SELECT name FROM users WHERE id = ?', [studentId]);
    await pool.query(
      `INSERT INTO audit_logs (id, actor, action, target, time) VALUES (?, ?, ?, ?, NOW())`,
      [logId, req.userId, '手动加抵卡', `${student[0]?.name || studentId} / ${creditType} ${hours}h / ${reason.trim().slice(0, 50)}`]
    );

    // Update student_progress hours
    if (creditType === '课程相关') {
      await pool.query('UPDATE student_progress SET course_hours = course_hours + ? WHERE student_id = ? AND course_id = ?', [Number(hours), studentId, courseId]);
    } else {
      await pool.query('UPDATE student_progress SET general_hours = general_hours + ? WHERE student_id = ? AND course_id = ?', [Number(hours), studentId, courseId]);
    }

    res.json({ id, status: '已通过', createdAt: new Date().toISOString() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #2A: Pending certifications list for teacher ─────────
app.get('/api/teacher/courses/:courseId/pending-certifications', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { courseId } = req.params;

    // Find all students enrolled in this course
    const [enrollments] = await pool.query(
      'SELECT student_id FROM student_progress WHERE course_id = ?', [courseId]
    );
    const studentIds = enrollments.map(e => e.student_id);
    if (studentIds.length === 0) return res.json({ items: [], count: 0 });

    // Query memberships where offset is pending teacher confirmation
    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name, u.gender, u.grade_level, u.college
       FROM memberships m
       JOIN users u ON m.student_id = u.id
       WHERE m.student_id IN (?)
         AND m.offset_status = '待确认'
         AND m.status = '认证有效'
       ORDER BY m.updated_at DESC`,
      [studentIds]
    );

    res.json({ items: rows, count: rows.length });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #2B: Confirm certification with optional hour adjustment ─
app.put('/api/teacher/certifications/:certId/confirm', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { certId } = req.params;
    const { adjustedHours } = req.body || {};

    const hours = adjustedHours != null ? Number(adjustedHours) : null;
    if (hours !== null && (hours <= 0 || hours > 20)) {
      return res.status(400).json({ code: 'VALIDATION', message: '调整后小时数须在 0.1–20 之间' });
    }

    const updates = ['offset_status = ?', 'confirmed_by = ?', 'confirmed_at = NOW()'];
    const params = ['可抵扣', req.userId];
    if (hours !== null) {
      updates.push('offset_hours = ?');
      params.push(hours);
    }

    params.push(certId);
    const [result] = await pool.query(
      `UPDATE memberships SET ${updates.join(', ')} WHERE id = ?`,
      params
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '抵扣记录不存在' });

    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m
       JOIN users u ON m.student_id = u.id WHERE m.id = ?`,
      [certId]
    );

    // Update student_progress for the student's course
    const m = rows[0];
    const [enrollments] = await pool.query(
      'SELECT course_id FROM student_progress WHERE student_id = ?', [m.student_id]
    );
    for (const enroll of enrollments) {
      await pool.query(
        'UPDATE student_progress SET general_hours = GREATEST(general_hours, ?) WHERE student_id = ? AND course_id = ?',
        [Number(m.offset_hours || 10.0), m.student_id, enroll.course_id]
      );
    }

    // Audit log
    const logId = 'log-cert-' + Date.now();
    await pool.query(
      `INSERT INTO audit_logs (id, actor, action, target, time) VALUES (?, ?, ?, ?, NOW())`,
      [logId, req.userId, '确认校队/社团抵扣', `${m.student_name} / ${m.organization} / ${m.offset_hours || 10.0}h`]
    );

    res.json({ membership: rows[0], confirmedBy: req.userId, adjustedHours: hours });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #2C: Reject certification ────────────────────────────
app.put('/api/teacher/certifications/:certId/reject', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { certId } = req.params;
    const { reason } = req.body || {};
    if (!reason || !reason.trim()) {
      return res.status(400).json({ code: 'VALIDATION', message: '驳回原因为必填项' });
    }

    const [result] = await pool.query(
      `UPDATE memberships SET offset_status = '不抵扣', rejection_reason = ?, confirmed_by = ?, confirmed_at = NOW() WHERE id = ?`,
      [reason.trim(), req.userId, certId]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '抵扣记录不存在' });

    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m
       JOIN users u ON m.student_id = u.id WHERE m.id = ?`,
      [certId]
    );

    // Notify student
    const notifId = 'n-rej-' + Date.now();
    await pool.query(
      `INSERT INTO notifications (id, student_id, title, message, category) VALUES (?, ?, ?, ?, '审核反馈')`,
      [notifId, rows[0].student_id, '校队/社团抵扣被驳回', `${rows[0].organization} 抵扣未通过审核。原因：${reason.trim().slice(0, 200)}`]
    );

    res.json({ membership: rows[0], rejectedBy: req.userId, reason: reason.trim() });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #3A: Get per-second conversion table ──────────────────
app.get('/api/admin/conversion-table/:gradeGroup/:gender', requireRole('admin'), async (req, res) => {
  try {
    const { gradeGroup, gender } = req.params;
    if (!['freshman_sophomore','junior_senior'].includes(gradeGroup)) {
      return res.status(400).json({ code: 'VALIDATION', message: '年级组无效' });
    }
    if (!['male','female'].includes(gender)) {
      return res.status(400).json({ code: 'VALIDATION', message: '性别无效' });
    }

    const [rows] = await pool.query(
      `SELECT * FROM conversion_rules_admin
       WHERE grade_group = ? AND gender = ?
       ORDER BY raw_seconds ASC`,
      [gradeGroup, gender]
    );

    // Check for gaps
    const gaps = [];
    for (let i = 1; i < rows.length; i++) {
      if (rows[i].raw_seconds !== rows[i-1].raw_seconds + 1) {
        gaps.push({
          fromSeconds: rows[i-1].raw_seconds,
          toSeconds: rows[i].raw_seconds,
          missingCount: rows[i].raw_seconds - rows[i-1].raw_seconds - 1
        });
      }
    }

    res.json({
      gradeGroup, gender,
      entries: rows,
      count: rows.length,
      scoreRange: rows.length > 0 ? `${rows[rows.length-1].converted_score} – ${rows[0].converted_score}` : '无数据',
      timeRange: rows.length > 0 ? `${rows[0].raw_seconds}s – ${rows[rows.length-1].raw_seconds}s` : '无数据',
      gaps,
      hasGaps: gaps.length > 0
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #3B: Replace per-second conversion table (batch) ─────
app.put('/api/admin/conversion-table/:gradeGroup/:gender', requireRole('admin'), async (req, res) => {
  try {
    const { gradeGroup, gender } = req.params;
    const { entries } = req.body || {};
    if (!entries || !Array.isArray(entries) || entries.length === 0) {
      return res.status(400).json({ code: 'VALIDATION', message: '请提供换算表数据数组' });
    }

    // Validate no gaps: entries must be contiguous by raw_seconds
    const sorted = [...entries].sort((a, b) => a.raw_seconds - b.raw_seconds);
    for (let i = 1; i < sorted.length; i++) {
      if (sorted[i].raw_seconds !== sorted[i-1].raw_seconds + 1) {
        return res.status(400).json({
          code: 'VALIDATION',
          message: `存在空档：${sorted[i-1].raw_seconds}s (分数${sorted[i-1].converted_score}) 到 ${sorted[i].raw_seconds}s (分数${sorted[i].converted_score}) 之间有 ${sorted[i].raw_seconds - sorted[i-1].raw_seconds - 1} 秒空缺`
        });
      }
    }

    // Delete old entries and insert new ones in a transaction
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      await conn.query(
        'DELETE FROM conversion_rules_admin WHERE grade_group = ? AND gender = ?',
        [gradeGroup, gender]
      );
      for (const e of entries) {
        const id = `cv-${gradeGroup}-${gender}-${e.raw_seconds}`;
        const rawValue = e.raw_value || `${Math.floor(e.raw_seconds/60)}'${String(e.raw_seconds%60).padStart(2,'0')}"`;
        await conn.query(
          `INSERT INTO conversion_rules_admin (id, grade_group, gender, item_name, raw_value, raw_seconds, converted_score, version)
           VALUES (?, ?, ?, ?, ?, ?, ?, 1)
           ON DUPLICATE KEY UPDATE converted_score = VALUES(converted_score), raw_value = VALUES(raw_value)`,
          [id, gradeGroup, gender, gender === 'male' ? '1000m' : '800m', rawValue, e.raw_seconds, e.converted_score]
        );
      }
      await conn.commit();
      res.json({ gradeGroup, gender, savedCount: entries.length, updatedAt: new Date().toISOString() });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #3C: Validate conversion table ────────────────────────
app.post('/api/admin/conversion-table/validate', requireRole('admin'), async (req, res) => {
  try {
    const combinations = [
      { gradeGroup: 'freshman_sophomore', gender: 'male', item: '1000m' },
      { gradeGroup: 'freshman_sophomore', gender: 'female', item: '800m' },
      { gradeGroup: 'junior_senior', gender: 'male', item: '1000m' },
      { gradeGroup: 'junior_senior', gender: 'female', item: '800m' }
    ];

    const results = [];
    for (const { gradeGroup, gender, item } of combinations) {
      const [rows] = await pool.query(
        'SELECT raw_seconds, converted_score FROM conversion_rules_admin WHERE grade_group = ? AND gender = ? ORDER BY raw_seconds ASC',
        [gradeGroup, gender]
      );
      const gaps = [];
      for (let i = 1; i < rows.length; i++) {
        if (rows[i].raw_seconds !== rows[i-1].raw_seconds + 1) {
          gaps.push({ fromSeconds: rows[i-1].raw_seconds, toSeconds: rows[i].raw_seconds, missingCount: rows[i].raw_seconds - rows[i-1].raw_seconds - 1 });
        }
      }
      results.push({
        gradeGroup, gender, item, entryCount: rows.length,
        scoreRange: rows.length > 0 ? `${rows[0].converted_score} – ${rows[rows.length-1].converted_score}` : '无',
        hasGaps: gaps.length > 0, gaps
      });
    }

    res.json({ results, allValid: results.every(r => !r.hasGaps && r.entryCount > 0) });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #3D: Auto-convert for a specific student ──────────────
app.get('/api/teacher/conversion/calculate', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { studentId, rawSeconds } = req.query;
    if (!studentId) return res.status(400).json({ code: 'VALIDATION', message: '缺少 studentId' });
    if (rawSeconds == null || Number(rawSeconds) <= 0) return res.status(400).json({ code: 'VALIDATION', message: '缺少 rawSeconds' });

    const timeSec = Number(rawSeconds);

    // Get student gender + grade
    const [users] = await pool.query('SELECT gender, grade_level FROM users WHERE id = ?', [studentId]);
    if (users.length === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '学生不存在' });
    const { gender, grade_level } = users[0];
    if (!gender || !grade_level) {
      return res.status(400).json({ code: 'VALIDATION', message: '学生缺少性别或年级信息，请先完善学生档案' });
    }

    const gradeGroup = ['freshman','sophomore'].includes(grade_level)
      ? 'freshman_sophomore' : 'junior_senior';

    // Look up per-second conversion table
    const [rows] = await pool.query(
      `SELECT converted_score FROM conversion_rules_admin
       WHERE grade_group = ? AND gender = ? AND raw_seconds = ?
       LIMIT 1`,
      [gradeGroup, gender, timeSec]
    );

    let score;
    if (rows.length > 0) {
      score = Number(rows[0].converted_score);
    } else {
      // Fallback to endurance_scoring_rules (legacy tiered table)
      const [legacy] = await pool.query(
        `SELECT score, tier FROM endurance_scoring_rules
         WHERE gender = ? AND grade_group = ? AND ? >= time_seconds_min AND ? <= time_seconds_max
         ORDER BY score DESC LIMIT 1`,
        [gender, gradeGroup, timeSec, timeSec]
      );
      if (legacy.length > 0) {
        score = Number(legacy[0].score);
      } else {
        // Time faster than best — return max score
        const [best] = await pool.query(
          `SELECT MAX(score) AS max_score FROM endurance_scoring_rules
           WHERE gender = ? AND grade_group = ?`,
          [gender, gradeGroup]
        );
        score = best[0]?.max_score || 100;
      }
    }

    // Also get the tier
    let tier = 'fail';
    if (score >= 90) tier = 'excellent';
    else if (score >= 80) tier = 'good';
    else if (score >= 60) tier = 'pass';

    // Format the raw time for display
    const mins = Math.floor(timeSec / 60);
    const secs = timeSec % 60;
    const rawDisplay = `${mins}'${String(secs).padStart(2,'0')}"`;

    res.json({
      studentId, gender, gradeLevel: grade_level, gradeGroup,
      rawSeconds: timeSec, rawDisplay,
      convertedScore: score, tier,
      itemName: gender === 'male' ? '1000m' : '800m'
    });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #4: Course-scoped exemptions for teacher ──────────────
app.get('/api/teacher/courses/:courseId/exemptions', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { courseId } = req.params;
    const { status } = req.query;

    // Get students in this course
    const [enrollments] = await pool.query(
      'SELECT student_id FROM student_progress WHERE course_id = ?', [courseId]
    );
    const studentIds = enrollments.map(e => e.student_id);
    if (studentIds.length === 0) return res.json([]);

    let sql = `SELECT e.*, u.name AS student_name, u.gender, u.grade_level, u.college
               FROM exemptions e
               JOIN users u ON e.student_id = u.id
               WHERE e.student_id IN (?)`;
    const params = [studentIds];

    if (status && status !== 'all') {
      const statusMap = { pending: '待审核', approved: '已通过', rejected: '已驳回' };
      if (statusMap[status]) { sql += ' AND e.status = ?'; params.push(statusMap[status]); }
    }
    sql += ' ORDER BY e.created_at DESC';

    const [rows] = await pool.query(sql, params);
    res.json(rows.map((r) => ({
      id: r.id, studentId: r.student_id, studentName: r.student_name,
      gender: r.gender, gradeLevel: r.grade_level, college: r.college,
      type: r.type, reason: r.reason, status: r.status,
      proofFiles: typeof r.proof_files === 'string' ? JSON.parse(r.proof_files) : (r.proof_files || []),
      reviewComment: r.review_comment, reviewerId: r.reviewer_id,
      courseId: r.course_id,
      createdAt: r.created_at, updatedAt: r.updated_at
    })));
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #5A: Teacher views student organization identity ──────
app.get('/api/teacher/courses/:courseId/students/:studentId/organization-identity', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { studentId } = req.params;

    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m
       JOIN users u ON m.student_id = u.id
       WHERE m.student_id = ?
       ORDER BY m.updated_at DESC`,
      [studentId]
    );

    const identities = rows.map((r) => ({
      id: r.id,
      type: r.type,           // team / club
      typeLabel: r.type === 'team' ? '校队' : '社团',
      organization: r.organization,
      isSport: r.type === 'team' ? true : (r.status !== '非体育类'),
      status: r.status,        // 认证有效 / 待确认 / 不通过 / 非体育类
      statusLabel: r.status,
      validUntil: r.valid_until,
      offsetStatus: r.offset_status,
      offsetStatusLabel: r.offset_status,
      offsetHours: Number(r.offset_hours || 10.0),
      comment: r.comment || '',
      rejectionReason: r.rejection_reason || '',
      confirmedBy: r.confirmed_by || '',
      confirmedAt: r.confirmed_at || '',
      updatedBy: r.updated_by || '',
      updatedAt: r.updated_at || ''
    }));

    res.json({ studentId, identities });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── Feature #5B: Teacher flags organization identity ───────────────
app.put('/api/teacher/students/:studentId/organization-identity/:identityId/flag', requireRole('teacher','admin'), async (req, res) => {
  try {
    const { studentId, identityId } = req.params;
    const { flag, comment } = req.body || {};

    if (!['confirmed','questionable'].includes(flag)) {
      return res.status(400).json({ code: 'VALIDATION', message: 'flag 只能为 confirmed 或 questionable' });
    }

    const newStatus = flag === 'confirmed' ? '认证有效' : '待确认';
    const newComment = comment || (flag === 'confirmed' ? '任课老师已确认身份信息无误' : '任课老师标记存疑');

    const [result] = await pool.query(
      `UPDATE memberships SET status = ?, comment = CONCAT(COALESCE(comment,''), '\n', ?), updated_by = ?, updated_at = NOW()
       WHERE id = ? AND student_id = ?`,
      [newStatus, newComment, req.userId, identityId, studentId]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 'NOT_FOUND', message: '组织身份记录不存在' });

    const [rows] = await pool.query(
      `SELECT m.*, u.name AS student_name FROM memberships m
       JOIN users u ON m.student_id = u.id WHERE m.id = ?`,
      [identityId]
    );

    // Audit log
    const logId = 'log-flag-' + Date.now();
    await pool.query(
      `INSERT INTO audit_logs (id, actor, action, target, time) VALUES (?, ?, ?, ?, NOW())`,
      [logId, req.userId, flag === 'confirmed' ? '确认组织身份' : '标记组织身份存疑', `${rows[0].student_name} / ${rows[0].organization}`]
    );

    res.json({ identity: rows[0], flag, comment: newComment });
  } catch (e) { res.status(500).json({ code: 'DB_ERROR', message: e.message }); }
});

// ── 404 catch-all ───────────────────────────────────────────────
app.use('/api/*', (_req, res) => {
  res.status(404).json({ code: 'RESOURCE_NOT_FOUND', message: 'Endpoint not implemented' });
});

// ── Start ───────────────────────────────────────────────────────
const port = process.env.PORT || 3001;
app.listen(port, '127.0.0.1', () => {
  console.log(`BNBU Sports API running on http://127.0.0.1:${port}/api/health`);
});
