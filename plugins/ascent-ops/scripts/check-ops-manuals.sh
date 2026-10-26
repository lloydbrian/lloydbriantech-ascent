#!/usr/bin/env bash
# Checks for the Maintenance and Operations Manual and the Troubleshooting Manual:
# structure, diagrams, dependency map and whether they are current. Part of the
# ascent-ops plugin (ops-review Step 3, ops-manuals Steps 2 and 5). Read-only.
#
# Usage: check-ops-manuals.sh [--repo DIR] [--today YYYY-MM-DD] [--max-age DAYS] MO-MANUAL TS-MANUAL [IAC-PATH...]
#
# MO-MANUAL and TS-MANUAL are the two manuals (ops.manuals in the contract). IAC-PATH
# is a file or directory holding Compose files, CloudFormation YAML or Terraform;
# their services must appear in the diagrams. --repo is the git repository the
# manuals describe: source changes are read with git log (read-only). --today
# fixes the date for tests; --max-age defaults to 90 days.
#
# Checks (severity from the ops-review severity table):
#   M1  Medium  each manual exists and has front matter: as_of (YYYY-MM-DD), describes
#               (the version or commit it describes) and a non-empty sources list
#   M2  Medium  each manual has its required sections (MO: overview, architecture,
#               dependency map, environments, configuration and secrets, deploy,
#               rollback, backup and restore, scheduled maintenance, upgrades, access,
#               escalation and contacts, change history; TS: symptoms, diagnostic
#               commands, known issues, escalation)
#   M3  Medium  the MO manual has Mermaid diagrams at the three C4 levels: system
#               context, containers and deployment
#   M4  Medium  every service in the IaC and Compose files appears in a diagram; N/A
#               when there is no IaC or Compose to map (then read the diagrams
#               against the system)
#   M5  Low     the dependency map is a table with a version column and at least one row
#   M6  Medium  each manual is current: as_of no older than --max-age days, every
#               source still exists, and no source changed since the commit it
#               describes
#   M7  Medium  the TS manual has a symptom table (symptom, where to look, likely cause,
#               fix or escalation) with at least one row
#   M8  High    no credential-like value in either manual (the value is never printed)
#
# Output: FAIL lines (FAIL  Mk  SEVERITY  file:line  message), a PASS line per check
# with no finding, N/A when a check found nothing to check, NOTE lines (unrated) when
# source changes could not be checked, then "check-ops-manuals: ...".
# Limits: headings are matched by keyword; a service counts as drawn when its name
# appears in a Mermaid block (case and punctuation ignored; generic names such as
# "this" or "main" are matched by their resource kind).
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
REPO=""; TODAY=""; MAXAGE=90
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || { usage >&2; exit 2; }; REPO="$2"; shift 2 ;;
    --today) [ $# -ge 2 ] || { usage >&2; exit 2; }; TODAY="$2"; shift 2 ;;
    --max-age) [ $# -ge 2 ] || { usage >&2; exit 2; }; MAXAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-ops-manuals: unknown option $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -ge 2 ] || { usage >&2; exit 2; }
MO="${POS[0]}"; TS="${POS[1]}"
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) echo "check-ops-manuals: --today must be YYYY-MM-DD" >&2; exit 2 ;; esac
case "$MAXAGE" in ''|*[!0-9]*) echo "check-ops-manuals: --max-age must be a number of days" >&2; exit 2 ;; esac
if [ -n "$REPO" ] && [ ! -d "$REPO" ]; then echo "check-ops-manuals: --repo is not a directory: $REPO" >&2; exit 2; fi
for m in "$MO" "$TS"; do [ ! -e "$m" ] || [ -f "$m" ] || { echo "check-ops-manuals: not a file: $m" >&2; exit 2; }; done

