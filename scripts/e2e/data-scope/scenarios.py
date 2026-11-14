"""场景阶段：对着真实的 Gateway / System / 示例服务逐条验证，并把结果写成报告。

所有断言都带「预期」，不一致即失败（退出码 1）。示例服务里没有任何范围代码，可见性全部来自 kaiwu-data-scope。
"""
import base64
import hashlib
import subprocess
import sys
import time
import uuid

from e2e_lib import *

API = f"{GATEWAY}/{PROJECT_CODE}-api/api/customers"
INTERNAL_TOKEN = os.environ.get("KAIWU_GATEWAY_INTERNAL_TOKEN", "gw-internal-token-e2e")
CONTEXT_KEY = os.environ.get("E2E_CONTEXT_KEY")  # Gateway 的 Context 私钥文件，仅用来本机签 Agent Context

results = []  # (场景, 预期, 实际, 通过)
lines = []  # 报告正文


def check(scenario, expected, actual):
    passed = expected == actual
    results.append((scenario, expected, actual, passed))
    print(("PASS " if passed else "FAIL ") + scenario + ("" if passed else f"\n   预期 {expected}\n   实际 {actual}"))
    return passed


def say(text=""):
    lines.append(text)
    print(text)


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def sign_jwt(header, claims):
    signing_input = b64(json.dumps(header, separators=(",", ":")).encode()) + "." + b64(json.dumps(claims, separators=(",", ":")).encode())
    signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", CONTEXT_KEY], input=signing_input.encode(), capture_output=True, check=True).stdout
    return signing_input + "." + b64(signature)


def snapshot(user_id):
    """System 的项目入口授权快照，与 Gateway 实际取到的是同一个接口。"""
    return ok("GET", f"{SYSTEM}/api/internal/gateway/project-access?projectCode={PROJECT_CODE}&userId={user_id}", None,
              headers={"X-Kaiwu-Internal-Token": INTERNAL_TOKEN}, where="project-access")


def agent_context(snap, user_id, meta, params_json="{}"):
    """按 GatewayContextIssuer.issueForAgent 的声明集合签发一次性只读 Agent Context。"""
    now = int(time.time())
    claims = {
        "iss": "kaiwu-gateway-service", "aud": ["kaiwu-demo-crm-service"], "sub": str(user_id), "jti": str(uuid.uuid4()),
        "iat": now, "exp": now + 60, "sid": "e2e-session", "projectId": snap["projectId"], "projectCode": snap["projectCode"],
        "permissions": snap["permissions"], "projectRoleCodes": snap["projectRoleCodes"], "capability": meta["code"],
        "version": meta["version"], "manifestHash": meta["manifestHash"],
        "paramsHash": hashlib.sha256(params_json.encode()).hexdigest(), "correlationId": "e2e-" + uuid.uuid4().hex[:12], "readOnly": True,
    }
    if snap.get("dataScope"):
        claims["ds"] = snap["dataScope"]
    return sign_jwt({"typ": "kaiwu-agent-action-context+jwt", "alg": "RS256"}, claims), claims


def agent_names(user_id, meta):
    snap = snapshot(user_id)
    token, claims = agent_context(snap, user_id, meta)
    status, body = call("POST", f"{DEMO}/api/internal/agent/capabilities/{meta['code']}/invoke",
                        {"code": meta["code"], "version": meta["version"], "manifestHash": meta["manifestHash"], "paramsJson": "{}",
                         "correlationId": claims["correlationId"]}, headers={"X-Kaiwu-Context": token})
    if status != 200:
        raise ApiError(status, body, "agent invoke")
    return sorted(row["name"] for row in body["rows"]), len(token)


class Session:
    """一个已登录用户经 Gateway 访问示例服务。"""

    def __init__(self, name, state):
        self.name = name
        self.id = state["users"][name]
        self.token = login(name, USER_PASSWORD)

    def req(self, method, path="", body=None):
        return call(method, API + path, body, self.token)

    def create(self, name):
        status, body = self.req("POST", "", {"name": name})
        assert status == 200, (self.name, name, status, body)
        return body["id"]

    def listing(self):
        status, body = self.req("GET", "?current=1&size=100")
        assert status == 200, (self.name, status, body)
        return sorted(body["names"]), body["total"]

    def count(self):
        return self.req("GET", "/count")[1]["count"]

    def export(self):
        return sorted(self.req("GET", "/export")[1])


def settle():
    """范围变更最长在 Gateway 的 30 秒缓存之后生效。"""
    time.sleep(32)


