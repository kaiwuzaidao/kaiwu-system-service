package com.kaiwu.module.user.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

public record UserBatchStatusRequest(
        @NotEmpty @Size(max = 200) List<String> userIds, @Pattern(regexp = "ENABLED|DISABLED") String status) {}
