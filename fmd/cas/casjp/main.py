import json
import re
import sys
from datetime import datetime
from urllib.parse import urljoin

import requests
import urllib3
from Crypto.Cipher import PKCS1_v1_5
from Crypto.PublicKey import RSA

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CAS_BASE_URL = "https://ca.xzit.edu.cn/cas"
AGG_8080_URL = "http://pgzlbz.xzit.edu.cn:8080"
AGG_8070_URL = "http://pgzlbz.xzit.edu.cn:8070"
ZLBZ_BACKEND = "http://211.65.116.214:8005"
ZLBZ_FRONTEND = "http://211.65.116.214:8085"
SSO_TIMEOUT = 10
REQUEST_TIMEOUT = 5

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


AGG_PUBLIC_KEY = (
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDBKw11ggtOzD1XfvcicMM3EIUg"
    "lOuOrEDiE7so9f9TogYvchS8FoxOrqW0520GwDrZLP5tc/DXo0lETPgZyW5RNhu4"
    "4NGqEo37iAbfdnDyFYzQw48WnxhsvHcbeO/Ni+wNnjG8PMtVX2xt0yTBZz/MUTeN"
    "U7pEe6Rr4LxPDCWC5QIDAQAB"
)


def pkcs1_encrypt(plaintext: str, pubkey_b64: str) -> str:
    import base64

    der = base64.b64decode(pubkey_b64)
    key = RSA.import_key(der)
    key_size = key.size_in_bytes()
    max_chunk = key_size - 11

    data = plaintext.encode("utf-8")
    chunks = []
    for i in range(0, len(data), max_chunk):
        cipher = PKCS1_v1_5.new(key)
        chunks.append(cipher.encrypt(data[i : i + max_chunk]))

    return base64.b64encode(b"".join(chunks)).decode("ascii")


# ===== SSO 登录链 =====


def _cas_login(session, username, password):
    base = CAS_BASE_URL.rstrip("/") + "/"
    login_url = urljoin(base, "login")
    pubkey_url = urljoin(base, "v2/getPubKey")
    headers = {"User-Agent": USER_AGENT, "Referer": login_url}

    page = session.get(login_url, headers=headers, timeout=SSO_TIMEOUT)
    if page.status_code != 200:
        return None

    m = re.search(
        r'name=["\']execution["\'][^>]*value=["\']([^"\']+)',
        page.text,
        re.I,
    )
    if not m:
        return None
    execution = m.group(1)

    pk = session.get(pubkey_url, headers=headers, timeout=SSO_TIMEOUT)
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
        timeout=SSO_TIMEOUT,
        allow_redirects=True,
    )

    if "cas/login" in resp.url:
        err = re.search(
            r'id=["\']errormsg["\'][^>]*>(.*?)</p>',
            resp.text,
            re.I | re.S,
        )
        msg = re.sub(r"<[^>]+>", "", err.group(1)).strip() if err else ""
        if "密码" in msg or "用户名" in msg:
            return "pwd"
        return None

    return True


def _sso_to_aggregation(session):
    headers = {"User-Agent": USER_AGENT}

    r = session.get(
        AGG_8080_URL + "/loginSSO",
        headers=headers,
        timeout=SSO_TIMEOUT,
    )
    if r.status_code != 200:
        return None

    m = re.search(r"var userCode = '([^']+)'", r.text)
    if not m:
        return None
    user_code = m.group(1)

    r = session.get(
        AGG_8070_URL + "/loginSSO",
        headers=headers,
        params={"code": user_code},
        timeout=SSO_TIMEOUT,
    )
    if r.status_code != 200:
        return None

    return user_code


def _sso_to_zlbz4(username):
    headers = {"User-Agent": USER_AGENT}

    payload = json.dumps(
        {"userCode": username, "role": "ROLE_STUDENT", "url": ""},
        separators=(",", ":"),
    )
    encrypted_code = pkcs1_encrypt(payload, AGG_PUBLIC_KEY)

    r = requests.get(
        ZLBZ_BACKEND + "/integration/loginSSO",
        headers=headers,
        params={"code": encrypted_code},
        timeout=SSO_TIMEOUT,
        allow_redirects=False,
        verify=False,
    )
    if r.status_code != 302:
        return None

    location = r.headers.get("Location", "")
    if "?" not in location:
        return None

    raw_query = location.split("?", 1)[1]
    params = {}
    for part in raw_query.split("&"):
        if "=" in part:
            k, v = part.split("=", 1)
            params[k] = v

    loginname = params.get("loginname", "")
    role_name = params.get("roleName", "")
    if not loginname or not role_name:
        return None

    url = (
        ZLBZ_FRONTEND
        + "/manage/integration/doLogin?loginname="
        + loginname
        + "&roleName="
        + role_name
        + "&response500=false"
    )
    r = requests.post(url, headers=headers, timeout=SSO_TIMEOUT, verify=False)
    if r.status_code != 200:
        return None

    try:
        data = r.json()
        token = data["data"]["accessToken"]
        return token
    except (KeyError, TypeError):
        return None


