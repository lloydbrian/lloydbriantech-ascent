#!/usr/bin/env bash
# Answers "are we ready for <env>?" for one environment on a project's ladder
# (local, beta, prod by default), from evidence the repository already holds.
# Part of the ascent-governance plugin (launch-readiness Steps 1, 3 and 4,
# governance-review Step 1), and made to run in a project's own CI at no token
# cost. It runs the other plugins' checkers; it reads the contract, and git
# only through those checkers.
#
# Usage: check-audit.sh [--env NAME] [--launch] [--record FILE] [--html FILE [--from RECORD]] [--contract FILE] [--plugins DIR] [--skip CHECK]... [--today YYYY-MM-DD] [--no-git] [REPO]
#
# REPO is the repository root (default "."). The contract is .ascent/contract.yml,
# or .claude/contract.yml, or --contract FILE. --env is an environment from
# governance.environments (default: the first). An environment's floor is what
# governance.floors lists for it and for every environment below it; with no
# floors in the contract, default floors follow the maturity target and what the
# repository contains. --plugins DIR is where the other plugins live
# (DIR/<plugin>/scripts/<script>.sh; default: beside this plugin, in a checkout
# or in the plugin cache). --skip CHECK leaves one check out (a CI job that
# already ran the gate passes --skip delivery/gate). --launch asks the launch
# question, where a review that is due is a NO-GO. --record FILE asks it and
# writes the answer as an unsigned launch record: FILE is
# <governance.launch_dir>/<today>-<env>.md, it is never overwritten, and it is
# written only when the working copy is the commit it names (launch records and
# the review log aside). A person signs it; this script never does. --html FILE
# also writes the result as one page that stands alone (no script, nothing
# fetched; a dark theme and a print style); with --from RECORD it writes the
# page of that launch record and runs no check. The page is never written into
# the launch folder, through a link, or over a file this script did not write.
# The files --record, --html and --from name are read from where the command is
# run, as --contract and --plugins are. When
# $GITHUB_STEP_SUMMARY is set, the result is added to it as Markdown. --no-git
# skips what needs git history.
#
# Checks (severity from the gov-severity table in launch-readiness):
#   GOV-S1  High    the governance section says what its author thinks: the
#                   contract can be read, every key of the section is one this
#                   version reads, with the kind of value it expects (a key
#                   that is not read would change the floor in silence), every
#                   floor is for an environment on the ladder, every review age
#                   is a positive number of days, every check is named
#                   <plugin>/<script>
#   GOV-S2  Medium  every check in the floor can be run: it has an adapter, and
#                   its checker accepts the options the adapter gives it (it
#                   refuses them with an exit 2 whose first line is its own
#                   message: <name>: or Usage: <name>.sh, ADR-030)
#   GOV-L1  High    every checker in the floor passes (one that stops without
#                   finishing has not passed, and an exit 2 without the
#                   checker's own message is one, ADR-030); a checker whose
#                   findings are all Medium or Low makes GOV-L1 Medium or Low,
#                   as its most severe finding is (ADR-029)
#   GOV-L2  Low     every check in the floor is measured: its plugin is
#                   available, the contract gives the input it needs, and it had
#                   something it could check (N/A is never a pass)
#   GOV-L3  High    on a rung with sign_off (or above one): the newest launch
#                   record of the environment is signed by a person, with a real
#                   date that is not after today, and its verdict is not NO-GO
#                   (a record whose file name is dated after today is not read)
#   GOV-L4  High    the signer is in governance.approvers, when that list is not empty
#   GOV-L5  High    nothing but launch records and the review log changed since
#                   the commit the signed record names (--no-git: not checked)
#   GOV-W1  High    no waiver in the contract is past its review_by date
#   GOV-W2  Low     no waiver is due for review within 14 days
#   GOV-W3  Medium  every waiver has a review_by that is a real date
#   GOV-W4  Medium  every waiver says what it skips, and its id is an ADR whose
#                   status is Accepted
#   GOV-R1  Medium  every review in the floor has a row in the review log that
#                   is no older than the floor allows, and no newer row of it
#                   that cannot be read (High with --launch)
#   GOV-R2  High    the newest row of each review names the rule of every open
#                   High finding, and none is a rule that no waiver covers
#                   (Medium: it is rated weak)
#   GOV-R3  Medium  every row of the review log can be read
#   GOV-R4  Medium  rows of the review log are only added: none was removed or
#                   changed in the git history
#   GOV-A1  High    every AI application (ai.applications) has a risk-tier record,
#                   <governance.ai_tier_dir>/<name>.md, and no AI code sits
#                   outside every declared application (ascent-ai's detect-ai.sh)
#   GOV-A2  High    the record has every field, a tier of 1, 2 or 3, its reasons
#                   in their fixed values, and the application's own name
#   GOV-A3  High    a person decided the tier: decided_by is in governance.approvers
#                   (any name when that list is empty), decided_on a real date
#                   that is not after today
#   GOV-A4  Medium  the record's review_by is not past
#   GOV-A5  High    the tier is not below the floor its own reasons imply
#                   (irreversible or financial actions, or decisions about
#                   people: 3; an external audience or reversible actions: 2)
# GOV-A runs on every rung above the lowest, whatever governance.floors says,
# when the contract declares an AI application. With no ai.applications, AI code
# that ascent-ai finds makes the repository one application, named after its
# folder. With an AI application, the default beta floor gains
# ascent-ai/check-ai-design (and the threat model, which then needs SEC-T5), and
# prod gains check-ai-evidence, check-ai-runtime, ascent-security/check-redteam
# and the ai-review review; each of those checkers runs once for each application.
# A waiver is an entry of any section's waivers list. Each is listed with what it
# skips and the days it has left; decisions.acknowledged_changes entries are
# listed too, and are not waivers.
#
# Verdict: NO-GO when a High check fails; GO WITH CONDITIONS when only Medium or
# Low checks fail, or something is unmeasured; GO otherwise. A plugin that is
# not available is unmeasured, never a NO-GO.
#
# Output: FAIL lines (FAIL  GOV-Xn  SEVERITY  source  message), a PASS line per
# piece of evidence, N/A and NOTE lines, then "check-audit: <env>: <verdict>, ...".
# Limits: it checks that the evidence exists and is current, not that the system
# is good.
# Exit: 0 GO or GO WITH CONDITIONS; 1 NO-GO; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '9p' "$0" | sed 's/^# //'; }
ENVNAME=""; LAUNCH=0; RECORD=""; HTML=""; FROM=""; CONTRACT=""; PLUGINS=""; TODAY=""; NOGIT=0; POS=(); SKIP=" "
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
bad() { echo "check-audit: $1" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --env) need $#; ENVNAME="$2"; shift 2 ;;
    --launch) LAUNCH=1; shift ;;
    --record) need $#; RECORD="$2"; LAUNCH=1; shift 2 ;;
    --html) need $#; HTML="$2"; shift 2 ;;
    --from) need $#; FROM="$2"; shift 2 ;;
    --contract) need $#; CONTRACT="$2"; shift 2 ;;
    --plugins) need $#; PLUGINS="$2"; shift 2 ;;
    --skip) need $#; SKIP="$SKIP$2 "; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --no-git) NOGIT=1; shift ;;
    -h|--help) usage; awk 'NR > 9 && /^#/ { sub(/^# ?/, ""); print; next } NR > 9 { exit }' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*) usage >&2; bad "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ "${#POS[@]}" -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "$REPO is not a directory"
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)

HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; LIB="$HERE/lib"
for f in contract.awk adapt.awk audit.awk ai-tier.awk log-rows.awk render.awk md-html.awk adapters.tsv; do [ -f "$LIB/$f" ] || bad "missing $LIB/$f"; done
[ -z "$PLUGINS" ] || [ -d "$PLUGINS" ] || bad "--plugins $PLUGINS is not a directory"
[ -z "$PLUGINS" ] || PLUGINS="$(cd "$PLUGINS" && pwd)"
if [ -n "$CONTRACT" ]; then
  [ -f "$CONTRACT" ] || bad "--contract $CONTRACT not found"
  CONTRACT="$(cd "$(dirname "$CONTRACT")" && pwd)/$(basename "$CONTRACT")"
fi
# --record, --html and --from are read from where the command is run, as --contract and --plugins are
CALLER="$PWD"; RECORD_ARG="$RECORD"
abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$CALLER" "$1" ;; esac; }
[ -z "$HTML" ] || HTML=$(abspath "$HTML")
[ -z "$FROM" ] || FROM=$(abspath "$FROM")
[ -z "$RECORD" ] || RECORD=$(abspath "$RECORD")
cd "$REPO"

# a real date, YYYY-MM-DD
realdate() { printf '%s\n' "$1" | awk '{ if ($0 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) exit 1
  y = substr($0, 1, 4) + 0; m = substr($0, 6, 2) + 0; d = substr($0, 9, 2) + 0
  n = (m == 2) ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  exit !(m >= 1 && m <= 12 && d >= 1 && d <= n) }'; }
realdate "$TODAY" || bad "--today $TODAY is not a real date (YYYY-MM-DD)"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
TAB="$(printf '\t')"
: > "$T/items.tsv"; : > "$T/c.tsv"
# item KIND ID STATUS SEVERITY SOURCE TEXT
item() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$(printf '%s' "$6" | tr '\t\n' '  ')" >> "$T/items.tsv"; }
finish() {  # prints the result and exits with the verdict's code
  awk -F '\t' -v fmt=text -v env="$ENVNAME" -f "$LIB/render.awk" "$T/items.tsv"
  if awk -F '\t' '($3 == "fail" || $3 == "due") && $4 == "High" { f = 1 } END { exit !f }' "$T/items.tsv"; then exit 1; fi
  exit 0
}

# --- the contract -----------------------------------------------------------
if [ -z "$CONTRACT" ]; then
  for c in .ascent/contract.yml .claude/contract.yml; do [ -f "$c" ] && { CONTRACT="$c"; break; }; done
fi
CNAME="${CONTRACT:-}"; case "$CNAME" in "$PWD"/*) CNAME="${CNAME#"$PWD"/}" ;; esac
UNREADABLE=""
if [ -n "$CONTRACT" ]; then
  awk -f "$LIB/contract.awk" "$CONTRACT" > "$T/c.tsv" 2> "$T/c.err" || { UNREADABLE=$(sed 's/^contract.awk: //' "$T/c.err" | head -1); : > "$T/c.tsv"; }
fi
cget()  { awk -F '\t' -v k="$1" '$1 == k { print $2; exit }' "$T/c.tsv"; }
clist() { awk -F '\t' -v k="$1" 'index($1, k "[") == 1 && substr($1, length(k) + 2) ~ /^[0-9]+\]$/ { print $2 }' "$T/c.tsv"; }
ckeys() { awk -F '\t' -v k="$1." 'index($1, k) == 1 { s = substr($1, length(k) + 1); sub(/[.\[].*$/, "", s); if (!(s in seen)) { seen[s] = 1; print s } }' "$T/c.tsv"; }
chas()  { awk -F '\t' -v k="$1" 'index($1, k) == 1 { f = 1 } END { exit !f }' "$T/c.tsv"; }

# --- the ladder -------------------------------------------------------------
# a name is letters, digits, "-" and "_": it is part of a file name and of a contract key
BADENV=$(clist governance.environments | grep -Ev '^[A-Za-z0-9][A-Za-z0-9_-]*$' | head -1 || true)
if [ -n "$BADENV" ]; then
  ENVNAME="${ENVNAME:--}"
  item setup GOV-S1 fail High "${CONTRACT:-the contract}" "governance.environments names '$BADENV'; an environment's name is letters, digits, - and _ (it is part of each launch record's file name)"
  finish
fi
LADDER=$(clist governance.environments | tr '\n' ' ')
[ -n "${LADDER// /}" ] || LADDER="local beta prod "
LADDER_TEXT=$(printf '%s' "$LADDER" | sed 's/ *$//; s/ /, /g')
[ -n "$ENVNAME" ] || ENVNAME="${LADDER%% *}"
ONLADDER=0; for e in $LADDER; do [ "$e" = "$ENVNAME" ] && ONLADDER=1; done
[ "$ONLADDER" -eq 1 ] || bad "unknown environment '$ENVNAME'; the ladder is: $LADDER_TEXT"
RUNGS=""; for e in $LADDER; do RUNGS="$RUNGS$e "; [ "$e" = "$ENVNAME" ] && break; done   # this rung and those below
NRUNGS=$(printf '%s' "$LADDER" | wc -w | tr -d ' ')

if [ -n "$UNREADABLE" ]; then
  item setup GOV-S1 fail High "$CNAME" "the contract cannot be read ($UNREADABLE); no floor can be worked out from it"
  finish
fi

# --- the maturity, and where it came from -----------------------------------
rank() { case "$1" in prototype) echo 1 ;; standard) echo 2 ;; enterprise) echo 3 ;; *) echo 0 ;; esac; }
MATURITY=$(cget governance.maturity_target); MSRC="governance.maturity_target"
if [ "$(rank "$MATURITY")" -eq 0 ]; then
  MATURITY=prototype
  if [ -z "$CONTRACT" ]; then MSRC="no contract"
  else
    MSRC="no maturity_target in $CNAME"; best=9
    while IFS="$TAB" read -r k v _; do
      r=$(rank "$v"); [ "$r" -gt 0 ] && [ "$r" -lt "$best" ] && { best=$r; MATURITY="$v"; MSRC="$k, the most lenient"; }
    done < <(awk -F '\t' '$1 ~ /^[a-z_-]+\.maturity_target$/' "$T/c.tsv")
  fi
fi

find_checker() {  # PLUGIN SCRIPT: prints the checker's path
  local p
  if [ -n "$PLUGINS" ]; then p="$PLUGINS/$1/scripts/$2.sh"; [ -f "$p" ] && { printf '%s' "$p"; return 0; }; return 1; fi
  p="$ROOT/../$1/scripts/$2.sh"; [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  p=$(ls -d "$ROOT"/../../"$1"/*/scripts/"$2".sh 2>/dev/null | awk -F/ '{ print $(NF - 2) "\t" $0 }' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-) || true
  [ -n "$p" ] && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  return 1
}

