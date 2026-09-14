---
name: kaiwu-development
description: Initialize, understand, run, troubleshoot, modify, test, or prepare Kubernetes deployment for the four-repository Kaiwu platform. Use when an agent is asked to clone Kaiwu, start the local environment, find the correct repository for a feature or bug, implement Kaiwu code, validate changes, or work with its Compose, Flyway, Nacos, Docker, Helm, and Kubernetes setup.
---

# Kaiwu development

Treat `kaiwu-system-service` as the workspace entry point and the four sibling Git repositories as independent
projects. Keep application behavior and verification evidence consistent across tools.

## Establish context

1. Run `bash .agents/skills/kaiwu-development/scripts/kaiwu-agent.sh context` from the System repository.
2. Read `docs/OVERVIEW.md`.
3. Read [references/repository-map.md](references/repository-map.md) when choosing the owning repository.
4. Read the selected repository's `AGENTS.md` and `CLAUDE.md` before editing.
5. Inspect all four worktrees before changing branches or files. Preserve unrelated user changes.

If the skill is installed through an adapter, resolve paths relative to the `kaiwu-system-service` repository,
not the adapter directory.

## Initialize or start

For “prepare”, “clone”, or “initialize” requests:

```bash
bash .agents/skills/kaiwu-development/scripts/kaiwu-agent.sh doctor
bash .agents/skills/kaiwu-development/scripts/kaiwu-agent.sh init
```

For “run”, “start”, or “show me Kaiwu” requests:

```bash
bash .agents/skills/kaiwu-development/scripts/kaiwu-agent.sh doctor
bash .agents/skills/kaiwu-development/scripts/kaiwu-agent.sh up
```

The initializer derives the other repository URLs from the System Git remote. It must refuse to overwrite an
existing non-Git directory. The launcher creates local secrets outside all repositories, starts Compose, waits
for Gateway health, and prints the local URL and initial admin credential.

Do not require Nacos for the first local experience. Use the documented Nacos path only when the user explicitly
asks for Nacos or an environment that already depends on it.

## Develop

1. Diagnose and explain the owning boundary before editing.
2. If the current branch is protected, create a descriptive feature or fix branch. Do not rewrite, delete, or
   switch away from an existing user branch without authorization.
3. Implement the smallest coherent change in the owning repository.
4. Preserve API, permission-code, Flyway, dictionary, gateway-context, and secret-management contracts described
   by repository instructions.
5. Commit repositories independently when the user requested implementation and the established repository
   workflow permits commits.
6. Never push, open a merge request, reset data, rotate secrets, or deploy merely because tests pass. Require an
   explicit user request for those external or destructive actions.

## Verify and hand off

Read [references/verification.md](references/verification.md), then run:

```bash
bash .agents/skills/kaiwu-development/scripts/kaiwu-agent.sh verify auto
```

Use an explicit scope when there are no uncommitted changes or the task needs a narrower check. Report:

- repositories and files changed;
- tests and scans actually run;
- remaining risks or environment blockers;
- local access instructions when the platform was started;
- commit IDs and whether anything was pushed or deployed.

For Kubernetes work, also read `docs/KUBERNETES.md`. Reuse the same application images as Compose, keep runtime
secrets external, and treat Flyway migrations as forward-only.

## Safety boundary

- Never clone over an existing path.
- Never expose `.kaiwu/dev.env`, Nacos credentials, tokens, private keys, or rendered Secrets.
- Never run `reset`, delete volumes, clean databases, or uninstall a release without explicit confirmation.
- Never use `main` or another protected branch as an implementation branch.
- Never claim startup success until the health check passes.
- Never claim a validation passed when a tool was missing or a command failed.
