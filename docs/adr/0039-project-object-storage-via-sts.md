# ADR 0039：对象存储由 System 按项目管理，并签发临时凭证

- 状态：Accepted（2026-10-29）
- 日期：2026-10-29
- 决策范围：`kaiwu-system-service`、`kaiwu-system-starter`、`kaiwu-system-web`、项目模板
- 补充：ADR 0003（网关身份）、ADR 0005（受管配置与密钥加密）、ADR 0036（清单同步）

## 背景

Kaiwu 目前没有文件存储能力。竞品分析（`docs/KAIWU-COMPETITIVE-ANALYSIS.md`）已经把它列为
“业务项目需自建”的缺口，并建议以 starter 增强的形式补上，而不是做成平台内置的文件服务。

第一个真实需求来自某业务项目的发票附件。已有一份业务侧实现（
`FileServiceFacade`），它暴露了三个不能照搬的问题：

1. 直接依赖阿里云 OSS SDK，换厂商要改代码；
2. 业务表保存完整 URL，换桶、换域名、换 CDN 都要迁历史数据；
3. 长期 AccessKey 放在每个应用的配置里，每多一个项目就多一份长期密钥。

Kaiwu 已经有“按项目管理配置”的通道：starter 的 `ProjectConfigClient` 使用项目服务凭据，
从 System 拉取“全局作底、项目覆盖”的参数配置。但这条通道明确约定**secret 配置不下发**，
密钥仍走环境变量。如果对象存储也照此处理，桶、前缀等参数可以在平台上管，AccessKey 却仍然要
逐个项目写进部署 Secret，平台既看不到也轮换不了。

我们希望存储配置像 AI 服务商配置一样在 System 后台统一管理，同时不把长期密钥分发给业务项目。

## 决策

### 1. 控制面在 System，数据面在业务项目

- System 负责：存储账号的登记与加密保存、项目与存储的绑定、按项目签发临时凭证、审计。
- 业务项目负责：上传、下载、删除、文件元数据落库、业务权限判断。
- **文件字节不经过 System**。System 不提供通用文件上传、下载或代理接口，避免成为流量瓶颈和
  跨项目数据的汇集点。

### 2. 长期密钥不出 System，项目只拿到临时凭证

- 存储账号的长期 AccessKey/SecretKey 只保存在 System，使用 `KAIWU_CONFIG_ENCRYPTION_KEY`
  做 AES-256-GCM 加密（与 ADR 0005 相同）。浏览器只看到 `secretConfigured`，看不到密文、明文
  或可逆掩码。
- 业务项目通过内部接口 `POST /api/internal/storage/credentials` 取得临时凭证，身份是
  **项目服务凭据**（与调度、项目配置同一份）。该路径遵守现有 `/api/internal` 约定，由网关阻断外部访问。
- System 用 STS AssumeRole 签发凭证，并附加 **session policy**，把权限收窄到
  `{bucket}/{projectCode}/*`。前缀由 System 根据 `sys_project.project_code` 强制生成，
  项目不能自己指定。即使某个项目的服务凭据泄露，影响面也只限于该项目自己的前缀，且会随凭证过期失效。
- 凭证有效期默认 30 分钟，可配置为 15～60 分钟（阿里云 STS 下限 900 秒）。
  System 不保存签发出去的凭证。审计只记录项目、存储、访问模式和过期时间，不记录凭证内容，日志一律脱敏。
- **不提供长期密钥下发**。“secret 配置不下发”这条规则保持不变，本 ADR 不构成例外。

### 3. 支持的存储类型

| 类型 | 签发方式 | 第一期 |
| --- | --- | --- |
| `ALIYUN_OSS` | 阿里云 STS AssumeRole + session policy | 是 |
| `S3_COMPATIBLE_STS` | S3 兼容的 STS AssumeRole（MinIO 等） | 是，同时作为集成测试后端 |
| 其他（腾讯云 COS、华为 OBS 等） | 在 System 实现 `StorageCredentialIssuer` 接入 | 按需求加 |

- starter 的数据面统一走 S3 协议（AWS SDK v2）。阿里云 OSS 必须使用 virtual-hosted 风格，
  并关闭 SDK 默认附加的请求校验和（`requestChecksumCalculation=WHEN_REQUIRED`），否则部分兼容
  实现会拒绝请求。两项都由凭证响应里的厂商类型自动决定，项目不需要配置。
- 不支持 STS 的存储不接入本通道。这类项目回到现有方式：静态密钥走环境变量或 K8s Secret，
  starter 以 `static` 模式读取。

### 4. 数据模型（System）

- `sys_storage_config`：存储账号。字段包括编码、名称、类型、endpoint、region、STS endpoint、
  角色 ARN、桶、加密后的签发用密钥、凭证有效期、状态。
- `sys_project_storage`：项目绑定。字段包括项目、存储名（项目内唯一，默认 `default`）、
  引用的存储账号、单文件大小上限、允许的 Content-Type、状态（`ACTIVE` / `READ_ONLY` / `DISABLED`）。
- 签发凭证时按访问模式区分：`READ_ONLY` 绑定只签发读权限；`DISABLED` 不签发。
- 被绑定引用的存储账号不可删除，只能停用；有历史文件的绑定不可删除，只能转为 `READ_ONLY`。

### 5. 切换存储不迁移历史文件

