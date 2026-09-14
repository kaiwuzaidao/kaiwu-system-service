<#noparse>#!/usr/bin/env node
/**
 * 校验前端权限码符合「权限三端同码」约定：前端按钮、后端 @RequirePermission、
 * sql/menu.sql 的 BUTTON seed 必须是同一个 `{module}:{resource}:{action}`。
 *
 * 存在的意义：权限码写错在运行时看不出来。
 *   - 前端写错 → 按钮对所有人隐藏，表现为「我没权限」而不是「代码写错了」。
 *   - 前端编造一个后端不校验的码 → 前端以为自己在管权限，后端其实对所有人放行。
 * 这个脚本把这两类沉默失败变成 CI 红灯。
 *
 * 前后端是两个独立仓库，CI 里看不到对方，因此分两档校验：
 *   - 默认：与 docs/kaiwu-project-blueprint.json 声明的模块前缀比对。
 *     同一模块下新增 action（如 :export）不需要改任何契约文件；
 *     新增模块必须把 permissionPrefix 登记进该文件，这是有意的显式动作。
 *   - 后端仓库在旁边（KAIWU_SERVICE_DIR，或按 kaiwu-{projectCode}-service 平级定位）时
 *     升级为与真实注解和 menu.sql 逐码比对。
 *
 * 退出码：0 通过；1 发现不一致。
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const frontendSrc = join(webRoot, 'src');
const manifestFile = join(webRoot, 'docs/kaiwu-project-blueprint.json');

/** 权限码形状：三段，全小写，中间用冒号。与平台 System 保持同一条正则。 */
const CODE = /^[a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+$/;

let failed = false;

function fail(title, items, hint) {
  failed = true;
  console.error(`[check:perm] ${title}`);
  items.forEach((item) => console.error(`  - ${item}`));
  if (hint) console.error(`  ${hint}`);
}

function walk(dir, test, visit) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry === 'dist' || entry.startsWith('.umi')) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      walk(full, test, visit);
    } else if (test(entry)) {
      visit(full, readFileSync(full, 'utf8'));
    }
  }
}

