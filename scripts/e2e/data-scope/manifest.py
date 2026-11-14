"""示例项目 demo-crm 的清单（与业务仓 kaiwu/ 目录同格式），经 manifest plan/apply 一次写入平台。"""

PERMS = ["list", "create", "update", "delete", "export", "transfer"]


def _button(action):
    return f"    - {{ key: customer.{action}, type: BUTTON, permission: 'democrm:customer:{action}' }}\n"


MENUS = (
    "- key: customer\n  type: MENU\n  name: { zh-CN: 客户 }\n  path: /customer\n  children:\n"
    + "".join(_button(action) for action in PERMS)
)

DATA_SCOPES = """resources:
  - code: 'democrm:customer'
    name: 客户
    table: demo_customer
    allowedScopes: [ALL, DEPT_AND_CHILD, DEPT, SELF, CUSTOM_DEPT]
"""


def roles_yaml():
    base = ["list", "create", "update", "delete", "export"]

    def perms(items):
        return "[" + ", ".join(f"'democrm:customer:{p}'" for p in items) + "]"

    return (
        "- roleCode: sales-self\n  name: 销售\n  permissions: " + perms(base) + "\n"
        "- roleCode: sales-manager\n  name: 销售经理\n  permissions: " + perms(base + ["transfer"]) + "\n"
        "  dataScopes:\n    - { resource: 'democrm:customer', scope: DEPT_AND_CHILD }\n"
        "- roleCode: sales-director\n  name: 销售总监\n  permissions: " + perms(base + ["transfer"]) + "\n"
        "  dataScopes:\n    - { resource: 'democrm:customer', scope: ALL }\n"
    )


def files():
    return {"menus.yml": MENUS, "data-scopes.yml": DATA_SCOPES, "roles.yml": roles_yaml()}
