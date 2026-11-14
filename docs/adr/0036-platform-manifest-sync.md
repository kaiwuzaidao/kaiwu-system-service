# ADR 0036：业务项目的平台资源声明式同步

- 状态：Accepted（plan/apply、project sync、模板清单和移除旧菜单 SQL 均已合入；已有配置移交导出 API，尚无 project export 子命令；生成前端的 check:dict 尚不比对清单）
- 日期：2026-10-28
- 决策范围：`kaiwu-system-service`（含项目工厂模板与 `scripts/kaiwu.sh`）、`kaiwu` 入口仓
- 补充：ADR 0006、ADR 0011、ADR 0014、ADR 0015、ADR 0035

## 背景

ADR 0035 之后，AI 编码工具可以启动平台、生成项目、取回代码并开发业务。剩下的缺口在平台侧：
业务项目需要的字典、参数配置、菜单与按钮权限，存放在平台数据库里，只能通过网页维护：

- 字典：生成项目的 `AGENTS.md` 要求"先到平台字典管理建 dictCode"，只有网页入口。前端
  `check:dict` 只能检查写法，查不到平台上是否真的建了。
- 参数配置：只能在网页"参数配置"页添加。
- 菜单与权限：生成项目带 `sql/menu.sql`，`./kaiwu import-project-menu` 直接写本机 Compose 的
  数据库。test、生产环境没有对应路径；而且绕过了平台的权限校验与操作审计。

结果是 AI 每新增一个状态字段或权限码，都需要人到网页上补一次。代码与平台状态由两条路径维护，
迟早会不一致。

## 决策

### 1. 平台资源随业务仓库版本化

业务后端仓新增 `kaiwu/` 目录，用 YAML 声明本项目需要的平台资源：

```text
order-center-service/kaiwu/
├── dicts.yml     # 字典类型与字典项，含各语言标签
├── configs.yml   # 参数配置的键、类型、默认值、说明
└── menus.yml     # 菜单、页面与按钮权限码
```

```yaml
# dicts.yml
- dictCode: order.order_status
  name: { zh-CN: 订单状态, en-US: Order status }
  items:
    - { value: PENDING_PAYMENT, label: { zh-CN: 待支付, en-US: Pending payment }, color: warning, sort: 10 }
    - { value: PAID,            label: { zh-CN: 已支付, en-US: Paid },            color: success, sort: 20 }

# configs.yml
- key: order.max_items_per_order
  type: NUMBER
  default: "50"
  description: 单笔订单最多商品数

# menus.yml
- key: order
  type: MENU
  name: { zh-CN: 订单管理, en-US: Orders }
  path: /order
  children:
    - { key: order.list,   type: BUTTON, permission: "order:order:list" }
    - { key: order.create, type: BUTTON, permission: "order:order:create" }
```

字典标签与菜单名的多语言文本按 ADR 0015 落为引用式国际化资源，键由平台按项目命名空间生成，
不在清单里手写键名。

### 2. 同步逻辑在服务端，CLI 只负责上传

新增两个项目级接口，由 System 解析清单、计算差异并在一个事务内执行：

| 接口 | 作用 |
|---|---|
| `POST /api/projects/{projectId}/manifest/plan` | 只读。返回将新增、将更新、平台上多出（漂移）的条目，以及本次计划的摘要哈希 |
| `POST /api/projects/{projectId}/manifest/apply` | 必须携带 plan 返回的哈希。哈希覆盖变化条目与清单涉及的平台条目当前状态（配置的当前值除外），计划之后这些条目被改动则返回 409 |

CLI 新增：

```bash
./kaiwu project sync <业务后端仓目录>            # 默认只出计划
./kaiwu project sync <业务后端仓目录> --apply    # 先计划、再执行
```

CLI 打包上传 `kaiwu/*.yml` 与当前 Git 提交号，不在 bash 里解析 YAML。以后 Node 版 CLI 与业务项目
CI 复用同一组接口。

