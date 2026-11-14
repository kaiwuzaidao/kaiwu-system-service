# 项目工厂 v24：Ant Design Pro 展示规格

v23→v24，只调整生成前端展示。使用原生 ProLayout light/mix/Fluid、56px 顶栏、256px 侧栏、40px 正文留白、20px 页标题、8px 卡片圆角和默认 Ant Design 控件比例。主页流式展开，面包屑在正文上方。菜单默认展开/group、授权结果过滤与待办行为不变。

公共主题由 tokens.ts、antd.ts、layout.ts、ant-pro.less 构成，生成模板与 System/采购实测文件一致。既有项目不重新生成、不覆盖历史 ZIP；由维护者在业务仓按本 MR 手工迁移 app、RightContent、global.less、theme 与首页展示样式。采购示例另有独立 MR，其他生成项目本轮不修改。

完整 System verify（含 MySQL/Flyway）、生成器 12 项、生成后端/前端与空模板真实构建、verify-generated-home.mjs 浏览器检查通过。参考官方预览 https://preview.pro.ant.design/dashboard/workplace/ 的 CSS 实测规格，保留业务内容和 Kaiwu 品牌；非完整演示页数据复制，不声称不同业务内容 PNG 零差异。

v21 通知模板修复 !207 是独立未合入项，本批不取代它；合入时保持模板版本唯一且保留其他已批准修复。未读 Secret，未合入或部署。
