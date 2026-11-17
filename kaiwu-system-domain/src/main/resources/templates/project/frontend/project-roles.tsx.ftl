<#noparse>import { PlusOutlined, ReloadOutlined } from '@ant-design/icons';
import { Alert, App, Button, Form, Input, Modal, Popconfirm, Space, Table, Tag, Tree } from 'antd';
import type { DataNode } from 'antd/es/tree';
import { useCallback, useEffect, useMemo, useState } from 'react';
import PermissionButton from '@/components/PermissionButton';
import { useProjectAccess } from '@/kaiwu';
import {
  createAccessRole,
  deleteAccessRole,
  grantAccessRoleMenus,
  queryAccessMenus,
  queryAccessRoles,
  updateAccessRole,
  updateAccessRoleStatus,
  type AccessMenu,
  type AccessRole,
} from '@/services/projectAccess';

type RoleForm = { roleCode?: string; roleName: string; description?: string };

function toTree(menus: AccessMenu[]): DataNode[] {
  return menus.map((menu) => ({
    key: menu.id,
    title: menu.permissionCode ? `${menu.menuName}（${menu.permissionCode}）` : menu.menuName,
    children: menu.children ? toTree(menu.children) : undefined,
  }));
}

/**
 * 角色授权：新增与编辑角色、启停、给角色勾选本项目的菜单与按钮。
 * 内置的项目管理员角色不可修改，由平台拒绝；这里只负责展示与提交。
 */
