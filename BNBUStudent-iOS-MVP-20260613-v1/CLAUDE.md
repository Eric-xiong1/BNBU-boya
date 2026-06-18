# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
# Build Debug for Simulator
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudent -configuration Debug -sdk iphonesimulator build

# Build UI test bundle
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudentUITests -configuration Debug -sdk iphonesimulator build

# Build unit test bundle
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudentTests -configuration Debug -sdk iphonesimulator build

# Run tests (requires matching Xcode SDK + Simulator runtime)
xcodebuild test -project ios-app/BNBUStudent.xcodeproj -scheme BNBUStudent -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build for device (arm64, unsigned)
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudent -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

Bundle ID: `edu.bnbu.student.mvp`

## Architecture

Pure SwiftUI app with no external dependencies (no CocoaPods, no SPM packages). Uses only system frameworks (SwiftUI, PhotosUI, AVFoundation, UniformTypeIdentifiers).

**Data flow**: `BNBUStudentApp.init()` → picks a `StudentRepository` implementation based on launch arguments → `AppState` (ObservableObject) reads from UserDefaults first, falls back to repository → all views read/write via `@EnvironmentObject var appState: AppState`.

### Directory Structure

```
ios-app/BNBUStudentApp/
  BNBUStudentApp.swift    — @main entry point, launch arg handling
  Core/
    Models.swift           — All data models (Codable, Identifiable)
    AppState.swift         — Single source of truth, all business logic
    AppLocalStore.swift    — UserDefaults persistence (workspace + draft)
    MockStudentRepository.swift — StudentRepository protocol + mock/empty impls
    StudentAPIClient.swift — API endpoint stubs (not connected to real backend)
    Theme.swift            — Design tokens (BNBUTheme colors) + utility extensions
  Features/
    AppRootView.swift      — 5-tab layout (首页/课程/打卡/成绩/我的) with badges
    LoginView.swift        — Demo login screen
    DashboardView.swift    — Home: progress, risk, action plan, tasks, notices
    CoursesView.swift      — Course list with section-level drill-down
    CheckInView.swift      — Tasks / submit / records segmented view
    GradesView.swift       — Grade breakdown + total score panel
    ProfileView.swift      — Settings, memberships, debug panel, logout
    Components.swift       — Reusable: GridBackground, BrandMark, SwissPanel, etc.
    DetailViews.swift      — CourseDetailView, RecordDetailView, NoticeDetailView
  Resources/               — Assets
ios-app/BNBUStudentTests/  — Unit tests (model validation, hour clamping, store recovery)
ios-app/BNBUStudentUITests/ — Smoke UI tests (login, tab navigation, draft submit, empty states)
```

### Key Patterns

- **Repository injection**: `StudentRepository` protocol with `MockStudentRepository` (demo data) and `EmptyStudentRepository` (empty states). Chosen via `ProcessInfo.processInfo.arguments`.
- **Launch arguments**: `-ui-testing-reset` clears UserDefaults before AppState init; `-ui-testing-empty-state` loads empty repository. Both are used by UI tests for a clean slate.
- **Persistence model**: `AppLocalStore` serializes `StudentWorkspace` and `CheckInDraft` to UserDefaults as JSON. AppState reads local data first, falls back to repository. Corrupt data triggers fallback and is reported in the Debug panel.
- **Sync queue**: Local mutations (submit, supplement, mark read, reset) produce `SyncOperation` entries tracked in `workspace.syncOperations` (capped at 12). This is scaffolding for future backend sync.
- **Hour rules**: `SportHourRule.standard` = 20h total / 10h course / 10h general / 2h daily limit. `AppState.normalizedHours()` clamps to `min(task.hours, dailyLimit)`.
- **Proof rules**: Max 8 attachments, images ≤ 10MB, videos ≤ 80MB and ≤ 30s. Validated by `ProofAttachment.isValidForUpload`.
- **Theme**: `BNBUTheme` provides all colors (ink, paper, surface, muted, blue variants, line). `SwissPanel`, `GridBackground`, `BrandMark` are the core visual primitives.
- **Accessibility**: Key views and buttons have `.accessibilityIdentifier()` for UI testing.
