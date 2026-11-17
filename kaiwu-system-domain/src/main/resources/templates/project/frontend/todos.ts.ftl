<#noparse>import { kaiwuRequest } from '@/kaiwu';

export interface ProjectTodo {
  id: string;
  projectId: string;
  title: string;
  content?: string;
  linkUrl?: string;
  overdue: boolean;
  dueAt?: string;
  openedAt: string;
}
export interface TodoPage {
  records: ProjectTodo[];
  total: number;
}

/** 只读当前登录者、本项目未完成待办，不接受收件人参数。 */
export async function queryProjectTodos(projectCode: string, current: number) {
  const query = new URLSearchParams({
    projectCode,
    current: String(current),
    size: '20',
    status: 'OPEN',
  });
  const page = await kaiwuRequest<TodoPage>(`/api/current/todos?${query}`);
  if (!page || !Array.isArray(page.records) || typeof page.total !== 'number')
    throw new Error('Invalid todo page');
  return page;
}

/** 待办链接只接受当前项目的平台工作台路径；任务权限仍由业务服务校验。 */
export function todoRoute(link: string | undefined, projectId: string): string | undefined {
  if (!link || !link.startsWith('/') || link.startsWith('//')) return undefined;
  try {
    const url = new URL(link, window.location.origin);
    if (
      url.origin !== window.location.origin ||
      url.pathname !== `/workspace/${encodeURIComponent(projectId)}`
    )
      return undefined;
    const route = url.searchParams.get('route');
    if (!route || !/^\/[a-zA-Z0-9_/-]+$/.test(route) || route.startsWith('//')) return undefined;
    return route;
  } catch {
    return undefined;
  }
}
</#noparse>