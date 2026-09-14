{
  "catalogVersion": "1",
  "constraints": [
    {"id":"security.secrets","level":"MUST","scope":"repository","rationale":"凭据不得进入源码、日志或制品。","enforcement":"gitleaks","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"security.supply-chain","level":"MUST","scope":"repository-ci","rationale":"高危依赖与镜像漏洞必须在交付前暴露，并产出可追溯 SBOM。","enforcement":"Trivy filesystem and image scan plus CycloneDX SBOM","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"logging.no-sensitive-data","level":"MUST","scope":"runtime-logs","rationale":"Gitleaks 只扫静态源码，运行时日志同样会把凭据和敏感个人信息带进采集链路。","enforcement":"SensitiveLoggingConventionTest","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"query.bounded-result","level":"MUST","scope":"externally-parameterized-queries","rationale":"结果集整体驻留内存，未设上限的 size 等于允许调用方要求全表；超限拒绝而不静默截断。","enforcement":"PageBounds and BoundedQueryConventionTest","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"query.explicit-projection","level":"MUST","scope":"orm-business-queries","rationale":"显式字段列表避免无意读取、映射和传输未使用或敏感列。","enforcement":"SqlProjectionConventionTest covering Java and mapper XML","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"auth.gateway-context","level":"MUST","scope":"backend","rationale":"业务服务只信任已验证的 Gateway Context。","enforcement":"starter tests","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"auth.resource-ownership","level":"MUST","scope":"generated-resource-crud","rationale":"接口权限只证明可以使用功能，不能证明调用方有权操作目标记录。","enforcement":"explicit PROJECT_WIDE or OWNER_ONLY policy plus authorization negative tests","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"permission.three-source-consistency","level":"MUST","scope":"backend-frontend-menu-sql","rationale":"权限注解、按钮和菜单 seed 必须同码。","enforcement":"permission checks","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"database.flyway-forward-only","level":"MUST","scope":"backend-migrations","rationale":"已发布迁移不可修改，结构变化只能前向追加。","enforcement":"Flyway and review","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"api.backward-compatibility","level":"MUST","scope":"backend-api","rationale":"已发布接口路径和字段不能被无意删除或改型。","enforcement":"ApiContractTest","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"dictionary.user-visible-values","level":"WARN","scope":"user-visible-configurable-enums","rationale":"需要翻译或运营配置的显示值使用受管字典。","enforcement":"check:dict","waivable":true,"reviewAfter":"2027-02-12"},
    {"id":"tests.behavior-baseline","level":"WARN","scope":"changed-business-behavior","rationale":"测试保护领域行为、权限反例和接口契约，不机械追求类名覆盖。","enforcement":"test warning and review","waivable":true,"reviewAfter":"2026-11-12"},
    {"id":"runtime.managed-threads","level":"MUST","scope":"java-production-threading","rationale":"线程与线程池必须具备可见的容量、命名、拒绝策略和生命周期。","enforcement":"ManagedThreadConventionTest","waivable":false,"reviewAfter":"2027-02-12"},
    {"id":"java.high-signal-conventions","level":"WARN","scope":"java-production-code-and-business-sql","rationale":"选择可由 JDK 21 稳定执行的阿里规范高信号规则。","enforcement":"repository convention tests, Spotless and review","waivable":true,"reviewAfter":"2026-11-12"},
    {"id":"runtime.managed-config","level":"DEFAULT","scope":"runtime-changeable-settings","rationale":"平台配置是运行期可变参数的默认入口，领域不变量可以版本化。","enforcement":"generated default","waivable":true,"reviewAfter":"2027-02-12"},
    {"id":"scheduler.managed-control-plane","level":"DEFAULT","scope":"distributed-scheduled-jobs","rationale":"Starter 是分布式调度默认方案，本地方案需自行承担协调责任。","enforcement":"generated default","waivable":true,"reviewAfter":"2027-02-12"},
    {"id":"i18n.enabled-locales","level":"WARN","scope":"declared-supported-locales","rationale":"只对项目明确启用的语言要求资源完整。","enforcement":"manifest and review","waivable":true,"reviewAfter":"2026-11-12"},
    {"id":"format.deterministic","level":"DEFAULT","scope":"java-typescript","rationale":"自动格式化减少不同人员和模型造成的排版漂移。","enforcement":"Spotless and Prettier","waivable":true,"reviewAfter":"2027-02-12"}
  ]
}
