<#noparse>import type { Request, Response } from './shared';
import { people, ok, fail, signed, readManifest, label, type Actor } from './shared';
import { reset } from './requests';
import blueprint from '../docs/kaiwu-project-blueprint.json';
const base = '/apps/' + blueprint.projectCode + '/';
const pid = 'mock-project';
function navigation(items: any[], user: Actor, parent = ''): any[] {
  return items.flatMap((item, index) => {
    const id = parent + '/' + index;
    const children = navigation(item.children || [], user, id);
    const allowed =
      item.type === 'BUTTON'
        ? user.permissions.has(item.permission)
        : user.routes.has(item.path) ||
          user.directories.has('dir:' + label(item.name)) ||
          children.length > 0;
    return allowed
      ? [
          {
            id,
            menuName: label(item.name ?? item.permission),
            menuType: item.type,
            visible: true,
            status: 'ACTIVE',
            routePath: item.path,
            permissionCode: item.permission,
            children,
          },
        ]
      : [];
  });
}
export const platform = {
  'GET /api/auth/me': signed((_req, res, user) =>
    ok(res, { id: user.id, username: user.key, displayName: user.name, locale: 'zh-CN' }),
  ),
  'POST /api/auth/logout': (_req: Request, res: Response) => {
    res.clearCookie('kaiwu_mock_role', { path: '/' });
    return ok(res);
  },
  'GET /api/current/projects': signed((_req, res) =>
    ok(res, [
      {
        id: pid,
        projectCode: blueprint.projectCode,
        projectName: blueprint.projectName,
        status: 'ACTIVE',
        backendUrl: base + '?projectId=' + pid,
      },
    ]),
  ),
  ['GET /api/current/projects/' + pid + '/access']: signed((_req, res, user) =>
    ok(res, {
      permissions: [...user.permissions],
      menus: navigation(readManifest('menus'), user),
      userLocale: 'zh-CN',
    }),
  ),
  ['GET /api/current/projects/' + pid + '/dicts/:code']: signed((req, res) => {
    const dict = readManifest('dicts').find((d: any) => d.dictCode === req.params.code);
    return ok(
      res,
      (dict?.items || []).map((v: any, i: number) => ({
        itemValue: v.value,
        itemLabel: label(v.label),
        color: v.color,
        sortNo: v.sort ?? i * 10,
        status: 'ENABLED',
      })),
    );
  }),
  ['GET /api/current/projects/' + pid + '/configs']: signed((_req, res) =>
    ok(
      res,
      readManifest('configs').map((c: any) => ({
        key: c.key,
        value: c.default,
        valueType: c.type,
      })),
    ),
  ),
  'GET /api/search': signed((_req, res) => ok(res, [])),
  'GET /api/current/notifications/summary': signed((_req, res) => ok(res, { unread: 0 })),
  'GET /api/current/notifications': signed((_req, res) => ok(res, { records: [], total: 0 })),
  'POST /api/current/notifications/read-all': signed((_req, res) => ok(res, 0)),
  'GET /api/current/todos': signed((_req, res) => ok(res, { records: [], total: 0 })),
};
const choose = (_req: Request, res: Response) => res.redirect('/__mock/');
export const panel = {
  'GET /': choose,
  'GET /login': choose,
  'GET /profile': choose,
  'GET /__mock/': (_req: Request, res: Response) =>
    res
      .type('html')
      .send(
        '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>选择演示身份</title><style>body{font:16px system-ui;color:#172c45;max-width:38rem;margin:12vh auto;padding:1rem}button{font:inherit;margin:0 .6rem .6rem 0;padding:.6rem 1rem;cursor:pointer}</style><h1>选择演示身份</h1><p>本地演示环境，所有数据都是模拟的。</p><form method="post" action="/__mock/role">' +
          people
            .map((p) => '<button name="role" value="' + p.key + '">' + p.name + '</button>')
            .join('') +
          '</form><form method="post" action="/__mock/reset"><button>重置演示数据</button></form></html>',
      ),
  'POST /__mock/role': (req: Request, res: Response) => {
    const user = people.find((p) => p.key === req.body?.role);
    if (!user) return fail(res, 400, '未知演示身份');
    res.cookie('kaiwu_mock_role', user.key, {
      path: '/',
      httpOnly: true,
      sameSite: 'strict',
      maxAge: 28800000,
    });
    return res.redirect(303, base + '?projectId=' + pid);
  },
  'POST /__mock/reset': (_req: Request, res: Response) => {
    reset();
    return res.redirect(303, '/__mock/');
  },
};
export const fallback: Record<string, (req: Request, res: Response) => unknown> = {};
for (const prefix of [
  '/api',
  '/' + blueprint.projectCode + '-api',
  '/' + blueprint.projectCode + '-svc',
]) {
  for (const method of ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD']) {
    fallback[method + ' ' + prefix] = fallback[method + ' ' + prefix + '/(.*)'] = (_req, res) =>
      fail(res, 501, '此接口在演示中不可用', 'mock.notImplemented');
  }
}
</#noparse>
