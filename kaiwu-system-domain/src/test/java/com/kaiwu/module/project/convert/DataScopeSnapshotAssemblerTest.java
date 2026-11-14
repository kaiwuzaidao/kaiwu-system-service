package com.kaiwu.module.project.convert;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.module.project.convert.DataScopeReducer.Reduction;
import com.kaiwu.module.project.vo.DataScopeView;
import com.kaiwu.module.project.vo.ProjectAccessView;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** 规范化、指纹与体积；共用测试向量来自 docs/DATA_SCOPE.md §4.4，Gateway 与 Starter 的测试断言同一组值。 */
class DataScopeSnapshotAssemblerTest {

    /** DATA_SCOPE.md §4.4 的规范化字节。 */
    private static final String GOLDEN =
            "{\"v\":1,\"primaryDeptId\":\"101\",\"depts\":[\"101\",\"102\",\"105\"],\"rules\":{"
                    + "\"crm:contract\":{\"all\":true},"
                    + "\"crm:customer\":{\"set\":[0,1,2]},"
                    + "\"crm:followup\":{\"set\":[]}}}";

    private static final String GOLDEN_FINGERPRINT = "d361b479f54b4be2";

    /** 故意用乱序的输入验证规范化不依赖调用方顺序。 */
    private static DataScopeView golden() {
        Map<String, Reduction> byResource = new LinkedHashMap<>();
        byResource.put("crm:followup", Reduction.selfOnly());
        byResource.put("crm:customer", new Reduction(false, Set.of("105", "101", "102")));
        byResource.put("crm:contract", Reduction.everything());
        return DataScopeSnapshotAssembler.assemble("101", byResource);
    }

    /** 产出与契约文档一致的共用测试向量，Gateway 与 Starter 的测试断言同一组值。 */
    @Test
    void producesTheSharedGoldenVector() {
        DataScopeView view = golden();

        assertThat(DataScopeSnapshotAssembler.canonical(
                        new DataScopeView(view.v(), view.primaryDeptId(), view.depts(), view.rules(), null)))
                .isEqualTo(GOLDEN);
        assertThat(view.fp()).isEqualTo(GOLDEN_FINGERPRINT);
    }

    /** Jackson 序列化结果与手工拼接的规范化字节逐字节相同。 */
    @Test
    void jacksonOutputIsByteIdenticalToTheCanonicalForm() {
        DataScopeView view = golden();

        assertThat(JsonMapper.builder().build().writeValueAsString(view))
                .isEqualTo(DataScopeSnapshotAssembler.canonical(view))
                .endsWith("\"fp\":\"" + GOLDEN_FINGERPRINT + "\"}");
    }

    /** 部门字典按数值升序而不是字典序，缺省主部门时不输出该键。 */
    @Test
    void departmentsSortNumericallyNotLexically() {
        DataScopeView view = DataScopeSnapshotAssembler.assemble(
                null, Map.of("crm:customer", new Reduction(false, Set.of("9", "100", "20"))));

        assertThat(view.depts()).containsExactly("9", "20", "100");
        assertThat(view.primaryDeptId()).isNull();
        assertThat(DataScopeSnapshotAssembler.canonical(view)).doesNotContain("primaryDeptId");
    }

    /** 多个资源共用的部门在字典里只出现一次。 */
    @Test
    void sharedDepartmentsAppearOnceInTheDictionary() {
        DataScopeView view = DataScopeSnapshotAssembler.assemble(
                "1",
                Map.of(
                        "crm:a", new Reduction(false, Set.of("1", "2")),
                        "crm:b", new Reduction(false, Set.of("2", "3"))));

        assertThat(view.depts()).containsExactly("1", "2", "3");
        assertThat(view.rules().get("crm:b").set()).containsExactly(1, 2);
    }

    /** 没有资源引用的部门不进入字典。 */
    @Test
    void departmentsNobodyReferencesAreNotInTheDictionary() {
        DataScopeView view = DataScopeSnapshotAssembler.assemble("101", Map.of("crm:a", Reduction.selfOnly()));

        assertThat(view.depts()).isEmpty();
    }

    /** 指纹随内容变化，与输入顺序无关。 */
    @Test
    void fingerprintChangesWithContentButNotWithInputOrder() {
        DataScopeView changed = DataScopeSnapshotAssembler.assemble(
                "101", Map.of("crm:customer", new Reduction(false, Set.of("101", "102"))));

        assertThat(changed.fp()).isNotEqualTo(GOLDEN_FINGERPRINT);
        assertThat(golden().fp()).isEqualTo(golden().fp());
    }

