# 覆盖率约束（xzitpocket + xzitpocket-control）

本文件是长期生效的工程约束，优先级高于任何一次覆盖率任务的临时做法。当前进度与剩余工作见仓库根目录的 `COVERAGE_HANDOFF.md`。

## 1. 目标与统计口径

- App（Flutter）：行覆盖率与分支覆盖率均 ≥ 85%。
- Control / Web（`web/app.js`、`web/template.js`）：行、statement、function、branch 均 ≥ 85%。
- Control / Go：statement 覆盖率 ≥ 85%，使用全模块跨包统计。
- 三份报告相互独立、分别上传，任何一份高覆盖都不能用来掩盖另一份不足。
- Go 原生覆盖率是 statement coverage，不得表述为分支覆盖率。

## 2. 禁止事项

- 禁止 `pragma: no cover`、`istanbul ignore`、`// NOLINT` 式覆盖率忽略，或任何“从统计中排除业务代码”的做法。
- 禁止缩小 `include`/`--coverage` 范围、排除生产文件、只统计被测试加载过的库来凑数。
- 禁止降低已有门槛来让 CI 变绿；门槛只能在不达标的测试补齐后提高。
- 禁止用 carryforward、陈旧报告、只跑部分包的 CI 结果声称达标。
- 禁止只堆 happy path；异常、边界、权限、失败与重试分支必须覆盖。
- 禁止为了命中率写没有行为断言的调用循环；每个测试都要断言可观察行为。
- 禁止在测试中访问真实账号、校园系统、云资源或备份里的凭据。

## 3. 不可达代码

- 优先删除没有调用方的死代码，而不是忽略它。
- 确属防御性、在当前调用路径不可达的分支，必须在评审说明中列出原因；它们不能作为“已达标”的论证依据。
- 不得为了覆盖率新增生产分支或重构无关代码；为可测试性做的小范围依赖注入必须保持业务行为不变。

## 4. 本地命令

### 4.1 App

```bash
flutter test --reporter expanded --coverage --branch-coverage
dart tool/check_coverage.dart coverage/lcov.info <行门槛> [分支门槛]
flutter analyze --no-pub
```

`check_coverage.dart` 同时统计 `LF/LH` 与 `BRDA`；报告缺少分支记录时以退出码 2 失败，防止上传残缺报告。

### 4.2 Control / Web

```bash
npm ci
npm run test:coverage
```

`vitest.config.js` 对 `web/app.js`、`web/template.js` 强制 lines/statements/functions/branches 85%。

### 4.3 Control / Go

```bash
go test ./... -coverpkg=./... -coverprofile=coverage.out -covermode=atomic
go tool cover -func=coverage.out | tail -n 1
(cd tools/covercheck && go run . ../../coverage.out 85)
```

`-coverpkg=./...` 是必须的：否则跨包调用不会计入被测包。该模式会让同一 block 在每个测试包重复出现，`tools/covercheck` 按完整 `file:start,end` 去重后再计算 statement 覆盖率，不得直接累加原始行。

## 5. CI 与 Codecov

- CI 必须在同一次运行中执行全量 Go 测试与全量 Web 测试，并分别校验报告存在、非空、包含预期源码。
- App CI 必须启用 `--branch-coverage`，上传完整 `coverage/lcov.info`。
- 三个报告分别使用 `go`、`web`、`app` flag 上传；不得自动收集依赖目录里的报告。
- 受信任分支（push、同仓库 PR）上传失败必须让 CI 失败；fork PR 无 token 时按 Codecov 支持的 best-effort 处理，不能统一吞掉错误。
- 不得使用 carryforward 来掩盖缺失的报告。
- AI 集成测试依赖 `pdftohtml`、`cwebp`、`weasyprint`、`node` 与 `ai-math` 的 MathJax 依赖；CI 要安装并前置校验，缺依赖应直接失败而不是 skip。

## 6. 当前状态（2026-10-28）

| 范围 | 实测 | 门槛 |
| --- | ---: | ---: |
| Web 行 / statement / function / branch | 99.93% / 99.11% / 99.76% / 86.84% | 85%（已强制） |
| Go statement | 85.01%（8006/9418，去重） | 85%（已强制） |
| App 行 | 46.33%（8674/18723） | 85%（未达标） |
| App 分支 | 37.08%（2253/6076） | 85%（未达标） |

未达标期间：

- App CI 行门槛保持 42%（只保证不回退），分支只报告不设门槛；不得把 42% 描述为达标。
- 本地与远端 Codecov 的差异以远端真实运行结果为准；未触发远端 CI 前不得声称线上已达标。

## 7. 继续补测的优先顺序

1. App 服务层：CAS/REST 登录、AuthService、JP/NETAUTH、PowerService、ToolsDataManager；这些类把 Dio/时钟/存储硬编码在内部，先加可选构造器注入再测。
2. App 页面层：资源上传与资源中心、书单、报修、考试、一卡通、课表设置、个性化与调休提醒，优先真实 widget 交互（空态、错误、取消、重试、权限）。
3. 两仓库的异常分支：HTTP/云服务错误响应、事务回滚、约束冲突、超时/取消、损坏数据。
4. 每批补测后重新生成完整报告再提交，不得提交报告产物、`node_modules` 或 `backup.7z`。

## 8. 提交约束

- 分批提交：Web、Go、App 服务、App 页面、CI/文档分别成 commit。
- 提交前确认 diff，不使用 `git add .`；不提交 `coverage/`、`coverage.out`、`node_modules`、构建产物。
- 不清理、不还原、不提交 `backup.7z`（内含凭据），也不输出其中内容。
- 未达标时在 commit message 与总结中明确写出实测数字，不写“已达标”。
