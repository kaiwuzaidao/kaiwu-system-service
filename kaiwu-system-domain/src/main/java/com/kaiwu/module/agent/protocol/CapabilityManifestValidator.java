package com.kaiwu.module.agent.protocol;

import com.kaiwu.port.agent.protocol.ConfirmationMode;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * 远程能力注册的准入检查。调用者必须先验证独立 Agent 注册凭据，再传入凭据所绑定的项目码。
 *
 * <p>通过校验只表示契约合法，不表示能力已上线或只读性已获批准；不能据此设置 verifiedReadOnly。
 */
@Component
public class CapabilityManifestValidator {
    private static final Pattern PROJECT_CODE = Pattern.compile("[a-z][a-z0-9-]{1,63}");
    private static final Pattern CAPABILITY_CODE = Pattern.compile("[a-z][a-z0-9-]*(\\.[a-z][a-z0-9-]*)+");
    private static final Pattern VERSION = Pattern.compile("[0-9]+(?:\\.[0-9]+){0,2}");
    private static final Pattern PERMISSION = Pattern.compile("[a-z][a-z0-9-]*(:[a-z][a-z0-9-]*){2}");
    private static final Pattern FIELD_NAME = Pattern.compile("[a-zA-Z][a-zA-Z0-9_]{0,63}");
    private static final Set<String> IDENTITY_PARAMS = Set.of(
            "userid",
            "owneruserid",
            "tenantid",
            "rolecode",
            "rolecodes",
            "roles",
            "roleid",
            "roleids",
            "operator",
            "actor",
            "projectid",
            "projectcode",
            "sessionid",
            "sid",
            "permissions",
            "permission",
            "audience",
            "authzversion",
            "correlationid",
            "actionid",
            "idempotencykey");
    private final ManifestParamValidator params = new ManifestParamValidator();

    /**
     * @param authenticatedProjectCode 从已验证注册凭据及项目事实源解析；禁止从请求体直接读取
     * @param registeredPermissions System 中该项目有效 BUTTON 的权限码；禁止使用平台或其他项目的权限集
     */
    public CapabilityManifest validate(
            CapabilityManifest manifest, String authenticatedProjectCode, Set<String> registeredPermissions) {
        return validate(manifest, authenticatedProjectCode, registeredPermissions, Set.of());
    }

