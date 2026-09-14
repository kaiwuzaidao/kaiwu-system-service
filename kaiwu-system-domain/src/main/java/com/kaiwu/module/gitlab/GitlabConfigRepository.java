package com.kaiwu.module.gitlab;

import com.kaiwu.module.gitlab.entity.GitlabConfigEntity;
import com.kaiwu.module.gitlab.mapper.GitlabConfigMapper;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/**
 * GitLab 交付配置数据访问。
 *
 * <p>数据层迁移到 MyBatis-Plus 后，Repository 仍然保留并继续对外暴露
 * {@link GitlabConfigRow}：Mapper 返回的是贴着表结构的实体，而调用方需要的是不含
 * 主键与审计列的业务视图。保留这一层意味着换 ORM 不把表结构泄露给 Service，
 * 调用方一行都不用改。</p>
 */
@Repository
public class GitlabConfigRepository {

    private static final long SINGLETON_ID = 1L;
    private static final int MESSAGE_MAX_LENGTH = 500;

    private final GitlabConfigMapper mapper;

    public GitlabConfigRepository(GitlabConfigMapper mapper) {
        this.mapper = mapper;
    }

    public Optional<GitlabConfigRow> current() {
        return Optional.ofNullable(mapper.selectById(SINGLETON_ID)).map(GitlabConfigRepository::toRow);
    }

    /** 写入唯一一行配置；连通性测试结果不在覆盖范围内，由 {@link #recordTest} 单独维护。 */
    public void save(GitlabConfigRow row) {
        mapper.upsert(
                SINGLETON_ID,
                row.baseUrl(),
                row.tokenCiphertext(),
                row.defaultGroupId(),
                row.enabled(),
                row.lastTestStatus(),
                abbreviate(row.lastTestMessage()),
                row.lastTestAt());
    }

    public void recordTest(boolean success, String message, LocalDateTime testedAt) {
        mapper.recordTest(SINGLETON_ID, success ? "SUCCESS" : "FAILED", abbreviate(message), testedAt);
    }

    private static GitlabConfigRow toRow(GitlabConfigEntity entity) {
        return new GitlabConfigRow(
                entity.getBaseUrl(),
                entity.getTokenCiphertext(),
                entity.getDefaultGroupId(),
                Boolean.TRUE.equals(entity.getEnabled()),
                entity.getLastTestStatus(),
                entity.getLastTestMessage(),
                entity.getLastTestAt());
    }

    /** 测试信息落库前截断到列宽，避免一条长错误信息直接让写入失败。 */
    private static String abbreviate(String value) {
        if (value == null || value.length() <= MESSAGE_MAX_LENGTH) return value;
        return value.substring(0, MESSAGE_MAX_LENGTH);
    }

    public record GitlabConfigRow(
            String baseUrl,
            String tokenCiphertext,
            String defaultGroupId,
            boolean enabled,
            String lastTestStatus,
            String lastTestMessage,
            LocalDateTime lastTestAt) {}
}
