# 基础镜像提成 ARG，默认值保持公开可复现的 Docker Hub 引用（含 digest 钉死）。
# 内网 CI 用 --build-arg 覆盖成 Harbor 副本——内网 runner 与 dind 都访问不到
# registry-1.docker.io，而默认值是仓库对外的契约，不应为内网环境改写。
ARG BUILDER_IMAGE=maven:3.9.11-eclipse-temurin-21
ARG RUNTIME_IMAGE=eclipse-temurin:21-jre
# 两条 ARG 都必须声明在第一个 FROM 之前：FROM 之后声明的 ARG 属于该 stage 的
# 作用域，对后续 FROM 不可见（buildkit 会直接报 UndefinedArgInFrom）。
FROM ${BUILDER_IMAGE} AS builder

WORKDIR /workspace/starter
COPY kaiwu-system-starter/ .
COPY kaiwu-system-service/.mvn/settings.xml /tmp/kaiwu-maven-settings.xml
# Maven 参数走 ARG：仓库内的 .mvn/settings.xml 把 central 指向阿里云镜像，那是给
# 境内开发机与内网 CI 用的。GitHub Actions 的 runner 在境外，经该镜像会解析失败，
# 构建时用 --build-arg MAVEN_ARGS= 直连 Central。默认值保持原行为不变。
ARG MAVEN_ARGS="-s /tmp/kaiwu-maven-settings.xml"
RUN mvn -q ${MAVEN_ARGS} \
    -Dmaven.resolver.transport=wagon -DskipTests install

WORKDIR /workspace/system
COPY kaiwu-system-service/ .
ARG MAVEN_ARGS_SYSTEM="-s .mvn/settings.xml"
RUN mvn -q ${MAVEN_ARGS_SYSTEM} -Dmaven.resolver.transport=wagon -DskipTests package

FROM ${RUNTIME_IMAGE}
WORKDIR /app
COPY --from=builder /workspace/system/kaiwu-system-boot/target/kaiwu-system-service.jar /app/app.jar
RUN mkdir -p /var/lib/kaiwu/artifacts \
    && chown -R 10001:10001 /var/lib/kaiwu
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
