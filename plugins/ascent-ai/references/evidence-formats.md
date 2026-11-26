# Evidence formats

The result files `ascent-ai` and `ascent-security` read, and the exact fields each rule reads. Every format here was checked against a real file or the code that writes it, in the tool's own public repository, before any rule read it. A format that could not be checked that way is under "Not in v1".

The checkers read these files with awk, through a small JSON reader (`scripts/lib/json.awk`) that prints one `path<TAB>value` row for each value: `results.stats.successes	95`, `results.results[2].testCase.metadata.slice	attack`. A file that does not have the fields below is not that format: the checker stops with exit 2 and says so.

## Promptfoo eval

What `promptfoo eval -o <file>.json` writes: the `OutputFile` type, whose `results` is an `EvaluateSummaryV3` (`version: 3`).

| Field | Path | Read by |
|---|---|---|
| Summary version | `results.version` (3) | AI-E1 |
| When it ran | `results.timestamp` (ISO 8601) | AI-E2 |
| Passed, failed, errored rows | `results.stats.successes`, `results.stats.failures`, `results.stats.errors` | AI-E3 |
| One row's outcome | `results.results[n].success` (`true` or `false`) | AI-E3 (the attack slice) |
| One row's test metadata | `results.results[n].testCase.metadata` | AI-E3, AI-E4 |

**Pass rate** = successes / (successes + failures + errors). An error is a failure: a row that could not be graded did not pass.

Promptfoo copies `defaultTest.metadata` into every test case's `metadata` (test metadata wins), so a value set once in the config's `defaultTest` reaches every row.

Source: `promptfoo/promptfoo@4a30804e923995e3a4249a8ba60e64cb24eed23d`, MIT licence. Types: `src/types/index.ts` (`OutputFile`, `EvaluateSummaryV3`, `EvaluateStats`, `EvaluateResult`). The metadata merge: `src/evaluator/engine.ts` (`testCase.metadata = { ...defaultTest.metadata, ...testCase.metadata }`). Real files: `examples/redteam-tracing-example/redteam_tracing_results.json` (version 3 with `errors`), `examples/simple-cli/output.json`. The fixture `tests/plugins/ascent-ai/fixtures/formats/promptfoo-eval.json` keeps that structure, trimmed to four rows.

## The golden set convention

Promptfoo has no slice or dataset version of its own, so `ascent-ai` sets one convention, carried in each test case's metadata:

- `tests/evals/golden/` holds the Promptfoo test files of the golden set.
- Each test case has `metadata.slice`: `typical`, `edge`, `attack` or `regression`.
- `tests/evals/golden/VERSION` holds one line: the golden set's version.
- The Promptfoo config sets `defaultTest.metadata.golden_version` to that version, so every result row carries it.
- A prompt `prompts/<name>.<ext>` is covered when a golden test case has `metadata.prompt: <name>` (AI-P1).

AI-E3 reads each row's slice, and AI-E4 each row's `golden_version`, from `results.results[n].testCase.metadata`.

## ascent-evidence-v1

A small file a project writes for a tool with no stable output file (Ragas, DeepEval, a Langfuse export). It is self-reported: AI-E5 says so on every run, so it is never mistaken for a tool's own output.

```json
{ "format": "ascent-evidence-v1", "tool": "ragas", "tool_version": "0.3.1",
  "run_at": "2026-11-20T14:02:00Z", "dataset": { "name": "golden", "version": "7" },
  "metrics": { "faithfulness": 0.93, "context_recall": 0.88 },
  "slices": { "attack": { "passed": 40, "total": 40 } }, "passed": 271, "total": 300 }
```

| Field | Read by |
|---|---|
| `format` is `ascent-evidence-v1` | AI-E1, AI-E5 |
| `run_at` (ISO 8601) | AI-E2, AI-R1 |
| `dataset.version` | AI-E4 |
| `passed`, `total` (pass rate = passed / total) | AI-E3 |
| `slices.attack.passed`, `slices.attack.total` | AI-E3 (the attack slice) |
| `metrics.<name>` | AI-R1 (against `retrieval_targets`) |

## garak

What `garak` writes to `<prefix>.report.jsonl` and, when an attack succeeds, `<prefix>.hitlog.jsonl`: one JSON object to a line.

**Report** (`*.report.jsonl`), rows told apart by `entry_type`:

| Row | Fields | Read by |
|---|---|---|
| `init` | `start_time` (ISO 8601, no zone), `garak_version`, `run` | SEC-R1 |
| `eval` | `probe` (`<module>.<Class>`), `detector`, `passed`, `fails`, `total_evaluated` | SEC-R2 |

