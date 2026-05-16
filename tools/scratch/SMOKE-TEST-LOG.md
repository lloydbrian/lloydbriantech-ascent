# Smoke Test Log — Phase 2

**Date:** 2026-05-16
**Template version:** 0.3.0 (in development)
**Engine:** Podman 5.8.2 on macOS Darwin 25.4.0
**Host Node:** v26.0.0 (not used for testing — Principle 1: container is the dev environment)
**Container Node:** v22.x (node:22-alpine)

---

## Test project parameters

| Placeholder | Value |
|---|---|
| `<<PROJECT_SLUG>>` | `hello-world-app` |
| `<<PROJECT_TITLE>>` | `Hello World App` |
| `<<ENV_PREFIX>>` | `HELLO_WORLD_APP` |
| `<<CONTAINER_DEV>>` | `hello-world-app-dev` |
| `<<NETWORK_NAME>>` | `hello-world-app-net` |
| `<<VOLUME_DATA>>` | `hello-world-app-data` |
| `<<FRAMEWORK_VERSION>>` | `0.3.0` |

---

## Verification results

| # | Step | Command | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | Scaffold | `bash tools/scratch/scaffold-hello-world.sh` | hello-world-app/ created | Created with all template files | **PASS** |
| 2 | Placeholder check | `grep -r '<<' hello-world-app/` | Zero matches | Zero matches | **PASS** |
| 3 | Stack start | `make dev-up` | All 3 containers running | Backend + frontend + nginx running; nginx had transient Podman proxy race on first attempt, resolved on retry | **PASS** |
| 4 | Liveness | `curl -sf http://localhost:8080/healthz` | `200 {"status":"ok"}` | `{"status":"ok"}` | **PASS** |
| 5 | Readiness | `curl -sf http://localhost:8080/readyz` | `200 {"status":"ready"}` | `{"status":"ready"}` | **PASS** |
| 6 | Items (empty) | `curl -sf http://localhost:8080/api/items` | `200 {"data":[]}` | `{"data":[]}` | **PASS** |
| 7 | Create item | `POST /api/items {"name":"smoke test item"}` | `201` with id + name + created_at | `{"data":{"id":"f507b55e-...","name":"smoke test item","created_at":"2026-05-16T14:30:13.315Z"}}` | **PASS** |
| 8 | Items (with data) | `curl -sf http://localhost:8080/api/items` | `200` with the new item | Item present in response | **PASS** |
| 9 | Frontend HTML | `curl -sf http://localhost:8080/` | HTML with React/Vite content | React refresh + module script injection (Vite HMR active) | **PASS** |
| 10 | Dev status | `make dev-status` | All 7 rows healthy | Engine ✓, Containers (3) ✓, /healthz ✓, /readyz ✓, Frontend ✓, .env ✓, Database (SQLite-WAL 4.0K) ✓ | **PASS** |
| 11a | Vitest (container) | `podman exec ... npx vitest run` | 3 tests pass | 3 passed, 169ms | **PASS** |
| 11b | Vitest (suite compose) | `podman compose -f ... run --rm test-runner` | 3 tests pass | 3 passed, 182ms | **PASS** |
| 12 | Graceful shutdown | `make dev-down` | Clean stop <15s | Stopped in 0.4s, all containers removed | **PASS** |
| 13 | Full cleanup | `make engine-clean-project` | All resources removed | Containers, networks, volumes all removed; `podman ps -a` shows empty | **PASS** |

**Result: 14/14 steps PASS.**

---

## Bugs found and fixed during testing

| # | Bug | Found at step | Root cause | Fix applied to | Description |
|---|---|---|---|---|---|
| 1 | Backend Dockerfile missing development stage | Step 3 (build) | Only had builder + production stages. Dev compose (no target) defaulted to production which used `npm ci --production` (skipped devDeps like Vitest). | `backend/Dockerfile` | Added development stage as LAST (matching frontend's 3-stage pattern). Dev stage has `npm install` (all deps) + `CMD ["node", "--watch", "server.js"]`. |
| 2 | `npm ci` fails without lockfile | Step 3 (build) | Templates ship `package.json` without `package-lock.json`. `npm ci` requires a lockfile. | `backend/Dockerfile`, `frontend/Dockerfile` | Changed `npm ci` to `npm install` in all Dockerfile stages. `npm install` works with or without a lockfile and generates one. |
| 3 | Host npm install fails (Node 26 incompatibility) | Step 1 (scaffold) | Scaffold script ran `npm install` on host (Node 26.0.0). `better-sqlite3` 11.7.0 native bindings don't compile on Node 26 V8 API. | `scaffold-hello-world.sh` | Removed host-level `npm install` from scaffold script. Principle 1: container handles deps (Node 22 inside container compiles successfully). |
| 4 | Missing .env file | Step 3 (compose) | `docker-compose.yml` has `env_file: .env` but scaffold only creates `.env.example`. | `scaffold-hello-world.sh` | Added step: `cp .env.example .env` (what any developer does after cloning per README). |
| 5 | dev-status Database row shows "not yet created" | Step 10 | Backend data was in a named Docker volume (not host-visible). `dev-status.mk` checks host path `data/<<PROJECT_SLUG>>.sqlite`. | `docker-compose.yml` | Changed backend data volume from named volume (`<<VOLUME_DATA>>:/app/data`) to bind mount (`./data:/app/data`). Data now host-visible for dev-status inspection and sqlite3 CLI access. |

---

## Notes

- **Podman proxy race (Step 3):** On first `make dev-up`, nginx container failed to start with "proxy already running" — a known Podman rootless networking race condition when multiple containers start simultaneously. Manual `podman start hello-world-app-dev-nginx` succeeded immediately. Not a template bug; transient infrastructure issue. Second scaffold run (after re-scaffolding with fixes) started cleanly without the race.

- **Host Node version:** The developer machine has Node 26.0.0 (bleeding edge). The template targets Node >= 22.0.0 per `package.json` `engines` field. All testing ran inside containers (node:22-alpine) per Principle 1. No host-level Node execution needed for the smoke test.

- **Vitest both paths validated:** Step 11a (exec into running container) and Step 11b (suite compose test-runner) both exercise Vitest successfully. This validates that docker-compose.suite.yml (Chunk 3) works end-to-end.

---

## Phase 4 carry-forward

Bug 3's resolution (removing host `npm install` from the scaffold script) is correct for Chunk 8 — Principle 1 says the container handles deps. However, it raises a design question for Phase 4's `scaffold.py`:

**Question:** When `scaffold.py` scaffolds a new project, should it assume the developer has a container engine available immediately, or should it offer a "generate lockfiles via Docker" step for developers who want `npm ci` reproducibility from Day 1?

**Options for Phase 4 to resolve:**

1. **Container-only path.** `scaffold.py` copies templates, substitutes placeholders, tells the developer to run `make dev-up`. Deps install inside the container at build time. No host Node required. (This is what Chunk 8's script does.)
2. **Hybrid path.** `scaffold.py` optionally runs `docker run --rm -v ... node:22-alpine npm install --package-lock-only` to generate lockfiles without requiring host Node. The developer then has `package-lock.json` for `npm ci` reproducibility.
3. **Host-aware path.** `scaffold.py` detects host Node version. If compatible (22.x), runs `npm install` locally. If incompatible (26.x or missing), falls back to the container path.

The choice affects the "time-to-first-dev-up" experience. Capture this decision as part of Phase 4's design review.
