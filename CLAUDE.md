# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a multi-platform campus sports credit management system for BNBU (Beijing Normal University). Three independent projects share this workspace — no cross-project build dependencies:

| Directory | Platform | Audience | Status |
|---|---|---|---|
| `BNBUStudent-iOS-MVP-20260613-v1/` | iOS SwiftUI | Students | MVP, mock data, no backend |
| `BNBUStudentAndroid/` | Android Kotlin/Compose | Students | MVP, mock data, no backend |
| `BNBU_Sports_Web_Delivery_20260612 (1)/` | Vanilla JS SPA + Node.js API | Teachers, admins, club managers | Deployed on Baota panel (123.207.5.70:96) |

All three share the same product domain: sports hour tracking, check-in submissions, grade calculation, organization offsets, and notification management. The iOS and Android apps mirror each other's feature set. The Web app covers teacher/manager workflows that don't exist in the student apps (course roster import, grade archiving, organization approval).

The iOS project has its own detailed `CLAUDE.md` — read it before working in that directory.

## Per-Project Quick Reference

### iOS Student App (`BNBUStudent-iOS-MVP-20260613-v1/`)

```
# Build for simulator
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudent -configuration Debug -sdk iphonesimulator build

# Run unit tests
xcodebuild test -project ios-app/BNBUStudent.xcodeproj -scheme BNBUStudent -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build for device (unsigned)
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudent -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

Bundle ID: `edu.bnbu.student.mvp`. Pure SwiftUI, no external dependencies. The iOS-specific CLAUDE.md covers architecture, data flow, design tokens, and UI patterns in detail.

### Android Student App (`BNBUStudentAndroid/`)

Open in Android Studio, sync Gradle, run the `app` target.

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
.\gradlew.bat :app:testDebugUnitTest --console=plain --no-daemon
.\gradlew.bat :app:assembleDebug --console=plain --no-daemon
```

Package: `edu.bnbu.student.mvp`. Kotlin + Jetpack Compose, Gson for JSON. Mirrors the iOS app feature-for-feature (5 tabs, same data models, same mock repository pattern). Backend endpoints are reserved under `core/network/` but not connected.

### Web App (`BNBU_Sports_Web_Delivery_20260612 (1)/`)

```bash
# Start local preview (no database — uses localStorage mock data)
node web-app/preview-server.cjs          # → http://127.0.0.1:4174/index.html?fresh=quality-v1

# Start Node.js API backend (connects to MySQL — production)
DB_HOST=127.0.0.1 DB_USER=... DB_PASSWORD=... DB_NAME=... node backend-handoff/server.js  # → http://127.0.0.1:3001/api/health

# Start mock API (standalone, no database — for local UI-only testing)
node backend-handoff/mock-api.cjs         # → http://127.0.0.1:8080/api/health

# Run verification
node web-app/self-test.cjs
node web-app/quality-smoke.cjs
```

Single-page app (`index.html` + `app.js` + `styles-campus-blue.css`). State lives in `localStorage` under key `bnbuSportsWebStateV1` when running without a backend. Three role-based route prefixes: `teacher-*`, `admin-*`, `manager-*`.

**Backend stack**: Node.js + Express + MySQL2 (pooled connections), managed via PM2 on a Baota Linux server panel. The `apiBaseUrl` default is empty (`""`), meaning the frontend sends API requests to the same origin — Nginx reverse-proxies `/api/*` to the internal Node.js process on `127.0.0.1:3001`. No CORS needed.

**Server details**:
- Public IP: `123.207.5.70:96` (Nginx → static files + `/api/*` reverse proxy)
- MySQL database: `123_207_5_70_96` via Baota panel (utf8mb4)
- API server: `backend-handoff/server.js` — Express REST API, 32+ endpoints (12 added 2026-06-17)
- DB schema: `backend-handoff/schema.sql` — 14 tables (semesters, users, courses, student_progress, reviews, audit_logs, sport_records, notifications, memberships, endurance_scoring_rules, exemptions, tasks + plan: attendance_logs, conversion_rules_admin)
- Deploy reference: `backend-handoff/DEPLOY.md`

