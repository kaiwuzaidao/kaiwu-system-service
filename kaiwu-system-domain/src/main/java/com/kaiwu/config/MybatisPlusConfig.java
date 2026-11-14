package com.kaiwu.config;

import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import java.util.Properties;
import org.apache.ibatis.mapping.DatabaseIdProvider;
import org.apache.ibatis.mapping.VendorDatabaseIdProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 平台控制面的 MyBatis-Plus 配置。
 *
 * <p>平台与生成项目继续使用同一套 MyBatis-Plus 数据层，只装分页插件。
 * 平台根据实际 JDBC 产品选择 MySQL / 达梦方言；生成业务项目仍遵守自身的数据库契约。</p>
 */
@Configuration
public class MybatisPlusConfig {

    /** 根据实际 JDBC 产品识别分页方言，允许平台连接 MySQL 或达梦。 */
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor());
        return interceptor;
    }

    /** 为差异查询选择独立 SQL；默认注解语句继续用于 MySQL。 */
    @Bean
    public DatabaseIdProvider databaseIdProvider() {
        Properties vendors = new Properties();
        vendors.setProperty("MySQL", "mysql");
        vendors.setProperty("DM DBMS", "dm");
        VendorDatabaseIdProvider provider = new VendorDatabaseIdProvider();
        provider.setProperties(vendors);
        return provider;
    }
}
