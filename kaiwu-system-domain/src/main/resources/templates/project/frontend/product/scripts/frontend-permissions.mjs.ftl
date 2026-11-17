<#noparse>import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import ts from 'typescript';

export function frontendPermissions(root) {
  const found = new Map();
  function walk(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const file = join(dir, entry.name);
      if (entry.isDirectory()) walk(file);
      else if (/\.tsx?$/.test(file)) {
        const source = ts.createSourceFile(
          file,
          readFileSync(file, 'utf8'),
          ts.ScriptTarget.Latest,
          true,
        );
        function record(value) {
          if (value && ts.isStringLiteralLike(value)) found.set(value.text, file);
        }
        function visit(node) {
          if (ts.isCallExpression(node)) {
            const fn = node.expression;
            if (ts.isIdentifier(fn) && ['useCan', 'hasPermission'].includes(fn.text)) {
              if (fn.text === 'useCan' && !node.arguments.length)
                throw Error(file + '：useCan 必须传入权限码并直接读取布尔返回值');
              record(node.arguments[0]);
            } else if (
              ts.isPropertyAccessExpression(fn) &&
              ['has', 'includes'].includes(fn.name.text)
            ) {
              const receiver = fn.expression;
              if (
                (ts.isIdentifier(receiver) && receiver.text === 'permissions') ||
                (ts.isPropertyAccessExpression(receiver) && receiver.name.text === 'permissions')
              )
                record(node.arguments[0]);
            }
          } else if (ts.isJsxAttribute(node) && node.name.getText(source) === 'permission') {
            const value = node.initializer;
            record(value && ts.isJsxExpression(value) ? value.expression : value);
          } else if (ts.isPropertyAssignment(node) && node.name.getText(source) === 'permission') {
            record(node.initializer);
          }
          ts.forEachChild(node, visit);
        }
        visit(source);
      }
    }
  }
  walk(root);
  return found;
}
</#noparse>
