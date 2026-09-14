package com.kaiwu.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 平台控制面的 MyBatis-Plus 配置。
 *
 * <p>与生成项目模板 {@code templates/project/backend/MybatisPlusConfig.java.ftl} 保持同一套
 * 配置：只装分页插件，不引入乐观锁、多租户等未被真实需求要求的拦截器。平台和业务项目用
 * 同一套栈、同一套配置，读代码的人（和 AI）在两边看到的是同一个东西。</p>
 */
@Configuration
public class MybatisPlusConfig {

    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
