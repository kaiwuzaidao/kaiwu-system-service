<#noparse>/**
 * 校验约束 `logging.no-sensitive-data`（MUST）的前端一侧。
 *
 * 生成后端已有 `SensitiveLoggingConventionTest`，前端此前没有任何门禁：
 * 浏览器控制台同样会被录屏、被前端监控 SDK 采集、被用户截图发到工单里，
 * 一次「加个 console.log 看看请求带了什么」就能把 token 或密码留在这些地方。
 *
 * 判定方式与后端一致，只卡两件明确的事：
 *
 *   1. `console.*` 的实参里出现以敏感词**结尾**的标识符/属性名
 *      （`rawPassword`、`accessToken` 命中；`credentialId`、`tokenType` 不命中——
 *      它们是 ID 和类型，不是凭据）。
 *   2. 字符串或模板串里写出 `password=`、`token:` 这类键名。
 *
 * 不卡「禁止一切 console」：`console.warn` 报告降级路径是正当用法，
 * 一个九成误报的规则只会让人学会忽略红灯。
 *
 * 判定依据是 TypeScript AST 而不是正则：模板串里的插值、以及注释里出现的 console，
 * 正则分不清。
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import ts from 'typescript';

const ROOT = process.cwd();
/**
 * 只扫会进浏览器的代码。`scripts/` 是构建期门禁工具，不接触凭据，
 * 但会出现 `checkedApiKeys` 这类「以敏感词结尾却与凭据无关」的变量名——
 * 为一个不承载风险的目录留误报，只会让人学会忽略红灯。
 */
const SCAN_DIRS = ['src', 'config'];
const SKIP_SEGMENTS = ['.umi', '.umi-production', 'node_modules', 'dist'];

/** 敏感词根：只在标识符结尾匹配。 */
const SENSITIVE_TAIL =
  /(password|passwd|secret|token|credential|privatekey|apikey|idcard|idnumber|phone|mobile|plaintext|ciphertext)s?$/i;

/** 字面量里直接写出的敏感键名，例如 `token=` 或 `"password":`。 */
const SENSITIVE_KEY =
  /(password|passwd|secret|token|credential|privatekey|apikey|idcard|idnumber)\s*[=:：]/i;

const problems = [];

function sourceFiles(relativeDir) {
  const directory = path.join(ROOT, relativeDir);
  if (!fs.existsSync(directory)) return [];
  return fs
    .readdirSync(directory, { recursive: true })
    .filter((name) => typeof name === 'string' && /\.(ts|tsx|mjs|js)$/.test(name))
    .map((name) => path.join(relativeDir, name))
    .filter((file) => !SKIP_SEGMENTS.some((segment) => file.split(path.sep).includes(segment)));
}

/** 是否是 console.xxx(...) 调用。 */
function isConsoleCall(node) {
  return (
    ts.isCallExpression(node) &&
    ts.isPropertyAccessExpression(node.expression) &&
    ts.isIdentifier(node.expression.expression) &&
    node.expression.expression.text === 'console'
  );
}

/** 实参里出现的敏感标识符/属性名。 */
function sensitiveNames(argument) {
  const found = [];
  const visit = (node) => {
    if (ts.isIdentifier(node) && SENSITIVE_TAIL.test(node.text)) {
      found.push(node.text);
    }
    if (ts.isPropertyAccessExpression(node) && SENSITIVE_TAIL.test(node.name.text)) {
      found.push(node.name.text);
    }
    ts.forEachChild(node, visit);
  };
  visit(argument);
  return found;
}

/** 实参里出现的敏感键名字面量。 */
function sensitiveLiterals(argument) {
  const found = [];
  const visit = (node) => {
    const text =
      ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)
        ? node.text
        : ts.isTemplateHead(node) || ts.isTemplateMiddle(node) || ts.isTemplateTail(node)
          ? node.text
          : null;
    if (text !== null && SENSITIVE_KEY.test(text)) {
      found.push(text.trim());
    }
    ts.forEachChild(node, visit);
  };
  visit(argument);
  return found;
}

for (const relativeDir of SCAN_DIRS) {
  for (const file of sourceFiles(relativeDir)) {
    const absolute = path.join(ROOT, file);
    const source = ts.createSourceFile(
      file,
      fs.readFileSync(absolute, 'utf8'),
      ts.ScriptTarget.Latest,
      true,
    );
    const visit = (node) => {
      if (isConsoleCall(node)) {
        const hits = node.arguments.flatMap((argument) => [
          ...sensitiveNames(argument),
          ...sensitiveLiterals(argument),
        ]);
        if (hits.length > 0) {
          const { line } = source.getLineAndCharacterOfPosition(node.getStart());
          problems.push(`${file}:${line + 1} → ${[...new Set(hits)].join(', ')}`);
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(source);
  }
}

if (problems.length > 0) {
  console.error('[check:log] 以下 console 调用可能写出凭据或敏感信息：');
  for (const problem of problems) console.error(`  - ${problem}`);
  console.error(
    '  请只输出标识、长度或掩码后的值（约束 logging.no-sensitive-data，MUST，不可豁免）。',
  );
  process.exit(1);
}

console.log('[check:log] 前端日志未发现凭据或敏感信息输出。');
</#noparse>
