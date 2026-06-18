# BNBU Sports V1 — Baota Server Configuration Guide

Last updated: 2026-06-16

Server: `123.207.5.70:96` (V1) | Panel: Baota Linux | OS: Linux | Web Server: Nginx | Database: MySQL

> **V1 vs V2**: 你是 V1，队友是 V2。两套版本运行在同一台服务器上，通过端口隔离，互不干扰。
>
> - **你的 V1**: 端口 96（前端）, API 端口 3001, 目录 `bnbu-api-v1/`
> - **队友 V2**: 端口 80 或其他（前端）, API 端口 3000, 目录 `bnbu-api/`

---

## Overview: What Goes Where

```
 STUDENT PHONE                 BAOTA SERVER (123.207.5.70:96)
 ┌──────────────────┐          ┌──────────────────────────────────┐
 │                  │          │                                  │
 │  Android APK     │  HTTP    │  Nginx :96 (你的 V1)              │
 │  baseUrl =       │─────────▶│  ├─ /api/* → proxy to :3001     │
 │  http://         │          │  └─ /*     → static files        │
 │  123.207.5.70:96  │          │              │                   │
 │  /api            │          │     ┌────────┴────────┐          │
 │                  │          │     ▼                 ▼          │
 │  Each API call   │          │  index.html       Node.js :3001 │
 │  goes to:        │          │  app.js           bnbu-api-v1   │
 │  /api/auth/login │          │  styles.css       └──────┬───────│
 │  /api/summary    │          │                          │       │
 │  /api/records    │          │  Browser visits page     │       │
 │  ...             │          │  → app.js runs in        │       │
 │                  │          │    browser               │       │
 │                  │          │  → fetches /api/*        │       │
 │                  │          │    → Nginx proxies       │       │
 │                  │          │      to Node.js          │       │
 │                  │          │    ← returns JSON        │       │
 │                  │◀─────────│                          │       │
 │                  │          │                    ┌─────┴─────┐│
 └──────────────────┘          │                    │  MySQL    ││
                               │                    │  DB       ││
    Same calls from both       │                    └───────────┘│
    sides: the server doesn't  └──────────────────────────────────┘
    care who is asking

                    ┌──────────────────────────────────┐
                    │  队友 V2 (不同端口)                │
                    │  Nginx :80 或其他                 │
                    │  ├─ /api/* → proxy to :3000      │
                    │  └─ /* → 队友的前端                │
                    │  Node.js :3000 (bnbu-api)        │
                    └──────────────────────────────────┘
```

**Key point:** 你的 V1 和队友的 V2 监听不同的 Nginx 端口和不同的 Node.js 端口，共享同一个 MySQL 数据库。Android app 跑在学生手机上，通过 HTTP 连接你的 API。

---

## 端口对照表

| 端口           | 服务                           | 归属              | PM2 进程名      |
| -------------- | ------------------------------ | ----------------- | --------------- |
| **96**   | Nginx 前端 +`/api/` → :3001 | **你 (V1)** | —              |
| 80 或其他      | Nginx 前端 +`/api/` → :3000 | 队友 (V2)         | —              |
| **3001** | Node.js API                    | **你 (V1)** | `bnbu-api-v1` |
| 3000           | Node.js API                    | 队友 (V2)         | `bnbu-api`    |
| 3306           | MySQL                          | 共享              | —              |

---

## 服务器目录结构

```
/www/wwwroot/
├── 123.207.5.70_96/      ← 你的 V1 前端（端口 96）
├── bnbu-api-v1/          ← 你的 V1 API（端口 3001）
├── bnbu-api/             ← 队友的 V2 API（端口 3000）
├── 123.123.376.23/       ← 队友的
└── default/              ← 系统默认
```

---

## Files to Upload to Server

### Required: 7 files + 1 SQL execution

| # | File (local path)                  | Destination on server                     | Method                |
| - | ---------------------------------- | ----------------------------------------- | --------------------- |
| 1 | `backend-handoff/schema.sql`     | Execute in**phpMyAdmin**            | Copy-paste → Execute |
| 2 | `backend-handoff/package.json`   | `/www/wwwroot/bnbu-api-v1/package.json` | Baota File Manager    |
| 3 | `backend-handoff/server.js`      | `/www/wwwroot/bnbu-api-v1/server.js`    | Baota File Manager    |
| 4 | `web-app/index.html`             | `/www/wwwroot/123.207.5.70_96/`         | Baota File Manager    |
| 5 | `web-app/app.js`                 | `/www/wwwroot/123.207.5.70_96/`         | Baota File Manager    |
| 6 | `web-app/styles-campus-blue.css` | `/www/wwwroot/123.207.5.70_96/`         | Baota File Manager    |
| 7 | `web-app/styles.css`             | `/www/wwwroot/123.207.5.70_96/`         | Baota File Manager    |

