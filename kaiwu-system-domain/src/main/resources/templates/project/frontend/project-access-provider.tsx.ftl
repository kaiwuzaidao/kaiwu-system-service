<#noparse>import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import useProjectId from '@/hooks/useProjectId';
import { requestJson } from '@/services/request';
import { useAccessTokenVersion, useHostAccessBridge } from '@/utils/accessToken';
import { getLocale, setLocale } from '@umijs/max';

const EMPTY_PERMISSIONS: ReadonlySet<string> = new Set<string>();

export interface ProjectNavigationMenu {
  id: string;
  menuName: string;
  menuNameKey?: string;
  menuType: string;
  routePath?: string;
  permissionCode?: string;
  visible: boolean;
  status: string;
  children?: ProjectNavigationMenu[];
}
interface ProjectAccessValue {
  projectId: string;
  permissions: ReadonlySet<string>;
  menus: ProjectNavigationMenu[];
  loading: boolean;
  error?: string;
  retry: () => void;
}

export const ProjectAccessContext = createContext<ProjectAccessValue>({
  projectId: '',
  permissions: EMPTY_PERMISSIONS,
  menus: [],
  loading: false,
  retry: () => undefined,
});

type AccessPayload =
  string[] | { permissions?: string[]; menus?: ProjectNavigationMenu[]; userLocale?: string };

/** 平台已发布的语言；未知值一律回落默认，不做半翻译。 */
// 与 docs/kaiwu-project-blueprint.json 的 supportedLocales 保持一致。
const SUPPORTED_LOCALES = ['zh-CN'] as const;
const DEFAULT_LOCALE = 'zh-CN';

function normalizeLocale(value?: string): string {
  return SUPPORTED_LOCALES.includes(value as never) ? (value as string) : DEFAULT_LOCALE;
}

export function useProjectAccess(): ProjectAccessValue {
  return useContext(ProjectAccessContext);
}

export default function ProjectAccessProvider({
  children,
}: {
  children: ReactNode;
}): React.ReactElement {
  useHostAccessBridge();
  const tokenVersion = useAccessTokenVersion();
  const projectId = useProjectId();
  const [permissions, setPermissions] = useState<ReadonlySet<string>>(EMPTY_PERMISSIONS);
  const [menus, setMenus] = useState<ProjectNavigationMenu[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>();
  const [attempt, setAttempt] = useState(0);
  const retry = useCallback(() => setAttempt((value) => value + 1), []);

  useEffect(() => {
    let active = true;
    setError(undefined);
    setMenus([]);
    if (!projectId) {
      setPermissions(EMPTY_PERMISSIONS);
      setLoading(false);
      return () => {
        active = false;
      };
    }
    setPermissions(EMPTY_PERMISSIONS);
    setLoading(true);
    void requestJson<AccessPayload>(
      `/api/current/projects/${encodeURIComponent(projectId)}/access`,
      { projectId },
    )
      .then((payload) => {
        if (!active) return;
        setMenus(!Array.isArray(payload) && Array.isArray(payload.menus) ? payload.menus : []);
        const values = Array.isArray(payload) ? payload : payload.permissions;
        setPermissions(new Set(Array.isArray(values) ? values : []));
        // 语言跟随平台账户偏好：本前端嵌在平台里，自建语言状态会出现
        // 平台英文、内嵌页面中文的割裂，也会让用户切两次。
        if (!Array.isArray(payload)) {
          const next = normalizeLocale(payload.userLocale);
          if (getLocale() !== next) {
            setLocale(next, false);
          }
        }
      })
      .catch(() => {
        if (active) {
          setPermissions(EMPTY_PERMISSIONS);
          setError('project.access.failed');
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [projectId, tokenVersion, attempt]);

  const value = useMemo(
    () => ({ projectId, permissions, menus, loading, error, retry }),
    [projectId, permissions, menus, loading, error, retry],
  );
  return <ProjectAccessContext.Provider value={value}>{children}</ProjectAccessContext.Provider>;
}
</#noparse>