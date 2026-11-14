package com.kaiwu.module.agent.vo;

/** System 内置能力及当前调用者的平台权限状态；不包含会话或业务数据。 */
public record AgentLocalCapabilityView(
        String code, String version, String description, String permission, boolean readOnly, boolean available) {}
