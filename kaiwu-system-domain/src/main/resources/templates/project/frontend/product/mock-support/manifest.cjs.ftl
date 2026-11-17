<#noparse>const { existsSync, readFileSync } = require('node:fs');
const { join } = require('node:path');
const { safeLoad, JSON_SCHEMA } = require('js-yaml');
function readManifest(name) {
  const project = require('../docs/kaiwu-project-blueprint.json');
  const dirs = [
    process.env.KAIWU_SERVICE_DIR,
    join('..', project.projectCode + '-service'),
    join('..', 'kaiwu-' + project.projectCode + '-service'),
  ].filter(Boolean);
  const file = dirs.map((dir) => join(dir, 'kaiwu', name + '.yml')).find(existsSync);
  if (name === 'roles') {
    const roles = file ? safeLoad(readFileSync(file, 'utf8'), { schema: JSON_SCHEMA }) : [];
    return ['editor', 'reader'].map(
      (roleCode) =>
        roles.find((r) => r.roleCode === roleCode) ?? {
          roleCode,
          routes: project.modules.map((m) => '/' + m.moduleCode),
          permissions: project.modules.flatMap((m) =>
            (roleCode === 'reader' ? ['list'] : ['list', 'save', 'delete']).map(
              (a) => m.permissionPrefix + ':' + a,
            ),
          ),
        },
    );
  }
  if (!file)
    return name === 'menus'
      ? project.modules.map((m) => ({ type: 'MENU', path: '/' + m.moduleCode, name: m.moduleCode }))
      : [];
  const value = safeLoad(readFileSync(file, 'utf8'), { schema: JSON_SCHEMA });
  if (!Array.isArray(value)) throw new Error(file + ' 必须是列表');
  return value;
}
function label(value) {
  return typeof value === 'object' && value ? String(value['zh-CN'] || '') : String(value ?? '');
}
module.exports = { readManifest, label };
</#noparse>
