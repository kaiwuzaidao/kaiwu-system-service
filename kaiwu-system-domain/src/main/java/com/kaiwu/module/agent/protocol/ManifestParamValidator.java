package com.kaiwu.module.agent.protocol;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;

/** 远程参数 schema 必须有限且自洽，默认值必须与声明的类型和范围一致。 */
final class ManifestParamValidator {
    void validate(ParamSpec spec) {
        if (spec == null) throw invalid();
        // Remote capabilities operate on the credential-bound project, never on model-selected projects.
        if (spec.enumFrom() != null) throw invalid();
        if (spec.type() != ParamType.INT
                && spec.type() != ParamType.STRING_LIST
                && (spec.min() != null || spec.max() != null)) throw invalid();
        if (spec.type() != ParamType.STRING && spec.type() != ParamType.STRING_LIST && spec.maxLength() != null)
            throw invalid();
        if (spec.type() != ParamType.ENUM && spec.values() != null) throw invalid();
        switch (spec.type()) {
            case STRING -> {
                if (spec.maxLength() == null || spec.maxLength() < 1 || spec.maxLength() > 4000) throw invalid();
                if (spec.defaultValue() != null
                        && (!(spec.defaultValue() instanceof String value) || value.length() > spec.maxLength()))
                    throw invalid();
            }
            case STRING_LIST -> {
                if (spec.min() == null
                        || spec.max() == null
                        || spec.min() < 0
                        || spec.max() < spec.min()
                        || spec.max() > 100
                        || spec.maxLength() == null
                        || spec.maxLength() < 1
                        || spec.maxLength() > 4000
                        || spec.defaultValue() != null) throw invalid();
            }
            case ENUM -> {
                if (spec.values() == null
                        || spec.values().isEmpty()
                        || spec.values().size() > 100) throw invalid();
                if (spec.values().stream().anyMatch(value -> value.isBlank() || value.length() > 128)) throw invalid();
                if (spec.defaultValue() != null
                        && (!(spec.defaultValue() instanceof String value)
                                || !spec.values().contains(value))) throw invalid();
            }
            case INT -> {
                if (spec.min() == null || spec.max() == null || spec.min() > spec.max()) throw invalid();
                if (spec.defaultValue() != null) {
                    if (!(spec.defaultValue() instanceof Number number)) throw invalid();
                    try {
                        int value = new BigDecimal(number.toString()).intValueExact();
                        if (value < spec.min() || value > spec.max()) throw invalid();
                    } catch (ArithmeticException | NumberFormatException exception) {
                        throw invalid();
                    }
                }
            }
            case BOOL -> {
                if (spec.defaultValue() != null && !(spec.defaultValue() instanceof Boolean)) throw invalid();
            }
            case DATETIME -> {
                if (spec.defaultValue() != null) {
                    if (!(spec.defaultValue() instanceof String value) || value.length() > 40) throw invalid();
                    try {
                        LocalDateTime.parse(value);
                    } catch (DateTimeParseException exception) {
                        throw invalid();
                    }
                }
            }
        }
    }

    private static IllegalArgumentException invalid() {
        return new IllegalArgumentException("能力 manifest 参数 schema 或默认值非法");
    }
}
