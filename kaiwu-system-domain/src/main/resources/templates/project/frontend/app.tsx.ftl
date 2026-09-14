<#noparse>import type { RunTimeLayoutConfig } from '@umijs/max';
import type { ReactNode } from 'react';
import RightContent from '@/components/RightContent';
import ProjectAccessProvider from '@/providers/ProjectAccessProvider';

export function rootContainer(container: ReactNode) {
  return <ProjectAccessProvider>{container}</ProjectAccessProvider>;
}

/**
 * 布局与平台端（Kaiwu System）保持同一套观感：同样的品牌方块、同样的纵向间距、
 * 同样的侧栏底部区域。多个业务后台并存时，用户在它们之间切换不应该有"换了个
 * 系统"的感觉。
 */
export const layout: RunTimeLayoutConfig = () => {
  return {
    // 关闭默认 logo，改用与平台一致的渐变方块，保证多个后台视觉同源。
    logo: false,
    menuHeaderRender: (_, title) => (
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 4px' }}>
        <div
          style={{
            width: 30,
            height: 30,
            borderRadius: 8,
            background: 'linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#fff',
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: 0.4,
            boxShadow: '0 4px 12px rgba(79,70,229,0.28)',
          }}
        >
          </#noparse>${projectName?has_content?then(projectName?substring(0, 1), "K")}<#noparse>
        </div>
        {title}
      </div>
    ),
    /**
     * 与平台端保持同一套纵向间距：PageContainer 的间距均由
     * paddingBlockPageContainerContent 派生，默认 40 会让标题上方叠出 44px。
     * 收到 24 后为 28px，标题到内容 20px。只调纵向，左右保持对齐。
     */
    token: {
      pageContainer: {
        paddingBlockPageContainerContent: 24,
      },
    },
    contentStyle: {
      // 顶部收紧，左右与底部保持规范的 24 页边距。
      padding: '16px 24px 24px',
      background: '#f5f6fa',
    },
    // 不渲染面包屑：与页头标题信息重复，平台端也只保留标题。
    breadcrumbRender: false,
    // side 布局下渲染在侧栏底部：全局搜索、切换项目、当前用户与站内信。
    rightContentRender: () => <RightContent />,
  };
};
</#noparse>
