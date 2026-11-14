package com.kaiwu.module.agent.protocol;

import com.kaiwu.port.agent.protocol.ConfirmationMode;
import java.util.Map;
import java.util.Set;

/**
 * 业务项目向 System 注册的能力描述。
 *
 * <p>这是不可信的远程输入；注册前必须通过 {@link CapabilityManifestValidator}，并且
 * {@code verifiedReadOnly} 永远不会由 manifest 提供。远程项目只能声明自己的命名空间，
 * 不能覆盖 System 或其他项目的能力。</p>
 */
public record CapabilityManifest(
        String projectCode,
        String code,
        String version,
        String description,
        String permission,
        DataScope dataScope,
        Map<String, ParamSpec> params,
        Set<String> outboundFields,
        Map<String, RedactRule> redact,
        Boolean readOnly,
        Boolean idempotent,
        ConfirmationMode confirmation,
        Integer timeoutMs,
        @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
                InputFormSpec inputForm,
        @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
                OutputViewSpec outputView) {

    /** V1 manifests retain their wire shape and digest when no form is declared. */
    public CapabilityManifest(
            String projectCode,
            String code,
            String version,
            String description,
            String permission,
            DataScope dataScope,
            Map<String, ParamSpec> params,
            Set<String> outboundFields,
            Map<String, RedactRule> redact,
            Boolean readOnly,
            Boolean idempotent,
            ConfirmationMode confirmation,
            Integer timeoutMs) {
        this(
                projectCode,
                code,
                version,
                description,
                permission,
                dataScope,
                params,
                outboundFields,
                redact,
                readOnly,
                idempotent,
                confirmation,
                timeoutMs,
                null);
    }

    /** Existing input-form declarations keep their wire digest when no result view is declared. */
    public CapabilityManifest(
            String projectCode,
            String code,
            String version,
            String description,
            String permission,
            DataScope dataScope,
            Map<String, ParamSpec> params,
            Set<String> outboundFields,
            Map<String, RedactRule> redact,
            Boolean readOnly,
            Boolean idempotent,
            ConfirmationMode confirmation,
            Integer timeoutMs,
            InputFormSpec inputForm) {
        this(
                projectCode,
                code,
                version,
                description,
                permission,
                dataScope,
                params,
                outboundFields,
                redact,
                readOnly,
                idempotent,
                confirmation,
                timeoutMs,
                inputForm,
                null);
    }

    public CapabilityManifest {
        if (params == null || outboundFields == null || redact == null) {
            throw new IllegalArgumentException("能力 manifest 必须声明 params、outboundFields 和 redact");
        }
        params = Map.copyOf(params);
        if (inputForm != null) inputForm.validate(params);
        outboundFields = Set.copyOf(outboundFields);
        if (outputView != null) {
            outputView.validate(outboundFields);
            outputView.validateNavigation(projectCode, params, inputForm, Boolean.TRUE.equals(readOnly), redact);
        }
        redact = Map.copyOf(redact);
    }
}
