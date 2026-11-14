package com.kaiwu.module.operation.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;

import com.kaiwu.common.GlobalExceptionHandler;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.operation.repository.ProjectSchedulerRepository;
import com.kaiwu.module.operation.service.ServiceCredentialManager;
import com.kaiwu.module.operation.vo.ServiceCredentialView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.*;
import io.jsonwebtoken.Jwts;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/** 真RSA Context与SDK权限拦截器下验证C5管理入口；项目成员/审计存储为明确测试桩，不冒充共享环境联调。 */
class ServiceCredentialControllerTest {
    /** 一轮HTTP夹具持有独立测试身份与可核对的领域依赖。 */
    private record Fixture(
            MockMvc mvc,
            ProjectSchedulerRepository repository,
            ProjectMembershipPort membership,
            AuditPort audit,
            KeyPair key) {}

    /** 本地固定权限事实与真实Context验证器组合，签发开关和项目成员关系可逐项控制。 */
    private Fixture fixture(boolean enabled, Set<String> permissions, boolean member) throws Exception {
        var generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        var key = generator.generateKeyPair();
        var properties = new KaiwuStarterProperties();
        properties.setAudience("kaiwu-system-service");
        properties.setContextPublicKey("-----BEGIN PUBLIC KEY-----\n"
                + Base64.getMimeEncoder(64, new byte[] {'\n'})
                        .encodeToString(key.getPublic().getEncoded()) + "\n-----END PUBLIC KEY-----");
        var repo = mock(ProjectSchedulerRepository.class);
        var membership = mock(ProjectMembershipPort.class);
        var audit = mock(AuditPort.class);
        var encoder = mock(PasswordEncoder.class);
        when(membership.activeMemberExists("1", "123")).thenReturn(member);
        when(repo.lockCredentialProject("1")).thenReturn(true);
        when(encoder.encode(anyString())).thenReturn("test-hash");
        when(repo.listScopedCredentials("1", 1, 20))
                .thenReturn(new PageResult<>(
                        1,
                        20,
                        1,
                        List.of(new ServiceCredentialView(
                                "10", "workflow", Set.of("member:read"), "ACTIVE", null, null, null))));
        var manager = new ServiceCredentialManager(repo, membership, audit, encoder, enabled, 60);
        var mvc = MockMvcBuilders.standaloneSetup(new ServiceCredentialController(manager))
                .setControllerAdvice(new GlobalExceptionHandler())
                .addInterceptors(new StarterAuthInterceptor(
                        new GatewayContextVerifier(properties),
                        (context, permission) -> permissions.contains(permission)))
                .build();
        return new Fixture(mvc, repo, membership, audit, key);
    }

    /** 只生成驻留内存的60秒测试Context；错误audience与外部JWT类型作为反向输入。 */
    private String token(KeyPair pair, String audience, String type) {
        var now = Instant.now();
        return Jwts.builder()
                .header()
                .type(type)
                .and()
                .issuer("kaiwu-gateway-service")
                .audience()
                .add(audience)
                .and()
                .subject("123")
                .id(UUID.randomUUID().toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(60)))
                .claim("sid", "c5-test-session")
                .claim("permissions", List.of())
                .signWith(pair.getPrivate(), Jwts.SIG.RS256)
                .compact();
    }

    /** 缺Context、错误audience、普通JWT或仅伪造身份头均不能进入新管理API。 */
    @Test
    void rejectsUntrustedIdentityAndMissingManagementPermission() throws Exception {
        var f = fixture(true, Set.of(), true);
        String path = "/api/projects/1/service-credentials";
        assertThat(f.mvc()
                        .perform(get(path).header("X-User-Id", "123"))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(401);
        for (String context : List.of(
                token(f.key(), "other-service", "kaiwu-context+jwt"), token(f.key(), "kaiwu-system-service", "JWT")))
            assertThat(f.mvc()
                            .perform(get(path).header("X-Kaiwu-Context", context))
                            .andReturn()
                            .getResponse()
                            .getStatus())
                    .isEqualTo(401);
        assertThat(f.mvc()
                        .perform(get(path)
                                .header("X-Kaiwu-Context", token(f.key(), "kaiwu-system-service", "kaiwu-context+jwt")))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(403);
        verifyNoInteractions(f.repository(), f.membership(), f.audit());
        assertThat(StarterContext.current()).isNull();
    }

    /** 平台列表权限不代替资源授权：非目标项目成员403；有资格时只返回无密钥元数据。 */
    @Test
    void listRequiresProjectMembershipAndNeverSerializesSecrets() throws Exception {
        var f = fixture(true, Set.of("system:service-credential:list"), true);
        String context = token(f.key(), "kaiwu-system-service", "kaiwu-context+jwt");
        var response = f.mvc()
                .perform(get("/api/projects/1/service-credentials").header("X-Kaiwu-Context", context))
                .andReturn()
                .getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(response.getContentAsString())
                .contains("workflow")
                .doesNotContain("tokenHash", "test-hash", "\"token\"");
        assertThat(f.mvc()
                        .perform(get("/api/projects/2/service-credentials").header("X-Kaiwu-Context", context))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(403);
        verify(f.repository(), never()).listScopedCredentials(eq("2"), anyLong(), anyLong());
        assertThat(f.mvc()
                        .perform(get("/api/projects/1/service-credentials?size=101")
                                .header("X-Kaiwu-Context", context))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(400);
        assertThat(StarterContext.current()).isNull();
    }

    /** 关闭开关时503且零写入；开启后操作者只取验签Context，明文仅在签发响应返回一次。 */
    @Test
    void issuanceKeepsGateClosedAndIgnoresForgedActorHeaders() throws Exception {
        String body = "{\"serviceCode\":\"workflow\",\"scopes\":[\"member:read\"],\"expiresAt\":\""
                + Instant.now().plusSeconds(3600) + "\"}";
        var off = fixture(false, Set.of("system:service-credential:manage"), true);
        assertThat(off.mvc()
                        .perform(post("/api/projects/1/service-credentials")
                                .header(
                                        "X-Kaiwu-Context",
                                        token(off.key(), "kaiwu-system-service", "kaiwu-context+jwt"))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(body))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(503);
        verifyNoInteractions(off.repository(), off.audit());
        var on = fixture(true, Set.of("system:service-credential:manage"), true);
        var response = on.mvc()
                .perform(post("/api/projects/1/service-credentials")
                        .header("X-Kaiwu-Context", token(on.key(), "kaiwu-system-service", "kaiwu-context+jwt"))
                        .header("X-User-Id", "999")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andReturn()
                .getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(response.getContentAsString()).contains("zsch_").doesNotContain("test-hash");
        verify(on.membership()).activeMemberExists("1", "123");
        verify(on.membership(), never()).activeMemberExists(anyString(), eq("999"));
        assertThat(StarterContext.current()).isNull();
    }
}
