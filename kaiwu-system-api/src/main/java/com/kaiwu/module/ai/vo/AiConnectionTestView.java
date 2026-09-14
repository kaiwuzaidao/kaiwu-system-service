package com.kaiwu.module.ai.vo;

import java.time.LocalDateTime;

public record AiConnectionTestView(
        boolean success, String model, long latencyMs, String message, LocalDateTime testedAt) {}
