<#noparse>import { PageContainer } from '@ant-design/pro-components';
import { history, useIntl } from '@umijs/max';
import { Alert, Button, Empty, Space, Table, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { useProjectAccess } from '@/kaiwu';
import { useAccessTokenVersion } from '@/kaiwu';
import { queryProjectTodos, todoRoute, type ProjectTodo } from '@/services/todos';

/** 待办状态由来源服务维护；列表仅展示和跳转，不提供手工完成按钮。 */
export default function TodosPage() {
  const intl = useIntl();
  const t = (id: string) => intl.formatMessage({ id });
  const { projectId, loading: accessLoading, error: accessError } = useProjectAccess();
  const tokenVersion = useAccessTokenVersion();
  const [current, setCurrent] = useState(1);
  const [attempt, setAttempt] = useState(0);
  const [rows, setRows] = useState<ProjectTodo[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  useEffect(() => {
    let active = true;
    setRows([]);
    setTotal(0);
    setError(false);
    if (!projectId || accessLoading || accessError) return;
    setLoading(true);
    void queryProjectTodos('</#noparse>${projectCode}<#noparse>', current)
      .then((data) => {
        if (active) {
          setRows(data.records);
          setTotal(data.total);
        }
      })
      .catch(() => {
        if (active) setError(true);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [projectId, current, attempt, tokenVersion, accessLoading, accessError]);
  return (
    <PageContainer title={t('menu.todos')}>
      <Space direction="vertical" size={16} style={{ width: '100%' }}>
        <Typography.Paragraph type="secondary">{t('todos.description')}</Typography.Paragraph>
        {error && (
          <Alert
            type="error"
            showIcon
            message={t('todos.failed')}
            action={
              <Button onClick={() => setAttempt((v) => v + 1)}>{t('common.action.retry')}</Button>
            }
          />
        )}
        <Table<ProjectTodo>
          rowKey="id"
          loading={loading || accessLoading}
          dataSource={rows}
          locale={{
            emptyText:
              error || accessError ? (
                t('todos.unavailable')
              ) : (
                <Empty description={t('todos.empty')} />
              ),
          }}
          title={() => (
            <Button onClick={() => setAttempt((v) => v + 1)}>{t('todos.refresh')}</Button>
          )}
          pagination={{
            current,
            total,
            pageSize: 20,
            showSizeChanger: false,
            onChange: setCurrent,
          }}
          columns={[
            {
              title: t('todos.title'),
              dataIndex: 'title',
              render: (_, row) => (
                <div>
                  <Typography.Text strong>{row.title}</Typography.Text>
                  {row.content && (
                    <Typography.Paragraph type="secondary">{row.content}</Typography.Paragraph>
                  )}
                </div>
              ),
            },
            { title: t('todos.time'), dataIndex: 'openedAt', responsive: ['md'] },
            {
              title: t('common.operation'),
              key: 'action',
              width: 120,
              render: (_, row) => {
                const route =
                  row.projectId === projectId ? todoRoute(row.linkUrl, projectId) : undefined;
                return route ? (
                  <Button
                    type="link"
                    onClick={() => history.push(`${route}?${new URLSearchParams({ projectId })}`)}
                  >
                    {t('todos.handle')}
                  </Button>
                ) : (
                  <Typography.Text type="secondary">{t('todos.noLink')}</Typography.Text>
                );
              },
            },
          ]}
        />
      </Space>
    </PageContainer>
  );
}
</#noparse>