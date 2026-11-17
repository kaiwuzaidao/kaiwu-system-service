<#noparse>import { ReloadOutlined } from '@ant-design/icons';
import { App, Button, Form, Input, Popconfirm, Space, Table } from 'antd';
import { useCallback, useEffect, useState } from 'react';
import PermissionButton from '@/components/PermissionButton';
import { useProjectAccess } from '@/kaiwu';
import {
  deleteProjectFile,
  downloadRelayedFile,
  queryFileDownload,
  queryProjectFiles,
  type ProjectFile,
} from '@/services/projectFiles';

type Filters = { keyword?: string; bizType?: string; bizId?: string };

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/**
 * 文件：本项目所有业务功能上传的文件的统一列表。
 * 文件由各业务功能产生并挂在业务记录上，这里只提供查找、下载和删除；删除是软删除，保留期内可由运维恢复。
 */
export default function ProjectFilesPage() {
  const { message } = App.useApp();
  const { permissions } = useProjectAccess();
  const [form] = Form.useForm<Filters>();
  const [filters, setFilters] = useState<Filters>({});
  const [rows, setRows] = useState<ProjectFile[]>([]);
  const [total, setTotal] = useState(0);
  const [current, setCurrent] = useState(1);
  const [size, setSize] = useState(20);
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    if (!permissions.has('file:record:list')) return;
    setLoading(true);
    try {
      const page = await queryProjectFiles({ ...filters, current, size });
      setRows(page.records);
      setTotal(page.total);
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
    } finally {
      setLoading(false);
    }
  }, [filters, current, size, permissions, message]);

  useEffect(() => {
    void load();
  }, [load]);

  const download = async (file: ProjectFile) => {
    try {
      const target = await queryFileDownload(file.id);
      if (target.direct) window.open(target.url, '_blank', 'noopener');
      else await downloadRelayedFile(target);
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
    }
  };

  const remove = async (file: ProjectFile) => {
    try {
      await deleteProjectFile(file.id);
      void message.success('已删除');
      await load();
    } catch (error) {
      void message.error(error instanceof Error ? error.message : String(error));
    }
  };

  return (
    <>
      <Form
        form={form}
        layout="inline"
        style={{ marginBottom: 16 }}
        onFinish={(values) => {
          setCurrent(1);
          setFilters(values);
        }}
      >
        <Form.Item name="keyword">
          <Input allowClear placeholder="文件名" />
        </Form.Item>
        <Form.Item name="bizType">
          <Input allowClear placeholder="业务类型" />
        </Form.Item>
        <Form.Item name="bizId">
          <Input allowClear placeholder="业务记录 ID" />
        </Form.Item>
        <Space>
          <Button type="primary" htmlType="submit">
            查询
          </Button>
          <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
            刷新
          </Button>
        </Space>
      </Form>
      <Table<ProjectFile>
        rowKey="id"
        loading={loading}
        dataSource={rows}
        pagination={{
          current,
          pageSize: size,
          total,
          showSizeChanger: true,
          onChange: (page, pageSize) => {
            setCurrent(page);
            setSize(pageSize);
          },
        }}
        columns={[
          { title: '文件名', dataIndex: 'originalName', ellipsis: true },
          { title: '类型', dataIndex: 'contentType', width: 160, ellipsis: true },
          {
            title: '大小',
            dataIndex: 'sizeBytes',
            width: 100,
            render: (value: number) => formatSize(value),
          },
          { title: '业务类型', dataIndex: 'bizType', width: 120 },
          {
            title: '业务记录',
            dataIndex: 'bizId',
            width: 160,
            render: (value?: string) => value ?? '-',
          },
          { title: '上传人', dataIndex: 'uploaderId', width: 120 },
          { title: '上传时间', dataIndex: 'createdAt', width: 180 },
          {
            title: '操作',
            width: 160,
            render: (_, file) => (
              <Space size={0}>
                <PermissionButton
                  type="link"
                  permission="file:record:download"
                  onClick={() => void download(file)}
                >
                  下载
                </PermissionButton>
                <Popconfirm
                  title="确认删除该文件？"
                  description="删除后业务里引用它的地方将无法再打开。"
                  onConfirm={() => void remove(file)}
                >
                  <PermissionButton type="link" danger permission="file:record:delete">
                    删除
                  </PermissionButton>
                </Popconfirm>
              </Space>
            ),
          },
        ]}
      />
    </>
  );
}
</#noparse>
