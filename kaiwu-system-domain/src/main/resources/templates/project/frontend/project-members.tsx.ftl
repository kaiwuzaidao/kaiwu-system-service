<#noparse>import { PlusOutlined, ReloadOutlined } from '@ant-design/icons';
import { Alert, App, Button, Form, Modal, Popconfirm, Select, Space, Table, Tag } from 'antd';
import { useCallback, useEffect, useMemo, useState } from 'react';
import PermissionButton from '@/components/PermissionButton';
import { useProjectAccess } from '@/providers/ProjectAccessProvider';
import {
  deleteAccessMember,
  queryAccessMembers,
  queryAccessRoles,
  saveAccessMember,
  searchAccessCandidates,
  type AccessCandidate,
  type AccessMember,
  type AccessRole,
} from '@/services/projectAccess';

type FormValues = {
  userId?: string;
  roleIds: string[];
  status: 'ACTIVE' | 'DISABLED';
};

const STATUS_OPTIONS = [
  { value: 'ACTIVE', label: '启用' },
  { value: 'DISABLED', label: '停用' },
];

/**
 * 项目成员：添加、编辑角色与启停、移除。由平台按本项目里的 access:member:* 权限把关；
 * 创建人必须保持启用并保留项目管理员角色，平台会拒绝违反这条的请求。
 */
export default function ProjectMembersPage() {
  const { message } = App.useApp();
  const { projectId, permissions } = useProjectAccess();
  const [members, setMembers] = useState<AccessMember[]>([]);
  const [roles, setRoles] = useState<AccessRole[]>([]);
  const [candidates, setCandidates] = useState<AccessCandidate[]>([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<AccessMember>();
  const [saving, setSaving] = useState(false);
  const [form] = Form.useForm<FormValues>();

  const roleNames = useMemo(() => new Map(roles.map((role) => [role.id, role.roleName])), [roles]);
  const activeRoleOptions = roles
    .filter((role) => role.status === 'ACTIVE')
    .map((role) => ({ value: role.id, label: role.roleName }));

  const load = useCallback(async () => {
    if (!projectId || !permissions.has('access:member:list')) return;
    setLoading(true);
    try {
      const [memberRows, roleRows] = await Promise.all([
        queryAccessMembers(projectId),
        permissions.has('access:role:list') ? queryAccessRoles(projectId) : Promise.resolve([]),
      ]);
      setMembers(memberRows);
      setRoles(roleRows);
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
    } finally {
      setLoading(false);
    }
  }, [message, permissions, projectId]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!permissions.has('access:member:list')) {
    return <Alert type="warning" showIcon message="没有查看项目成员的权限" />;
  }

  const openCreate = () => {
    setEditing(undefined);
    setCandidates([]);
    form.resetFields();
    form.setFieldsValue({ roleIds: [], status: 'ACTIVE' });
    setOpen(true);
  };

  const openEdit = (member: AccessMember) => {
    setEditing(member);
    form.setFieldsValue({
      userId: member.userId,
      roleIds: member.roleIds,
      status: member.status,
    });
    setOpen(true);
  };

  const submit = async () => {
    const values = await form.validateFields();
    const userId = editing?.userId ?? values.userId;
    if (!userId) return;
    setSaving(true);
    try {
      await saveAccessMember(projectId, userId, {
        roleIds: values.roleIds,
        status: values.status,
      });
      void message.success('已保存');
      setOpen(false);
      await load();
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <PermissionButton
          type="primary"
          icon={<PlusOutlined />}
          permission="access:member:save"
          onClick={openCreate}
        >
          添加成员
        </PermissionButton>
        <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
          刷新
        </Button>
      </Space>
      <Table<AccessMember>
        rowKey="userId"
        loading={loading}
        dataSource={members}
        pagination={false}
        columns={[
          {
            title: '成员',
            render: (_, member) => (
              <Space direction="vertical" size={0}>
                <span>{member.displayName || member.username}</span>
                <span style={{ fontSize: 12, color: '#8c8c8c' }}>{member.username}</span>
              </Space>
            ),
          },
          {
            title: '角色',
            render: (_, member) => (
              <Space wrap>
                {member.roleIds.map((id) => (
                  <Tag key={id}>{roleNames.get(id) ?? id}</Tag>
                ))}
              </Space>
            ),
          },
          {
            title: '状态',
            dataIndex: 'status',
            width: 90,
            render: (value: string) =>
              value === 'ACTIVE' ? <Tag color="success">启用</Tag> : <Tag>停用</Tag>,
          },
          {
            title: '操作',
            width: 160,
            render: (_, member) => (
              <Space>
                <PermissionButton
                  type="link"
                  permission="access:member:save"
                  onClick={() => openEdit(member)}
                >
                  编辑
                </PermissionButton>
                <Popconfirm
                  title="确认移除该成员？"
                  onConfirm={async () => {
                    try {
                      await deleteAccessMember(projectId, member.userId);
                      void message.success('已移除');
                      await load();
                    } catch (error) {
                      void message.error(error instanceof Error ? error.message : String(error));
                    }
                  }}
                >
                  <PermissionButton type="link" danger permission="access:member:delete">
                    移除
                  </PermissionButton>
                </Popconfirm>
              </Space>
            ),
          },
        ]}
      />
      <Modal
        title={editing ? '编辑成员' : '添加成员'}
        open={open}
        confirmLoading={saving}
        onOk={() => void submit()}
        onCancel={() => setOpen(false)}
        destroyOnHidden
      >
        <Form form={form} layout="vertical">
          {editing ? (
            <Form.Item label="成员">
              <span>{editing.displayName || editing.username}</span>
            </Form.Item>
          ) : (
            <Form.Item
              name="userId"
              label="成员"
              rules={[{ required: true, message: '请选择成员' }]}
              extra="输入登录名或姓名搜索，已在本项目的成员不会出现。"
            >
              <Select
                showSearch
                filterOption={false}
                placeholder="搜索用户"
                onSearch={(keyword) => {
                  if (!keyword.trim()) {
                    setCandidates([]);
                    return;
                  }
                  void searchAccessCandidates(projectId, keyword.trim())
                    .then(setCandidates)
                    .catch(() => setCandidates([]));
                }}
                options={candidates.map((candidate) => ({
                  value: candidate.userId,
                  label: `${candidate.displayName || candidate.username}（${candidate.username}）`,
                }))}
              />
            </Form.Item>
          )}
          <Form.Item
            name="roleIds"
            label="角色"
            rules={[{ required: true, message: '请选择角色' }]}
          >
            <Select mode="multiple" options={activeRoleOptions} placeholder="选择角色" />
          </Form.Item>
          <Form.Item name="status" label="状态" rules={[{ required: true }]}>
            <Select options={STATUS_OPTIONS} />
          </Form.Item>
        </Form>
      </Modal>
    </>
  );
}
</#noparse>
