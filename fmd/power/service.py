from __future__ import annotations

import hashlib
import re
import unicodedata
from dataclasses import dataclass
from typing import Any, Literal

import requests
from bs4 import BeautifulSoup


USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/146.0.0.0 Safari/537.36"
)


class QueryError(RuntimeError):
    pass


class RoomNotFoundError(QueryError):
    pass


class LoginFailedError(QueryError):
    pass


class RemoteSystemError(QueryError):
    pass


@dataclass(frozen=True)
class EndpointConfig:
    url: str
    mode: Literal["legacy", "dxq"]
    timeout: float
    password: str | None = None
    price: str = ""
    login_path: str = ""
    consume_history_path: str = ""


@dataclass(frozen=True)
class RoomRecord:
    endpoint: str
    roomName: str
    roomID: str


def normalize_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", value or "")
    text = text.replace("\xa0", " ").replace("　", " ")
    return re.sub(r"\s+", " ", text).strip()


def md5_hex(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def get_soup(html: str) -> BeautifulSoup:
    return BeautifulSoup(html, "html.parser")


def get_input_value(soup: BeautifulSoup, input_id: str) -> str:
    element = soup.find("input", id=input_id)
    if element is None:
        raise RemoteSystemError(f"页面中未找到字段 {input_id}")
    value = element.get("value")
    if value is None:
        raise RemoteSystemError(f"字段 {input_id} 缺少 value")
    return str(value)


def get_table_rows(table: Any) -> list[list[str]]:
    rows: list[list[str]] = []
    for tr in table.find_all("tr"):
        cells = [normalize_text(td.get_text(" ", strip=True)) for td in tr.find_all("td")]
        if cells:
            rows.append(cells)
    return rows


def find_table_containing(soup: BeautifulSoup, keyword: str) -> Any:
    candidates: list[tuple[int, Any]] = []
    for table in soup.find_all("table"):
        table_text = normalize_text(table.get_text(" ", strip=True))
        if keyword in table_text:
            candidates.append((len(table_text), table))
    if not candidates:
        raise RemoteSystemError(f"页面中未找到包含 {keyword!r} 的表格")
    candidates.sort(key=lambda item: item[0])
    return candidates[0][1]


def zip_headers_values(headers: list[str], values: list[str]) -> dict[str, str]:
    return {
        header.replace("（", "(").replace("）", ")"): value
        for header, value in zip(headers, values, strict=False)
    }


def parse_daily_usage(soup: BeautifulSoup) -> list[dict[str, str]]:
    table = find_table_containing(soup, "用电明细")
    items: list[dict[str, str]] = []
    for td in table.find_all("td", class_="table-td"):
        spans = td.find_all("span")
        if len(spans) < 2:
            continue
        date_label = normalize_text(spans[0].get_text(" ", strip=True))
        value = normalize_text(spans[1].get_text(" ", strip=True))
        if not date_label or not value or value == "&":
            continue
        if not any(char.isdigit() for char in value):
            continue
        items.append({"date_label": date_label, "value": value})
    return items


def parse_legacy_consume_history(html: str) -> dict[str, Any]:
    if "网络超时或者您还没有登录" in html:
        raise RemoteSystemError("读取 consumeHistory 失败，服务端认为当前会话未登录")

    soup = get_soup(html)
    balance_rows = get_table_rows(find_table_containing(soup, "帐户余额"))
    if len(balance_rows) < 5:
        raise RemoteSystemError("consumeHistory 页面结构异常")

    balance_section_two = zip_headers_values(balance_rows[3], balance_rows[4])
    return {
        "month_usage": balance_section_two.get("本月用电", ""),
        "available": balance_section_two.get("本月剩余", ""),
        "daily_usage": parse_daily_usage(soup),
    }


def parse_dxq_available(html: str) -> str:
    soup = get_soup(html)
    header = soup.find("h6")
    if header is None:
        raise RemoteSystemError("dxq 页面中未找到余额信息")
    text = normalize_text(header.get_text(" ", strip=True))
    matches = re.findall(r"剩余电\(水\)量\s*([0-9.]+)", text)
    if not matches:
        raise RemoteSystemError("dxq 页面中未解析到剩余电(水)量")
    return matches[-1]


def parse_login_result(response_text: str) -> None:
    text = normalize_text(response_text)
    if "success: true" in text.lower():
        return
    match = re.search(r"msg:'([^']+)'", text)
    message = match.group(1) if match else f"登录失败，原始响应：{text}"
    raise LoginFailedError(message)


class XudaPowerClient:
    def __init__(self, endpoint: EndpointConfig) -> None:
        self.endpoint = endpoint
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT})

    def close(self) -> None:
        self.session.close()

    def _request(
        self,
        method: str,
        path: str,
        *,
        data: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> str:
        try:
            response = self.session.request(
                method,
                f"{self.endpoint.url}{path}",
                data=data,
                headers=headers,
                timeout=self.endpoint.timeout,
            )
            response.raise_for_status()
            response.encoding = response.apparent_encoding or response.encoding
            return response.text
        except requests.Timeout as exc:
            raise RemoteSystemError("上游请求超时") from exc
        except requests.RequestException as exc:
            raise RemoteSystemError("上游请求失败") from exc

    def _login_legacy(self, room: RoomRecord) -> None:
        login_page = self._request("GET", "/")
        psw_session_match = re.search(r"g_pswSession\s*=\s*(\d+)", login_page)
        if psw_session_match is None or self.endpoint.password is None:
            raise RemoteSystemError("登录页中未找到 g_pswSession")

        response_text = self._request(
            "POST",
            self.endpoint.login_path,
            data={
                "login_type": "accountId",
                "login_roomName": room.roomName,
                "login_roomID": room.roomID,
                "password": md5_hex(md5_hex(self.endpoint.password + psw_session_match.group(1))),
            },
            headers={
                "Referer": f"{self.endpoint.url}/",
                "X-Requested-With": "XMLHttpRequest",
            },
        )
        parse_login_result(response_text)

    def _query_legacy_room(self, room: RoomRecord) -> dict[str, Any]:
        self._login_legacy(room)
        consume_html = self._request("GET", self.endpoint.consume_history_path)
        return parse_legacy_consume_history(consume_html)

    def _post_dxq_form(
        self,
        *,
        viewstate: str,
        viewstate_generator: str,
        building: str,
        floor: str,
        room_id: str,
        submit: bool = False,
    ) -> str:
        data: dict[str, Any] = {
            "__VIEWSTATE": viewstate,
            "__VIEWSTATEGENERATOR": viewstate_generator,
            "drlouming": building,
            "drceng": floor,
            "drfangjian": room_id,
            "radio": "allR",
        }
        if submit:
            data["ImageButton1.x"] = "30"
            data["ImageButton1.y"] = "12"
        return self._request("POST", "/", data=data)

    def _query_dxq_room(self, room: RoomRecord) -> dict[str, Any]:
        if len(room.roomID) < 4:
            raise RemoteSystemError("dxq 房间编码无效")

        landing_html = self._request("GET", "/")
        landing_soup = get_soup(landing_html)
        building = room.roomID[:2]
        floor = room.roomID[:4]

        building_html = self._post_dxq_form(
            viewstate=get_input_value(landing_soup, "__VIEWSTATE"),
            viewstate_generator=get_input_value(landing_soup, "__VIEWSTATEGENERATOR"),
            building=building,
            floor="",
            room_id="",
        )
        building_soup = get_soup(building_html)

        floor_html = self._post_dxq_form(
            viewstate=get_input_value(building_soup, "__VIEWSTATE"),
            viewstate_generator=get_input_value(building_soup, "__VIEWSTATEGENERATOR"),
            building=building,
            floor=floor,
            room_id="",
        )
        floor_soup = get_soup(floor_html)

        result_html = self._post_dxq_form(
            viewstate=get_input_value(floor_soup, "__VIEWSTATE"),
            viewstate_generator=get_input_value(floor_soup, "__VIEWSTATEGENERATOR"),
            building=building,
            floor=floor,
            room_id=room.roomID,
            submit=True,
        )
        return {"available": parse_dxq_available(result_html)}

    def query_room(self, room: RoomRecord) -> dict[str, Any]:
        if self.endpoint.mode == "dxq":
            return self._query_dxq_room(room)
        return self._query_legacy_room(room)
