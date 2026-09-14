package com.kaiwu.module.scheduler;

public record SchedulerClaimView(boolean acquired, String executionId) {

    public static SchedulerClaimView acquired(String executionId) {
        return new SchedulerClaimView(true, executionId);
    }

    public static SchedulerClaimView rejected() {
        return new SchedulerClaimView(false, null);
    }
}
