package com.kaiwu.port.agent;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.util.Map;

/** Explicitly reviewed local write adapter. The Agent core never calls an arbitrary Controller or URL. */
public interface LocalAgentWriteHandler {
    String capabilityCode();

    /** Normalize and validate the exact fields frozen in the action record. Never include secrets. */
    Map<String, Object> normalize(Map<String, Object> parameters);

    /** User-visible safe values for the confirmation card; no business mutation. */
    Map<String, String> preview(Map<String, Object> parameters, KaiwuContext actor);

    /** Destructive actions require a phrase typed by the user in addition to the one-time token. */
    default ConfirmationMode confirmationMode(Map<String, Object> parameters) {
        return ConfirmationMode.REQUIRED;
    }

    default String confirmationPhrase(Map<String, Object> parameters, Map<String, String> previewFields) {
        return null;
    }

    /** Reuse the domain Service, whose state and resource checks remain authoritative. */
    default String execute(Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        throw new UnsupportedOperationException("Write handler must implement execute or executeForAction");
    }

    /** One-time secrets are returned only with the first confirm response, never written to the action store. */
    default LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters, KaiwuContext actor, RequestMetadata metadata) {
        return new LocalAgentWriteResult(execute(parameters, actor, metadata), null);
    }

    /** Pass the server-frozen preview to handlers that need a business-version precondition. */
    default LocalAgentWriteResult executeForAction(
            Map<String, Object> parameters,
            Map<String, String> previewFields,
            KaiwuContext actor,
            RequestMetadata metadata) {
        return executeForAction(parameters, actor, metadata);
    }
}
