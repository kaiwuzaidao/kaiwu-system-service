<#noparse>import type { ReactNode } from 'react';
import ProjectAccessProvider, { useProjectAccess } from './ProjectAccessProvider';
import { gotoPlatform, platformLogout } from './platform';
export { default as ProjectAccessProvider, useProjectAccess } from './ProjectAccessProvider';
export { requestJson as kaiwuRequest } from './request';
export { default as useDict } from './useManagedDictionary';
export { default as useProjectConfig } from './useProjectConfig';
export { default as useProjectId } from './useProjectId';
export type { ProjectNavigationMenu } from './ProjectAccessProvider';
export * from './platform';
export { useAccessTokenVersion, currentAccessToken, whenAccessTokenSettled } from './accessToken';
export { readProjectId } from './useProjectId';
export {
  useProjectConfigNumber,
  useProjectConfigBoolean,
  useProjectConfigs,
} from './useProjectConfig';

export function rootContainer(container: ReactNode) {
  return <ProjectAccessProvider>{container}</ProjectAccessProvider>;
}

export function useCan(permission: string) {
  return useProjectAccess().permissions.has(permission);
}
export function Can({ permission, children }: { permission: string; children: ReactNode }) {
  return useCan(permission) ? <>{children}</> : null;
}
export function useKaiwuSession() {
  return {
    returnToPlatform: () => gotoPlatform('/'),
    logout: async () => {
      try {
        await platformLogout();
      } finally {
        gotoPlatform('/login');
      }
    },
  };
}
</#noparse>
