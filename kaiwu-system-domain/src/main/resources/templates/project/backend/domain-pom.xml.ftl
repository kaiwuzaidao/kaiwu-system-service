<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>${basePackage}</groupId>
        <artifactId>kaiwu-${projectCode}</artifactId>
        <version>0.1.0-SNAPSHOT</version>
    </parent>
    <artifactId>kaiwu-${projectCode}-domain</artifactId>
    <name>${projectName} :: Domain</name>
    <description>Controller、Service、Entity 与 Mapper</description>
    <dependencies>
        <dependency>
            <groupId>${basePackage}</groupId>
            <artifactId>kaiwu-${projectCode}-api</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>mybatis-plus-spring-boot4-starter</artifactId>
            <version>${r"${mybatis-plus.version}"}</version>
        </dependency>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>mybatis-plus-jsqlparser</artifactId>
            <version>${r"${mybatis-plus.version}"}</version>
        </dependency>
        <dependency>
            <groupId>com.kaiwuzaidao</groupId>
            <artifactId>kaiwu-system-starter</artifactId>
        </dependency>
        <!-- 测试基线依赖：JUnit 5、Mockito、AssertJ 与 MockMvc 都来自这一个 starter。 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
