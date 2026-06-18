# BNBU 学生端 iOS App MVP 交付说明

交付版本：`BNBUStudent-iOS-MVP-20260613-v1`

交付日期：2026-06-13

Bundle ID：`edu.bnbu.student.mvp`

开发形态：原生 SwiftUI iOS App，本地 Mock 数据，暂未接真实后端。

## 交付内容

- `BNBUStudent-Simulator-Debug.app.zip`
  - 可安装到 iOS Simulator 的 Debug 预览包
  - 包含演示凭证入口，便于负责人无需真实相册素材也能走通提交打卡流程
- `BNBUStudent-iOS-Source.zip`
  - iOS 工程源码包
  - 包含 `BNBUStudent.xcodeproj`、App 源码、UI Tests、Unit Tests 和项目 README
- `screenshots/`
  - 当前 28 张模拟器验证截图
- `RUN-模拟器运行命令.md`
  - 模拟器安装、启动、空状态预览命令
- `QA-验证记录.md`
  - 当前已验证项、未完成真机项、签名限制说明

## 当前产品范围

本版聚焦 BNBU 学生端 App 第一阶段：

- 学生登录 / 演示登录
- 首页体育学时进度看板
- 我的课程，按课程代码 + Section 区分教学班
- 打卡任务列表，区分课程相关和其他运动
- 提交打卡，支持图片 / 视频凭证 UI、草稿、提交确认
- 打卡记录，支持待审核、已通过、被驳回、需补材料
- 补材料闭环
- 成绩进度与总分预估
- 校队 / 社团抵扣状态
- 通知 / 截止提醒
- 设置页、本地调试和退出登录
- 空状态、异常状态、本地数据恢复提示

## 重要限制

- 本版不包含老师端或管理端功能；这些已由 Web 端承担。
- 本版未接真实后端，所有数据来自本地 Mock 和本地持久化。
- 当前 Mac 没有 Apple Development 证书，无法生成可安装真机的签名 IPA。
- 已完成 iPhoneOS arm64 编译校验，但真机安装和权限弹窗实测需要补齐 Apple Developer Team / 证书 / provisioning profile 后继续。

## 建议评审方式

优先使用 iOS Simulator 评审：

1. 解压本目录下的 `BNBUStudent-Simulator-Debug.app.zip`
2. 按 `RUN-模拟器运行命令.md` 安装到模拟器
3. 进入 App 后点击“演示登录”
4. 重点评审首页、课程、打卡提交、补材料、成绩、通知、设置和空状态

若需要真机评审，需要先在 Xcode 中配置 Apple Developer Team 并重新 Archive / Export。
