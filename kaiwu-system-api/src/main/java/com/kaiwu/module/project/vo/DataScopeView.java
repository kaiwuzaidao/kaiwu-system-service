package com.kaiwu.module.project.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

/**
 * 项目权限快照里的数据范围（docs/DATA_SCOPE.md §4），Gateway 原样写入 Context 的 {@code ds} 声明。
 *
 * <p>记录组件的顺序就是规范化 JSON 的键顺序，{@code fp} 必须最后；构造应通过
 * {@code DataScopeSnapshotAssembler}，那里负责排序、去重和指纹，直接 new 出来的实例不保证规范。</p>
 *
 * @param v             协议版本，目前恒为 1
 * @param primaryDeptId 用户主部门；没有任何所属部门时缺省
 * @param depts         部门字典，每个部门 ID 只出现一次，按数值升序
 * @param rules         资源码到归约结果，键按字典序
 * @param fp            去掉自身后规范化字节的 SHA-256 前 16 位十六进制
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record DataScopeView(
        int v, String primaryDeptId, List<String> depts, Map<String, DataScopeRuleView> rules, String fp) {}
