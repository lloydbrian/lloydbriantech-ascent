#!/usr/bin/env bash
# Rule test for the ascent-ops skills and agent (ADR-013). The lessons of the
# ascent-architecture and ascent-ux trials are pinned from day one, plus the
# ops-specific rules:
#   R1  every $PLUGIN_ROOT/<path> a skill or the agent names exists
#   R2  the maturity_target values quoted in ops-review and the agent are exactly those
#       in references/contract-template.yml
#   R3  ops-review and the agent route off-table concerns to "Other observations (unrated)"
#   R4  a missing target is "unmeasured, never met", or at risk when the evidence shows a gap
#   R5  fresh evidence and repository-relative file:line evidence
#   R6  endpoint defaults are /-/health, /-/ready and /-/started everywhere; a z-suffixed
#       name appears only as a contract override, and the scaffold template serves none;
#       a non-default path is fixed by renaming it, and the contract proposal never
#       carries one
#   R7  ops-manuals writes only the two manuals, modifies rather than overwrites, shows
#       the diff and never commits
#   R8  every other skill is read-only, and runbook-check never runs the scripts
#   R9  values are never printed; contacts are roles and channels
#   R10 security items are referred, and Recommended next names ascent-security
#   R11 every "<skill> Step N" a skill cites names a skill and a heading that exist
#   R12 the agent's inline ops: key list equals the keys of the contract template
#   R13 every check id a script prints (S, Z, M) is in the severity table at the
#       severity the script gives it, in its header and in every fail() call
#   R14 the blueprint passes check-iac-config.sh and check-ops-scripts.sh
#   R15 N/A is never a pass, and NOTE lines are unrated
#   R16 every script parses and runs under the system /bin/bash (3.2 on macOS) with
#       the same result as the bash on PATH
#   R17 a missing rollback is High only for a production deploy that exists; while
#       the deploy files are empty or stubs it is the Low maturity gap
#   R18 trivy runs unasked only with the flags that keep it offline
#
# Prints "test-ops-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-ops"
REVIEW="$PLUGIN/skills/ops-review/SKILL.md"
IAC="$PLUGIN/skills/iac-config-check/SKILL.md"
RUNB="$PLUGIN/skills/runbook-check/SKILL.md"
MAN="$PLUGIN/skills/ops-manuals/SKILL.md"
AGENT="$PLUGIN/agents/ops-reviewer.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
SRE="$PLUGIN/references/sre-baseline.md"
OBS="$ROOT/skills/lloydbriantech-ascent/references/observability-contract.md"
BP="$PLUGIN/blueprints/operable-service"
for f in "$REVIEW" "$IAC" "$RUNB" "$MAN" "$AGENT" "$TEMPLATE" "$SRE" "$OBS"; do
  [ -f "$f" ] || { echo "test-ops-rules: missing $f"; echo "test-ops-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$ROOT"/} does not contain: $3"; fi; }
list_of() { printf '%s\n' "$1" | awk -F' [|] ' '{ s = $1; for (i = 2; i < NF; i++) s = s ", " $i; if (NF > 1) s = s " or " $NF; print s }'; }

# R1 — named plugin paths exist
NPATHS=0
for f in "$PLUGIN"/skills/*/SKILL.md "$AGENT"; do
  for p in $(grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9._/-]+' "$f" | sed 's|^\$PLUGIN_ROOT/||' | LC_ALL=C sort -u); do
    NPATHS=$((NPATHS + 1))
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$PLUGIN"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done
[ "$NPATHS" -gt 0 ] || bad "R1 no \$PLUGIN_ROOT paths found at all"

# R2 — maturity values match the template
MAT=$(sed -n 's/^[[:space:]]*# \(enterprise\) (default) | \([a-z |]*\)\..*/\1 | \2/p' "$TEMPLATE" | head -1)
if [ -z "$MAT" ]; then bad "R2 cannot read maturity_target values from the contract template"
else
  has R2 "$REVIEW" "\`maturity_target\` is one of $(list_of "$MAT")"
  has R2 "$AGENT" "\`maturity_target\` is one of $(list_of "$MAT")"
