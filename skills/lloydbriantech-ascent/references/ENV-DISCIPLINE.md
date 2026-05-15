# ENV-DISCIPLINE

> The `.env` handling contract. [PRINCIPLES.md §5](../../../docs/framework/PRINCIPLES.md#5-env-discipline) is authoritative.

## The rules

1. `.env` is **gitignored**.
2. `.env` is **dockerignored**.
3. `.env.example` is committed and contains **empty defaults only** — never `REPLACE_ME`, never `<your-key-here>`, never any placeholder that looks like a value.
4. Production images **do not contain `.env`**. Production secrets come from the environment (AWS Secrets Manager, Kubernetes secrets, the orchestrator's secret store).
5. `.env.example` is the **schema** — the list of variables a project reads. Empty values declare presence without prescribing content.

## `.gitignore` entries

Every ASCENT project's `.gitignore` includes:

```
.env
.env.local
.env.*.local
*.pem
*.key
!.env.example
```

The negation `!.env.example` ensures the example file remains tracked even when a future `.env*` pattern would otherwise sweep it.

## `.dockerignore` entries

Every ASCENT project's `.dockerignore` includes the same list — the production image must not bundle the file:

```
.env
.env.local
.env.*.local
*.pem
*.key
```

`.env.example` is not necessary in the production image; the image consumes environment variables directly from the orchestrator.

## `.env.example` content rule

Correct:

```
LAWN_CARE_APP_PORT=
LAWN_CARE_APP_DB_URL=
LAWN_CARE_APP_OPENAI_API_KEY=
LAWN_CARE_APP_LOG_LEVEL=
```

Incorrect:

```
LAWN_CARE_APP_PORT=3000
LAWN_CARE_APP_DB_URL=postgresql://user:REPLACE_ME@host/db
LAWN_CARE_APP_OPENAI_API_KEY=sk-REPLACE_ME
LAWN_CARE_APP_LOG_LEVEL=info
```

The "Incorrect" version has three problems:

- `3000` is an implicit default — but the code already has a default. Putting one in `.env.example` makes the file ambiguous (is `3000` an example or a requirement?).
- `REPLACE_ME` is a fake-but-non-empty placeholder. It looks valid enough to be deployed accidentally.
- `info` repeats the implicit-default problem — let the code own defaults.

Empty values are unambiguous. A value is set, or it isn't. The schema is the documentation.

## Production secrets

The production image's filesystem must not contain `.env`. Secrets flow in from the environment:

- **AWS ECS / Fargate:** task-definition secret references resolved from AWS Secrets Manager or SSM Parameter Store
- **Kubernetes:** `envFrom: secretRef:` pulling from a Secret resource
- **Local production runs (Podman):** environment variables passed at run time, not from a file

`make aws-ecs-deploy-prod` and similar targets read secret references from a per-environment manifest, never from a `.env.production` checked into the repo.

## Detection patterns

The `ascent-self-audit` skill checks for:

- `.env` listed in `.gitignore` ✓
- `.env` listed in `.dockerignore` ✓
- `.env.example` exists and is tracked in git ✓
- `.env.example` contains no `REPLACE_ME`-style placeholders ✓
- Production Dockerfile contains no `COPY .env` or `COPY .env.*` ✓
- Repository does not contain `.env` at any path (it's in `.gitignore`, but a stray earlier commit could still have introduced it)

Regex for placeholder detection: `(REPLACE_ME|<your-[a-z-]+>|YOUR_[A-Z_]+_HERE|<paste-.*>)`.

## Reading `.env` in development

The application reads `.env` in development through standard library mechanisms (`dotenv` for Node, `python-dotenv` for Python, etc.). The reader does not panic if `.env` is missing — it loads what's there and falls back to environment.

In containers, `.env` is mounted as a volume in development (`docker-compose.yml` includes `env_file: .env`), never copied into the image.

## Anti-patterns

- **Committed `.env`.** The single worst violation. `git rm --cached .env`, force a re-deploy, and rotate every credential the file contained.
- **`.env.example` with example values.** Encourages the "I'll just change `REPLACE_ME` to the real value" workflow that produces committed-secret incidents.
- **Multiple `.env.<env>` files in the image.** `.env.staging`, `.env.production` baked into the image means secrets travel with the image and the security boundary collapses.
- **Reading secrets from a fixed-path file in production.** The runtime should accept environment variables, not depend on a specific file path that ties deployment to filesystem layout.

## Overriding the rules

A project that genuinely needs an `.env.production` in the image (e.g., for non-secret configuration that legitimately ships with the build) writes `ADR-NNN-supersede-env-discipline` explaining what's in the file, why it's not a secret, and what audit trail confirms it.
