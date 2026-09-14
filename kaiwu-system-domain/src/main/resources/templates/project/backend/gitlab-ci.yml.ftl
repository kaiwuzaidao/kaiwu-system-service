stages:
  - verify
  - security

verify:
  stage: verify
  image: maven:3.9.11-eclipse-temurin-21
  variables:
    MAVEN_OPTS: "-Dmaven.repo.local=.m2/repository"
  script:
    # ZIP 与 Git 初始提交不携带可执行位，显式用 bash 调用。
    - bash scripts/check-permission-seed.sh
    - bash scripts/check-test-baseline.sh
    - mvn --batch-mode verify
  cache:
    key: maven
    paths:
      - .m2/repository/
  artifacts:
    when: always
    reports:
      junit:
        - "**/target/surefire-reports/TEST-*.xml"

constraints:
  stage: verify
  image: alpine:3.20
  before_script:
    - apk add --no-cache jq
  script:
    - sh scripts/check-constraints.sh

secrets:
  stage: security
  image:
    name: ghcr.io/gitleaks/gitleaks:v8.28.0
    entrypoint: [""]
  script:
    - gitleaks dir . --no-banner --redact

dependencies:
  stage: security
  image:
    name: aquasec/trivy:0.64.1
    entrypoint: [""]
  script:
    - trivy fs --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed .
    - trivy fs --format cyclonedx --output gl-sbom.cdx.json .
  artifacts:
    when: always
    paths:
      - gl-sbom.cdx.json

# 构建/发布流水线设置 KAIWU_IMAGE_REF 后扫描实际镜像；未产出镜像的 MR 不伪造扫描结果。
image-vulnerabilities:
  stage: security
  image:
    name: aquasec/trivy:0.64.1
    entrypoint: [""]
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$KAIWU_IMAGE_REF"
  rules:
    - if: '$KAIWU_IMAGE_REF'
