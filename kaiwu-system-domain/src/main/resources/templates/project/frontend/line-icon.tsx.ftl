<#noparse>import type { CSSProperties } from 'react';

/**
 * V5 线性图标集，路径取自设计稿原型的 SVG symbol（24 栅格、1.7 描边、圆角端点）。
 *
 * <p>菜单、顶栏与 AI 模式导航统一用这一套，避免 Ant Design 实心/线框图标与设计稿的细线风格混排。
 * 外层沿用 `anticon` 类名，让 Menu、Button 等组件按原有图标位排版。</p>
 */
const PATHS = {
  layout: (
    <>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <path d="M3 9h18M9 9v12" />
    </>
  ),
  grid: (
    <>
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
      <rect x="14" y="14" width="7" height="7" rx="1" />
    </>
  ),
  bell: <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />,
  settings: (
    <>
      <path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z" />
      <path d="M19.4 15a1.8 1.8 0 0 0 .36 2l-1.73 1.73a1.8 1.8 0 0 0-2-.36l-1.4.58a1.8 1.8 0 0 0-1.08 1.65h-2.45a1.8 1.8 0 0 0-1.08-1.65l-1.4-.58a1.8 1.8 0 0 0-2 .36L4.9 17a1.8 1.8 0 0 0 .36-2l-.58-1.4A1.8 1.8 0 0 0 3 12.5v-2A1.8 1.8 0 0 0 4.68 9.4l.58-1.4a1.8 1.8 0 0 0-.36-2l1.73-1.73a1.8 1.8 0 0 0 2 .36l1.4-.58A1.8 1.8 0 0 0 11.1 2.4h2.45a1.8 1.8 0 0 0 1.08 1.65l1.4.58a1.8 1.8 0 0 0 2-.36L19.76 6a1.8 1.8 0 0 0-.36 2l.58 1.4a1.8 1.8 0 0 0 1.65 1.08v2.45a1.8 1.8 0 0 0-1.65 1.08Z" />
    </>
  ),
  code: <path d="m8 8-4 4 4 4m8-8 4 4-4 4m-3-11-4 14" />,
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="m16 16 5 5" />
    </>
  ),
  down: <path d="m6 9 6 6 6-6" />,
  plus: <path d="M12 5v14M5 12h14" />,
  spark: <path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5L12 2Z" />,
  layers: <path d="m12 3 9 5-9 5-9-5 9-5Zm-9 9 9 5 9-5m-18 5 9 5 9-5" />,
  package: <path d="m12 2 9 5v10l-9 5-9-5V7l9-5Zm-9 5 9 5 9-5m-9 5v10" />,
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </>
  ),
  activity: <path d="M3 12h4l3-7 4 14 3-7h4" />,
  arrow: <path d="M5 12h14m-6-6 6 6-6 6" />,
  external: <path d="M7 17 17 7M8 7h9v9" />,
  message: <path d="M4 4h16v12H8l-4 4V4Z" />,
  shield: <path d="m12 2 9 4v6c0 5-4 8-9 10-5-2-9-5-9-10V6l9-4Zm-4 10 3 3 5-6" />,
  user: (
    <>
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21a8 8 0 0 1 16 0" />
    </>
  ),
  clipboard: (
    <>
      <rect x="4" y="5" width="16" height="17" rx="2" />
      <path d="M9 3h6v4H9zM8 12h8m-8 4h7" />
    </>
  ),
  terminal: (
    <>
      <rect x="2" y="3" width="20" height="18" rx="2" />
      <path d="m6 9 4 3-4 3m7 1h5" />
    </>
  ),
} as const;

export type LineIconName = keyof typeof PATHS;

export default function LineIcon({
  name,
  size = '1em',
  className,
  style,
}: {
  name: LineIconName;
  size?: number | string;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <span
      role="img"
      aria-hidden="true"
      className={`anticon kaiwu-line-icon${className ? ` ${className}` : ''}`}
      style={style}
    >
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.7}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        {PATHS[name]}
      </svg>
    </span>
  );
}
</#noparse>