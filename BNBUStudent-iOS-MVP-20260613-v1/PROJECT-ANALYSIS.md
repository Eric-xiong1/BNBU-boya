# BNBU Student iOS MVP — 项目结构与设计体系

## 一、项目层级关系

### `ios-app/` — 源代码目录

```
ios-app/
├── BNBUStudent.xcodeproj/              # Xcode 工程文件
├── BNBUStudentApp/                     # 源代码根目录
│   ├── BNBUStudentApp.swift            # @main 入口
│   ├── Core/                           # 核心层
│   │   ├── AppState.swift              # 全局状态 (ObservableObject)，所有业务逻辑入口
│   │   ├── AppLocalStore.swift         # UserDefaults 持久化（工作台 + 草稿）
│   │   ├── Models.swift                # 所有数据模型
│   │   ├── MockStudentRepository.swift # Mock 仓库 + StudentRepository 协议
│   │   ├── StudentAPIClient.swift      # API 占位（路径 / 请求结构体）
│   │   └── Theme.swift                 # 色彩系统与工具扩展
│   ├── Features/                       # 界面层
│   │   ├── AppRootView.swift           # 五 Tab 根容器
│   │   ├── LoginView.swift             # 登录页
│   │   ├── DashboardView.swift         # 首页看板
│   │   ├── CoursesView.swift           # 课程列表 + 详情
│   │   ├── CheckInView.swift           # 打卡三 Tab（任务→提交→记录）
│   │   ├── GradesView.swift            # 成绩进度
│   │   ├── ProfileView.swift           # 我的（通知/设置/Debug）
│   │   ├── DetailViews.swift           # 课程/任务/记录/通知详情页
│   │   └── Components.swift            # 共享组件层
│   └── Resources/                      # 资源目录（当前为空）
├── BNBUStudentTests/                   # 单元测试
│   └── BNBUStudentModelTests.swift     # 凭证验证、时长裁剪、存储损坏恢复
├── BNBUStudentUITests/                 # UI Smoke 测试
│   └── BNBUStudentSmokeUITests.swift   # 登录→提交→空状态全流程
└── README.md                           # 14 轮迭代完整历史
```

### `BNBUStudent.app/` — 编译产物

```
BNBUStudent.app/
├── BNBUStudent                         # 可执行二进制 (8.4MB)
├── Info.plist                          # Bundle 配置
├── PkgInfo                             # 包类型标识
└── _CodeSignature/                     # 代码签名
```

> **一句话**：`ios-app` 是源代码 + Xcode 工程，`BNBUStudent.app` 是编译产物。Bundle ID: `edu.bnbu.student.mvp`

---

## 二、架构模式

### MVVM 简化风格

没有独立的 ViewModel 层。`AppState` 兼做 Model + ViewModel，通过 `@EnvironmentObject` 注入所有 View：

```
AppState (ObservableObject, @MainActor)
 ├── workspace: StudentWorkspace     ← 全部业务数据
 ├── draft: CheckInDraft?            ← 打卡草稿（UserDefaults 持久化）
 ├── storeHealth: LocalStoreHealth   ← 本地储存健康状态
 ├── 业务方法: submitCheckIn(), markNoticeRead(), logout()...
 └── 计算属性: courseRemaining, completionRatio, activeTasks...
```

### 数据流

```
启动 → AppState.init()
  ├── try AppLocalStore.readWorkspace()     ← UserDefaults
  │   └── 失败/缺失 → MockStudentRepository.loadWorkspace()
  ├── try AppLocalStore.readDraft()
  │   └── 失效/解码失败 → 自动清理
  └── 构建 bootEvent 写入 storeHealth

运行时操作（提交/标记已读/保存草稿）
  → 更新内存 workspace/draft
  → 回写 UserDefaults
  → 记录 SyncOperation（为后续替换真实 API 准备）
```

### API 接入准备

- `StudentRepository` 协议：`MockStudentRepository`（当前）可替换为 `RemoteStudentRepository`
- `StudentAPIClient`：预留学生端 API 路径（`POST /auth/login`, `GET /sport/summary`, `POST /sport/records/:id/supplements` 等）
- `SyncOperation` 队列：所有本地操作保留记录，待同步状态清晰可追溯

### UI 自动化测试策略

| 机制 | 方式 |
|------|------|
| 启动参数 `-ui-testing-reset` | 清空 UserDefaults，从干净状态启动 |
| 启动参数 `-ui-testing-empty-state` | 使用 `EmptyStudentRepository`，展示空课程/空任务/空通知 |
| accessibilityIdentifier | 所有关键页面 (`screen.login`)、面板 (`panel.profile.debug`)、按钮 (`login.demo.button`) 均有稳定标识符 |

---

## 三、设计体系

### 核心设计语言：瑞士国际主义风格

| 特征 | 体现 |
|------|------|
| **完全无圆角** | 所有卡片、按钮、面板、进度条均为直角矩形 |
| **粗描边代替阴影** | 1.5px 黑色描边（`BNBUTheme.line = #0B0B0C`） |
| **极大号字重** | 关键数字 34-54pt `.black` 字重 |
| **全大写标签** | Eyebrow 文字使用 `caption2.weight(.black).uppercased()` |
| **装饰网格背景** | 42px 间距蓝色极浅线 (`blue.opacity(0.10)`)，所有页面共享 |

