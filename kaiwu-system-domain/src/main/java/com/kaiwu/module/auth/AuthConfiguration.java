package com.kaiwu.module.auth;

import com.kaiwu.module.auth.mapper.AuthMapper;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.util.StringUtils;

/**
 * 认证组件与首次管理员初始化。
 */
@Configuration
@EnableConfigurationProperties(AuthProperties.class)
public class AuthConfiguration {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    /** 缺少引导管理员密码时 fail-fast：宁可起不来，也不要留一个密码未知的管理员账号。 */
    @Bean
    public AccessTokenService accessTokenService(AuthProperties properties) {
        if (!StringUtils.hasText(properties.getBootstrapAdminPassword())) {
            throw new IllegalStateException("缺少必需配置：kaiwu.auth.bootstrap-admin-password");
        }
        return new AccessTokenService(properties);
    }

    /** 全新库首启创建内置 admin；已存在则不动，因此重启是安全的。 */
    @Bean
    @Order(10)
    public ApplicationRunner bootstrapAdmin(
            AuthMapper authMapper,
            AuthRepository repository,
            PasswordEncoder passwordEncoder,
            AuthProperties properties) {
        return arguments -> {
            if (!repository.userExists("admin")) {
                // 引导密码来自环境变量，可能留存于部署脚本、CI 变量与聊天记录，
                // 因此首次登录必须由本人改掉（SQL 里的 must_change_password = 1）。
                authMapper.insertBootstrapAdmin(passwordEncoder.encode(properties.getBootstrapAdminPassword()));
                // 这里不再绑定 legacy sys_user_role：鉴权只认 sys_project_*，
                // admin 的实际权限由 SystemProjectBootstrap 建立的 system 项目成员身份提供。
            }
        };
    }
}