> Nginx web root is `/www/wwwroot/123.207.5.70_96/` — verify by checking the `root` directive in Baota → Website → your site (port 96) → Configuration.

### Files NOT needed on server

| File                     | Reason                                 |
| ------------------------ | -------------------------------------- |
| `mock-api.cjs`         | Local testing only                     |
| `sample-payloads.json` | Reference documentation                |
| `nginx-snippet.conf`   | Content gets copy-pasted, not uploaded |
| `openapi.yaml`         | API documentation, not runtime         |
| `data-dictionary.md`   | Reference documentation                |
| `DEPLOY.md`            | This guide you're reading              |

---

## Phase 1: Database Setup

### Action 1 — Execute `schema.sql`

1. Baota Panel → **Database** → find database `123_207_5_70_96` → click **Manage**
2. phpMyAdmin opens → click the **SQL** tab at the top
3. Open `backend-handoff/schema.sql` from the project, **Select All → Copy**
4. Paste into phpMyAdmin's SQL text box
5. Click **Execute** (bottom right)

**Verify:** You should see 9 tables in the left sidebar:

- `semesters`
- `users`
- `courses`
- `student_progress`
- `reviews`
- `audit_logs`
- `sport_records`
- `notifications`
- `memberships`

> If tables already exist (队友可能已建过) and you want a clean start: in phpMyAdmin, check all tables → Drop → then execute `schema.sql`. Otherwise skip this step.

---

## Phase 2: Backend — Node.js API (V1)

### Action 2 — Create server directory

Baota → **Files** → navigate to `/www/wwwroot/` → **New Folder** → name it `bnbu-api-v1`

> ⚠️ 注意：是 `bnbu-api-v1`，不是 `bnbu-api`（队友已占用）。

### Action 3 — Upload backend files

Into `/www/wwwroot/bnbu-api-v1/`, upload these 2 files:

- `package.json`
- `server.js`

### Action 4 — Install npm dependencies

Baota → **Terminal** (or SSH into the server):

```bash
cd /www/wwwroot/bnbu-api-v1
npm install
```

This installs `express` and `mysql2` into `node_modules/`.

### Action 5 — Start the API process

**Option A: Baota Node Project Manager (GUI)**

Baota → **Website** → switch to **Node Project** tab → **Add Node Project**

| Field             | Value                        |
| ----------------- | ---------------------------- |
| Project Directory | `/www/wwwroot/bnbu-api-v1` |
| Startup File      | `server.js`                |
| Project Name      | `bnbu-api-v1`              |
| Port              | `3001`                     |
| Bind IP           | `127.0.0.1`                |
| Startup Command   | `node server.js`           |

Click **Submit** → then click **Start**.

**Option B: PM2 (推荐)**

```bash
cd /www/wwwroot/bnbu-api-v1
pm2 start server.js --name bnbu-api-v1
pm2 save
```

### Action 6 — Verify the API is running

```bash
curl http://127.0.0.1:3001/api/health
```

Expected response:

```json
{"ok":true,"service":"BNBU Sports API","timestamp":"...","db":"connected"}
```

> If no response: the Node process isn't running. Check Baota Node Manager or run `node server.js` directly to see error output.
> If `db: "disconnected"`: MySQL credentials in `server.js` don't match. Check `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`.

### Server connection details

| Variable        | Value                | Where it comes from       |
| --------------- | -------------------- | ------------------------- |
| `DB_HOST`     | `127.0.0.1`        | MySQL on same server      |
| `DB_USER`     | `123_207_5_70_96`  | Baota database user       |
| `DB_PASSWORD` | `Bd84EKfpw3XSmheB` | Baota database password   |
| `DB_NAME`     | `123_207_5_70_96`  | Baota database name       |
| API port        | `3001`             | Internal only (127.0.0.1) |

---

## Phase 3: Nginx Reverse Proxy

### Action 7 — Configure the `/api/` proxy for your site (port 96)

1. Baota → **Website** → click your site (`123.207.5.70:96`) → **Configuration**
2. Find the existing `location / { ... }` block — **do not modify it**
3. **After** the `location / { ... }` closing brace, add:

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    proxy_read_timeout 30s;
    proxy_connect_timeout 5s;
}
```

4. Click **Save** → click **Reload Nginx**

> ⚠️ 确保你配置的是**你自己的站点（端口 96）**，不是队友的站点。队友有自己的 `/api/` 转发指向 3000。
>
> Reference: `backend-handoff/nginx-snippet.conf` contains the complete example.

### What the proxy does

Every request to `http://123.207.5.70:96/api/*` gets transparently forwarded to **your** Node.js process on `127.0.0.1:3001`. The client (browser or Android app) never knows the API is on a different port — it looks like a single server. This means **no CORS issues** for the web app (same origin). The API does send CORS headers for the Android app's direct calls.

---

## Phase 4: Frontend — Web UI

### Action 8 — Upload frontend files

