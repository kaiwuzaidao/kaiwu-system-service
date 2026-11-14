- type: MENU
  name: "${moduleNameJson}"
  path: /${moduleCode}
  component: ${modulePageName}
  sort: 0
  children:
    - type: BUTTON
      name: 查询
      permission: ${permissionPrefix}:list
      sort: 10
    - type: BUTTON
      name: 新增/编辑
      permission: ${permissionPrefix}:save
      sort: 20
    - type: BUTTON
      name: 删除
      permission: ${permissionPrefix}:delete
      sort: 30
