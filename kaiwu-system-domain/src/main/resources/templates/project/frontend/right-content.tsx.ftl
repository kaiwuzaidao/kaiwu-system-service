<#noparse>import {
  AppstoreOutlined,
  CheckCircleFilled,
  IdcardOutlined,
  LogoutOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { App, Avatar, Dropdown, Empty, Modal, Segmented, Skeleton, Tag, Typography } from 'antd';
import { useEffect, useState, type ReactNode } from 'react';
import GlobalSearch from '@/components/GlobalSearch';
import NotificationBell from '@/components/NotificationBell';
import { readProjectId } from '@/hooks/useProjectId';
import {
  fetchCurrentUser,
  fetchMyProjects,
  gotoPlatform,
  platformLogout,
  type PlatformProjectSummary,
  type PlatformUser,
} from '@/services/platform';

/**
 * 侧边栏底部区域（ProLayout side 布局下 rightContentRender 渲染在此）。
 *
 * 侧边栏只有 216px，搜索条与用户信息横排会把用户名挤到换行，因此分三行：
 * 搜索、切换项目、用户信息 + 站内信。与平台端保持一致。
 *
 * 切换项目是独立一行而不是收进用户菜单：它是跨项目工作时的高频动作，
 * 藏在头像下拉里要点两次才够得着。
 *
 * 这里不显示当前项目名——侧栏 logo 区已经是本项目的名字，再写一次就是
 * 同一个品牌在侧栏出现两回（见 UI 规范禁做第 12 条）。
 *
 * 语言切换不在此提供：本应用 supportedLocales 只有 zh-CN，且语言跟随平台
 * 账户偏好（见 config.ts），子应用不另设入口。
 */
export default function RightContent() {
  const [user, setUser] = useState<PlatformUser>();
  const [switching, setSwitching] = useState(false);

  useEffect(() => {
    void fetchCurrentUser()
      .then(setUser)
      // 取不到用户时只是不显示这块，不影响业务功能。
      .catch(() => undefined);
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, padding: '8px 4px' }}>
      <GlobalSearch block />
      <ProjectSwitcher open={switching} onClose={() => setSwitching(false)} />
      <SidebarAction
        icon={<AppstoreOutlined />}
        label="切换项目"
        onClick={() => setSwitching(true)}
      />
      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
        <UserMenu user={user} />
        <NotificationBell compact />
      </div>
    </div>
  );
}

/** 侧栏底部的行按钮，视觉与下方用户行对齐（同样的高度、圆角与 hover 底色）。 */
function SidebarAction({
  icon,
  label,
  onClick,
}: {
  icon: ReactNode;
  label: string;
  onClick: () => void;
}) {
  const [hover, setHover] = useState(false);
  return (
    <div
      role="button"
      tabIndex={0}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          onClick();
        }
      }}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '6px 6px',
        borderRadius: 6,
        cursor: 'pointer',
        color: hover ? '#4f46e5' : 'rgba(0,0,0,0.65)',
        background: hover ? 'rgba(79,70,229,0.08)' : 'transparent',
        transition: 'background .2s, color .2s',
      }}
    >
      <span style={{ display: 'flex', width: 28, justifyContent: 'center', flexShrink: 0 }}>
        {icon}
      </span>
      <span style={{ flex: 1, minWidth: 0 }}>{label}</span>
    </div>
  );
}

function UserMenu({ user }: { user?: PlatformUser }) {
  const { modal, message } = App.useApp();
  const name = user?.displayName || user?.username || '';

  const onSignOut = () => {
    modal.confirm({
      title: '确认退出登录？',
      okText: '退出',
      cancelText: '取消',
      onOk: async () => {
        try {
          await platformLogout();
        } catch {
          // 登出接口失败也要跳回平台，避免停留在已失效的会话里。
          message.error('退出登录请求失败，将返回平台');
        }
        gotoPlatform('/login');
      },
    });
  };

  // 切换项目不放进这里：它已在侧栏有独立入口，两处重复只是噪音。
  return (
    <Dropdown
      placement="topLeft"
      menu={{
        items: [
          { key: 'profile', icon: <IdcardOutlined />, label: '个人中心' },
          { type: 'divider' },
          { key: 'logout', icon: <LogoutOutlined />, label: '退出登录', danger: true },
        ],
        onClick: ({ key }) => {
          if (key === 'profile') gotoPlatform('/profile');
          if (key === 'logout') onSignOut();
        },
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          flex: 1,
          minWidth: 0,
          cursor: 'pointer',
          padding: '4px 6px',
          borderRadius: 6,
        }}
      >
        <Avatar
          size={28}
          icon={!name ? <UserOutlined /> : undefined}
          style={{ background: 'linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%)', flexShrink: 0 }}
        >
          {name ? name.slice(0, 1) : undefined}
        </Avatar>
        <Typography.Text ellipsis style={{ flex: 1, minWidth: 0 }}>
          {name || '未登录'}
        </Typography.Text>
      </div>
    </Dropdown>
  );
}