fi

# R3 — off-table concerns are unrated
has R3 "$REVIEW" '**Other observations (unrated)**'
has R3 "$REVIEW" 'Other observations (unrated):'
has R3 "$AGENT" '**Other observations (unrated)**'

# R4 — no target, no "met"
has R4 "$REVIEW" 'unmeasured, never met; it is at risk instead when the evidence shows a gap'
has R4 "$AGENT" 'unmeasured, never met; it is at risk instead when the evidence shows a gap'

# R5 — fresh, exact evidence
has R5 "$REVIEW" '**Fresh evidence.**'
has R5 "$REVIEW" 'repository-relative `path/to/file:line` (never a bare file name or a directory)'
has R5 "$AGENT" 'repository-relative `path/to/file:line` (never a bare file name or a directory)'

# R6 — endpoint defaults, everywhere
for f in "$REVIEW" "$AGENT" "$SRE"; do has R6 "$f" '`/-/health`'; has R6 "$f" '`/-/ready`'; has R6 "$f" '`/-/started`'; done
has R6 "$TEMPLATE" 'health_path: /-/health'
has R6 "$TEMPLATE" 'ready_path: /-/ready'
has R6 "$OBS" '`GET /-/health`'
has R6 "$OBS" '`GET /-/ready`'
has R6 "$OBS" '`GET /-/started`'
has R6 "$REVIEW" 'Never recommend a `z`-suffixed name.'
has R6 "$AGENT" 'Never recommend a `z`-suffixed name.'
# Judge the text after "file:line:", so a path containing "contract" excuses nothing.
ZLINES=$(grep -rnE '/(healthz|readyz)' "$PLUGIN" "$OBS" 2>/dev/null | sed -E 's/^[^:]+:[0-9]+://' | grep -vE 'in the contract|are not used' || true)
if [ -z "$ZLINES" ]; then ok; else bad "R6 a z-suffixed endpoint appears outside a contract-override sentence: $(printf '%s' "$ZLINES" | head -2 | sed "s|$ROOT/||g")"; fi
TPLZ=$(grep -rlE '/(healthz|readyz)' "$ROOT/skills/lloydbriantech-ascent/assets/template" 2>/dev/null || true)
if [ -z "$TPLZ" ]; then ok; else bad "R6 the scaffold template still uses z-suffixed endpoints: $(printf '%s' "$TPLZ" | sed "s|$ROOT/||g" | head -3 | tr '\n' ' ')"; fi
has R6 "$ROOT/skills/lloydbriantech-ascent/assets/template/backend/routes/health.js" "healthRoutes.get('/-/health'"
has R6 "$ROOT/skills/lloydbriantech-ascent/assets/template/backend/routes/health.js" "healthRoutes.get('/-/ready'"

# R7 — ops-manuals writes two files, surgically, and never commits
has R7 "$MAN" '**Two files only.** Write only `ops.manuals.maintenance` and `ops.manuals.troubleshooting`'
has R7 "$MAN" '**Modify, never overwrite.**'
has R7 "$MAN" '**Show the diff, never commit.**'
has R7 "$MAN" 'never run `git add`, `git commit` or any other git write'
has R7 "$TEMPLATE" 'maintenance: docs/operations/MAINTENANCE-AND-OPERATIONS.md'
has R7 "$TEMPLATE" 'troubleshooting: docs/operations/TROUBLESHOOTING.md'

# R8 — the other skills are read-only
has R8 "$REVIEW" '**Read-only.** Never edit files, run a deploy, apply a plan'
for f in "$IAC" "$RUNB"; do has R8 "$f" 'All `ops-review` rules apply: read-only'; done
has R8 "$RUNB" '**Never run the scripts or the runbook steps**'
for f in "$REVIEW" "$IAC" "$RUNB"; do
  if grep -qE '^(Write|Edit)|[^a-z](Write|Edit)[,)]' <(sed -n '/^---$/,/^---$/p' "$f"); then bad "R8 ${f#"$PLUGIN"/} pre-approves a write tool"; else ok; fi