dot() { case "$1" in /*|./*) printf '%s' "$1" ;; *) printf './%s' "$1" ;; esac; }
ARGS=()
[ -f "$MO" ] && ARGS+=("K=mo" "$(dot "$MO")")
[ -f "$TS" ] && ARGS+=("K=ts" "$(dot "$TS")")
NIAC=0
for p in "${POS[@]:2}"; do
  if [ -d "$p" ]; then
    LIST=$(find "$p" \( -name node_modules -o -name .git -o -name .terraform -o -name vendor -o -name dist -o -name build \) -prune -o -type f -print 2>/dev/null | LC_ALL=C sort || true)
  elif [ -f "$p" ]; then LIST="$p"
  else echo "check-ops-manuals: no such file or directory: $p" >&2; exit 2; fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lb=$(basename "$f" | tr 'A-Z' 'a-z')
    case "$lb" in
      docker-compose*.yml|docker-compose*.yaml|compose*.yml|compose*.yaml|podman-compose*.yml|podman-compose*.yaml) ARGS+=("K=compose" "$(dot "$f")"); NIAC=$((NIAC + 1)) ;;
      *.tf) ARGS+=("K=tf" "$(dot "$f")"); NIAC=$((NIAC + 1)) ;;
      *.yml|*.yaml|*.template)
        if grep -q '^Resources:' "$f" 2>/dev/null && grep -Eq 'Type:[ ]*["'"'"']?AWS::' "$f" 2>/dev/null; then ARGS+=("K=cfn" "$(dot "$f")"); NIAC=$((NIAC + 1)); fi ;;
    esac
  done <<EOF_LIST
$LIST
EOF_LIST
done

# Front matter, read here so source changes can be checked with git (read-only).
# A trailing " # comment" on a front-matter line is dropped, as YAML does.
fm() { awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { sub(/[ \t]+#.*$/, ""); print }' "$1" | tr -d '\r'; }
sources() {  # front matter on stdin -> one source per line
  awk '/^sources:[ ]*\[/ { s = $0; sub(/^sources:[ ]*\[/, "", s); sub(/\].*/, "", s); n = split(s, a, ","); for (i = 1; i <= n; i++) { gsub(/^[ "'"'"']+|[ "'"'"']+$/, "", a[i]); if (a[i] != "") print a[i] }; exit }
       /^sources:[ ]*$/ { on = 1; next }
       on && /^[ ]+-[ ]/ { s = $0; sub(/^[ ]+-[ ]+/, "", s); gsub(/^["'"'"']|["'"'"']$/, "", s); print s; next }
       on && /^[^ ]/ { exit }'
}
GITNOTE=""; GIT_MO=""; GIT_TS=""
TAB=$(printf '\t')
gitcheck() {  # MANUAL -> "<commits|NOTE><TAB><changed sources|note><TAB><missing sources>"
  local m="$1" f desc src n changed missing=""
  f=$(fm "$m"); desc=$(printf '%s\n' "$f" | sed -n 's/^describes:[ ]*//p' | head -1 | tr -d '"'"'"); src=$(printf '%s\n' "$f" | sources)
  if [ -z "$REPO" ]; then printf 'NOTE%ssource changes not checked: no --repo given%s' "$TAB" "$TAB"; return; fi
  while IFS= read -r s; do [ -n "$s" ] || continue; [ -e "$REPO/$s" ] || missing="$missing $s"; done <<EOF_SRC
$src
EOF_SRC
  if ! command -v git >/dev/null 2>&1 || ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'NOTE%ssource changes not checked: %s is not a git repository%s%s' "$TAB" "$REPO" "$TAB" "$missing"; return
  fi
  if [ -z "$desc" ] || [ -z "$src" ] || ! git -C "$REPO" rev-parse --verify --quiet "$desc^{commit}" >/dev/null 2>&1; then
    printf 'NOTE%ssource changes not checked: describes "%s" is not a commit or tag in the repository%s%s' "$TAB" "$desc" "$TAB" "$missing"; return
  fi
  # shellcheck disable=SC2086
  n=$(cd "$REPO" && git log --oneline "$desc..HEAD" -- $src 2>/dev/null | grep -c . || true)
  # shellcheck disable=SC2086
  changed=$(cd "$REPO" && git diff --name-only "$desc" HEAD -- $src 2>/dev/null | head -5 | tr '\n' ' ' || true)
  printf '%s%s%s%s%s' "$n" "$TAB" "$changed" "$TAB" "$missing"
}
[ -f "$MO" ] && GIT_MO=$(gitcheck "$MO")
[ -f "$TS" ] && GIT_TS=$(gitcheck "$TS")

PROG_FILE="$(cd "$(dirname "$0")" && pwd)/lib/check-ops-manuals.awk"
[ -f "$PROG_FILE" ] || { echo "check-ops-manuals: missing $PROG_FILE" >&2; exit 2; }

[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)
COM_TODAY="$TODAY" COM_MAXAGE="$MAXAGE" COM_GIT_MO="$GIT_MO" COM_GIT_TS="$GIT_TS" COM_MO="$MO" COM_TS="$TS" COM_NIAC="$NIAC" \
  LC_ALL=C awk -f "$PROG_FILE" "${ARGS[@]}"
