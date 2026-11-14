package com.kaiwu.module.agent.catalog;

import com.kaiwu.module.agent.config.AgentRemoteProperties;
import com.kaiwu.module.agent.entity.AgentCapabilityEntity;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityManifest;
import com.kaiwu.module.agent.protocol.CapabilityManifestValidator;
import com.kaiwu.module.agent.repository.AgentRegistryRepository;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.port.ProjectAgentAccessPort;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.stereotype.Component;

/** 动态只读目录：审核、心跳、项目、会话与当前项目权限全部满足才可见。 */
@Component
public class RemoteCapabilitySource {
    public record Approved(
            Capability capability,
            String manifestHash,
            int timeoutMs,
            ProjectAccessView access,
            ConfirmationMode confirmation) {
        public Approved(Capability capability, String manifestHash, int timeoutMs, ProjectAccessView access) {
            this(capability, manifestHash, timeoutMs, access, ConfirmationMode.NONE);
        }
    }

    private final AgentRemoteProperties properties;
    private final AgentRegistryRepository registry;
    private final AgentManifestCodec codec;
    private final CapabilityManifestValidator validator;
    private final ProjectAgentAccessPort projects;
    private final AuthRepository auth;
    private final Clock clock;

    public RemoteCapabilitySource(
            AgentRemoteProperties properties,
            AgentRegistryRepository registry,
            AgentManifestCodec codec,
            CapabilityManifestValidator validator,
            ProjectAgentAccessPort projects,
            AuthRepository auth,
            Clock clock) {
        this.properties = properties;
        this.registry = registry;
        this.codec = codec;
        this.validator = validator;
        this.projects = projects;
        this.auth = auth;
        this.clock = clock;
    }

    public List<Capability> visibleTo(KaiwuContext actor) {
        if (!properties.isEnabled()) return List.of();
        String user = user(actor.sessionId());
        if (!user.equals(actor.userId())) throw denied();
        return registry.visibleCandidates(user, LocalDateTime.now(clock).minusSeconds(180)).stream()
                .map(row -> approved(row, user))
                .flatMap(Optional::stream)
                .map(Approved::capability)
                .toList();
    }

    /** 仅向聊天规划阶段展示已审核、在线且当前用户可用的写能力。 */
    public List<Capability> visibleWritesTo(KaiwuContext actor) {
        if (!properties.isEnabled() || !properties.isWriteEnabled()) return List.of();
        String user = user(actor.sessionId());
        if (!user.equals(actor.userId())) throw denied();
        return registry.visibleCandidates(user, LocalDateTime.now(clock).minusSeconds(180)).stream()
                .map(row -> approved(row, user, true))
                .flatMap(Optional::stream)
                .map(Approved::capability)
                .toList();
    }

    public Optional<Capability> findVisibleWrite(String code, KaiwuContext actor) {
        if (!properties.isEnabled() || !properties.isWriteEnabled()) return Optional.empty();
        String user = user(actor.sessionId());
        if (!user.equals(actor.userId())) throw denied();
        return approved(registry.byCode(code), user, true).map(Approved::capability);
    }

    public Approved visibleWriteRevision(String code, KaiwuContext actor) {
        if (!properties.isEnabled() || !properties.isWriteEnabled()) throw denied();
        String user = user(actor.sessionId());
        if (!user.equals(actor.userId())) throw denied();
        return approved(registry.byCode(code), user, true).orElseThrow(RemoteCapabilitySource::denied);
    }

    public Approved visibleRevision(String code, KaiwuContext actor) {
        if (!properties.isEnabled()) throw denied();
        String user = user(actor.sessionId());
        if (!user.equals(actor.userId())) throw denied();
        return approved(registry.byCode(code), user).orElseThrow(RemoteCapabilitySource::denied);
    }

    public Optional<Capability> findVisible(String code, KaiwuContext actor) {
        if (!properties.isEnabled()) return Optional.empty();
        String user = user(actor.sessionId());
        if (!user.equals(actor.userId())) throw denied();
        return approved(registry.byCode(code), user).map(Approved::capability);
    }

    /** Gateway 内部二次授权：用户只从活动会话解析，不接受调用方提供 userId。 */
    public Approved authorize(String code, String version, String hash, String sessionId) {
        if (!properties.isEnabled()) throw denied();
        var value = approved(registry.byCode(code), user(sessionId)).orElseThrow(RemoteCapabilitySource::denied);
        if (!value.capability().version().equals(version)
                || !value.manifestHash().equals(hash)) throw denied();
        return value;
    }

