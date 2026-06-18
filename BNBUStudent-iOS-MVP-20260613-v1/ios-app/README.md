# BNBU Student iOS App

SwiftUI 原生学生端 MVP，第一阶段聚焦体育打卡与体育成绩透明化，不包含老师端或管理端功能。

## 范围

- 学生演示登录
- 首页体育学时进度看板：总 20h、课程相关 10h、其他运动 10h
- 我的课程：按 `课程代码 / Section` 展示教学班
- 打卡任务、提交打卡、图片/视频凭证入口、打卡记录与老师反馈
- 成绩进度：体育打卡、专项考试、平时表现 / 签到、体测、总分预估
- 校队 / 社团认证与其他运动抵扣状态
- 通知 / 截止提醒
- 设置、当前学生信息、退出登录、版本信息

## 数据与后端对齐

当前使用本地 mock 数据。模型命名与字段语义贴合 `backend-handoff`：

- `Course`
- `StudentProgress`
- `CourseTask`
- `CheckInRecord` / `ReviewRecord` 视角
- `Membership`
- `GradeRow`
- `ProofAttachment`
- `CheckInDraft`

当前提交记录、通知已读与打卡草稿会写入 `UserDefaults`，由 `Core/AppLocalStore.swift` 管理。后续接真实 API 时，可以在 `Core/MockStudentRepository.swift` 同级新增网络 repository，并保留 `AppState` 作为学生端状态入口。

本地操作会进入 `SyncOperation` 队列，用于展示“待同步”状态：提交打卡、补交材料、通知已读、重置演示数据都会留下本地操作记录。当前仍不会请求真实后端，`Core/StudentAPIClient.swift` 仅保留登录、体育总览、打卡记录、补交材料、运动身份、通知等 API 路径占位。

## 构建

```bash
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudent -configuration Debug -sdk iphonesimulator build
```

UI smoke test bundle 编译：

```bash
xcodebuild -project ios-app/BNBUStudent.xcodeproj -target BNBUStudentUITests -configuration Debug -sdk iphonesimulator build
```

当本机 Xcode SDK 与已安装 Simulator runtime 匹配时，可运行：

