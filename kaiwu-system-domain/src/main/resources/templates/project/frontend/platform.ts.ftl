<#noparse>import { requestJson } from '@/services/request';

/**
 * 平台侧接口。本应用是 Kaiwu 平台的业务子应用，顶栏的用户、站内信、全局搜索
 * 都由平台承载，这里只做转调；业务自身的接口一律在各自的 service 文件里。
 *
 * 路径走 `/api/`（平台 Gateway），与业务的 `/</#noparse>${projectCode}<#noparse>-api/` 前缀区分开。
 */

export type PlatformUser = {
  id: string;
  username: string;
  displayName: string;
  locale?: string;
};

export type PlatformProjectSummary = {
  id: string;
  projectCode: string;
  projectName: string;
  status: string;
  builtIn: boolean;
  /** 浏览器可直接打开的业务后台入口；缺省表示该项目还没有后台 */
  backendUrl?: string;
  backendLabel?: string;
};

export type SearchItem = {
  type: 'PROJECT' | 'USER' | 'DELIVERY';
  id: string;
  title: string;
  subtitle: string;
  /** 平台侧路由，需跳出子应用访问 */
  path: string;
};

export type PlatformNotification = {
  id: string;
  title: string;
  content?: string;
  link?: string;
  readAt?: string | null;
  createAt?: string;
};

export type NotificationSummary = {
  unread: number;
};

export function fetchCurrentUser() {
  return requestJson<PlatformUser>('/api/auth/me');
}

export function platformLogout() {
  return requestJson<void>('/api/auth/logout', { method: 'POST' });
}

export function updateUserLocale(locale: string) {
  return requestJson<void>('/api/auth/me/locale', {
    method: 'PUT',
    body: JSON.stringify({ locale }),
  });
}

/** 当前登录者有权访问的项目，用于在子应用内直接切换后台。 */
export function fetchMyProjects() {
  return requestJson<PlatformProjectSummary[]>('/api/current/projects');
}

export function globalSearch(query: string) {
  return requestJson<SearchItem[]>(`/api/search?q=${encodeURIComponent(query)}`);
}

export function fetchNotificationSummary() {
  return requestJson<NotificationSummary>('/api/current/notifications/summary');
}

export function queryNotifications(params: { page?: number; size?: number } = {}) {
  const search = new URLSearchParams();
  if (params.page != null) search.set('page', String(params.page));
  if (params.size != null) search.set('size', String(params.size));
  const suffix = search.toString();
  return requestJson<{ records: PlatformNotification[]; total: number }>(
    `/api/current/notifications${suffix ? `?${suffix}` : ''}`,
  );
}

export function markNotificationRead(id: string) {
  return requestJson<void>(`/api/current/notifications/${encodeURIComponent(id)}/read`, {
    method: 'POST',
  });
}

export function markAllNotificationsRead() {
  return requestJson<number>('/api/current/notifications/read-all', { method: 'POST' });
}

/**
 * 跳转到平台页面。子应用部署在 /apps/</#noparse>${projectCode}<#noparse>/ 下，平台在同源根路径，
 * 因此用同源绝对路径离开子应用，不写死域名。
 */
export function gotoPlatform(path: string) {
  window.location.href = path.startsWith('/') ? path : `/${path}`;
}
</#noparse>