package com.kaiwu.module.agent.protocol;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

/** Reviewed display metadata only. Types, bounds and permissions come from the capability schema. */
public record InputFormSpec(String title, List<Field> fields) {
    public InputFormSpec {
        fields = List.copyOf(fields);
    }

    /** Plain text labels are rendered as text, never HTML, scripts or translation keys. */
    public record Field(
            String name, String label, boolean multiline, @JsonInclude(JsonInclude.Include.NON_NULL) String dictCode) {
        public Field(String name, String label, boolean multiline) {
            this(name, label, multiline, null);
        }
    }

    /** Fail closed on incomplete or unsupported form contracts before registration or dispatch. */
    public void validate(Map<String, ParamSpec> params) {
        text(title, 100);
        if (fields.isEmpty() || fields.size() > 32) throw new IllegalArgumentException("Invalid form fields");
        var names = new HashSet<String>();
        for (var field : fields) {
            text(field.label(), 100);
            var spec = params.get(field.name());
            if (!names.add(field.name()) || spec == null || spec.enumFrom() != null)
                throw new IllegalArgumentException("Form fields must match parameter schema");
            if (spec.type() == ParamType.ENUM) {
                if (field.dictCode() == null
                        || !field.dictCode().matches("[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+")
                        || field.dictCode().length() > 128
                        || spec.values() == null
                        || spec.values().isEmpty()
                        || spec.values().size() > 100)
                    throw new IllegalArgumentException(
                            "Enum form fields require a managed dictionary and bounded values");
            } else if (field.dictCode() != null) {
                throw new IllegalArgumentException("Only enum fields support dictionaries");
            }
            if (field.multiline() && spec.type() != ParamType.STRING)
                throw new IllegalArgumentException("Only text fields support multiline");
        }
        if (!names.equals(params.keySet())) throw new IllegalArgumentException("Form must cover every parameter");
    }

    private static void text(String value, int limit) {
        if (value == null
                || value.isBlank()
                || value.length() > limit
                || value.chars().anyMatch(Character::isISOControl))
            throw new IllegalArgumentException("Invalid form label");
    }
}