**Key backend files**:
| File | Purpose |
|------|---------|
| `backend-handoff/server.js` | Production API server (Express + MySQL2) |
| `backend-handoff/schema.sql` | Full DDL + demo seed data (6 students, 3 courses) |
| `backend-handoff/mock-api.cjs` | Standalone mock API (no DB dependency) |
| `backend-handoff/openapi.yaml` | OpenAPI 3.0 contract (30+ endpoints) |
| `backend-handoff/data-dictionary.md` | Field-level type definitions |

**Nginx reverse proxy pattern** (configured in Baota panel):
```nginx
location / {
    # static files from web-app/
}
location /api/ {
    proxy_pass http://127.0.0.1:3001;
    proxy_set_header X-Real-IP $remote_addr;
}
```

**PM2 process management** (on server):
```bash
pm2 start server.js --name bnbu-api
pm2 save
```

**⚠️ Baota terminal PATH caveat**: Baota's web terminal creates a clean shell that does NOT source `~/.bashrc` or `~/.profile`. Node.js/NPM/PM2 are managed via NVM under `/root/.nvm/versions/node/v22.22.3/bin/` and will NOT be in PATH. When `node`, `npm`, `npx`, or `pm2` report "command not found", first fix PATH permanently:

```bash
# One-time symlink fix (survives reboots and new terminals)
ln -sf /root/.nvm/versions/node/v22.22.3/bin/node /usr/local/bin/node
ln -sf /root/.nvm/versions/node/v22.22.3/bin/npm  /usr/local/bin/npm
ln -sf /root/.nvm/versions/node/v22.22.3/bin/pm2  /usr/local/bin/pm2
```

If NVM version differs, find the actual path first: `find /root/.nvm -name "node" -type f 2>/dev/null`

PM2 error `/usr/bin/env: 'node': No such file or directory` means the PM2 binary's shebang (`#!/usr/bin/env node`) can't find `node` in PATH — the symlink above fixes this.

To verify PM2 is managing the correct processes:
```bash
pm2 list
# Expected: bnbu-api (V2, port 3000) + bnbu-api-v1 (V1, port 3001) both "online"

# If a process is running as bare `node` (outside PM2), kill it and restart via PM2:
ps aux | grep "node.*server"           # find PID
kill <PID>
pm2 restart bnbu-api-v1
pm2 save
```

**Current server state (2026-06-17)**:
- OS: OpenCloudOS (CentOS-compatible)
- Two Node.js versions: system v16.9.0 (`/www/server/nodejs/v16.9.0/`) and NVM v22.22.3 (`/root/.nvm/versions/node/v22.22.3/`)
- PM2 processes: `bnbu-api` (V2 teammate, port 3000) and `bnbu-api-v1` (V1, port 3001)
- V1 API path: `/www/wwwroot/bnbu-api-v1/server.js`
- V1 frontend: `/www/wwwroot/123.207.5.70_96/`
- Database: MySQL `123_207_5_70_96` (shared with V2)
- DB credentials: user `123_207_5_70_96`, password `Bd84EKfpw3XSmheB`

## Cross-Project Conventions

- **Course identification**: `courseCode + Section` (e.g., `GEPE101 / Section 1004`). Section is always a 4-digit string.
- **Sport hour rules**: 20h total default, 10h course (A), 10h general (B), 2h daily limit.
- **Grade weighting**: 打卡 25%, 专项考试 30%, 平时表现 20%, 体测 25%.
- **Design language**: Swiss internationalist — no rounded corners, 1.5px black strokes, heavy weight numbers, uppercase eyebrow labels. Primary color `#3A9DF6`.
- **iOS and Android apps are frontend-only MVP**: mock data, local persistence, reserved API boundaries. The Web app has a real backend (Node.js + MySQL via Baota panel).

## Feature Implementation Notes

### Endurance Run Scoring (耐力跑成绩换算)

The Chinese national standard scoring table for 800m (female) / 1000m (male) is stored in `endurance_scoring_rules` (80 rows). The conversion endpoint is `POST /api/scoring/convert-endurance`.

**Key rules**:
- 4 populations: M/FS, M/JS, F/FS, F/JS (FS=freshman+sophomore, JS=junior+senior)
- 4 tiers: excellent (90-100), good (80-85), pass (60-78, 10 steps at 2-point intervals), fail (10-50, 5 steps at 10-point intervals)
- Scoring logic: `timeSeconds <= time_seconds_max` → that score (faster is better)
- Both backend (`server.js`) and frontend (`app.js` `localScoreLookup()`) have the full scoring table — frontend falls back to local lookup if API is unavailable

