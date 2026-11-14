package com.kaiwu.module.operation.vo;

/** 受限于本项目及生产者的投递回执，不包含用户身份资料和待办正文。 */
public record ManagedTodoReceipt(
        String disposition, long storedSequence, String storedState, boolean storedTerminal, String payloadDigest) {}