def jp_login(username: str, password: str):
    try:
        session = requests.Session()
        session.verify = False

        result = _cas_login(session, username, password)
        if result == "pwd":
            return {"status": "pwd"}
        if result is None:
            return {"status": "error"}

        if _sso_to_aggregation(session) is None:
            return {"status": "error"}

        token = _sso_to_zlbz4(username)
        if token is None:
            return {"status": "error"}

        return {"status": "success", "data": {"token": token}}
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


# ===== 评教 API =====


def _api_headers(token):
    return {
        "User-Agent": USER_AGENT,
        "Authorization": "Bearer" + token,
        "Referer": ZLBZ_FRONTEND + "/",
    }


def _api_post(token, path, params=None, data=None, json_data=None):
    url = ZLBZ_FRONTEND + "/api" + path
    headers = _api_headers(token)
    if json_data is not None:
        headers["Content-Type"] = "application/json;charset=utf-8"
        return requests.post(
            url,
            headers=headers,
            params=params,
            data=json.dumps(json_data) if not isinstance(json_data, str) else json_data,
            timeout=REQUEST_TIMEOUT,
            verify=False,
        )
    return requests.post(
        url,
        headers=headers,
        params=params,
        data=data,
        timeout=REQUEST_TIMEOUT,
        verify=False,
    )


def _get_task_data(token):
    r = _api_post(token, "/xspj/xspj/getXspjtask", params={})
    if r.status_code != 200:
        return {}, []
    body = r.json()
    if body.get("code") != 200:
        return {}, []
    data = body.get("data", {})
    sfwc = {s["taskid"]: s for s in (data.get("taskSfwc") or [])}
    tasks = data.get("pageData") or []
    return sfwc, tasks


def _get_task_list(token):
    _, tasks = _get_task_data(token)
    return tasks


def _get_student_courses(token, taskid):
    r = _api_post(
        token, "/xspj/xspj/getXspjStudentCourses", params={"taskid": taskid}
    )
    if r.status_code != 200:
        return []
    body = r.json()
    if body.get("code") != 200:
        return []
    return body.get("data", {}).get("pageData", []) or []


def _get_index_system(token, indexid, pjcoursetype):
    r = _api_post(
        token,
        "/xspj/xspj/getXspjTindexSystem",
        params={"indexid": indexid, "pjcoursetype": pjcoursetype},
    )
    if r.status_code != 200:
        return []
    body = r.json()
    if body.get("code") != 200:
        return []
    return body.get("data", {}).get("pageData", []) or []


def _build_evaluate_result(indicators):
    results = []
    total_score = 0

    for idx, ind in enumerate(indicators):
        item_type = ind.get("type", "")
        is_scored = ind.get("isscoredid") == 1 or ind.get("isscored") == "是"
        options = ind.get("optionarr") or []

        result = {
            "indexid": ind.get("indexid", ""),
            "index_order": ind.get("ordor", idx + 1),
            "sfbt": ind.get("isemptyed", "否"),
            "index_type": item_type,
        }

        first_lvl = ind.get("firstlevlindex")
        if first_lvl:
            result["yjzb"] = first_lvl

        if item_type in ("单选题", "量表题") and options:
            best = max(options, key=lambda o: float(o.get("score", 0) or 0))
            result["index_title"] = best.get("title", "")
            result["index_score"] = float(best.get("score", 0) or 0)
            result["option_id"] = best.get("id", 0)
            if is_scored:
                total_score += result["index_score"]

        elif item_type == "打分题":
            max_score = float(ind.get("score", 0) or 0) * float(
                ind.get("weight", 1) or 1
            )
            result["index_title"] = str(int(max_score)) if max_score == int(max_score) else str(max_score)
            result["index_score"] = max_score
            if is_scored:
                total_score += max_score

        elif item_type == "问答题":
            result["index_title"] = ""
            result["index_score"] = 0

        elif item_type == "填空题":
            result["index_title"] = ""
            result["index_score"] = 0

        elif item_type == "多选题" and options:
            result["index_title"] = "*".join(
                o.get("title", "") for o in options
            )
            result["index_score"] = 0

        else:
            if options:
                best = max(
                    options, key=lambda o: float(o.get("score", 0) or 0)
                )
                result["index_title"] = best.get("title", "")
                result["index_score"] = float(best.get("score", 0) or 0)
                result["option_id"] = best.get("id", 0)
                if is_scored:
                    total_score += result["index_score"]
            else:
                result["index_title"] = ""
                result["index_score"] = 0

        results.append(result)

    return results, round(total_score, 2)


