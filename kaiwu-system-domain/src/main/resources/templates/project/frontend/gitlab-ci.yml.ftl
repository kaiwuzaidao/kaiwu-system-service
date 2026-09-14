<#noparse>stages:
  - verify
  - build
  - image
  - security
  - sync

default:
  tags: [docker]

# 所有外部镜像都走变量，默认值是公共镜像，任何人 clone 下来就能跑。
# 内网/离线环境把同名变量配到 GitLab 的 group 或 project 级即可整体改指到私有
# 仓库——CI 变量优先级高于本文件的 variables，不需要改这个文件。
variables:
  GIT_DEPTH: "20"
  NODE_BUILD_IMAGE: "node:20-bookworm"
  # 部署侧 securityContext 为 runAsNonRoot/runAsUser=101，标准 nginx 镜像在该约束下
  # 无法写 /var/cache/nginx 与 pid 文件，启动即 emerg。必须用 unprivileged 变体。
  WEB_RUNTIME_IMAGE: "nginxinc/nginx-unprivileged:1.31.1-alpine"
  DOCKER_CLI_IMAGE: "docker:27.5.1-cli"
  DOCKER_DIND_IMAGE: "docker:27.5.1-dind"
  UTIL_IMAGE: "alpine:3.20"
  TRIVY_IMAGE: "aquasec/trivy:0.64.1"
  GITLEAKS_IMAGE: "ghcr.io/gitleaks/gitleaks:v8.28.0"

workflow:
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_BRANCH == "dev"'
    - if: '$CI_COMMIT_BRANCH =~ /^(feature|fix)\//'
    - if: '$CI_COMMIT_TAG'
    - when: never

verify:configuration:
  stage: verify
  image: $UTIL_IMAGE
  script:
    - test -f ci.env
    - . ./ci.env
    - test -n "$APP_NAME"
    - test -n "$HARBOR_PROJECT"
    - test -n "$HARBOR_REGISTRY"

build:web:
  stage: build
  image: $NODE_BUILD_IMAGE
  before_script:
    # check:constraints 用 jq 解析约束目录，node:20-bookworm 不自带。
    - apt-get update -qq && apt-get install -y -qq --no-install-recommends jq
  script:
    - corepack enable
    - pnpm install --frozen-lockfile --ignore-scripts
    - pnpm run setup
    - pnpm typecheck
    - pnpm check:dict
    - pnpm check:perm
    - pnpm check:log
    - pnpm check:constraints
    - pnpm build
    - test -f dist/index.html
  artifacts:
    expire_in: 1 day
    paths: [dist/, nginx.conf]

image:push-harbor:
  stage: image
  image: $DOCKER_CLI_IMAGE
  services:
    - name: $DOCKER_DIND_IMAGE
      alias: docker
      command: ["--tls=false"]
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  needs:
    - job: build:web
      artifacts: true
  before_script:
    - echo "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" -u "$HARBOR_USER" --password-stdin
  script:
    - . ./ci.env
    - tag="${CI_COMMIT_TAG:-${CI_COMMIT_REF_SLUG}-${CI_PIPELINE_IID}-${CI_COMMIT_SHORT_SHA}}"
    - image="$HARBOR_REGISTRY/${HARBOR_PROJECT}/${APP_NAME}:$tag"
    - |
      cat >Dockerfile.ci <<DFEOF
      FROM ${WEB_RUNTIME_IMAGE}
      COPY nginx.conf /etc/nginx/conf.d/default.conf
      COPY dist/ /usr/share/nginx/html/apps/</#noparse>${projectCode}<#noparse>/
      USER 101:101
      EXPOSE 8080
      DFEOF
    - docker build --label "org.opencontainers.image.revision=$CI_COMMIT_SHA" -f Dockerfile.ci -t "$image" .
    - set -o pipefail
    - docker push "$image" 2>&1 | tee push.log
    - "digest=\"$(sed -nE 's/.*digest: (sha256:[0-9a-f]+).*/\\1/p' push.log | tail -1)\""
    - if [ -z "$digest" ]; then digest="$(docker inspect --format '{{index .RepoDigests 0}}' "$image" 2>/dev/null | cut -d@ -f2)"; fi
    - test -n "$digest"
    - printf 'IMAGE=%s\nIMAGE_DIGEST=%s\nAPP_NAME=%s\n' "$image" "$digest" "$APP_NAME" >image.env
  after_script:
    - docker logout "$HARBOR_REGISTRY" || true
  artifacts:
    reports:
      dotenv: image.env
    expire_in: 30 days

