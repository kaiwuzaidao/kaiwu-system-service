<#noparse>import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';

import { posix } from 'node:path';
import ts from 'typescript';
// 新版清单标明摘要算法，同时读取早期版本的裸 SHA-256。
const expected = JSON.parse(readFileSync('docs/kaiwu-integration-lock.json', 'utf8'), (_, value) =>
  typeof value === 'string' ? value.replace(/^sha256:/, '') : value,
);
const actual = {};
for (const file of readdirSync('src/kaiwu', { withFileTypes: true })) {
  assert(file.isFile(), '接入层只包含模板交付的文件');
  const contents = readFileSync('src/kaiwu/' + file.name, 'utf8').replace(/\r\n/g, '\n');
  actual[file.name] = createHash('sha256').update(contents).digest('hex');
}
assert.deepEqual(
  actual,
  expected,
  '接入层已偏离模板。业务修改放在 pages、components 或 services，平台升级时一起更新接入层和基线。',
);

const shims = new Map(
  Object.entries({
    'hooks/useManagedDictionary': 'useManagedDictionary',
    'hooks/useProjectConfig': 'useProjectConfig',
    'hooks/useProjectId': 'useProjectId',
    'providers/ProjectAccessProvider': 'ProjectAccessProvider',
    'utils/accessToken': 'accessToken',
    'services/request': 'request',
    'services/platform': 'platform',
  }),
);
function checkImports(dir) {
  for (const entry of readdirSync(posix.join('src', dir), { withFileTypes: true })) {
    if (entry.name.startsWith('.') || (dir === '.' && entry.name === 'kaiwu')) continue;
    const path = posix.join(dir, entry.name);
    if (entry.isDirectory()) {
      checkImports(path);
      continue;
    }
    if (!/\.tsx?$/.test(path)) continue;
    const source = readFileSync('src/' + path, 'utf8');
    const shim = shims.get(path.replace(/\.tsx?$/, ''));
    if (shim) {
      for (const line of source.trim().split(/\r?\n/)) {
        assert(
          [
            "export * from '@/kaiwu/" + shim + "';",
            "export { default } from '@/kaiwu/" + shim + "';",
          ].includes(line),
          path + ' 是兼容导出',
        );
      }
      continue;
    }
    for (const { fileName } of ts.preProcessFile(source, true, true).importedFiles) {
      if (fileName === '@/kaiwu') continue;
      const resolved = fileName.startsWith('@/')
        ? fileName.slice(2)
        : fileName.startsWith('.')
          ? posix.join(posix.dirname(path), fileName)
          : undefined;
      if (!resolved) continue;
      const stem = resolved.replace(/\.tsx?$/, '').replace(/\/index$/, '');
      assert(
        stem !== 'kaiwu' && !stem.startsWith('kaiwu/') && !shims.has(stem),
        path + ' 请通过 @/kaiwu 接入平台：' + fileName,
      );
    }
  }
}
checkImports('.');
</#noparse>
