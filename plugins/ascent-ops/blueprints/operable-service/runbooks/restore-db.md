# Runbook: restore drill for db (example-service)

Restores the newest nightly `pg_dump` of the `db` volume into a scratch PostgreSQL container on the operator's host, starts the api against it, measures the time until the api answers readiness, compares row counts, and removes everything it created. It never touches the production `db` container or its volume. Recovery path `db` (`ops.drills.paths`, kind `restore`); record format in `references/drill-records.md`. Last run: 2026-11-01, against v1.0.0 ([record](../drills/2026-11-01-db.md)).

The scratch database and the dump hold a full copy of production data: the post-flight removes both, and the drill is not finished until it has.

## Inputs

```bash
read -r DUMP_FILE         # the newest dump, downloaded from the backup bucket, e.g. ./db-2026-10-20.dump
read -r DUMP_TIME         # when the dump was taken, UTC, e.g. 2026-10-20T02:00:00Z
read -r INCIDENT_TIME     # the failure the drill pretends, UTC (the RPO is INCIDENT_TIME minus DUMP_TIME)
read -rs SCRATCH_PASSWORD # a throwaway password for the scratch container; never written down
export SCRATCH_PASSWORD
```

The api reads its configuration from `/example-service/drill/` and the database secret `example-service/drill/db`, which point at `127.0.0.1:5432` with `SCRATCH_PASSWORD`. They are created once, through IaC, like every other environment.

## Pre-flight

1. The dump is readable and is a custom-format archive.

   ```bash
   podman run --rm -i docker.io/library/postgres:16.4 pg_restore --list < "$DUMP_FILE" | head -5
   ```

   **Expect:** a `; Archive created at` header and table of contents lines.
   **Stop if:** `pg_restore: error`, or the file is empty: the backup is broken, which is the drill's finding. Record `result: fail` with the output.

2. Nothing is left from an earlier drill.

   ```bash
   podman ps -a --filter name='^drill-(db|api)$' --format '{{.Names}}'
   podman volume ls --filter name='^drill-db-data$' --format '{{.Name}}'
   ```

   **Expect:** no output from either command.
   **Stop if:** anything is listed: run the Rollback first.

3. The drill configuration exists, and both images are pulled, so the clock measures the recovery and not a download.

   ```bash
   aws ssm get-parameters-by-path --path /example-service/drill/ --query 'length(Parameters)'
   podman pull docker.io/library/postgres:16.4 registry.example/example-service-api:1.0.0
   ```

   **Expect:** a number above 0, then two image ids.
   **Stop if:** `0` or an error: create the drill environment through IaC first; or a pull fails.

4. Note the start time.

   ```bash
   START=$(date +%s); date -u +%Y-%m-%dT%H:%M:%SZ
   ```

   **Expect:** the current UTC time.
   **Stop if:** never.

## Steps

1. Start the scratch database (the same image and version as `compose.yml`) on a named volume the post-flight removes, and wait at most two minutes for it to accept TCP connections. The image's first-start server listens on the socket only, so a TCP check is not fooled by it.

   ```bash
   podman run -d --name drill-db -e POSTGRES_PASSWORD -v drill-db-data:/var/lib/postgresql/data docker.io/library/postgres:16.4
   i=0; until podman exec drill-db pg_isready -h 127.0.0.1 -U postgres -q; do i=$((i + 1)); [ "$i" -lt 120 ] || { echo "not ready after 120 s"; break; }; sleep 1; done
   ```

   **Expect:** a container id, then the loop ends without a message.
   **Stop if:** the image cannot be pulled, or `not ready after 120 s`: run the Rollback.

2. Restore the dump.

   ```bash
   podman exec drill-db createdb -U postgres app
   podman exec -i drill-db pg_restore -U postgres -d app --no-owner < "$DUMP_FILE"
   ```

   **Expect:** no output and exit 0.
   **Stop if:** any `pg_restore: error`. Record `result: fail`, keep the output as evidence, open a follow-up, and run the Rollback.