/** 平台自身在 sys_project 里是 built_in 项目，入口就是平台根路径，没有 backend_url。 */
const PLATFORM_ENTRY_PATH = '/';

/**
 * 去别的业务后台一律经平台的宿主页，而不是直接跳它的 backendUrl。
 *
 * 令牌只存在内存，靠向 opener/parent 发 postMessage 索取；顶层直达的页面两者都
 * 没有，进去必然 401。宿主页会把目标装进同源 iframe，桥接才成立。
 */
function projectWorkspacePath(projectId: string): string {
  return `/workspace/${encodeURIComponent(projectId)}`;
}

/**
 * 打开方式偏好。与平台同源，共用同一个 localStorage 键——在平台上选了「新标签页」，
 * 进到子应用里的切换器也应该是新标签页，不该出现两套各记各的。
 */
type ProjectOpenMode = 'inline' | 'newTab';

const OPEN_MODE_KEY = 'kaiwu.projectOpenMode';

function readOpenMode(): ProjectOpenMode {
  try {
    return window.localStorage.getItem(OPEN_MODE_KEY) === 'newTab' ? 'newTab' : 'inline';
  } catch {
    return 'inline';
  }
}

function writeOpenMode(mode: ProjectOpenMode): void {
  try {
    window.localStorage.setItem(OPEN_MODE_KEY, mode);
  } catch {
    // 存不下就只在本次会话生效，不影响切换本身。
  }
}

/**
 * 切换目标要换掉的是最外层窗口。
 *
 * 本应用可能正跑在平台宿主页的 iframe 里，这时改 window.location 只会把新页面
 * 套进同一个 iframe——平台里嵌平台。同源，可以直接拿 top。
 */
function navigateTop(href: string): void {
  const top = window.top ?? window;
  top.location.href = href;
}

/** 新标签页必须保留 opener：那正是子应用取令牌的对端，不能加 noopener。 */
function openTarget(href: string, mode: ProjectOpenMode): void {
  if (mode === 'newTab') {
    window.open(href, '_blank');
    return;
  }
  navigateTop(href);
}

type SwitchTarget = {
  key: string;
  name: string;
  caption: string;
  href: string;
  current: boolean;
  platform: boolean;
};

/**
 * 项目切换弹窗。平台端的"切换项目"是跳回工作台挑选，但子应用没有工作台，
 * 跳出去再点回来要两跳；这里直接列出有权访问的去处，一步到位。
 *
 * 三个容易踩的点：
 * 1. 平台（built_in）必须在列表里。它是"回到 Kaiwu System"的唯一入口，
 *    早先按子应用模型过滤掉了 built_in，导致有 system 权限也切不回去。
 * 2. 平台没有 backend_url，不能按"无 backendUrl 即无处可去"一并滤掉，
 *    它走 PLATFORM_ENTRY_PATH。
 * 3. 子应用靠 query 上的 projectId 认项目（见 useProjectId），跳转必须带上，
 *    否则进去是一个没有项目上下文的空壳。
 */
