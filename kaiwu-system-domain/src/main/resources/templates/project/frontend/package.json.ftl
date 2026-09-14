{
  "name": "kaiwu-${projectCode}-web",
  "version": "0.1.0",
  "private": true,
  "license": "Apache-2.0",
  "scripts": {
    "dev": "max dev",
    "build": "max build",
    "typecheck": "tsc --noEmit",
    "check:dict": "node scripts/check-dict-consistency.mjs",
    "check:perm": "node scripts/check-permission-consistency.mjs",
    "check:log": "node scripts/check-log-redaction.mjs",
    "check:constraints": "sh scripts/check-constraints.sh",
    "format": "prettier --write \"{config,scripts,src}/**/*.{js,mjs,ts,tsx}\" \"*.{js,json,ts}\"",
    "format:check": "prettier --check \"{config,scripts,src}/**/*.{js,mjs,ts,tsx}\" \"*.{js,json,ts}\"",
    "audit:prod": "pnpm audit --prod --audit-level high",
    "verify": "pnpm typecheck && pnpm check:dict && pnpm check:perm && pnpm check:log && pnpm check:constraints && pnpm format:check && pnpm build && pnpm audit:prod",
    "setup": "max setup",
    "postinstall": "max setup"
  },
  "dependencies": {
    "@ant-design/icons": "^5.5.1",
    "@ant-design/pro-components": "^2.8.2",
    "@umijs/max": "^4.6.82",
    "antd": "^5.22.2",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@playwright/test": "^1.62.0",
    "@types/node": "^26.1.2",
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "dotenv": "^17.4.2",
    "prettier": "3.9.6",
    "typescript": "^5.6.3"
  },
  "pnpm": {
    "overrides": {
      "@umijs/max>@umijs/lint": "-",
      "@umijs/max>eslint": "-",
      "@umijs/max>stylelint": "-",
      "@umijs/preset-umi>@stagewise/toolbar": "-",
      "@umijs/preset-umi>@umijs/bundler-mako": "-",
      "@umijs/bundler-vite>vite": "6.4.3",
      "@umijs/preset-umi>path-to-regexp": "1.9.0",
      "@ant-design/pro-layout>path-to-regexp": "8.4.0",
      "isomorphic-fetch>node-fetch": "2.6.7",
      "brace-expansion": "5.0.9",
      "fast-uri": "3.1.7",
      "js-yaml": "3.15.2",
      "less": "4.8.1",
      "svgo": "2.8.4",
      "nanoid": "3.3.18",
      "@umijs/preset-umi>@umijs/bundler-utoopack": "-",
      "axios": "0.33.0",
      "immer": "9.0.21"
    }
  },
  "packageManager": "pnpm@10.8.0"
}