def _flatten_indicators(tree, target_level=None):
    flat = []
    for node in tree:
        sub = node.get("subList") or []
        if sub:
            flat.extend(_flatten_indicators(sub, target_level))
        else:
            flat.append(node)
    return flat


def _submit_evaluation(token, task, course, indicators):
    eval_results, total_score = _build_evaluate_result(indicators)

    commit_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    payload = {
        "classno": course.get("classno", ""),
        "coursecode": course.get("coursecode", ""),
        "coursename": course.get("coursename", ""),
        "jobnumber": course.get("jobnumber", ""),
        "studentid": course.get("studentid", ""),
        "studentname": course.get("studentname", ""),
        "taskid": task.get("taskid", ""),
        "teachername": course.get("teachername", ""),
        "yearterm": course.get("yearterm", ""),
        "totalscore": total_score,
        "pjcoursetype": course.get("pjcoursetype", ""),
        "courseorgcode": course.get("courseorgcode", ""),
        "courseorgname": course.get("courseorgname", ""),
        "evaluateResult": eval_results,
        "commit_time": commit_time,
    }

    pjjgid = course.get("pjjgid")
    if pjjgid:
        payload["tevaluateResultid"] = pjjgid

    r = _api_post(
        token,
        "/xspj/xspj/saveStudentComment",
        params={},
        json_data=json.dumps([payload], ensure_ascii=False),
    )
    if r.status_code != 200:
        return False
    body = r.json()
    return body.get("code") == 200


# ===== 查询 & 一键评教 =====


def _get_course_score(token, pjjgid):
    r = _api_post(token, "/xspj/xspj/getevaluateResultId", params={"id": pjjgid})
    if r.status_code != 200:
        return None
    body = r.json()
    if body.get("code") != 200:
        return None
    records = body.get("data", {}).get("pageData") or []
    if not records:
        return None
    latest = {}
    for rec in records:
        iid = rec.get("indexid")
        rid = rec.get("id", 0)
        if iid not in latest or rid > latest[iid].get("id", 0):
            latest[iid] = rec
    return round(sum(float(r.get("index_score", 0) or 0) for r in latest.values()), 2)


def query_status(username: str, password: str):
    try:
        login_result = jp_login(username, password)
        if login_result["status"] != "success":
            return login_result

        token = login_result["data"]["token"]

        sfwc, tasks = _get_task_data(token)
        if not tasks:
            return {"status": "empty", "message": "没有评教任务"}

        result_tasks = []
        for task in tasks:
            taskid = task.get("taskid", "")
            stat = sfwc.get(taskid, {})

            courses = _get_student_courses(token, taskid)
            pending = [c for c in courses if c.get("hassubmit", 0) != 1]
            done = [c for c in courses if c.get("hassubmit", 0) == 1]

            course_list = []
            for c in courses:
                course_list.append({
                    "pjjgid": c.get("pjjgid"),
                    "coursename": c.get("coursename", ""),
                    "teachername": c.get("teachername", ""),
                    "done": c.get("hassubmit", 0) == 1,
                })

            result_tasks.append({
                "taskid": taskid,
                "taskname": task.get("taskname", ""),
                "status": task.get("currentStatus", ""),
                "starttime": task.get("starttime", ""),
                "endtime": task.get("endtime", ""),
                "total": stat.get("yprs", len(courses)),
                "completed": stat.get("sprs", len(done)),
                "pending": stat.get("wprs", len(pending)),
                "courses": course_list,
            })

        return {"status": "success", "data": result_tasks, "token": token}
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def _get_course_detail(token, pjjgid):
    score = _get_course_score(token, pjjgid)
    r = _api_post(token, "/xspj/xspj/getevaluateResultId", params={"id": pjjgid})
    records = r.json().get("data", {}).get("pageData") or []
    latest = {}
    for rec in records:
        iid = rec.get("indexid")
        rid = rec.get("id", 0)
        if iid not in latest or rid > latest[iid].get("id", 0):
            latest[iid] = rec
    details = sorted(latest.values(), key=lambda x: int(x.get("index_order", 0)))
    return {
        "score": score,
        "details": [
            {
                "order": d.get("index_order"),
                "title": d.get("title", ""),
                "answer": d.get("index_title", ""),
                "score": d.get("index_score", 0),
            }
            for d in details
        ],
    }


