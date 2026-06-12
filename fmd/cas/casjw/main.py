import datetime
import json
import re
import sys
from urllib.parse import urljoin, quote

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CAS_BASE_URL = "https://ca.xzit.edu.cn/cas"
JW_BASE_URL = "http://jwglxt.xzit.edu.cn/jwglxt"
JW_SSO_URL = "http://jwglxt.xzit.edu.cn/sso/zfiotlogin"
REQUEST_TIMEOUT = 10

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/146.0.0.0 Safari/537.36"
)


# ===== CAS 加密 =====


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


# ===== CAS SSO 登录教务系统 =====


def cas_login_jw(username: str, password: str):
    base = CAS_BASE_URL.rstrip("/") + "/"
    login_url = urljoin(base, "login")
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

    r = session.get(JW_SSO_URL, headers=headers, timeout=REQUEST_TIMEOUT)
    if r.status_code != 200 or "用户登录" in r.text or "cas/login" in r.url:
        return None

    return session


# ===== SSO 登录（返回 cookies） =====


def jw_login(username: str, password: str):
    try:
        session = cas_login_jw(username, password)
        if session == "pwd":
            return {"status": "pwd"}
        if session is None:
            return {"status": "error"}

        cookies = {
            c.name: c.value
            for c in session.cookies
            if "jwglxt" in c.domain
        }
        return {
            "status": "success",
            "data": {"cookies": cookies},
        }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


# ===== 辅助函数 =====


def get_current_school_term():
    now = datetime.datetime.now()
    if 9 <= now.month <= 12:
        return now.year, 1
    return now.year - 1, 2


def parse_int(value):
    if value is None:
        return None
    s = str(value)
    return int(s) if s.isdigit() else s


def align_floats(value):
    if value is None:
        return None
    try:
        f = float(value)
        return int(f) if f == int(f) else f
    except (ValueError, TypeError):
        return value


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


def parse_week_ranges(text: str):
    if not text:
        return []

    normalized = (
        str(text)
        .replace("（", "(")
        .replace("）", ")")
        .replace("，", ",")
        .replace("周次", "")
        .replace("周", "")
    )

    result = []
    seen = set()
    pattern = re.compile(r"(\d+\s*-\s*\d+|\d+)\s*(?:\(([^()]*)\))?")

    for m in pattern.finditer(normalized):
        raw_range = m.group(1)
        parity = (m.group(2) or "").strip()

        if "-" in raw_range:
            start_text, end_text = re.split(r"\s*-\s*", raw_range, maxsplit=1)
            start, end = int(start_text), int(end_text)
            if start > end:
                start, end = end, start
            values = list(range(start, end + 1))
        else:
            values = [int(raw_range.strip())]

        if "单" in parity:
            values = [n for n in values if n % 2 == 1]
        elif "双" in parity:
            values = [n for n in values if n % 2 == 0]

        for n in values:
            if n not in seen:
                seen.add(n)
                result.append(n)

    return result


# ===== 课表查询 =====


def get_schedule(username: str, password: str):
    try:
        session = cas_login_jw(username, password)
        if session == "pwd":
            return {"status": "pwd"}
        if session is None:
            return {"status": "error"}

        year, term = get_current_school_term()
        base_url = JW_BASE_URL.rstrip("/") + "/"
        schedule_url = urljoin(
            base_url, "kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151"
        )

        headers = {
            "User-Agent": USER_AGENT,
            "Referer": urljoin(base_url, "xtgl/index_initMenu.html"),
        }

        xqm = term * term * 3
        resp = session.post(
            schedule_url,
            headers=headers,
            data={"xnm": str(year), "xqm": str(xqm)},
            timeout=REQUEST_TIMEOUT,
        )
        if resp.status_code != 200 or "用户登录" in resp.text:
            return {"status": "error"}

        payload = resp.json()
        if "kbList" not in payload:
            return {"status": "error"}

        courses = payload.get("kbList") or []
        if not courses:
            return {"status": "empty"}

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
                    "weeks": parse_week_ranges(c.get("zcd")),
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


# ===== 考试查询 =====


def get_exam_schedule(username: str, password: str):
    try:
        session = cas_login_jw(username, password)
        if session == "pwd":
            return {"status": "pwd"}
        if session is None:
            return {"status": "error"}

        year, term = get_current_school_term()
        base_url = JW_BASE_URL.rstrip("/") + "/"
        exam_url = urljoin(
            base_url,
            "kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105",
        )

        headers = {
            "User-Agent": USER_AGENT,
            "Referer": urljoin(base_url, "xtgl/index_initMenu.html"),
        }

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
        resp = session.post(
            exam_url,
            headers=headers,
            data=exam_data,
            timeout=REQUEST_TIMEOUT,
        )
        if resp.status_code != 200 or "用户登录" in resp.text:
            return {"status": "error"}

        payload = resp.json()
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
    sys.stdout.reconfigure(encoding="utf-8")

    print("1. SSO 登录")
    print("2. 课表查询")
    print("3. 考试查询")
    choice = input("选择功能: ").strip()

    username = input("username: ").strip()
    password = input("password: ").strip()

    if choice == "1":
        result = jw_login(username, password)
    elif choice == "2":
        result = get_schedule(username, password)
    elif choice == "3":
        result = get_exam_schedule(username, password)
    else:
        result = {"status": "error"}

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
