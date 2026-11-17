import { kaiwuRequest } from '@/kaiwu';
import { currentAccessToken, whenAccessTokenSettled } from '@/kaiwu';
import { readProjectId } from '@/kaiwu';

/**
 * 本项目「文件」管理页接口（kaiwu-system-starter 提供，数据在本项目自己的库里，ADR 0041）。
 *
 * 与业务接口一样走本项目的网关前缀；权限码 `file:record:*` 由平台在创建项目时随菜单种入。
 */
const API_BASE = '/${projectCode}-api/api/files';
<#noparse>
export type ProjectFile = {
  id: string;
  originalName: string;
  contentType: string;
  sizeBytes: number;
  bizType: string;
  bizId?: string;
  uploaderId: string;
  createdAt: string;
};

export type ProjectFilePage = {
  records: ProjectFile[];
  total: number;
  current: number;
  size: number;
};

export type FileDownload = { url: string; direct: boolean; name: string };

function toQuery(params: Record<string, unknown>): string {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') search.append(key, String(value));
  });
  return search.toString();
}

export function queryProjectFiles(params: Record<string, unknown>) {
  return kaiwuRequest<ProjectFilePage>(`${API_BASE}?${toQuery(params)}`);
}

export function deleteProjectFile(id: string) {
  return kaiwuRequest<void>(`${API_BASE}/${encodeURIComponent(id)}`, { method: 'DELETE' });
}

export function queryFileDownload(id: string) {
  return kaiwuRequest<FileDownload>(`${API_BASE}/${encodeURIComponent(id)}/download`);
}

/**
 * 存储不支持预签名时的中转下载：带登录态取回内容，由浏览器保存。
 * 直连地址不需要登录态，调用方直接打开即可。
 */
export async function downloadRelayedFile(download: FileDownload): Promise<void> {
  await whenAccessTokenSettled();
  const headers = new Headers();
  const token = currentAccessToken();
  if (token) headers.set('Authorization', `Bearer ${token}`);
  const projectId = readProjectId();
  if (projectId) headers.set('X-Project-Id', projectId);
  // 中转地址由 Starter 返回为 /api/files/{id}/content，补上本项目的网关前缀。
  const path = download.url.startsWith('/api/')
    ? `${API_BASE.replace(/\/api\/files$/, '')}${download.url}`
    : download.url;
  const response = await fetch(path, { headers });
  if (!response.ok) throw new Error(`下载失败（HTTP ${response.status}）`);
  const objectUrl = URL.createObjectURL(await response.blob());
  const link = document.createElement('a');
  link.href = objectUrl;
  link.download = download.name;
  link.click();
  URL.revokeObjectURL(objectUrl);
}
</#noparse>