    /** 写清单仅供后续预览/确认权威路径使用，绝不加入现有只读聊天目录。 */
    public Approved authorizeWrite(String code, String version, String hash, String sessionId) {
        if (!properties.isEnabled() || !properties.isWriteEnabled()) throw denied();
        var value = approved(registry.byCode(code), user(sessionId), true).orElseThrow(RemoteCapabilitySource::denied);
        if (!value.capability().version().equals(version)
                || !value.manifestHash().equals(hash)) throw denied();
        return value;
    }

    public String user(String sessionId) {
        if (sessionId == null || sessionId.isBlank() || sessionId.length() > 128) throw denied();
        var session = auth.findSession(sessionId).orElseThrow(RemoteCapabilitySource::denied);
        var user = auth.findUserById(session.userId()).orElseThrow(RemoteCapabilitySource::denied);
        if (!"ONLINE".equals(session.status())
                || !session.expiresAt().isAfter(Instant.now(clock))
                || !"ENABLED".equals(user.status())
                || user.mustChangePassword()
                || !auth.findPermissions(session.userId()).contains("system:agent:ask")) throw denied();
        return session.userId();
    }

    private Optional<Approved> approved(AgentCapabilityEntity row, String user) {
        return approved(row, user, false);
    }

    private Optional<Approved> approved(AgentCapabilityEntity row, String user, boolean write) {
        if (row == null
                || !"APPROVED".equals(row.getStatus())
                || row.getLastSeenAt() == null
                || !row.getLastSeenAt().isAfter(LocalDateTime.now(clock).minusSeconds(180))) return Optional.empty();
        var manifest = codec.decode(row.getManifestJson().getBytes(StandardCharsets.UTF_8));
        if (!row.getManifestHash().equals(AgentManifestCodec.digest(codec.canonical(manifest)))
                || !row.getCapabilityCode().equals(manifest.code())
                || !row.getVersion().equals(manifest.version())
                || (write
                        ? !Boolean.FALSE.equals(manifest.readOnly())
                                || !Boolean.TRUE.equals(manifest.idempotent())
                                || manifest.params().values().stream().anyMatch(spec -> spec.enumFrom() != null)
                                || !(manifest.confirmation() == ConfirmationMode.REQUIRED
                                        || manifest.confirmation() == ConfirmationMode.STRONG)
                        : !Boolean.TRUE.equals(manifest.readOnly())
                                || manifest.confirmation() != ConfirmationMode.NONE)) return Optional.empty();
        var access = projects.resolve(manifest.projectCode(), user);
        if (access.isEmpty()
                || !access.get().projectId().equals(row.getProjectId())
                || !access.get().permissions().contains(manifest.permission())) return Optional.empty();
        var registered = registry.permissions(row.getProjectId());
        if (!registered.contains(manifest.permission())) return Optional.empty();
        validator.validate(manifest, access.get().projectCode(), registered);
        var capability = new Capability(
                manifest.projectCode(),
                manifest.code(),
                manifest.version(),
                manifest.description(),
                manifest.permission(),
                manifest.dataScope(),
                manifest.params(),
                manifest.outboundFields(),
                manifest.redact(),
                !write,
                !write,
                Boolean.TRUE.equals(manifest.idempotent()),
                formView(manifest),
                manifest.outputView());
        return Optional.of(new Approved(
                capability, row.getManifestHash(), manifest.timeoutMs(), access.get(), manifest.confirmation()));
    }

    private static com.kaiwu.module.agent.vo.AgentInputFormView.Definition formView(CapabilityManifest manifest) {
        if (manifest.inputForm() == null) return null;
        return new com.kaiwu.module.agent.vo.AgentInputFormView.Definition(
                null,
                manifest.permission(),
                manifest.inputForm().fields().stream()
                        .map(field -> {
                            var spec = manifest.params().get(field.name());
                            return new com.kaiwu.module.agent.vo.AgentInputFormView.Field(
                                    field.name(),
                                    null,
                                    spec.required(),
                                    spec.maxLength(),
                                    field.multiline(),
                                    "text",
                                    spec.type().name(),
                                    spec.min(),
                                    spec.max(),
                                    field.label(),
                                    field.dictCode(),
                                    spec.values() == null
                                            ? null
                                            : spec.values().stream().sorted().toList());
                        })
                        .toList(),
                manifest.projectCode(),
                manifest.inputForm().title());
    }

    private static PlanRejectedException denied() {
        return new PlanRejectedException(3, "无权限操作");
    }
}