```bash
xcodebuild test -project ios-app/BNBUStudent.xcodeproj -scheme BNBUStudent -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Bundle ID:

```text
edu.bnbu.student.mvp
```

## 本轮验证

- Xcode 26.5 target 构建通过，产物位于 `ios-app/build/Debug-iphonesimulator/BNBUStudent.app`
- 已安装并启动到 iPhone 17 Pro Simulator（iOS 26.4）
- 已验证演示登录、首页进度、课程 Section、任务时长上限、凭证规则、提交确认、补材料复审、草稿保存、待审核记录、成绩页、校队 / 社团抵扣、通知全部已读、设置页与本地调试面板
- 关键截图位于 `ios-app/build/screenshots`

## 第二轮迭代

- 课程卡片可进入教学班详情，展示 Section、老师、截止时间、课程相关缺口和本教学班任务
- 打卡任务支持按 `全部 / 课程相关 / 其他运动` 筛选
- 提交打卡新增图片 / 视频凭证区域，并校验至少 1 个凭证
- 打卡记录支持状态筛选，并可进入记录详情查看凭证数量、老师反馈和学生说明
- 通知可进入详情并标记为已读
- 新增 `StudentAPIClient`，预留学生端 API 请求路径：登录、体育总览、打卡记录、运动身份、通知

## 第三轮迭代

- 新增 `AppLocalStore`，使用 `UserDefaults` 持久化学生工作台、通知已读状态、提交后的本地记录与打卡草稿
- `CheckInRecord` 增加 `proofFiles`，记录详情可展示具体图片 / 视频凭证文件
- 提交页接入 SwiftUI `PhotosPicker`，支持从相册选择图片/视频；保留“拍摄占位”按钮，方便模拟器完整走提交审核流程
- 提交页支持保存、恢复、清空本地草稿；提交成功后自动清理草稿
- 设置页展示未读通知数、打卡草稿状态，并提供“重置本地演示数据”入口
- 新增验证截图：
  - `ios-app/build/screenshots/06-record-proof-files.jpg`
  - `ios-app/build/screenshots/07-profile-settings-local-state.jpg`

## 第四轮 Debug / 优化

- 修复课程详情的相关记录过滤：教学班详情只展示属于该 Section 的课程记录，不再混入无课程归属的组织抵扣记录
- 修复提交时长边界：提交页 Stepper、展示文案、草稿保存和最终提交均统一使用 `min(task.hours, dailyLimit)`，例如 1.5h 任务不能提交 2h
- 清理旧的未使用凭证占位组件，避免后续误读实现状态
- 新增设置页“本地调试”面板，展示活跃任务、本地记录、待审核记录、需补材料、草稿凭证和 Bundle ID
- 调整 Debug 构建配置 `ONLY_ACTIVE_ARCH = NO`，消除命令行 target build 的 active arch 警告
- 已扫描本次运行日志，无 App 级 crash/fatal/exception；仅存在 iOS Simulator 系统级 WebKit/WebCore accessibility duplicate class 提示
- 新增验证截图：
  - `ios-app/build/screenshots/08-debug-panel.jpg`

## 第五轮迭代

- 新增补材料闭环：`需补材料` 与 `被驳回` 记录可在打卡记录页直接进入补交模式
- 补交材料会合并新凭证、更新原记录状态为 `待审核`，并新增“补充材料已提交”通知
- 首页新增“待处理”面板，汇总需补材料、待审核、未读通知，学生可以一眼看到要处理的事项
- 底部 Tab 增加 badge：打卡显示待处理记录数，我的显示未读通知数
- 通知区域新增“全部已读”，可一次性清空未读状态并持久化到本地
- 新增验证截图：
  - `ios-app/build/screenshots/09-supplement-resubmitted.jpg`
  - `ios-app/build/screenshots/10-notifications-read.jpg`

## 第六轮迭代

- 新增本地同步准备面板：展示当前数据源、API Base URL、待同步操作数、最近本地操作和操作队列
- 新增 `SyncOperation` 模型，记录提交打卡、补交材料、通知已读和重置数据等本地操作，为后续替换真实网络 repository 做准备
- 记录详情页支持直接发起“补交材料 / 重新提交材料”，学生看完老师反馈后可一键进入对应补交表单
- `StudentAPIClient` 新增补交材料接口占位和 `SupplementSportRecordRequest`
- 已验证详情页重新提交入口、补交提交、记录状态更新、同步队列展示
- 新增验证截图：
  - `ios-app/build/screenshots/11-record-detail-resubmit.jpg`
  - `ios-app/build/screenshots/12-sync-readiness.jpg`

## 第七轮迭代

- 通知模型新增 `NoticeCategory`，支持截止提醒、审核反馈、组织认证、系统通知分类；旧本地数据会按标题和内容自动推断分类
- “我的”页通知区域新增筛选：全部、未读、截止、审核，通知卡片显示分类图标和标签
- 通知详情页显示通知分类与未读 / 已读状态
- 成绩页新增总分计算面板，展示四项成绩权重、加权贡献和四舍五入后的总分预估
- 记录详情页新增审核进度时间线，清晰展示学生提交、老师审核、最终结果三步状态
- 已验证成绩公式、通知分类筛选、记录审核时间线；构建和模拟器运行通过
- 新增验证截图：
  - `ios-app/build/screenshots/13-grade-formula.jpg`
  - `ios-app/build/screenshots/14-notice-filter.jpg`
  - `ios-app/build/screenshots/15-record-review-timeline.jpg`

## 第八轮迭代

- 首页“待处理”面板新增快捷入口：处理打卡、看通知、看成绩，可直接切换到底部对应 Tab
- 首页新增“本周行动计划”，根据课程相关缺口、补材料、待审核、未读通知自动生成学生下一步行动建议
- AppRoot 将 `TabView` 的选中状态通过闭包传给首页，避免引入额外全局路由
- 已验证首页快捷入口到打卡 / 我的 / 成绩三处跳转；构建和模拟器运行通过
- 新增验证截图：
  - `ios-app/build/screenshots/16-dashboard-action-plan.jpg`

## 第九轮迭代

- 上传凭证面板新增权限状态区：相册显示“仅所选文件”，摄像头显示待授权 / 已允许 / 已拒绝 / 系统限制 / 设备不可用
- 相册继续使用系统 `PhotosPicker`，只读取学生主动选择的图片或视频，不请求完整相册访问
- “拍摄”接入真实摄像头权限链路：首次点击触发系统授权弹窗，允许后进入系统相机；拒绝后可跳转系统设置
- 模拟器或无摄像头设备会提示设备不可用，并保留“添加占位凭证”兜底，方便演示完整提交流程
- 补充麦克风隐私用途说明，用于后续录制视频凭证声音
- 已验证系统摄像头授权弹窗、允许后相机呈现、权限状态更新为“已允许”；模拟器拍照预览未稳定生成最终附件，真机仍需继续验证完整拍摄回填
- 新增验证截图：
  - `ios-app/build/screenshots/17-proof-permissions-camera.jpg`

## 第十轮稳定性 / Debug 优化

- 新增 `LocalStoreHealth`，本地存储可区分工作台 / 草稿的未保存、已读取、解码失败、已丢弃状态
- `AppLocalStore` 的读写结果不再完全静默：写入工作台、保存草稿、清理草稿、重置演示数据都会更新最近读写状态
- App 启动时如遇旧版本或损坏的 `UserDefaults` 数据，会回退到 mock 工作台，并在 Debug 面板显示解码失败原因
- `AppState` 新增数据完整性自检：课程 / 任务 / 记录 ID 重复、任务课程引用失效、记录课程引用失效、草稿任务失效都会显示到本地调试面板
- “我的 - 本地调试”新增数据完整性、工作台存储、草稿存储、最近写入和最近本地事件，方便后续接真实 API 前定位状态问题
- 已验证命令行构建、模拟器安装启动、登录后 Debug 面板渲染；运行日志无 App 级 crash/fatal/exception
- 新增验证截图：
  - `ios-app/build/screenshots/18-debug-store-health.jpg`

## 第十一轮稳定性 / UI 回归

- 新增 `BNBUStudentUITests` UI 测试 target，包含 `BNBUStudentSmokeUITests`
- UI smoke 覆盖演示登录、首页、课程、打卡、成绩、我的、Debug 面板和数据完整性状态
- App 新增 `-ui-testing-reset` 启动参数，测试启动时清空本地 `UserDefaults`，避免手动演示数据污染回归结果
- 为登录按钮、五个底部 Tab、五个根页面和 Debug 面板补充稳定 accessibility identifiers
- 已验证 App target 与 UI test target 均可编译；当前机器 Xcode 26.5 SDK 与 iOS 26.4 Simulator runtime 不完全匹配，`xcodebuild test` 精确运行需等本机安装匹配 runtime 后执行
- 已用 Simulator 手动 smoke 验证同一条路径：登录、切换课程 / 打卡 / 成绩 / 我的、滚动到 Debug 面板；运行日志无 App 级 crash/fatal/exception
- 新增验证截图：
  - `ios-app/build/screenshots/19-ui-smoke-debug-anchor.jpg`

## 第十二轮凭证规则 / 提交确认

- 新增 `ProofUploadRule`，集中定义凭证数量和大小限制：最多 8 个、图片不超过 10MB、视频不超过 80MB，并在提交前统一校验
- 凭证面板展示上传规则、剩余名额、相册 / 摄像头权限状态和操作反馈，避免学生不知道为什么按钮不可用
- 凭证列表改为预览卡片，展示文件名、类型、大小、来源和“可提交 / 超限”状态；超限凭证会阻止提交
- Debug 构建新增“添加演示凭证”按钮，方便 Simulator、评审和 UI 回归不依赖真实相册文件；Release 构建不会包含该入口
- 提交打卡前新增确认弹窗，明确任务、小时数、凭证数量以及“进入老师审核队列”的后果
- 已验证 App target 与 UI test target 均可编译；已用 Simulator 走通登录、任务提交、添加演示凭证、提交确认、待审核记录生成；运行日志无 App 级 crash/fatal/exception
- 新增验证截图：
  - `ios-app/build/screenshots/20-proof-rules-preview.jpg`
  - `ios-app/build/screenshots/21-submit-confirmation.jpg`
  - `ios-app/build/screenshots/22-record-pending-after-proof.jpg`

## 第十三轮关键前端收尾

- 凭证选择体验继续打磨：图片 / 视频会生成缩略图预览，视频凭证展示时长；视频超过 30 秒、图片超过 10MB、视频超过 80MB 或总数超过 8 个都会在提交前拦截
- 凭证删除新增二次确认，提示删除后不会随本次打卡提交，避免误删材料
- 相册导入会在后台读取必要的本地元数据，避免大文件先进入重处理；摄像头路径继续保留系统权限链路和模拟器占位凭证
- 完善空状态和异常状态：无任务、无可提交任务、无课程、无通知、无校队 / 社团认证、任务已关闭、本地草稿 / 工作台数据损坏恢复都有明确 UI
- 首页风险提示修正空数据场景，不会把“其他运动缺口”误判成组织认证已覆盖
- 新增 `EmptyStudentRepository` 与 `-ui-testing-empty-state` 启动参数，方便评审和 UI 回归直接查看空状态
- UI smoke case 扩展到提交草稿、正式提交、补材料、通知已读、退出登录和空状态；新增 `BNBUStudentTests` 单元测试 target，覆盖凭证规则、小时数裁剪、本地存储损坏恢复和过期草稿丢弃
- 已验证 App target、UI test target、unit test target 均可编译；当前本机 Xcode 26.5 SDK 与 iOS 26.4 Simulator runtime 不完全匹配，`xcodebuild test` 需要安装匹配 runtime 后再跑完整自动化
- 已用 Simulator 手动验证：凭证缩略图、删除确认、关闭任务不可提交、空课程、空任务、空提交页、空认证、空通知；运行日志无 App 级 crash/fatal/exception
- 真机仍建议补充复测：首次摄像头授权、拍照 / 录像回填、相册完整 / 限制 / 拒绝路径，以及大图片 / 视频选择后的内存和耗时表现
- 新增验证截图：
  - `ios-app/build/screenshots/23-proof-thumbnail-delete-ready.jpg`
  - `ios-app/build/screenshots/24-proof-delete-confirmation.jpg`
  - `ios-app/build/screenshots/25-closed-task-disabled.jpg`
  - `ios-app/build/screenshots/26-empty-dashboard-risk.jpg`
  - `ios-app/build/screenshots/27-empty-submit-state.jpg`
  - `ios-app/build/screenshots/28-empty-profile-state.jpg`

## 第十四轮真机验证状态

- 已检测到真机：`LABYR1NTH的iPhone`，iOS `26.4.2`，UDID `00008150-000260523438401C`
- 当前 CoreDevice 状态为 `unavailable / offline`，详情显示 `pairingState: paired`、`tunnelState: unavailable`、`ddiServicesAvailable: false`
- 已完成 iPhoneOS 真机架构编译校验：`BNBUStudent` 使用 `iphoneos26.5` SDK 编译到 arm64 成功，产物位于 `ios-app/build-device/Debug-iphoneos/BNBUStudent.app`
- 当前 Mac Keychain 中没有可用 Apple Development 证书：`security find-identity -v -p codesigning` 返回 `0 valid identities found`
- 因此本轮还不能完成“安装到真机并操作系统权限弹窗”的最终验证；需要先完成设备可用状态和开发者签名
- 继续真机验证前请确认：
  - iPhone 已连接到 Mac、保持解锁，并在系统弹窗中选择“信任此电脑”
  - iPhone 已开启“设置 > 隐私与安全性 > 开发者模式”
  - Xcode 已登录 Apple ID，并为 `BNBUStudent` target 选择可用 Team，生成 Apple Development 证书 / provisioning profile
  - Xcode Components 中已安装与当前 Xcode / 设备匹配的 iOS platform 支持
- 设备和签名准备好后，需继续实测：
  - 摄像头真实拍照回填
  - 摄像头真实录像回填与 30 秒限制
  - 相册完整访问 / 限制访问 / 拒绝访问
  - 权限拒绝后跳系统设置再授权
  - 大图片、大视频选择后的缩略图生成、时长读取和页面响应
