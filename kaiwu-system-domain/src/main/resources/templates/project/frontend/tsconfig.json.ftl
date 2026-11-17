{
  "extends": "./src/.umi/tsconfig.json",
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "resolveJsonModule": true
  },
  "include": ["src", "config", ".umirc.ts", "typings.d.ts", "mock", "mock-support"]
}