# --- the AI applications ------------------------------------------------------
# the contract's ai.applications; with none, when ascent-ai finds AI code, the
# repository is one application, named after the origin remote's repository or its
# folder (detect-ai.sh names it). detect-ai.sh also names
# AI code outside every declared application's root (GOV-A1)
APPROOTS=(); IMPLICIT=""; : > "$T/detect"
while IFS="$TAB" read -r n r; do [ -n "$n" ] && [ -n "$r" ] && APPROOTS+=(--app "$n=$r"); done < <(awk -F '\t' '
  $1 ~ /^ai\.applications\[[0-9]+\]\.(name|root)$/ { m = $1; sub(/^ai\.applications\[/, "", m); f = m; sub(/\].*$/, "", m); sub(/^[0-9]+\]\./, "", f); V[m, f] = $2; if (!(m in S)) { S[m] = 1; O[++n] = m } }
  END { for (i = 1; i <= n; i++) print V[O[i], "name"] "\t" V[O[i], "root"] }' "$T/c.tsv")
if DETECT=$(find_checker ascent-ai detect-ai); then
  bash "$DETECT" ${APPROOTS[@]+"${APPROOTS[@]}"} . > "$T/detect" 2>/dev/null </dev/null || : > "$T/detect"
fi
if ! chas ai.applications[ && grep -q "^app$TAB" "$T/detect"; then
  IFS="$TAB" read -r _ IMPLICIT _ < <(grep -m1 "^app$TAB" "$T/detect")
  printf 'ai.applications[0].name\t%s\t0\nai.applications[0].root\t.\t0\n' "$IMPLICIT" >> "$T/c.tsv"
fi
HAS_AI=0; chas ai.applications[ && HAS_AI=1

# --- the floor: check<TAB>name<TAB>rung, review<TAB>name<TAB>age<TAB>rung, signoff<TAB>rung
: > "$T/floor.tsv"
has_file() {  # NAME-PATTERN...: a file with one of these names, outside dependency and build folders
  local args=() p; for p in "$@"; do [ "${#args[@]}" -eq 0 ] || args+=(-o); args+=(-name "$p"); done
  [ -n "$(find . \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv -o -name target \) -prune -o -type f \( "${args[@]}" \) -print 2>/dev/null | head -1)" ]
}
adr_dir() { local d; d=$(cget decisions.dir); for d in "$d" docs/adr docs/decisions docs/architecture/decisions docs/framework/DECISIONS doc/adr; do [ -n "$d" ] && [ -d "$d" ] && { printf '%s' "${d%/}"; return 0; }; done; return 1; }
shows() {  # whether the repository shows the signal an item's plugin checks
  case "$1" in
    ascent-ux/*|ux-review) has_file '*.html' '*.jsx' '*.tsx' '*.vue' '*.svelte' ;;
    ascent-ops/*|ops-review|architecture-review) chas architecture. || chas ops. || has_file '*.tf' 'template.yaml' 'template.yml' 'cdk.json' 'compose.yaml' 'compose.yml' 'docker-compose.yml' 'docker-compose.yaml' 'Dockerfile' ;;
    ascent-quality/*|quality-review) has_file '*.test.*' '*.spec.*' '*_test.*' 'test_*.py' 'test-*.sh' ;;
    ascent-adr/*) adr_dir >/dev/null ;;
    ascent-docs/*) [ -f README.md ] || [ -d docs ] ;;
    ascent-delivery/check-acceptance) local d; d=$(cget delivery.acceptance_dir); [ -d "${d:-docs/delivery/acceptance}" ] ;;
    ascent-security/check-dependencies) has_file package.json requirements.txt pyproject.toml go.mod Cargo.toml ;;
    ascent-security/check-threat-model) local m; m=$(cget security.threat_model.path); [ -f "${m:-docs/security/THREAT-MODEL.md}" ] || chas security.endpoints || [ "$HAS_AI" -eq 1 ] ;;
    ascent-security/check-redteam) [ "$HAS_AI" -eq 1 ] ;;
    delivery/gate) [ -n "$(cget delivery.gate)" ] ;;
    ascent-ai/*|ai-review) [ "$HAS_AI" -eq 1 ] ;;
    *) return 0 ;;
  esac
}
default_tier() {  # TIER RUNG: the default floor, for what the repository shows
  local it
  case "$1" in
    L) for it in ascent-security/check-env delivery/gate; do shows "$it" && printf 'check\t%s\t%s\n' "$it" "$2"; done ;;
    B) for it in ascent-security/check-dependencies ascent-security/check-threat-model ascent-ux/check-flow-integrity ascent-docs/check-docs ascent-ai/check-ai-design; do shows "$it" && printf 'check\t%s\t%s\n' "$it" "$2"; done
       printf 'review\tsec-posture\t30\t%s\n' "$2"
       shows ux-review && printf 'review\tux-review\t60\t%s\n' "$2" ;;
    P) for it in ascent-delivery/check-acceptance ascent-ops/check-drills ascent-quality/check-test-evidence ascent-adr/check-adrs ascent-ai/check-ai-evidence ascent-ai/check-ai-runtime ascent-security/check-redteam; do shows "$it" && printf 'check\t%s\t%s\n' "$it" "$2"; done
       for it in architecture-review ops-review quality-review ai-review; do shows "$it" && printf 'review\t%s\t90\t%s\n' "$it" "$2"; done
       printf 'signoff\t%s\n' "$2" ;;
  esac
  return 0
}
S1=0
# every key of the section is one this version reads, with the kind of value it
# expects: a key that is not read would change the floor in silence
while IFS="$TAB" read -r ln why; do
  S1=1; item setup GOV-S1 fail High "$CNAME:$ln" "$why"
done < <(awk -F '\t' '
  $1 != "governance" && index($1, "governance.") != 1 { next }
  { k = $1; v = $2; why = ""; q = "\047"
    if (k == "governance") why = "is " q v q "; the section is a map of keys"
    else if (k == "governance.maturity_target") { if (v != "prototype" && v != "standard" && v != "enterprise") why = "is " q v q "; it is prototype, standard or enterprise, in lower case" }
    else if (k ~ /^governance\.environments\[[0-9]+\]$/ || k ~ /^governance\.approvers\[[0-9]+\]$/ || k == "governance.adr_dir") { }
    else if (k == "governance.review_log" || k == "governance.launch_dir" || k == "governance.ai_tier_dir") { if (v ~ /^\// || v ~ /(^|\/)\.\.(\/|$)/) why = "is " q v q "; it is a path inside the repository" }
    else if (k ~ /^governance\.waivers\[[0-9]+\]/) { }
    else if (k ~ /^governance\.floors\.[^.[]+\.checks\[[0-9]+\]$/ || k ~ /^governance\.floors\.[^.[]+\.reviews\.[^.[]+$/) { }
    else if (k ~ /^governance\.floors\.[^.[]+\.sign_off$/) { if (v != "true" && v != "false") why = "is " q v q "; write true or false" }
    else if (k == "governance.environments" || k == "governance.approvers" || k == "governance.waivers" || k ~ /^governance\.floors\.[^.[]+\.checks$/) why = "is " q v q "; it is a list ([a, b], or one item to a line)"
    else if (k ~ /^governance\.floors\.[^.[]+\.reviews/) why = "is not a map of each review and the most days it may be old ({ sec-posture: 30 })"
    else why = "is not a key this version of ascent-governance reads; a key that is not read would change the floor in silence (see references/contract-template.yml)"
    if (why != "") printf "%s\t%s %s\n", $3, k, why }' "$T/c.tsv")
if chas governance.floors.; then
  FSRC="governance.floors"
  for e in $(ckeys governance.floors); do
    case " $LADDER" in *" $e "*) ;; *) S1=1; item setup GOV-S1 fail High "$CNAME" "governance.floors has a floor for '$e', which is not on the ladder ($LADDER_TEXT); nothing would ever ask for it" ;; esac
  done
  for e in $RUNGS; do
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      if printf '%s\n' "$c" | grep -Eq '^[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$'; then printf 'check\t%s\t%s\n' "$c" "$e" >> "$T/floor.tsv"
      else S1=1; item setup GOV-S1 fail High "$CNAME" "governance.floors.$e.checks names '$c'; a check is <plugin>/<script>, for example ascent-docs/check-docs"; fi
    done < <(clist "governance.floors.$e.checks")
    for r in $(ckeys "governance.floors.$e.reviews"); do
      a=$(cget "governance.floors.$e.reviews.$r")
      if printf '%s\n' "$a" | grep -Eq '^[1-9][0-9]*$'; then printf 'review\t%s\t%s\t%s\n' "$r" "$a" "$e" >> "$T/floor.tsv"
      else S1=1; item setup GOV-S1 fail High "$CNAME" "governance.floors.$e.reviews.$r is '$a'; the most days a review may be old is a whole number above 0"; fi
    done
    [ "$(cget "governance.floors.$e.sign_off")" = true ] && printf 'signoff\t%s\n' "$e" >> "$T/floor.tsv"
  done
else
  FSRC="the default floors for $MATURITY maturity"
  i=0
  for e in $LADDER; do
    i=$((i + 1))
    case " $RUNGS" in *" $e "*) ;; *) continue ;; esac
    [ "$i" -eq 1 ] && default_tier L "$e" >> "$T/floor.tsv"
    [ "$MATURITY" = prototype ] && continue
    if [ "$NRUNGS" -ge 3 ] && [ "$i" -eq 2 ]; then default_tier B "$e" >> "$T/floor.tsv"; fi
    if [ "$i" -eq "$NRUNGS" ]; then                         # the top rung; on a short ladder it carries the middle tier too
      [ "$NRUNGS" -le 2 ] && default_tier B "$e" >> "$T/floor.tsv"
      default_tier P "$e" >> "$T/floor.tsv"
    fi
  done
fi
item setup - note - "$CNAME" "maturity $MATURITY ($MSRC); floor from $FSRC; ladder $LADDER_TEXT"
[ "$S1" -eq 0 ] && item setup GOV-S1 pass - "$CNAME" "the governance section is well formed"

# --- the checks -------------------------------------------------------------
TOPRUNG=$(printf '%s' "$LADDER" | awk '{ print $NF }')
adapt() {  # CHECK [ITEM]: fills ARGS, INPUTS, EACH_DIR, UNSET, NITEMS and ADAPT_ERR from the adapter table; 1 when the check has no row
  ARGS=(); INPUTS=(); EACH_DIR=""; UNSET=""; NITEMS=""; ADAPT_ERR=0; local tag a b f found=1
  while IFS="$TAB" read -r tag a b; do
    case "$tag" in
      K) found=0 ;;
      F) ARGS+=("$a") ;;
      P) INPUTS+=("$a") ;;
      X) for f in $b; do [ -f "$f" ] && ARGS+=("$a" "$f"); done ;;
      D) EACH_DIR="${a%/}" ;;
      U) UNSET="$a" ;;
      I) NITEMS="$a" ;;
      E) ADAPT_ERR=1; item check GOV-S2 fail Medium "$1" "$a" ;;
    esac
  done < <(awk -F '\t' -v check="$1" -v item="${2:-}" -v envname="$ENVNAME" -v toprung="$TOPRUNG" -v today="$TODAY" -v nogit="$NOGIT" -f "$LIB/adapt.awk" "$T/c.tsv" "$LIB/adapters.tsv")
  return $found
}
LAUNCH_DIR=$(cget governance.launch_dir); LAUNCH_DIR="${LAUNCH_DIR:-docs/governance/launches/}"; LAUNCH_DIR="${LAUNCH_DIR%/}"; LAUNCH_DIR="${LAUNCH_DIR#./}"
REVIEW_LOG=$(cget governance.review_log); REVIEW_LOG="${REVIEW_LOG:-docs/governance/review-log.md}"; REVIEW_LOG="${REVIEW_LOG#./}"
in_git() { [ "$NOGIT" -eq 0 ] && command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
# paths that are not governance records: not under the launch folder, not the review log
not_records() { awk -v ld="$LAUNCH_DIR/" -v log_="$REVIEW_LOG" 'NF && index($0, ld) != 1 && $0 != log_'; }

# --html: one page, written anywhere but the launch folder (a page there would
# sit beside the records and is not one), and never over a file that is not a
# page this script wrote. With --from it is the page of a launch record, and no
# check is run.
MARK="generated by ascent-governance check-audit.sh"
lexical() {  # PATH: absolute, with "." and ".." resolved by name
  local p="$1"; case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  printf '%s\n' "$p" | awk -F/ '{ n = 0; for (i = 1; i <= NF; i++) { if ($i == "" || $i == ".") continue; if ($i == "..") { if (n > 0) n--; continue } P[++n] = $i }
    s = ""; for (i = 1; i <= n; i++) s = s "/" P[i]; print s }'
}
physical() { (cd "$1" 2>/dev/null && pwd -P) || true; }
page() {  # MARKDOWN-FILE: writes it to $HTML as one page
  mkdir -p "$(dirname "$HTML")" || bad "--html $HTML: its folder could not be made"
  awk -f "$LIB/md-html.awk" "$1" > "$T/page.html" && cat "$T/page.html" > "$HTML" || bad "--html $HTML could not be written"
}
[ -z "$FROM" ] || [ -n "$HTML" ] || bad "--from RECORD is used with --html FILE"
if [ -n "$HTML" ]; then
  inld="--html $HTML is in the launch folder ($LAUNCH_DIR/), which holds only launch records; write the page somewhere else"
  # by name, whatever the case of the letters: on a volume that ignores case it is one folder
  hp=$(lexical "$HTML" | tr 'A-Z' 'a-z'); lp=$(lexical "$LAUNCH_DIR" | tr 'A-Z' 'a-z')
  case "$hp" in "$lp"/*) bad "$inld" ;; esac
  [ ! -L "$HTML" ] || bad "--html $HTML is a link; the page is written to a file of its own, never through a link"
  # by what the folders are: the nearest folder that exists, and every folder above it, is not the launch folder
  hd=$(dirname "$HTML"); while [ ! -d "$hd" ] && [ "$hd" != / ] && [ "$hd" != . ]; do hd=$(dirname "$hd"); done
  hd=$(physical "$hd")
  while [ -n "$hd" ] && [ -d "$LAUNCH_DIR" ]; do
    if [ "$hd" -ef "$LAUNCH_DIR" ]; then bad "$inld"; fi
    if [ "$hd" = / ]; then break; fi
    hd=$(dirname "$hd")
  done
  # a page this script wrote has its mark on the second line; a file that only quotes the mark is not one
  if [ -e "$HTML" ] && ! sed -n '2p' "$HTML" 2>/dev/null | grep -qF -- "$MARK"; then bad "--html $HTML exists and was not written by this script; it is not overwritten"; fi
  if [ -n "$FROM" ]; then
    [ -f "$FROM" ] || bad "--from $FROM not found"
    head -1 "$FROM" | grep -q '^# Launch record: ' || bad "--from $FROM is not a launch record (its first line is not '# Launch record: ...')"
    page "$FROM"
    echo "check-audit: wrote $HTML from $FROM"
    exit 0
  fi
fi

# --record: the record names a commit, so it is written only for that commit
HEAD_COMMIT=""
if [ -n "$RECORD" ]; then
  want="$LAUNCH_DIR/$TODAY-$ENVNAME.md"
  rp=$(lexical "$RECORD")                                    # "//" and ".." are resolved by name
  if [ "$rp" != "$(lexical "$want")" ]; then
    { [ "${rp##*/}" = "$TODAY-$ENVNAME.md" ] && [ -d "$LAUNCH_DIR" ] && [ "$(dirname "$rp")" -ef "$LAUNCH_DIR" ]; } || RECORD=""
  fi
  [ -n "$RECORD" ] || bad "--record $RECORD_ARG: a launch record of $ENVNAME made today is $want (governance.launch_dir, the date, the environment)"
  RECORD="$want"
  [ ! -e "$RECORD" ] || bad "--record $RECORD exists; a launch record is never overwritten. Remove it yourself if it is an unsigned draft you no longer want"
  in_git || bad "--record needs git: the record names the commit it describes"
  HEAD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null) || bad "--record needs a commit: this repository has none yet"
  { git -c core.quotepath=off diff --no-renames --name-only --relative HEAD -- . 2>/dev/null; git -c core.quotepath=off ls-files --others --exclude-standard -- . 2>/dev/null; } | not_records > "$T/dirty"
  if [ -s "$T/dirty" ]; then
    bad "--record: the working copy differs from commit $HEAD_COMMIT ($(head -3 "$T/dirty" | tr '\n' ' ' | sed 's/ $//')$([ "$(wc -l < "$T/dirty" | tr -d ' ')" -le 3 ] || echo ' and more')); commit or put aside those changes first, so the record describes the commit it names"
  fi
fi
launch_fields() {  # RECORD: prints verdict<TAB>signer<TAB>date, "-" for one that is empty
  awk 'function val(s) { sub(/^\*\*[A-Za-z]+:\*\*[ \t]*/, "", s); sub(/[ \t\r]+$/, "", s); return (s == "" ? "-" : s) }
    /^\*\*Verdict:\*\*/ { v = val($0) } /^\*\*Signed:\*\*/ { s = val($0) } /^\*\*Date:\*\*/ { d = val($0) }
    END { named = 0   # a name has a letter: a line of underscores is a blank nobody filled in (bytes above ASCII are letters of other alphabets)
          for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c ~ /[A-Za-z]/ || c > "~") named = 1 }
          printf "%s\t%s\t%s\n", (v == "" ? "-" : v), (named ? s : "-"), (d == "" ? "-" : d) }' "$1"
}
signed() {  # RECORD: whether a person signed it: a name, a real date not after today, and a verdict that is not NO-GO
  local v s d; IFS="$TAB" read -r v s d < <(launch_fields "$1")
  [ "$s" != - ] && { [ "$v" = GO ] || [ "$v" = "GO WITH CONDITIONS" ]; } && realdate "$d" && [ ! "$d" \> "$TODAY" ] && SIGNED_ON="$d"
}
record_commit() { awk 'NR <= 6 && match($0, / commit [0-9a-f]+/) { print substr($0, RSTART + 8, RLENGTH - 8); exit }' "$1"; }
# the launch records of this environment, oldest first. A file whose name is
# not a real date, or is dated after today, is not a record yet: it would be
# "the newest" for as long as its name says, and hide every record after it
: > "$T/records"
for f in "$LAUNCH_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$ENVNAME".md; do
  [ -f "$f" ] || continue
  d="${f##*/}"; d="${d:0:10}"
  if ! realdate "$d"; then item launch - note - "$f" "$f is not read: its name is not a real date"; continue; fi
  if [ "$d" \> "$TODAY" ]; then item launch - note - "$f" "$f is not read: its name is dated after today ($TODAY)"; continue; fi
  printf '%s\n' "$f" >> "$T/records"