### 色彩系统

| Token | 色值 | 用途 |
|-------|------|------|
| `ink` | `#0B0B0C` | 主文字色、描边色 |
| `paper` | `#F3F9FF` | 页面背景色 |
| `surface` | `#FFFFFF` | 卡片背景色 |
| `blue` | `#3A9DF6` | 强调色、进度条填充 |
| `blueLight` | `#7EBEFB` | BrandMark 中间条 |
| `blueSoft` | `#E3F2FF` | 填充信息卡片、小计区域 |
| `muted` | `#4D6F8F` | 辅助文字、标签 |
| `line` | `#0B0B0C` | 描边色（同 `ink`） |

### 核心 UI 组件

| 组件 | 文件:行号 | 描述 |
|------|-----------|------|
| `BrandMark` | Components:35-60 | 左上角品牌标识，三个竖条矩形（黑-浅蓝-黑）+ "BNBU" 等宽黑字 |
| `SwissPanel` | Components:62-75 | 白色卡片 + 1.5px 黑色描边，`padding(18)`，所有内容区域的容器 |
| `GridBackground` | Components:7-33 | 42px 间距网格线，`Canvas` 绘制，所有页面 ZStack 背景 |
| `StatusBadge` | Components:93-109 | 状态标签，`filled` 变体黑底白字，默认蓝底黑字+描边 |
| `HourProgressBar` | Components:111-132 | 纯色蓝色进度条 + 黑描边，`GeometryReader` 自适应 |
| `PrimaryActionButton` | Components:160-178 | 黑底白字全宽按钮，`headline.weight(.black)` |
| `MetricCell` | Components:134-158 | 34pt 数字 + 全大写标签，用于仪表盘指标网格 |
| `EmptyPlaceholder` | Components:203-219 | 空状态占位，白色卡片描边 + 标题 + 说明 |
| `ReviewTimelineStep` | DetailViews:318-343 | 图标 + 文字的三步时间线（提交→审核→最终） |

### 布局规范

- 页面根结构：`ZStack { GridBackground() + ScrollView { VStack(spacing: 16-18) } }`
- 卡片间距：`18pt`（`ScrollView` 内 `VStack`），或 `12pt`（子区域）
- 卡片内边距：`18pt`（`SwissPanel`），`10-14pt`（次级卡片）
- 描边宽度：`1.5pt`（主容器），`1pt`（状态标签/次要分隔）
- 进度条高度：`12pt`

### 截图索引

所有截图位于 `screenshots/` 目录：

```
登录与主页                  打卡与凭证                 我的与调试
├── 01-login.jpg           ├── 04-records-after-      ├── 03-profile.jpg
├── 02-dashboard.jpg         submit.jpg              ├── 07-profile-settings-
├── 16-dashboard-action-   ├── 05-record-detail.jpg     local-state.jpg
   plan.jpg                 ├── 06-record-proof-       ├── 08-debug-panel.jpg
├── 26-empty-dashboard-       files.jpg              ├── 09-supplement-
   risk.jpg                 ├── 11-record-detail-        resubmitted.jpg
                            ├── 20-proof-rules-         ├── 10-notifications-
成绩与公式                     preview.jpg               read.jpg
├── 13-grade-formula.jpg   ├── 21-submit-             ├── 12-sync-readiness.jpg
├── 15-record-review-         confirmation.jpg        ├── 18-debug-store-
   timeline.jpg            ├── 22-record-pending-        health.jpg
├── 20-proof-rules-           after-proof.jpg         ├── 25-closed-task-
   preview.jpg             ├── 23-proof-thumbnail-       disabled.jpg
                            ├── 24-proof-delete-         ├── 27-empty-submit-
通知筛选                       confirmation.jpg          state.jpg
├── 14-notice-filter.jpg                               ├── 28-empty-profile-
                                                           state.jpg
```

---

## 四、迭代历史速览

| 轮次 | 重点 |
|------|------|
| 1 | SwiftUI 基础壳 + Tab 导航 + Mock 数据 + 首页进度看板 |
| 2 | 课程详情 + 打卡筛选 + 图片凭证 + 记录状态筛选 + API Client 占位 |
| 3 | UserDefaults 持久化 + PhotosPicker + 草稿保存/恢复 + 设置页 |
| 4 | 漏洞修复（记录过滤/时长边界/未用组件清理）+ Debug 面板 |
| 5 | 补材料闭环 + 首页待处理面板 + Tab badge + 全部已读 |
| 6 | SyncOperation 队列 + 记录详情重新提交 + 同步准备面板 |
| 7 | NoticeCategory 分类 + 通知筛选 + 成绩公式面板 + 审核时间线 |
| 8 | 首页快捷入口（处理打卡/看通知/看成绩）+ 本周行动计划 |
| 9 | 相机权限链路 + 权限状态展示 + 模拟器占位凭证 |
| 10 | LocalStoreHealth + 数据完整性自检 + 解码失败回退 + Debug 增强 |
| 11 | UI Smoke Test target + accessibilityIdentifiers + 空状态启动参数 |
| 12 | ProofUploadRule + 预览卡片 + 超限校验 + 提交确认弹窗 |
| 13 | 凭证缩略图 + 删除确认 + 空状态全面覆盖 + 单元测试 target |
| 14 | 真机 arm64 编译验证 + CoreDevice offline 状态记录 |