done

# R9 — values never printed; contacts are roles
has R9 "$REVIEW" 'name the key and the location, never the value'
has R9 "$IAC" '**Never print a value.**'
has R9 "$AGENT" 'Name the key and cite the location.'
has R9 "$MAN" 'Contacts are roles and channels'
has R9 "$BP/MAINTENANCE-AND-OPERATIONS.md" 'Contacts are roles and channels'

# R10 — security referral
for f in "$REVIEW" "$AGENT" "$IAC" "$RUNB"; do has R10 "$f" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'; done

# R11 — cross-skill step references resolve
NREFS=0
for f in "$PLUGIN"/skills/*/SKILL.md; do
  refs=$(sed 's/`//g' "$f" | grep -oE '[a-z][a-z0-9]*-[a-z0-9-]+ Steps? [0-9][0-9, –-]*' || true)
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    skill=${ref%% Step*}
    [ -f "$PLUGIN/skills/$skill/SKILL.md" ] || continue
    for n in $(printf '%s' "${ref#* Step}" | tr -cs '0-9' ' '); do
      NREFS=$((NREFS + 1))
      if grep -q "^### Step $n " "$PLUGIN/skills/$skill/SKILL.md"; then ok; else bad "R11 ${f#"$PLUGIN"/} cites $skill Step $n, which does not exist"; fi
    done
  done <<EOF_REFS
$refs
EOF_REFS
done
[ "$NREFS" -gt 0 ] || bad "R11 no step references found"

# R12 — the agent's key list equals the template's ops: keys
TKEYS=$(awk '/^ops:/ { on = 1; next } on && /^[^ #]/ { on = 0 } on && /^  [a-z_]+:/ { k = $1; sub(/:$/, "", k); print k }' "$TEMPLATE" | LC_ALL=C sort | tr '\n' ' ')
AKEYS=$(sed -n 's/.*The `ops:` keys are \(.*\)\. Use no other keys\..*/\1/p' "$AGENT" | sed 's/ (`[^)]*`)//g; s/ and /, /g' | tr ',' '\n' | tr -d '` ' | grep -v '^$' | LC_ALL=C sort | tr '\n' ' ')
if [ -n "$TKEYS" ] && [ "$TKEYS" = "$AKEYS" ]; then ok; else bad "R12 agent keys [$AKEYS] != template keys [$TKEYS]"; fi

# R13 — every script check id is in the severity table at its severity
TABLE=$(awk '/<!-- ops-severity:start/ { on = 1; next } /<!-- ops-severity:end/ { on = 0 } on' "$REVIEW")
NIDS=0
for s in "$PLUGIN"/scripts/*.sh; do
  while read -r id sev; do
    [ -n "$id" ] || continue
    NIDS=$((NIDS + 1)); L=$(printf '%s' "${id#OPS-}" | cut -c1); n=$(printf '%s' "$id" | tr -cd '0-9'); hit=0
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      named=0
      if printf '%s\n' "$row" | grep -qE "[(, ]$id([,) ]|$(printf '\342\200\223'))"; then named=1
      else
        for r in $(printf '%s\n' "$row" | grep -oE "OPS-$L[0-9]+$(printf '\342\200\223')$L[0-9]+" || true); do
          lo=$(printf '%s' "${r%%$(printf '\342\200\223')*}" | tr -cd '0-9'); hi=$(printf '%s' "${r##*$(printf '\342\200\223')}" | tr -cd '0-9')
          [ "$n" -ge "$lo" ] && [ "$n" -le "$hi" ] && named=1
        done
      fi
      [ "$named" = 1 ] || continue
      case "$row" in *"| $sev |") hit=1 ;; esac
    done <<EOF_ROWS
$TABLE
EOF_ROWS
    if [ "$hit" = 1 ]; then ok; else bad "R13 $(basename "$s") prints $id as $sev, but no severity-table row names $id at $sev"; fi
  done <<EOF_IDS
$( { sed -nE 's/^#   (OPS-[SZM][0-9]+) +(High|Medium|Low) .*/\1 \2/p' "$s"
      lib="$PLUGIN/scripts/lib/$(basename "$s" .sh).awk"
      [ -f "$lib" ] && grep -ohE 'fail\("[SZM][0-9]+", "[A-Za-z]+"' "$lib" | sed -E 's/fail\("([^"]+)", "([^"]+)"/OPS-\1 \2/'; } | LC_ALL=C sort -u)
