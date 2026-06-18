# BNBU 体育成绩管理 Web 交付包说明

交付日期：2026-06-12

## 交付范围

- `web-app/`：正式 Web 前端代码、样式、预览服务、自测脚本和质量烟测脚本
- `backend-handoff/`：后端联调说明、OpenAPI 草案、数据字典、示例 payload、联调检查清单、mock API
- `BNBU校园综合平台产品文档_整合版.md`：产品文档 v1.9
- `BNBU校园综合平台_Web端开发任务拆分表.docx`：开发任务拆分表
- `UI_Style.png`：视觉风格参考
- `DELIVERY_VERIFICATION.md`：交付验证记录

## 快速启动

在交付包根目录运行：

```bash
node web-app/preview-server.cjs
```

打开：

```text
http://127.0.0.1:4174/index.html?fresh=quality-v1
```

如需 mock API：

```bash
node backend-handoff/mock-api.cjs
```

健康检查地址：

```text
http://127.0.0.1:8080/api/health
```

## 验证命令

```bash
node web-app/self-test.cjs
node web-app/quality-smoke.cjs
```

## 当前结论

Web 前端已达到后端联调交付状态。真实上线前仍需接入正式后端、真实登录鉴权、真实文件上传/导出服务，并完成 Chrome、Edge、Safari、Firefox 的人工主流程验收。
