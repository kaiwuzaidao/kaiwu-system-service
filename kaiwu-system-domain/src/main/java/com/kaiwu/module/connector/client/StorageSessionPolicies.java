package com.kaiwu.module.connector.client;

import java.util.List;
import java.util.Map;
import tools.jackson.databind.json.JsonMapper;

/**
 * 生成把临时凭证收窄到 {@code {bucket}/{prefix}*} 的会话策略（ADR 0039 第 2 节）。
 *
 * <p>只授予对象级权限，不授予列举桶或管理桶的权限：业务项目只能读写自己前缀下的对象。
 */
public final class StorageSessionPolicies {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final List<String> OSS_READ = List.of("oss:GetObject");
    private static final List<String> OSS_WRITE =
            List.of("oss:GetObject", "oss:PutObject", "oss:DeleteObject", "oss:AbortMultipartUpload", "oss:ListParts");
    private static final List<String> S3_READ = List.of("s3:GetObject");
    private static final List<String> S3_WRITE = List.of(
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:AbortMultipartUpload",
            "s3:ListMultipartUploadParts");

    /** 工具类不实例化。 */
    private StorageSessionPolicies() {}

    /**
     * 阿里云 RAM 会话策略。
     *
     * @param bucket 桶名
     * @param prefix 对象前缀，以 {@code /} 结尾
     * @param readOnly 是否只读
     * @return JSON 策略文本
     */
    public static String aliyun(String bucket, String prefix, boolean readOnly) {
        return JSON.writeValueAsString(Map.of(
                "Version",
                "1",
                "Statement",
                List.of(Map.of(
                        "Effect",
                        "Allow",
                        "Action",
                        readOnly ? OSS_READ : OSS_WRITE,
                        "Resource",
                        List.of("acs:oss:*:*:" + bucket + "/" + prefix + "*")))));
    }

    /**
     * S3 兼容（AWS IAM 语法）会话策略。
     *
     * @param bucket 桶名
     * @param prefix 对象前缀，以 {@code /} 结尾
     * @param readOnly 是否只读
     * @return JSON 策略文本
     */
    public static String s3(String bucket, String prefix, boolean readOnly) {
        return JSON.writeValueAsString(Map.of(
                "Version",
                "2012-10-17",
                "Statement",
                List.of(Map.of(
                        "Effect",
                        "Allow",
                        "Action",
                        readOnly ? S3_READ : S3_WRITE,
                        "Resource",
                        List.of("arn:aws:s3:::" + bucket + "/" + prefix + "*")))));
    }
}
