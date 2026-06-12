import json
import re
import sys

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CAS_BASE = "https://ca.xzit.edu.cn/cas"
HQGL_BASE = "http://hqgl.xzit.edu.cn/SmartTest"
SYSTEM_ID = "AEC93905F80DCC25"
TIMEOUT = 10

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/146.0.0.0 Safari/537.36"
)


def _decode_a(s):
    return "".join(chr(int(p)) for p in str(s).split("A") if p)


def _api(session, path, data=None):
    r = session.post(
        f"{HQGL_BASE}/{path}",
        headers={"User-Agent": USER_AGENT},
        data=data or {},
        timeout=TIMEOUT,
    )
    body = r.json()
    raw = body.get("data")
    if isinstance(raw, str) and "A" in raw:
        try:
            return json.loads(_decode_a(raw))
        except (json.JSONDecodeError, ValueError):
            pass
    return body


# ===== CAS =====


def _rsa_encrypt(message, exponent_hex, modulus_hex):
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


def _cas_login(session, username, password):
    from urllib.parse import urljoin

    base = CAS_BASE.rstrip("/") + "/"
    login_url = urljoin(base, "login")
    pubkey_url = urljoin(base, "v2/getPubKey")
    headers = {"User-Agent": USER_AGENT, "Referer": login_url}

    page = session.get(login_url, headers=headers, timeout=TIMEOUT)
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

    pk = session.get(pubkey_url, headers=headers, timeout=TIMEOUT).json()
    resp = session.post(
        login_url,
        headers=headers,
        data={
            "username": username,
            "password": _rsa_encrypt(
                password[::-1], pk["exponent"], pk["modulus"]
            ),
            "execution": execution,
            "_eventId": "submit",
        },
        timeout=TIMEOUT,
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

    return True


# ===== SSO =====


def bx_login(username, password):
    try:
        session = requests.Session()
        session.verify = False
        result = None
        for _ in range(3):
            session.cookies.clear()
            result = _cas_login(session, username, password)
            if result is True:
                break
        if result == "pwd":
            return {"status": "pwd"}
        if result is None:
            return {"status": "error"}

        session.get(
            f"{HQGL_BASE}/sys/transiturl9002?key=xgcas",
            headers={"User-Agent": USER_AGENT},
            timeout=TIMEOUT,
            allow_redirects=True,
        )
        return {"status": "success", "session": session}
    except requests.exceptions.Timeout:
        return {"status": "timeout"}
    except Exception:
        return {"status": "error"}


# ===== Area / Item =====


def _get_areas(session):
    return _api(session, "repair/getParentArea", {"status": "0"}).get("data", [])


def _get_child_areas(session, parentid):
    return (
        _api(session, "repair/getAreaListByParent", {"parentid": parentid})
        .get("data", [])
    )


def _get_items(session, areaid):
    return (
        _api(session, "repair/getParentItem", {"areaid": areaid})
        .get("data", [])
    )


def _get_child_items(session, parentid):
    return (
        _api(session, "repair/getChildItem", {"parentid": parentid})
        .get("data", [])
    )


def _get_user_info(session):
    data = _api(session, "repair/getUserPhone")
    m = data.get("map", {})
    return m.get("username", ""), m.get("phone", "")


def _pick(prompt, items, key_id, key_name):
    for i, item in enumerate(items, 1):
        print(f"  {i}) {item[key_name]}")
    while True:
        s = input(prompt).strip()
        if s.isdigit() and 1 <= int(s) <= len(items):
            chosen = items[int(s) - 1]
            return chosen[key_id], chosen[key_name]
        print("无效选择")


def _select_area(session):
    areas = _get_areas(session)
    if not areas:
        return None, None
    aid, aname = _pick("选择报修区域: ", areas, "areauuid", "areaname")
    children = _get_child_areas(session, aid)
    while children:
        aid, aname = _pick(f"选择下级区域: ", children, "areauuid", "areaname")
        children = _get_child_areas(session, aid)
    return aid, aname


def _select_item(session, areaid):
    items = _get_items(session, areaid)
    if not items:
        return None, None
    iid, iname = _pick("选择报修项目: ", items, "itemuuid", "itemname")
    children = _get_child_items(session, iid)
    while children:
        iid, iname = _pick(f"选择下级项目: ", children, "itemuuid", "itemname")
        children = _get_child_items(session, iid)
    return iid, iname


# ===== Submit =====


def _submit_repair(session, areauuid, itemuuid, address, content, phone, repairer, remark=""):
    proc_data = _api(session, "process/getProcess", {"systemid": SYSTEM_ID})
    procs = proc_data.get("data", [])
    if not procs:
        return False, "无法获取流程"
    processid = procs[0].get("uuid")

    btn_data = _api(session, "process/getOneBtn", {"processid": processid})
    nodes = btn_data.get("data", [])
    if not nodes:
        return False, "无法获取提交按钮"
    node = nodes[0]
    vb = node.get("visiblebutton", "")
    try:
        idx_o = vb.index("(")
        idx_c = vb.index(")")
        btnvalue = vb[:idx_o]
        btncode = vb[idx_o + 1 : idx_c]
    except ValueError:
        return False, "无法解析按钮"
    nodename = node.get("nodename", "")
    bnodecode = str(node.get("nodecode", ""))

    form_resp = _api(
        session,
        "repair/insertForm",
        {
            "areauuid": areauuid,
            "itemuuid": itemuuid,
            "address": address,
            "content": content,
            "phone": phone,
            "repairer": repairer,
            "remark": remark,
            "maketime": "",
            "images": "",
        },
    )
    if form_resp.get("code") != 0:
        return False, form_resp.get("msg", "创建报修单失败")
    orderid = form_resp.get("map", {}).get("orderid")
    if not orderid:
        return False, "未获取到报修单号"

    detail = _api(session, "repair/getRepairFormById", {"fid": orderid})
    form_list = detail.get("data") or []
    if not form_list:
        return False, "获取报修单详情失败"
    proobj = json.dumps(form_list[0], ensure_ascii=False)

    sub_resp = _api(
        session,
        "process/subprocess",
        {
            "btnval": btnvalue,
            "proobj": proobj,
            "orderid": orderid,
            "bnodecode": bnodecode,
            "processid": processid,
            "bnodename": nodename,
            "nodecode": btncode,
            "images": "",
        },
    )
    if sub_resp.get("code") != 0:
        return False, sub_resp.get("msg", "流程提交失败")

    visibman = sub_resp.get("map", {}).get("visibman", "")
    sub_nodename = sub_resp.get("map", {}).get("nodename", "")
    ischange = sub_resp.get("map", {}).get("ischange")

    if ischange == "1":
        change_resp = _api(
            session,
            "process/changeprocess",
            {"busid": orderid, "proobj": proobj},
        )
        if change_resp.get("code") == 0:
            visibman = change_resp.get("map", {}).get("visibman", visibman)

    _api(
        session,
        "repair/updateFormVisibman",
        {"fid": orderid, "visibman": visibman},
    )

    node_resp = _api(
        session,
        "repair/updateFormNode",
        {"fid": orderid, "nodecode": btncode, "nodename": sub_nodename},
    )
    if node_resp.get("code") != 0:
        return False, node_resp.get("msg", "更新状态失败")

    return True, orderid


# ===== Query =====


def query_repairs(session):
    data = _api(
        session,
        "repair/getMyFormList",
        {
            "page": 1,
            "limit": 50,
            "areaid": "",
            "itemid": "",
            "status": "",
            "btime": "",
            "etime": "",
            "content": "",
        },
    )
    return data.get("data", [])


# ===== Main =====


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    username = input("username: ").strip()
    password = input("password: ").strip()

    print("登录中...")
    result = bx_login(username, password)
    if result["status"] == "pwd":
        print("用户名或密码错误")
        return
    if result["status"] != "success":
        print(f"登录失败: {result['status']}")
        return
    session = result["session"]
    print("登录成功")

    print("\n1) 我要报修")
    print("2) 我的报修")
    choice = input("选择: ").strip()

    if choice == "1":
        uname, phone = _get_user_info(session)
        print(f"报修人: {uname}  电话: {phone}")

        areaid, areaname = _select_area(session)
        if not areaid:
            print("没有可选区域")
            return

        itemid, itemname = _select_item(session, areaid)
        if not itemid:
            print("没有可选项目")
            return

        address = input("详细地址: ").strip()
        content = input("故障描述: ").strip()
        if not content:
            print("故障描述不能为空")
            return
        remark = input("补充说明(可选): ").strip()

        print(f"\n确认信息:")
        print(f"  区域: {areaname}")
        print(f"  项目: {itemname}")
        print(f"  地址: {address}")
        print(f"  描述: {content}")
        if remark:
            print(f"  备注: {remark}")
        confirm = input("确认提交？(y/n): ").strip().lower()
        if confirm != "y":
            print("已取消")
            return

        ok, msg = _submit_repair(
            session, areaid, itemid, address, content, phone, uname, remark
        )
        if ok:
            print(f"提交成功，报修单号: {msg}")
        else:
            print(f"提交失败: {msg}")

    elif choice == "2":
        repairs = query_repairs(session)
        if not repairs:
            print("没有报修记录")
            return
        for r in repairs:
            status = r.get("nodename", "未知")
            print(f"\n[{status}] {r.get('content', '')}")
            print(f"  区域: {r.get('areaname', '')}  项目: {r.get('itemname', '')}")
            print(f"  地址: {r.get('address', '')}")
            print(f"  时间: {r.get('createtime', '')}")
            print(f"  单号: {r.get('orderid', '')}")
    else:
        print("无效选择")


if __name__ == "__main__":
    main()
