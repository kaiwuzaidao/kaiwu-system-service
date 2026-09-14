package com.kaiwu.module.user.vo;

import java.util.List;

public record UserImportResult(int total, int succeeded, int failed, List<UserImportError> errors) {}
