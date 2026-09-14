package com.kaiwu.module.projecthealth;

import com.kaiwu.module.projecthealth.vo.ProjectHealthView.CheckView;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import tools.jackson.databind.ObjectMapper;

/**
 * 体检判定逻辑（ADR 0012 第 5 节）。
 *
 * <p>刻意做成不碰网络、不碰数据库的纯函数：判定规则是这个功能里最需要被测试覆盖、
 * 也最容易随模板演进而改错的部分，把它和 GitLab 访问分开才能无条件单测。</p>
 *
 * <p>三种输入状态必须区分清楚：</p>
 * <ul>
 *   <li>读到了内容 → 按规则判 PASS/WARN/FAIL；</li>
 *   <li>确认文件不存在（HTTP 404）→ 该文件相关的检查判 FAIL；</li>
 *   <li>无法确认（GitLab 不可达、仓库未绑定）→ UNKNOWN，**绝不当成失败**。
 *       平台看不到的东西不能算不合格，否则一次网络抖动就会给项目扣上不合规的帽子。</li>
 * </ul>
 */
@Component
public class ProjectHealthEvaluator {

    static final String PASS = "PASS";
    static final String WARN = "WARN";
    static final String FAIL = "FAIL";
    static final String UNKNOWN = "UNKNOWN";

    private final ObjectMapper objectMapper;

