# 项目工厂 v25：统一页面外沿

v24→v25。将桌面上下32px、左右40px（手机16px）的留白从PageContainer提升到公共kaiwu-content-frame。普通成员/角色/文件页面和嵌入的业务组件同样获得边距；PageContainer页头与内容去掉重复水平padding。面包屑放在公共外沿内。

既有业务项目不覆盖、不重新生成、不修改历史ZIP。维护者按diff手动更新app.tsx与theme/ant-pro.less；菜单展开、权限和业务流程不改。System与采购提供独立修复MR。

验证：完整System verify含MySQL/Flyway、生成前后端构建；生成页面浏览器验收检查公共frame左右40、顶部32及PageContainer无重复padding。
