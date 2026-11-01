#!/usr/bin/env bash
# Checks recovery drills and readiness exercises against the records the operator
# writes after running them. Part of the ascent-ops plugin (recovery-drill Step 2,
# ops-review Step 3). Read-only; it never runs a drill.
#
# Usage: check-drills.sh [--repo DIR] [--today YYYY-MM-DD] [--max-age DAYS] [--maturity LEVEL] [--rto DUR] [--rpo DUR] [--ready-path PATH] [--manual MO-MANUAL] [--path NAME:KIND:RUNBOOK]... [--alert NAME:RUNBOOK[:page]]... [--iac PATH]... DRILLS-DIR
#
# DRILLS-DIR holds one record per drill, named YYYY-MM-DD-<name>.md, opening with a
# "| Field | Value |" table (references/drill-records.md); other files are ignored.
# The values come from the project contract: --path from ops.drills.paths (KIND is
# restore or failover), --alert from ops.alerts (":page" when page: true), --rto and
# --rpo from architecture.quality_targets, --ready-path from ops.ready_path,
# --manual from ops.manuals.maintenance, --max-age from ops.drills.max_age_days
# (default 90) and --maturity from ops.maturity_target (enterprise, standard or
# prototype; default enterprise). --iac is a file or directory of Compose files,
# CloudFormation YAML or Terraform, read for backups and failover. --repo is the
# root that runbook and evidence paths are relative to (default "."). --today fixes
# the date for tests. Durations are <n>d, <n>h, <n>m and <n>s, combined (1h30m).
#
# Checks (severity from the ops-review severity table):
#   OPS-R1  Medium  every recovery path names a runbook that exists; Low when the IaC
#               declares backups and no path is given (unmeasured)
#   OPS-R2  Medium  each recovery runbook has pre-flight, post-flight and rollback
#               sections and steps with Expect and Stop if
#   OPS-R3  Medium  each path has a passing record of its kind no older than
#               --max-age days; Low for a record missing path, kind, date or
#               result, with an unknown kind or result, or not dated as its name
#   OPS-R4  Medium  the newest current passing record has measured_rto <= rto and
#               measured_rpo <= rpo; N/A with no target (unmeasured)
#   OPS-R5  High    no credential-like value in a record or its evidence: key=value
#               (also before a command), key: value, JSON, a table row, a password
#               in a URL, a bearer token, an access key or a private key; Medium for
#               evidence missing, outside the repository, or holding an email
#               address or phone number. No record value that is not plain text is
#               ever printed
#   OPS-R6  Medium  a failed drill has a follow_up, or a later passing record of the
#               same path and kind
#   OPS-R7  Low     the manual's Backup and restore section dates its last restore no
#               earlier than the newest passing restore record
#   OPS-R8  Low     failover the IaC declares (Multi-AZ, Route 53 failover, global
#               tables or clusters, read replicas) has a failover path
#   OPS-X1  Low     every paging alert has a fresh passing alarm record naming the role
#               it reached
#   OPS-X2  Low     a fresh passing readiness record shows --ready-path answering a
#               non-2xx status with a dependency down
#   OPS-X3  Low     every runbook an alert links to has a fresh passing dry-run record
# At standard maturity only OPS-R1–R5 apply; at prototype none do. OPS-R5's
# credential check applies at every level.
#
# Output: FAIL lines (FAIL  OPS-Rk  SEVERITY  file:line  message, or "absent" for a
# missing record or runbook), a PASS line per check with no finding, N/A when a check
# found nothing to check or is not required, NOTE lines (unrated) for backups the
# paths do not name and records for unknown paths, then "check-drills: ...".
# Limits: a record shows a drill was recorded consistently, not that it was honest;
# the evidence is read for credentials and personal data, not for truth. IaC is read
# line by line for known backup and failover settings.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
REPO="."; TODAY=""; MAXAGE=90; MATURITY=enterprise; RTO=""; RPO=""; READY=""; MANUAL=""
PATHS_IN=(); ALERTS_IN=(); IAC=(); POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) need $#; REPO="$2"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --max-age) need $#; MAXAGE="$2"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --rto) need $#; RTO="$2"; shift 2 ;;
    --rpo) need $#; RPO="$2"; shift 2 ;;
    --ready-path) need $#; READY="$2"; shift 2 ;;
    --manual) need $#; MANUAL="$2"; shift 2 ;;
    --path) need $#; PATHS_IN+=("$2"); shift 2 ;;
    --alert) need $#; ALERTS_IN+=("$2"); shift 2 ;;
    --iac) need $#; IAC+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-drills: unknown option $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -eq 1 ] || { usage >&2; exit 2; }
DIR="${POS[0]}"
bad() { echo "check-drills: $1" >&2; exit 2; }
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
y=$((10#${TODAY%%-*})); m=${TODAY#*-}; m=$((10#${m%-*})); d=$((10#${TODAY##*-})); ml=31
case $m in 4|6|9|11) ml=30 ;; 2) ml=28; { [ $((y % 4)) -eq 0 ] && [ $((y % 100)) -ne 0 ]; } || [ $((y % 400)) -eq 0 ] && ml=29 ;; esac
[ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$d" -ge 1 ] && [ "$d" -le "$ml" ] || bad "--today is not a calendar date: $TODAY"
for t in "$RTO" "$RPO"; do
  [ -z "$t" ] || [ "$t" = 0 ] || printf '%s\n' "$t" | grep -Eq '^([0-9]+[dhms])+$' || bad "--rto and --rpo are durations such as 4h, 30m or 1h30m, got '$t'"
done
case "$MAXAGE" in ''|*[!0-9]*) bad "--max-age must be a number of days" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
[ -d "$REPO" ] || bad "--repo is not a directory: $REPO"
[ ! -e "$DIR" ] || [ -d "$DIR" ] || bad "not a directory: $DIR"
[ -z "$MANUAL" ] || [ ! -e "$MANUAL" ] || [ -f "$MANUAL" ] || bad "--manual is not a file: $MANUAL"

