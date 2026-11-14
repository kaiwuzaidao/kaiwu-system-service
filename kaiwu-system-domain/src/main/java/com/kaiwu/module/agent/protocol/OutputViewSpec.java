package com.kaiwu.module.agent.protocol;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Reviewed presentation and read navigation; declarations never grant execution rights. */
public record OutputViewSpec(
        String title,
        List<Field> fields,
        @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
                Pagination pagination,
        @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
                Detail detail) {
    public OutputViewSpec(String title, List<Field> fields) {
        this(title, fields, null, null);
    }
    /** Bounded page parameters; no total count is inferred from a result page. */
    public record Pagination(String pageParam, String sizeParam) {}
    /** A read-only capability in the same project, with one safe row field as its argument. */
    public record Detail(String label, String capabilityCode, String param, String rowField) {}

    public void validateNavigation(
            String projectCode,
            Map<String, ParamSpec> params,
            InputFormSpec form,
            boolean readOnly,
            Map<String, RedactRule> redact) {
        if ((pagination != null || detail != null) && !readOnly)
            throw new IllegalArgumentException("Navigation requires read-only source");
        if (pagination != null) {
            if (form == null || pagination.pageParam().equals(pagination.sizeParam()))
                throw new IllegalArgumentException("Pagination requires distinct form parameters");
            for (String name : List.of(pagination.pageParam(), pagination.sizeParam())) {
                var spec = params.get(name);
                if (spec == null
                        || spec.type() != ParamType.INT
                        || spec.min() == null
                        || spec.min() != 1
                        || spec.max() == null
                        || !(spec.defaultValue() instanceof Number))
                    throw new IllegalArgumentException("Pagination requires bounded integer defaults");
            }
            if (params.get(pagination.sizeParam()).max() > 50)
                throw new IllegalArgumentException("Page size exceeds card projection limit");
        }
        if (detail != null) {
            text(detail.label());
            if (detail.capabilityCode() == null
                    || !detail.capabilityCode().startsWith(projectCode + ".")
                    || !detail.capabilityCode().matches("[a-z][a-z0-9_.-]{1,159}")
                    || detail.param() == null
                    || !detail.param().matches("[A-Za-z][A-Za-z0-9_]{0,63}")
                    || !fields.stream().anyMatch(field -> field.name().equals(detail.rowField()))
                    || redact.containsKey(detail.rowField()))
                throw new IllegalArgumentException("Invalid detail binding");
        }
    }

    public OutputViewSpec {
        fields = List.copyOf(fields);
    }

    /** Dictionary codes reference managed dictionaries; labels are plain text, never HTML or URLs. */
    public record Field(String name, String label, Format format, String dictCode) {}

    public enum Format {
        TEXT,
        BOOLEAN_ENABLED,
        DATETIME,
        DICTIONARY
    }

    /** Validate against the exact reviewed output boundary before registration and execution. */
    public void validate(Set<String> outboundFields) {
        text(title);
        if (fields.isEmpty() || fields.size() > 64) throw new IllegalArgumentException("Invalid output fields");
        var names = new HashSet<String>();
        for (var field : fields) {
            text(field.label());
            if (field.name() == null
                    || !field.name().matches("[A-Za-z][A-Za-z0-9_]{0,63}")
                    || "sourceProjectId".equals(field.name())
                    || !names.add(field.name())
                    || !outboundFields.contains(field.name())
                    || field.format() == null)
                throw new IllegalArgumentException("Output fields must be unique whitelisted fields");
            if (field.format() == Format.DICTIONARY) {
                if (field.dictCode() == null
                        || !field.dictCode().matches("[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*){1,5}")
                        || field.dictCode().length() > 100)
                    throw new IllegalArgumentException("Invalid managed dictionary code");
            } else if (field.dictCode() != null)
                throw new IllegalArgumentException("Dictionary requires DICTIONARY format");
        }
    }

    private static void text(String value) {
        if (value == null
                || value.isBlank()
                || value.length() > 100
                || value.chars().anyMatch(Character::isISOControl))
            throw new IllegalArgumentException("Invalid output label");
    }
}
