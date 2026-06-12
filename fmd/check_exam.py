import json, re, requests, urllib3, datetime
urllib3.disable_warnings()

CAS_BASE = "https://ca.xzit.edu.cn/cas"
JW_BASE = "http://jwxt.xzit.edu.cn/jwglxt"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/146.0.0.0 Safari/537.36"

def rsa_encrypt(message, exponent_hex, modulus_hex):
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

s = requests.Session()
headers = {"User-Agent": UA}

login_url = CAS_BASE + "/login"
page = s.get(login_url, headers={**headers, "Referer": login_url}, verify=False, timeout=10)
execution = re.search(r"name=[\"']execution[\"'][^>]*value=[\"']([^\"']+)", page.text).group(1)
pk = s.get(CAS_BASE + "/v2/getPubKey", headers=headers, verify=False, timeout=10).json()
encrypted = rsa_encrypt("@Wangrun071519"[::-1], pk["exponent"], pk["modulus"])

resp = s.post(login_url, headers={**headers, "Referer": login_url}, data={
    "username": "25070100245",
    "password": encrypted,
    "execution": execution,
    "_eventId": "submit",
}, verify=False, allow_redirects=True, timeout=10)

jw_sso = JW_BASE + "/xtgl/login_slogin.html"
s.get(CAS_BASE + "/login?service=" + jw_sso, headers=headers, verify=False, allow_redirects=True, timeout=10)

now = datetime.datetime.now()
year = now.year - 1 if now.month < 9 else now.year
month = now.month
if month >= 9:
    xqm = "3"
elif month >= 2:
    xqm = "12"
else:
    xqm = "3"

exam_resp = s.post(
    JW_BASE + "/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105",
    headers=headers,
    data={
        "xnm": str(year),
        "xqm": xqm,
        "_search": "false",
        "queryModel.showCount": "100",
        "queryModel.currentPage": "1",
        "queryModel.sortName": "",
        "queryModel.sortOrder": "asc",
        "time": "0",
    },
    timeout=10,
)

data = exam_resp.json()
items = data.get("items", [])
for item in items:
    print(f"Course: {item.get('kcmc')}, cxbj: {repr(item.get('cxbj'))}, ksmc: {item.get('ksmc')}")

print()
if items:
    print("Raw first item:")
    print(json.dumps(items[0], ensure_ascii=False, indent=2))
