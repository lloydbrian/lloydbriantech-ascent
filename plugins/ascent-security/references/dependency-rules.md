# Dependency rules: SEC-D1–D10

The rules behind [dependency-check](../skills/dependency-check/SKILL.md). `check-dependencies.sh` applies SEC-D1–D6 and SEC-D10 by reading files; `run-vuln-scan.sh` applies SEC-D7–D9 through a scanner. Severities come from the skill's `dep-severity` table, never from this page.

| Rule | What it checks | npm | Python | Go | Cargo |
|---|---|---|---|---|---|
| SEC-D1 | A manifest with dependencies has a lockfile that covers it and git tracks it | yes | yes | yes | yes |
| SEC-D2 | Versions are exact under `ops.version_pinning: exact`, bounded under `minor` | yes | yes | — | — |
| SEC-D3 | The lockfile is in step with the manifest | yes | yes | — | — |
| SEC-D4 | The runtime version is declared | yes | yes | — | — |
| SEC-D5 | Every dependency comes from the public registry or a declared one | yes | yes | yes | yes |
| SEC-D6 | No dependency is licensed only under a denied licence | npm v2/v3 lockfiles | NOTE | NOTE | NOTE |
| SEC-D7 | No advisory at or above the threshold in a dependency | scanner | scanner | scanner | scanner |
| SEC-D8 | The scan is measured, and its database is recent | — | — | — | — |
| SEC-D9 | No advisory at or above the threshold in a local image | scanner | — | — | — |
| SEC-D10 | Every scanner ignore entry has a waiver ADR, and none has expired | — | — | — | — |

Go and Cargo modules pin by checksum (`go.sum`) or lockfile, and their ranges carry no install-time risk that SEC-D2 adds to, so they get SEC-D1 and SEC-D5 only.

## What each file means

**Manifests.** `package.json` (`dependencies`, `devDependencies`, `optionalDependencies`); `pyproject.toml` (`[project] dependencies`, `[project.optional-dependencies]`, `[dependency-groups]`, `[tool.poetry.*dependencies]`); `Pipfile`; `requirements*.in`; a `requirements*.txt` or `constraints*.txt` that is not fully pinned; `setup.cfg` and `setup.py` `install_requires`; `go.mod` `require`; `Cargo.toml` `[*dependencies]`.

**Lockfiles.** `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock` (v1 and Berry), `pnpm-lock.yaml` (v5–v9); `poetry.lock`, `uv.lock`, `pdm.lock`, `Pipfile.lock`, and a `requirements*.txt` whose every requirement is `==` or `===` pinned (pip-compile output); `go.sum`; `Cargo.lock`.

**Coverage (SEC-D1, SEC-D3).** A manifest is covered by the lockfiles in its own directory or the nearest directory above that has one (a workspace member uses the root lockfile). An npm v2/v3 lockfile covers a nested manifest only when it has a `packages` entry for its path; a v1 lockfile covers only its own directory. A `go.mod` needs a `go.sum` in its own directory. A lockfile git does not track counts as missing: no one else installs from it.

**In step (SEC-D3).** npm v2/v3: every manifest dependency is recorded with the same range, and nothing extra is recorded for that package. yarn: each `name@range` has an entry. pnpm: each importer specifier matches (v5 importers, v6 single-project lockfiles and v9). Python: every manifest name (PEP 503 normalised) is in a lockfile of the covering directory.

**Pinning (SEC-D2).** Exact means `1.2.3` (npm) or `==1.2.3` (PEP 440); Poetry and Pipfile strings `1.2.3` and `==1.2.3` count. Unbounded means `*`, `x`, `latest`, an empty specifier, or a lower bound with no upper bound (`>=1.2`). Local paths, workspaces and git or URL dependencies are not rated here: SEC-D5 covers the remote ones.

**Engines (SEC-D4).** npm: `engines.node` or `volta.node` in the manifest or one above it, `.nvmrc` or `.node-version` in its directory or above. Python: `requires-python`, Poetry `python`, Pipfile `[requires] python_version`, `python_requires`, `.python-version` or `runtime.txt`, in its directory or above.

