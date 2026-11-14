package com.kaiwu.module.agent.vo;

import java.util.List;
import java.util.Map;

/** Server-owned form metadata; values are user input, never execution authorization. */
public record AgentInputFormView(String capabilityCode, Map<String, Object> values, Definition definition) {
    /** Compatibility constructor for stored v1 messages. New forms must supply a definition. */
    public AgentInputFormView(String capabilityCode, Map<String, Object> values) {
        this(capabilityCode, values, null);
    }

    /** Controls are derived from the reviewed parameter schema. */
    public record Definition(String titleKey, String permission, List<Field> fields, String projectCode, String title) {
        public Definition(String titleKey, String permission, List<Field> fields) {
            this(titleKey, permission, fields, null, null);
        }

        public Definition {
            fields = List.copyOf(fields);
        }
    }

    /** Required and length constraints are derived from the capability parameter schema. */
    public record Field(
            String name,
            String labelKey,
            boolean required,
            Integer maxLength,
            boolean multiline,
            String format,
            String type,
            Integer min,
            Integer max,
            String label,
            String dictCode,
            List<String> values) {
        public Field(
                String name,
                String labelKey,
                boolean required,
                Integer maxLength,
                boolean multiline,
                String format,
                String type,
                Integer min,
                Integer max,
                String label) {
            this(name, labelKey, required, maxLength, multiline, format, type, min, max, label, null, null);
        }

        public Field(
                String name, String labelKey, boolean required, Integer maxLength, boolean multiline, String format) {
            this(name, labelKey, required, maxLength, multiline, format, "STRING", null, null, null);
        }
    }
}
