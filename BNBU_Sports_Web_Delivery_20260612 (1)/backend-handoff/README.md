# BNBU 体育成绩管理 Web 后端交接说明

日期：2026-06-12
范围：老师端 Web、体育部管理端 Web、校队/社团负责人 Web
不包含：学生端 App 后端细节、学校官网成绩系统写入、真实文件存储服务

## 交付状态

当前 Web 端已完成可演示的前端闭环，数据暂存在浏览器 `localStorage`，存储键为 `bnbuSportsWebStateV1`。后端接入时建议按本目录的 `openapi.yaml` 实现 REST API，再把前端的本地状态读写替换为 HTTP 请求。

正式预览入口：

```text
http://127.0.0.1:4174/index.html?fresh=quality-v1
```

正式 Web 文件：

```text
web-app/index.html
web-app/app.js
web-app/styles-campus-blue.css
web-app/self-test.cjs
web-app/quality-smoke.cjs
web-app/preview-server.cjs
```

后端交付材料：

```text
backend-handoff/README.md
backend-handoff/openapi.yaml
backend-handoff/data-dictionary.md
backend-handoff/sample-payloads.json
backend-handoff/integration-checklist.md
backend-handoff/mock-api.cjs
```

管理端内置交付页面：

```text
角色：体育部管理员
页面：接口联调交付
能力：导出状态快照、导出路由矩阵、导出接口清单、导出交付包 Manifest、配置 API Base URL、检查后端连接
```

## 角色与页面

| 角色 | Web 路由前缀 | 已覆盖页面 |
|---|---|---|
| 体育任课老师 | `teacher-*` | 课程工作台、我的课程、课程任务、名单导入、学生名单、打卡进度、异常审核、专项考试、签到/平时分、体测录入、成绩汇总、成绩导出 |
| 体育部管理员 | `admin-*` | 管理端首页、全校数据看板、学期设置、课程与老师、用户管理、体育学时标准、成绩规则、体测换算表、导出模板、校队管理、社团管理、组织抵扣审核、成绩归档审核、操作日志、接口联调交付 |
| 校队/社团负责人 | `manager-*` | 校队成员认证、社团成员认证 |

学生端定位为原生 App，不在当前 Web 路由中实现。

## 后端优先级

1. 账号与角色：`POST /auth/login`、`GET /auth/me`
2. 老师课程工作台：课程列表、学生名单、进度统计、异常审核
3. 成绩录入：专项、平时、体测三类批量保存
4. 成绩汇总与导出：预检、问题清单、CSV/Excel 生成
5. 管理端配置：学期、课程、用户、体育学时规则、成绩权重、体测换算、导出模板
6. 组织抵扣：校队/社团成员认证、管理员复核、抵扣生效
7. 成绩归档：老师提交预检，管理员确认归档或退回清理
8. 操作日志：关键写操作必须落审计日志

## 核心业务规则

- 老师实际管理的不是抽象课程代码，而是某门课的某个教学班，即 `courseCode + section`。
- 同一课程代码可以有多个 Section，不同 Section 的学生名单、任务、审核、成绩和归档必须隔离。
- Section 真实数据通常是四位数字，例如 `1004`；前端展示为 `Section 1004`，导入时可接受 `1004`、`Section 1004`、`section 1004` 等写法，服务端应标准化为 `1004` 后比较。
- 每学期体育学时总计默认 20 小时。
- A 类为课程相关，默认 10 小时。
- B 类为其他运动，默认 10 小时。
- 校队或体育类社团认证有效后，可抵扣 B 类其他运动小时。
- 四块成绩默认权重：体育打卡 25%、专项考试 30%、平时表现 20%、体测 25%。
- 导出前必须检查：体测缺失或过低、打卡未满、异常未处理、导出模板字段不匹配。
- 学校最终成绩录入仍由老师在官方系统完成，本系统只负责导入前整理、预检、导出。

## CSV 导入规则

### 课程名单

推荐表头：

```text
姓名,学号,学院,班级,课程代码,Section,选课状态
```

前端当前校验：

- 姓名必填
- 学号必填
- 学院必填
- 课程代码必须等于当前教学班的课程代码
- Section 必须等于当前教学班的 Section
- 选课状态必须为 `已选`
- 当前课程已存在学生不可重复导入
- 同一 CSV 内学号不可重复

### 组织成员

推荐表头：

```text
组织,学生姓名,学号,有效期,认证状态,备注
```

前端当前校验：

- 组织必须存在于管理员配置的校队/社团列表
- 学生姓名必填
- 学号必填
- 认证状态仅支持：`待确认`、`认证有效`、`不通过`、`非体育类`
- 同一组织内同一学号不可重复导入
- 认证有效且组织规则允许抵扣时，自动设置为 `可抵扣`

## 推荐错误码

| code | HTTP | 含义 |
|---|---:|---|
| `AUTH_REQUIRED` | 401 | 未登录或 token 失效 |
| `FORBIDDEN_ROLE` | 403 | 当前角色无权限 |
| `RESOURCE_NOT_FOUND` | 404 | 课程、学生、组织或记录不存在 |
| `VALIDATION_FAILED` | 422 | 字段校验失败 |
| `DUPLICATE_RECORD` | 409 | 重复导入或重复配置 |
| `EXPORT_BLOCKED` | 409 | 导出前检查未通过 |
| `ARCHIVE_BLOCKED` | 409 | 归档前仍存在预检问题 |

