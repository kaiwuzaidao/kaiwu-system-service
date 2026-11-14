package com.kaiwu.module.identity.service;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.user.dto.ResetPasswordRequest;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.module.user.dto.UserUpdateRequest;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.starter.KaiwuContext;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface UserService {

    PageResult<UserView> page(String keyword, long current, long size);

    UserView create(UserCreateRequest request, KaiwuContext actor, RequestMetadata metadata);

    UserView update(String id, UserUpdateRequest request, KaiwuContext actor, RequestMetadata metadata);

    UserView updateProfileForAgent(
            String id,
            UserUpdateRequest request,
            UserProfileExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    UserView updateDisplayNameForAgent(
            String id, String displayName, String expectedDisplayName, KaiwuContext actor, RequestMetadata metadata);

    UserView updateStatus(String id, String status, KaiwuContext actor, RequestMetadata metadata);

    void resetPassword(String id, ResetPasswordRequest request, KaiwuContext actor, RequestMetadata metadata);

    void resetPasswordForAgent(
            String id,
            ResetPasswordRequest request,
            UserResetExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    public record UserProfileExpectation(String username, String displayName, String email, String status) {}

    public record UserResetExpectation(String username, String displayName, String status) {}
}
