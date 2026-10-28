# 覆盖率提升交接给 DeepSeek

## 任务与边界

请接着现有工作，把 App、Control 的覆盖率提升到至少 85%，并让 CI 全量运行后向 Codecov 上传完整报告。Control 包含 Go 后端和 Web 管理界面，需分别检查，不能让某一份高覆盖报告掩盖另一份不足。

用户明确要求：

- 不通过 `pragma: no cover`、`istanbul ignore` 或缩小统计范围跳过业务代码。
- 不只测 happy path，必须覆盖异常、边界和重要分支。
- 不允许本地全测、CI 只测一部分而上传残缺报告。
- 不滥用 carryforward。
- 保留现有 UI 和功能逻辑；为了可测试性可做小范围依赖注入，业务行为不变。
- 分批提交 commit；本轮尚未提交，不要推送或部署。
- 不清理、还原、提交用户原有的 `backup.7z` 修改；备份含凭据，不能输出其内容。
- 参考 git 历史理解意图，冲突以新 commit 为准。真正不明确的业务规则先问用户。

## 工作区与已有提交

- App：`C:\userdata\project\xzitpocket`，本轮基于 `00d559c` 继续提交。
- Control：`C:\userdata\project\xzitpocket-control`，本轮基于 `47d9343` 继续提交。
- 本轮实际运行环境：WSL Linux；Node 20.19.2，Go 1.24.4，Flutter 3.47.0 / Dart 3.13.0。
- 已搜索，没有找到 AGENTS.md。本任务没有使用技能，也没有启动子 agent。
- Python 可用 `py -3 -X utf8 -`，不要用 Windows Store 的 `python.exe` alias。

前轮项目清理已经提交，不要重做（提交号保留作参考）：

- Control：`35c841b` 全新数据库结构与资源版本；`a184316` 独立模块权限；`2d88af2` App 上报/上传学号校验；`47d9343` 删除分享码过期字段。
- App：`06f9b4c` 身份协议和下载版本；`00a95c5` 清理旧偏好、完整替换个性化快照；`c7a4637` 调休提醒和键盘避让；`00d559c` 审查文档。

## 实测状态（2026-10-28，本地）

| 范围 | 当前测量 | 目标 | 说明 |
| --- | --- | --- | --- |
| Web 行 | 99.93%，1622/1623 | 85% | `npm run test:coverage` 退出码 0 |
| Web statements | 99.11%，2138/2157 | 85% | |
| Web branches | 86.84%，1371/1579 | 85% | |
| Web functions | 99.76%，434/435 | 85% | |
| Go statements | **85.01%**，8006/9418 | 85% | 跨包 `-coverpkg=./...` 去重后统计，CI 已强制 |
| Flutter 行 | 46.33%，8674/18723 | 85% | 401 项测试通过，`--branch-coverage` |
| Flutter 分支 | 37.08%，2253/6076 | 85% | |

Web 与 Go 已达标。Flutter 仍未达标，**不能说覆盖率目标已完成**，远端 Codecov 也尚未验证。

### Web 已完成的测试（42 项，4 个文件 + harness）

`test/web/console.test.js` 13 项（登录、权限、课程、题库、分页/查询/排序、状态/归档/删除、用户/风控/错误记录、分享码、CDK）；
`configuration.test.js` 8 项（管理员密钥/权限、配置序列化与隐藏密钥、发布配置、校历时段/学院例外/日期重建）；
`uploads.test.js` 11 项（批量 PDF、进度、部分失败、XHR 错误/401、人工解析、封面/教材附件、贡献者、下载、审核文件同步）；
`dashboard.test.js` 10 项（总览指标、分布、缩放、5 个图表与交互、CDN/主机/存储桶统计、轮询、静默刷新、失败/401）；
`ai.test.js` 10 项（AI 状态/进度/标签、排队/重试/取消/下载、轮询、Prompt JSON 与 precheck 过滤、MathJax 成功/失败）；
`pages.test.js` 14 项（路由、popstate、tab 记忆、权限回退、页面 loader、页脚组件、格式化函数、分享码 JSON、管理员/用户/风控/错误记录/题库/CDK 操作）。

为让统计全部落在业务代码上，删除了 `web/app.js` 中未被任何调用方使用的 `normalizeCompactDate`（死代码），未添加任何忽略规则。

### Go 已完成的工作

新增 8 个测试文件：`internal/cloud/stats_test.go`、`cos_objects_test.go`、`internal/config/coverage_test.go`、`internal/crypto/errors_test.go`、`internal/ai/coverage_test.go`、`internal/httpapi/endpoints_coverage_test.go`、`internal/app/cloud_ai_test.go`、`cmd/server/main_test.go`。`internal/httpapi/courses_test.go` 的 fixture 现在同时暴露 handler/store/app。

覆盖内容：腾讯云 host/COS/CDN 统计与对象生命周期（含错误响应、签名、分页/合并）、配置加载/夹取/密钥校验、解密与 Argon2id 失败分支、AI 模型客户端（预判、续写、永久错误、Prompt 序列化、抽取辅助）、管理端与用户端全部剩余接口、权限拒绝/CSRF/限流/静态资源/健康检查、SPA 回退与路由识别、AI 队列/重试/取消/下载、统计缓存与降级。

Go 63.2% → **85.01%**，已达到 85% statement 门槛。`tools/covercheck` 按完整 `file:start,end` 去重后统计并在 CI 中强制 85%；Codecov 的 `go` 状态也已改为强制。剩余未覆盖主要是不可达的防御分支与外部进程错误细节。

### Flutter 本轮

新增 `test/utils/cas_encrypt_test.dart`（RSA 分块/确定性/独立期望值）、`test/utils/exam_utils_test.dart`（日期与时间段解析）、`test/services/course_backup_test.dart`（备份结构与 JSON 排版）、`test/widgets/power_usage_chart_test.dart`（空态、过滤无效行、单价换算）。401 项测试通过，`flutter analyze` 无问题。

### CI 改动

- `.github/workflows/go-ci.yml`：安装 Node、AI 工具与 `ai-math` 依赖；**前置检查失败即失败**，不再静默 skip；Go 使用 `-coverpkg=./... -covermode=atomic`；运行完整 Web 套件；校验两份报告存在且非空；artifact 保存完整报告；Go/Web 分别用 `go`、`web` flags 上传，受信任分支上传失败会让 CI 失败。
- `codecov.yml`（Control）：新增 `go`/`web` flags，Web project 85% 为强制状态，Go 85% 暂为 informational。
- `.github/workflows/android-build.yml`：启用 `--branch-coverage`，上传带 `app` flag 的完整 lcov，受信任分支上传失败即失败。
- `tool/check_coverage.dart`：同时统计行与分支，报告缺少分支记录时以退出码 2 失败；行门槛仍为 42（未达 85 前不调高，也不隐藏缺口）。
- `codecov.yml`（App）：新增 `app` flag。

### 仍未完成

- Flutter 85% 行/分支门槛尚未达到，App CI 的行门槛仍为 42%，分支只报告不设门槛；没有谎报达标。
- Flutter 仍缺：CAS/REST 登录、AuthService、JP/NETAUTH、PowerService、ToolsDataManager、资源上传/资源中心、书单/报修/考试/一卡通页面、课表设置与个性化。这些服务大多把 Dio 硬编码在内部，需要先做小范围构造器注入。
- 未构建 APK、未推送、未触发远端 CI。

