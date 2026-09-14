<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>${basePackage}</groupId>
        <artifactId>kaiwu-${projectCode}</artifactId>
        <version>0.1.0-SNAPSHOT</version>
    </parent>
    <artifactId>kaiwu-${projectCode}-boot</artifactId>
    <name>${projectName} :: Boot</name>
    <description>启动装配与可执行包</description>
    <dependencies>
        <dependency>
            <groupId>${basePackage}</groupId>
            <artifactId>kaiwu-${projectCode}-domain</artifactId>
        </dependency>
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <scope>runtime</scope>
        </dependency>
        <!-- Spring Boot 4.0 把 Flyway 自动配置从 spring-boot-autoconfigure 拆到了独立模块。
             只引 flyway-core 的话 FlywayAutoConfiguration 根本不在 classpath 上，应用能正常
             启动，但迁移一次都不会执行——第一次查业务表就是 "Table doesn't exist"。 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-flyway</artifactId>
        </dependency>
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-mysql</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <!-- 启动冒烟只连 Testcontainers 的一次性 MySQL，绝不读开发库或共享库配置。
             版本由 spring-boot-starter-parent 引入的 testcontainers-bom 管理。 -->
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>testcontainers-junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>testcontainers-mysql</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    <build>
        <finalName>kaiwu-${projectCode}-service</finalName>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <executions>
                    <execution>
                        <goals>
                            <goal>repackage</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