3. Start the api against the scratch database and wait at most five minutes for readiness.

   ```bash
   podman run -d --name drill-api --network container:drill-db -e APP_ENV=drill -e CONFIG_PATH=/example-service/drill/ -e DB_SECRET_ID=example-service/drill/db registry.example/example-service-api:1.0.0
   i=0; until podman exec drill-api wget -qO- http://localhost:8080/-/ready >/dev/null 2>&1; do i=$((i + 1)); [ "$i" -lt 300 ] || { echo "not ready after 300 s"; break; }; sleep 1; done
   ```

   **Expect:** a container id, then the loop ends without a message.
   **Stop if:** `not ready after 300 s`: record `result: fail` with `podman logs drill-api` (redacted) as evidence, open a follow-up, and run the Rollback.

4. Measure the recovery time.

   ```bash
   echo "rto_seconds=$(( $(date +%s) - START ))"
   ```

   **Expect:** a number of seconds; the record's `measured_rto` is this, rounded up to a minute.
   **Stop if:** never.

5. Compare row counts with the source at dump time (the counts the backup job logs).

   ```bash
   for t in $(podman exec drill-db psql -U postgres -d app -Atc "select tablename from pg_tables where schemaname = 'public' order by 1"); do
     printf '%s ' "$t"; podman exec drill-db psql -U postgres -d app -Atc "select count(*) from \"$t\""
   done
   ```

   **Expect:** the same tables and counts as the backup job's log for that night.
   **Stop if:** a table is missing or its count differs: `result: fail`.

## Post-flight

1. ⚠ Destructive: remove the scratch containers, their volume and the downloaded dump. They hold production data; production itself is not touched. The command asks before it removes anything.

   ```bash
   printf 'Type drill to remove drill-api, drill-db, drill-db-data and %s: ' "$DUMP_FILE"; read -r OK
   [ "$OK" = drill ] && podman rm -f -v drill-api drill-db && podman volume rm drill-db-data && rm -f -- "$DUMP_FILE"
   podman ps -a --filter name='^drill-(db|api)$' --format '{{.Names}}'; podman volume ls --filter name='^drill-db-data$' --format '{{.Name}}'; ls -- "$DUMP_FILE" 2>&1
   ```

   **Expect:** `drill-api`, `drill-db` and `drill-db-data` printed by the removal, then no container or volume listed, and `No such file or directory` for the dump.
   **Stop if:** a container, the volume or the dump is still listed: remove it before going on, and do not write the record until nothing is left.

2. Write the record `docs/operations/drills/<today>-db.md` with `measured_rto`, `measured_rpo` (`INCIDENT_TIME` minus `DUMP_TIME`), and the redacted output of steps 2–5 as evidence (the redaction in `references/drill-records.md`).
3. Update the Backup and restore section of the Maintenance and Operations Manual with today's date.

**Expect:** `check-drills.sh` reports OPS-R3, OPS-R4, OPS-R5 and OPS-R7 as PASS.
**Stop if:** OPS-R5 reports a credential in the evidence: redact it before committing.

## Rollback

Run this when the drill stops part way. ⚠ Destructive: removes the scratch containers, their volume and the downloaded dump; production is not touched.

```bash
printf 'Type drill to remove drill-api, drill-db, drill-db-data and %s: ' "$DUMP_FILE"; read -r OK
[ "$OK" = drill ] && podman rm -f -v drill-api drill-db; [ "$OK" = drill ] && podman volume rm drill-db-data; [ "$OK" = drill ] && rm -f -- "$DUMP_FILE"
podman ps -a --filter name='^drill-(db|api)$' --format '{{.Names}}'; podman volume ls --filter name='^drill-db-data$' --format '{{.Name}}'
```

**Expect:** after the prompt, no container and no volume listed (a "no such container" message for one that never started is fine).
**Stop if:** a `drill-` container or `drill-db-data` is still listed: remove it by name and check again.
