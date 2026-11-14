ARG BUILDER_IMAGE=maven:3.9.11-eclipse-temurin-21
ARG RUNTIME_IMAGE=eclipse-temurin:21-jre-noble
FROM ${BUILDER_IMAGE} AS build
WORKDIR /source
COPY pom.xml ./
COPY .mvn ./.mvn
COPY kaiwu-dm-migrator ./kaiwu-dm-migrator
ARG MAVEN_ARGS="-s .mvn/settings.xml"
RUN mvn -B ${MAVEN_ARGS} -f kaiwu-dm-migrator/pom.xml -DskipTests package

FROM ${RUNTIME_IMAGE}
WORKDIR /app
COPY THIRD-PARTY-NOTICES.md /licenses/THIRD-PARTY-NOTICES.md
COPY --from=build /source/kaiwu-dm-migrator/target/classes /app/classes
COPY --from=build /source/kaiwu-dm-migrator/target/dependency /app/lib
USER 10001:10001
ENTRYPOINT ["java", "-cp", "/app/classes:/app/lib/*", "com.kaiwu.database.DmMigrationMain"]
