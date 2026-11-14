"""种子阶段：经平台 API 造出部门树、用户、示例项目、清单（菜单/角色/受控资源/角色范围）、成员与 member:read 凭据。

只用 HTTP，所有请求走 Gateway；同时验证了 D1 的清单同步与 ADR 0042 的配置移交。
"""
import datetime

from e2e_lib import *
import manifest

DEPARTMENTS = [  # (code, name, 父部门 code)
    ("hq", "总部", None),
    ("sales-1", "销售一部", "hq"),
    ("sales-1-east", "销售一部-华东组", "sales-1"),
    ("sales-2", "销售二部", "hq"),
]
# 用户 → (所属部门, 角色)；erin 不是项目成员，用来验证交接时的成员校验。
USERS = {
    "alice": ("sales-1-east", "sales-self"),
    "bob": ("sales-1", "sales-manager"),
    "carol": ("hq", "sales-director"),
    "dave": ("sales-2", "sales-self"),
    "erin": ("sales-2", None),
}


def seed():
    token = login(ADMIN_USER, ADMIN_PASSWORD)
    state = {"departments": {}, "users": {}}
    for code, name, parent in DEPARTMENTS:
        body = {"name": name, "code": code, "sortNo": len(state["departments"]) + 1}
        if parent:
            body["parentId"] = state["departments"][parent]
        state["departments"][code] = ok("POST", f"{GATEWAY}/api/org/departments", body, token, where=f"department {code}")["id"]
    for username, (dept, _role) in USERS.items():
        user = ok(
            "POST", f"{GATEWAY}/api/users", {"username": username, "displayName": username.title(), "password": USER_PASSWORD}, token,
            where=f"user {username}",
        )
        state["users"][username] = user["id"]
        ok("POST", f"{GATEWAY}/api/org/users/{user['id']}/departments", {"departmentIds": [state["departments"][dept]]}, token,
           where=f"departments of {username}")
    project = ok("POST", f"{GATEWAY}/api/projects", {"projectCode": PROJECT_CODE, "projectName": "Demo CRM", "description": "data scope e2e"},
                 token, where="create project")
    pid = state["project_id"] = project["id"]

    files = manifest.files()
    plan = ok("POST", f"{GATEWAY}/api/projects/{pid}/manifest/plan", {"files": files}, token, where="manifest plan")
    state["plan_categories"] = sorted({(c["resource"], c["category"]) for c in plan["changes"]})
    ok("POST", f"{GATEWAY}/api/projects/{pid}/manifest/apply",
       {"files": files, "planHash": plan["planHash"], "applyAccess": True, "deleteKeys": []}, token, where="manifest apply")

    roles = {r["roleCode"]: r["id"] for r in ok("GET", f"{GATEWAY}/api/projects/{pid}/roles", None, token, where="roles")}
    for username, (_dept, role) in USERS.items():
        if role:
            ok("PUT", f"{GATEWAY}/api/projects/{pid}/members/{state['users'][username]}", {"roleIds": [roles[role]], "status": "ACTIVE"},
               token, where=f"member {username}")
    # 签发凭据要求操作者本身是目标项目的有效成员。
    ok("PUT", f"{GATEWAY}/api/projects/{pid}/members/1", {"roleIds": [roles["project-admin"]], "status": "ACTIVE"}, token,
       where="admin membership")
    expires = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    issued = ok("POST", f"{GATEWAY}/api/projects/{pid}/service-credentials",
                {"serviceCode": "democrm", "scopes": ["member:read"], "expiresAt": expires}, token, where="issue credential")
    state["credential_keys"] = sorted(issued.keys())
    state["credential"] = next(v for k, v in issued.items() if isinstance(v, str) and v.startswith("zsch_"))
    state["roles"] = roles
    save_state(state)
    print(json.dumps({k: v for k, v in state.items() if k != "credential"}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    seed()
