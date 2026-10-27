#!/usr/bin/env bash
# Behavior test for make/check-ownership.sh (the T13 ownership gate, ADR-015).
#
# Builds a small synthetic repository (three released plugins, one planned, a
# template skill, a marketplace, README, PILLARS and a registry) that passes
# every rule, then breaks one thing per case and checks that exactly the named
# rule fails and every other rule still passes. Also covers table edge cases:
# CRLF line endings, rows without a trailing pipe, bold and padded cells, tabs
# and non-ASCII text in cells, a missing or repeated marker, a header-only table
# and a row with the wrong number of cells.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Usage: test-check-ownership.sh [CHECKER]   (defaults to make/check-ownership.sh)
# Prints "test-check-ownership: N/N PASS" last (make/test-plugins.sh T13.0).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
CHK="${1:-$HERE/../../make/check-ownership.sh}"
[ -f "$CHK" ] || { echo "test-check-ownership: missing $CHK"; echo "test-check-ownership: 0/1 PASS"; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }

# ---------------------------------------------------------------------------
# The fixture: everything agrees.
F="$WORK/fixture"
build() {
  rm -rf "$F"; mkdir -p "$F"
  mk() { mkdir -p "$(dirname "$F/$1")"; cat > "$F/$1"; }
  pj() { mk "plugins/$1/.claude-plugin/plugin.json" <<J
{
  "name": "$1",
  "version": "$2",
  "description": "fixture"
}
J
  }
  pj ascent-alpha 0.2.0
  pj ascent-beta 0.1.0
  pj ascent-delivery 0.1.2
  mk plugins/ascent-alpha/skills/alpha-review/SKILL.md <<'M'
---
name: alpha-review
---
# Alpha review

Severity follows the rules in [rules](../../references/rules.md). Hand secrets → ascent-beta.
M
  mk plugins/ascent-alpha/skills/alpha-check/SKILL.md <<'M'
---
name: alpha-check
---
# Alpha check
M
  mk plugins/ascent-alpha/agents/alpha-reviewer.md <<'M'
---
name: alpha-reviewer
description: >-
  Use when a read-only alpha review is needed, or as a delivery-loop review lens
  for alpha changes.
tools: Read, Grep, Glob
---
Return findings in the delivery-loop format.
M
  mk plugins/ascent-alpha/references/rules.md <<'M'
# Rules

| Id | Severity | Rule |
|---|---|---|
| AL-R1 | High | The first rule |
| AL-R2 | Low | The second rule, café-safe |
M
  mk plugins/ascent-alpha/references/contract-template.yml <<'M'
# .ascent/contract.yml: the alpha: section
version: 1

alpha:
  maturity_target: enterprise
M
  mk plugins/ascent-alpha/scripts/check-alpha.sh <<'M'
#!/usr/bin/env bash
# Rules:
#   AL-R1  High    the first rule
#   AL-R2  Low     the second rule
# Catalogue entries AL-K1 onward are listed in rules.md.
echo ok
M
  mk plugins/ascent-beta/skills/beta-audit/SKILL.md <<'M'
---
name: beta-audit
---
# Beta audit
M
  mk plugins/ascent-delivery/skills/delivery-loop/SKILL.md <<'M'
---
name: delivery-loop
---
# Delivery loop

### Step 4 — Review

| Lens | Providers, first installed wins | Otherwise |
|---|---|---|
| Correctness | `engineering:code-review` | fallback prompt |
| Alpha | `ascent-alpha:alpha-reviewer`, `other:alpha-skill` | fallback prompt |

Then verify.

| Lens | Unrelated later table |
|---|---|
| Not checked | — |
M
  mk plugins/ascent-delivery/skills/delivery-loop/references/review-lenses.md <<'M'
# Review lenses

| Lens | Providers, first installed wins | Fallback |
|---|---|---|
| Correctness | `engineering:code-review` | [Correctness](#correctness) |
| Alpha | `ascent-alpha:alpha-reviewer`, `other:alpha-skill` | [Alpha](#alpha) |
M
  mk plugins/ascent-delivery/README.md <<'M'
# ascent-delivery

| Lens | Providers, first installed wins |
|---|---|
| Correctness | `engineering:code-review` |
| Alpha | `ascent-alpha:alpha-reviewer`, `other:alpha-skill` |
M
  mk plugins/ascent-delivery/hooks/operator-boundary.sh <<'M'
#!/usr/bin/env bash
exit 0
M
  mk .claude-plugin/marketplace.json <<'J'
{
  "name": "fixture",
  "owner": { "name": "fixture" },
  "plugins": [
    { "name": "ascent-alpha", "source": "./plugins/ascent-alpha", "version": "0.2.0" },
    {
      "name": "ascent-beta",
      "source": "./plugins/ascent-beta",
      "version": "0.1.0"
    },
    {
      "name": "ascent-delivery",
      "source": "./plugins/ascent-delivery",
      "version": "0.1.2"
    }
  ]
}
J
  mk skills/lloydbriantech-ascent/assets/template/.claude/skills/ascent-tpl/SKILL.md <<'M'
# template skill
M
  mk README.md <<'M'
# Fixture

| Plugin | Version | Pillars | Ask | What it does |
|---|---|---|---|---|
| [`ascent-alpha`](plugins/ascent-alpha/README.md) | 0.2.0 | Resilience | "alpha?" | Alpha |
| [`ascent-beta`](plugins/ascent-beta/README.md) | 0.1.0 | Trust | "beta?" | Beta |
| [`ascent-delivery`](plugins/ascent-delivery/README.md) | 0.1.2 | Value | "ship" | Delivery |
M
  mk docs/framework/PILLARS.md <<'M'
# Pillars

| Attribute | Checked by |
|---|---|
| Alpha-ness | `ascent-alpha` (`alpha-review`, `alpha-check`), AL-R1 |
| Templates | `ascent-tpl`, `ascent-delivery` (definition of done) |
| Planned | `ascent-gamma` |
| Bare names | `beta-audit`, `alpha-reviewer` |

Text outside the table naming `ascent-unknown` is not checked.
M
  mk docs/framework/OWNERSHIP.md <<'M'
# Ownership registry

<!-- ownership:signals:start -->
| Signal | Plugin | Why |
|---|---|---|
| alpha files | `ascent-alpha` | alpha |
| secrets | `ascent-beta` | beta |
| git | `ascent-delivery` | delivery |
<!-- ownership:signals:end -->

<!-- ownership:plugins:start -->
| Plugin | Code | Status | Build | Contract section | Severity marker |
|---|---|---|---|---|---|
| `ascent-alpha` | `AL` | released | hand-written | `alpha` | — |
| `ascent-beta` | `BE` | released | generated | — | — |
| `ascent-delivery` | `DEL` | released | hand-written | — | — |
| `ascent-gamma` | `GA` | planned | hand-written | `gamma` | — |
<!-- ownership:plugins:end -->

<!-- ownership:components:start -->
| Plugin | Kind | Name |
|---|---|---|
| `ascent-alpha` | skill | `alpha-review` |
| `ascent-alpha` | skill | `alpha-check` |
| `ascent-alpha` | agent | `alpha-reviewer` |
| `ascent-beta` | skill | `beta-audit` |
| `ascent-delivery` | skill | `delivery-loop` |
| `ascent-delivery` | hook | `operator-boundary` |
<!-- ownership:components:end -->

<!-- ownership:families:start -->
| Prefix | Plugin | Kind | Defined in |
|---|---|---|---|
| `AL-R` | `ascent-alpha` | rule | `plugins/ascent-alpha/scripts/check-alpha.sh` |
| `AL-K` | `ascent-alpha` | catalogue | `plugins/ascent-alpha/scripts/check-alpha.sh` |
| `T` | — | internal | `README.md` |
<!-- ownership:families:end -->

<!-- ownership:reserved:start -->
| Reserved | For | Release |
|---|---|---|
| `GA-X` | `ascent-gamma` | v9.9.9 |
<!-- ownership:reserved:end -->

<!-- ownership:domains:start -->
| Domain | Target owner | Test-present owner | Status |
|---|---|---|---|
| alpha things | `ascent-alpha` | `ascent-alpha` | released |
| gamma things | — | `ascent-gamma` | planned |
| templated things | operator | `ascent-tpl` | released |
<!-- ownership:domains:end -->

<!-- ownership:lenses:start -->
| Lens | Providers, first installed wins | Fallback |
|---|---|---|
| Correctness | `engineering:code-review` | fallback prompt |
| Alpha | `ascent-alpha:alpha-reviewer`, `other:alpha-skill` | fallback prompt |
<!-- ownership:lenses:end -->
M
}

# ---------------------------------------------------------------------------
# Helpers. edit FILE SED — the case is void (and fails) when sed changes nothing.
edit() {
  sed -e "$2" "$F/$1" > "$WORK/edit" || { bad "$CASE: sed failed on $1"; return 1; }
  if cmp -s "$WORK/edit" "$F/$1"; then bad "$CASE: anchor miss in $1 ($2)"; return 1; fi
  cat "$WORK/edit" > "$F/$1"
}
run() { PATH="$SHIM:$PATH" bash "$CHK" "$F" > "$WORK/out" 2>&1; RC=$?; }
# expect RULE — only RULE fails (all ten rules still print), exit 1; "none" — all pass, exit 0
expect() {
  run
  local fails n
  fails=$(sed -n 's/^FAIL  \(T13\.[0-9]*\) .*/\1/p' "$WORK/out" | tr '\n' ' ' | sed 's/ $//')
  n=$(grep -cE '^(PASS|FAIL)  T13\.[0-9]+ ' "$WORK/out")
  if [ "$1" = none ]; then
    if [ -z "$fails" ] && [ "$RC" -eq 0 ] && [ "$n" -eq 10 ]; then ok
    else bad "$CASE: expected all 10 to pass, got rc=$RC n=$n fails='$fails': $(grep '^FAIL' "$WORK/out" | head -2 | tr '\n' ';')"; fi
  elif [ "$fails" = "$1" ] && [ "$RC" -eq 1 ] && [ "$n" -eq 10 ]; then
    if [ -n "${2:-}" ] && ! grep "^FAIL  $1 " "$WORK/out" | grep -qF -- "$2"; then bad "$CASE: $1 failed without '$2': $(grep "^FAIL  $1 " "$WORK/out")"; else ok; fi
  else bad "$CASE: expected only $1 to fail, got rc=$RC n=$n fails='$fails': $(grep '^FAIL' "$WORK/out" | head -3 | tr '\n' ';')"; fi
}
c() { CASE="$1"; build; }

matrix() {
  CASE=help; PATH="$SHIM:$PATH" bash "$CHK" --help > "$WORK/out" 2>&1
  if [ $? -eq 0 ] && grep -q 'Usage: check-ownership.sh' "$WORK/out"; then ok; else bad "help: no usage"; fi

  c clean; expect none
  c crlf; sed 's/$/\r/' "$F/docs/framework/OWNERSHIP.md" > "$WORK/crlf" && cat "$WORK/crlf" > "$F/docs/framework/OWNERSHIP.md"; expect none
  c no-trailing-pipe; edit docs/framework/OWNERSHIP.md 's/^\(| `ascent-[a-z]*` | skill | `[a-z-]*`\) |$/\1/' && expect none
  c bold-padded; edit docs/framework/OWNERSHIP.md 's/^| `ascent-beta` | `BE` |/|   **`ascent-beta`**   |  `BE`  |/' && expect none
  c tab-in-cell; edit docs/framework/OWNERSHIP.md "s/^| alpha files |/|	alpha	files	|/" && expect none
  c unicode-cell; edit docs/framework/OWNERSHIP.md 's/^| alpha things |/| alpha things — café |/' && expect none

  # T13.1 registry
  c no-registry; rm "$F/docs/framework/OWNERSHIP.md"; run
  if [ "$RC" -eq 1 ] && grep -q '^FAIL  T13.1 registry: docs/framework/OWNERSHIP.md not found' "$WORK/out"; then ok; else bad "$CASE: $(head -1 "$WORK/out")"; fi
  c no-end-marker; edit docs/framework/OWNERSHIP.md '/<!-- ownership:reserved:end -->/d' && expect T13.1 "reserved: needs one start and one end marker"
  c two-tables; printf '\n<!-- ownership:reserved:start -->\n| A | B | C |\n|---|---|---|\n<!-- ownership:reserved:end -->\n' >> "$F/docs/framework/OWNERSHIP.md"; expect T13.1 "found 2 and 2"
  c header-only; edit docs/framework/OWNERSHIP.md '/^| `GA-X` /d' && expect T13.1 "reserved: table has no rows"
  c cell-count; edit docs/framework/OWNERSHIP.md 's/^| `GA-X` | `ascent-gamma` | v9.9.9 |/| `GA-X` | `ascent-gamma` |/' && expect T13.1 "row has 2 cells, header has 3"

  c row-without-pipe; edit docs/framework/OWNERSHIP.md 's/^| `GA-X` | `ascent-gamma` | v9.9.9 |$/`GA-X` | `ascent-gamma` | v9.9.9 |/' && expect T13.1 "reserved: line is not a table row"

  # T13.2 plugins
  c dir-without-row; mkdir -p "$F/plugins/ascent-rogue"; expect T13.2 "plugins/ascent-rogue has no released row"
  c row-without-dir; rm -rf "$F/plugins/ascent-beta"; edit .claude-plugin/marketplace.json 's/"ascent-beta"/"ascent-zzz"/'; edit README.md '/ascent-beta/d'; edit docs/framework/PILLARS.md 's/`beta-audit`, //'
  edit docs/framework/OWNERSHIP.md '/| `ascent-beta` | skill |/d' && expect T13.2 "released ascent-beta has no plugins/ascent-beta directory"
  c market-extra; edit .claude-plugin/marketplace.json 's/"ascent-beta",/"ascent-beta2",/' && expect T13.2 "released ascent-beta has no marketplace entry"
  c planned-with-dir; mkdir -p "$F/plugins/ascent-gamma"; expect T13.2 "planned ascent-gamma already has a plugins/ascent-gamma directory"
  c bad-status; edit docs/framework/OWNERSHIP.md 's/| `GA` | planned |/| `GA` | maybe |/' && expect T13.2 'unknown status "maybe"'
  c bad-build; edit docs/framework/OWNERSHIP.md 's/| released | generated |/| released | magic |/' && expect T13.2 'unknown build "magic"'
  c market-only-entry; edit .claude-plugin/marketplace.json 's#^    { "name": "ascent-alpha", "source": "./plugins/ascent-alpha", "version": "0.2.0" },$#&\
    { "name": "ascent-zeta", "source": "./plugins/ascent-zeta" },#' && expect T13.2 "marketplace entry ascent-zeta has no released row"
  c market-nested-name; edit .claude-plugin/marketplace.json 's#^      "name": "ascent-beta",$#&\
      "author": { "name": "someone", "url": "https://example.invalid/{x}" },#' && expect none
  c market-missing; rm "$F/.claude-plugin/marketplace.json"; expect T13.2 "marketplace.json not found"
  c plugin-row-twice; edit docs/framework/OWNERSHIP.md 's/^| `ascent-gamma` | `GA` | planned | hand-written | `gamma` | — |$/&\
| `ascent-gamma` | `GB` | planned | hand-written | — | — |/' && expect T13.2 "two plugin rows for ascent-gamma"
  c signal-not-released; edit docs/framework/OWNERSHIP.md 's/^| git | `ascent-delivery` | delivery |$/&\
| gamma files | `ascent-gamma` | gamma |/' && expect T13.2 "signal row names ascent-gamma, which is not a released plugin"
  c no-signal; edit docs/framework/OWNERSHIP.md '/^| secrets | /d' && expect T13.2 "released ascent-beta has no signal"

  # T13.3 components
  c skill-unregistered; mkdir -p "$F/plugins/ascent-beta/skills/beta-extra"; expect T13.3 "skill ascent-beta:beta-extra is not registered"
  c agent-missing; rm "$F/plugins/ascent-alpha/agents/alpha-reviewer.md"; expect T13.3 "registered agent ascent-alpha:alpha-reviewer does not exist"
  c hook-unregistered; printf '#!/bin/sh\n' > "$F/plugins/ascent-delivery/hooks/second.sh"; expect T13.3 "hook ascent-delivery:second is not registered"
  c component-twice; edit docs/framework/OWNERSHIP.md 's/^\(| `ascent-beta` | skill | `beta-audit` |\)$/\1\
\1/' && expect T13.3 "two rows for ascent-beta:beta-audit"

  # T13.4 codes, families and reserved names
  c code-twice; edit docs/framework/OWNERSHIP.md 's/| `GA` | planned/| `AL` | planned/' && expect T13.4 "two plugins share the code AL"
  c family-wrong-code; edit docs/framework/OWNERSHIP.md 's/^| `AL-K` | `ascent-alpha`/| `AL-K` | `ascent-beta`/' && expect T13.4 "does not start with ascent-beta's code BE-"
  c family-undefined; edit plugins/ascent-alpha/scripts/check-alpha.sh 's/AL-K1 onward/later entries/' && expect T13.4 "never mentions AL-K1"
  c family-file-missing; edit docs/framework/OWNERSHIP.md 's#`plugins/ascent-alpha/scripts/check-alpha.sh` |$#`plugins/ascent-alpha/scripts/gone.sh` |#' && expect T13.4 "defining file plugins/ascent-alpha/scripts/gone.sh not found"
  c family-twice; edit docs/framework/OWNERSHIP.md 's/^\(| `AL-R` | .*\)$/\1\
\1/' && expect T13.4 "two families share the prefix AL-R"
  c reserved-taken; edit docs/framework/OWNERSHIP.md 's/^\(| `AL-K` | `ascent-alpha` | catalogue |\)\(.*\)$/\1\2\
| `GA-X` | `ascent-alpha` | catalogue |\2/' && expect T13.4 "family GA-X is reserved for ascent-gamma, used by ascent-alpha"
  c no-code; edit docs/framework/OWNERSHIP.md 's/^| `ascent-gamma` | `GA` |/| `ascent-gamma` | — |/' && expect T13.4 "ascent-gamma has no code"
  c reserved-twice; edit docs/framework/OWNERSHIP.md 's/^| `GA-X` | `ascent-gamma` | v9.9.9 |$/&\
&/' && expect T13.4 "reserved twice: GA-X"
  c internal-two-letters; edit docs/framework/OWNERSHIP.md 's/^| `T` | — | internal/| `TT` | — | internal/' && expect T13.4 "internal family TT is not one capital letter"
  c family-format; edit docs/framework/OWNERSHIP.md 's#^| `AL-K` | .*$#&\
| `AL-` | `ascent-alpha` | rule | `plugins/ascent-alpha/scripts/check-alpha.sh` |#' && expect T13.4 "family AL- is not <CODE>-<letters>"
  c family-unknown-kind; edit docs/framework/OWNERSHIP.md 's#^| `AL-K` | .*$#&\
| `AL-Q` | `ascent-alpha` | rules | `plugins/ascent-alpha/scripts/check-alpha.sh` |#' && expect T13.4 'family AL-Q has unknown kind "rules"'
  c reserved-unregistered; edit docs/framework/OWNERSHIP.md 's/^| `GA-X` | `ascent-gamma` | v9.9.9 |$/&\
| `OM-X` | `ascent-omega` | v9.9.9 |/' && expect T13.4 "reserved OM-X is for unregistered plugin ascent-omega"
  c internal-with-plugin; edit docs/framework/OWNERSHIP.md 's/^| `T` | — | internal/| `T` | `ascent-alpha` | internal/' && expect T13.4 "internal family T names a plugin"
  c reserved-wrong-code; edit docs/framework/OWNERSHIP.md 's/^| `GA-X` |/| `AL-X` |/' && expect T13.4 "reserved AL-X does not start with ascent-gamma's code GA-"

  # T13.5 contract sections
  c extra-section; printf '\nbeta:\n  x: 1\n' >> "$F/plugins/ascent-alpha/references/contract-template.yml"; expect T13.5 "declares 'alpha beta', registry says 'alpha'"
  c section-twice; edit docs/framework/OWNERSHIP.md 's/| generated | — |/| generated | `alpha` |/'
  printf 'version: 1\nalpha:\n' > "$F/plugins/ascent-beta/contract.tmp"; mkdir -p "$F/plugins/ascent-beta/references"; mv "$F/plugins/ascent-beta/contract.tmp" "$F/plugins/ascent-beta/references/contract-template.yml"
  expect T13.5 "two plugins claim the contract section alpha"

  # T13.6 markers
  c marker-planned; edit plugins/ascent-alpha/skills/alpha-review/SKILL.md 's/→ ascent-beta/→ ascent-gamma/' && expect T13.6 "marker → ascent-gamma names no released plugin"

  # T13.7 domains
  c domain-twice; edit docs/framework/OWNERSHIP.md 's/^| gamma things |/| alpha things |/' && expect T13.7 "two rows for the domain alpha things"
  c domain-owner-unknown; edit docs/framework/OWNERSHIP.md 's/^| alpha things | `ascent-alpha`/| alpha things | `ascent-omega`/' && expect T13.7 "owner ascent-omega is not a registered plugin"
  c domain-bad-status; edit docs/framework/OWNERSHIP.md 's/^| alpha things | `ascent-alpha` | `ascent-alpha` | released |/| alpha things | `ascent-alpha` | `ascent-alpha` | maybe |/' && expect T13.7 'alpha things: unknown status "maybe"'
  c domain-released-planned-owner; edit docs/framework/OWNERSHIP.md 's/^| gamma things | — | `ascent-gamma` | planned |/| gamma things | — | `ascent-gamma` | released |/' && expect T13.7 "owner ascent-gamma is planned"

  # T13.8 lenses
  c lens-drift; edit plugins/ascent-delivery/skills/delivery-loop/references/review-lenses.md '/^| Alpha |/d' && expect T13.8 "review-lenses.md lacks: Alpha"
  c lens-order; edit plugins/ascent-delivery/README.md 's/`ascent-alpha:alpha-reviewer`, `other:alpha-skill`/`other:alpha-skill`, `ascent-alpha:alpha-reviewer`/' && expect T13.8 "README.md has, registry lacks: Alpha other:alpha-skill,ascent-alpha:alpha-reviewer"
  c lens-later-table-ignored; edit plugins/ascent-delivery/skills/delivery-loop/SKILL.md 's/^| Not checked | — |/| Not checked | `x:y` |/' && expect none
  c lens-header-padded; edit plugins/ascent-delivery/README.md 's/^| Lens | Providers/|  **Lens**  | Providers/' && expect none
  c lens-no-table; edit plugins/ascent-delivery/skills/delivery-loop/SKILL.md 's/^| Lens |/| Lenses |/' && expect T13.8 "SKILL.md has no lens table"
  c lens-agent-unprovided; edit docs/framework/OWNERSHIP.md 's/^| Alpha | `ascent-alpha:alpha-reviewer`, `other:alpha-skill` |/| Alpha | `other:alpha-skill` |/'
  for f in plugins/ascent-delivery/skills/delivery-loop/SKILL.md plugins/ascent-delivery/skills/delivery-loop/references/review-lenses.md plugins/ascent-delivery/README.md; do
    edit "$f" 's/`ascent-alpha:alpha-reviewer`, //'
  done
  expect T13.8 "agent ascent-alpha:alpha-reviewer calls itself a delivery-loop review lens but provides none"
  c lens-provider-unregistered; edit docs/framework/OWNERSHIP.md 's/^| Correctness | `engineering:code-review` |/| Correctness | `ascent-beta:beta-reviewer` |/'
  for f in plugins/ascent-delivery/skills/delivery-loop/SKILL.md plugins/ascent-delivery/skills/delivery-loop/references/review-lenses.md plugins/ascent-delivery/README.md; do
    edit "$f" 's/^| Correctness | `engineering:code-review` |/| Correctness | `ascent-beta:beta-reviewer` |/'
  done
  expect T13.8 "provider ascent-beta:beta-reviewer is not a registered skill or agent"

  # T13.9 docs
  c readme-version; edit README.md 's/^\(| \[`ascent-beta`\]([^)]*)\) | 0.1.0 |/\1 | 0.0.9 |/' && expect T13.9 "README says ascent-beta 0.0.9, plugin.json says 0.1.0"
  c readme-missing; edit README.md '/^| \[`ascent-delivery`\]/d' && expect T13.9 "README plugin table has no row for ascent-delivery"
  c pillars-unknown; edit docs/framework/PILLARS.md 's/^| Planned | `ascent-gamma` |/| Planned | `ascent-omega` |/' && expect T13.9 "PILLARS names ascent-omega"
  c pillars-bare-name; edit docs/framework/PILLARS.md 's/`beta-audit`, `alpha-reviewer`/`beta-audits`, `alpha-reviewer`/' && expect T13.9 "PILLARS names beta-audits, which is not a registered skill or agent"
  c pillars-component; edit docs/framework/PILLARS.md 's/`alpha-check`)/`alpha-gone`)/' && expect T13.9 "PILLARS names ascent-alpha (alpha-gone)"

  # T13.10 id format
  c unqualified-cell; edit plugins/ascent-alpha/references/rules.md 's/^| AL-R2 |/| R2 |/' && expect T13.10 "unqualified id cell | R2 |"
  c unqualified-bold-cell; edit plugins/ascent-alpha/references/rules.md 's/^| AL-R2 |/| **R2** |/' && expect T13.10 "unqualified id cell"
  c unqualified-backtick-cell; edit plugins/ascent-alpha/references/rules.md 's/^| AL-R2 |/| `R2` |/' && expect T13.10 "unqualified id cell"
  c pillars-prefix; edit docs/framework/PILLARS.md 's/), AL-R1 |$/), AL-Q1 |/' && expect T13.10 "id prefix AL-Q is not a registered or reserved family"
  c unqualified-header; edit plugins/ascent-alpha/scripts/check-alpha.sh 's/^#   AL-R2  Low /#   R2  Low /' && expect T13.10 "unqualified header id R2"
  c unknown-prefix; edit plugins/ascent-alpha/references/rules.md 's/^| AL-R2 |/| AL-Q2 |/' && expect T13.10 "id prefix AL-Q is not a registered or reserved family"
  c reserved-prefix-ok; edit plugins/ascent-alpha/skills/alpha-check/SKILL.md 's/^# Alpha check$/# Alpha check (GA-X1 later)/' && expect none
}

realpath_of() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")"); }
AWKS="default"; SEEN=" $(realpath_of "$(command -v awk)") "
[ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
  p=$(command -v "$a" 2>/dev/null) || continue
  r=$(realpath_of "$p")
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; AWKS="$AWKS $a"
done
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-check-ownership: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
