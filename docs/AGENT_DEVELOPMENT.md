# 使用 AI Agent 开发 Kaiwu

Kaiwu 在 `kaiwu-system-service` 中维护一份通用开发 Skill。所有工具共享相同的初始化、启动、
仓库路由、安全边界和验证流程。接入方式分两层：**`AGENTS.md` 兜底 + 每工具适配层按需生成**。

## 1. 支持情况

**第一层：读 `AGENTS.md` 的工具，零配置。** 根目录 `AGENTS.md` 顶部指向核心 Skill，
Codex 等遵循该约定的工具打开仓库即可，不需要任何额外文件。

**第二层：只认自己私有规则路径的工具，按需生成一层薄转发。**

```bash
.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh adapters list
.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh adapters add cursor
```

| 工具 | 生成的文件 | 调用方式 |
| --- | --- | --- |
| Codex | 无需（走 `AGENTS.md`） | `$kaiwu-development` 或自然语言触发 |
| Claude Code | `.claude/skills/kaiwu-development/SKILL.md` | `/kaiwu-development` 或自然语言触发 |
| CodeBuddy | `.codebuddy/skills/kaiwu-development/SKILL.md` | `/kaiwu-development` 或自然语言触发 |
| Cursor | `.cursor/rules/kaiwu-development.mdc` | `@kaiwu-development` 或相关任务自动选择 |
| Trae | `.trae/rules/kaiwu-development.md` | 打开项目后用自然语言提出相关任务 |
| 通义灵码 | `.lingma/rules/kaiwu-development.md` | 打开项目后用自然语言提出相关任务 |
| 文心快码 Comate | `.comate/rules/kaiwu-development.mdr` | `#kaiwu-development` 或在规则面板启用 |

**仓库里默认只有你在用的那个。** 生成一次是一秒，而一个没人用的适配文件在根目录上多占
一个点目录，翻找成本天天付、收益要等到真换工具那天才兑现——所以正确的默认是不存在。
不再用了就 `adapters remove <tool>`，别留着"万一以后要用"。

用 `adapters remove` 只删这一个转发文件，目录里若还有与本适配层无关的文件（如
`.claude/settings.json`）会原样保留。

通义灵码的生效方式由 IDE 规则面板设置，文件本身不表达；首次使用时按需选择「始终生效」
或「模型自动决策」。文心快码与 Cursor 的 `alwaysApply: false` 一致——默认手动选用，
避免与其它规则争抢上下文。

### 为什么不让工具首次打开项目时自行生成

工具只会自动读**它自己认识的路径**。那个路径不存在时它什么都读不到——包括"去生成适配层"
这条指令本身（README 不是入口，没有任何 agent 工具把它当指令自动加载）。结果是这个方案
**只在不需要它的地方生效**：能读到引导指令的工具本来就已经拿到全部流程，真正需要转发的
工具永远触发不了。

即便绕过引导问题，让模型即兴生成也会弄丢适配层唯一的价值：内容不再逐字确定，得逐个 review
才知道写了什么；首次打开就往仓库写文件，与本仓「未经明确授权不得覆盖已有目录」冲突；
每次 clone 和每条 CI 都会冒出未跟踪文件。

所以是**确定性生成器**，不是 AI 自举：模板固定、输出逐字可预期、可 review、可回滚，
并由 `adapters check` 守住。

## 2. 第一次使用

先克隆唯一入口仓库：

```bash
git clone https://github.com/<你的组织>/kaiwu-system-service.git
cd kaiwu-system-service
```

用任一支持的 Agent 工具打开该目录，然后提出：

```text
初始化并启动 Kaiwu，启动成功后告诉我访问地址和下一步体验路径。
```

Agent 会按顺序：

