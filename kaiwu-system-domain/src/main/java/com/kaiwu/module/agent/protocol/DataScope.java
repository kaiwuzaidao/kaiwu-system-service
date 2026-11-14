package com.kaiwu.module.agent.protocol;

/**
 * 能力的数据范围，用于没有 {@code projectId} 参数的能力（ADR 0030 第 4 条）。
 *
 * <p>必须显式声明：默认成 {@code ALL} 会让一条忘记标注的能力直接越过项目边界。
 * 曾经还有 {@code ORG}（按组织范围），因当时 {@code KaiwuContext} 不含组织字段、平台也没有可执行的数据权限实现而删除——
 * 声明一个无法执行的安全策略比不声明更危险。ADR 0044 引入项目数据范围之后，该语义由 {@link #ROLE_SCOPED}
 * 以可执行的形式承接：范围来自调用者的角色配置，由业务服务在 SQL 层强制。</p>
 */
public enum DataScope {

    /** 全平台可见，需要单独论证。 */
    ALL,

    /** 仅调用者是有效成员的项目。 */
    MEMBER_PROJECTS,

    /** 仅调用者自己的数据。 */
    SELF,

    /**
     * 项目内按调用者角色的数据范围（ADR 0044）。
     *
     * <p>读取或写入受控资源的能力必须声明它而不是 {@link #ALL}：{@code ALL} 表示项目内全部数据，
     * 声明它会让使用者误以为不受行级范围约束。</p>
     */
    ROLE_SCOPED
}
