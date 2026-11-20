# ascent-governance

Launch readiness for any repository. It answers one question for one environment, "are we ready to go live here?", with GO, NO-GO or GO WITH CONDITIONS, and every reason cites a file, a line or a script:
- the scripted checks of that environment's floor are run fresh, every time, at no token cost
- each review that needs judgement leaves one dated row in a review log, so anyone can tell that it happened, when, on which commit and how it came out
- every waiver in the contract is listed with the ADR that allows it and the date it is looked at again
- the answer is written down as a launch record that a person signs; Claude never signs

It checks that the evidence exists and is current, not that the system is good. The other `ascent-*` plugins judge quality; this one conducts them and keeps the record ([ADR-028](../../docs/framework/DECISIONS/ADR-028-auditability-and-the-governance-conductor.md)). You don't need an ASCENT project to use it, and a plugin that is not installed is reported as unmeasured, never as a failure.

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-governance@lloydbriantech-ascent
```

Ask "are we ready for prod?" or run `/ascent-governance:launch-readiness`. Between launches: "which reviews are due?" (`governance-review`). After a review: "record this review" (`review-record`).

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `launch-readiness` | skill, entry point | one environment: the launch question, the reviews that are due, the launch record and its plain-words summary |
| `governance-review` | skill | every environment, as CI sees it: what is due, expiring or broken, and when. Read-only |
| `review-record` | skill | one row in the review log for a review that was just run; rows are only added |
| `governance-conductor` | agent | read-only second opinion on the launch evidence, by reading; never signs |
| `check-audit.sh` | script | GOV-S1–S2, GOV-L1–L5, GOV-W1–W4 and GOV-R1–R4; `--record` writes the unsigned launch record, `--html` one page that stands alone |
| `references/` | references | the governance rules, the contract template, and generated copies of the plugin registry |

## The ladder

`governance.environments` is the project's ladder, `[local, beta, prod]` by default. Each environment has a floor and inherits the floors below it. With no `governance` section, these defaults apply, filtered by what the repository contains (no UI files, no UX items; no infrastructure code, no operations items):

| Environment | Who uses it | Checks, run fresh | Reviews, from the log | Signature |
|---|---|---|---|---|
| local | the operator or owner | `ascent-security/check-env`, the contract's own gate | none | no |
| beta | other people | dependencies, threat model, flow integrity, docs | `sec-posture` within 30 days, `ux-review` within 60 | no |
| prod | real users | acceptance, drills, test evidence, ADRs | architecture, ops and quality reviews within 90 days | yes |

A prototype needs only the local floor. A floor is a floor, never a ceiling: every other check and review stays usable.

## One result, three views

1. **The launch record**, `docs/governance/launches/<date>-<environment>.md`: the commit, the verdict, a plain-words summary, the evidence table, the waivers in force, the conditions, and the two lines a person signs. `check-audit.sh --record` writes it only when the working copy is the commit it names, and never overwrites one.
2. **The CI job summary:** the same result, added to `$GITHUB_STEP_SUMMARY` when that is set.
3. **One HTML page**, `--html <file>`, or `--html <file> --from <record>` for a signed record: no script, nothing fetched, a dark theme and a print style, so it can be sent to someone outside GitHub or printed to PDF. It is generated, never edited, and never written into the launch folder.

## In your CI

`check-audit.sh` needs bash, awk and git, and the other plugins' scripts beside it. Pin a release tag; never a branch.

```yaml
jobs:
  launch-evidence:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # GOV-L5 and GOV-R4 read the history
      - name: Get the ASCENT plugins, pinned
        run: git clone --quiet --depth 1 --branch v0.4.24 https://github.com/lloydbrian/lloydbriantech-ascent "$RUNNER_TEMP/ascent"
      - name: Launch evidence for prod
        run: bash "$RUNNER_TEMP/ascent/plugins/ascent-governance/scripts/check-audit.sh" --env prod .
```

The job fails only on what it can check itself: a failing check, an expired waiver, an open High finding of a recorded review, or a prod floor with no signed launch record for the code as it is. A review that is due is reported in the summary and the job stays green; `launch-readiness` is where it becomes a NO-GO. To hold a deploy until the launch is signed, make the deploy job `needs: launch-evidence`. Nothing is held unless the project chooses that.

## Boundaries

- **Whether the system is good** is the other plugins' judgement and a person's. This plugin proves the judgement was made, is current and was accepted.
- **Signing** is a person's. No skill, agent or script here writes after `Signed:` or `Date:`. The commit that adds the signature is the evidence of who signed.
- **The review log** is written only by `launch-readiness` and `review-record`, one row at a time, after approval. Rows are only added.
- **Commits** are the operator's: nothing here commits.
- **`delivery/gate`** runs the contract's own `delivery.gate` command with `sh -c`. The contract is the project's file; review a change to that line as you would a change to a build script.
- **Security, UX, operations, quality, decisions and docs findings** belong to their plugins. A GOV-L1 line names the checker and its findings; the fix is in that plugin's skill.

## Maturity targets

| Item | Prototype (when the contract names no target) | Standard | Enterprise |
|---|---|---|---|
| Default floors | local only | local, beta, prod | local, beta, prod |
| Scripted checks (GOV-L1, L2) | `check-env` | each floor's checks | the same |
| Reviews (GOV-R1–R4) | none | each floor's reviews, dated | the same |
| Sign-off (GOV-L3–L5) | none | prod | prod |
| Waivers (GOV-W1–W4) | checked when present | the same | the same |

A project that writes its own `floors` gets exactly those, at any maturity.

## Evidence, strongest first

1. **The script:** exact, repeatable, run fresh, each line labelled with its rule id and source.
2. **The review log and the launch records** in git: who recorded what, when, on which commit.
3. **Reading** by `governance-conductor`: what the records say, without running anything.

## Tests

`make test-plugins` runs `tests/plugins/ascent-governance/`, on every awk installed:
- `test-contract-reader.sh`: the contract's YAML subset, with line numbers
- `test-check-audit.sh`: the ladder, the floors, inheritance, defaults and the verdict, with stand-in checkers
- `test-adapters.sh`: every option each checker is given, against that checker's own usage line, and the real checkers on a fixture
- `test-waivers.sh`, `test-review-log.sh`, `test-launch-records.sh`: GOV-W, GOV-R and GOV-L3–L5, one broken copy per control, with history in scratch git repositories
- `test-views.sh`: the job summary and the HTML page: self-contained, escaped, never in the launch folder
- `test-governance-rules.sh`: the skills and the agent against the script, the severity table, the contract keys, and bash 3.2

`make test-mutants GROUP=ascent-governance` and the groups `ascent-governance-ladder`, `-adapters`, `-waivers`, `-reviews-1` to `-reviews-3`, `-launch-1` to `-launch-4`, `-views-1`, `-views-2` and `-rules` add negative controls that must each make a named check fail. The slow areas are split so that each CI job on macOS keeps inside 25 minutes.
