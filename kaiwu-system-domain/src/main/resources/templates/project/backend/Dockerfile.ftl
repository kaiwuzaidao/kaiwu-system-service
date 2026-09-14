FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY . .
RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/kaiwu-${projectCode}-boot/target/kaiwu-${projectCode}-service.jar app.jar
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
