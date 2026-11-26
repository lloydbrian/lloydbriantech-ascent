# AI risk tier: <application>

One record for each AI application, at `<governance.ai_tier_dir>/<application>.md` (`docs/governance/ai-tier/` by default); the file name is the application's name in `ai.applications`. A person decides the tier and fills in `decided_by` and `decided_on`; Claude may draft the reasons, marked `# guess` in the Note cell, and never fills in those two. `check-audit.sh` checks the record on every environment above the lowest (GOV-A1–A5).

## The tiers

| Tier | Meaning | Typical example |
|---|---|---|
| 1 | Internal use; a person reviews every output before it has any effect; no tool that changes anything | a drafting aid for staff |
| 2 | Users outside the team see outputs, or the AI acts through reversible tools | a customer-facing assistant, a ticket triage service |
| 3 | The AI can take irreversible, financial or external actions, or informs decisions about people (employment, credit, health, legal, education, access to services: the EU AI Act's Annex III areas) | an agent that issues refunds, a screening tool |

The reasons below set a floor the tier may not go below (GOV-A5): `actions` irreversible or financial, or `decisions_about_people: yes`, means tier 3; `audience: external` or `actions: reversible` means at least tier 2. A person may choose a higher tier than the floor, never a lower one; a deliberate exception is a waiver in an accepted ADR.

## The record

Each value is one of the values in brackets; the Note cell says why, in words.

<!-- ai-tier:start -->
| Field | Value | Note |
|---|---|---|
| application | <application> | |
| tier | <1, 2 or 3> | |
| audience | <internal or external> | who sees what it produces |
| actions | <none, reversible, irreversible or financial> | what its tools can change |
| decisions_about_people | <no or yes> | |
| personal_data | <none, personal or sensitive> | what it reads |
| decided_by | | a person in governance.approvers fills this in |
| decided_on | | the date they decided, YYYY-MM-DD |
| review_by | <YYYY-MM-DD> | when a person looks at the tier again |
<!-- ai-tier:end -->

`ascent-ai` and `ascent-security` read the tier from this table to scale their severities: a tier-2 finding is one level lighter than at tier 3, a tier-1 finding two, and a few rules never change.
