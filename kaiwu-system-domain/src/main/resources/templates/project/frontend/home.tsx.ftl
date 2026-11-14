<#noparse>import { PageContainer } from '@ant-design/pro-components';
import { Link, useIntl } from '@umijs/max';
import { Alert, Button, Card, Col, Empty, Row, Skeleton, Typography } from 'antd';
import { useProjectAccess } from '@/providers/ProjectAccessProvider';

// prettier-ignore
const entries: { path: string; key: string; permission: string }[] = [
</#noparse>${homeEntries}<#noparse>
];

/** 只展示当前项目已授权的业务模块，最终授权仍由服务端执行。 */
export default function HomePage() {
  const intl = useIntl();
  const t = (id: string) => intl.formatMessage({ id });
  const { projectId, permissions, loading, error, retry } = useProjectAccess();
  const visible = entries.filter((item) => permissions.has(item.permission));
  return (
    <PageContainer title={t('menu.home')}>
      <div style={{ paddingBottom: 8 }}>
        <div style={{ marginBottom: 24 }}>
          <Typography.Title level={4}>{t('home.welcome')}</Typography.Title>
          <Typography.Paragraph type="secondary">{t('home.description')}</Typography.Paragraph>
        </div>
        {!projectId ? (
          <Alert type="warning" showIcon message={t('home.missingProject')} />
        ) : error ? (
          <Alert
            type="error"
            showIcon
            message={t('home.failed')}
            action={<Button onClick={retry}>{t('home.retry')}</Button>}
          />
        ) : loading ? (
          <Skeleton active />
        ) : visible.length ? (
          <Row gutter={[20, 20]}>
            {visible.map((item) => (
              <Col xs={24} md={12} xl={8} key={item.path}>
                <Card style={{ height: '100%' }}>
                  <Typography.Title level={4}>{t(item.key)}</Typography.Title>
                  <Typography.Paragraph type="secondary">
                    {t('home.moduleHint')}
                  </Typography.Paragraph>
                  <Link
                    to={{
                      pathname: item.path,
                      search: new URLSearchParams({ projectId }).toString(),
                    }}
                  >
                    {intl.formatMessage({ id: 'home.enter' }, { name: t(item.key) })}
                  </Link>
                </Card>
              </Col>
            ))}
          </Row>
        ) : (
          <Card>
            <Empty description={t(entries.length ? 'home.noAccess' : 'home.empty')} />
          </Card>
        )}
      </div>
    </PageContainer>
  );
}
</#noparse>