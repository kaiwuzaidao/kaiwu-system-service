package com.kaiwu.module.scheduler;

import com.kaiwu.module.credential.ProjectServiceCredential;
import com.kaiwu.module.credential.ProjectServiceCredentials;
import com.kaiwu.port.ProjectCredentialAuthenticationPort;
import org.springframework.stereotype.Component;

/** 调度服务到共享项目凭据认证器的适配器。 */
@Component
public class SchedulerCredentialAdapter implements ProjectCredentialAuthenticationPort {

    private final ProjectServiceCredentials credentials;

    public SchedulerCredentialAdapter(ProjectServiceCredentials credentials) {
        this.credentials = credentials;
    }

    @Override
    public AuthenticatedProject authenticate(String token) {
        ProjectServiceCredential credential = credentials.authenticate(token);
        return new AuthenticatedProject(credential.id(), credential.projectId());
    }
}