/** 前端权限码：覆盖 PermissionButton 的 permission 属性与 access 判断两种用法。 */
function readFrontendCodes() {
  const found = new Map();
  const patterns = [
    /permission=["']([^"']+)["']/g,
    /permissions\.includes\(\s*["']([^"']+)["']/g,
    /hasPermission\(\s*["']([^"']+)["']/g,
  ];
  walk(
    frontendSrc,
    (name) => /\.tsx?$/.test(name),
    (file, source) => {
      for (const pattern of patterns) {
        for (const match of source.matchAll(pattern)) {
          if (!found.has(match[1])) found.set(match[1], relative(webRoot, file));
        }
      }
    },
  );
  return found;
}

function readManifest() {
  if (!existsSync(manifestFile)) {
    fail(
      '缺少 docs/kaiwu-project-blueprint.json：',
      [relative(webRoot, manifestFile)],
      '该文件是前后端共享的模块与权限契约，不得删除；新增模块时往 modules 里追加一条。',
    );
    return null;
  }
  try {
    return JSON.parse(readFileSync(manifestFile, 'utf8'));
  } catch (error) {
    fail('docs/kaiwu-project-blueprint.json 不是合法 JSON：', [String(error)]);
    return null;
  }
}

/** 后端仓库里的 @RequirePermission 与 menu.sql seed；缺任一目录返回 null 表示无法比对。 */
function readBackendCodes(serviceDir) {
  const javaRoots = readdirSync(serviceDir)
    .filter((entry) => entry.endsWith('-domain'))
    .map((entry) => join(serviceDir, entry, 'src/main/java'))
    .filter((path) => existsSync(path));
  if (javaRoots.length === 0) return null;

  const annotated = new Map();
  for (const root of javaRoots) {
    walk(
      root,
      (name) => name.endsWith('.java'),
      (file, source) => {
        for (const match of source.matchAll(/@RequirePermission\(\s*"([^"]+)"/g)) {
          if (!annotated.has(match[1])) annotated.set(match[1], relative(serviceDir, file));
        }
      },
    );
  }

  const menuFile = join(serviceDir, 'sql/menu.sql');
  const seeded = new Set();
  if (existsSync(menuFile)) {
    // 按「三段冒号字面量」提取，不绑定某种 INSERT 写法——列顺序和换行在后续迁移里会变。
    for (const match of readFileSync(menuFile, 'utf8').matchAll(
      /['"]([a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+)['"]/g,
    )) {
      seeded.add(match[1]);
    }
  }
  return { annotated, seeded, hasMenuFile: existsSync(menuFile) };
}

const frontend = readFrontendCodes();

// 检查一：格式。格式错的码永远匹配不上任何后端权限，且不会有任何报错。
const malformed = [...frontend]
  .filter(([code]) => !CODE.test(code))
  .map(([code, where]) => `${code}  (${where})`);
if (malformed.length > 0) {
  fail('权限码不符合 {module}:{resource}:{action} 格式：', malformed);
}

const wellFormed = [...frontend].filter(([code]) => CODE.test(code));
const manifest = readManifest();

if (manifest) {
  const declared = new Set(
    (manifest.modules ?? []).map((module) => module.permissionPrefix).filter(Boolean),
  );
  // 检查二：模块前缀必须已在契约中登记。
  // 同模块新增 action 自动通过；新模块必须显式登记，避免前端单方面发明权限。
  const undeclared = wellFormed
    .filter(([code]) => !declared.has(code.split(':').slice(0, 2).join(':')))
    .map(([code, where]) => `${code}  (${where})`);
  if (undeclared.length > 0) {
    fail(
      '权限码的模块前缀未在 docs/kaiwu-project-blueprint.json 登记：',
      undeclared,
      '改法：确认拼写；确属新模块时，往 modules 追加 ' +
        '{"table":"...","moduleCode":"...","permissionPrefix":"mod:res"}，' +
        '并同步补后端 @RequirePermission 与 sql/menu.sql 的 BUTTON seed。',
    );
  }
}

// 检查三：后端仓库在旁边时，升级为逐码比对。
const serviceDir = process.env.KAIWU_SERVICE_DIR
  ? resolve(process.env.KAIWU_SERVICE_DIR)
  : manifest?.projectCode
    ? resolve(webRoot, `../kaiwu-${manifest.projectCode}-service`)
    : null;

if (!serviceDir || !existsSync(serviceDir)) {
  console.log(
    '[check:perm] 后端仓库不在旁边，仅完成格式与契约登记校验；' +
      '设置 KAIWU_SERVICE_DIR 可启用逐码比对。',
  );
  process.exit(failed ? 1 : 0);
}

const backend = readBackendCodes(serviceDir);
if (!backend) {
  console.log(`[check:perm] 未在 ${serviceDir} 找到 *-domain 源码目录，跳过逐码比对。`);
  process.exit(failed ? 1 : 0);
}

// 前端在用、后端无注解：前端管了一个后端不校验的权限，接口实际对所有人开放。
const notEnforced = wellFormed
  .filter(([code]) => !backend.annotated.has(code))
  .map(([code, where]) => `${code}  (前端 ${where})`);
if (notEnforced.length > 0) {
  fail(
    '前端在用、后端无 @RequirePermission（接口实际未受保护）：',
    notEnforced,
    '改法：给对应 Controller 方法加注解，或修正前端权限码拼写。',
  );
}

// 后端有注解、menu.sql 无 seed：全新库里管理员看不到这个按钮，无法授权给任何角色。
if (backend.hasMenuFile) {
  const unseeded = [...backend.annotated]
    .filter(([code]) => !backend.seeded.has(code))
    .map(([code, where]) => `${code}  (后端 ${where})`);
  if (unseeded.length > 0) {
    fail(
      '后端有注解、sql/menu.sql 无 BUTTON seed（管理员无法授权，功能不可用）：',
      unseeded,
      '改法：在 sql/menu.sql 补 BUTTON 节点并导入平台库；' +
        '只在运行库里手工建菜单不算数，全新安装复现不出来。',
    );
  }
}

if (!failed) {
  console.log(
    `[check:perm] 权限三端一致：前端 ${frontend.size} 个权限码与后端注解、` +
      'menu.sql seed 全部对齐。',
  );
}
process.exit(failed ? 1 : 0);
</#noparse>
