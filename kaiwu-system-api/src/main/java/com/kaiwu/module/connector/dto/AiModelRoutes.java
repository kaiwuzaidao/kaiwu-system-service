package com.kaiwu.module.connector.dto;

/** 两个用途分别绑定的模型编号；空值表示默认模型。 */
public record AiModelRoutes(String planModelId, String answerModelId) {}
