package com.kaiwu.module.connector.mapper;

import com.kaiwu.module.connector.entity.StorageAccountRow;
import java.time.LocalDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 存储账号 Mapper（ADR 0039）。所有查询显式列出字段，顺序与 {@link StorageAccountRow} 一致。 */
@Mapper
public interface StorageAccountMapper {

    /** 账号查询的公共字段列表，绑定数用相关子查询统计。 */
    String COLUMNS =
            """
            a.id, a.account_code, a.account_name, a.provider_type, a.endpoint, a.region, a.bucket,
            a.path_style, a.sts_endpoint, a.role_arn, a.access_key_id, a.access_key_secret_ciphertext,
            a.credential_ttl_seconds, a.status, a.last_test_status, a.last_test_message, a.last_test_at,
            (SELECT COUNT(1) FROM sys_project_storage b WHERE b.account_id = a.id) AS binding_count
            """;

    /**
     * 列出全部账号，最多 200 条；账号由平台管理员维护，数量很小。
     *
     * @return 按创建时间倒序的账号
     */
    @Select("SELECT " + COLUMNS + " FROM sys_storage_account a ORDER BY a.created_at DESC, a.id DESC LIMIT 200")
    List<StorageAccountRow> listAccounts();

    /**
     * 按 ID 查询账号。
     *
     * @param id 账号 ID
     * @return 账号，不存在时为 {@code null}
     */
    @Select("SELECT " + COLUMNS + " FROM sys_storage_account a WHERE a.id = #{id}")
    StorageAccountRow findAccount(@Param("id") String id);

    /**
     * 按编码查询账号，用于创建时判重。
     *
     * @param accountCode 账号编码
     * @return 账号，不存在时为 {@code null}
     */
    @Select("SELECT " + COLUMNS + " FROM sys_storage_account a WHERE a.account_code = #{accountCode}")
    StorageAccountRow findAccountByCode(@Param("accountCode") String accountCode);

    /**
     * 新建账号。Secret 必须已经加密。
     *
     * @param row 待写入的账号，忽略测试结果与绑定数
     * @param operatorId 操作人 ID
     * @return 写入行数
     */
    @Insert(
            """
            INSERT INTO sys_storage_account
                (id, account_code, account_name, provider_type, endpoint, region, bucket, path_style,
                 sts_endpoint, role_arn, access_key_id, access_key_secret_ciphertext, credential_ttl_seconds,
                 status, created_by, created_at, updated_at)
            VALUES (#{row.id}, #{row.accountCode}, #{row.accountName}, #{row.providerType}, #{row.endpoint},
                    #{row.region}, #{row.bucket}, #{row.pathStyle}, #{row.stsEndpoint}, #{row.roleArn},
                    #{row.accessKeyId}, #{row.accessKeySecretCiphertext}, #{row.credentialTtlSeconds},
                    #{row.status}, #{operatorId}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertAccount(@Param("row") StorageAccountRow row, @Param("operatorId") String operatorId);

    /**
     * 修改账号。编码不可修改；测试结果保持不变，由 {@link #recordTest} 维护。
     *
     * @param row 修改后的账号，Secret 必须已经加密
     * @return 更新行数
     */
    @Update(
            """
            UPDATE sys_storage_account
            SET account_name = #{row.accountName}, provider_type = #{row.providerType},
                endpoint = #{row.endpoint}, region = #{row.region}, bucket = #{row.bucket},
                path_style = #{row.pathStyle}, sts_endpoint = #{row.stsEndpoint}, role_arn = #{row.roleArn},
                access_key_id = #{row.accessKeyId},
                access_key_secret_ciphertext = #{row.accessKeySecretCiphertext},
                credential_ttl_seconds = #{row.credentialTtlSeconds}, status = #{row.status},
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{row.id}
            """)
    int updateAccount(@Param("row") StorageAccountRow row);

    /**
     * 记录一次连通性测试结果。
     *
     * @param id 账号 ID
     * @param status 测试结果
     * @param message 已截断到列宽且不含密钥的说明
     * @param testedAt 测试时间
     * @return 更新行数
     */
    @Update(
            """
            UPDATE sys_storage_account
            SET last_test_status = #{status}, last_test_message = #{message}, last_test_at = #{testedAt},
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int recordTest(
            @Param("id") String id,
            @Param("status") String status,
            @Param("message") String message,
            @Param("testedAt") LocalDateTime testedAt);
}
