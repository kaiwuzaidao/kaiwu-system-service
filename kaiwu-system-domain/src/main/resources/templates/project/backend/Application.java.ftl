package ${basePackage};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** 启动业务项目的 Spring Boot 应用。 */
@SpringBootApplication
public class ${applicationClass} {

    /**
     * 启动应用并交由 Spring 管理运行时组件。
     *
     * @param args 启动参数
     */
    public static void main(String[] args) {
        SpringApplication.run(${applicationClass}.class, args);
    }
}
