# ascent-ai rules

Every rule `ascent-ai` checks, the script that checks it, and its base severity. A finding names its application: `FAIL  AI-A3  Critical  [support-assistant] src/tools/refund.py:12  …`.

**Severity follows the AI risk tier** (ascent-governance's record, `docs/governance/ai-tier/<application>.md`). The base severity below is for tier 3. At tier 2 a finding is one level lighter, at tier 1 two levels, never below Low. A rule marked **fixed** has the same severity at every tier. With no tier record a checker uses tier 3, and ascent-governance reports the missing record (GOV-A1). A check that cannot apply prints `n/a` and its rule id, never a pass.

**No overlap.** Each concern has one owner. AI safety by design and red-team results are `ascent-security`'s (SEC-R, SEC-T5); provider keys and pinned packages are `ascent-security`'s too; the fine-tune runbook's structure is `ascent-ops`'s `runbook-check`; rollout and rollback are `ascent-ops`'s; ordinary tests are `ascent-quality`'s; hosting cost is `ascent-architecture`'s; the tier is `ascent-governance`'s. `ascent-ai` checks what is left: the AI application's own declarations, evidence and safeguards.

<!-- ai-rules:start -->
| Id | Pass when | Base | Script |
|---|---|---|---|
| AI-V1 | a baseline (metric, value, measured date) and a target are declared | High | `check-ai-design.sh` |
| AI-V2 | before a `prod` launch, the pilot result exists and names the baseline metric | Medium | `check-ai-design.sh` |
| AI-M1 | model names appear only in the files the design record's `defined in` names | Medium | `check-ai-design.sh` |
| AI-M2 | a fallback model is declared and named in a `defined in` file | Medium | `check-ai-design.sh` |
| AI-M3 | at tier 3, the model selection record exists | Medium | `check-ai-design.sh` |
| AI-A1 | the autonomy is declared and matches the code: no tool definitions under `prompt`, no model-driven loop under `workflow` | High | `check-ai-design.sh` |
| AI-A2 | every declared tool is defined in code, and every tool defined in code is declared | High | `check-ai-design.sh` |
| AI-A3 | every irreversible tool needs a person's approval and names a `limit enforced in` file that exists and names the tool | Critical, fixed | `check-ai-design.sh` |
| AI-A4 | a `workflow` or `agent` declares its most steps, tokens and seconds, and every model call sets an output token limit | High | `check-ai-design.sh` |
| AI-A5 | no declared tool is irreversible while the tier record says tier 1 or 2 | High, fixed | `check-ai-design.sh` |
| AI-P1 | every prompt file under the prompts folder has a golden test case that names it (`metadata.prompt`); a prompt written inline in code is found by reading (`ai-design-check`) | Medium | `check-ai-design.sh` |
| AI-K1 | the off switch is declared, and its flag is read in the file named | High | `check-ai-design.sh` |
| AI-F1 | with a fine-tune runbook, it has a spend cap, a personal-data check of the dataset, and an eval against the golden set after training | High | `check-ai-design.sh` |
| AI-G1 | the golden set has the four slices (typical, edge, attack, regression), each with a case, and a version | High | `check-ai-evidence.sh` |
| AI-E1 | the eval result file exists, in a known format | High | `check-ai-evidence.sh` |
| AI-E2 | it is no older than the most days allowed, and newer than the last change to a prompt or the golden set (git: a change committed after the results and written after the run) | High | `check-ai-evidence.sh` |
| AI-E3 | it meets the pass-rate target (errors count as failures), and the attack slice meets its own target | High; the attack slice Critical, fixed | `check-ai-evidence.sh` |
| AI-E4 | its golden-set version is the golden set's version | Medium | `check-ai-evidence.sh` |
| AI-E5 | a self-reported result file (`ascent-evidence-v1`) is reported as self-reported, never as a tool's output | Low, fixed | `check-ai-evidence.sh` |
| AI-R1 | the retrieval results exist, are fresh and meet every retrieval target | High | `check-ai-evidence.sh` |
| AI-R2 | every retrieval source has an owner and a review date that is not past | Medium | `check-ai-evidence.sh` |
| AI-L1 | the application's `review_by` is not past | Medium | `check-ai-evidence.sh` |
| AI-L2 | since the last review in the review notes, the regression slice grew, or that review flagged no new failures | Low | `check-ai-evidence.sh` |
| AI-O1 | tracing for model calls is in the dependencies (OpenTelemetry GenAI instrumentation, OpenInference, Langfuse, Phoenix, Traceloop) | High | `check-ai-runtime.sh` |
| AI-O2 | the capture policy exists and says what prompt and output content is stored, redacted or dropped | High | `check-ai-runtime.sh` |
| AI-C1 | model calls go through the declared gateway, or the design record says `gateway: none` (a finding at tier 3) | Medium | `check-ai-runtime.sh` |
| AI-C2 | the gateway policy names the allowed models, a budget, an alert threshold and rate limits | High | `check-ai-runtime.sh` |
| AI-C3 | a cost-per-task alert is declared | Medium | `check-ai-runtime.sh` |
<!-- ai-rules:end -->

## Exit codes

Every checker: 0 when no finding is at or above `--threshold` (default High), 1 when one is, 2 for bad input, with `<script>: <option>: <reason>` as its first line (ADR-030). `ascent-governance` runs each checker once for each application.