### Exemption Workflow (免测申请)

Students submit exemption applications (`POST /api/student/exemptions`) with type (800m/1000m), reason, and optional proof files. Teachers or admins review and approve/reject (`PUT /api/teacher/exemptions/:id/decision`). The `exemptions` table tracks status through: pending → approved/rejected.

### Cross-Type Check-in Records (统一打卡查询)

`GET /api/teacher/students/:id/records` aggregates three record sources into one unified view:
1. Regular `sport_records` (student-submitted check-ins)
2. Team membership offsets (`memberships` with type='team', offset_status='可抵扣')
3. Club membership offsets (`memberships` with type='club', offset_status='可抵扣')

The `record_source` column on `sport_records` (ENUM: student/team/club) distinguishes origin. Membership offsets are computed at query time (not stored as rows).

### Auth Token System

Two token types coexist during transition:
- **Legacy demo tokens**: `demo-token-<userId>` format — bypasses role check, used for quick API testing
- **New tokens**: `bnbu-<uuid>` format — issued by `/api/auth/login`, stored in memory (`tokenStore` Map), expire on server restart

### Android API Integration

Android uses `StudentApiClient` (OkHttp + Gson) with `DefaultBaseUrl = "http://123.207.5.70:96/api"`. New endpoints added via `StudentEndpoint` sealed class. The `ApiStudentRepository` maps backend DTOs → domain models. Key pattern: network calls wrapped in `withContext(Dispatchers.IO)`, errors surface as exceptions caught by `StudentAppState`.

### File Upload System (Proof Files)

**Audience boundary**: File upload is a **student-only** action. Students upload proof images via the Android app. The Web app is for teachers/admins/managers — it only **views** proof images uploaded by students; it does NOT have upload UI. (iOS app is MVP with no upload implemented yet.)

**Server infrastructure** (all ready as of 2026-06-18):
- `uploads/` directory: `/www/wwwroot/bnbu-api-v1/uploads/` (chmod 755, owned by www:www)
- Multer config in `server.js`: disk storage, max 5 files × 10MB each
- Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`
- Nginx `/uploads/` location: `location ^~ /uploads/ { alias /www/wwwroot/bnbu-api-v1/uploads/; }` (uses `^~` prefix to override the catch-all regex `location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$` which has higher priority and would otherwise match `.png` requests against the wrong root)
- Nginx `/api/` location: needs `client_max_body_size 10m` for large uploads

**Upload flow** (two-request pattern):
1. Student Android app sends raw image bytes → `POST /api/upload/proof` (multipart/form-data, field name `files`)
2. Server multer saves files to disk, returns JSON: `{ urls: ["/uploads/xxx.jpg", ...], count: N }`
3. Student Android app submits the business record (sport check-in, exemption, etc.) with `proofFiles: ["/uploads/xxx.jpg"]` in the JSON body
4. Database stores only URL strings in `proof_files` JSON columns — never the actual file bytes

**Teacher viewing flow**:
1. Teacher opens review page in Web app → API returns record data including `proofFiles` array
2. Web app renders `<img>` tags pointing to `/uploads/xxx.jpg`
3. Nginx serves `/uploads/` files directly from disk (bypassing Node.js, high performance)

**Tables with `proof_files` column** (all JSON type):
| Table | Usage |
|-------|-------|
| `sport_records` | Student check-in proof images |
| `exemptions` | Medical exemption proof |
| `manual_credits` | Teacher-entered manual credits |

**Known frontend gaps** (as of 2026-06-18):
- **Android**: Has image picker UI but no actual upload call — stores URI references only. This is the critical gap blocking production. `ProofUploadRule` (8 files max, 10MB image, 80MB video, 30s video) is defined but not connected to `POST /api/upload/proof`.
- **Web teacher review** (`renderReviewTable`): Proof card is a static placeholder (hardcoded "6.12 km", empty `<div class="proof-map">`). Needs to display real `<img>` tags from review data.
- **Web exemption review**: Proof link (`查看(N)`) works — opens first proof file in new tab.
- **iOS**: Same gap as Android — local PhotosPicker/Camera only, no upload implementation.
