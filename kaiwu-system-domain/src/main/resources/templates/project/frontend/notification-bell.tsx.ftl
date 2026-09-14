<#noparse>import { BellOutlined } from '@ant-design/icons';
import { App, Badge, Button, Empty, List, Popover, Spin, Typography } from 'antd';
import { useCallback, useEffect, useState } from 'react';
import {
  fetchNotificationSummary,
  gotoPlatform,
  markAllNotificationsRead,
  markNotificationRead,
  queryNotifications,
  type PlatformNotification,
} from '@/services/platform';

/**
 * 平台站内信。消息由平台统一投递（收件人是平台用户），本子应用只做展示与已读，
 * 详情链接指向平台页面，需整页跳出。
 */
export default function NotificationBell({ compact }: { compact?: boolean }) {
  const { message } = App.useApp();
  const [unread, setUnread] = useState(0);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<PlatformNotification[]>([]);

  const refreshSummary = useCallback(() => {
    void fetchNotificationSummary()
      .then((data) => setUnread(data?.unread ?? 0))
      // 站内信是辅助信息，取不到时静默降级，不打断业务操作。
      .catch(() => undefined);
  }, []);

  useEffect(refreshSummary, [refreshSummary]);

  const loadList = useCallback(() => {
    setLoading(true);
    void queryNotifications({ page: 1, size: 10 })
      .then((data) => setItems(data?.records ?? []))
      .catch(() => setItems([]))
      .finally(() => setLoading(false));
  }, []);

  const onOpenChange = (next: boolean) => {
    setOpen(next);
    if (next) loadList();
  };

  const onRead = async (item: PlatformNotification) => {
    if (!item.readAt) {
      try {
        await markNotificationRead(item.id);
        refreshSummary();
        loadList();
      } catch {
        message.error('标记已读失败');
        return;
      }
    }
    if (item.link) gotoPlatform(item.link);
  };

  const onReadAll = async () => {
    try {
      await markAllNotificationsRead();
      message.success('已全部标记为已读');
      refreshSummary();
      loadList();
    } catch {
      message.error('操作失败');
    }
  };

  const content = (
    <div style={{ width: 320 }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: 8,
        }}
      >
        <Typography.Text strong>站内信</Typography.Text>
        <Button type="link" size="small" disabled={unread === 0} onClick={onReadAll}>
          全部已读
        </Button>
      </div>
      <Spin spinning={loading}>
        {items.length === 0 && !loading ? (
          <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="暂无消息" />
        ) : (
          <List
            size="small"
            dataSource={items}
            renderItem={(item) => (
              <List.Item
                style={{ cursor: 'pointer', paddingInline: 0 }}
                onClick={() => void onRead(item)}
              >
                <List.Item.Meta
                  title={
                    <Typography.Text strong={!item.readAt} ellipsis>
                      {item.title}
                    </Typography.Text>
                  }
                  description={
                    item.content ? (
                      <Typography.Text type="secondary" style={{ fontSize: 12 }} ellipsis>
                        {item.content}
                      </Typography.Text>
                    ) : undefined
                  }
                />
              </List.Item>
            )}
          />
        )}
      </Spin>
    </div>
  );

  return (
    <Popover
      open={open}
      onOpenChange={onOpenChange}
      trigger="click"
      placement="topRight"
      content={content}
    >
      <Button type="text" size={compact ? 'small' : 'middle'} aria-label="站内信">
        <Badge count={unread} size="small" offset={[2, -2]}>
          <BellOutlined style={{ fontSize: 16 }} />
        </Badge>
      </Button>
    </Popover>
  );
}
</#noparse>