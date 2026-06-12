import json
import re
import sys

import requests
from bs4 import BeautifulSoup

BASE_URL = "http://211.87.126.147:8080/Self"
REQUEST_TIMEOUT = 5

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/146.0.0.0 Safari/537.36"
)

CARRIER_FIELDS = {
    "移动": ("FLDEXTRA1", "FLDEXTRA2"),
    "联通": ("FLDEXTRA3", "FLDEXTRA4"),
    "电信": ("FLDEXTRA5", "FLDEXTRA6"),
}


def decode(resp: requests.Response) -> str:
    return resp.content.decode("utf-8")


def extract_checkcode(html: str) -> str:
    tag = BeautifulSoup(html, "html.parser").find("input", {"name": "checkcode"})
    if tag is None:
        raise ValueError("checkcode not found")
    return str(tag.get("value", ""))


def extract_error_tip(html: str) -> str:
    m = re.search(r"\}\)\('([^']*?)'\);", html)
    return m.group(1) if m else ""


def extract_user_json(html: str) -> dict:
    m = re.search(r"\}\)\((\{.*?\})\)", html, re.S)
    if m:
        return json.loads(m.group(1))
    return {}


def extract_ajax_csrf(html: str) -> str:
    m = re.search(r'ajaxCsrfToken.*?["\']([a-f0-9-]{36})["\']', html)
    if not m:
        raise ValueError("ajaxCsrfToken not found")
    return m.group(1)


