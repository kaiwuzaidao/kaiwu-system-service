<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>${basePackage}</groupId>
        <artifactId>kaiwu-${projectCode}</artifactId>
        <version>0.1.0-SNAPSHOT</version>
    </parent>
    <artifactId>kaiwu-${projectCode}-api</artifactId>
    <name>${projectName} :: API</name>
    <description>稳定 DTO、VO 与统一响应契约</description>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <!-- ApiException 用 HttpStatus 表达状态码。只引 spring-web，不引 starter-web：
             API 模块是契约层，不应该把 Tomcat 和自动装配带进依赖树。 -->
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-web</artifactId>
        </dependency>
    </dependencies>
</project>
