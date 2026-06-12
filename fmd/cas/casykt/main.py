import json
import re
import sys
from urllib.parse import urljoin, quote

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CAS_BASE_URL = "https://ca.xzit.edu.cn/cas"
MYU_BASE_URL = "http://myu.xzit.edu.cn"
REQUEST_TIMEOUT = 5

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/146.0.0.0 Safari/537.36"
)


def rsa_encrypt(message: str, exponent_hex: str, modulus_hex: str) -> str:
    e = int(exponent_hex, 16)
    n = int(modulus_hex, 16)
    n_digits = (n.bit_length() + 15) // 16
    chunk_size = 2 * (n_digits - 1)

    msg_bytes = [ord(c) for c in message]
    while len(msg_bytes) % chunk_size != 0:
        msg_bytes.append(0)

    parts = []
    for i in range(0, len(msg_bytes), chunk_size):
        block = 0
        for j in range(0, chunk_size, 2):
            low = msg_bytes[i + j]
            high = msg_bytes[i + j + 1] if i + j + 1 < len(msg_bytes) else 0
            block |= (low | (high << 8)) << (16 * (j // 2))
        parts.append(format(pow(block, e, n), "x"))
    return " ".join(parts)


def encrypt_password(password: str, modulus: str, exponent: str) -> str:
    return rsa_encrypt(password[::-1], exponent, modulus)


def cas_login_myu(username: str, password: str, service: str):
    base = CAS_BASE_URL.rstrip("/") + "/"
    login_url = urljoin(base, "login") + "?service=" + quote(service, safe="")
    pubkey_url = urljoin(base, "v2/getPubKey")
    headers = {"User-Agent": USER_AGENT, "Referer": login_url}

    session = requests.Session()
    session.verify = False

    page = session.get(login_url, headers=headers, timeout=REQUEST_TIMEOUT)
    if page.status_code != 200:
        return None

    m = re.search(
        r'name=["\']execution["\'][^>]*value=["\']([^"\']+)', page.text, re.I
    )
    if not m:
        return None
    execution = m.group(1)

    pk = session.get(pubkey_url, headers=headers, timeout=REQUEST_TIMEOUT)
    if pk.status_code != 200:
        return None
    pk_json = pk.json()

    resp = session.post(
        login_url,
        headers=headers,
        data={
            "username": username,
            "password": encrypt_password(
                password, pk_json["modulus"], pk_json["exponent"]
            ),
            "execution": execution,
            "_eventId": "submit",
        },
        timeout=REQUEST_TIMEOUT,
        allow_redirects=True,
    )

    if "cas/login" in resp.url:
        err = re.search(
            r'id=["\']errormsg["\'][^>]*>(.*?)</p>', resp.text, re.I | re.S
        )
        msg = re.sub(r"<[^>]+>", "", err.group(1)).strip() if err else ""
        if "密码" in msg or "用户名" in msg:
            return "pwd"
        return None

    return session


def get_balance(username: str, password: str):
    try:
        session = cas_login_myu(
            username, password, MYU_BASE_URL + "/yikat-detail"
        )
        if session == "pwd":
            return {"status": "pwd"}
        if session is None:
            return {"status": "error"}

        headers = {
            "User-Agent": USER_AGENT,
            "Referer": MYU_BASE_URL + "/yikat-detail",
        }
        r = session.get(
            MYU_BASE_URL + "/api/yikat/info",
            headers=headers,
            timeout=REQUEST_TIMEOUT,
        )
        if r.status_code != 200:
            return {"status": "error"}

        info = r.json()
        items = info.get("data", [])
        if not items:
            return {"status": "empty"}

        return {
            "status": "success",
            "data": {
                "balance": items[0].get("ye"),
                "card_no": items[0].get("kh"),
            },
        }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def get_transactions(
    username: str,
    password: str,
    start_date: str,
    end_date: str,
    page: int = 1,
    page_size: int = 20,
    tx_type: str = "",
):
    try:
        session = cas_login_myu(
            username, password, MYU_BASE_URL + "/yikat-detail"
        )
        if session == "pwd":
            return {"status": "pwd"}
        if session is None:
            return {"status": "error"}

        headers = {
            "User-Agent": USER_AGENT,
            "Referer": MYU_BASE_URL + "/yikat-detail",
            "Content-Type": "application/x-www-form-urlencoded",
        }
        r = session.post(
            MYU_BASE_URL + "/api/yikat/consumerList",
            headers=headers,
            data={
                "currentPage": str(page),
                "pageNumber": str(page_size),
                "kssj": start_date,
                "jssj": end_date,
                "jylx": tx_type,
            },
            timeout=REQUEST_TIMEOUT,
        )
        if r.status_code != 200:
            return {"status": "error"}

        payload = r.json()
        data = payload.get("data", {})
        items = data.get("items", [])
        if not items:
            return {"status": "empty"}

        return {
            "status": "success",
            "data": {
                "total": data.get("totalCount", 0),
                "page": int(data.get("currentPage", page)),
                "page_size": data.get("pageSize", page_size),
                "items": [
                    {
                        "time": i.get("jysj"),
                        "amount": i.get("jye"),
                        "terminal": i.get("zd"),
                        "merchant": i.get("shdm", ""),
                        "type": i.get("jylxm"),
                        "balance": i.get("ye"),
                        "card_no": i.get("kh"),
                    }
                    for i in items
                ],
            },
        }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    print("1. 查询余额")
    print("2. 查询账单")
    choice = input("选择功能: ").strip()

    username = input("username: ").strip()
    password = input("password: ").strip()

    if choice == "1":
        result = get_balance(username, password)
    elif choice == "2":
        start = input("开始日期 (YYYY-MM-DD): ").strip()
        end = input("结束日期 (YYYY-MM-DD): ").strip()
        result = get_transactions(username, password, start, end)
    else:
        result = {"status": "error"}

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