    /** 体积按含指纹的规范化字节计算，超大快照会超过上限。 */
    @Test
    void sizeIncludesTheFingerprintAndBoundsTheSnapshot() {
        DataScopeView view = golden();
        int size = DataScopeSnapshotAssembler.sizeBytes(view);

        assertThat(size).isEqualTo(GOLDEN.length() + ",\"fp\":\"\"".length() + 16);

        List<String> many = java.util.stream.IntStream.range(0, 400)
                .mapToObj(i -> String.valueOf(900000000000000000L + i))
                .toList();
        DataScopeView large = DataScopeSnapshotAssembler.assemble(
                "1", Map.of("crm:customer", new Reduction(false, Set.copyOf(many))));
        assertThat(DataScopeSnapshotAssembler.sizeBytes(large)).isGreaterThan(DataScopeSnapshotAssembler.MAX_BYTES);
    }

    /** 按真实的 19 位部门 ID 计算，128 个部门被三个资源完全重叠引用仍在上限内，这是对外宣称 128 的依据。 */
    @Test
    void oneHundredTwentyEightRealSizedDepartmentsFitEvenWhenThreeResourcesShareThemAll() {
        // 真实部门 ID 由 currentTimeMillis * 10^6 生成，是 19 位；这是对外宣称 128 个部门的依据。
        Set<String> depts = java.util.stream.IntStream.range(0, 128)
                .mapToObj(i -> String.valueOf(1_780_000_000_000_000_000L + i))
                .collect(java.util.stream.Collectors.toSet());
        Reduction all128 = new Reduction(false, depts);
        DataScopeView view = DataScopeSnapshotAssembler.assemble(
                "1780000000000000000", Map.of("crm:a", all128, "crm:b", all128, "crm:c", all128));

        assertThat(DataScopeSnapshotAssembler.sizeBytes(view)).isLessThan(5000);
    }

    /** 256 个真实大小的部门在单个资源上就已超限，说明宣称 256 不成立。 */
    @Test
    void twoHundredAndFiftySixRealSizedDepartmentsOnOneResourceAlreadyOverflow() {
        Set<String> depts = java.util.stream.IntStream.range(0, 256)
                .mapToObj(i -> String.valueOf(1_780_000_000_000_000_000L + i))
                .collect(java.util.stream.Collectors.toSet());
        DataScopeView view = DataScopeSnapshotAssembler.assemble(
                "1780000000000000000", Map.of("crm:a", new Reduction(false, depts)));

        assertThat(DataScopeSnapshotAssembler.sizeBytes(view)).isGreaterThan(DataScopeSnapshotAssembler.MAX_BYTES);
    }

    /** 格式非法的部门 ID 或资源码直接拒绝，而不是转义后放行。 */
    @Test
    void rejectsMalformedIdentifiersInsteadOfEscapingThem() {
        assertThatThrownBy(() -> DataScopeSnapshotAssembler.assemble("1\"x", Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> DataScopeSnapshotAssembler.assemble(
                        "1", Map.of("crm:customer", new Reduction(false, Set.of("12a")))))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> DataScopeSnapshotAssembler.assemble("1", Map.of("Bad Code", Reduction.selfOnly())))
                .isInstanceOf(IllegalArgumentException.class);
    }

    /** 没有数据范围的入口授权快照，序列化结果与引入数据范围之前完全一致。 */
    @Test
    void accessViewWithoutDataScopeSerialisesExactlyAsBefore() {
        String json = JsonMapper.builder()
                .build()
                .writeValueAsString(new ProjectAccessView("9001", "demo", List.of("a:b:c"), List.of("r")));

        assertThat(json)
                .isEqualTo("{\"projectId\":\"9001\",\"projectCode\":\"demo\","
                        + "\"permissions\":[\"a:b:c\"],\"projectRoleCodes\":[\"r\"]}");
    }

    /** 带数据范围时，它作为最后一个键追加在原有字段之后。 */
    @Test
    void accessViewWithDataScopeAppendsItAsTheLastKey() {
        String json = JsonMapper.builder()
                .build()
                .writeValueAsString(new ProjectAccessView("9001", "demo", List.of(), List.of(), golden()));

        assertThat(json).contains(",\"dataScope\":{\"v\":1,\"primaryDeptId\":\"101\"");
    }
}
