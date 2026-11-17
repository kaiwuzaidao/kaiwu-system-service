<#noparse>import type { MenuDataItem } from '@ant-design/pro-components';
import type { ProjectNavigationMenu } from '@/kaiwu';

/** 业务菜单来自平台当前用户的授权结果；内置自服务入口不依赖角色菜单种子。 */
export function projectMenu(
  menus: ProjectNavigationMenu[],
  permissions: ReadonlySet<string>,
): MenuDataItem[] {
  const convert = (items: ProjectNavigationMenu[]): MenuDataItem[] =>
    items.flatMap((item) => {
      if (
        !item.visible ||
        item.status !== 'ACTIVE' ||
        item.menuType === 'BUTTON' ||
        (item.permissionCode && !permissions.has(item.permissionCode))
      )
        return [];
      if (item.routePath === '/' || item.routePath === '/todos') return [];
      if (item.routePath === '/project-members' && !permissions.has('access:member:list'))
        return [];
      if (item.routePath === '/project-roles' && !permissions.has('access:role:list')) return [];
      if (item.routePath === '/project-files' && !permissions.has('file:record:list')) return [];
      const children = convert(item.children ?? []);
      if (
        (item.menuType === 'DIRECTORY' ||
          item.children?.some((child) => child.menuType !== 'BUTTON')) &&
        !children.length
      )
        return [];
      return [
        {
          key: item.id,
          path: item.routePath,
          name: item.menuName,
          locale: false,
          ...(children.length ? { children } : {}),
        },
      ];
    });
  return [{ path: '/', name: 'home' }, { path: '/todos', name: 'todos' }, ...convert(menus)];
}
</#noparse>