def extract_form_csrf(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    tag = soup.find("input", {"name": "csrftoken"})
    if tag is None:
        raise ValueError("csrftoken not found")
    return str(tag.get("value", ""))


def extract_operator_values(html: str) -> dict[str, str]:
    soup = BeautifulSoup(html, "html.parser")
    values = {}
    for field in ("FLDEXTRA1", "FLDEXTRA2", "FLDEXTRA3",
                   "FLDEXTRA4", "FLDEXTRA5", "FLDEXTRA6"):
        tag = soup.find("input", {"name": field})
        values[field] = str(tag.get("value", "")) if tag else ""
    return values


def extract_swal_message(html: str) -> str:
    matches = re.findall(r"\}\)\('([^']*)'\)", html)
    for msg in reversed(matches):
        if msg:
            return msg.replace("\\n", "").strip()
    return ""


def parse_user(user: dict) -> dict[str, object]:
    if not user:
        return {}
    group = user.get("serviceDefault") or {}
    return {
        "name": user.get("userRealName", ""),
        "account": user.get("userName", ""),
        "class": user.get("memo", ""),
        "group": group.get("defaultName", ""),
        "status": "正常" if user.get("useFlag") == 1 else "停用",
        "used_hours": round(user.get("useTime", 0) / 60, 1),
        "used_flow_gb": round(user.get("useFlow", 0) / 1024, 2),
        "down_flow_gb": round(user.get("internetDownFlow", 0) / 1024, 2),
        "up_flow_gb": round(user.get("internetUpFlow", 0) / 1024, 2),
        "max_devices": (user.get("userGroup") or {}).get("ipMaxCount", 0),
        "mac_addresses": (user.get("macAddress") or "").split(";"),
    }


def parse_devices(data: dict) -> list[dict[str, str]]:
    devices: list[dict[str, str]] = []
    for row in data.get("rows", []):
        if len(row) < 5:
            continue
        devices.append({
            "online": row[0] == "1",
            "mac": row[1],
            "type": row[2],
            "last_time": row[3],
            "ip": row[4],
        })
    return devices


def _do_login(
    session: requests.Session,
    headers: dict[str, str],
    account: str,
    password: str,
) -> dict[str, object] | None:
    login_page = session.get(
        f"{BASE_URL}/login",
        headers=headers,
        timeout=REQUEST_TIMEOUT,
        allow_redirects=True,
    )
    if login_page.status_code != 200:
        return {"status": "error", "message": "无法访问登录页"}

    checkcode = extract_checkcode(decode(login_page))

    session.get(
        f"{BASE_URL}/login/randomCode?t=0.1",
        headers=headers,
        timeout=REQUEST_TIMEOUT,
    )

    login_resp = session.post(
        f"{BASE_URL}/login/verify",
        headers={**headers, "Referer": f"{BASE_URL}/login/"},
        data={
            "account": account,
            "password": password,
            "checkcode": checkcode,
            "foo": "",
            "bar": "",
        },
        timeout=REQUEST_TIMEOUT,
        allow_redirects=False,
    )

    if login_resp.status_code != 302:
        return {"status": "error", "message": f"非预期响应: {login_resp.status_code}"}

    location = login_resp.headers.get("Location", "")
    if "dashboard" not in location:
        redirect = session.get(
            f"http://211.87.126.147:8080{location}",
            headers=headers,
            timeout=REQUEST_TIMEOUT,
        )
        tip = extract_error_tip(decode(redirect))
        if "密码" in tip or "账号" in tip:
            return {"status": "pwd", "message": tip}
        if "验证码" in tip:
            return {"status": "captcha", "message": tip}
        return {"status": "error", "message": tip or "登录失败"}

    return None


def login(account: str, password: str) -> dict[str, object]:
    try:
        headers = {"User-Agent": USER_AGENT}

        with requests.Session() as session:
            err = _do_login(session, headers, account, password)
            if err:
                return err

            user_page = session.get(
                f"{BASE_URL}/service/myMac",
                headers=headers,
                timeout=REQUEST_TIMEOUT,
            )
            user_info = parse_user(extract_user_json(decode(user_page)))

            mac_resp = session.get(
                f"{BASE_URL}/service/getMacList",
                headers=headers,
                timeout=REQUEST_TIMEOUT,
            )
            devices = parse_devices(mac_resp.json())

            return {
                "status": "success",
                "data": {**user_info, "devices": devices},
            }
    except requests.exceptions.Timeout:
        return {"status": "timeout", "message": "请求超时"}
    except Exception as exc:
        return {"status": "error", "message": str(exc)}


def unbind_mac(account: str, password: str, mac: str) -> dict[str, object]:
    try:
        headers = {"User-Agent": USER_AGENT}

        with requests.Session() as session:
            err = _do_login(session, headers, account, password)
            if err:
                return err

            mac_page = session.get(
                f"{BASE_URL}/service/myMac",
                headers=headers,
                timeout=REQUEST_TIMEOUT,
            )
            csrf = extract_ajax_csrf(decode(mac_page))

            clean_mac = mac.replace("-", "").replace(":", "").upper()

            resp = session.get(
                f"{BASE_URL}/service/unbindmac",
                params={"mac": clean_mac, "ajaxCsrfToken": csrf},
                headers=headers,
                timeout=REQUEST_TIMEOUT,
                allow_redirects=True,
            )

            msg = extract_swal_message(decode(resp))
            failed = not msg or "失败" in msg
            return {
                "status": "error" if failed else "success",
                "message": msg or "未知结果",
            }
    except requests.exceptions.Timeout:
        return {"status": "timeout", "message": "请求超时"}
    except Exception as exc:
        return {"status": "error", "message": str(exc)}


def bind_operator(
    account: str,
    password: str,
    carrier: str,
    broadband_account: str,
    broadband_password: str,
) -> dict[str, object]:
    if carrier not in CARRIER_FIELDS:
        return {
            "status": "error",
            "message": f"运营商须为: {', '.join(CARRIER_FIELDS)}",
        }

    try:
        headers = {"User-Agent": USER_AGENT}

        with requests.Session() as session:
            err = _do_login(session, headers, account, password)
            if err:
                return err

            op_page = session.get(
                f"{BASE_URL}/service/operatorId",
                headers=headers,
                timeout=REQUEST_TIMEOUT,
            )
            html = decode(op_page)
            csrf = extract_form_csrf(html)
            values = extract_operator_values(html)

            acct_field, pwd_field = CARRIER_FIELDS[carrier]
            values[acct_field] = broadband_account
            values[pwd_field] = broadband_password

            resp = session.post(
                f"{BASE_URL}/service/bind-operator",
                headers={**headers, "Referer": f"{BASE_URL}/service/operatorId"},
                data={"csrftoken": csrf, **values},
                timeout=REQUEST_TIMEOUT,
                allow_redirects=True,
            )

            msg = extract_swal_message(decode(resp))
            failed = not msg or "失败" in msg
            return {
                "status": "error" if failed else "success",
                "message": msg or "未知结果",
            }
    except requests.exceptions.Timeout:
        return {"status": "timeout", "message": "请求超时"}
    except Exception as exc:
        return {"status": "error", "message": str(exc)}


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    account = input("account: ").strip()
    password = input("password: ").strip()
    if not account or not password:
        print("账号和密码不能为空", file=sys.stderr)
        sys.exit(1)

    result = login(account=account, password=password)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
