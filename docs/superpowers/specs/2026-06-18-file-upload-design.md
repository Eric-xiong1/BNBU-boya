# File Upload: Android Upload + Web Teacher Proof Viewing

2026-06-18 | MVP | Three-layer (Android / Backend / Web)

## Problem

Server infrastructure for file upload is fully deployed (multer endpoint, Nginx static serving, DB proof_files columns), but:

1. **Android** (student app): Has image picker UI but never calls `POST /api/upload/proof` — sends content:// URIs as strings instead of actual file bytes
2. **Backend** `reviews` endpoint: Does not JOIN `sport_records` to include `proof_files`, so teacher review page has no proof data
3. **Web** (teacher app): `renderReviewTable()` shows a static mock proof card; `buildStudentRecordsHtml()` has no proof column

## Audience boundary (important)

- **Students** use the Android app to upload proof images
- **Teachers/admins** use the Web app to **view** student proof images (no upload)

## Design

### Part A: Android — Real file upload (2 new Kotlin files + 4 edits)

**Flow**:
```
CheckInScreen: pick photos → ProofAttachment (metadata)
         ↓
ApiStudentRepository.uploadProofFiles(uris)
         ↓  reads bytes from ContentResolver, POST multipart
StudentApiClient.uploadProof(uris) → POST /api/upload/proof
         ↓
{ urls: ["/uploads/abc.jpg"] }
         ↓
SubmitSportRecordRequest(proofFiles = urls) → POST /api/sport/records
```

**Files to change**:

1. **`StudentEndpoint.kt`** — Add `UploadProof` endpoint
2. **`StudentApiClient.kt`** — Add `executeMultipart(listOfUris)` method using OkHttp `MultipartBody`
3. **`ApiStudentRepository.kt`** — Add `uploadProofFiles(uris: List<Uri>): Result<List<String>>` that reads bytes via ContentResolver and calls client
4. **`StudentAppState.kt`** — Wire upload before submit: `uploadProofFiles()` → get URLs → `submitRecord(proofFiles = urls)` (change fire-and-forget to sequential await)
5. **`CheckInScreen.kt`** — Minor: ensure `source` field stores the content URI for upload (already does this)

### Part B: Backend — Reviews endpoint JOIN

**File**: `server.js` line 253-266

- SQL: `SELECT r.*, sr.proof_files FROM reviews r LEFT JOIN sport_records sr ON r.record_id = sr.id WHERE r.course_id = ?`
- Response map: add `proofFiles` field parsed from JSON

### Part C: Web — Teacher viewing

**File**: `app.js`

1. **`renderReviewTable()`** (line 1404-1410): Replace mock proof-card with real image grid
   - Condition: if `active.proofFiles` has URLs, render `<img>` tags
   - Fallback: if no proof files, show "无凭证" placeholder
2. **`buildStudentRecordsHtml()`** (line 3154-3236): Add "凭证" column showing proof links/images
   - API path: add `proofFiles` to the item map
   - Local mock path: add proof links from review/membership data

## Risk & Rollback

- All changes are additive — no existing API contracts change
- Android upload is fire-and-forget in current code; the change makes it sequential (upload → submit) which is slightly slower but correct
- Backend SQL change adds a LEFT JOIN — existing rows without linked sport_records return proofFiles: [] (no breakage)
- Web changes are template-only — data availability is gated by `proofFiles && proofFiles.length > 0`
