<#noparse>#!/usr/bin/env node
/**
 * 校验页面没有绕过受管字典组件。
 *
 * 存在的意义：字典项是在 Kaiwu 平台配置的，页面一旦把状态映射硬编码进代码，
 * 平台改了字典页面不会跟着变，而且运行时看起来一切正常——这类退化只能靠静态检查发现。
 * 多个 AI 分别迭代同一个项目时，硬编码 valueEnum 是最常见的一种「各写各的」。
 *
 * 能力边界（有意为之）：字典的事实源在平台运行库，不在本仓库，因此这里**无法**校验
 * 某个 dictCode 是否真的在平台配置过。那属于平台侧的项目体检，不是仓库 CI 能做的事。
 * 本脚本只保证：页面走字典组件、dictCode 形状合法。
 *
 * 退出码：0 通过；1 发现问题。
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const srcDir = join(webRoot, 'src');
const pagesDir = join(srcDir, 'pages');

/** 字典码形状：`{模块}.{资源}_{用途}`，全小写点分。与平台受管字典保持一致。 */
const DICT_CODE = /^[a-z][a-z0-9_]*\.[a-z0-9_]+$/;

let failed = false;

function fail(title, items, hint) {
  failed = true;
  console.error(`[check:dict] ${title}`);
  items.forEach((item) => console.error(`  - ${item}`));
  if (hint) console.error(`  ${hint}`);
}

function walk(dir, visit) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry === 'dist' || entry.startsWith('.umi')) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      walk(full, visit);
    } else if (/\.tsx?$/.test(entry)) {
      visit(full, readFileSync(full, 'utf8'));
    }
  }
}

/**
 * 检查一：页面里不允许出现硬编码 valueEnum。
 *
 * ProTable 的 valueEnum 同时承担筛选项和渲染，是绕开字典最常见的入口。
 * 改法：筛选用 fieldProps.options 接 useManagedDictionary，渲染用 ManagedDictText。
 */
const valueEnumOffenders = [];
walk(pagesDir, (file, source) => {
  source.split('\n').forEach((line, index) => {
    if (/\bvalueEnum\s*:/.test(line)) {
      valueEnumOffenders.push(`${relative(webRoot, file)}:${index + 1}`);
    }
  });
});
if (valueEnumOffenders.length > 0) {
  fail(
    '页面存在硬编码 valueEnum，请改用受管字典：',
    valueEnumOffenders,
    '改法：fieldProps={{ options: useManagedDictionary(code).options }} ' +
      '+ <ManagedDictText dictCode=... />',
  );
}

/**
 * 检查二：dictCode 形状。
 * 写错的码在运行时表现为「字典没配」——页面原样显示机器值，不会报错，很难被发现。
 */
const badCodes = [];
walk(srcDir, (file, source) => {
  const patterns = [/dictCode=["']([^"']+)["']/g, /useManagedDictionary\(\s*["']([^"']+)["']/g];
  for (const pattern of patterns) {
    for (const match of source.matchAll(pattern)) {
      if (!DICT_CODE.test(match[1])) {
        badCodes.push(`${match[1]}  (${relative(webRoot, file)})`);
      }
    }
  }
});
if (badCodes.length > 0) {
  fail('字典码不符合 {module}.{resource} 小写点分格式：', badCodes);
}

if (!failed) {
  console.log('[check:dict] 页面未绕过受管字典组件，字典码格式合法。');
}
process.exit(failed ? 1 : 0);
</#noparse>