## 前端替换点

当前 `web-app/app.js` 中的 `state` 是后端数据源的临时替代。后端接入时推荐按以下方式替换：

- `hydrateState()`：替换为登录后拉取当前角色所需的初始数据。
- `saveState()`：后端接入后不再全量保存本地状态，只保留少量 UI 偏好。
- CSV 解析与预检：可继续前端预检，但最终以服务端校验结果为准。
- 成绩导出：前端目前生成 CSV；正式版建议由后端生成文件，前端只触发下载。
- 操作日志：前端目前写入本地 `state.logs`；正式版必须由后端审计记录生成。

## 联调配置

管理端 `接口联调交付` 页面支持配置：

| 配置 | 默认值 | 说明 |
|---|---|---|
| API Base URL | `http://127.0.0.1:8080/api` | 后端本地服务地址 |
| 健康检查路径 | `/health` | 后端可实现 `GET /api/health`，也可在页面里改成实际路径 |

健康检查只用于联调，不影响当前前端演示数据。检查结果会显示 URL、HTTP 状态、耗时和响应摘要。

## 稳定性与安全基线

Web 前端已补齐以下交付基线：

- 本地预览服务使用 `web-app/preview-server.cjs`，带 CSP、拒绝 iframe 嵌套、禁止 MIME sniffing、referrer 策略、权限策略、no-store 缓存和路径穿越防护。
- API 请求统一经过前端请求客户端，默认 5 秒超时、最多重试 2 次，并记录耗时、重试次数和错误摘要。
- API Base URL 会校验协议和非法字符；本地 HTTP 仅用于 `127.0.0.1`、`localhost`、`[::1]` 调试，正式部署必须使用 HTTPS。
- 管理端 `接口联调交付` 页面新增稳定性、安全、兼容性门禁，并可导出 `BNBU-web-quality-security-checklist.csv`。
- 前端交付包提供 `node web-app/quality-smoke.cjs`，可复测安全响应头、CORS、路径防护和 200 并发烟测。
- 当前静态前端可承接 200 名 Web 用户同时访问静态资源；真实登录、导入、保存、审核、导出等并发写入压力必须由后端通过连接池、幂等、防重复提交、限流、审计和水平扩展保障。

后端建议的最低非功能验收口径：

- 200 名 Web 用户同时登录并执行常用操作时，P95 API 响应时间不高于 800ms，错误率低于 1%。
- 登录、导入、成绩保存、异常审核、组织抵扣、成绩归档、导出接口必须有服务端鉴权和角色校验。
- 写接口需要幂等键或版本号，避免老师重复点击导致重复加学时、重复导入、重复归档。
- 文件导入接口必须限制大小、行数、MIME、扩展名，并对 CSV 内容做服务端终验。
- 所有导出和归档操作必须进入审计日志。
- CORS 只允许正式 Web 域名和本地联调来源，不建议使用 `*`。

## Mock API

如需先验证前端联调面板，可在项目根目录运行：

```bash
node backend-handoff/mock-api.cjs
```

mock API 已包含基础 CORS 白名单、安全响应头、请求超时和限流模拟。可通过环境变量调整：

```bash
CORS_ORIGINS=http://127.0.0.1:4174 RATE_LIMIT_MAX=6000 node backend-handoff/mock-api.cjs
```

默认地址：

```text
http://127.0.0.1:8080/api/health
```

已提供的 mock 路径：

```text
GET /api/health
GET /api/auth/me
GET /api/teacher/courses
GET /api/teacher/courses/gepe/students
GET /api/teacher/courses/gepe/export/precheck
```

## 前端自测

在项目根目录运行：

```bash
node web-app/self-test.cjs
```

自测覆盖：

- 三个角色共 29 个 Web 路由渲染
- 角色越权路由回退
- 课程名单 CSV 预检
- 组织成员 CSV 预检
- 异常审核通过与驳回回滚
- 管理端接口联调交付页
- 健康检查 mock
- 路由矩阵、接口清单、交付 manifest 下载函数

## 质量烟测

启动 Web 预览和 mock API 后运行：

```bash
node web-app/quality-smoke.cjs
```

默认覆盖：

- Web 预览安全响应头
- 预览服务方法限制与路径穿越防护
- mock API CORS、安全头与健康检查
- Web 静态资源 200 并发请求
- mock API 健康接口 200 并发请求

## 联调验收建议

- 老师可登录并只看到自己课程。
- 同一老师切换不同课程时，名单、任务、异常、成绩互相隔离。
- 管理员修改成绩权重后，老师成绩汇总即时按新权重计算。
- 组织负责人确认成员后，老师端该学生 B 类学时显示组织抵扣。
- 老师提交成绩预检后，管理员端成绩归档审核页可看到对应状态。
- 管理员退回清理后，老师端成绩导出页能看到退回说明。
- 所有写操作能在操作日志查到 actor、action、target、time。
