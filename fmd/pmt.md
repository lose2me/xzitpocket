# fmd 开发约束

## 项目结构

每个子目录为独立的 Python 项目，必须包含：

- `main.py` — 入口文件
- `pyproject.toml` — 项目配置与依赖声明
- `.python-version` — 固定 Python 3.12

使用 `uv` 管理虚拟环境和依赖，`.venv/` 不入库。

## 请求行为（模拟正常用户）

所有 HTTP 请求必须模拟真实浏览器行为：

### User-Agent

使用**当前主流浏览器**的 UA 字符串，禁止使用 requests 默认 UA 或过时版本：

```python
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/146.0.0.0 Safari/537.36"
)
```

所有项目统一维护同一版本号，UA 版本过时时需同步更新。

### Referer

涉及表单提交、API 调用时必须设置 `Referer` 头，值为对应页面的 URL。

### Session

使用 `requests.Session()` 维持会话，自动管理 Cookie。设置 `session.keep_alive = False` 避免连接泄漏（视目标系统需要）。

### 请求频率

设置合理的 `timeout`（默认 5 秒），不做高频请求，不并发爬取。

## 代码风格

- **函数式**：核心逻辑封装为独立函数，不使用类（除非场景需要，如 power/service）
- **返回格式**：统一返回 `dict`，必须包含 `status` 字段：
  - `"success"` — 成功，数据放在 `data` 字段
  - `"error"` — 通用错误
  - `"pwd"` — 密码错误
  - `"timeout"` — 请求超时
  - `"captcha"` — 需要验证码
  - `"empty"` — 查询结果为空
- **main 函数**：交互式输入输出，结果用 `json.dumps(result, ensure_ascii=False)` 打印

## 错误处理

- 捕获 `requests.exceptions.Timeout` 返回 `{"status": "timeout"}`
- 捕获其他异常返回 `{"status": "error"}`
- 不向调用方抛出异常
- 不打印 traceback（静默处理）

## 安全

- 密码必须加密传输，按目标系统要求使用对应加密方式（RSA 等）
- 不在代码中硬编码用户凭据
- HTTPS 请求如需跳过证书验证，使用 `verify=False` 并抑制 urllib3 警告
