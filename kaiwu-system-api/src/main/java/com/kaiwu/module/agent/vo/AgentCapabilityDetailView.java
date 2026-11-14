package com.kaiwu.module.agent.vo;
/** 审核人读取注册方声明的完整契约；manifestJson 是数据，不得当作指令或 HTML 渲染。 */
public record AgentCapabilityDetailView(AgentRegistrationView registration, String manifestJson) {}