**Sources (SEC-D5).** Flagged: an `.npmrc` `registry=`, a lockfile `resolved` URL, a pip `--index-url`/`--extra-index-url`/`--find-links`, a uv or Poetry index, or a Pipfile `[[source]]` that is not a public default or a declared registry; `--trusted-host`; git, GitHub shorthand and URL tarball dependencies; a PEP 508 direct URL or a remote `-e`/`--editable` requirement (`-e file:.`, the project itself, is fine); a Go `replace` to another module (a local `./` path, or the same module at another version, is fine); a Cargo `git` or non-crates.io `registry`, a `[patch]` git source, or a `Cargo.lock` source other than crates.io. A declared registry matches at a boundary, in any case: `https://npm.corp.example` allows `https://npm.corp.example/x`, never `https://npm.corp.example.attacker.io/`. Plain `http://` is High. Credentials in a URL are masked (everything before the last `@` of the host part: `https://***@host/`), path segments that look like tokens are masked, query strings are dropped, and no `.npmrc` line other than `registry=` is read into the output.

**Licences (SEC-D6).** Read from the `license` field of npm v2/v3 lockfile packages. `(MIT OR GPL-3.0-only)` passes a `GPL-3.0-only` deny list; `(MIT AND GPL-3.0-only)` fails it. AND binds tighter than OR, parentheses group and `WITH` binds an exception to its licence, so `GPL-3.0-only AND (MIT OR BSD-3-Clause)` fails. The project's own licence (`packages[""]`) is not checked. Other lockfiles carry no licences, which is a NOTE when a deny list is set. Ten findings per lockfile, the rest counted.

**Ignore files (SEC-D10).** `.trivyignore` (`exp:YYYY-MM-DD`), `.trivyignore.yaml` (`expired_at`), `osv-scanner.toml` (`[[IgnoredVulns]]`, `ignoreUntil`), `.nsprc` (top-level advisory keys), `audit-ci.json`/`audit-ci.jsonc` (`allowlist`). An entry whose id is in a waiver's `advisories` is INFO; otherwise Low, with the expiry named when it has passed; a NOTE at prototype.

## Scanning (SEC-D7–D9)

`run-vuln-scan.sh` is offline by default. trivy runs with `--skip-db-update --skip-java-db-update --offline-scan --skip-version-check --scanners vuln`, and images come from `--input <archive>` or `--image-src docker,containerd,podman` (never a registry). trivy runs from a scratch directory with an empty `--config` and `--ignorefile`, so a `trivy.yaml` or `.trivyignore` committed to the repository cannot change or hide what it reports; SEC-D10 rates those ignore entries. These invocations were proven with the network denied (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on macOS); see ADR-016.

osv-scanner, `npm audit` and `pip-audit` send package names and versions to a third party, so they run only with `--allow-network`, which the skill passes only after the operator agrees. `npm audit` runs with `--package-lock-only` and installs nothing; `pip-audit` runs with `--no-deps --disable-pip` on fully pinned requirements files only.

Never run, and never recommend, `npm install --package-lock-only` to make a lockfile for scanning: it resolves new versions and rewrites the lockfile it should be checking. The database is refreshed by the operator (`trivy image --download-db-only`), never by the skill.

**Rating.** The same advisory from several scanners (the same package and version at the same place, with an id or alias in common) is one finding. Critical or High with a fixed release is High, with no fix yet is Medium; no scanner severity (pip-audit, trivy UNKNOWN, some osv-scanner entries) is Medium at any threshold; Medium or Low at or above the threshold is Low. Advisories below the threshold are NOTE counts. A waived id or alias is INFO. Twenty-five findings per lockfile or image, the rest counted. An image whose OS is past end of support is a NOTE.

**Database (SEC-D8).** trivy's `VulnerabilityDB.UpdatedAt` older than `scan_max_age_days` is Low: advisories found are still rated, but the ones published since are not seen. No scanner and no `--allow-network` is unmeasured, also Low. So is each scanner that fails or writes something that is not a complete report of its format (cut short, an error object such as `npm audit`'s `ENOLOCK`, or npm 6 output): that part of the scan is unmeasured, never clean. All are NOTEs at prototype. A scanner that is not installed, or a requirements file pip-audit skips because it is not fully pinned, is a NOTE.
