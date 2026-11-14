"""Data Scope 端到端脚本的公共部分：HTTP、登录、状态文件。只用标准库，不引入依赖。"""
import json
import os
import time
import urllib.error
import urllib.request

GATEWAY = os.environ.get("E2E_GATEWAY", "http://127.0.0.1:8088")
SYSTEM = os.environ.get("E2E_SYSTEM", "http://127.0.0.1:8080")
DEMO = os.environ.get("E2E_DEMO", "http://127.0.0.1:8316")
PROJECT_CODE = "demo-crm"
ADMIN_USER = "admin"
ADMIN_PASSWORD = os.environ.get("KAIWU_BOOTSTRAP_ADMIN_PASSWORD", "Kaiwu!e2e-admin-1")
USER_PASSWORD = "Demo!pass-2026"


class ApiError(Exception):
    def __init__(self, status, body, where):
        super().__init__(f"{where} -> HTTP {status}: {str(body)[:300]}")
        self.status = status
        self.body = body


def call(method, url, body=None, token=None, headers=None, raw=False):
    """发一个请求；返回 (HTTP 状态码, 解析后的 JSON 或文本)。不对非 2xx 抛异常，由调用方断言。"""
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, method=method)
    if body is not None:
        request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            status, payload = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, payload = error.code, error.read()
    if raw:
        return status, payload
    try:
        return status, json.loads(payload) if payload else None
    except ValueError:
        return status, payload.decode(errors="replace")


def ok(method, url, body=None, token=None, where=None, headers=None):
    """要求 2xx 且业务码为 0，返回 data。"""
    status, payload = call(method, url, body, token, headers)
    if status // 100 != 2 or (isinstance(payload, dict) and payload.get("code") not in (0, None)):
        raise ApiError(status, payload, where or f"{method} {url}")
    return payload.get("data") if isinstance(payload, dict) else payload


def login(username, password):
    return ok("POST", f"{GATEWAY}/api/auth/login", {"username": username, "password": password}, where=f"login {username}")[
        "accessToken"
    ]


def wait_until(predicate, timeout, interval=1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(interval)
    return None


def state_path():
    return os.path.join(os.environ["E2E_WORK"], "state.json")


def load_state():
    path = state_path()
    return json.load(open(path)) if os.path.exists(path) else {}


def save_state(state):
    with open(state_path(), "w") as handle:
        json.dump(state, handle, indent=2, ensure_ascii=False)