export default function ProjectRolesPage() {
  const { message } = App.useApp();
  const { projectId, permissions } = useProjectAccess();
  const [roles, setRoles] = useState<AccessRole[]>([]);
  const [menus, setMenus] = useState<AccessMenu[]>([]);
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState<AccessRole>();
  const [formOpen, setFormOpen] = useState(false);
  const [granting, setGranting] = useState<AccessRole>();
  const [checked, setChecked] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [form] = Form.useForm<RoleForm>();
  const treeData = useMemo(() => toTree(menus), [menus]);

  const load = useCallback(async () => {
    if (!projectId || !permissions.has('access:role:list')) return;
    setLoading(true);
    try {
      const [roleRows, menuRows] = await Promise.all([
        queryAccessRoles(projectId),
        queryAccessMenus(projectId),
      ]);
      setRoles(roleRows);
      setMenus(menuRows);
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
    } finally {
      setLoading(false);
    }
  }, [message, permissions, projectId]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!permissions.has('access:role:list')) {
    return <Alert type="warning" showIcon message="没有查看角色授权的权限" />;
  }

  const run = async (action: () => Promise<unknown>, success: string) => {
    try {
      await action();
      void message.success(success);
      await load();
      return true;
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
      return false;
    }
  };

  const openCreate = () => {
    setEditing(undefined);
    form.resetFields();
    setFormOpen(true);
  };

  const openEdit = (role: AccessRole) => {
    setEditing(role);
    form.setFieldsValue({
      roleCode: role.roleCode,
      roleName: role.roleName,
      description: role.description,
    });
    setFormOpen(true);
  };

  const submitRole = async () => {
    const values = await form.validateFields();
    setSaving(true);
    const ok = await run(
      () =>
        editing
          ? updateAccessRole(projectId, editing.id, {
              roleName: values.roleName,
              description: values.description,
            })
          : createAccessRole(projectId, {
              roleCode: values.roleCode ?? '',
              roleName: values.roleName,
              description: values.description,
            }),
      '已保存',
    );
    setSaving(false);
    if (ok) setFormOpen(false);
  };

  const openGrant = (role: AccessRole) => {
    setGranting(role);
    setChecked(role.menuIds);
  };

  const submitGrant = async () => {
    if (!granting) return;
    setSaving(true);
    const ok = await run(() => grantAccessRoleMenus(projectId, granting.id, checked), '授权已保存');
    setSaving(false);
    if (ok) setGranting(undefined);
  };

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <PermissionButton
          type="primary"
          icon={<PlusOutlined />}
          permission="access:role:save"
          onClick={openCreate}
        >
          新增角色
        </PermissionButton>
        <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
          刷新
        </Button>
      </Space>
      <Table<AccessRole>
        rowKey="id"
        loading={loading}
        dataSource={roles}
        pagination={false}
        columns={[
          {
            title: '角色',
            render: (_, role) => (
              <Space direction="vertical" size={0}>
                <span>
                  {role.roleName}
                  {role.builtIn && (
                    <Tag style={{ marginLeft: 8 }} color="blue">
                      内置
                    </Tag>
                  )}
                </span>
                <span style={{ fontSize: 12, color: '#8c8c8c' }}>{role.roleCode}</span>
              </Space>
            ),
          },
          { title: '说明', dataIndex: 'description', ellipsis: true },
          {
            title: '状态',
            dataIndex: 'status',
            width: 90,
            render: (value: string) =>
              value === 'ACTIVE' ? <Tag color="success">启用</Tag> : <Tag>停用</Tag>,
          },
          {
            title: '操作',
            width: 300,
            render: (_, role) => (
              <Space>
                <PermissionButton
                  type="link"
                  permission="access:role:grant"
                  disabled={role.builtIn}
                  onClick={() => openGrant(role)}
                >
                  授权
                </PermissionButton>
                <PermissionButton
                  type="link"
                  permission="access:role:save"
                  disabled={role.builtIn}
                  onClick={() => openEdit(role)}
                >
                  编辑
                </PermissionButton>
                <PermissionButton
                  type="link"
                  permission="access:role:save"
                  disabled={role.builtIn}
                  onClick={() =>
                    void run(
                      () =>
                        updateAccessRoleStatus(
                          projectId,
                          role.id,
                          role.status === 'ACTIVE' ? 'DISABLED' : 'ACTIVE',
                        ),
                      '状态已更新',
                    )
                  }
                >
                  {role.status === 'ACTIVE' ? '停用' : '启用'}
                </PermissionButton>
                <Popconfirm
                  title="确认删除该角色？仍有成员使用时会被拒绝。"
                  onConfirm={() => void run(() => deleteAccessRole(projectId, role.id), '已删除')}
                >
                  <PermissionButton
                    type="link"
                    danger
                    permission="access:role:delete"
                    disabled={role.builtIn}
                  >
                    删除
                  </PermissionButton>
                </Popconfirm>
              </Space>
            ),
          },
        ]}
      />
      <Modal
        title={editing ? '编辑角色' : '新增角色'}
        open={formOpen}
        confirmLoading={saving}
        onOk={() => void submitRole()}
        onCancel={() => setFormOpen(false)}
        destroyOnHidden
      >
        <Form form={form} layout="vertical">
          <Form.Item
            name="roleCode"
            label="角色编码"
            rules={[
              { required: !editing, message: '请输入角色编码' },
              { pattern: /^[a-z][a-z0-9-]{1,63}$/, message: '只能包含小写字母、数字和连字符' },
            ]}
          >
            <Input disabled={Boolean(editing)} placeholder="例如 order-viewer" />
          </Form.Item>
          <Form.Item
            name="roleName"
            label="角色名称"
            rules={[{ required: true, message: '请输入角色名称' }]}
          >
            <Input maxLength={100} />
          </Form.Item>
          <Form.Item name="description" label="说明">
            <Input.TextArea rows={3} maxLength={255} />
          </Form.Item>
        </Form>
      </Modal>
      <Modal
        title={granting ? `授权：${granting.roleName}` : '授权'}
        open={Boolean(granting)}
        confirmLoading={saving}
        onOk={() => void submitGrant()}
        onCancel={() => setGranting(undefined)}
        width={560}
        destroyOnHidden
      >
        <Tree
          checkable
          checkStrictly
          defaultExpandAll
          treeData={treeData}
          checkedKeys={checked}
          onCheck={(keys) => setChecked((Array.isArray(keys) ? keys : keys.checked).map(String))}
        />
      </Modal>
    </>
  );
}
</#noparse>
