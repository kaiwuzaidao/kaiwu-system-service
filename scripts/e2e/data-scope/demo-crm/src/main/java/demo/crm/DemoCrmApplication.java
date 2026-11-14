package demo.crm;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** 示例业务服务：只演示按 Skill 接入数据范围后的行为，不含任何范围代码。 */
@SpringBootApplication
@MapperScan("demo.crm")
public class DemoCrmApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoCrmApplication.class, args);
    }
}
