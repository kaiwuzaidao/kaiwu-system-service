package com.kaiwu.module.operation.vo;

public record SchedulerClaimView(boolean acquired, String executionId) {

    public static SchedulerClaimView acquired(String executionId) {
        return new SchedulerClaimView(true, executionId);
    }

    public static SchedulerClaimView rejected() {
        return new SchedulerClaimView(false, null);
    }
}
