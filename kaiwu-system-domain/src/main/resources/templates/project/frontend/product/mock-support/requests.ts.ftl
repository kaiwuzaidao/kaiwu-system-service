<#noparse>import project from '../docs/kaiwu-project-blueprint.json';
import { signed, ok, fail, type Request, type Response } from './shared';
type Item = Record<string, unknown>;
type Module = {
  apiPath: string;
  primaryKey: string;
  permissionPrefix: string;
  moduleCode: string;
  accessScope: string;
};
const stores = new Map<string, Map<string, { owner: string; data: Item }>>();
let serial = 0;
export function reset() {
  for (const store of stores.values()) store.clear();
  serial = 0;
}
export const requests: Record<string, (req: Request, res: Response) => unknown> = {};
for (const mod of project.modules as Module[]) {
  const base = '/' + project.projectCode + '-api' + mod.apiPath;
  const store = new Map<string, { owner: string; data: Item }>();
  stores.set(base, store);
  for (const [method, permission] of [
    ['GET', 'list'],
    ['POST', 'save'],
    ['PUT', 'save'],
    ['DELETE', 'delete'],
  ]) {
    const item = method === 'PUT' || method === 'DELETE';
    requests[method + ' ' + base + (item ? '/:id' : '')] = signed((req, res, user) => {
      if (!user.permissions.has(mod.permissionPrefix + ':' + permission))
        return fail(res, 403, '没有操作权限');
      const visible = (row: { owner: string }) =>
        mod.accessScope === 'PROJECT_WIDE' || row.owner === user.id;
      if (method === 'GET') {
        const current = Number(req.query.current ?? 1),
          size = Number(req.query.size ?? 10);
        if (
          !Number.isSafeInteger(current) ||
          !Number.isSafeInteger(size) ||
          current < 1 ||
          size < 1 ||
          size > 100
        )
          return fail(res, 400, '分页参数无效');
        const rows = [...store.values()].filter(visible).map((row) => row.data);
        return ok(res, {
          records: rows.slice((current - 1) * size, current * size),
          total: rows.length,
        });
      }
      const id = item ? req.params.id : String(++serial);
      const previous = store.get(id);
      if (item && (!previous || !visible(previous))) return fail(res, 404, '记录不存在');
      if (method === 'DELETE') store.delete(id);
      else
        store.set(id, {
          owner: previous?.owner ?? user.id,
          data: { ...req.body, [mod.primaryKey]: id },
        });
      return ok(res);
    });
  }
}
</#noparse>