def run():
    state = load_state()
    admin = login(ADMIN_USER, ADMIN_PASSWORD)
    meta = call("GET", f"{DEMO}/demo/agent-meta")[1]
    s = {n: Session(n, state) for n in ("alice", "bob", "carol", "dave")}
    pid = state["project_id"]

    say("# Data Scope 端到端联调报告")
    say()
    say("## 场景 1：行数对照（列表、总数、count、导出、Agent 读）")
    ids = {}
    for who, names in (("alice", ["A1", "A2"]), ("bob", ["B1", "B2"]), ("carol", ["C1"]), ("dave", ["D1", "D2"])):
        for n in names:
            ids[n] = s[who].create(n)
    expected = {"alice": ["A1", "A2"], "bob": ["A1", "A2", "B1", "B2"], "carol": ["A1", "A2", "B1", "B2", "C1", "D1", "D2"], "dave": ["D1", "D2"]}
    say("| 用户 | 范围 | 列表 | total | count | 导出 | Agent |")
    say("|---|---|---|---|---|---|---|")
    scope_of = {"alice": "SELF", "bob": "DEPT_AND_CHILD", "carol": "ALL", "dave": "SELF"}
    for who in s:
        names, total = s[who].listing()
        exported, count = s[who].export(), s[who].count()
        agent, _ = agent_names(s[who].id, meta)
        say(f"| {who} | {scope_of[who]} | {' '.join(names)} | {total} | {count} | {' '.join(exported)} | {' '.join(agent)} |")
        check(f"行数对照 {who}：列表", expected[who], names)
        check(f"行数对照 {who}：total/count/导出/Agent 与列表一致", [len(expected[who])] * 2 + [expected[who]] * 2, [total, count, exported, agent])

    say()
    say("## 场景 1b：详情 / 修改 / 删除（越权一律 404）")
    say("| 操作者 → 目标 | 详情 | 修改 | 删除 |")
    say("|---|---|---|---|")

    def trio(who, target, delete=False):
        g = s[who].req("GET", f"/{ids[target]}")[0]
        u = s[who].req("PUT", f"/{ids[target]}", {"name": target})[0]
        d = s[who].req("DELETE", f"/{ids[target]}")[0] if delete else "—"
        say(f"| {who} → {target} | {g} | {u} | {d} |")
        return g, u, d

    check("alice → 自己的 A1：详情/修改", (200, 200, "—"), trio("alice", "A1"))
    check("alice → bob 的 B1：详情/修改/删除均 404", (404, 404, 404), trio("alice", "B1", True))
    check("alice → dave 的 D1：详情/修改均 404", (404, 404, "—"), trio("alice", "D1"))
    check("bob → 子部门 alice 的 A1：详情/修改", (200, 200, "—"), trio("bob", "A1"))
    check("bob → 范围外 D1：详情/修改/删除均 404", (404, 404, 404), trio("bob", "D1", True))
    check("carol → 任意行：详情/修改", (200, 200, "—"), trio("carol", "D1"))
    check("越权删除没有真的删除（B1、D1 仍在）", True, "B1" in s["carol"].export() and "D1" in s["carol"].export())
    check("alice 删除自己的 A2 → 200", 200, s["alice"].req("DELETE", f"/{ids['A2']}")[0])

    say()
    say("## 场景 2：角色范围变更的生效时间")
    scopes_url = f"{GATEWAY}/api/projects/{pid}/roles/{state['roles']['sales-self']}/data-scopes"
    sales2 = state["departments"]["sales-2"]
    base = s["alice"].listing()[0]
    ok("PUT", scopes_url, {"items": [{"resourceCode": "democrm:customer", "scope": "CUSTOM_DEPT", "includeChild": False, "deptIds": [sales2]}]},
       admin, where="scope change")
    started = time.time()
    widened = wait_until(lambda: len(s["alice"].listing()[0]) > len(base), 60)
    took_up = time.time() - started
    check("sales-self 改为 CUSTOM_DEPT(销售二部) 后 alice 看到销售二部的行", True, bool(widened))
    check("扩大后 alice 可见的集合", sorted(base + ["D1", "D2"]), s["alice"].listing()[0])
    ok("PUT", scopes_url, {"items": []}, admin, where="scope revert")
    started = time.time()
    narrowed = wait_until(lambda: s["alice"].listing()[0] == base, 60)
    took_down = time.time() - started
    check("还原为仅本人后 alice 回到原集合", True, bool(narrowed))
    say(f"生效耗时：扩大 {took_up:.1f} s，收窄 {took_down:.1f} s（上限约 30 s 缓存 + 1 s 轮询粒度）")
    check("两次生效耗时都不超过 40 秒", True, took_up < 40 and took_down < 40)

    say()
    say("## 场景 3：调岗与批量交接")
    ok("POST", f"{GATEWAY}/api/org/users/{s['alice'].id}/departments", {"departmentIds": [sales2]}, admin, where="alice moves")
    check("alice 调岗后立刻仍能看到自己名下的 A1", True, "A1" in s["alice"].listing()[0])
    settle()
    check("等过缓存期，alice 仍能看到 A1（可见性跟归属人走）", True, "A1" in s["alice"].listing()[0])
    ids["A3"] = s["alice"].create("A3")  # 调岗后创建：归属部门变成销售二部
    transfer = lambda who, body: s[who].req("POST", "/transfer", body)
    erin = state["users"]["erin"]
    check("alice 没有 transfer 权限 → 403", 403, transfer("alice", {"fromUserId": s["alice"].id, "toUserId": s["dave"].id, "toDeptId": int(sales2)})[0])
    check("bob 转给非成员 erin → 400", 400, transfer("bob", {"fromUserId": s["alice"].id, "toUserId": int(erin), "toDeptId": int(sales2)})[0])
    check("bob 转给 carol 但部门不是 carol 的所属部门 → 400", 400,
          transfer("bob", {"fromUserId": s["alice"].id, "toUserId": int(s["carol"].id), "toDeptId": int(sales2)})[0])
    status, body = transfer("bob", {"fromUserId": s["dave"].id, "toUserId": int(s["carol"].id), "toDeptId": int(state["departments"]["hq"])})
    check("bob 转移 dave 名下的行（不在 bob 范围内）→ 200 且转移 0 行", (200, 0), (status, body.get("transferred") if isinstance(body, dict) else body))
    status, body = transfer("bob", {"fromUserId": s["alice"].id, "toUserId": int(s["dave"].id), "toDeptId": int(sales2)})
    check("bob 把 alice 名下（bob 看得到的）转给 dave → 200 且转移 1 行（A1）", (200, 1), (status, body.get("transferred") if isinstance(body, dict) else body))
    check("转移后 alice 只剩 A3", ["A3"], s["alice"].listing()[0])
    check("转移后 dave 看到 A1 与自己的行", ["A1", "D1", "D2"], s["dave"].listing()[0])
    check("转移后 bob 只剩自己的两行（A1 已属销售二部）", ["B1", "B2"], s["bob"].listing()[0])
    check("carol（全部）仍可见全部", True, len(s["carol"].listing()[0]) >= 6)

    say()
    say("## 场景 4：管理端契约（D1 接口、V119 字典与文案）")
    view = ok("GET", f"{GATEWAY}/api/projects/{pid}/roles/{state['roles']['sales-manager']}/data-scopes", None, admin, where="manager scopes")
    item = view["items"][0]
    check("sales-manager 的配置来自清单：DEPT_AND_CHILD、已配置", ("DEPT_AND_CHILD", True, False), (item["scope"], item["configured"], view["readOnly"]))
    admin_view = ok("GET", f"{GATEWAY}/api/projects/{pid}/roles/{state['roles']['project-admin']}/data-scopes", None, admin, where="admin scopes")
    check("内置 project-admin 只读且全部", (True, "ALL"), (admin_view["readOnly"], admin_view["items"][0]["scope"]))
    status, body = call("PUT", scopes_url, {"items": [{"resourceCode": "democrm:customer", "scope": "ORG", "includeChild": False, "deptIds": []}]}, admin)
    check("保存不在允许范围内的类型 → 400 且错误键为 dataScopeInvalid", (400, "api.project.dataScopeInvalid"), (status, (body or {}).get("messageKey")))
    status, body = call("PUT", f"{GATEWAY}/api/projects/{pid}/roles/{state['roles']['project-admin']}/data-scopes", {"items": []}, admin)
    check("内置角色保存 → 400", 400, status)
    dictionary = ok("GET", f"{GATEWAY}/api/metadata/dicts/effective/project.data_scope.type", None, admin, where="dict")
    check("字典 project.data_scope.type 的五个取值", ["ALL", "CUSTOM_DEPT", "DEPT", "DEPT_AND_CHILD", "SELF"], sorted(i["itemValue"] for i in dictionary["items"]))
    # 登录后的完整目录（/api/public/... 只有登录页用的一小部分）
    catalog = ok("GET", f"{GATEWAY}/api/i18n/catalog?locale=zh-CN", None, admin, where="catalog")
    messages = catalog.get("messages", {}) if isinstance(catalog, dict) else {}
    check("V119 界面文案已进入文案目录", True, all(k in messages for k in ("roles.dataScope", "dataScope.confirmAll", "dataScope.sizeWarning")))

    say()
    say("## 场景 5：非成员与 Context 体积")
    erin_token = login("erin", USER_PASSWORD)
    check("非项目成员 erin 经 Gateway 访问 → 403", 403, call("GET", API + "?current=1&size=10", None, erin_token)[0])
    say("| 用户 | `ds` 紧凑 JSON 字节 | Agent Context 字符数 |")
    say("|---|---|---|")
    for who in s:
        snap = snapshot(s[who].id)
        ds_bytes = len(json.dumps(snap["dataScope"], separators=(",", ":"), ensure_ascii=False).encode()) if snap.get("dataScope") else 0
        token, _ = agent_context(snap, s[who].id, meta)
        say(f"| {who} | {ds_bytes} | {len(token)} |")
        check(f"{who} 的 Agent Context 小于 16 KiB", True, len(token) < 16384)

    failed = [r for r in results if not r[3]]
    say()
    say(f"## 结果：{len(results) - len(failed)} / {len(results)} 通过")
    for scenario, exp, act, _ in failed:
        say(f"- ❌ {scenario}：预期 {exp}，实际 {act}")
    with open(os.path.join(os.environ["E2E_WORK"], "report.md"), "w") as handle:
        handle.write("\n".join(lines) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(run())
