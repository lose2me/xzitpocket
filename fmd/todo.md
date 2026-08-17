# TODO

## 电费查询接口方法固定（去掉回退机制）

**状态**：⏳ 待办（需要校园内网环境，当前无内网无法测试）

**背景**：`lib/services/power_service.dart` 当前是「多级回退」设计，查询电费时依次尝试多种方法，失败才降级。目标是**实测确定哪个方法能用，固定使用单一方法**，去掉回退逻辑（一般不会突然失效）。

### 需要测试的端点与方法

| 端点 | 模式 | 候选方法 |
|------|------|----------|
| `zx`（211.87.126.94/zx） | legacy | ① AJAX JSON（`X-Requested-With: XMLHttpRequest`）② HTML 表格解析 |
| `cn`（211.87.126.94/cn） | legacy | ① AJAX JSON ② HTML 表格解析 |
| `dxq`（211.87.126.249/dxq） | dxq | ① WebMethod JSON（`GetBalance` / `GetRoomInfo` / `GetElecInfo`）② 单步 postback ③ 三步 postback 链 |

### 测试流程（legacy）

1. `GET /` 提取 `g_pswSession`
2. `POST {loginPath}` 登录（密码 = `md5(md5(pwd + session))`，字段：`login_type=accountId` / `login_roomName` / `login_roomID` / `password`）
3. 带 AJAX 头查询 `consumeHistory` 路径 → 判断返回 JSON 还是 HTML
4. 记录哪个方法稳定可用

### 测试凭据（来自 `fmd/power/room.db`）

- zx 示例：房间 `1A102` / roomID `1252138521` / pwd `888888`
- cn 示例：房间 `7B101` / roomID `1536811473` / pwd `888888`
- dxq 示例：房间 `8A101`（roomID ≥ 4 位）

### 待测试结论

- [ ] zx 用哪种方法
- [ ] cn 用哪种方法
- [ ] dxq 用哪种方法

### 确定后要改的代码

- `_queryLegacyRoom`：去掉 `_tryLegacyAjax` → HTML 的回退，只保留可用路径
- `_queryDxqRoom`：去掉 WebMethod → 单步 → 三步链的回退，只保留可用路径
- 可保留「样本不足回查上月」的数据补全逻辑（非接口回退，不影响）

> 注：WSL 本机与手机（adb）当前均无法访问 211.87.126.x（校园内网），需在内网环境下执行上述测试。