    public ProjectHealthEvaluator(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * @param sources           读到的四个契约面文件；{@code Optional.empty()} 表示确认不存在
     * @param currentTemplate   平台当前模板版本
     * @param currentStarter    平台当前 Starter 版本
     */
    public List<CheckView> evaluate(RepositorySources sources, String currentTemplate, String currentStarter) {
        List<CheckView> checks = new ArrayList<>();
        checks.add(manifestCheck(sources.manifest(), sources.backendReadable()));
        checks.add(backendGateCheck(sources.backendCi(), sources.backendReadable()));
        checks.add(frontendGateCheck(sources.frontendPackageJson(), sources.frontendReadable()));
        checks.add(templateVersionCheck(sources.manifest(), sources.backendReadable(), currentTemplate));
        checks.add(starterVersionCheck(sources.backendPom(), sources.backendReadable(), currentStarter));
        return List.copyOf(checks);
    }

    /** 汇总：任一 FAIL 即 FAIL，其次 WARN，全部 UNKNOWN 时为 UNKNOWN。 */
    public String summarize(List<CheckView> checks) {
        if (checks.stream().anyMatch(check -> FAIL.equals(check.verdict()))) return FAIL;
        if (checks.stream().anyMatch(check -> WARN.equals(check.verdict()))) return WARN;
        if (checks.stream().allMatch(check -> UNKNOWN.equals(check.verdict()))) return UNKNOWN;
        return PASS;
    }

    private CheckView manifestCheck(Optional<String> manifest, boolean readable) {
        if (!readable) {
            return unknown("contract.manifest", "契约清单", "后端仓库未绑定或不可读");
        }
        if (manifest.isEmpty()) {
            return new CheckView(
                    "contract.manifest", "契约清单", FAIL, "docs/kaiwu-project-blueprint.json 已不存在，前后端失去共享的模块与权限契约");
        }
        try {
            objectMapper.readTree(manifest.get());
        } catch (Exception exception) {
            return new CheckView("contract.manifest", "契约清单", FAIL, "docs/kaiwu-project-blueprint.json 不是合法 JSON");
        }
        return new CheckView("contract.manifest", "契约清单", PASS, "契约清单完整");
    }

    private CheckView backendGateCheck(Optional<String> ci, boolean readable) {
        if (!readable) {
            return unknown("backend.gate", "后端门禁", "后端仓库未绑定或不可读");
        }
        if (ci.isEmpty()) {
            return new CheckView("backend.gate", "后端门禁", FAIL, ".gitlab-ci.yml 已不存在，后端没有任何流水线门禁");
        }
        String content = ci.get();
        if (!content.contains("check-permission-seed.sh")) {
            return new CheckView("backend.gate", "后端门禁", FAIL, "流水线不再执行 check-permission-seed.sh，权限三端同码已失去强制");
        }
        if (!content.contains("check-constraints.sh")) {
            return new CheckView("backend.gate", "后端门禁", FAIL, "流水线不再校验约束目录与 waiver，MUST/WARN/DEFAULT 分级已失去强制");
        }
        if (!content.contains("gitleaks")) {
            return new CheckView("backend.gate", "后端门禁", FAIL, "流水线不再执行 Gitleaks，Secret 泄露门禁已失去强制");
        }
        if (!content.contains("trivy fs") || !content.contains("cyclonedx") || !content.contains("trivy image")) {
            return new CheckView("backend.gate", "后端门禁", FAIL, "流水线缺少 Trivy 文件系统/镜像扫描或 CycloneDX SBOM，供应链门禁不完整");
        }
        if (!content.contains("check-test-baseline.sh")) {
            return new CheckView("backend.gate", "后端门禁", WARN, "流水线不再执行 check-test-baseline.sh，测试基线可被静默删除");
        }
        return new CheckView("backend.gate", "后端门禁", PASS, "后端门禁齐全");
    }

    private CheckView frontendGateCheck(Optional<String> packageJson, boolean readable) {
        if (!readable) {
            return unknown("frontend.gate", "前端门禁", "前端仓库未绑定或不可读");
        }
        if (packageJson.isEmpty()) {
            return new CheckView("frontend.gate", "前端门禁", FAIL, "package.json 已不存在");
        }
        String content = packageJson.get();
        if (!content.contains("check:perm")) {
            return new CheckView("frontend.gate", "前端门禁", FAIL, "package.json 缺少 check:perm，前端权限码不再受校验");
        }
        if (!content.contains("check:constraints")) {
            return new CheckView("frontend.gate", "前端门禁", FAIL, "package.json 缺少 check:constraints，约束目录与 waiver 不再受校验");
        }
        if (!content.contains("check:dict")) {
            return new CheckView("frontend.gate", "前端门禁", WARN, "package.json 缺少 check:dict，页面可能绕过受管字典");
        }
        return new CheckView("frontend.gate", "前端门禁", PASS, "前端门禁齐全");
    }

    private CheckView templateVersionCheck(Optional<String> manifest, boolean readable, String currentTemplate) {
        if (!readable || manifest.isEmpty()) {
            return unknown("version.template", "模板版本", "契约清单不可读");
        }
        String version;
        try {
            version = objectMapper
                    .readTree(manifest.get())
                    .path("templateVersion")
                    .asText("");
        } catch (Exception exception) {
            return unknown("version.template", "模板版本", "契约清单不是合法 JSON");
        }
        if (!StringUtils.hasText(version)) {
            return unknown("version.template", "模板版本", "契约清单未记录模板版本");
        }
        // 版本落后只报 WARN：平台无权要求业务项目跟随升级（ADR 0012 第 5 节）。
        return version.equals(currentTemplate)
                ? new CheckView("version.template", "模板版本", PASS, "与平台当前模板一致：" + version)
                : new CheckView("version.template", "模板版本", WARN, "模板版本为 " + version + "，平台当前为 " + currentTemplate);
    }

    private CheckView starterVersionCheck(Optional<String> pom, boolean readable, String currentStarter) {
        if (!readable || pom.isEmpty()) {
            return unknown("version.starter", "Starter 版本", "后端 pom.xml 不可读");
        }
        String version = between(pom.get(), "<kaiwu-system-starter.version>", "</kaiwu-system-starter.version>");
        if (!StringUtils.hasText(version)) {
            return unknown("version.starter", "Starter 版本", "pom.xml 未声明 Starter 版本");
        }
        return version.equals(currentStarter)
                ? new CheckView("version.starter", "Starter 版本", PASS, "与平台当前 Starter 一致：" + version)
                : new CheckView(
                        "version.starter", "Starter 版本", WARN, "Starter 版本为 " + version + "，平台当前为 " + currentStarter);
    }

    private CheckView unknown(String code, String name, String reason) {
        return new CheckView(code, name, UNKNOWN, reason);
    }

    /**
     * 取两个标记之间的文本。用字符串定位而不是 XML 解析：只取一个已知属性，
     * 引入 XML 解析器反而要处理命名空间和实体展开，风险大于收益。
     */
    private static String between(String source, String open, String close) {
        int start = source.indexOf(open);
        if (start < 0) return null;
        int end = source.indexOf(close, start + open.length());
        if (end < 0) return null;
        return source.substring(start + open.length(), end).trim();
    }

    /**
     * 体检读到的原始素材。{@code Optional.empty()} 表示确认不存在；
     * {@code readable=false} 表示整个仓库无法访问，此时所有 Optional 都无意义。
     */
    public record RepositorySources(
            boolean backendReadable,
            boolean frontendReadable,
            Optional<String> manifest,
            Optional<String> backendCi,
            Optional<String> backendPom,
            Optional<String> frontendPackageJson) {}
}
