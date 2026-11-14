<#noparse>// Ant Design Pro 展示层：使用原生混合布局、页头和组件 Token，不改菜单授权与展开行为。
body {
  margin: 0;
  background: #f5f5f5;
}
.kaiwu-line-icon svg {
  display: block;
}
.ant-pro-layout .ant-pro-layout-content {
  min-width: 0;
  padding: 0;
}
.ant-pro-layout .ant-pro-page-container {
  width: 100%;
  max-width: none;
  margin: 0;
  padding: 0;
}
.ant-pro-layout .ant-pro-page-container .ant-page-header {
  padding: 8px 40px 16px;
  background: transparent;
}
.ant-pro-layout .ant-pro-page-container-children-container {
  padding: 0 40px 32px;
  margin: 0;
}
.ant-pro-layout .ant-page-header-heading-title {
  font-size: 20px;
  font-weight: 600;
  line-height: 32px;
  letter-spacing: normal;
}
.ant-pro-layout .ant-breadcrumb {
  font-size: 14px;
}
.ant-pro-layout .ant-pro-page-container .ant-breadcrumb {
  padding-top: 18px;
}
.ant-pro-layout .ant-card {
  box-shadow:
    0 1px 2px rgba(0, 0, 0, 0.03),
    0 1px 6px -1px rgba(0, 0, 0, 0.02),
    0 2px 4px rgba(0, 0, 0, 0.02);
}
.ant-pro-layout .ant-pro-card .ant-pro-card {
  box-shadow: none;
}
.ant-pro-layout .ant-pro-table-search {
  margin-bottom: 24px;
}
.ant-pro-layout .ant-pro-table,
.ant-pro-layout .ant-pro-card-body {
  min-width: 0;
  max-width: 100%;
}
.ant-pro-layout .ant-table-content {
  overflow-x: auto;
}
.ant-pro-layout .ant-menu-item-selected::before {
  display: none;
}
.ant-pro-layout .ant-menu-item-group-title {
  font-size: 14px;
  font-weight: 400;
  letter-spacing: normal;
}
.kaiwu-sidebar-brand {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.kaiwu-sidebar-brand-mark {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 28px;
  height: 28px;
  color: #1677ff;
  font-size: 18px;
  font-weight: 600;
  border: 2px solid #1677ff;
  border-radius: 6px;
  background: transparent;
}
.kaiwu-sidebar-brand-name {
  color: rgba(0, 0, 0, 0.88);
  font-size: 16px;
  font-weight: 600;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.kaiwu-header-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  min-width: 0;
}
.kaiwu-header-user {
  display: flex;
  align-items: center;
  gap: 4px;
}
.kaiwu-user-menu {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  max-width: 180px;
  border: 0;
  border-radius: 6px;
  padding: 0 8px;
  height: 40px;
  background: transparent;
  cursor: pointer;
}
.kaiwu-user-menu-copy {
  display: flex;
  min-width: 0;
}
.kaiwu-header-actions .kaiwu-user-menu .ant-avatar {
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  line-height: 24px;
  font-size: 12px;
}
.kaiwu-user-menu .ant-typography {
  color: rgba(0, 0, 0, 0.65);
  font-size: 14px;
}
.kaiwu-user-menu:focus-visible,
.kaiwu-project-entry:focus-visible {
  outline: 2px solid #1677ff;
  outline-offset: 2px;
}
.kaiwu-project-context.ant-btn {
  border: 0;
  box-shadow: none;
  background: transparent;
  padding-inline: 8px;
  font-weight: 400;
}
.kaiwu-header-caret {
  color: rgba(0, 0, 0, 0.45);
}
.kaiwu-global-search {
  max-width: 180px;
}
.kaiwu-mode-switch {
  display: flex;
  align-items: center;
}
.kaiwu-mode-switch .ant-btn {
  padding-inline: 8px;
}
.kaiwu-sidebar-footer {
  padding: 16px;
}
.kaiwu-sidebar-assistant strong {
  font-weight: 500;
}
.kaiwu-sidebar-assistant .ant-typography {
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
  margin: 8px 0;
}
.kaiwu-sidebar-assistant-link.ant-btn {
  padding: 0;
}
.kaiwu-dot-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 0 7px;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  color: rgba(0, 0, 0, 0.65);
  font-size: 12px;
  line-height: 20px;
}
.kaiwu-dot-tag.is-green {
  color: #389e0d;
  background: #f6ffed;
  border-color: #b7eb8f;
}
.kaiwu-dot-tag.is-blue {
  color: #0958d9;
  background: #e6f4ff;
  border-color: #91caff;
}
.kaiwu-dot-tag.is-amber {
  color: #d48806;
  background: #fffbe6;
  border-color: #ffe58f;
}
.kaiwu-dot-tag.is-red {
  color: #cf1322;
  background: #fff1f0;
  border-color: #ffa39e;
}
.kaiwu-link-arrow {
  margin-inline-start: 4px;
}
.kaiwu-cell-muted,
.kaiwu-cell-time {
  color: rgba(0, 0, 0, 0.45);
}
.kaiwu-table-head,
.kaiwu-project-cell {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}
.kaiwu-project-cell {
  gap: 8px;
}
.kaiwu-table-tabs {
  min-width: 0;
  flex: 1;
}
.kaiwu-table-tabs .ant-tabs-nav {
  margin-bottom: 0;
}
.kaiwu-tab-count {
  margin-inline-start: 6px;
  font-size: 12px;
}
.kaiwu-table-search {
  max-width: 240px;
}
@media (max-width: 1120px) {
  .kaiwu-header-actions .kaiwu-global-search {
    display: none;
  }
  .kaiwu-mode-switch .ant-btn {
    font-size: 12px;
  }
}
@media (max-width: 767px) {
  .ant-pro-layout .ant-pro-page-container .ant-page-header {
    padding: 8px 16px 16px;
  }
  .ant-pro-layout .ant-pro-page-container-children-container {
    padding: 0 16px 24px;
  }
  .kaiwu-header-actions {
    gap: 4px;
  }
  .kaiwu-header-action-label,
  .kaiwu-user-menu-copy {
    display: none;
  }
  .kaiwu-user-menu {
    max-width: 40px;
    padding-inline: 4px;
  }
  .kaiwu-sidebar-brand-name {
    max-width: 130px;
    font-size: 14px;
  }
  .kaiwu-project-context.ant-btn {
    padding-inline: 4px;
  }
}

