import { PlusOutlined, ReloadOutlined } from '@ant-design/icons';
import {
  ModalForm,
  ProForm,
  ProFormText,
  ProTable,
  type ActionType,
  type ProColumns,
} from '@ant-design/pro-components';
import { App, Popconfirm, Space } from 'antd';
import { useRef, useState } from 'react';
import {
  ManagedDictSelect,
  ManagedDictText,
  PermissionButton,
} from '@/shell';
import {
  delete${table.entityName},
  page${table.entityName},
  save${table.entityName},
} from './api';

export default function ${table.entityName}Page() {
  const { message } = App.useApp();
  const actionRef = useRef<ActionType>();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Record<string, unknown>>();
  const columns: ProColumns<Record<string, unknown>>[] = [
<#list table.editableColumns() as column>
    {
      title: '${column.label}',
      dataIndex: '${column.fieldName}',
<#if !column.searchable>      search: false,
</#if><#if column.fieldName?lower_case?contains("status")>      render: (_, row) => (
        <ManagedDictText dictCode="${moduleCode}.${resourceCode}_status" value={String(row.${column.fieldName} ?? '')} />
      ),
</#if>    },
</#list>
    {
      title: '操作',
      valueType: 'option',
      render: (_, row) => (
        <Space>
          <PermissionButton
            type="link"
            permission="${permissionPrefix}:save"
            onClick={() => { setEditing(row); setOpen(true); }}
          >
            编辑
          </PermissionButton>
          <Popconfirm
            title="确认删除？"
            onConfirm={async () => {
              await delete${table.entityName}(String(row.${pkField}));
              void message.success('已删除');
              actionRef.current?.reload();
            }}
          >
            <PermissionButton
              type="link"
              danger
              permission="${permissionPrefix}:delete"
            >
              删除
            </PermissionButton>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <>
      <ProTable<Record<string, unknown>>
        rowKey="${pkField}"
        actionRef={actionRef}
        columns={columns}
        request={async (params) => {
          const page = await page${table.entityName}({
            ...params,
            current: params.current,
            size: params.pageSize,
          });
          return { data: page.records, total: page.total, success: true };
        }}
        toolBarRender={() => [
          <PermissionButton
            key="refresh"
            permission="${permissionPrefix}:list"
            icon={<ReloadOutlined />}
            onClick={() => actionRef.current?.reload()}
          >
            刷新
          </PermissionButton>,
          <PermissionButton
            key="create"
            permission="${permissionPrefix}:save"
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => {
              setEditing(undefined);
              setOpen(true);
            }}
          >
            新增
          </PermissionButton>,
        ]}
      />
      <ModalForm<Record<string, unknown>>
        key={String(editing?.${pkField} ?? 'new')}
        title={editing ? '编辑' : '新增'}
        open={open}
        initialValues={editing ?? {}}
        modalProps={{ destroyOnHidden: true, onCancel: () => setOpen(false) }}
        onFinish={async (values) => {
          await save${table.entityName}({
            ...values,
            ${pkField}: editing?.${pkField},
          });
          void message.success('保存成功');
          setOpen(false);
          actionRef.current?.reload();
          return true;
        }}
      >
<#list table.editableColumns() as column>
<#if column.fieldName?lower_case?contains("status")>
        <ProForm.Item name="${column.fieldName}" label="${column.label}">
          <ManagedDictSelect
            dictCode="${moduleCode}.${resourceCode}_status"
            allowClear
            placeholder="字典未配置时可留空"
          />
        </ProForm.Item>
<#else>
        <ProFormText name="${column.fieldName}" label="${column.label}" />
</#if>
</#list>
      </ModalForm>
    </>
  );
}
