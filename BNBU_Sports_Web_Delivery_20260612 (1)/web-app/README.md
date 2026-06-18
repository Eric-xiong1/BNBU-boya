# BNBU 体育成绩管理 Web

这是 BNBU 体育成绩管理 Web 端交付版本，覆盖：

- 体育任课老师 Web
- 体育部管理员 Web
- 校队/社团负责人 Web

学生端定位为原生 App，不在本 Web 项目中实现。

## 本地预览

当前正式预览地址：

```text
http://127.0.0.1:4174/index.html?fresh=quality-v1
```

如需重新启动：

```bash
node web-app/preview-server.cjs
```

`preview-server.cjs` 会提供本地静态预览，并附带 CSP、`X-Frame-Options`、`X-Content-Type-Options`、`Referrer-Policy`、`Permissions-Policy`、no-store 缓存策略和基础路径穿越防护。

## 入口角色

登录页支持三个演示角色：

| 角色 | 说明 |
|---|---|
| 体育任课老师 | 课程、任务、名单、打卡审核、四块成绩、导出 |
| 体育部管理员 | 全校看板、规则配置、组织抵扣审核、成绩归档、接口联调交付 |
| 校队/社团负责人 | 校队/社团成员认证、批量导入、身份确认 |

## 课程与 Section

老师端管理的最小单位是教学班：

```text
课程代码 + Section
```

例如 `GEPE101 / Section 1004` 和 `GEPE101 / Section 1005` 是两个不同教学班，名单导入、任务、异常审核、成绩汇总和归档都必须隔离。课程名单 CSV 需要同时提供 `课程代码` 和 `Section`。

Section 通常是四位数字。前端导入可接受：

```text
1004
Section 1004
section 1004
```

## 视觉标准

正式样式文件：

```text
styles-campus-blue.css
```

主色：

```text
#3A9DF6
#7EBEFB
```

## 自测

在项目根目录运行：

```bash
node web-app/self-test.cjs
```

自测覆盖：

- 29 个 Web 路由渲染
- 角色权限回退
- 课程名单 CSV 预检
- 组织成员 CSV 预检
- 异常审核通过与驳回回滚
- 管理端接口联调交付页
- API 健康检查 mock
- 交付导出函数
- 稳定性 / 安全 / 兼容性门禁渲染
- API URL 策略、请求超时/重试元数据
- 运行期错误兜底和本地状态污染防护

## 质量烟测

启动 Web 预览和 mock API 后，可运行：

```bash
node web-app/quality-smoke.cjs
```

默认会检查：

- Web 预览返回 200
- Web 安全响应头存在
- POST 被拒绝为 405
- 路径穿越探测不能读到项目外文件
- mock API 健康检查、CORS 和安全头正常
- Web 静态资源 200 并发请求全部成功
- mock API 健康接口 200 并发请求全部成功

可通过环境变量调整：

```bash
CONCURRENCY=200 WEB_URL=http://127.0.0.1:4174 API_URL=http://127.0.0.1:8080/api/health node web-app/quality-smoke.cjs
```

## 稳定性、安全、兼容性

当前前端交付基线：

- 目标联调容量：200 名 Web 用户同时登录操作，前端以静态资源交付，真实并发写入压力由后端连接池、队列、限流和水平扩展承接。
- API 请求策略：5 秒超时，最多重试 2 次，5xx 或网络失败时使用递增退避。
- 安全策略：CSP、拒绝 frame 嵌套、禁用 MIME sniffing、限制 referrer、API URL 校验、用户输入输出转义。
- 浏览器目标：Chrome、Edge、Safari、Firefox 最近两个稳定版本。
- 降级策略：`localStorage` 不可用时回退默认演示状态；`AbortController` 不可用时仍保留请求错误兜底。

## 后端交付

后端负责人优先阅读：

```text
backend-handoff/README.md
backend-handoff/openapi.yaml
backend-handoff/data-dictionary.md
backend-handoff/sample-payloads.json
backend-handoff/integration-checklist.md
```

管理端内置页面：

```text
体育部管理员 -> 接口联调交付
```

该页面可以配置 API Base URL、检查后端健康状态，并导出状态快照、路由矩阵、接口清单和交付包 manifest。

## Mock API

后端未启动前，可用项目内置 mock API 测试联调面板：

```bash
node backend-handoff/mock-api.cjs
```

然后在管理端 `接口联调交付` 页面点击 `检查后端连接`。
