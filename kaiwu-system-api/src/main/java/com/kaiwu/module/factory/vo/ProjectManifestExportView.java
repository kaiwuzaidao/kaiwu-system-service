package com.kaiwu.module.factory.vo;

import java.util.List;
import java.util.Map;

/**
 * 项目配置移交包（ADR 0042）。
 *
 * <p>是项目配置在导出时刻的全量快照：{@code files} 里的 dicts.yml、configs.yml、menus.yml 与业务仓
 * {@code kaiwu/} 目录同格式，roles.yml 为角色及授权的业务键清单。包内不含数据库 ID、成员与密钥。</p>
 *
 * @param formatVersion 移交包格式版本，当前为 1
 * @param projectCode   项目编码；导入时必须与目标项目一致
 * @param source        来源信息，仅供人核对，不参与摘要
 * @param digest        文件名与内容的 SHA-256；同一状态两次导出相同，不是签名
 * @param stats         各类资源条数
 * @param warnings      未能导出或无法表达的内容，例如敏感配置、停用状态
 * @param files         文件名到 YAML 文本
 */
public record ProjectManifestExportView(
        int formatVersion,
        String projectCode,
        Source source,
        String digest,
        Map<String, Integer> stats,
        List<String> warnings,
        Map<String, String> files) {

    /**
     * 导出来源。
     *
     * @param host       导出请求到达的主机名，best-effort，经网关时可能是外部域名
     * @param exportedBy 导出人的用户 ID
     * @param exportedAt 导出时间，ISO-8601 UTC
     */
    public record Source(String host, String exportedBy, String exportedAt) {}
}
