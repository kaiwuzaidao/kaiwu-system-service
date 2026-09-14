# Kaiwu repository map

| Repository | Owns | Does not own |
| --- | --- | --- |
| `kaiwu-system-service` | Users, projects, permissions, configuration, dictionaries, audit, project factory, Flyway, Compose, Helm | External request authentication |
| `kaiwu-gateway-service` | External JWT validation, online session checks, trusted context signing, explicit routes | Permission facts or platform business rules |
| `kaiwu-system-web` | Management UI and permission-aware interactions | Authorization enforcement |
| `kaiwu-system-starter` | Context verification and local permission annotations for Java services | System business APIs |

Request path:

```text
Browser -> System Web -> Gateway -> System Service -> MySQL/Redis
```

Route work by the boundary that owns the behavior. Cross-repository changes are acceptable only when the
contract genuinely changes. Commit each repository independently.

Read the current repository's `AGENTS.md` and `CLAUDE.md` before editing. For system-wide decisions, read
`kaiwu-system-service/docs/ARCHITECTURE.md` and the relevant ADR.
