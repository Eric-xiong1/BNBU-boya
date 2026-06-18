# BNBU 学生端 iOS App QA 验证记录

验证日期：2026-06-13

## 构建验证

- `BNBUStudent` App target：通过
- `BNBUStudentUITests` target：通过编译
- `BNBUStudentTests` target：通过编译
- iPhoneOS arm64 编译：通过，使用 `CODE_SIGNING_ALLOWED=NO` 做真机架构编译校验

## 模拟器手动验证

已在 iOS Simulator 验证：

- 演示登录
- 首页体育学时进度、缺口和风险提示
- 我的课程与 Section 展示
- 打卡任务筛选
- 任务已关闭不可提交
- 提交打卡、保存草稿、清空草稿
- 添加演示图片 / 视频凭证
- 凭证缩略图预览
- 视频时长展示和 30 秒规则提示
- 凭证数量 / 文件大小规则提示
- 凭证删除二次确认
- 提交前二次确认
- 提交后生成待审核记录
- 需补材料记录重新提交
- 老师反馈展示
- 通知分类、通知详情、全部已读
- 成绩进度和总分预估
- 校队 / 社团抵扣状态
- 设置页、退出登录、本地调试面板
- 无课程、无任务、无可提交任务、无通知、无认证等空状态
- 本地数据损坏恢复提示

## 日志状态

最近模拟器运行日志未发现 App 级：

- crash
- fatal
- exception
- assertion failed

模拟器日志中存在 iOS Simulator 系统级 WebKit / WebCore accessibility duplicate class 提示，不属于 App 代码崩溃。

## 自动化测试状态

已补充：

- UI smoke：登录、主 Tab、提交草稿、正式提交、补材料、通知已读、退出登录、空状态
- Unit tests：凭证规则、小时数裁剪、本地存储损坏恢复、过期草稿丢弃

当前机器存在 Xcode 26.5 SDK 与 iOS 26.4 Simulator runtime 不完全匹配问题，因此完整 `xcodebuild test` 需要安装匹配 runtime 后继续执行。

## 真机验证状态

已检测到真机：

- 设备名：`LABYR1NTH的iPhone`
- iOS：`26.4.2`
- UDID：`00008150-000260523438401C`

当前限制：

- CoreDevice 状态为 `offline / unavailable`
- `pairingState: paired`
- `tunnelState: unavailable`
- `ddiServicesAvailable: false`
- Mac Keychain 中 Apple Development 证书数量为 0

因此本轮未能安装到真机完成权限弹窗实测。

真机验证待补：

- 摄像头真实拍照回填
- 摄像头真实录像回填
- 相册完整访问 / 限制访问 / 拒绝访问
- 权限拒绝后跳系统设置再授权
- 大图片、大视频选择后的性能表现

## 真机交付前置条件

需要先完成：

- iPhone 解锁并信任此电脑
- iPhone 开启开发者模式
- Xcode 登录 Apple ID
- `BNBUStudent` target 配置 Apple Developer Team
- 生成 Apple Development certificate 和 provisioning profile
- 安装与 Xcode / iPhone 匹配的 iOS platform 支持

完成后可继续生成签名 `.ipa` 或通过 TestFlight 分发。
