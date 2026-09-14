FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS build
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml .npmrc ./
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY . .
RUN pnpm run setup && pnpm typecheck && pnpm build

FROM nginxinc/nginx-unprivileged:1.31.1-alpine@sha256:cc300bd2e8776708a8c2c8686a74f06eadf221c5ce01e85d0e821955d7a730ab
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html/apps/${projectCode}
USER 101:101
EXPOSE 8080
