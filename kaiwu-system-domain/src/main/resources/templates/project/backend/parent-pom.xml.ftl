<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>4.0.7</version>
        <relativePath/>
    </parent>
    <groupId>${basePackage}</groupId>
    <artifactId>kaiwu-${projectCode}</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <packaging>pom</packaging>
    <name>${projectName}</name>
    <modules>
        <module>kaiwu-${projectCode}-api</module>
        <module>kaiwu-${projectCode}-domain</module>
        <module>kaiwu-${projectCode}-boot</module>
    </modules>
    <properties>
        <java.version>21</java.version>
        <jackson-2-bom.version>2.21.5</jackson-2-bom.version>
        <jackson-bom.version>3.1.5</jackson-bom.version>
        <!-- Spring Boot 4.0.7 管理的 tomcat 11.0.22 有 3 个 CRITICAL：CVE-2026-65182
             （安全约束绕过）、CVE-2026-65905（DIGEST 认证重放）、CVE-2026-68525
             （FORM 认证绕过）。修复版 11.0.25。Spring Boot 升级到自带该版本后可移除。 -->
        <tomcat.version>11.0.25</tomcat.version>
        <mybatis-plus.version>3.5.17</mybatis-plus.version>
        <kaiwu-system-starter.version>${starterVersion}</kaiwu-system-starter.version>
        <spotless.version>2.46.1</spotless.version>
        <error-prone.version>2.36.0</error-prone.version>
    </properties>
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>${basePackage}</groupId>
                <artifactId>kaiwu-${projectCode}-api</artifactId>
                <version>${r"${project.version}"}</version>
            </dependency>
            <dependency>
                <groupId>${basePackage}</groupId>
                <artifactId>kaiwu-${projectCode}-domain</artifactId>
                <version>${r"${project.version}"}</version>
            </dependency>
            <dependency>
                <groupId>com.kaiwuzaidao</groupId>
                <artifactId>kaiwu-system-starter</artifactId>
                <version>${r"${kaiwu-system-starter.version}"}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>
    <build>
        <plugins>
            <!-- ADR 0020：自动格式化是可执行默认值，不作为业务合并阻断条件。 -->
            <plugin>
                <groupId>com.diffplug.spotless</groupId>
                <artifactId>spotless-maven-plugin</artifactId>
                <version>${r"${spotless.version}"}</version>
                <configuration>
                    <java>
                        <palantirJavaFormat/>
                        <removeUnusedImports/>
                        <trimTrailingWhitespace/>
                        <endWithNewline/>
                    </java>
                </configuration>
            </plugin>
            <!--
                ErrorProne：编译期抓真实缺陷（字符串用 == 比较、格式化串参数不匹配、
                误用 Optional、忽略应当检查的返回值等）。与 Kaiwu 平台三仓同一套配置。

                只开它自带的规则，产出是 WARNING，不阻断构建——按 ADR 0020，这类
                质量提示属于报告而非合并门禁。JDK 21 需要下面那组 compilerArgs 才能
                让插件访问 javac 内部 API，是 ErrorProne 对 JDK 16+ 的既定要求。
            -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <!-- -J 前缀的参数只在 fork 模式下有效：不 fork 时 javac 在 Maven 进程内运行，
                         这些参数会被直接拒绝，表现为「An unknown compilation problem occurred」。 -->
                    <fork>true</fork>
                    <compilerArgs>
                        <arg>-XDcompilePolicy=simple</arg>
                        <arg>--should-stop=ifError=FLOW</arg>
                        <arg>-Xplugin:ErrorProne</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED</arg>
                        <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED</arg>
                        <arg>-J--add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED</arg>
                        <arg>-J--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED</arg>
                    </compilerArgs>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>com.google.errorprone</groupId>
                            <artifactId>error_prone_core</artifactId>
                            <version>${r"${error-prone.version}"}</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
