from __future__ import annotations

import asyncio
import sqlite3
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import uvicorn
from fastapi import FastAPI

from service import (
    EndpointConfig,
    LoginFailedError,
    RemoteSystemError,
    RoomNotFoundError,
    RoomRecord,
    XudaPowerClient,
)


BASE_DIR = Path(__file__).resolve().parent
ROOM_DB_PATH = BASE_DIR / "room.db"
CONFIG_PATH = BASE_DIR / "config.toml"


@dataclass(frozen=True)
class ServerConfig:
    host: str
    port: int
    request_timeout: float
    est_days_min: int


@dataclass(frozen=True)
class AppConfig:
    server: ServerConfig
    endpoints: dict[str, EndpointConfig]


def load_config(path: Path) -> AppConfig:
    with path.open("rb") as file:
        config = tomllib.load(file)

    zx = config["zx"]
    cn = config["cn"]
    dxq = config["dxq"]
    server = config["server"]

    server_config = ServerConfig(
        host=str(server["host"]),
        port=int(server["port"]),
        request_timeout=float(server["request_timeout"]),
        est_days_min=int(server["est_days_min"]),
    )

    return AppConfig(
        server=server_config,
        endpoints={
            "zx": EndpointConfig(
                url=str(zx["url"]).rstrip("/"),
                mode="legacy",
                timeout=server_config.request_timeout,
                password=str(zx["password"]),
                price=str(zx["price"]),
                login_path="/chkuser.fwps",
                consume_history_path="/consumeHistory.fwps",
            ),
            "cn": EndpointConfig(
                url=str(cn["url"]).rstrip("/"),
                mode="legacy",
                timeout=server_config.request_timeout,
                password=str(cn["password"]),
                price=str(cn["price"]),
                login_path="/chkuser.fwp",
                consume_history_path="/consumeHistory.fwp",
            ),
            "dxq": EndpointConfig(
                url=str(dxq["url"]).rstrip("/"),
                mode="dxq",
                timeout=server_config.request_timeout,
                price=str(dxq["price"]),
            ),
        },
    )


APP_CONFIG = load_config(CONFIG_PATH)

app = FastAPI(
    title="徐工电费查询 API",
    version="0.2.0",
    description="",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)


def get_connection() -> sqlite3.Connection:
    if not ROOM_DB_PATH.exists():
        raise RemoteSystemError("room.db 不存在")
    conn = sqlite3.connect(ROOM_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def get_room_by_id(custom_id: str) -> RoomRecord:
    with get_connection() as conn:
        row = conn.execute(
            'SELECT endpoint, roomName, roomID FROM rooms WHERE "ID" = ?',
            (custom_id,),
        ).fetchone()
    if row is None:
        raise RoomNotFoundError("无此房间号")
    return RoomRecord(
        endpoint=str(row["endpoint"]),
        roomName=str(row["roomName"]),
        roomID=str(row["roomID"]),
    )


def divide_by_price(value: str, price: str) -> str:
    try:
        amount = float(value)
        unit_price = float(price)
    except (TypeError, ValueError):
        return "-"
    if unit_price <= 0:
        return "-"
    return f"{amount / unit_price:.2f}"


def estimate_days_left(available: str, daily_usage: list[dict[str, str]], min_days: int) -> str:
    if len(daily_usage) < min_days:
        return "-"
    try:
        available_value = float(available)
        usage_values = [float(item["value"]) for item in daily_usage]
    except (KeyError, TypeError, ValueError):
        return "-"
    average_usage = sum(usage_values) / len(usage_values)
    if average_usage <= 0:
        return "-"
    return str(int(available_value / average_usage))


def build_success_payload(result: dict[str, Any], endpoint: EndpointConfig) -> dict[str, Any]:
    if endpoint.mode == "dxq":
        return {
            "status": "success",
            "data": {
                "price": endpoint.price,
                "available": result.get("available", "-"),
            },
        }

    available = divide_by_price(str(result.get("available", "")), endpoint.price)
    daily_usage = result.get("daily_usage", [])
    return {
        "status": "success",
        "data": {
            "price": endpoint.price,
            "monthUsage": divide_by_price(str(result.get("month_usage", "")), endpoint.price),
            "available": available,
            "estDays": estimate_days_left(available, daily_usage, APP_CONFIG.server.est_days_min),
            "dailyUsage": [
                {
                    "date": item.get("date_label", ""),
                    "usage": item.get("value", ""),
                }
                for item in daily_usage
            ],
        },
    }


def build_error_payload() -> dict[str, str]:
    return {"status": "error"}


def query_sync(custom_id: str) -> dict[str, Any]:
    room = get_room_by_id(custom_id)
    endpoint = APP_CONFIG.endpoints[room.endpoint]
    client = XudaPowerClient(endpoint)
    try:
        result = client.query_room(room)
    finally:
        client.close()
    return build_success_payload(result, endpoint)


@app.get("/query/{id}")
async def query(id: str) -> dict[str, Any]:
    try:
        return await asyncio.to_thread(query_sync, id)
    except (RoomNotFoundError, LoginFailedError, RemoteSystemError):
        return build_error_payload()
    except Exception:
        return build_error_payload()


def main() -> None:
    uvicorn.run(app, host=APP_CONFIG.server.host, port=APP_CONFIG.server.port, reload=False)


if __name__ == "__main__":
    main()