done
# the newest signed launch record of this environment, and the commit it names when git has it
SIGNED_REC=""; SIGNED_COMMIT=""
while IFS= read -r f; do
  if signed "$f"; then SIGNED_REC="$f"; fi
done < "$T/records"
if [ -n "$SIGNED_REC" ] && in_git; then
  SIGNED_COMMIT=$(record_commit "$SIGNED_REC")
  [ -n "$SIGNED_COMMIT" ] && git cat-file -e "$SIGNED_COMMIT^{commit}" 2>/dev/null || SIGNED_COMMIT=""
fi
last_launch() {  # prints the date of the newest signed launch record of this environment, if any
  local f best=""
  while IFS= read -r f; do
    if signed "$f" && [ "$SIGNED_ON" \> "$best" ]; then best="$SIGNED_ON"; fi
  done < "$T/records"
  printf '%s' "$best"
}
# the checker's findings, the most severe first: up to three, then how many more
fails_of() {
  awk '/^FAIL / { sub(/^FAIL  */, ""); gsub(/   */, " "); n++; L[n] = substr($0, 1, 160); R[n] = ($2 == "Medium" ? 2 : ($2 == "Low" ? 3 : 1)) }
    END { for (r = 1; r <= 3; r++) for (i = 1; i <= n; i++) if (R[i] == r && k < 3) { printf "%s%s", (k ? "; " : ""), L[i]; k++ }
          if (n > 3) printf " (and %d more)", n - 3 }' "$1"
}
# the severity of a check that failed: its most severe finding; High when it printed
# none, or one whose severity is not High, Medium or Low (ADR-029)
sev_of() {
  awk '/^FAIL / { n++; if ($3 == "High") h = 1; else if ($3 == "Medium") m = 1; else if ($3 != "Low") h = 1 }
    END { print (h || n == 0 ? "High" : (m ? "Medium" : "Low")) }' "$1"
}
worse() {  # NEW OLD: whether NEW is more severe than OLD (an empty OLD is no failure yet)
  case "$1:$2" in *:|High:Medium|High:Low|Medium:Low) return 0 ;; *) return 1 ;; esac
}
# whether an exit 2 is the checker's own usage error: its first line is its own
# message, NAME: or Usage: NAME.sh; awk and bash also exit 2 when they fail (ADR-030)
own_usage() {  # OUT NAME
  local first=""
  IFS= read -r first < "$1" || :
  case "$first" in "$2: "*|"Usage: $2.sh"*) return 0 ;; *) return 1 ;; esac
}
run_each() {  # CHECK CHECKER: the checker once for each dated record since the last signed launch
  local c="$1" f b n=0 all=0 rc since why="" failed="" fsev="" sev unread="" name="${2##*/}"
  name="${name%.sh}"
  since=$(last_launch)
  for f in "$EACH_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md; do
    [ -f "$f" ] || continue
    all=$((all + 1))
    b="${f##*/}"; [ -n "$since" ] && [ "${b:0:10}" \< "$since" ] && continue
    n=$((n + 1)); rc=0
    bash "$2" ${ARGS[@]+"${ARGS[@]}"} "$f" > "$T/run.out" 2>&1 </dev/null || rc=$?
    case "$rc" in
      0) ;;
      # the most severe finding across the records, cited from the first record that has it
      1) sev=$(sev_of "$T/run.out"); if worse "$sev" "$fsev"; then failed="$f: $(fails_of "$T/run.out")"; fsev=$sev; fi ;;
      2) if own_usage "$T/run.out" "$name"; then [ -n "$unread" ] || unread="$f: $(head -1 "$T/run.out" | cut -c1-120)"
         elif worse High "$fsev"; then failed="$f: its checker exited 2 without finishing"; fsev=High; fi ;;
      *) if worse High "$fsev"; then failed="$f: its checker exited $rc without finishing"; fsev=High; fi ;;
    esac
  done
  [ -n "$since" ] && why=" since the launch signed on $since"
  if [ "$all" -eq 0 ]; then item check GOV-L2 unmeasured Low "$c" "$c is unmeasured: no acceptance record in $EACH_DIR/"
  elif [ "$n" -eq 0 ]; then item check GOV-L1 na - "$c" "$c: no acceptance record$why"
  elif [ -z "$failed$unread" ]; then item check GOV-L1 pass - "$c" "$c passes ($n record$([ "$n" -eq 1 ] || echo s)$why)"
  else   # one record that cannot be read never hides another that fails
    [ -z "$failed" ] || item check GOV-L1 fail "$fsev" "$c" "$c failed: $failed"
    [ -z "$unread" ] || item check GOV-S2 fail Medium "$c" "$c could not be run: its checker exited with a usage error ($unread); fix the record or the contract value it names, or the adapter"
  fi
}
run_check() {  # CHECK
  local c="$1" plugin="${1%/*}" script="${1#*/}" rc=0 path cmd
  case "$SKIP" in *" $c "*) item check - note - "$c" "$c was skipped (--skip)"; return 0 ;; esac
  if [ "$c" = delivery/gate ]; then
    cmd=$(cget delivery.gate)
    [ -n "$cmd" ] || { item check GOV-L2 unmeasured Low "$c" "$c is unmeasured: the contract has no delivery.gate"; return 0; }
    # a gate that asks this question itself would run the gate again, without end
    [ -z "${ASCENT_GOVERNANCE_GATE:-}" ] || { item check GOV-L1 na - "$c" "$c is not run again: this check is running inside the gate"; return 0; }
    ASCENT_GOVERNANCE_GATE=1 sh -c "$cmd" > "$T/run.out" 2>&1 </dev/null || rc=$?
    if [ "$rc" -eq 0 ]; then item check GOV-L1 pass - "$c" "$c passes ($cmd)"
    else item check GOV-L1 fail High "$c" "$c failed: $cmd exited $rc"; fi
    return 0
  fi
  adapt "$c" || { item check GOV-S2 fail Medium "$c" "$c has no adapter in this version of ascent-governance, so it was not run; see lib/adapters.tsv for the checks it can run"; return 0; }
  path=$(find_checker "$plugin" "$script") || { item check GOV-L2 unmeasured Low "$c" "$c is unmeasured: $plugin is not available here"; return 0; }
  [ -z "$UNSET" ] || { item check GOV-L2 unmeasured Low "$c" "$c is unmeasured: the contract has no $UNSET, so which files are the pages is not known; set $UNSET to where they are (for example [\"src/**\"])"; return 0; }
  if [ -n "$EACH_DIR" ]; then run_each "$c" "$path"; return 0; fi
  if [ -n "$NITEMS" ]; then run_items "$c" "$path" "$script"; return 0; fi
  bash "$path" ${ARGS[@]+"${ARGS[@]}"} ${INPUTS[@]+"${INPUTS[@]}"} > "$T/run.out" 2>&1 </dev/null || rc=$?
  judge "$c" "$c" "$rc" "$script"
}
judge() {  # CHECK LABEL RC SCRIPT: one result from the checker's exit code and $T/run.out
  local c="$1" l="$2" rc="$3" script="$4" na
  case "$rc" in
    0) na=$(awk '/^N\/A / && !($2 in S) { S[$2] = 1; printf "%s%s", (n++ ? ", " : ""), $2 }' "$T/run.out")   # N/A is never a pass
       if [ -n "$na" ] && ! grep -q '^PASS ' "$T/run.out"; then item check GOV-L2 unmeasured Low "$c" "$l is unmeasured: it had nothing it could check here ($na)"
       elif [ -n "$na" ]; then item check GOV-L1 pass - "$c" "$l passes (not checked here: $na)"
       else item check GOV-L1 pass - "$c" "$l passes"; fi ;;
    1) item check GOV-L1 fail "$(sev_of "$T/run.out")" "$c" "$l failed: $(fails_of "$T/run.out")" ;;
    2) if own_usage "$T/run.out" "$script"; then item check GOV-S2 fail Medium "$c" "$l could not be run: its checker exited with a usage error ($(head -1 "$T/run.out" | cut -c1-120)); fix the contract value it names, or the adapter"
       else item check GOV-L1 fail High "$c" "$l failed: its checker exited 2 without finishing ($(head -1 "$T/run.out" | cut -c1-120))"; fi ;;
    *) item check GOV-L1 fail High "$c" "$l failed: its checker exited $rc without finishing ($(head -1 "$T/run.out" | cut -c1-120))" ;;
  esac
}
run_items() {  # CHECK CHECKER SCRIPT: the checker once for each AI application, each judged on its own
  local c="$1" m=0 rc n total="$NITEMS"   # adapt, run for one item, clears NITEMS
  [ "$total" -gt 0 ] || { item check GOV-L2 unmeasured Low "$c" "$c is unmeasured: the contract declares no AI application (ai.applications)"; return 0; }
  while [ "$m" -lt "$total" ]; do
    n=$(cget "ai.applications[$m].name"); n="${n:-item $((m + 1))}"
    adapt "$c" "$m" || :
    if [ "$ADAPT_ERR" -eq 0 ]; then
      rc=0; bash "$2" ${ARGS[@]+"${ARGS[@]}"} ${INPUTS[@]+"${INPUTS[@]}"} > "$T/run.out" 2>&1 </dev/null || rc=$?
      judge "$c" "$c [$n]" "$rc" "$3"
    fi
    m=$((m + 1))
  done
}
: > "$T/seen"
while IFS="$TAB" read -r kind name rung rest; do
  [ "$kind" = check ] || continue
  grep -qxF -- "$name" "$T/seen" && continue
  echo "$name" >> "$T/seen"
  run_check "$name"