function ProjectSwitcher({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [loading, setLoading] = useState(false);
  const [projects, setProjects] = useState<PlatformProjectSummary[]>();
  const [openMode, setOpenMode] = useState<ProjectOpenMode>('inline');
  const currentProjectId = readProjectId();

  // 偏好读在打开弹窗时，而不是组件挂载时：平台那边可能刚改过。
  useEffect(() => {
    if (open) setOpenMode(readOpenMode());
  }, [open]);

  useEffect(() => {
    if (!open) return;
    setLoading(true);
    void fetchMyProjects()
      .then((data) => setProjects(data ?? []))
      .catch(() => setProjects([]))
      .finally(() => setLoading(false));
  }, [open]);

  const targets: SwitchTarget[] = (projects ?? [])
    // 平台恒可进入；业务项目要有后台入口，没有 backendUrl 的点了也无处可去。
    .filter((p) => p.builtIn || p.backendUrl)
    .map((p) => ({
      key: p.id,
      name: p.projectName,
      caption: p.builtIn ? '平台控制台' : p.backendLabel || p.projectCode,
      href: p.builtIn ? PLATFORM_ENTRY_PATH : projectWorkspacePath(p.id),
      current: !p.builtIn && p.id === currentProjectId,
      platform: p.builtIn,
    }))
    // 平台置顶，其余保持后端给的顺序。
    .sort((a, b) => Number(b.platform) - Number(a.platform));

  return (
    <Modal
      open={open}
      onCancel={onClose}
      footer={null}
      title={
        // 与平台端同一个位置：标题行右侧，右留 32px 给关闭按钮。
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 16,
            paddingRight: 32,
          }}
        >
          <span>切换项目</span>
          <Segmented<ProjectOpenMode>
            size="small"
            value={openMode}
            onChange={(value) => {
              setOpenMode(value);
              writeOpenMode(value);
            }}
            options={[
              { value: 'inline', label: '当前页面' },
              { value: 'newTab', label: '新标签页' },
            ]}
          />
        </div>
      }
      width={640}
      styles={{ body: { paddingTop: 8 } }}
    >
      <Typography.Paragraph type="secondary" style={{ fontSize: 12, marginBottom: 16 }}>
        选择要进入的项目后台，或返回平台控制台。
      </Typography.Paragraph>
      {loading ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
          {[0, 1, 2, 3].map((i) => (
            <Skeleton key={i} active avatar paragraph={{ rows: 1 }} />
          ))}
        </div>
      ) : targets.length === 0 ? (
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="没有可进入的项目后台，请联系管理员开通"
        />
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
          {targets.map((item) => (
            <SwitchCard key={item.key} item={item} mode={openMode} />
          ))}
        </div>
      )}
    </Modal>
  );
}

function SwitchCard({ item, mode }: { item: SwitchTarget; mode: ProjectOpenMode }) {
  const [hover, setHover] = useState(false);
  const active = hover && !item.current;

  return (
    <div
      role="button"
      tabIndex={item.current ? -1 : 0}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onClick={() => {
        if (!item.current) openTarget(item.href, mode);
      }}
      onKeyDown={(e) => {
        if (item.current) return;
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          openTarget(item.href, mode);
        }
      }}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: 16,
        borderRadius: 8,
        cursor: item.current ? 'default' : 'pointer',
        border: `1px solid ${active ? '#4f46e5' : '#f0f0f0'}`,
        background: item.current ? 'rgba(79,70,229,0.04)' : '#fff',
        boxShadow: active ? '0 4px 12px rgba(79,70,229,0.12)' : 'none',
        transition: 'border-color .2s, box-shadow .2s',
      }}
    >
      <div
        style={{
          width: 40,
          height: 40,
          flexShrink: 0,
          borderRadius: 8,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 16,
          fontWeight: 600,
          color: item.platform ? '#fff' : '#4f46e5',
          background: item.platform
            ? 'linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%)'
            : 'rgba(79,70,229,0.08)',
        }}
      >
        {item.platform ? <AppstoreOutlined /> : item.name.slice(0, 1)}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Typography.Text strong ellipsis style={{ minWidth: 0 }}>
            {item.name}
          </Typography.Text>
          {item.current && (
            <Tag color="processing" style={{ marginInlineEnd: 0, flexShrink: 0 }}>
              当前
            </Tag>
          )}
        </div>
        <Typography.Text
          type="secondary"
          ellipsis
          style={{ fontSize: 12, display: 'block', minWidth: 0 }}
        >
          {item.caption}
        </Typography.Text>
      </div>
      {item.current && <CheckCircleFilled style={{ color: '#4f46e5', flexShrink: 0 }} />}
    </div>
  );
}
</#noparse>