package com.kaiwu.module.project.vo;

import java.util.List;

/** 逐个报告请求中的用户是否仍具有效资格。 */
public record ProjectMemberEligibilityResult(List<Item> items) {
    /** 一个候选用户的资格，不包含个人资料。 */
    public record Item(String userId, boolean eligible) {}
}