### 3. 同步语义：只增不删，归属清晰

| 资源 | 清单负责 | 平台运营负责 | 同步行为 |
|---|---|---|---|
| 字典类型与字典项 | 编码、值、默认标签、颜色、排序 | 项目内覆盖标签；带国际化资源的标签以资源文本为准 | 不存在则新增；已存在则更新清单负责的字段，带国际化资源的名称只比较引用的 key |
| 参数配置 | 键、类型、说明、默认值、可见性 | **当前值** | 不存在则以默认值新增；已存在时**不覆盖当前值**，只更新类型与说明 |
| 菜单与按钮 | 节点、路由、权限码、默认名称 | 角色授权 | 不存在则新增；平台新建菜单时自动授予内置 `project-admin`，同步本身不改任何角色授权 |
| 国际化资源 | 清单内文本的默认译文 | 平台上的人工改译 | 不存在则新增；已被人工改过的译文不覆盖 |

- **从不删除。** 平台上存在、清单里没有的条目只在计划里列为"漂移"，由人决定是否在网页上删除。
  这与"配置只新增"的规范一致，也避免误删运营人员在网页上加的内容。
- **只作用于本项目范围**，不能写全局字典、全局配置或内置 `system` 项目。
- **其它角色的授权仍由人在网页上分配**：授权属于安全决策，不跟随代码自动扩散。
- 清单禁止声明敏感配置（密钥、Token、密码）。敏感项继续走环境变量或平台加密配置，清单里出现即拒绝。

### 4. 权限与审计

- 调用者必须是该项目的有效项目管理员，且具备 `system:dict:save`、`system:config:save`、`system:i18n:save`、`system:project:menu`；计划会列出缺失的权限，执行时权限不全整体拒绝。CLI 会话权限与本人相同（ADR 0035）。
- `apply` 写一条操作审计，记录清单摘要哈希、Git 提交号、新增与更新的条目数。

### 5. 项目工厂与存量迁移

- 项目工厂模板改为生成 `kaiwu/` 清单，`sql/menu.sql` 与 `import-project-menu` 在迁移完成后移除
  （不长期保留两条路径）。
- 新增 `./kaiwu project export <编码>`：把平台上该项目现有的字典、配置、菜单导出为清单，供存量项目一次性迁移。
- 生成项目的 `AGENTS.md` 改为："新增字典、配置或权限时，修改 `kaiwu/` 清单并执行 `project sync`"；
  前端 `check:dict` 改为同时校验页面引用的 dictCode 是否在清单中声明。

## 被否决方案

- **CLI 在 bash 里直接调用现有的增删改接口**：差异计算与幂等逻辑要在 bash 里重写一遍，不可测；
  多次调用之间失败会留下半同步状态。
- **继续用 SQL 脚本（扩展 `menu.sql`）**：只能直接写数据库，绕过权限校验与审计；各环境数据库访问方式不同，
  test、生产无法统一。
- **全量同步（清单为唯一事实源，多余条目删除）**：会删掉运营人员在网页上合法添加或覆盖的内容；
  参数配置的当前值属于运营，不应被代码回滚。
- **只在平台上维护，不进仓库**：即现状，AI 改不了，代码与平台状态必然漂移。

## 后果

- AI 新增字典、配置或权限，变成修改一个仓库文件并执行一条命令；可评审、可回滚，本机、test、生产走同一套接口。
- 平台新增清单解析、差异计算、两个接口及其测试；项目工厂模板与 web 端 `check:dict` 需要配套调整。
- 在 ADR 0035 的基础上，人只保留三个确认点：授权 CLI、修改系统配置前确认、生产发布前确认。
- 原计划的"移除 GitLab 推送与体检"顺延为 ADR 0037。

## 迁移与回滚

- 新能力不改变现有网页维护方式，两者并存期间网页修改会在下次计划里显示为漂移。
- 回滚时下线两个接口与 `project sync` 命令即可；已同步进平台的数据是普通的字典、配置、菜单记录，无需清理。
