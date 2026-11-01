# Runbook: ready-failing (example-service)

Answers the `ready-failing` alert: the api's readiness probe at `/-/ready` has returned a non-2xx status for five minutes, so the proxy has stopped sending it traffic. Diagnosis only reads; the one change (starting a stopped database container) has its own pre-flight and post-flight. Written 2026-11-01 for v1.0.0; not yet dry-run (OPS-X3 asks for one every 90 days).

The api publishes no port on the host (only the proxy does), so every probe runs inside the api container, as its own healthcheck does.

## Pre-flight

1. Confirm the alert is real: liveness up, readiness down.

   ```bash
   podman compose -f compose.yml exec api wget -qO- -S http://localhost:8080/-/health 2>&1 | grep -m1 'HTTP/'
   podman compose -f compose.yml exec api wget -qO- -S http://localhost:8080/-/ready 2>&1 | grep -m1 'HTTP/'
   ```

   **Expect:** `HTTP/1.1 200 OK`, then `HTTP/1.1 503 Service Unavailable`.
   **Stop if:** liveness is not 200, or the exec fails: the process itself is down; follow the Troubleshooting Manual's "`/-/health` fails, container restarting" row instead.

## Steps

1. Find the dependency readiness reports as down.

   ```bash
   podman compose -f compose.yml exec api wget -qO- http://localhost:8080/-/ready
   ```

   **Expect:** a JSON body naming the failed dependency, e.g. `{"db":"down"}`.
   **Stop if:** the body names no dependency: escalate to the on-call secondary.

2. Check the database container.

   ```bash
   podman compose -f compose.yml ps db
   ```

   **Expect:** `db` listed; its status says why it is not ready.
   **Stop if:** `db` is up and its healthcheck says healthy: the fault is between the api and the database; escalate. If it says starting or restarting, it may be recovering after a reboot (Troubleshooting Manual, Known issues: up to 90 seconds): wait, then run this step again.

3. Start the database when it has stopped.

   Pre-flight: the container exists and has exited, so `start` does not create or recreate anything.

   ```bash
   podman compose -f compose.yml ps -a db
   ```

   **Expect:** `db` with status `Exited`.
   **Stop if:** any other status, or no container: do not start or create one; escalate.

   ```bash
   podman compose -f compose.yml start db
   ```

   **Expect:** `db` started.
   **Stop if:** the start fails: follow the Troubleshooting Manual's "`/-/health` passes, `/-/ready` returns 503" row (`podman logs db`); do not delete the volume.

   Post-flight for this step:

   ```bash
   podman compose -f compose.yml ps db
   ```

   **Expect:** `db` up, healthy within two minutes.
   **Stop if:** it exits again: escalate with `podman logs db`.

## Post-flight

```bash
podman compose -f compose.yml exec api wget -qO- -S http://localhost:8080/-/ready 2>&1 | grep -m1 'HTTP/'
```

**Expect:** `HTTP/1.1 200 OK` within a minute, and the alert resolves.
**Stop if:** still 503 after five minutes: escalate.

## Rollback

Nothing to roll back: the only change starts a stopped container. If the start made things worse, stop it again with `podman compose -f compose.yml stop db` and escalate.