EOF_IDS
done
[ "$NIDS" -ge 27 ] || bad "R13 expected at least 27 check ids in the script headers, found $NIDS"

# R14 — the blueprint passes the IaC and script checks (the manuals are covered by test-check-ops-manuals)
if bash "$PLUGIN/scripts/check-iac-config.sh" --manual "$BP/MAINTENANCE-AND-OPERATIONS.md" "$BP" >/dev/null 2>&1; then ok; else bad "R14 the blueprint fails check-iac-config.sh"; fi
if bash "$PLUGIN/scripts/check-ops-scripts.sh" "$BP" >/dev/null 2>&1; then ok; else bad "R14 the blueprint fails check-ops-scripts.sh"; fi

# R15 — N/A and NOTE are never passes
has R15 "$REVIEW" '`N/A` is never a pass.'
has R15 "$REVIEW" '`NOTE` lines are unrated'
has R15 "$AGENT" 'A check with nothing to check is N/A, never a pass.'

# R16 — the scripts run under the system bash (3.2 on macOS), not only a newer one
if [ -x /bin/bash ]; then
  for sc in "$PLUGIN"/scripts/*.sh; do
    if /bin/bash -n "$sc" 2>/dev/null; then ok; else bad "R16 $(basename "$sc") does not parse under /bin/bash ($(/bin/bash -c 'echo $BASH_VERSION'))"; fi
  done
  for sc in check-iac-config check-ops-scripts; do
    a=$(bash "$PLUGIN/scripts/$sc.sh" "$BP" 2>&1; echo "rc=$?"); b=$(/bin/bash "$PLUGIN/scripts/$sc.sh" "$BP" 2>&1; echo "rc=$?")
    if [ "$a" = "$b" ]; then ok; else bad "R16 $sc.sh gives a different result under /bin/bash"; fi
  done
  a=$(bash "$PLUGIN/scripts/check-ops-manuals.sh" --today 2026-10-25 "$BP/MAINTENANCE-AND-OPERATIONS.md" "$BP/TROUBLESHOOTING.md" "$BP" 2>&1; echo "rc=$?")
  b=$(/bin/bash "$PLUGIN/scripts/check-ops-manuals.sh" --today 2026-10-25 "$BP/MAINTENANCE-AND-OPERATIONS.md" "$BP/TROUBLESHOOTING.md" "$BP" 2>&1; echo "rc=$?")
  if [ "$a" = "$b" ]; then ok; else bad "R16 check-ops-manuals.sh gives a different result under /bin/bash"; fi
fi

# R6 — a non-default endpoint is renamed, not kept through the contract
has R6 "$REVIEW" 'the fix renames it to the contract path'
has R6 "$REVIEW" 'Never propose a `z`-suffixed value.'
has R6 "$AGENT" 'mark each detected path for rename'
has R6 "$PLUGIN/references/sre-baseline.md" 'The fix is to rename them to the defaults.'

# R17 — rollback is rated by what exists
has R17 "$REVIEW" '**Rollback is rated by what exists.**'
has R17 "$AGENT" '**Rollback is rated by what exists.**'
has R17 "$REVIEW" '| No rollback path while no production deploy exists yet (deploy files empty or stubs) | Low |'
has R17 "$PLUGIN/references/runbook-standard.md" '| no rollback path while no production deploy exists yet (deploy files empty or stubs) | Low |'
has R17 "$RUNB" 'Low while the deploy files are empty or stubs'

# R18 — trivy stays offline unless the operator agrees
has R18 "$IAC" '`trivy config --skip-check-update --skip-version-check --quiet .`: run it without asking.'
has R18 "$IAC" 'Plain `trivy config .` downloads its check bundle: ask first.'

printf "test-ops-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