# 回写 GitOps 仓库的镜像 digest，由 ArgoCD 应用 </#noparse>${projectCode}<#noparse>-admin-test 同步到集群。
# 实现与 platform/ci-templates 的 node-web-gitops.yml 保持一致；本仓库未 include
# 该模板（构建方式不同），故在此内联。
deploy:gitops:dev:
  stage: sync
  image: $UTIL_IMAGE
  # 必须把安全门禁列进 needs：本任务是 DAG 任务，只靠 stage 顺序拦不住它——
  # 只要 needs 里的任务跑完就会启动，security stage 还没跑也照样部署。
  needs:
    - job: image:push-harbor
      artifacts: true
    - job: secrets
      artifacts: false
    - job: dependencies
      artifacts: false
  variables:
    GIT_STRATEGY: none
    # 不能复用 GITOPS_DEV_FILE：该变量在 group 级已定义（指向 miniprogram），
    # 而 .gitlab-ci.yml 的 variables 优先级低于 group 变量，会被覆盖。
    PROJECT_GITOPS_FILE: "apps/</#noparse>${projectCode}<#noparse>-admin/overlays/test/kustomization.yaml"
  before_script:
    - apk add --no-cache git
    - test -n "$IMAGE_DIGEST"
    - 'test -n "$GITOPS_PUSH_TOKEN" || { echo "Missing protected CI variable: GITOPS_PUSH_TOKEN"; exit 1; }'
    - 'test -n "$GITOPS_REPO_PATH" || { echo "Missing CI variable: GITOPS_REPO_PATH"; exit 1; }'
  script:
    # APP_NAME 由 image:push-harbor 经 dotenv artifact 传入；此任务 GIT_STRATEGY=none，
    # 工作目录没有 ci.env，不能在这里 source。
    - test -n "$APP_NAME"
    - git clone --depth 1 "https://${GITOPS_PUSH_USER:-gitops-ci}:${GITOPS_PUSH_TOKEN}@${CI_SERVER_HOST}/${GITOPS_REPO_PATH}.git" gitops
    - cd gitops
    - file="$PROJECT_GITOPS_FILE"
    - test -f "$file"
    - 'grep -q "newName: .*${APP_NAME}$" "$file"'
    - 'sed -i "/newName: .*${APP_NAME}$/ {n; s#digest: .*#digest: ${IMAGE_DIGEST}#;}" "$file"'
    - git diff --exit-code -- "$file" && { echo 'GitOps 已指向该 digest，无需提交'; exit 0; }
    - git config user.name "${GITOPS_PUSH_USER:-gitops-ci}"
    - git config user.email "${GITOPS_PUSH_EMAIL:-gitops-ci@example.invalid}"
    - git add "$file"
    - 'git commit -m "deploy(test): update ${APP_NAME} to ${CI_COMMIT_REF_SLUG}-${CI_PIPELINE_IID}-${CI_COMMIT_SHORT_SHA}"'
    - git push origin HEAD:main
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev" && $GITOPS_ENABLED == "true" && $GITOPS_DEV_ENABLED == "true"'

secrets:
  stage: security
  image:
    name: $GITLEAKS_IMAGE
    entrypoint: [""]
  # 只扫源码。默认会下载前序 stage 的 artifacts，把 dist/ 一并扫进来，
  # 压缩后的属性名（tabKey、key 等）会被 generic-api-key 规则持续误报。
  dependencies: []
  script:
    - gitleaks dir . --no-banner --redact

dependencies:
  stage: security
  # 内网 runner 拉不到 Docker Hub，改用 Harbor 同步的副本。
  image:
    name: $TRIVY_IMAGE
    entrypoint: [""]
  # 同 secrets：只扫源码与依赖清单，不扫构建产物。
  dependencies: []
  variables:
    # 漏洞库的源：mirror.gcr.io 内网不可达；ghcr.io 能建连但拉 112MB 必被
    # 对端掐断（PROTOCOL_ERROR，2026-09-12 连续三次重试全败）。同一份库
    # AWS ECR Public 也有，实测 4.7MiB/s、29 秒拉完，改用它。
    TRIVY_DB_REPOSITORY: "public.ecr.aws/aquasecurity/trivy-db:2"
    TRIVY_TIMEOUT: "15m"
  # 漏洞库有 100 MB 以上，中途被对端掐断是常态（PROTOCOL_ERROR、
  # context deadline exceeded），一断整条流水线就红，还得有人手点 Retry。
  # 这里把"拉库"和"扫描"拆开：拉库失败重试三次，扫描本身用 --skip-db-update
  # 且不重试——真扫出 CVE 时重试三遍只会拖慢结论，不会改变结果。
  before_script:
    - |
      for attempt in 1 2 3; do
        if trivy image --download-db-only; then break; fi
        echo "漏洞库下载失败（第 ${attempt} 次）"
        if [ "$attempt" = 3 ]; then echo "三次均失败，判定为网络问题"; exit 1; fi
        sleep 20
      done
  script:
    - trivy fs --skip-db-update --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed .
    - trivy fs --skip-db-update --format cyclonedx --output gl-sbom.cdx.json .
  artifacts:
    when: always
    paths:
      - gl-sbom.cdx.json

image-vulnerabilities:
  stage: security
  image:
    name: $TRIVY_IMAGE
    entrypoint: [""]
  variables:
    # 漏洞库的源：mirror.gcr.io 内网不可达；ghcr.io 能建连但拉 112MB 必被
    # 对端掐断（PROTOCOL_ERROR，2026-09-12 连续三次重试全败）。同一份库
    # AWS ECR Public 也有，实测 4.7MiB/s、29 秒拉完，改用它。
    TRIVY_DB_REPOSITORY: "public.ecr.aws/aquasecurity/trivy-db:2"
    TRIVY_TIMEOUT: "15m"
  # 漏洞库有 100 MB 以上，中途被对端掐断是常态（PROTOCOL_ERROR、
  # context deadline exceeded），一断整条流水线就红，还得有人手点 Retry。
  # 这里把"拉库"和"扫描"拆开：拉库失败重试三次，扫描本身用 --skip-db-update
  # 且不重试——真扫出 CVE 时重试三遍只会拖慢结论，不会改变结果。
  before_script:
    - |
      for attempt in 1 2 3; do
        if trivy image --download-db-only; then break; fi
        echo "漏洞库下载失败（第 ${attempt} 次）"
        if [ "$attempt" = 3 ]; then echo "三次均失败，判定为网络问题"; exit 1; fi
        sleep 20
      done
  script:
    - trivy image --skip-db-update --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$KAIWU_IMAGE_REF"
  rules:
    - if: '$KAIWU_IMAGE_REF'
</#noparse>