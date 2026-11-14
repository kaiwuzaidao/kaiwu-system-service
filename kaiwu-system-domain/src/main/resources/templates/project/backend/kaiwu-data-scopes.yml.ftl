# 行级数据范围清单（ADR 0044）：同一菜单下不同用户应看到不同行的业务表，在这里声明为「受控资源」。
# 新增表或列表/详情/导出接口时，先回答 Skill kaiwu-data-scope 的第一个问题；不需要隔离的表写进 exempt 并附理由。
#
# 受控资源示例（取消注释并按实际表名修改；表需要 owner_user_id、owner_dept_id 两列，各一个单列索引）：
#   resources:
#     - code: crm:customer              # 模块:资源，与权限前缀一致
#       name: 客户
#       table: crm_customer
#       allowedScopes: [ALL, DEPT_AND_CHILD, DEPT, SELF]   # 必须包含 SELF
#   exempt:
#     - { table: crm_industry, reason: 行业字典，全员共享 }
#
# 清单里不要写默认范围或任何授权信息：未配置的角色一律「仅本人」，授权由平台管理员在角色页完成。
# 使用 kaiwu-data-scope 之前，需要在 pom 中显式加入该依赖，见 .agents/skills/kaiwu-data-scope/SKILL.md。
<#if dataScopeResources?? && dataScopeResources?size gt 0>
# 下列资源由项目工厂按「表同时含 owner_user_id 与 owner_dept_id」自动声明；
# 过滤由 kaiwu-data-scope 拦截器完成，Service 里不要再手写归属条件。
resources:
<#list dataScopeResources as resource>
  - { code: '${resource.code}', name: '${resource.name}', table: ${resource.table}, allowedScopes: [ALL, DEPT_AND_CHILD, DEPT, SELF, CUSTOM_DEPT] }
</#list>
<#else>
resources: []
</#if>
exempt: []