- 业务文件记录保存 `storage_ref`（签发响应返回的绑定标识）和 `object_key`，**不保存完整 URL**。
- 写入始终使用该存储名当前 `ACTIVE` 的绑定。管理员把项目切换到新的存储账号时，System 新建一条
  `ACTIVE` 绑定，旧绑定转为 `READ_ONLY`。
- 读取按记录里的 `storage_ref` 请求凭证，所以旧文件在切换后仍然可读，不需要一次性迁移。
  是否搬迁历史文件由运维单独决定，不属于本能力。

### 6. Starter 能力

- 提供 `ObjectStorage` 接口：`put` / `get` / `delete` / `exists` / `presignGet` / `presignPut`。
- 凭证提供方式：`kaiwu`（向 System 申请临时凭证）、`static`（环境变量静态密钥）、
  `local`（本地磁盘，用于开发与体验版）。AWS SDK 为可选依赖，未引入时不装配 S3 实现。
- **凭证获取不在业务请求路径上**，遵守“正常业务请求不得由 Starter 回调 System”。
  一次申请会返回本项目全部 `ACTIVE` 与 `READ_ONLY` 绑定的凭证；starter 在启动时预取，之后由
  后台线程续签。业务请求只读内存缓存，缓存里没有对应凭证时直接失败，不在请求内同步调用 System。
- 临时凭证缓存在内存中，剩余有效期不足 20% 时提前续签。System 不可达时
  继续使用未过期的凭证；过期后存储操作明确失败，但**不阻断应用启动**，与 `ProjectConfigClient`
  的降级原则一致。
- 预签名 URL 的有效期不得超过签名所用临时凭证的剩余有效期。starter 会把请求的有效期截断到
  凭证剩余时间。
- object key 由 starter 生成：`{projectCode}/{业务类型}/{yyyy/MM}/{uuid}.{扩展名}`，
  不使用用户上传的原始文件名。原始文件名只作为元数据保存。

### 7. 上传方式

- 小文件：由业务后端接收后写入存储，后端负责类型和大小校验。
- 大文件或移动端：业务后端签发预签名 PUT，前端直接上传，完成后调用业务确认接口落库。
  确认接口必须用 `exists` 和对象元数据复核大小与类型，不能只信任前端的回报。
- 桶默认私有，读取一律使用预签名 GET。是否允许公共读，由存储账号单独声明，默认关闭。

### 8. 管理与权限

- 菜单和权限码登记到内置 system 项目：`system:storage:list|save|test`，项目绑定沿用同一组权限。
  第一期只开放给平台管理员，项目管理员不能修改绑定，也不能查看账号信息。
- “测试连接”由 System 实际执行一次 AssumeRole，并用签出的凭证在保留前缀 `_kaiwu-probe/` 下写入、删除一个探测对象，不需要业务项目参与。会话策略只授予对象级权限，HeadBucket 这类桶级操作会被拒绝，所以不用它探测。
- System 访问 STS 与存储的出站请求必须命中 `kaiwu.storage.allowed-hosts` 主机名白名单，白名单为空时一律拒绝（fail-closed），不接受 IP 字面量、不跟随重定向。与 AI 服务商不同，出站代理可选：存储常部署在内网（如 MinIO），强制代理会让内网部署无法使用。

## 被否决的方案

- **只用参数配置，密钥走环境变量**：零新机制，但平台无法统一轮换和审计密钥，每个项目都持有长期密钥。
  该方式仍作为 `static` 模式保留给不支持 STS 的存储。
- **System 加密保存长期密钥并下发给项目**：后台可以全管，但长期密钥会出现在每个项目的进程里。
  System 一旦被攻破，所有项目的长期密钥会一起泄露，而且会推翻“secret 不下发”的规则。
- **各业务项目在自己的库里维护存储配置**：Kaiwu 已经有按项目管理配置的通道，再让每个项目重复一套
  配置表和页面，与“平台统一运营入口”的方向相反。
- **System 提供统一文件服务，代理上传和下载**：文件流量和所有项目的数据都会汇集到 System，
  System 也会因此成为所有项目上传链路的单点。

## 后果

- System 新增两张表和一个内部接口；按 Flyway 前向迁移提交（`database.flyway-forward-only`）。
- System 成为对象存储的凭证中心：System 不可用超过凭证有效期时，所有接入项目的存储操作都会失败。
  有效期上限与续签提前量是这一风险的主要调节手段。
- 体验版默认使用 `local`。体验版迁到开发版时，迁移工具必须连同本地文件一起迁走，否则附件会丢失。
- System 侧实现合入时，在 `docs/kaiwu-constraints.json` 登记以下 MUST 约束，并附上对应的测试作为执行手段：
  长期存储密钥不离开 System；业务记录不保存完整对象 URL。
- starter 代码与示例会随开源同步导出，其中不得出现内部 endpoint、桶名或业务项目名。

## 落地顺序

1. System：两张表、加密保存、`ALIYUN_OSS` 与 `S3_COMPATIBLE_STS` 签发器、内部接口、管理页面与测试连接。
2. starter：`ObjectStorage`、三种凭证提供方式、凭证缓存与续签；以 MinIO（Testcontainers）做集成测试。
3. web-starter：上传组件，同时支持后端中转和预签名直传。
4. 首个业务项目的发票附件作为第一个接入方，验证接口；之后再决定是否把存储能力写进项目模板。