Upload these 4 files to the Nginx web root `/www/wwwroot/123.207.5.70_96/`:

| File                       | Purpose                    |
| -------------------------- | -------------------------- |
| `index.html`             | SPA entry point            |
| `app.js`                 | All application logic      |
| `styles-campus-blue.css` | Swiss design system styles |
| `styles.css`             | Additional styles          |

> **Overwrite** if older versions exist. The frontend talks to `/api/*` using relative paths, so `apiBaseUrl` can be left empty.

---

## Phase 5: Android APK (Student App)

### Action 9 — Build the APK

On your Windows development machine:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
cd BNBUStudentAndroid
.\gradlew.bat :app:assembleDebug --console=plain --no-daemon
```

Output: `app\build\outputs\apk\debug\app-debug.apk`

### Action 10 — Host the APK for download

Upload `app-debug.apk` to the Nginx web root and rename it:

```
/www/wwwroot/123.207.5.70_96/bnbu-student.apk
```

Students download from: `http://123.207.5.70:96/bnbu-student.apk`

> On the phone: Settings → Security → allow "Install from unknown sources" → open the download → Install.

### How the Android app connects to the server

The Android app is pre-configured at `StudentApiClient.kt`:

```kotlin
const val DefaultBaseUrl = "http://123.207.5.70:96/api"
```

The server's CORS middleware allows `*` (all origins). No code changes needed — the connection is pre-wired.

> **Current limitation (MVP):** The Android app uses `MockRepository` for local demo data. The `StudentApiClient` is defined but not connected. To switch to live data, the repository must be swapped in a future development task. For now, the app works standalone with demo data.

---

## Phase 6: Full Verification

### Action 11 — Test the complete chain

**Test 1: API from any external device**

```bash
curl http://123.207.5.70:96/api/health
```

Should return JSON with `"ok": true`. This proves:

- Nginx is receiving requests ✓
- Nginx proxies `/api/*` to your Node.js :3001 ✓
- Node.js connects to MySQL ✓

**Test 2: Web app in browser**

Open `http://123.207.5.70:96/` → login as `admin@bnbu.edu.cn` (any password) → go to "后端交付" → leave API Base URL empty → click "检查后端连接" → should say connected.

**Test 3: Android APK**

1. Install APK on a phone (see Action 10)
2. Open the app → login as any demo student
3. Tab through all 5 tabs (Dashboard, Courses, Check-In, Grades, Profile)
4. Verify data loads in each tab

---

## Troubleshooting

| Symptom                                                   | Likely Cause                   | Fix                                                                                                                      |
| --------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `curl http://127.0.0.1:3001/api/health` has no response | Node.js not running            | Restart `bnbu-api-v1` in Baota or PM2                                                                                  |
| API health returns `db: "disconnected"`                 | MySQL credentials wrong        | Check env vars `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`                                                    |
| `curl http://123.207.5.70:96/api/health` returns 502    | Nginx can't reach Node.js      | Check Node.js is running on port 3001 (`netstat -tlnp \| grep 3001`)                                                    |
| Web page is blank/white                                   | Frontend files not uploaded    | Check `app.js` exists in `/www/wwwroot/123.207.5.70_96/`; check browser Console (F12) for JS errors                  |
| Android APK can't reach server                            | Network or firewall            | Phone must be on a network that can reach `123.207.5.70:96`; check `android:usesCleartextTraffic="true"` in manifest |
| Android login fails                                       | Mock data vs real API mismatch | Currently expected — Android uses local mock data, not real API                                                         |

### Useful server commands

```bash
# Check if your V1 Node.js is running on port 3001
netstat -tlnp | grep 3001

# Check all Node.js processes (yours + teammate's)
ps aux | grep node

# Check PM2 status (see both bnbu-api and bnbu-api-v1)
pm2 status

# View your V1 Node.js logs (PM2)
pm2 logs bnbu-api-v1

# Check Nginx config syntax
nginx -t

# Restart Nginx
systemctl reload nginx
# or via Baota: Website → your site → Reload

# Check MySQL is running
systemctl status mysql
# or: systemctl status mysqld
```

---

## Pre-Production Checklist

Before going live with real students:

- [ ] Configure SSL certificate (Let's Encrypt via Baota) and switch to `https://`
- [ ] Update Android `DefaultBaseUrl` to `https://123.207.5.70:96/api` (or your domain)
- [ ] Configure production release signing keystore for Android
- [ ] Replace Android `MockRepository` with real API repository
- [ ] Set strong passwords for all seed accounts
- [ ] Configure firewall: only port 96 open to public (plus teammate's ports)
- [ ] Set up regular database backups (Baota → Scheduled Tasks)
- [ ] Enable PM2 auto-start on reboot: `pm2 startup` + `pm2 save`
- [ ] Make sure `bnbu-api-v1` (your V1) auto-starts, not just `bnbu-api` (teammate's V2)
