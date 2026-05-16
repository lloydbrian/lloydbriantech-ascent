# ADR-001: Container-first development

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>> needs a development environment that works identically across developer machines, CI, and production staging. The single largest source of friction in software delivery is "works on my machine" — subtle differences in host-installed runtimes, library versions, system dependencies, and configuration produce bugs that exist on one machine but not another.

The traditional approach — installing the runtime (Node.js), the database, and system dependencies directly on the developer's host — creates three problems:

1. **Version drift.** Developer A has Node 20, Developer B has Node 22, CI has Node 21. Each discovers the bug at a different time.
2. **Implicit dependencies.** The project works because the developer happened to have `libsqlite3-dev` installed from another project. A new developer clones and fails.
3. **Environmental leakage.** A global npm package, a stale `.env` from another project, or a lingering process on port 3001 breaks the build for reasons unrelated to the project's code.

## Decision

The development environment for <<PROJECT_TITLE>> is the container. There is no host-language path.

A developer with the container engine installed (Podman or Docker) and nothing else can clone the repository and run `make dev-up` to a working stack. The host machine's role is to run the container engine — nothing more.

This means:

- Application code runs inside containers, not on the host
- Dependencies (Node.js, SQLite, npm packages) live inside the container image
- Environment variables flow from `.env` into containers via `docker-compose.yml`
- The host filesystem is bind-mounted for hot reload, but the runtime is the container's

## Alternatives considered

**Bare-metal host installation.** Install Node.js, SQLite, and npm packages directly on the developer's machine. Rejected because version drift and implicit dependencies produce the class of bugs containerization eliminates by construction. Every "it works on my machine" incident is a cost the team pays.

**System package manager (Homebrew, apt).** Manage runtime versions via the OS package manager. Rejected because package managers don't isolate projects from each other — two projects needing different Node versions compete for the system path. Also: CI environments rarely match the developer's package-manager state.

**Version managers (nvm, fnm, asdf).** Use a per-project `.nvmrc` or `.tool-versions` to pin runtime versions. Rejected because version managers solve only the runtime version problem, not the system-dependency or environmental-leakage problems. They're a partial solution that leaves the harder issues unsolved.

**Virtual environments (Python venv, Node `--prefix`).** Isolate project dependencies in a directory tree without containers. Rejected because virtual environments don't isolate system libraries, port bindings, or database processes. They solve dependency isolation for interpreted languages but not for the full stack.

## Consequences

**Easier:**

- A new developer clones and runs `make dev-up` — working in under two minutes
- CI uses the same container images as dev — no environmental divergence
- Port conflicts are impossible — containers bind internal ports, host mapping is explicit
- Cleanup is one command (`make engine-clean-project`) — no residual state on the host
- Production parity — the production image is a subset of the dev image, not a different environment

**Harder:**

- Developers must install and run a container engine (Podman or Docker)
- Container build times add latency to the first `make dev-up` (mitigated by layer caching)
- Debugging requires container-aware tooling (`make dev-shell`, container logs, attach debugger to container process)
- Disk usage is higher — container images and volumes consume space the host-native approach avoids
- Native binary compilation (e.g., `better-sqlite3`) happens inside the container's Alpine environment, not the host's macOS/Linux — occasional build-tool friction

**Neutral:**

- Hot reload works identically via bind mounts — no developer experience regression from containerization
- IDE integrations (VS Code Dev Containers, JetBrains remote) support containerized development natively

## Cost implications

**Time:** One-time cost for developers to install the container engine (~10 minutes). Ongoing time savings from eliminated "works on my machine" incidents. First `make dev-up` takes 2-5 minutes (image build); subsequent starts are under 10 seconds (cached).

**Complexity:** Slightly higher operational complexity (container commands, volume management, network inspection) offset by the elimination of environmental debugging.

**Future flexibility:** The container-first decision enables future deployment to any orchestrator (ECS, Kubernetes, local Podman) without application changes. The application doesn't know or care where it runs.

**Money:** No incremental cost. Podman is free; Docker Desktop is free for individual use.
