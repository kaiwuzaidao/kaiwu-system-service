package com.kaiwu.module.factory.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;

/**
 * 业务项目平台资源清单的计划或执行请求（ADR 0036、ADR 0042）。
 *
 * @param files            文件名到 YAML 文本，只接受 dicts.yml、configs.yml、menus.yml、roles.yml、jobs.yml、i18n.yml
 * @param gitCommit        清单所在提交，只用于审计记录，可为空
 * @param planHash         执行时必填：计划返回的哈希，与当前平台状态不一致时拒绝执行
 * @param applyAccess      执行时是否导入授权（角色及授权）；默认不导入，授权需要显式勾选
 * @param deleteKeys       执行时勾选要删除的条目，格式 {@code 资源|标识}，只能取自计划里的「源环境已删除」
 * @param packageDigest    移交包摘要，只用于移交记录与重复导入提示，可为空
 * @param sourceHost       移交包来源主机，只用于移交记录
 * @param sourceExportedBy 移交包导出人，只用于移交记录
 * @param sourceExportedAt 移交包导出时间原文，只用于移交记录
 */
public record ProjectManifestRequest(
        @NotEmpty(message = "清单文件不能为空") @Size(max = 7, message = "清单文件最多 7 个") Map<String, String> files,
        @Size(max = 64, message = "提交号不能超过 64 个字符") @Pattern(regexp = "^$|[0-9a-fA-F]{7,64}", message = "提交号格式不正确")
                String gitCommit,
        @Size(max = 128, message = "计划哈希不能超过 128 个字符") String planHash,
        Boolean applyAccess,
        @Size(max = 500, message = "一次最多勾选 500 项删除") List<@Size(max = 300, message = "删除项标识过长") String> deleteKeys,
        @Size(max = 64, message = "摘要不能超过 64 个字符") String packageDigest,
        @Size(max = 255, message = "来源主机不能超过 255 个字符") String sourceHost,
        @Size(max = 64, message = "导出人不能超过 64 个字符") String sourceExportedBy,
        @Size(max = 40, message = "导出时间不能超过 40 个字符") String sourceExportedAt) {

    /** 只含清单、提交号与计划哈希的请求，命令行 {@code project sync} 使用；不导入授权、不删除。 */
    public ProjectManifestRequest(Map<String, String> files, String gitCommit, String planHash) {
        this(files, gitCommit, planHash, false, List.of(), null, null, null, null);
    }

    /**
     * 是否导入授权；请求里没有这个字段时按 {@code false} 处理。
     *
     * <p>组件类型用包装类型：Jackson 3 默认拒绝把缺失字段映射到基本类型，计划请求与命令行都不带该字段，
     * 用 {@code boolean} 会让它们全部返回 400。</p>
     */
    public Boolean applyAccess() {
        return Boolean.TRUE.equals(applyAccess);
    }

    /** 勾选的删除项；未提供时为空列表。 */
    public List<String> deleteKeys() {
        return deleteKeys == null ? List.of() : deleteKeys;
    }
}