1. 检查 Git、Docker、Compose、OpenSSL 和 curl；
2. 根据 System 仓库 HTTPS/SSH remote 推导并克隆缺少的三个同组织仓库；
3. 拒绝覆盖已有的普通目录或用户改动；
4. 在四仓父目录的 `.kaiwu/dev.env` 生成本地开发密钥；
5. 构建并启动 MySQL、Redis、Flyway、System、Gateway 和 Web；
6. 等待 Gateway 健康检查通过；
7. 输出 `http://127.0.0.1:8000` 和首次登录信息。

初始化完成后，使用多仓编辑器的用户可以打开 `kaiwu.code-workspace`，四个独立仓库会显示在
同一个工作区中。各仓仍保持独立 Git 历史、分支和提交。

也可以不启动，只让 Agent 准备工作区：

```text
使用 Kaiwu Development Skill 初始化四仓工作区，但暂时不要启动容器。
```

## 3. 基于项目开发

直接描述需求，例如：

```text
基于 Kaiwu 增加用户头像上传。先判断应该修改哪些仓库，说明边界后实现并验证。
```

Skill 要求 Agent：

- 先读取架构、当前仓库的 `AGENTS.md` 和 `CLAUDE.md`；
- 将需求路由给真正拥有该行为的仓库；
- 检查四个独立 Git 工作区并保留已有改动；
- 不在受保护分支直接实现；
- 根据改动运行 Java、前端、Compose、Shell 或 Helm 的对应验证；
- 多仓分别提交并报告每个提交；
- 未经明确要求不 push、不部署、不删除数据、不轮换密钥。

## 4. 可直接运行的辅助命令

Agent 调用的确定性入口是：

```bash
skill=.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh

bash "$skill" doctor
bash "$skill" init
bash "$skill" up
bash "$skill" status
bash "$skill" context
bash "$skill" verify auto
```

验证也可指定 `starter`、`system`、`gateway`、`web` 或 `all`。Java 源码验证需要 JDK 21；
只使用 Docker 快速体验时不要求本机安装 JDK、Maven、Node.js 或 pnpm。

## 5. 安全边界

Skill 不会因为“代码已经完成”就自动执行以下操作：

- push 或创建合并请求；
- 部署 Kubernetes；
- 执行 `reset`、删除 Docker volume 或清空数据库；
- 覆盖已有目录；
- 输出 `.kaiwu/dev.env`、Nacos 凭据、私钥或 Kubernetes Secret。

这些操作必须由用户在当前任务中明确授权。

## 6. 接入新工具

Kaiwu 承诺「可以更换 AI，不需要更换架构」。兑现方式是**一份事实源 + 薄转发**，
不是为每种工具各写一套协议。

表里已有的工具，一条命令即可：

```bash
.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh adapters add trae
```

表里没有的工具，在 `kaiwu-agent.sh` 的 `adapter_label` / `adapter_path` / `adapter_format`
三个 `case` 里各加一行，然后同样用 `adapters add` 生成——**不要手写适配文件**。已有的三种
格式（`skill`、`rule-frontmatter`、`rule-plain`）覆盖了目前见到的全部约定；真遇到第四种，
在 `render_adapter` 里加一个分支，正文仍然共用。最后在上面的支持情况表里加一行。

**不要**把初始化步骤、构建命令、仓库路由或安全边界复制进适配文件——
复制一次就产生第二份会漂移的协议，而适配层的全部价值就在于它薄到不可能漂移。
这条由门禁守着，不靠自觉：

```bash
.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh adapters check
```

它只校验**已存在**的适配文件与模板逐字一致（一个都没有也是合法状态），
偏离就红，并提示用 `adapters add` 重新生成。

模型能力差异（代码风格、指令遵循质量）不靠适配文件解决，而由机器可读约束、确定性格式化
和风险分级门禁共同收敛。`docs/kaiwu-constraints.json` 区分 `MUST`、`WARN`、`DEFAULT`：
安全边界与生成完整性必须阻断；同名测试骨架等启发式规则默认告警；格式与运行方式提供默认值，
但允许项目在有记录、可过期的 waiver 内调整。这样既限制模型漂移，也不把合理工程取舍误判为失败。
