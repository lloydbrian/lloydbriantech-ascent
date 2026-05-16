# tools/scratch/

Temporary working directory for scaffold testing and development experiments.

**Everything in this directory is gitignored** (per the root `.gitignore` entry `tools/scratch/`). Nothing here ships or persists — it's throwaway evidence of test runs.

## Contents

- `scaffold-hello-world.sh` — one-shot script that scaffolds a test project from the template assets (Chunks 1-7) for smoke testing. NOT production scaffolding (Phase 4's `scaffold.py` handles that).
- `SMOKE-TEST-LOG.md` — verification results from the Phase 2 smoke test (the truth-test that validates all template assets compose into a working project).
- `hello-world-app/` — the scaffolded test project (created by the script above; gitignored; not committed).

## Usage

```bash
# From the repo root:
bash tools/scratch/scaffold-hello-world.sh
cd tools/scratch/hello-world-app
make dev-up
```