**Attack success rate** of a probe = `fails / total_evaluated`, per `eval` row. The probe's module (`promptinject` in `promptinject.HijackHateHumans`) is its category.

**Hitlog** (`*.hitlog.jsonl`), one row per successful attack: `probe`, `detector`, `goal`, `attempt_id`, `score`, `run_id`. SEC-R3 reads `probe`, `detector` and `goal`.

Source: `NVIDIA/garak@223712893aea7338745c297e6fbf444a75d36d76`, Apache-2.0 licence. Real report files: `tests/_assets/analyze/test.report.jsonl`, `tests/_assets/report/report_test.report.jsonl`. The hitlog has no committed sample; its fields are the ones `garak/evaluators/base.py` (`_evaluate_one_detector`) writes. The fixtures `tests/plugins/ascent-security/fixtures/redteam/garak.report.jsonl` and `garak.hitlog.jsonl` keep that structure.

## Promptfoo red team

What `promptfoo redteam run -o <file>.json` writes: the same `OutputFile` as an eval. Each row is one attack; `results.results[n].success` is `true` when the target withstood it, so an attack succeeded when it is `false`.

| Field | Path | Read by |
|---|---|---|
| When it ran | `results.timestamp` | SEC-R1 |
| The attack's category | `results.results[n].testCase.metadata.pluginId` (`indirect-prompt-injection`, `pii:direct`, `hijacking`, `harmful:hate`) | SEC-R2 |
| Whether the attack succeeded | `results.results[n].success` is `false` | SEC-R2, SEC-R3 |

Source: `promptfoo/promptfoo@4a30804e923995e3a4249a8ba60e64cb24eed23d`, `examples/redteam-tracing-example/redteam_tracing_results.json` (every row carries `testCase.metadata.pluginId`). Fixture: `tests/plugins/ascent-security/fixtures/redteam/promptfoo-redteam.json`.

## Retrieval sources

The application's `retrieval_sources` file: one row for each source the application retrieves from, who owns it, and when they look at it again (AI-R2).

```markdown
<!-- ai-sources:start -->
| Source | Owner | Review by |
|---|---|---|
| help-centre articles | support-content | 2027-01-15 |
<!-- ai-sources:end -->
```

## Review notes

The application's `review_notes` file: one row each time a person looks at the application's evidence again (AI-L2). `Regression cases` is how many cases the golden set's regression slice had at that review, and `New failures flagged` how many failures the review found. Each failure found becomes a regression case, so by the next run the slice has grown, or the review flagged none.

```markdown
<!-- ai-reviews:start -->
| Reviewed on | Regression cases | New failures flagged | Notes |
|---|---|---|---|
| 2026-08-01 | 0 | 1 | the double refund, now a regression case |
<!-- ai-reviews:end -->
```

## Not in v1

- **lighteval** results: named as next. No rule reads them in this release.
- **Langfuse, Ragas, DeepEval and PyRIT** have no stable result file of their own: a project writes `ascent-evidence-v1` for them.

## Capture policy

What the traces of model calls keep (AI-O2, `check-ai-runtime.sh --capture-policy`): a Markdown file, the contract's `capture_policy`, with three labelled lines, each a list item, a table row or a plain line that starts with its label (case does not matter, bold allowed):

```markdown
- Stored: the prompt template name, the model, token counts, latency and the tool calls, for 30 days.
- Redacted: names, emails and order numbers in ticket text, replaced before the span is written.
- Dropped: the full ticket text and the model's reply are never stored.
```

A line that says "nothing" is an answer; a missing label is a finding. Whether the code does what the policy says is read by `ai-runtime-check`, not checked by the script.

## Gateway policy

The gateway's own configuration file (the contract's `gateway_policy`, AI-C2), read as text: a LiteLLM proxy `config.yaml` or a Portkey config. The script looks for an allowed-models key (`model_list`, `allowed_models`, `models`), a budget key (`max_budget`, `soft_budget`, `budget_limit`, `monthly_budget`, `budget`), any key or value naming an alert, and a rate-limit key (`rpm`, `tpm`, `rate_limit`, `requests_per_minute`, `tokens_per_minute`). Checked against LiteLLM's documentation on 2026-11-25 (docs.litellm.ai/docs/proxy/configs, /users, /alerting): `model_list` with `litellm_params.rpm` and `tpm`; `litellm_settings.max_budget` and `budget_duration`; `general_settings.alerting` (for example `["slack"]`), which sends budget alerts among others. LiteLLM's `alerting_threshold` is a timeout in seconds for hung requests, not a spend threshold, and its budgets fail open without a database: both are read by `ai-runtime-check` Step 2, not by the script. Portkey configs are read by the same keys and have not been checked against a real file.

