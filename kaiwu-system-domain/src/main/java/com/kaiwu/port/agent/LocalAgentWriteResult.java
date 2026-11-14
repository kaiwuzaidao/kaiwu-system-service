package com.kaiwu.port.agent;

/** One-time secret is returned only in the initial response, never persisted in the action ledger. */
public record LocalAgentWriteResult(String id, String oneTimeSecret) {}