    /**
     * 同上，并按项目的受控数据资源校验 {@code dataScope}（ADR 0044）。
     *
     * @param controlledResources 项目已启用的受控资源码；权限码去掉最后一段操作后与之相同，说明该能力触达受控数据：
     *                            此时必须声明 {@code ROLE_SCOPED} 而不能是 {@code ALL}，反过来 {@code ROLE_SCOPED}
     *                            必须对应一个受控资源，否则声明的是无法执行的策略
     */
    public CapabilityManifest validate(
            CapabilityManifest manifest,
            String authenticatedProjectCode,
            Set<String> registeredPermissions,
            Set<String> controlledResources) {
        if (manifest == null) throw invalid("manifest 不能为空");
        requireMatch(PROJECT_CODE, manifest.projectCode(), 64, "projectCode");
        if (Capability.SYSTEM_PROJECT_CODE.equals(manifest.projectCode())) {
            throw invalid("远程能力不能注册 system 命名空间");
        }
        if (!manifest.projectCode().equals(authenticatedProjectCode)) {
            throw invalid("manifest 与注册凭据所属项目不一致");
        }
        requireMatch(CAPABILITY_CODE, manifest.code(), 160, "能力码");
        if (!manifest.code().startsWith(manifest.projectCode() + ".")) {
            throw invalid("能力码必须属于项目命名空间");
        }
        requireMatch(VERSION, manifest.version(), 16, "version");
        requireLength(manifest.description(), 200, "description");
        requireMatch(PERMISSION, manifest.permission(), 128, "权限码");
        if (registeredPermissions == null || !registeredPermissions.contains(manifest.permission())) {
            throw invalid("权限码未在目标项目登记");
        }
        if (manifest.dataScope() == null) throw invalid("dataScope 不能为空");
        boolean controlled =
                controlledResources != null && controlledResources.contains(resourceOf(manifest.permission()));
        if (manifest.dataScope() == DataScope.ROLE_SCOPED && !controlled) {
            throw invalid("ROLE_SCOPED 要求权限前缀对应项目已登记的受控数据资源");
        }
        if (manifest.dataScope() == DataScope.ALL && controlled) {
            throw invalid("权限对应受控数据资源，dataScope 不能声明 ALL，请使用 ROLE_SCOPED");
        }
        if (manifest.params().size() > 32) throw invalid("参数数量不能超过 32");
        for (Map.Entry<String, ParamSpec> entry : manifest.params().entrySet()) {
            requireName(entry.getKey(), "参数名");
            if (IDENTITY_PARAMS.contains(normalized(entry.getKey()))) {
                throw invalid("身份与项目归属参数必须由 Context 注入");
            }
            params.validate(entry.getValue());
        }
        if (manifest.outboundFields().size() > 64) throw invalid("outboundFields 数量不能超过 64");
        manifest.outboundFields().forEach(field -> requireName(field, "outboundFields 字段"));
        for (String field : manifest.redact().keySet()) {
            if (!manifest.outboundFields().contains(field)) {
                throw invalid("redact 字段必须先列入 outboundFields");
            }
        }
        if (manifest.timeoutMs() == null || manifest.timeoutMs() < 100 || manifest.timeoutMs() > 10_000) {
            throw invalid("timeoutMs 必须在 100 到 10000 之间");
        }
        if (manifest.readOnly() == null) throw invalid("readOnly 必须显式声明");
        if (manifest.idempotent() == null) throw invalid("idempotent 必须显式声明");
        if (manifest.confirmation() == null) throw invalid("confirmation 不能为空");
        if (manifest.readOnly() && manifest.confirmation() != ConfirmationMode.NONE) {
            throw invalid("只读能力的 confirmation 必须为 NONE");
        }
        if (manifest.readOnly() && !manifest.idempotent()) throw invalid("只读能力必须声明幂等");
        if (!manifest.readOnly() && manifest.confirmation() == ConfirmationMode.NONE) {
            throw invalid("写能力必须要求确认");
        }
        if (!manifest.readOnly() && !manifest.idempotent()) {
            throw invalid("写能力必须声明幂等");
        }
        return manifest;
    }

    /** 权限码「模块:资源:操作」去掉最后一段操作，得到与受控资源码同形的前缀。 */
    private static String resourceOf(String permission) {
        int cut = permission.lastIndexOf(':');
        return cut < 0 ? permission : permission.substring(0, cut);
    }

    private static void requireMatch(Pattern pattern, String value, int maxLength, String field) {
        requireLength(value, maxLength, field);
        if (!pattern.matcher(value).matches()) throw invalid(field + " 格式非法");
    }

    private static void requireLength(String value, int maxLength, String field) {
        if (value == null || value.isBlank() || value.length() > maxLength) throw invalid(field + " 长度非法");
    }

    private static void requireName(String name, String field) {
        requireMatch(FIELD_NAME, name, 64, field);
        String key = normalized(name);
        if (key.contains("url")
                || key.contains("password")
                || key.contains("passwd")
                || key.contains("secret")
                || key.contains("token")
                || key.contains("credential")
                || key.contains("privatekey")
                || key.equals("authorization")
                || key.equals("context")
                || key.equals("kaiwucontext")) {
            throw invalid(field + " 不得包含凭据或内部地址");
        }
    }

    private static String normalized(String value) {
        return value.replace("_", "").toLowerCase(Locale.ROOT);
    }

    private static IllegalArgumentException invalid(String message) {
        return new IllegalArgumentException("能力 manifest 非法：" + message);
    }
}