# Contract values, one per line with tab-separated fields, checked before use.
TAB=$(printf '\t')
PLIST=""; ALIST=""; RUNBOOKS=""
for s in ${PATHS_IN[@]+"${PATHS_IN[@]}"}; do
  name=${s%%:*}; rest=${s#*:}; kind=${rest%%:*}; rb=${rest#*:}
  case "$s" in *:*:*) ;; *) bad "--path must be NAME:KIND:RUNBOOK, got '$s'" ;; esac
  case "$name" in ''|*[!A-Za-z0-9._-]*) bad "--path name must be letters, digits, '.', '_' or '-', got '$name'" ;; esac
  case "$kind" in restore|failover) ;; *) bad "--path kind must be restore or failover, got '$kind'" ;; esac
  case "$rb" in *:*|*"$TAB"*) bad "--path runbook must not hold ':' or a tab, got '$rb'" ;; esac
  PLIST="$PLIST$name$TAB$kind$TAB$rb
"
  [ -z "$rb" ] || RUNBOOKS="$RUNBOOKS$rb
"
done
for s in ${ALERTS_IN[@]+"${ALERTS_IN[@]}"}; do
  case "$s" in *:*) ;; *) bad "--alert must be NAME:RUNBOOK[:page], got '$s'" ;; esac
  name=${s%%:*}; rest=${s#*:}; page=0
  case "$rest" in *:page) page=1; rest=${rest%:page} ;; *:*) bad "--alert ends in ':page' or nothing, got '$s'" ;; esac
  case "$name" in ''|*[!A-Za-z0-9._-]*) bad "--alert name must be letters, digits, '.', '_' or '-', got '$name'" ;; esac
  case "$rest" in *"$TAB"*) bad "--alert runbook must not hold a tab" ;; esac
  ALIST="$ALIST$name$TAB$rest$TAB$page
"
done

# Files for awk, each as "K=<kind> ./<path>" (the ./ stops awk from reading a path
# holding "=" as an assignment); runbooks also carry the contract's spelling.
dot() { case "$1" in /*|./*) printf '%s' "$1" ;; *) printf './%s' "$1" ;; esac; }
nodash() { case "$1" in -*) printf './%s' "$1" ;; *) printf '%s' "$1" ;; esac; }   # never an expression to find
ARGS=()
NREC=0
if [ -d "$DIR" ]; then
  RECS=$(find -H "$(nodash "$DIR")" -type f -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md' 2>/dev/null | LC_ALL=C sort || true)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    ARGS+=("K=record" "$(dot "$f")"); NREC=$((NREC + 1))
  done <<EOF_RECS
$RECS
EOF_RECS
fi
while IFS= read -r rb; do
  [ -n "$rb" ] || continue
  case "$rb" in /*) f="$rb" ;; *) f="${REPO%/}/$rb" ;; esac
  [ -f "$f" ] && ARGS+=("K=runbook" "RB=$rb" "$(dot "$f")")
done <<EOF_RB
$(printf '%s' "$RUNBOOKS" | LC_ALL=C sort -u)
EOF_RB
[ -n "$MANUAL" ] && [ -f "$MANUAL" ] && ARGS+=("K=manual" "$(dot "$MANUAL")")
for p in ${IAC[@]+"${IAC[@]}"}; do
  if [ -d "$p" ]; then
    LIST=$(find -H "$(nodash "$p")" \( -name node_modules -o -name .git -o -name .terraform -o -name vendor -o -name dist -o -name build \) -prune -o -type f -print 2>/dev/null | LC_ALL=C sort || true)
  elif [ -f "$p" ]; then LIST="$p"
  else bad "no such file or directory: $p"; fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lb=$(basename "$f" | tr 'A-Z' 'a-z')
    case "$lb" in
      docker-compose*.yml|docker-compose*.yaml|compose*.yml|compose*.yaml|podman-compose*.yml|podman-compose*.yaml) ARGS+=("K=compose" "$(dot "$f")") ;;
      *.tf) ARGS+=("K=tf" "$(dot "$f")") ;;
      *.yml|*.yaml|*.template)
        if grep -q '^Resources:' "$f" 2>/dev/null && grep -Eq 'Type:[ ]*["'"'"']?AWS::' "$f" 2>/dev/null; then ARGS+=("K=cfn" "$(dot "$f")"); fi ;;
    esac
  done <<EOF_LIST
$LIST
EOF_LIST
done

PROG_FILE="$(cd "$(dirname "$0")" && pwd)/lib/check-drills.awk"
[ -f "$PROG_FILE" ] || bad "missing $PROG_FILE"

[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)
CDR_TODAY="$TODAY" CDR_MAXAGE="$MAXAGE" CDR_MATURITY="$MATURITY" CDR_RTO="$RTO" CDR_RPO="$RPO" CDR_READY="$READY" \
CDR_MANUAL="$MANUAL" CDR_REPO="$REPO" CDR_DIR="$DIR" CDR_PATHS="$PLIST" CDR_ALERTS="$ALIST" CDR_NREC="$NREC" \
  LC_ALL=C awk -f "$PROG_FILE" "${ARGS[@]}"
