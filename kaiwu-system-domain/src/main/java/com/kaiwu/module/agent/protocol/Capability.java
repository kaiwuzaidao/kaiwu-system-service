package com.kaiwu.module.agent.protocol;

import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * 一条可被 Agent 调用的能力（ADR 0030 第 3 条的能力契约）。
 *
 * <p>每个字段都承载一条安全约束，缺一即可能绕过该约束，因此校验放在紧凑构造器里：
 * 缺必填字段的能力**构造不出来**，而不是构造出来之后等着谁去检查。本地能力因此
 * 在启动装配时就会失败，不会带着半个契约进入目录。</p>
 *
 * <p>{@code verifiedReadOnly} 决定能否免二次确认，**不接受自报**：本地能力由平台
 * 代码声明即认定（代码在评审范围内），远程能力只能由平台侧登记，starter 上报的
 * 该字段一律忽略。</p>
 */
public record Capability(
        String projectCode,
        String code,
        String version,
        String description,
        String permission,
        DataScope dataScope,
        Map<String, ParamSpec> paramsSchema,
        Set<String> outboundFields,
        Map<String, RedactRule> redact,
        boolean readOnly,
        boolean verifiedReadOnly,
        boolean idempotent,
        com.kaiwu.module.agent.vo.AgentInputFormView.Definition inputForm,
        OutputViewSpec outputView) {

    /** Legacy declarations have no form; adding metadata does not grant execution rights. */
    public Capability(
            String projectCode,
            String code,
            String version,
            String description,
            String permission,
            DataScope dataScope,
            Map<String, ParamSpec> paramsSchema,
            Set<String> outboundFields,
            Map<String, RedactRule> redact,
            boolean readOnly,
            boolean verifiedReadOnly,
            boolean idempotent) {
        this(
                projectCode,
                code,
                version,
                description,
                permission,
                dataScope,
                paramsSchema,
                outboundFields,
                redact,
                readOnly,
                verifiedReadOnly,
                idempotent,
                null);
    }

    public Capability(
            String projectCode,
            String code,
            String version,
            String description,
            String permission,
            DataScope dataScope,
            Map<String, ParamSpec> paramsSchema,
            Set<String> outboundFields,
            Map<String, RedactRule> redact,
            boolean readOnly,
            boolean verifiedReadOnly,
            boolean idempotent,
            com.kaiwu.module.agent.vo.AgentInputFormView.Definition inputForm) {
        this(
                projectCode,
                code,
                version,
                description,
                permission,
                dataScope,
                paramsSchema,
                outboundFields,
                redact,
                readOnly,
                verifiedReadOnly,
                idempotent,
                inputForm,
                null);
    }

    /** 控制面自身的能力命名空间。 */
    public static final String SYSTEM_PROJECT_CODE = "system";

    /**
     * 身份类参数一律由服务端从 Context 注入，能力不得声明。
     *
     * <p>否则模型可以生成 {@code {userId: "<他人>"}} 去读别人的数据（ADR 0030 第 4 条）。</p>
     */
    private static final Set<String> FORBIDDEN_PARAM_NAMES =
            Set.of("userid", "user_id", "tenantid", "tenant_id", "rolecode", "role_code", "operator", "actor");

    public Capability {
        requireText(projectCode, "projectCode");
        requireText(code, "code");
        requireText(version, "version");
        requireText(description, "description");
        requireText(permission, "permission");
        if (dataScope == null) {
            throw new IllegalArgumentException(code + " 必须显式声明 dataScope，不允许默认为 ALL");
        }
        if (paramsSchema == null) {
            throw new IllegalArgumentException(code + " 缺少 paramsSchema");
        }
        for (String name : paramsSchema.keySet()) {
            if (FORBIDDEN_PARAM_NAMES.contains(name.toLowerCase(Locale.ROOT))) {
                throw new IllegalArgumentException(code + " 不得声明身份类参数：" + name + "，该值应由服务端从 Context 注入");
            }
        }
        if (verifiedReadOnly && !readOnly) {
            throw new IllegalArgumentException(code + " 声明了 verifiedReadOnly 却不是 readOnly");
        }
        if (inputForm != null) {
            if (!permission.equals(inputForm.permission())
                    || inputForm.projectCode() != null && !projectCode.equals(inputForm.projectCode()))
                throw new IllegalArgumentException("表单权限及项目必须与能力一致");
            var names = new java.util.HashSet<String>();
            for (var field : inputForm.fields()) {
                if (!Set.of("text", "slug", "javaPackage").contains(field.format()))
                    throw new IllegalArgumentException("不支持的表单格式");
                var spec = paramsSchema.get(field.name());
                if (!names.add(field.name())
                        || spec == null
                        || !spec.type().name().equals(field.type())
                        || !java.util.Objects.equals(
                                field.values(),
                                spec.values() == null
                                        ? null
                                        : spec.values().stream().sorted().toList())
                        || field.multiline() && spec.type() != ParamType.STRING
                        || !java.util.Objects.equals(spec.min(), field.min())
                        || !java.util.Objects.equals(spec.max(), field.max())
                        || spec.required() != field.required()
                        || !java.util.Objects.equals(spec.maxLength(), field.maxLength()))
                    throw new IllegalArgumentException("表单字段必须与参数契约一致");
            }
            if (!names.equals(paramsSchema.keySet())) throw new IllegalArgumentException("表单必须声明全部参数");
            new InputFormSpec(
                            "form",
                            inputForm.fields().stream()
                                    .map(field -> new InputFormSpec.Field(
                                            field.name(), field.name(), field.multiline(), field.dictCode()))
                                    .toList())
                    .validate(paramsSchema);
        }
        paramsSchema = Map.copyOf(paramsSchema);
        outboundFields = outboundFields == null ? Set.of() : Set.copyOf(outboundFields);
        redact = redact == null ? Map.of() : Map.copyOf(redact);
        if (outputView != null) outputView.validate(outboundFields);
    }

    private static void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("能力契约缺少必填字段：" + field);
        }
    }

    /** 免二次确认的条件：只读，且只读性经平台认定。自称只读不算。 */
    public boolean canSkipConfirmation() {
        return readOnly && verifiedReadOnly;
    }

    public boolean hasParam(String name) {
        return paramsSchema.containsKey(name);
    }

    public static Builder builder(String code) {
        return new Builder(code);
    }

    /**
     * 带安全默认值的构造器：可省略项一律默认到最保守的取值
     * （不外发、非只读、需确认、不幂等），必填项仍须显式提供。
     */
    public static final class Builder {

        private final String code;
        private String projectCode = SYSTEM_PROJECT_CODE;
        private String version = "1";
        private String description;
        private String permission;
        private DataScope dataScope;
        private Map<String, ParamSpec> paramsSchema = Map.of();
        private Set<String> outboundFields = Set.of();
        private Map<String, RedactRule> redact = Map.of();
        private boolean readOnly;
        private boolean verifiedReadOnly;
        private boolean idempotent;
        private com.kaiwu.module.agent.vo.AgentInputFormView.Definition inputForm;

        private Builder(String code) {
            this.code = code;
        }

        public Builder description(String value) {
            this.description = value;
            return this;
        }

        public Builder permission(String value) {
            this.permission = value;
            return this;
        }

        public Builder dataScope(DataScope value) {
            this.dataScope = value;
            return this;
        }

        public Builder params(Map<String, ParamSpec> value) {
            this.paramsSchema = value;
            return this;
        }

        /** Declare ordered text fields. Constraints always come from paramsSchema. */
        public Builder inputForm(
                String titleKey, java.util.List<String> names, Set<String> multiline, Map<String, String> formats) {
            return inputForm(titleKey, names, multiline, formats, Map.of());
        }

        /** Enum labels use managed dictionaries; values remain constrained by paramsSchema. */
        public Builder inputForm(
                String titleKey,
                java.util.List<String> names,
                Set<String> multiline,
                Map<String, String> formats,
                Map<String, String> dictionaries) {
            new InputFormSpec(
                            titleKey,
                            names.stream()
                                    .map(name -> new InputFormSpec.Field(
                                            name, name, multiline.contains(name), dictionaries.get(name)))
                                    .toList())
                    .validate(paramsSchema);
            this.inputForm = new com.kaiwu.module.agent.vo.AgentInputFormView.Definition(
                    titleKey,
                    permission,
                    names.stream()
                            .map(name -> {
                                var spec = paramsSchema.get(name);
                                if (spec == null) throw new IllegalArgumentException("未知表单字段：" + name);
                                return new com.kaiwu.module.agent.vo.AgentInputFormView.Field(
                                        name,
                                        "agent.input." + name,
                                        spec.required(),
                                        spec.maxLength(),
                                        multiline.contains(name),
                                        formats.getOrDefault(name, "text"),
                                        spec.type().name(),
                                        spec.min(),
                                        spec.max(),
                                        null,
                                        dictionaries.get(name),
                                        spec.values() == null
                                                ? null
                                                : spec.values().stream()
                                                        .sorted()
                                                        .toList());
                            })
                            .toList());
            return this;
        }

        public Builder outboundFields(String... fields) {
            this.outboundFields = Set.of(fields);
            return this;
        }

        public Builder redact(Map<String, RedactRule> value) {
            this.redact = value;
            return this;
        }

        /** 平台自身代码声明的只读能力：代码在评审范围内，声明即认定。 */
        public Builder verifiedReadOnly() {
            this.readOnly = true;
            this.verifiedReadOnly = true;
            this.idempotent = true;
            return this;
        }

        public Capability build() {
            return new Capability(
                    projectCode,
                    code,
                    version,
                    description,
                    permission,
                    dataScope,
                    paramsSchema,
                    outboundFields,
                    redact,
                    readOnly,
                    verifiedReadOnly,
                    idempotent,
                    inputForm);
        }
    }
}
