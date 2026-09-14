# Kaiwu verification matrix

| Changed area | Minimum verification |
| --- | --- |
| Starter Java | `kaiwu-agent.sh verify starter` |
| System Java, SQL or configuration | `kaiwu-agent.sh verify system` |
| Gateway Java or routes | `kaiwu-agent.sh verify gateway` |
| Web TypeScript, dependencies or Nginx | `kaiwu-agent.sh verify web` |
| Compose | `docker compose config --quiet` with required non-secret test values |
| Helm | `helm lint`, `helm template`, then Kubernetes schema validation |
| Shell | `bash -n` and ShellCheck |
| Multiple dirty repositories | `kaiwu-agent.sh verify auto` |

Java source builds require JDK 21. A local JDK mismatch is an environment failure, not a passing test.
Docker quick start does not require a host JDK or Node installation.

Always report commands actually executed and their results. Never describe documentation review, rendering,
or a partial test as a full integration pass.
