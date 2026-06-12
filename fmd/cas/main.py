import json
import re
import sys
from urllib.parse import urljoin

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CAS_BASE_URL = "https://ca.xzit.edu.cn/cas"
IM_BASE_URL = "http://ca.xzit.edu.cn:81/im"
FIND_PWD_URL = IM_BASE_URL + "/V3/securitycenter/findPwd/"
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


def extract_execution(html: str) -> str:
    m = re.search(
        r'name=["\']execution["\'][^>]*value=["\']([^"\']+)', html, re.I
    )
    if not m:
        m = re.search(
            r'value=["\']([^"\']+)["\'][^>]*name=["\']execution["\']',
            html,
            re.I,
        )
    if not m:
        raise ValueError("execution not found")
    return m.group(1)


def extract_error_msg(html: str) -> str:
    m = re.search(r'id=["\']errormsg["\'][^>]*>(.*?)</p>', html, re.I | re.S)
    if not m:
        return ""
    return re.sub(r"<[^>]+>", "", m.group(1)).strip()


# ===== CAS 登录 =====


def cas_login(username: str, password: str):
    try:
        base = CAS_BASE_URL.rstrip("/") + "/"
        login_url = urljoin(base, "login")
        pubkey_url = urljoin(base, "v2/getPubKey")
        headers = {"User-Agent": USER_AGENT, "Referer": login_url}

        with requests.Session() as session:
            page = session.get(
                login_url, headers=headers, timeout=REQUEST_TIMEOUT, verify=False
            )
            if page.status_code != 200:
                return {"status": "error"}

            execution = extract_execution(page.text)

            pk = session.get(
                pubkey_url, headers=headers, timeout=REQUEST_TIMEOUT, verify=False
            )
            if pk.status_code != 200:
                return {"status": "error"}
            pk_json = pk.json()

            login_data = {
                "username": username,
                "password": encrypt_password(
                    password, pk_json["modulus"], pk_json["exponent"]
                ),
                "execution": execution,
                "_eventId": "submit",
            }
            resp = session.post(
                login_url,
                headers=headers,
                data=login_data,
                timeout=REQUEST_TIMEOUT,
                verify=False,
                allow_redirects=False,
            )

            if resp.status_code == 302:
                return {
                    "status": "success",
                    "data": {
                        "tgc": session.cookies.get("TGC", ""),
                        "location": resp.headers.get("Location", ""),
                    },
                }

            err = extract_error_msg(resp.text)
            if "密码" in err or "用户名" in err:
                return {"status": "pwd", "message": err}
            if "验证码" in err:
                return {"status": "captcha", "message": err}
            return {"status": "error", "message": err or "登录失败"}
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


# ===== 找回密码 =====


def send_reset_code(phone: str):
    try:
        headers = {"User-Agent": USER_AGENT}
        with requests.Session() as session:
            session.get(
                FIND_PWD_URL + "index.zf",
                headers=headers,
                timeout=REQUEST_TIMEOUT,
            )
            resp = session.post(
                FIND_PWD_URL + "byPhone.zf",
                headers=headers,
                data={"phone": phone, "validCode": "0"},
                timeout=REQUEST_TIMEOUT,
            )
            result = resp.json()
            if result.get("code") == "0":
                return {"status": "success", "cookies": dict(session.cookies)}
            return {
                "status": "error",
                "message": result.get("content", "发送失败"),
            }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def verify_reset_code(phone: str, code: str, cookies: dict):
    try:
        headers = {"User-Agent": USER_AGENT}
        with requests.Session() as session:
            session.cookies.update(cookies)
            resp = session.post(
                FIND_PWD_URL + "validateCodePhone.zf",
                headers=headers,
                data={"phone": phone, "yzm": code},
                timeout=REQUEST_TIMEOUT,
            )
            result = resp.json()
            if result.get("code") == "0":
                accounts = [
                    {"sid": a["zgh"], "info": a.get("jsxx", "")}
                    for a in result.get("multipleAccountList", [])
                ]
                return {
                    "status": "success",
                    "data": {
                        "validate_id": result["validateID"],
                        "accounts": accounts,
                    },
                    "cookies": dict(session.cookies),
                }
            return {
                "status": "error",
                "message": result.get("content", "验证失败"),
            }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def validate_password(password: str) -> str:
    if len(password) < 10:
        return "密码长度不低于10位"
    checks = [
        (r"[A-Z]", "大写字母"),
        (r"[a-z]", "小写字母"),
        (r"[0-9]", "数字"),
        (r"[!@#$%^&*()_+\-=\[\]{};':\"\\|,.<>/?~`]", "特殊字符"),
    ]
    missing = [name for pat, name in checks if not re.search(pat, password)]
    if missing:
        return "密码必须包含" + "、".join(missing)
    return ""


def reset_password(
    phone: str,
    new_password: str,
    sid: str,
    validate_id: str,
    cookies: dict,
):
    try:
        err = validate_password(new_password)
        if err:
            return {"status": "error", "message": err}

        headers = {"User-Agent": USER_AGENT}
        with requests.Session() as session:
            session.cookies.update(cookies)

            pk_resp = session.get(
                IM_BASE_URL + "/securitycenter/findPwd/getPublicKey.zf",
                headers=headers,
                timeout=REQUEST_TIMEOUT,
            )
            parts = pk_resp.text.strip().split(";")
            modulus, exponent = parts[0], parts[1]

            resp = session.post(
                FIND_PWD_URL + "updatePwdPhone.zf",
                headers=headers,
                data={
                    "zgh": sid,
                    "phone": phone,
                    "subNewPwd": encrypt_password(new_password, modulus, exponent),
                    "validateID": validate_id,
                },
                timeout=REQUEST_TIMEOUT,
            )
            result = resp.json()
            if result.get("code") == "0":
                return {"status": "success"}
            return {
                "status": "error",
                "message": result.get("content", "重置失败"),
            }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    print("1. CAS 登录")
    print("2. 找回密码")
    choice = input("选择功能: ").strip()

    if choice == "1":
        username = input("username: ").strip()
        password = input("password: ").strip()
        result = cas_login(username, password)
        print(json.dumps(result, ensure_ascii=False))

    elif choice == "2":
        phone = input("phone: ").strip()
        send_result = send_reset_code(phone)
        if send_result["status"] != "success":
            print(json.dumps(send_result, ensure_ascii=False))
            return
        print("验证码已发送")

        code = input("sms code: ").strip()
        verify_result = verify_reset_code(phone, code, send_result["cookies"])
        if verify_result["status"] != "success":
            print(json.dumps(verify_result, ensure_ascii=False))
            return

        accounts = verify_result["data"]["accounts"]
        if len(accounts) > 1:
            for i, a in enumerate(accounts):
                print(f"  {i + 1}. {a['sid']} ({a['info']})")
            sid = accounts[int(input("序号: ").strip()) - 1]["sid"]
        else:
            sid = accounts[0]["sid"]

        new_password = input("new password: ").strip()
        result = reset_password(
            phone,
            new_password,
            sid,
            verify_result["data"]["validate_id"],
            verify_result["cookies"],
        )
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
