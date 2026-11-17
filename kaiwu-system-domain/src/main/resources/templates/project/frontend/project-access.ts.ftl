<#noparse>import { kaiwuRequest } from '@/kaiwu';

/**
 * 本项目的成员与角色授权接口（平台提供）。
 *
 * 走平台 Gateway 的 `/api/current/projects/{projectId}/access-admin`，权限由平台按调用者在本项目里的
 * `access:member:*` / `access:role:*` 判定，与业务自身的 `-api` 前缀区分开。
 */

export type AccessMember = {
  userId: string;
  username: string;
  displayName?: string;
  status: 'ACTIVE' | 'DISABLED';
  roleIds: string[];
};

export type AccessCandidate = {
  userId: string;
  username: string;
  displayName?: string;
};

export type AccessRole = {
  id: string;
  roleCode: string;
  roleName: string;
  description?: string;
  status: 'ACTIVE' | 'DISABLED';
  builtIn: boolean;
  menuIds: string[];
};

export type AccessMenu = {
  id: string;
  menuName: string;
  menuType: 'DIRECTORY' | 'MENU' | 'BUTTON';
  permissionCode?: string;
  children?: AccessMenu[];
};

function base(projectId: string): string {
  return `/api/current/projects/${encodeURIComponent(projectId)}/access-admin`;
}

export function queryAccessMembers(projectId: string) {
  return kaiwuRequest<AccessMember[]>(`${base(projectId)}/members`, { projectId });
}

export function searchAccessCandidates(projectId: string, keyword: string) {
  return kaiwuRequest<AccessCandidate[]>(
    `${base(projectId)}/members/candidates?keyword=${encodeURIComponent(keyword)}`,
    { projectId },
  );
}

export function saveAccessMember(
  projectId: string,
  userId: string,
  body: { roleIds: string[]; status: 'ACTIVE' | 'DISABLED' },
) {
  return kaiwuRequest<AccessMember[]>(`${base(projectId)}/members/${encodeURIComponent(userId)}`, {
    projectId,
    method: 'PUT',
    body: JSON.stringify(body),
  });
}

export function deleteAccessMember(projectId: string, userId: string) {
  return kaiwuRequest<void>(`${base(projectId)}/members/${encodeURIComponent(userId)}`, {
    projectId,
    method: 'DELETE',
  });
}

export function queryAccessRoles(projectId: string) {
  return kaiwuRequest<AccessRole[]>(`${base(projectId)}/roles`, { projectId });
}

export function queryAccessMenus(projectId: string) {
  return kaiwuRequest<AccessMenu[]>(`${base(projectId)}/menus`, { projectId });
}

export function createAccessRole(
  projectId: string,
  body: { roleCode: string; roleName: string; description?: string },
) {
  return kaiwuRequest<AccessRole>(`${base(projectId)}/roles`, {
    projectId,
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export function updateAccessRole(
  projectId: string,
  roleId: string,
  body: { roleName: string; description?: string },
) {
  return kaiwuRequest<AccessRole>(`${base(projectId)}/roles/${encodeURIComponent(roleId)}`, {
    projectId,
    method: 'PUT',
    body: JSON.stringify(body),
  });
}

export function updateAccessRoleStatus(
  projectId: string,
  roleId: string,
  status: 'ACTIVE' | 'DISABLED',
) {
  return kaiwuRequest<AccessRole>(`${base(projectId)}/roles/${encodeURIComponent(roleId)}/status`, {
    projectId,
    method: 'PUT',
    body: JSON.stringify({ status }),
  });
}

export function grantAccessRoleMenus(projectId: string, roleId: string, menuIds: string[]) {
  return kaiwuRequest<AccessRole>(`${base(projectId)}/roles/${encodeURIComponent(roleId)}/menus`, {
    projectId,
    method: 'PUT',
    body: JSON.stringify({ menuIds }),
  });
}

export function deleteAccessRole(projectId: string, roleId: string) {
  return kaiwuRequest<void>(`${base(projectId)}/roles/${encodeURIComponent(roleId)}`, {
    projectId,
    method: 'DELETE',
  });
}
</#noparse>
