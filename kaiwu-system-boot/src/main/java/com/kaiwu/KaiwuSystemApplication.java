package com.kaiwu;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.AutoConfigurationExcludeFilter;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.TypeExcludeFilter;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;

/**
 * Kaiwu 平台控制面启动入口。
 *
 * <p>组件扫描排除 {@code com.kaiwu.starter}：Starter 与平台共用 {@code com.kaiwu} 包前缀，但它是发给业务
 * 项目的 SDK，所有 Bean 都由自身的自动配置按开关注册（例如「文件」接口、Agent 能力接口）。若被平台的包扫描
 * 直接拾取，这些接口会绕过开关在平台里装配，缺少依赖时启动失败，依赖齐全时则会暴露不该存在的端点。
 * 前两个过滤器是 {@link SpringBootApplication} 的默认值，显式声明扫描时必须保留。</p>
 */
@SpringBootApplication
@ComponentScan(
        excludeFilters = {
            @ComponentScan.Filter(type = FilterType.CUSTOM, classes = TypeExcludeFilter.class),
            @ComponentScan.Filter(type = FilterType.CUSTOM, classes = AutoConfigurationExcludeFilter.class),
            @ComponentScan.Filter(type = FilterType.REGEX, pattern = "com\\.kaiwu\\.starter\\..*")
        })
public class KaiwuSystemApplication {

    /**
     * 启动平台控制面。
     *
     * @param args 命令行参数
     */
    public static void main(String[] args) {
        SpringApplication.run(KaiwuSystemApplication.class, args);
    }
}