done < "$T/floor.tsv"

# --- the AI risk-tier records (GOV-A) -----------------------------------------
# on every rung above the lowest (the only rung of a one-rung ladder), whatever the floors say
AI_TIER_DIR=$(cget governance.ai_tier_dir); AI_TIER_DIR="${AI_TIER_DIR:-docs/governance/ai-tier/}"; AI_TIER_DIR="${AI_TIER_DIR#./}"
awk -F '\t' '$1 ~ /^ai\.applications\[[0-9]+\]\.name$/ { print $2 "\t" $3 }' "$T/c.tsv" | while IFS="$TAB" read -r n ln; do
  if [ -n "$IMPLICIT" ]; then printf '%s\tthe repository (ascent-ai found AI code; ai.applications declares none)\n' "$n"; else printf '%s\t%s:%s\n' "$n" "$CNAME" "$ln"; fi
done > "$T/apps.tsv"
case "$AI_TIER_DIR" in /*|..|../*|*/..|*/../*) : > "$T/apps.tsv" ;; esac   # GOV-S1 reports it; no record is read from outside the repository
if [ -s "$T/apps.tsv" ] && { [ "$ENVNAME" != "${LADDER%% *}" ] || [ "$NRUNGS" -eq 1 ]; }; then
  awk -F '\t' -v today="$TODAY" -v dir="$AI_TIER_DIR" -v cname="${CNAME:-the contract}" -f "$LIB/ai-tier.awk" "$T/c.tsv" "$T/apps.tsv" >> "$T/items.tsv"
fi
# AI code under no declared application's root belongs to no application: no record, no checks
awk -F '\t' '$1 == "orphan" { print $2 }' "$T/detect" | LC_ALL=C sort -u > "$T/orphans"
if [ -s "$T/orphans" ] && { [ "$ENVNAME" != "${LADDER%% *}" ] || [ "$NRUNGS" -eq 1 ]; }; then
  no=$(wc -l < "$T/orphans" | tr -d ' ')
  item launch GOV-A1 fail High "$(head -1 "$T/orphans")" "AI code outside every application ai.applications declares: $(head -3 "$T/orphans" | tr '\n' ' ' | sed 's/ $//; s/ /, /g')$([ "$no" -le 3 ] || echo " (and $((no - 3)) more)"); it would ship with no tier record and no AI checks. Put it under an application's root, or declare it as an application with its own tier record"
fi

# --- sign-off -----------------------------------------------------------------
# A rung with sign_off, or above one, needs the newest launch record of the
# environment asked about signed by a person. --launch asks before that: the
# answer comes first, the signature after.
if grep -q "^signoff$TAB" "$T/floor.tsv"; then
  if [ "$LAUNCH" -eq 1 ]; then
    item launch - note - "$LAUNCH_DIR" "sign-off: awaiting signature (a person signs the launch record; --launch gives the answer they sign)"
  else
    NEWEST=$(tail -1 "$T/records")
    if [ -z "$NEWEST" ]; then
      item launch GOV-L3 fail High "$LAUNCH_DIR" "no launch record for $ENVNAME ($LAUNCH_DIR/<date>-$ENVNAME.md): ask launch-readiness for one, or run check-audit.sh --env $ENVNAME --record $LAUNCH_DIR/$TODAY-$ENVNAME.md, then a person signs it"
    else
      IFS="$TAB" read -r lv ls ld < <(launch_fields "$NEWEST"); why=""
      if [ "$lv" = - ]; then why="it has no verdict (**Verdict:**)"
      elif [ "$lv" = NO-GO ]; then why="its verdict is NO-GO; a NO-GO is not launched, signed or not"
      elif [ "$lv" != GO ] && [ "$lv" != "GO WITH CONDITIONS" ]; then why="its verdict '$lv' is not GO or GO WITH CONDITIONS"
      elif [ "$ls" = - ]; then why="it is not signed: no name after Signed:"
      elif [ "$ld" = - ]; then why="it has no date after Date:"
      elif ! realdate "$ld"; then why="its date '$ld' is not a real date (YYYY-MM-DD)"
      elif [ "$ld" \> "$TODAY" ]; then why="its date $ld is after today ($TODAY)"
      fi
      if [ -n "$why" ]; then item launch GOV-L3 fail High "$NEWEST" "the newest launch record for $ENVNAME does not count: $why. Only a person signs"
      else
        item launch GOV-L3 pass - "$NEWEST" "$NEWEST is signed by $ls on $ld (verdict $lv)"
        # GOV-L4: an approver, when the contract lists approvers
        if [ -z "$(clist governance.approvers)" ]; then item launch GOV-L4 na - "$CNAME" "governance.approvers is empty, so any person's name counts"
        elif clist governance.approvers | awk -v s="$ls" 'tolower($0) == tolower(s) { f = 1 } END { exit !f }'; then item launch GOV-L4 pass - "$NEWEST" "$ls is in governance.approvers"
        else item launch GOV-L4 fail High "$NEWEST" "$ls signed $NEWEST and is not in governance.approvers ($(clist governance.approvers | tr '\n' ',' | sed 's/,$//; s/,/, /g'))"; fi
        # GOV-L5: nothing but governance records changed since the commit the record names
        lc=$(record_commit "$NEWEST")
        if [ "$NOGIT" -eq 1 ]; then item launch GOV-L5 na - "$NEWEST" "--no-git given: whether anything changed since the record's commit was not checked"
        elif [ -z "$lc" ]; then item launch GOV-L5 fail High "$NEWEST" "$NEWEST names no commit, so what was signed cannot be matched to the code"
        elif ! in_git; then item launch GOV-L5 fail High "$NEWEST" "not a git repository: whether anything changed since commit $lc cannot be checked"
        elif ! git cat-file -e "$lc^{commit}" 2>/dev/null; then
          if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then item launch GOV-L5 fail High "$NEWEST" "commit $lc is not in this shallow clone, so what changed since the signature cannot be checked: fetch the full history (fetch-depth: 0 in GitHub Actions)"
          else item launch GOV-L5 fail High "$NEWEST" "commit $lc is not in this repository, so what was signed cannot be matched to the code"; fi
        else
          # --no-renames: a file moved into the launch folder is a change to the file it was
          git -c core.quotepath=off diff --no-renames --name-only --relative "$lc" HEAD -- . 2>/dev/null | not_records > "$T/changed"
          if [ -s "$T/changed" ]; then
            nc=$(wc -l < "$T/changed" | tr -d ' ')
            item launch GOV-L5 fail High "$NEWEST" "$nc path(s) changed since commit $lc, which is what $ls signed: $(head -3 "$T/changed" | tr '\n' ',' | sed 's/,$//; s/,/, /g')$([ "$nc" -le 3 ] || echo " (and $((nc - 3)) more)"). A change needs a new launch record and a new signature"
          else item launch GOV-L5 pass - "$NEWEST" "nothing but governance records changed since commit $lc"; fi
        fi
      fi
    fi
  fi
fi

# --- waivers ------------------------------------------------------------------
# One row per decision record of a folder: folder, number, 1 when its status is
# Accepted, file. The status is the first line that starts with "Status" (after
# any Markdown marks), or the line under a "Status" heading.
scan_adrs() {  # DIR
  local d="${1%/}" f
  [ -d "$d" ] || return 0
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    awk -v dir="$d" -v file="$f" '
      function judge(v) { v = tolower(v); sub(/^[ \t>*_#-]+/, "", v); acc = (v ~ /^accepted/) ? 1 : 0; done = 1 }
      BEGIN { b = file; sub(/^.*\//, "", b)
        if (b ~ /^[Aa][Dd][Rr]-[0-9]/) sub(/^[A-Za-z]+-/, "", b); else if (b !~ /^[0-9]/) exit
        sub(/[^0-9].*$/, "", b); num = b + 0; ok = 1 }
      done { next }
      pend { if ($0 !~ /^[ \t\r]*$/) judge($0); next }
      { l = tolower($0); sub(/^[ \t>*_#-]+/, "", l)
        if (l ~ /^status/) { l = substr(l, 7); sub(/^[*_: \t]+/, "", l); sub(/[ \t\r]+$/, "", l); if (l == "") pend = 1; else judge(l) } }
      END { if (ok) printf "%s\t%d\t%d\t%s\n", dir, num, acc, file }' "$f" >> "$T/adrs.tsv"
  done
}
: > "$T/adrs.tsv"
ADR_FALLBACK=$(cget decisions.dir); [ -n "$ADR_FALLBACK" ] || ADR_FALLBACK=$(adr_dir || true)
{ awk -F '\t' '$1 ~ /^[A-Za-z_-]+\.adr_dir$/ && $2 != "" { print $2 }' "$T/c.tsv"; printf '%s\n' "$ADR_FALLBACK"; } | sed 's|/*$||' | awk 'NF && !seen[$0]++' > "$T/adr-dirs"
while IFS= read -r d; do scan_adrs "$d"; done < "$T/adr-dirs"

# --- the review log -----------------------------------------------------------
: > "$T/logrows.tsv"; HASLOG=0
if [ -f "$REVIEW_LOG" ]; then HASLOG=1; awk -f "$LIB/log-rows.awk" "$REVIEW_LOG" > "$T/logrows.tsv"; fi
awk -F '\t' -v today="$TODAY" -v cname="${CNAME:-the contract}" -v fallback="$ADR_FALLBACK" -v launch="$LAUNCH" -v logname="$REVIEW_LOG" -v haslog="$HASLOG" \
  -f "$LIB/audit.awk" "$T/c.tsv" "$T/adrs.tsv" "$T/floor.tsv" "$T/logrows.tsv" >> "$T/items.tsv"

# GOV-R4: rows are only added. Every row of each version in the history must be in
# each version made from it (on any branch), and in the working copy, whatever
# its spacing. A lost row is reported once.
if grep -q "^review$TAB" "$T/floor.tsv"; then
  R4NA=""
  if [ "$HASLOG" -eq 0 ]; then R4NA="no review log at $REVIEW_LOG"
  elif [ "$NOGIT" -eq 1 ]; then R4NA="--no-git given"
  elif ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then R4NA="not a git repository"
  elif ! git ls-files --error-unmatch -- "$REVIEW_LOG" >/dev/null 2>&1; then R4NA="the review log is not tracked by git yet"
  elif [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then R4NA="a shallow clone: the history is incomplete; fetch it with git fetch --unshallow (fetch-depth: 0 in GitHub Actions)"
  fi
  if [ -n "$R4NA" ]; then item setup GOV-R4 na - "$REVIEW_LOG" "$R4NA: whether rows of the review log were removed or changed was not checked"
  else
    rows_of() { git show "$1:./$REVIEW_LOG" 2>/dev/null | awk -f "$LIB/log-rows.awk" | awk -F '\t' '$1 == "R"' | cut -f4- | sort -u; }
    # a signed launch accepts the log as it was at its commit: the history is read from there
    RANGE=HEAD; R4SINCE=""
    [ -z "$SIGNED_COMMIT" ] || { RANGE="$SIGNED_COMMIT..HEAD"; R4SINCE=" since the launch record $SIGNED_REC (commit $SIGNED_COMMIT)"; }
    git log --parents --format='%h %p' "$RANGE" -- "$REVIEW_LOG" > "$T/revs" 2>/dev/null || : > "$T/revs"
    : > "$T/lost"
    while read -r c ps; do
      for p in $ps; do
        rows_of "$p" > "$T/prev"; rows_of "$c" > "$T/cur"
        comm -23 "$T/prev" "$T/cur" | while IFS= read -r e; do printf '%s\t%s\n' "$c" "$e"; done >> "$T/lost"
      done
    done < "$T/revs"
    if git cat-file -e "HEAD:./$REVIEW_LOG" 2>/dev/null; then  # the working copy against HEAD's version
      rows_of HEAD > "$T/prev"; awk -F '\t' '$1 == "R"' "$T/logrows.tsv" | cut -f4- | sort -u > "$T/cur"
      comm -23 "$T/prev" "$T/cur" | while IFS= read -r e; do printf 'the working copy\t%s\n' "$e"; done >> "$T/lost"
    fi
    awk -F '\t' '{ k = $0; sub(/^[^\t]*\t/, "", k) } !seen[k]++' "$T/lost" > "$T/lost1"
    if [ -s "$T/lost1" ]; then
      while IFS="$TAB" read -r c d name rest; do
        item review GOV-R4 fail Medium "$REVIEW_LOG" "a row of the review log was removed or changed in $c: $name of $d; rows are only added, so a review that was recorded stays on record"
      done < <(head -5 "$T/lost1")
      n=$(wc -l < "$T/lost1" | tr -d ' '); [ "$n" -le 5 ] || item review GOV-R4 fail Medium "$REVIEW_LOG" "$((n - 5)) more row(s) of the review log were removed or changed"
    else item setup GOV-R4 pass - "$REVIEW_LOG" "no row of the review log was removed or changed in its history$R4SINCE ($(wc -l < "$T/revs" | tr -d ' ') version(s))"; fi
  fi
fi

# --- the launch record --------------------------------------------------------
VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -1)
markdown() {  # SIGN COMMIT: the result as the launch record's Markdown
  awk -F '\t' -v fmt=md -v sign="$1" -v project="$(basename "$PWD")" -v env="$ENVNAME" -v date="$TODAY" -v commit="$2" \
    -v maturity="$MATURITY" -v msrc="$MSRC" -v version="${VERSION:-unknown}" -f "$LIB/render.awk" "$T/items.tsv"
}
NOW_COMMIT="$HEAD_COMMIT"
[ -n "$NOW_COMMIT" ] || NOW_COMMIT=$(git rev-parse --short HEAD 2>/dev/null) || NOW_COMMIT=unknown
if [ -n "$RECORD" ]; then mkdir -p "$(dirname "$RECORD")"; markdown 1 "$HEAD_COMMIT" > "$RECORD"; fi
# the same result as a page, and as the CI job's summary when there is one
if [ -n "$HTML" ]; then markdown 0 "$NOW_COMMIT" > "$T/run.md"; page "$T/run.md"; fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { { markdown 0 "$NOW_COMMIT"; echo; } >> "$GITHUB_STEP_SUMMARY"; } 2>/dev/null || echo "check-audit: could not write the job summary to $GITHUB_STEP_SUMMARY" >&2
fi
[ -z "$RECORD" ] || item launch - note - "$RECORD" "wrote $RECORD: it is unsigned. A person adds their name and the date after Signed: and Date:, and commits it"
[ -z "$HTML" ] || item launch - note - "$HTML" "wrote $HTML: a page of this result; it is generated, never edited"

finish
