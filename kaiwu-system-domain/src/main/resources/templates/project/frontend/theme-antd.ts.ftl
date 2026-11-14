<#noparse>import type { ThemeConfig } from 'antd';
import { kaiwuPalette } from './tokens';

/** 优先使用 Ant Design 默认组件比例，避免全局覆盖形成第二套控件规格。 */
export const kaiwuTheme: ThemeConfig = {
  token: {
    colorPrimary: kaiwuPalette.primary,
    colorBgLayout: kaiwuPalette.page,
    fontFamily:
      '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"',
    fontSize: 14,
    borderRadius: 6,
    borderRadiusLG: 8,
    controlHeight: 32,
  },
  components: {
    Menu: {
      itemHeight: 40,
      itemBorderRadius: 6,
      itemColor: 'rgba(0, 0, 0, 0.65)',
      itemSelectedBg: 'rgba(0, 0, 0, 0.04)',
      itemSelectedColor: 'rgba(0, 0, 0, 0.95)',
    },
    Card: { headerHeight: 56, headerFontSize: 16, paddingLG: 24 },
  },
};
</#noparse>