package com.kaiwu.module.gitlab.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.gitlab.entity.GitlabConfigEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/**
 * GitLab 配置 Mapper。
 *
 * <p>约定：单表 CRUD 走 {@link BaseMapper}；MyBatis-Plus 表达不了的 SQL（此处是
 * {@code ON DUPLICATE KEY UPDATE}）写成 Mapper 上的注解，**不引入 XML**。
 * 理由是让「一条 SQL 的全部真相」最多分布在实体和 Mapper 两个文件里；
 * 加一层 XML 就变成三处要同步，而这正是迁移前手写 SQL 唯一的优点所在。</p>
 */
@Mapper
public interface GitlabConfigMapper extends BaseMapper<GitlabConfigEntity> {

    /**
     * 写入唯一一行配置。
     *
     * <p>MyBatis-Plus 没有原生的 upsert，而这张表恒定单行、由 {@code id = 1} 定义，
     * 用「先查后插/更新」会引入并发窗口，因此保留 {@code ON DUPLICATE KEY UPDATE}。
     * 注意 {@code last_test_*} 三列有意不在更新列表里：保存配置不应清空上一次连通性
     * 测试结果，那是 {@link #recordTest} 的职责。</p>
     */
    @Update(
            """
            INSERT INTO sys_gitlab_config
                (id, base_url, token_ciphertext, default_group_id, enabled,
                 last_test_status, last_test_message, last_test_at,
                 created_at, updated_at)
            VALUES (#{id}, #{baseUrl}, #{tokenCiphertext}, #{defaultGroupId}, #{enabled},
                    #{lastTestStatus}, #{lastTestMessage}, #{lastTestAt},
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE
                base_url = VALUES(base_url),
                token_ciphertext = VALUES(token_ciphertext),
                default_group_id = VALUES(default_group_id),
                enabled = VALUES(enabled),
                updated_at = CURRENT_TIMESTAMP
            """)
    int upsert(
            @Param("id") long id,
            @Param("baseUrl") String baseUrl,
            @Param("tokenCiphertext") String tokenCiphertext,
            @Param("defaultGroupId") String defaultGroupId,
            @Param("enabled") boolean enabled,
            @Param("lastTestStatus") String lastTestStatus,
            @Param("lastTestMessage") String lastTestMessage,
            @Param("lastTestAt") java.time.LocalDateTime lastTestAt);

    /** 记录一次连通性测试结果，只动测试相关列。 */
    @Update(
            """
            UPDATE sys_gitlab_config
            SET last_test_status = #{status}, last_test_message = #{message},
                last_test_at = #{testedAt}, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int recordTest(
            @Param("id") long id,
            @Param("status") String status,
            @Param("message") String message,
            @Param("testedAt") java.time.LocalDateTime testedAt);
}
