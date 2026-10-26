---
as_of: 2026-10-25
describes: v1.0.0
sources:
  - compose.yml
  - secure-parameters.yaml
  - ops-script-template.sh
---

# Troubleshooting Manual: example-service

<!-- ascent-ops blueprint. ops-manuals adds a row whenever an incident, a runbook
step or a known issue teaches something new. Diagnostic commands are read-only:
anything that changes the system belongs in a runbook with pre-flight and
post-flight checks. -->

How the parts fit together is in the [Maintenance and Operations Manual](MAINTENANCE-AND-OPERATIONS.md#architecture-diagrams). Start with the symptom, look where the table says, and escalate when the fix column says so.

## Symptoms

| Symptom | Where to look | Likely cause | Fix or escalation |
|---|---|---|---|
| `/-/health` fails, container restarting | `podman logs api`, `podman inspect api --format '{{.State.ExitCode}}'` | crash at start: missing parameter or a bad release | roll back (runbook); if the parameter is missing, add it in IaC and redeploy |
| `/-/health` passes, `/-/ready` returns 503 | `curl -s http://localhost:8080/-/ready` (the reason field), `podman logs db` | database unreachable or migrations not applied | check the db container and its volume; escalate to the on-call operator after 15 minutes |
| 502 from the proxy | `podman logs proxy`, `podman ps` | api container down or still starting | wait for `/-/started`; if it never passes, roll back |
| Slow responses on `/api/orders` | api request logs (duration field), `podman stats` | database load or a missing index | check slow queries; escalate to the platform team lead |
| Drift check reports a difference | `ops-script-template.sh --env prod --check-drift` output | a change made by hand in the console | revert it through IaC and deploy; record it in the change history |
| Secret rotation failed | Secrets Manager rotation status for `example-service/<env>/db` | the rotation function cannot reach the database | escalate to the on-call operator; the old secret stays valid until rotation succeeds |

## Diagnostic commands

Every command here only reads.

```bash
podman ps --format '{{.Names}} {{.Status}}'
podman logs --since 15m api
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/-/ready
aws cloudformation describe-stacks --stack-name example-service-prod --query 'Stacks[0].StackStatus'
aws ssm get-parameters-by-path --path /example-service/prod/ --query 'Parameters[].Name'
```

## Known issues

| Issue | Workaround | Tracked in |
|---|---|---|
| The first start after a host reboot takes up to 90 seconds while the database recovers | wait for `/-/started` before checking `/-/ready` | the backlog, item "faster db recovery" |

## Escalation

Follow the [escalation table](MAINTENANCE-AND-OPERATIONS.md#escalation-and-contacts): the on-call operator first, then the platform team lead. Anything that may involve exposed secrets or customer data goes to security on-call at once (→ ascent-security).
