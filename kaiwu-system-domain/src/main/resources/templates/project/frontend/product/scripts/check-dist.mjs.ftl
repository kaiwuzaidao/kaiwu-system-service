<#noparse>import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
function inspect(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) inspect(path);
    else if (
      /\.(js|html|json|css|map)$/.test(path) &&
      /kaiwu_mock_role|\/__mock\/|mock\.notImplemented/.test(readFileSync(path, 'utf8'))
    ) {
      throw new Error('生产构建包含演示运行时：' + path);
    }
  }
}
inspect('dist');
</#noparse>