def auto_evaluate(username: str, password: str):
    try:
        login_result = jp_login(username, password)
        if login_result["status"] != "success":
            return login_result

        token = login_result["data"]["token"]

        tasks = _get_task_list(token)
        if not tasks:
            return {"status": "empty", "message": "没有评教任务"}

        active_tasks = [
            t
            for t in tasks
            if t.get("currentStatus") == "进行中"
        ]
        if not active_tasks:
            active_tasks = tasks

        evaluated = []
        skipped = []

        for task in active_tasks:
            taskid = task.get("taskid", "")
            indexid = task.get("indexid", "")
            task_name = task.get("taskname", "")

            courses = _get_student_courses(token, taskid)
            if not courses:
                continue

            for course in courses:
                cname = course.get("coursename", "")
                tname = course.get("teachername", "")
                label = f"{cname}({tname})"

                has_submit = course.get("hassubmit", 0)
                zt = course.get("zt", "")
                if has_submit == 1 or zt == "yjs":
                    skipped.append(label)
                    continue

                pjcoursetype = course.get("pjcoursetype", "")
                index_tree = _get_index_system(token, indexid, pjcoursetype)
                if not index_tree:
                    skipped.append(f"{label}(无指标)")
                    continue

                indicators = _flatten_indicators(index_tree)
                if not indicators:
                    skipped.append(f"{label}(指标为空)")
                    continue

                ok = _submit_evaluation(token, task, course, indicators)
                if ok:
                    evaluated.append(label)
                else:
                    skipped.append(f"{label}(提交失败)")

        if not evaluated and not skipped:
            return {"status": "empty", "message": "没有待评课程"}

        return {
            "status": "success",
            "data": {
                "evaluated": evaluated,
                "skipped": skipped,
                "count": len(evaluated),
            },
        }
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    username = input("username: ").strip()
    password = input("password: ").strip()

    print("1) 查询教评状态")
    print("2) 一键完成教评")
    choice = input("选择: ").strip()

    if choice == "1":
        result = query_status(username, password)
        if result["status"] == "success":
            all_courses = []
            for t in result["data"]:
                print(f"\n{t['taskname']} [{t['status']}]")
                print(f"  {t['starttime']} ~ {t['endtime']}")
                print(f"  已评 {t['completed']}/{t['total']}，待评 {t['pending']}")
                for c in t["courses"]:
                    idx = len(all_courses) + 1
                    mark = "v" if c["done"] else " "
                    print(f"  {idx}. [{mark}] {c['coursename']}({c['teachername']})")
                    all_courses.append(c)

            pick = input("\n输入编号查看详情（回车跳过）: ").strip()
            if pick.isdigit() and 1 <= int(pick) <= len(all_courses):
                c = all_courses[int(pick) - 1]
                if not c["done"]:
                    print("该课程尚未评教")
                elif c.get("pjjgid"):
                    token = result["token"]
                    detail = _get_course_detail(token, c["pjjgid"])
                    print(f"\n{c['coursename']}({c['teachername']}) 总分: {detail['score']}")
                    for item in detail["details"]:
                        print(f"  {item['order']}. {item['title']}")
                        print(f"     答: {item['answer']}  分: {item['score']}")
        else:
            print(json.dumps(result, ensure_ascii=False))
    elif choice == "2":
        result = auto_evaluate(username, password)
        print(json.dumps(result, ensure_ascii=False))
    else:
        print("无效选择")


if __name__ == "__main__":
    main()
