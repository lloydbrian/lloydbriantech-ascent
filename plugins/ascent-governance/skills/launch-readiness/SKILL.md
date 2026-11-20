---
name: launch-readiness
description: >-
  Use when asked "are we ready to launch?", "can we go live?", "go or no-go
  for prod?", "is this ready for beta?", "is it safe to run this locally?",
  "what is blocking the launch?", "draft the launch record", or before the
  first deploy to an environment. Answers one question for one environment
  (local, beta, prod, or the project's own ladder) with GO, NO-GO or GO WITH
  CONDITIONS: runs the scripted checks on that environment's floor fresh
  (GOV-L1–L2), reads the dated record of every review that needs judgement
  and offers to run the ones that are due (GOV-R1–R4), lists the waivers in
  force with their review dates (GOV-W1–W4), then drafts the launch record
  with a plain-words summary for a person to sign (GOV-L3–L5). It checks that
  the evidence exists and is current, not that the system is good. Claude
  never signs.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# launch-readiness

The entry point of `ascent-governance`. It answers one question: is this project ready to go live in this environment, and what says so?

Shared sources:
- [governance-rules.md](../../references/governance-rules.md): the ladder, the floors, the review log, the launch record, GOV-S, GOV-L, GOV-W and GOV-R, and their limits
- [contract-template.yml](../../references/contract-template.yml): the `governance:` section
- [registry.md](../../references/registry.md): which plugin owns each check and review

## Rules

- **One environment, one answer.** Ask which environment when the request does not say; never answer for the whole ladder at once (that is `governance-review`).
- **The script gives the verdict.** GO, NO-GO or GO WITH CONDITIONS is what `check-audit.sh` prints. Never soften it, never upgrade it, and never give a verdict the script did not give.
- **Evidence, not goodness.** The verdict says the evidence exists and is current. Say so in every answer; a GO is not a promise that the system is good.
- **Claude never signs.** Never write anything after `Signed:` or `Date:` in a launch record, never propose a name for them, and never commit a record. Only a person signs, in their own editor.
- **Write only these, and only after approval:** the plain-words summary inside the record `check-audit.sh --record` just wrote, and rows appended to the review log (as `review-record` does). Any other path is a failure of this skill. Never edit the verdict, the evidence table, the waivers or the conditions of a record: the script wrote them.
- **A floor is a floor.** Run only what the floor names. Offer other reviews as suggestions, never as conditions.
- **Rate only with the severity table below.** A concern that matches no row goes under **Other observations (unrated)**.
- **No secrets or personal data** in the answer, the summary or the review log.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every value you pass to a script.

## Severity

<!-- gov-severity:start -->
| Finding | Severity |
|---|---|
| A governance section with a key this version does not read, a value of the wrong kind, or an environment, a check or a review age that cannot be read (GOV-S1) | High |
| A check on the floor fails (GOV-L1) | High |
| A rung with sign-off whose newest launch record is missing, unsigned, undated or NO-GO (GOV-L3) | High |
| A launch record signed by someone who is not in the contract's approvers (GOV-L4) | High |
| Something other than launch records and the review log changed since the commit the signed record names (GOV-L5) | High |
| A waiver past its review date (GOV-W1) | High |
| A review whose newest record has an open High finding that no waiver covers (GOV-R2) | High |
| A review on the floor that is due when the launch question is asked (GOV-R1 with --launch) | High |
| A review on the floor that is due, outside the launch question (GOV-R1) | Medium |
| A review whose newest record is rated weak (GOV-R2) | Medium |
| A check that could not be run: no adapter, or its checker refused the contract's values (GOV-S2) | Medium |
| A waiver with no review date, or one that is not a real date (GOV-W3) | Medium |
| A waiver that does not say what it skips, or whose id is not an accepted ADR (GOV-W4) | Medium |
| A row of the review log that cannot be read (GOV-R3) | Medium |
| A row of the review log removed or changed after it was recorded (GOV-R4) | Medium |
| A check whose plugin is not available here, whose input the contract does not give, or that had nothing it could check: unmeasured (GOV-L2) | Low |
| A waiver due for review within 14 days (GOV-W2) | Low |
<!-- gov-severity:end -->

**Verdict:** NO-GO: any High. GO WITH CONDITIONS: no High, and any Medium, Low or unmeasured item. GO: none of them.

## Steps

### Step 0 — Load the contract and the environment

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `governance.environments`, `floors`, `approvers`, `review_log`, `launch_dir`, `maturity_target`. With no `governance` section the script uses default floors for the project's maturity and for what the repository contains, and says which; propose the section once from the contract template, marking guessed values `# guess`, and go on with the defaults. Settle the environment: the one asked for, which must be on the ladder.

### Step 1 — Ask the launch question

```bash
bash "$PLUGIN_ROOT/scripts/check-audit.sh" --env '<environment>' --launch .
```

Exit 0 is GO or GO WITH CONDITIONS, exit 1 is NO-GO, exit 2 is bad input: fix the arguments, never rate it. Read every line. For a GOV-L1 failure, the line names the checker and its most severe findings; the plugin that owns it (registry.md) has the skill that explains and fixes them. A GOV-L2 line means a plugin is not installed: say which, and that its check is unmeasured, never failed.

### Step 2 — Bring the reviews up to date

For each GOV-R1 line, the review is due. Offer to run it now, naming its skill (governance-rules.md lists them) and what it costs in time. When the operator agrees, run that skill, then record it as review-record Step 2 to Step 4 do: one new row, shown first, appended after approval. A review the operator declines stays due: the answer stays NO-GO for this launch, and that is the operator's call to make.

For a GOV-R2 line, the review's open High finding blocks the launch until it is fixed and the review is run again, or until an accepted ADR waives it (`ascent-adr:adr-write`, then a waiver in the contract with `skips` naming the rule id and a `review_by` date). Never write the waiver yourself without the operator asking for it.

### Step 3 — Ask again

Run Step 1 again after any review was recorded or anything was fixed. Repeat until nothing more will change in this session. Show the final output.

### Step 4 — Draft the launch record

When the operator wants the answer on record (always for an environment whose floor has `sign_off`), the working copy must be the commit being launched: `--record` refuses otherwise, and names what differs. Then:

```bash
bash "$PLUGIN_ROOT/scripts/check-audit.sh" --env '<environment>' --record '<governance.launch_dir>/<today>-<environment>.md' .
```

`<governance.launch_dir>` is the contract's value (`docs/governance/launches/` when it has none); a doubled slash where the two parts join is the same file.

When Step 3's answer is NO-GO, do not write the record unless the operator asks for the refusal on record: there is one record per environment per day, so a NO-GO record written now is in the way of the answer after the fix, until the operator removes it.

The script writes the record, unsigned: the commit, the verdict, the evidence table, the waivers in force and the conditions. It never overwrites one. If today's record exists and is an unsigned draft the operator no longer wants, the operator removes it; never remove it yourself.

### Step 5 — Write the plain-words summary

Under `## In plain words`, below the marker line, write two or three sentences for a reader who does not read code: ready or not; what was checked, in ordinary words; what needs attention and by when. It must say what the verdict line says and name nothing that is not in the evidence table, the waivers or the conditions. Show it to the operator first; write it after approval. Change nothing else in the file.

### Step 6 — Hand the record to a person

Say exactly this, with the path: "The launch record is at `<path>`. It is unsigned. To sign it, add your name after `Signed:` and today's date after `Date:`, then commit it. I never sign." Add that `check-audit.sh --env <environment>` passes GOV-L3 to GOV-L5 only after that commit, and only until something other than governance records changes.

For a page to share outside GitHub, offer `--html '<file outside the launch folder>' --from '<the record>'`; it is generated from the record and never edited.

## Output

```
## Launch readiness — <environment>: <GO | NO-GO | GO WITH CONDITIONS>
It checks that the evidence exists and is current, not that the system is good.

| Rule | Severity | Evidence | What it blocks | Fix |
|---|---|---|---|---|
Reviews: <each review on the floor: its rating, date and age, or "due">
Waivers in force: <each: what it skips, review by, days left; or "none">
Unmeasured: <each check whose plugin is not available; or "none">
Other observations (unrated)
Launch record: <path, "unsigned: a person signs it"> | not drafted
Recommended next: <the skill that fixes each High finding, by plugin; review-record after a review; governance-review for the whole ladder>
```

Also name any plugin in `references/plugin-signals.md` whose signal this repository shows and whose skills are not available in this session, with its reason. The file is [plugin-signals.md](../../references/plugin-signals.md).