@media (max-width: 767px) {
  .kaiwu-mode-switch {
    display: flex;
  }
  .kaiwu-mode-switch .ant-btn {
    width: 28px;
    padding: 0;
  }
  .kaiwu-mode-switch .ant-btn > span:not(.kaiwu-line-icon):not(.anticon) {
    display: none;
  }
  .kaiwu-sidebar-brand-name {
    display: none;
  }
}
@media (max-width: 1120px) {
  .kaiwu-header-actions .kaiwu-global-search {
    display: none !important;
  }
}
@media (max-width: 767px) {
  .kaiwu-table-head {
    flex-wrap: wrap;
    width: 100%;
    gap: 12px;
  }
  .kaiwu-table-tabs {
    flex-basis: 100%;
  }
  .ant-pro-table-list-toolbar-title {
    width: 100%;
    min-width: 0;
  }
  .ant-pro-table-list-toolbar-left {
    min-width: 0;
    max-width: 100%;
  }
}

.kaiwu-sidebar-brand-mark {
  line-height: 1;
}
.kaiwu-sidebar-brand-mark > span {
  line-height: 1;
}
.kaiwu-page-breadcrumb {
  min-height: 48px;
  padding: 24px 40px 0;
  font-size: 14px;
  line-height: 22px;
  color: rgba(0, 0, 0, 0.45);
}
.kaiwu-page-breadcrumb .kaiwu-header-breadcrumb {
  display: flex;
  align-items: center;
  gap: 8px;
}
.kaiwu-page-breadcrumb strong {
  font-weight: 400;
  color: rgba(0, 0, 0, 0.88);
}
.kaiwu-page-breadcrumb + .ant-pro-page-container .ant-breadcrumb {
  display: none;
}
@media (max-width: 767px) {
  .kaiwu-page-breadcrumb {
    padding: 16px 16px 0;
    min-height: 40px;
  }
}

// 页面外沿统一承载留白：普通页面、PageContainer 和 Workflow 包都适用。
.kaiwu-content-frame {
  min-width: 0;
  padding: 32px 40px;
}
.kaiwu-content-frame .ant-pro-page-container .ant-page-header {
  padding: 8px 0 16px;
}
.kaiwu-content-frame .ant-pro-page-container-children-container {
  padding: 0;
}
.kaiwu-content-frame > .kaiwu-page-breadcrumb {
  min-height: 22px;
  margin-bottom: 16px;
  padding: 0;
}
.kaiwu-content-frame > .kaiwu-page-breadcrumb + .ant-pro-page-container .ant-breadcrumb {
  display: none;
}
@media (max-width: 767px) {
  .kaiwu-content-frame {
    padding: 16px;
  }
  .kaiwu-content-frame .ant-pro-page-container .ant-page-header {
    padding: 8px 0 16px;
  }
  .kaiwu-content-frame .ant-pro-page-container-children-container {
    padding: 0;
  }
}
</#noparse>