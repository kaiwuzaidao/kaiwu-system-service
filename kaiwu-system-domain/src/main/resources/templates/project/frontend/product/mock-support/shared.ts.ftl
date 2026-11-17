<#noparse>import type { Request, Response } from './http';
import { readManifest, label } from './manifest.cjs';
export type { Request, Response };
export const people = [
  { id: '10001', key: 'editor', role: 'editor', name: '编辑人员' },
  { id: '10002', key: 'reader', role: 'reader', name: '只读人员' },
];
export function actor(req: Request) {
  const key = /(?:^|;\s*)kaiwu_mock_role=([^;]+)/.exec(req.headers.cookie || '')?.[1];
  const person = people.find((item) => item.key === key);
  const role = person && readManifest('roles').find((item: any) => item.roleCode === person.role);
  return role
    ? {
        ...person!,
        permissions: new Set<string>(role.permissions || []),
        routes: new Set<string>(role.routes || []),
        directories: new Set<string>(role.directories || []),
      }
    : undefined;
}
export function ok(res: Response, data: unknown = null) {
  return res.json({ code: 0, data });
}
export function fail(res: Response, code: number, message: string, messageKey?: string) {
  return res.status(code).json({ code, message, messageKey, data: null });
}
export type Actor = NonNullable<ReturnType<typeof actor>>;
export function signed(handler: (req: Request, res: Response, user: Actor) => unknown) {
  return (req: Request, res: Response) => {
    try {
      const user = actor(req);
      if (!user) return fail(res, 401, '请选择演示身份');
      return handler(req, res, user);
    } catch {
      return fail(res, 500, '演示清单无效，请检查 kaiwu 目录后重试');
    }
  };
}
export { readManifest, label };
</#noparse>
