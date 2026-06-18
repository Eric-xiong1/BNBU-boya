const fs = require("fs");
const vm = require("vm");

const code = fs.readFileSync(new URL("./app.js", `file://${__dirname}/`), "utf8");
const app = { innerHTML: "" };
const storage = new Map();
const downloads = [];

const context = {
  console,
  downloads,
  fetch: async () => ({
    ok: true,
    status: 200,
    statusText: "OK",
    text: async () => "{\"ok\":true}",
  }),
  Blob: function BlobMock(parts, options) {
    this.parts = parts;
    this.options = options;
  },
  URL: {
    createObjectURL: () => "blob:mock",
    revokeObjectURL: () => {},
  },
  window: {
    __BNBU_SUPPRESS_RENDER_ERRORS: true,
    localStorage: {
      getItem: (key) => (storage.has(key) ? storage.get(key) : null),
      setItem: (key, value) => storage.set(key, value),
      removeItem: (key) => storage.delete(key),
    },
    location: { reload: () => {} },
  },
  document: {
    querySelector: (selector) => (selector === "#app" ? app : null),
    createElement: () => ({
      click: () => downloads.push(true),
      set href(value) {
        this._href = value;
      },
      set download(value) {
        this._download = value;
      },
    }),
    addEventListener: () => {},
  },
  setTimeout,
  clearTimeout,
};

const tests = `
  (async () => {
    const failures = [];
    const roles = [
      ["teacher", teacherNav],
      ["admin", adminNav],
      ["manager", managerNav],
    ];

    for (const [role, nav] of roles) {
      state.loggedIn = true;
      state.role = role;
      for (const [route] of nav) {
        state.route = route;
        try {
          renderRoute();
          if (!app.innerHTML || app.innerHTML.length < 500) failures.push(route + ": short html");
          if (app.innerHTML.includes("页面建设中")) failures.push(route + ": fallback page");
          if (app.innerHTML.includes("undefined")) failures.push(route + ": contains undefined");
          if (app.innerHTML.includes("NaN")) failures.push(route + ": contains NaN");
        } catch (error) {
          failures.push(route + ": " + error.message);
        }
      }
    }

    state.role = "teacher";
    state.route = "admin-dashboard";
    renderRoute();
    if (state.route !== "teacher-dashboard") failures.push("role fallback failed");

    mergeState(state, { "__proto__": { polluted: true }, unknownKey: "ignored" });
    if ({}.polluted || state.unknownKey) failures.push("state merge accepted unsafe keys");

    state.courseId = "gepe";
    const rosterRows = importRowsFromCsv("姓名,学号,学院,班级,课程代码,Section,选课状态\\n许一,22309901,工商管理学院,2026A,GEPE101,1004,已选\\n许二,22309902,数据科学学院,2026B,GEPE101,Section 1004,已选\\n许三,22309903,人文社科学院,2026C,GEPE101,section 1004,已选\\n许四,22309904,人文社科学院,2026D,GEPE101,9999,已选");
    state.importPreview = buildImportPreview(rosterRows);
    if (state.importPreview.filter((row) => row.valid).length !== 3) failures.push("roster import validation failed");
    if (!state.importPreview.some((row) => row.status === "Section不匹配")) failures.push("section mismatch validation failed");

    const memberRows = importMembershipRowsFromCsv("组织,学生姓名,学号,有效期,认证状态,备注\\n跑步社,新同学,22309951,2026-09-01,认证有效,CSV导入\\n不存在社,无效同学,22309952,2026-09-01,待确认,CSV导入", "club");
    state.managerImportPreview = buildMembershipImportPreview(memberRows, "club");
    if (state.managerImportPreview.filter((row) => row.valid).length !== 1) failures.push("membership import validation failed");

    const review = state.reviews.find((item) => item.id === "r1");
    const student = courseRoster("gepe").find((item) => item.id === review.studentId);
    const beforeHours = student.course;
    applyReviewDecision(review, "approve", review.hours);
    review.status = "已通过";
    if (student.course <= beforeHours) failures.push("review approve did not add hours");
    applyReviewDecision(review, "reject", review.hours);
    review.status = "已驳回";
    if (student.course !== beforeHours) failures.push("review reject did not roll back hours");

    state.loggedIn = true;
    state.role = "admin";
    state.route = "admin-api-handoff";
    renderRoute();
    if (!app.innerHTML.includes("API 联调配置")) failures.push("api handoff panel missing");
    if (!app.innerHTML.includes("稳定性 / 安全 / 兼容性基线")) failures.push("quality gates panel missing");
    state.apiBaseUrl = "http://127.0.0.1:8080";
    state.apiHealthPath = "/api/health";
    if (apiHealthUrl() !== "http://127.0.0.1:8080/api/health") failures.push("api health url mismatch");
    if (apiUrlPolicy("javascript:alert(1)").status !== "bad") failures.push("api url policy failed");
    await checkApiHealth();
    if (state.apiHealth.status !== "ok") failures.push("api health check failed");
    if (!state.apiHealth.attempts) failures.push("api retry metadata missing");

    downloadRouteMatrix();
    downloadEndpointMap();
    downloadHandoffManifest();
    downloadQualityChecklist();
    if (downloads.length < 4) failures.push("download helpers failed");

    const snapshot = integrationSnapshot();
    if (snapshot.endpointCount !== backendEndpoints.length) failures.push("snapshot endpoint mismatch");
    if (!snapshot.routes.some((item) => item.route === "admin-api-handoff")) failures.push("snapshot route missing");
    if (!snapshot.qualityGates?.length) failures.push("snapshot quality gates missing");
    if (!snapshot.apiRequestPolicy?.timeoutMs) failures.push("snapshot api request policy missing");
    const manifest = handoffManifest();
    if (!manifest.frontendFiles.includes("web-app/quality-smoke.cjs")) failures.push("quality smoke missing from manifest");

    const savedRules = state.admin.gradeRules;
    state.admin.gradeRules = null;
    state.route = "admin-dashboard";
    renderRoute();
    if (!app.innerHTML.includes("页面遇到错误")) failures.push("runtime error guard failed");
    state.admin.gradeRules = savedRules;
    state.route = "admin-api-handoff";
    renderRoute();
    if (!app.innerHTML.includes("API 联调配置")) failures.push("runtime recovery failed");

    if (failures.length) throw new Error(failures.join(" | "));
    globalThis.__result = {
      routes: roles.reduce((sum, [, nav]) => sum + nav.length, 0),
      endpoints: backendEndpoints.length,
      downloads: downloads.length,
      health: state.apiHealth.status,
      qualityGroups: snapshot.qualityGates.length,
    };
  })()
`;

Promise.resolve(vm.runInNewContext(`${code}\n${tests}`, context, { timeout: 5000 }))
  .then(() => {
    console.log(`BNBU Web self-test passed: ${JSON.stringify(context.__result)}`);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
