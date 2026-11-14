package com.kaiwu.module.agent.service;

import static com.kaiwu.testing.AgentTestFixtures.manifest;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.agent.dto.*;
import com.kaiwu.module.agent.entity.*;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.CapabilityManifest;
import com.kaiwu.module.agent.protocol.CapabilityManifestValidator;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.repository.AgentRegistryRepository;
import com.kaiwu.module.agent.service.impl.AgentRegistryServiceImpl;
import com.kaiwu.module.agent.vo.*;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class AgentRegistryServiceTest {
    private static final Instant TIME = Instant.parse("2026-09-23T00:00:00Z");
    private static final Clock CLOCK = Clock.fixed(TIME, ZoneOffset.UTC);
    private static final KaiwuContext ADMIN = actor(Set.of("system:project:list", "system:project:update"));
    private final AgentRegistryRepository repository = mock(AgentRegistryRepository.class);
    private final AgentManifestCodec codec = new AgentManifestCodec();
    private final AuditPort audit = mock(AuditPort.class);
    private final Map<String, AgentCapabilityEntity> rows = new HashMap<>();
    private AgentCredentialEntity savedCredential;
    private AgentRegistryServiceImpl service;
    private String authorization;

    @BeforeEach
    void setup() {
        service = service(CLOCK);
        when(repository.lockProject("10")).thenReturn("crm");
        when(repository.active("10")).thenReturn(true);
        when(repository.isAdmin("10", "1")).thenReturn(true);
        when(repository.permissions("10")).thenReturn(Set.of("record:record:list"));
        when(repository.credential("10")).thenAnswer(call -> savedCredential);
        doAnswer(call -> {
                    savedCredential = call.getArgument(0);
                    return null;
                })
                .when(repository)
                .insertCredential(any());
        doAnswer(call -> {
                    savedCredential = call.getArgument(0);
                    return null;
                })
                .when(repository)
                .updateCredential(any());
        when(repository.capability(eq("10"), anyString())).thenAnswer(call -> rows.get(call.getArgument(1)));
        when(repository.list("10")).thenAnswer(call -> List.copyOf(rows.values()));
        when(repository.count("10")).thenAnswer(call -> (long) rows.size());
        doAnswer(call -> {
                    AgentCapabilityEntity row = call.getArgument(0);
                    rows.put(row.getCapabilityCode(), row);
                    return null;
                })
                .when(repository)
                .insertCapability(any());
        doAnswer(call -> {
                    AgentCapabilityEntity row = call.getArgument(0);
                    rows.put(row.getCapabilityCode(), row);
                    return null;
                })
                .when(repository)
                .updateCapability(any());
        doAnswer(call -> {
                    rows.values().stream()
                            .filter(row -> !"REVOKED".equals(row.getStatus()))
                            .forEach(row -> {
                                row.setStatus(call.getArgument(1));
                                row.setLastSeenAt(null);
                            });
                    return null;
                })
                .when(repository)
                .invalidate(eq("10"), anyString(), any());
        authorization = "Bearer " + service.rotateCredential("10", ADMIN, null).token();
        clearInvocations(repository, audit);
    }

    @Test
    void registrationDoesNotApproveAndIdenticalRegistrationIsIdempotent() {
        AgentRegistrationView first = register("1");
        assertThat(first.status()).isEqualTo("PENDING");
        assertThat(first.description()).isEqualTo("查询记录");
        assertThat(service.list("10", ADMIN).getFirst().description()).isEqualTo("查询记录");
        assertThat(service.detail("10", first.capabilityCode(), ADMIN)
                        .registration()
                        .description())
                .isEqualTo("查询记录");
        assertThat(first.online()).isTrue();
        assertThat(register("1").id()).isEqualTo(first.id());
        verify(repository, times(1)).insertCapability(any());
        verify(repository, times(1)).event(any());
        assertThat(service.detail("10", first.capabilityCode(), ADMIN).manifestJson())
                .contains("record:record:list");
    }

    @Test
    void approveRequiresExactRevisionAndAllowsValidatedWriteManifest() {
        var view = register("1");
        assertThat(review(view, "APPROVED").status()).isEqualTo("APPROVED");
        assertThatThrownBy(() -> service.review(
                        "10",
                        new AgentCapabilityReviewRequest(
                                new AgentCapabilityRevision(view.capabilityCode(), view.version(), "0".repeat(64)),
                                "REVOKED"),
                        ADMIN,
                        null))
                .isInstanceOf(ApiException.class);
        CapabilityManifest write = new CapabilityManifest(
                "crm",
                "crm.record.write",
                "1",
                "写操作",
                "record:record:list",
                DataScope.MEMBER_PROJECTS,
                Map.of(),
                Set.of("id"),
                Map.of(),
                false,
                true,
                ConfirmationMode.REQUIRED,
                3000);
        var pendingWrite = service.register(authorization, bytes(write));
        assertThat(review(pendingWrite, "APPROVED").status()).isEqualTo("APPROVED");
    }

    @Test
    void batchApprovesOnlyValidatedOnlineReadManifests() {
        var first = register("1");
        var second = service.register(authorization, bytes(manifestWithCode("crm.invoice-title.list")));
        clearInvocations(repository, audit);
        var approved = service.reviewBatch(
                "10", new AgentCapabilityBatchReviewRequest(List.of(revision(first), revision(second))), ADMIN, null);
        assertThat(approved).extracting(AgentRegistrationView::status).containsExactly("APPROVED", "APPROVED");
        verify(repository, times(2)).updateCapability(any());
        verify(repository, times(2)).event(any());
        verify(audit, times(2))
                .recordOperationInCallerTransaction(
                        eq(ADMIN), eq("agent"), eq("REVIEW_APPROVED"), anyString(), eq("projectId=10"), any());
    }

    @Test
    void batchRejectsStaleRevisionBeforeUpdatingAnyRow() {
        var first = register("1");
        var second = service.register(authorization, bytes(manifestWithCode("crm.invoice-title.list")));
        var stale = new AgentCapabilityRevision(second.capabilityCode(), second.version(), "0".repeat(64));
        assertThatThrownBy(() -> service.reviewBatch(
                        "10", new AgentCapabilityBatchReviewRequest(List.of(revision(first), stale)), ADMIN, null))
                .isInstanceOf(ApiException.class);
        assertThat(first.status()).isEqualTo("PENDING");
        verify(repository, never()).updateCapability(any());
        verify(audit, never())
                .recordOperationInCallerTransaction(any(), anyString(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void batchCannotApproveWriteOrDuplicateCapabilities() {
        var first = register("1");
        CapabilityManifest write = new CapabilityManifest(
                "crm",
                "crm.record.write",
                "1",
                "写操作",
                "record:record:list",
                DataScope.MEMBER_PROJECTS,
                Map.of(),
                Set.of("id"),
                Map.of(),
                false,
                true,
                ConfirmationMode.REQUIRED,
                3000);
        var pendingWrite = service.register(authorization, bytes(write));
        assertThatThrownBy(() -> service.reviewBatch(
                        "10",
                        new AgentCapabilityBatchReviewRequest(List.of(revision(first), revision(pendingWrite))),
                        ADMIN,
                        null))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> service.reviewBatch(
                        "10",
                        new AgentCapabilityBatchReviewRequest(List.of(revision(first), revision(first))),
                        ADMIN,
                        null))
                .isInstanceOf(ApiException.class);
        verify(repository, never()).updateCapability(any());
    }

    @Test
    void batchRequiresProjectAdminAndPlatformEditPermission() {
        var first = register("1");
        var request = new AgentCapabilityBatchReviewRequest(List.of(revision(first)));
        assertThatThrownBy(() -> service.reviewBatch("10", request, actor(Set.of("system:project:list")), null))
                .isInstanceOf(ApiException.class);
        when(repository.isAdmin("10", "1")).thenReturn(false);
        assertThatThrownBy(() -> service.reviewBatch("10", request, ADMIN, null))
                .isInstanceOf(ApiException.class);
        verify(repository, never()).updateCapability(any());
    }

    private static CapabilityManifest manifestWithCode(String code) {
        return new CapabilityManifest(
                "crm",
                code,
                "1",
                "查询记录",
                "record:record:list",
                DataScope.MEMBER_PROJECTS,
                Map.of(),
                Set.of("id", "title"),
                Map.of(),
                true,
                true,
                ConfirmationMode.NONE,
                3000);
    }

    @Test
    void revokedManifestCannotBeResurrectedByRegistrationOrHeartbeat() {
        var view = register("1");
        review(view, "REVOKED");
        assertThatThrownBy(() -> register("1")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> register("2")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> service.heartbeat(authorization, revision(view)))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> review(view, "APPROVED")).isInstanceOf(ApiException.class);
        assertThat(review(view, "PENDING").online()).isFalse();
        assertThat(register("1").status()).isEqualTo("PENDING");
        assertThat(review(view, "APPROVED").status()).isEqualTo("APPROVED");
    }

    @Test
    void newVersionResetsApprovalAndOldInstanceCannotHeartbeat() {
        var old = register("1");
        review(old, "APPROVED");
        var next = register("2");
        assertThat(next.status()).isEqualTo("PENDING");
        assertThatThrownBy(() -> service.heartbeat(authorization, revision(old)))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> review(old, "APPROVED")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> register("1")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> register("2.0")).isInstanceOf(ApiException.class);
        assertThat(register("2.1").status()).isEqualTo("PENDING");
    }

    @Test
    void sameVersionCannotChangeDefinition() {
        register("1");
        String changed = codec.canonical(manifest("1")).replace("查询记录", "修改描述");
        assertThatThrownBy(() -> service.register(authorization, changed.getBytes(StandardCharsets.UTF_8)))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void expiryAndClockSkewFailOffline() {
        var view = register("1");
        var later = service(Clock.fixed(TIME.plusSeconds(180), ZoneOffset.UTC));
        assertThat(later.list("10", ADMIN).getFirst().online()).isFalse();
        assertThatThrownBy(() ->
                        later.review("10", new AgentCapabilityReviewRequest(revision(view), "APPROVED"), ADMIN, null))
                .isInstanceOf(ApiException.class);
        assertThat(service(Clock.fixed(TIME.minusSeconds(1), ZoneOffset.UTC))
                        .list("10", ADMIN)
                        .getFirst()
                        .online())
                .isFalse();
        assertThat(later.heartbeat(authorization, revision(view)).online()).isTrue();
    }

    @Test
    void rotationInvalidatesOldCredentialAndApprovalWithoutRestoringRevokedCapabilities() {
        var view = register("1");
        review(view, "APPROVED");
        var nextCredential = service.rotateCredential("10", ADMIN, null);
        assertThat(nextCredential.toString()).doesNotContain(nextCredential.token());
        assertThat(savedCredential.getTokenHash()).doesNotContain(nextCredential.token());
        assertThatThrownBy(() -> service.heartbeat(authorization, revision(view)))
                .isInstanceOf(ApiException.class);
        assertThat(service.list("10", ADMIN).getFirst().status()).isEqualTo("PENDING");
        assertThat(service.list("10", ADMIN).getFirst().online()).isFalse();
        authorization = "Bearer " + nextCredential.token();
        service.heartbeat(authorization, revision(view));
        review(view, "REVOKED");
        service.rotateCredential("10", ADMIN, null);
        assertThat(service.list("10", ADMIN).getFirst().status()).isEqualTo("REVOKED");
    }

    @Test
    void credentialRevocationInvalidatesAllCapabilitiesEvenWhenProjectDisabled() {
        var view = register("1");
        when(repository.active("10")).thenReturn(false);
        service.revokeCredential("10", ADMIN, null);
        assertThat(savedCredential.getStatus()).isEqualTo("REVOKED");
        assertThat(service.list("10", ADMIN).getFirst().online()).isFalse();
        when(repository.active("10")).thenReturn(true);
        assertThatThrownBy(() -> service.heartbeat(authorization, revision(view)))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void heartbeatAndApprovalRecheckPermissionFacts() {
        var view = register("1");
        when(repository.permissions("10")).thenReturn(Set.of());
        assertThatThrownBy(() -> service.heartbeat(authorization, revision(view)))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> review(view, "APPROVED")).isInstanceOf(ApiException.class);
    }

    @Test
    void membershipOrPlatformPermissionRemovalBlocksManagement() {
        var view = register("1");
        when(repository.isAdmin("10", "1")).thenReturn(false);
        assertThatThrownBy(() -> service.rotateCredential("10", ADMIN, null)).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> review(view, "APPROVED")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> service.list("10", actor(Set.of()))).isInstanceOf(ApiException.class);
    }

    @Test
    void rejectsManifestForAnotherProjectAndUnregisteredPermission() {
        String foreign = codec.canonical(manifest("1")).replace("crm", "other");
        assertThatThrownBy(() -> service.register(authorization, foreign.getBytes(StandardCharsets.UTF_8)))
                .isInstanceOf(ApiException.class);
        when(repository.permissions("10")).thenReturn(Set.of());
        assertThatThrownBy(() -> register("1")).isInstanceOf(ApiException.class);
        verify(repository, never()).insertCapability(any());
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(
            strings = {
                "Bearer zsch_10_secret",
                "Bearer eyJ.user.jwt",
                "Basic anything",
                "Bearer kagent_11_short",
                "Bearer kagent_10_short"
            })
    void schedulerAndUserCredentialsCannotRegister(String bearer) {
        assertThatThrownBy(() -> service.register(bearer, bytes(manifest("1")))).isInstanceOf(ApiException.class);
        verifyNoInteractions(repository);
    }

    @Test
    void enforcesProjectCapabilityQuota() {
        when(repository.count("10")).thenReturn(100L);
        assertThatThrownBy(() -> register("1")).isInstanceOf(ApiException.class);
        verify(repository, never()).insertCapability(any());
    }

    @Test
    void disabledProjectCannotRegister() {
        when(repository.active("10")).thenReturn(false);
        assertThatThrownBy(() -> register("1")).isInstanceOf(ApiException.class);
    }

    @Test
    void auditContainsNoTokenOrManifestContent() {
        var view = register("1");
        review(view, "APPROVED");
        var event = org.mockito.ArgumentCaptor.forClass(AgentRegistryEventEntity.class);
        verify(repository, times(2)).event(event.capture());
        assertThat(event.getAllValues()).allSatisfy(e -> {
            assertThat(e.getProjectId()).isEqualTo("10");
            assertThat(e.getManifestHash()).hasSize(64);
        });
        verify(audit)
                .recordOperationInCallerTransaction(
                        eq(ADMIN), eq("agent"), eq("REVIEW_APPROVED"), anyString(), eq("projectId=10"), any());
    }

    private AgentRegistrationView register(String version) {
        return service.register(authorization, bytes(manifest(version)));
    }

    private AgentRegistrationView review(AgentRegistrationView view, String status) {
        return service.review("10", new AgentCapabilityReviewRequest(revision(view), status), ADMIN, null);
    }

    private AgentRegistryServiceImpl service(Clock clock) {
        return new AgentRegistryServiceImpl(repository, new CapabilityManifestValidator(), codec, clock, audit);
    }

    private byte[] bytes(CapabilityManifest manifest) {
        return codec.canonical(manifest).getBytes(StandardCharsets.UTF_8);
    }

    private static AgentCapabilityRevision revision(AgentRegistrationView view) {
        return new AgentCapabilityRevision(view.capabilityCode(), view.version(), view.manifestHash());
    }

    private static KaiwuContext actor(Set<String> permissions) {
        return new KaiwuContext(
                "1",
                "session",
                null,
                null,
                permissions,
                Set.of(),
                "v1",
                "kaiwu-system-service",
                TIME,
                TIME.plusSeconds(60),
                "jti");
    }
}
