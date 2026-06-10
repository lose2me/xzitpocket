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


def get_current_school_term():
    now = datetime.datetime.now()
    current_year = now.year
    current_month = now.month
    if 9 <= current_month <= 12:
        return current_year, 1
    return current_year - 1, 2


def align_floats(value):
    if value is None:
        return None
    try:
        f = float(value)
        return int(f) if f == int(f) else f
    except (ValueError, TypeError):
        return value


def get_exam_schedule(sid: str, password: str):
    try:
        year, term = get_current_school_term()
        base_url = BASE_URL.rstrip("/") + "/"
        login_url = urljoin(base_url, "xtgl/login_slogin.html")
        key_url = urljoin(base_url, "xtgl/login_getPublicKey.html")
        exam_url = urljoin(
            base_url,
            "kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105",
        )

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
                "mm": encrypt_password(
                    password, pubkey_json["modulus"], pubkey_json["exponent"]
                ),
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
            exam_data = {
                "xnm": str(year),
                "xqm": str(xqm),
                "_search": "false",
                "nd": int(datetime.datetime.now().timestamp() * 1000),
                "queryModel.showCount": "100",
                "queryModel.currentPage": "1",
                "queryModel.sortName": "",
                "queryModel.sortOrder": "asc",
                "time": "0",
            }
            exam_resp = session.post(
                exam_url,
                headers=headers,
                data=exam_data,
                timeout=REQUEST_TIMEOUT,
            )
            if exam_resp.status_code != 200:
                return {"status": "error"}
            if "用户登录" in exam_resp.text:
                return {"status": "error"}

            payload = exam_resp.json()
            items = payload.get("items")
            if not items:
                return {"status": "empty"}

            data = {
                "sid": items[0].get("xh"),
                "name": items[0].get("xm"),
                "year": year,
                "term": term,
                "count": len(items),
                "exams": [
                    {
                        "course_id": i.get("kch"),
                        "title": i.get("kcmc"),
                        "time": i.get("kssj"),
                        "location": i.get("cdmc"),
                        "campus": i.get("cdxqmc"),
                        "seat": i.get("zwh"),
                        "resit": i.get("cxbj", ""),
                        "exam_name": i.get("ksmc"),
                        "teacher": i.get("jsxx"),
                        "class_name": i.get("jxbmc"),
                        "college": i.get("kkxy"),
                        "credit": align_floats(i.get("xf")),
                        "exam_type": i.get("ksfs"),
                        "paper_id": i.get("sjbh"),
                        "note": i.get("bz1", ""),
                    }
                    for i in items
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

    result = get_exam_schedule(
        sid=sid,
        password=password,
    )

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
