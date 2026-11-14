<#noparse>import type { MenuDataItem } from '@ant-design/pro-components';
import { Link, type RunTimeLayoutConfig } from '@umijs/max';
import type { ReactNode } from 'react';
import LineIcon, { type LineIconName } from '@/components/LineIcon';
import RightContent, { PageBreadcrumb } from '@/components/RightContent';
import ProjectAccessProvider, { useProjectAccess } from '@/providers/ProjectAccessProvider';
import { projectMenu } from '@/utils/projectMenu';
import useProjectConfig from '@/hooks/useProjectConfig';
import { proLayoutTokens } from '@/theme/layout';
import { readProjectId } from '@/hooks/useProjectId';

export function rootContainer(container: ReactNode) {
  return <ProjectAccessProvider>{container}</ProjectAccessProvider>;
}

/**
 * 菜单图标按路由取 线性图标。Umi 只认 Ant Design 图标名，设计稿的细线图标在这里统一替换；
 * 新增页面时按路由在表里登记一个图标，不登记则使用通用图标，保证每个菜单项都有图标、文字对齐。
 */
const MENU_GLYPHS: Record<string, LineIconName> = {
  '/': 'layout',
  '/project-members': 'user',
  '/project-roles': 'shield',
</#noparse><#if fileRegistry><#noparse>
  '/project-files': 'grid',
</#noparse></#if><#noparse>};

/** 有子菜单的目录在 group 菜单里显示为分组标题，标题不带图标（与平台侧栏一致）。 */
function withLineIcons(items: MenuDataItem[]): MenuDataItem[] {
  return items.map((item) =>
    item.children?.length
      ? { ...item, icon: undefined, children: withLineIcons(item.children) }
      : { ...item, icon: <LineIcon name={MENU_GLYPHS[item.path ?? ''] ?? 'grid'} /> },
  );
}

/**
 * 布局与平台端（Kaiwu System）保持同一套 Ant Design Pro 规格：同样的品牌方块、分组侧栏、顶部操作栏与页面留白。
 * 多个业务后台并存时，用户在它们之间切换不应该有「换了个系统」的感觉。
 */
/** 项目配置可以覆盖默认的管理端名称和品牌。 */
function SidebarBrand({ title }: { title: ReactNode }) {
  const label = useProjectConfig('app.admin.label');
  const brand = useProjectConfig('app.admin.brand');
  return (
    <div className="kaiwu-sidebar-brand">
      <span className="kaiwu-sidebar-brand-mark" aria-hidden="true">
        <span></#noparse>${projectName?has_content?then(projectName?substring(0, 1), "K")}<#noparse></span>
      </span>
      <span className="kaiwu-sidebar-brand-name">{label || brand || title}</span>
    </div>
  );
}

export const layout: RunTimeLayoutConfig = function useProjectLayout() {
  const access = useProjectAccess();
  return {
    logo: false,
    className: 'kaiwu-subapp-layout',
    navTheme: 'light',
    layout: 'mix',
    splitMenus: false,
    fixedHeader: true,
    fixSiderbar: true,
    contentWidth: 'Fluid',
    headerHeight: 56,
    siderWidth: 256,
    menu: { type: 'group', locale: true },
    menuDataRender: () =>
      withLineIcons(
        access.loading || access.error || !access.projectId
          ? []
          : projectMenu(access.menus, access.permissions),
      ),
    menuItemRender: (item, defaultDom, menuProps) => {
      if (item.isUrl || item.children || !item.path || item.path === menuProps.location?.pathname) {
        return defaultDom;
      }
      // 菜单切页只继承平台项目，订单等页面参数留在原页。
      const projectId = readProjectId();
      const search = projectId ? new URLSearchParams({ projectId }).toString() : '';
      return (
        <Link to={{ pathname: item.path.replace('/*', ''), search }} target={item.target}>
          {defaultDom}
        </Link>
      );
    },
    headerTitleRender: (_, title) => <SidebarBrand title={title} />,
    menuFooterRender: false,
    // 桌面与窄屏共用原生 ProLayout 顶栏。
    rightContentRender: () => <RightContent />,
    childrenRender: (children) => (
      <>
        <div className="kaiwu-content-frame">
          <PageBreadcrumb />
          {children}
        </div>
      </>
    ),
    token: proLayoutTokens,
    contentStyle: { padding: 0 },
  };
};
</#noparse>