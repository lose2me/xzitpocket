import binascii
import datetime
import json
import re
from urllib.parse import urljoin

import requests
import rsa

BASE_URL = "http://jwglxt.xzit.edu.cn/jwglxt"
REQUEST_TIMEOUT = 5


def encrypt_password(password: str, modulus: str, exponent: str) -> str:
    rsa_n = binascii.b2a_hex(binascii.a2b_base64(modulus))
    rsa_e = binascii.b2a_hex(binascii.a2b_base64(exponent))
    key = rsa.PublicKey(int(rsa_n, 16), int(rsa_e, 16))
    encrypted = rsa.encrypt(password.encode(), key)
    return binascii.b2a_base64(encrypted).decode().strip()


def extract_csrf_token(html: str) -> str:
    m = re.search(r'id=["\']csrftoken["\'][^>]*value=["\']([^"\']+)', html, re.I)
    if not m:
        m = re.search(r'value=["\']([^"\']+)["\'][^>]*id=["\']csrftoken["\']', html, re.I)
    if not m:
        raise ValueError("csrftoken not found")
    return m.group(1)


def extract_tips(html: str) -> str:
    m = re.search(r'<p[^>]*id=["\']tips["\'][^>]*>(.*?)</p>', html, re.I | re.S)
    if not m:
        return ""
    return re.sub(r"<[^>]+>", "", m.group(1)).strip()


def parse_int(value):
    if value is None:
        return None
    s = str(value)
    return int(s) if s.isdigit() else s


def parse_number_ranges(text: str):
    if not text:
        return []
    result = []
    seen = set()
    for m in re.finditer(r"(\d+)\s*-\s*(\d+)|(\d+)", str(text)):
        if m.group(1) and m.group(2):
            start, end = int(m.group(1)), int(m.group(2))
            if start > end:
                start, end = end, start
            values = range(start, end + 1)
        else:
            values = [int(m.group(3))]
        for n in values:
            if n not in seen:
                seen.add(n)
                result.append(n)
    return result


def get_current_school_term():
    now = datetime.datetime.now()
    current_year = now.year
    current_month = now.month
    if 9 <= current_month <= 12:
        return current_year, 1
    return current_year - 1, 2


def get_schedule(sid: str, password: str):
    try:
        year, term = get_current_school_term()
        base_url = BASE_URL
        base_url = base_url.rstrip("/") + "/"
        login_url = urljoin(base_url, "xtgl/login_slogin.html")
        key_url = urljoin(base_url, "xtgl/login_getPublicKey.html")
        schedule_url = urljoin(base_url, "kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151")

        headers = requests.utils.default_headers()
        headers["Referer"] = login_url
        headers["User-Agent"] = (
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/56.0.2924.87 Safari/537.36"
        )

        with requests.Session() as session:
            session.keep_alive = False

            login_page = session.get(login_url, headers=headers, timeout=REQUEST_TIMEOUT)
            if login_page.status_code != 200:
                return {"status": "error"}

            if re.search(r'id=["\']yzm["\']', login_page.text, re.I):
                return {"status": "error"}

            csrf_token = extract_csrf_token(login_page.text)

            pubkey = session.get(key_url, headers=headers, timeout=REQUEST_TIMEOUT)
            if pubkey.status_code != 200:
                return {"status": "error"}
            pubkey_json = pubkey.json()

            login_data = {
                "csrftoken": csrf_token,
                "yhm": sid,
                "mm": encrypt_password(password, pubkey_json["modulus"], pubkey_json["exponent"]),
            }
            login_resp = session.post(
                login_url,
                headers=headers,
                data=login_data,
                timeout=REQUEST_TIMEOUT,
            )
            if login_resp.status_code != 200:
                return {"status": "error"}

            tips = extract_tips(login_resp.text)
            if "用户名或密码" in tips:
                return {"status": "pwd"}
            if tips:
                return {"status": "error"}

            xqm = term * term * 3
            schedule_resp = session.post(
                schedule_url,
                headers=headers,
                data={"xnm": str(year), "xqm": str(xqm)},
                timeout=REQUEST_TIMEOUT,
            )
            if schedule_resp.status_code != 200:
                return {"status": "error"}
            if "用户登录" in schedule_resp.text:
                return {"status": "error"}

            payload = schedule_resp.json()
            if "kbList" not in payload:
                return {"status": "error"}

            courses = payload.get("kbList") or []
            data = {
                "sid": (payload.get("xsxx") or {}).get("XH"),
                "name": (payload.get("xsxx") or {}).get("XM"),
                "year": year,
                "term": term,
                "count": len(courses),
                "courses": [
                    {
                        "course_id": c.get("kch_id"),
                        "title": c.get("kcmc"),
                        "teacher": c.get("xm"),
                        "class_name": c.get("jxbmc"),
                        "weekday": parse_int(c.get("xqj")),
                        "sessions": parse_number_ranges(c.get("jc")),
                        "weeks": parse_number_ranges(c.get("zcd")),
                        "campus": c.get("xqmc"),
                        "place": c.get("cdmc"),
                    }
                    for c in courses
                ],
            }
            return {"status": "success", "data": data}
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def main():
    sid = input("sid: ").strip()
    password = input("password: ").strip()

    result = get_schedule(
        sid=sid,
        password=password,
    )

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
