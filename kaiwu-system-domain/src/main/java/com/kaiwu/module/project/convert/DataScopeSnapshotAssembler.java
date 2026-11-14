package com.kaiwu.module.project.convert;

import com.kaiwu.module.project.convert.DataScopeReducer.Reduction;
import com.kaiwu.module.project.vo.DataScopeRuleView;
import com.kaiwu.module.project.vo.DataScopeView;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Pattern;

/**
 * 把各资源的归约结果组装成规范化的快照，并计算指纹与体积（docs/DATA_SCOPE.md §4.3–4.5）。
 *
 * <p>同一输入必须得到字节完全相同的输出：System 生成、Gateway 透传、Starter 读取，三方的测试用同一组向量比对。
 * 规范化字节手工拼接而不经过 Jackson，避免序列化库升级悄悄改变键顺序或转义。</p>
 */
public final class DataScopeSnapshotAssembler {

    /** 快照字节上限，编码为 JWT 声明之前、含 {@code fp}。 */
    public static final int MAX_BYTES = 6144;

    private static final int VERSION = 1;
    private static final Pattern DEPT_ID = Pattern.compile("^[0-9]{1,19}$");
    private static final Pattern RESOURCE_CODE = Pattern.compile("^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$");
    private static final Comparator<String> NUMERIC =
            Comparator.comparingInt(String::length).thenComparing(Comparator.naturalOrder());

    private DataScopeSnapshotAssembler() {}

    /**
     * 组装。
     *
     * @param primaryDeptId 用户主部门，没有所属部门时为空
     * @param byResource    资源码到归约结果；调用方保证只含已启用资源
     * @return 规范化快照，调用方再用 {@link #sizeBytes(DataScopeView)} 判断是否超限
     * @throws IllegalArgumentException 部门 ID 或资源码不符合约定，说明上游数据有误，不可静默放行
     */
    public static DataScopeView assemble(String primaryDeptId, Map<String, Reduction> byResource) {
        if (primaryDeptId != null && !DEPT_ID.matcher(primaryDeptId).matches()) {
            throw new IllegalArgumentException("主部门 ID 非法：" + primaryDeptId);
        }
        TreeSet<String> referenced = new TreeSet<>(NUMERIC);
        for (Map.Entry<String, Reduction> entry : byResource.entrySet()) {
            if (!RESOURCE_CODE.matcher(entry.getKey()).matches()) {
                throw new IllegalArgumentException("资源码非法：" + entry.getKey());
            }
            for (String dept : entry.getValue().deptIds()) {
                if (!DEPT_ID.matcher(dept).matches()) {
                    throw new IllegalArgumentException("部门 ID 非法：" + dept);
                }
                referenced.add(dept);
            }
        }
        List<String> depts = new ArrayList<>(referenced);
        Map<String, Integer> indexOf = new HashMap<>();
        for (int i = 0; i < depts.size(); i++) {
            indexOf.put(depts.get(i), i);
        }
        Map<String, DataScopeRuleView> rules = new TreeMap<>();
        byResource.forEach((code, reduction) -> {
            if (reduction.all()) {
                rules.put(code, DataScopeRuleView.everything());
                return;
            }
            List<Integer> indexes = new ArrayList<>();
            for (String dept : reduction.deptIds()) {
                indexes.add(indexOf.get(dept));
            }
            indexes.sort(Comparator.naturalOrder());
            rules.put(code, DataScopeRuleView.departments(indexes));
        });
        DataScopeView bare = new DataScopeView(VERSION, primaryDeptId, List.copyOf(depts), rules, null);
        return new DataScopeView(VERSION, primaryDeptId, bare.depts(), rules, fingerprint(bare));
    }

    /** 规范化紧凑 JSON；{@code view.fp()} 为空时不输出 {@code fp}，用于计算指纹。 */
    public static String canonical(DataScopeView view) {
        StringBuilder json = new StringBuilder(128);
        json.append("{\"v\":").append(view.v());
        if (view.primaryDeptId() != null) {
            json.append(",\"primaryDeptId\":\"").append(view.primaryDeptId()).append('"');
        }
        json.append(",\"depts\":[");
        List<String> depts = view.depts();
        for (int i = 0; i < depts.size(); i++) {
            json.append(i == 0 ? "" : ",").append('"').append(depts.get(i)).append('"');
        }
        json.append("],\"rules\":{");
        boolean first = true;
        for (Map.Entry<String, DataScopeRuleView> rule : new TreeMap<>(view.rules()).entrySet()) {
            json.append(first ? "" : ",").append('"').append(rule.getKey()).append("\":");
            first = false;
            if (Boolean.TRUE.equals(rule.getValue().all())) {
                json.append("{\"all\":true}");
            } else {
                json.append("{\"set\":[");
                List<Integer> set = rule.getValue().set() == null
                        ? List.of()
                        : rule.getValue().set();
                for (int i = 0; i < set.size(); i++) {
                    json.append(i == 0 ? "" : ",").append(set.get(i));
                }
                json.append("]}");
            }
        }
        json.append('}');
        if (view.fp() != null) {
            json.append(",\"fp\":\"").append(view.fp()).append('"');
        }
        return json.append('}').toString();
    }

    /** 去掉 {@code fp} 后规范化字节的 SHA-256 前 16 位十六进制。 */
    public static String fingerprint(DataScopeView view) {
        DataScopeView bare = new DataScopeView(view.v(), view.primaryDeptId(), view.depts(), view.rules(), null);
        try {
            byte[] digest =
                    MessageDigest.getInstance("SHA-256").digest(canonical(bare).getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(16);
            for (int i = 0; i < 8; i++) {
                hex.append(String.format("%02x", digest[i]));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("JDK 缺少 SHA-256", e);
        }
    }

    /** 含 {@code fp} 的规范化字节数，与 {@link #MAX_BYTES} 比较。 */
    public static int sizeBytes(DataScopeView view) {
        return canonical(view).getBytes(StandardCharsets.UTF_8).length;
    }
}
