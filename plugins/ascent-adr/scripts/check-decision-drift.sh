#!/usr/bin/env bash
# Checks the code against the constraints accepted ADRs declare. Part of the
# ascent-adr plugin (decision-drift Step 3). Read-only.
#
# Usage: check-decision-drift.sh [--dir DIR] [--maturity LEVEL] [--forbid ADR-N REGEX [--under PATHS]]... [--require ADR-N PATH]... [REPO]
#
# Each --forbid and --require is one entry of decisions.constraints in
# .ascent/contract.yml. --forbid ADR-N REGEX: no file may match REGEX, a POSIX
# extended regular expression, matched line by line; --under PATHS (comma-separated
# folders or files, relative to REPO) limits the forbid before it to those paths.
# --require ADR-N PATH: PATH, a file or folder relative to REPO, must exist. --dir is
# the ADR folder (decisions.dir; found as check-adrs.sh finds it). The files searched
# are those git tracks or would track (new files git does not ignore; every file
# when REPO is not a git repository), without the ADR folder, .ascent/ and .claude/,
# and without binary files.
#
# Checks (severity from the dec-severity table in adr-check):
#   DEC-C1  Medium  no file matches a forbid of an accepted ADR (the first 20 matches
#                   of each forbid are listed, then a count)
#   DEC-C2  Medium  every path a require of an accepted ADR names exists
#   DEC-C3  Low     every constraint names an ADR that exists and is accepted; the
#                   constraints of any other ADR are reported here, not enforced
# At prototype maturity every finding is a NOTE.
#
# Output: FAIL lines (FAIL  DEC-Ck  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A, NOTE lines, then "check-decision-drift: ...". Limits:
# it checks only the constraints declared, not every way code can drift from a
# decision.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk and grep -E, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '5p' "$0" | sed 's/^# //'; }
DIR=""; MATURITY=enterprise; NC=0; POS=()
need() { [ "$1" -ge "$2" ] || { usage >&2; exit 2; }; }
bad() { echo "check-decision-drift: $1" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) need $# 2; DIR="$2"; shift 2 ;;
    --maturity) need $# 2; MATURITY="$2"; shift 2 ;;
    --forbid) need $# 3; NC=$((NC + 1)); KIND[$NC]=forbid; CADR[$NC]="$2"; CVAL[$NC]="$3"; CUNDER[$NC]=""; shift 3 ;;
    --under) need $# 2; [ "$NC" -gt 0 ] && [ "${KIND[$NC]}" = forbid ] || bad "--under must follow a --forbid"; CUNDER[$NC]="$2"; shift 2 ;;
    --require) need $# 3; NC=$((NC + 1)); KIND[$NC]=require; CADR[$NC]="$2"; CVAL[$NC]="$3"; CUNDER[$NC]=""; shift 3 ;;
    -h|--help) usage; exit 0 ;;
    -*) bad "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "not a directory: $REPO"
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
case "$DIR" in /*|*..*) bad "--dir is relative to the repository, without ..: $DIR" ;; esac
i=1
while [ "$i" -le "$NC" ]; do
  printf '%s\n' "${CADR[$i]}" | grep -Eq '^[Aa][Dd][Rr]-?[0-9]+$' || bad "a constraint's ADR must be ADR-N, got '${CADR[$i]}'"
  [ -n "${CVAL[$i]}" ] || bad "an empty ${KIND[$i]}"
  if [ "${KIND[$i]}" = forbid ]; then
    set +e; printf 'x\n' | grep -Eq -- "${CVAL[$i]}" 2>/dev/null; r=$?; set -e
    [ "$r" -le 1 ] || bad "--forbid ${CADR[$i]}: not a valid extended regular expression: ${CVAL[$i]}"
  else
    case "${CVAL[$i]}" in /*|*..*) bad "--require ${CADR[$i]}: the path is relative to the repository, without ..: ${CVAL[$i]}" ;; esac
  fi
  for u in $(printf '%s' "${CUNDER[$i]}" | tr ',' ' '); do case "$u" in /*|*..*) bad "--under is relative to the repository, without ..: $u" ;; esac; done
  i=$((i + 1))
done

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in adr-dir.sh adr-common.awk adr-tool.awk; do [ -f "$LIB/$f" ] || bad "missing $LIB/$f"; done
cd "$REPO"
. "$LIB/adr-dir.sh"; adr_dir
DIR="${DIR%/}"

# Each ADR's number and status class.
STAT=""
if [ -n "$DIR" ] && [ -d "$DIR" ]; then
  ADRS=(); while IFS= read -r f; do ADRS+=("$f"); done < <(adrs_in "$DIR")
  set -- ${ADRS[@]+"${ADRS[@]}"}
  [ $# -gt 0 ] && STAT=$(awk -v MODE=list -f "$LIB/adr-common.awk" -f "$LIB/adr-tool.awk" "$@")
fi
status_of() { printf '%s\n' "$STAT" | awk -F'\t' -v n="$1" '$1 == n { print ($2 == "" ? "without a status" : $2); f = 1; exit } END { if (!f) print "missing" }'; }

# The files a forbid searches.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then LIST=$(git ls-files --cached --others --exclude-standard -- .)
else LIST=$(find . -type f ! -path './.git/*' ! -path '*/node_modules/*' | sed 's|^\./||'); fi
# without the ADR folder, or only its ADRs when it is a shared folder such as docs/
if [ "$SHARED" = 1 ]; then XD="/"; XF=$(adrs_in "$DIR" | sed 's|^\./||'); else XD="$DIR/"; XF=""; fi
LIST=$(printf '%s\n' "$LIST" | XF="$XF" awk -v d="$XD" 'BEGIN { n = split(ENVIRON["XF"], a, "\n"); for (i = 1; i <= n; i++) x[a[i]] = 1 }
  NF && (d == "/" || index($0, d) != 1) && !($0 in x) && $0 !~ /^\.(ascent|claude)\//' | LC_ALL=C sort)

OUT=""; NFAIL=0; NOTES=""; CK1=0; CK2=0; CK3=0; F1=""; F2=""; F3=""
fail() {  # CHECK SEVERITY WHERE MESSAGE
  if [ "$MATURITY" = prototype ]; then NOTES="${NOTES}$(printf 'NOTE  %-7s %-6s %s  %s (prototype: not rated)' "DEC-$1" "$2" "$3" "$4")
"; return; fi
  local line; line=$(printf 'FAIL  %-7s %-6s %s  %s' "DEC-$1" "$2" "$3" "$4")
  case "$1" in C1) F1="$F1$line
" ;; C2) F2="$F2$line
" ;; C3) F3="$F3$line
" ;; esac
  NFAIL=$((NFAIL + 1))
}
i=1
while [ "$i" -le "$NC" ]; do
  n=$(printf '%s' "${CADR[$i]}" | tr -dc '0-9' | sed 's/^0*//'); n=${n:-0}; id="ADR-$n"
  st=$(status_of "$n"); CK3=$((CK3 + 1))
  if [ "$st" != accepted ]; then
    if [ "$st" = missing ]; then fail C3 Low "${DIR:-.}:1" "a ${KIND[$i]} constraint names $id, which is not in ${DIR:-the ADR folder}"
    else fail C3 Low "${DIR:-.}:1" "a ${KIND[$i]} constraint names $id, which is $st, not accepted: remove the constraint or move it to the ADR that replaced it"; fi
    i=$((i + 1)); continue
  fi
  if [ "${KIND[$i]}" = require ]; then
    CK2=$((CK2 + 1))
    p="${CVAL[$i]%/}"
    [ -e "$p" ] || fail C2 Medium "$p:absent" "$id requires $p, which does not exist"
  else
    CK1=$((CK1 + 1))
    FILES=$(printf '%s\n' "$LIST" | awk -v u="${CUNDER[$i]}" 'BEGIN { n = split(u, a, ",") } { if (n == 0) { print; next } for (j = 1; j <= n; j++) { p = a[j]; sub(/^\.\//, "", p); sub(/\/$/, "", p); if (p == "" || $0 == p || index($0, p "/") == 1) { print; next } } }')
    HITS=""
    if [ -n "$FILES" ]; then
      HITS=$(printf '%s\n' "$FILES" | tr '\n' '\000' | xargs -0 grep -IHnE -- "${CVAL[$i]}" 2>/dev/null || true)
    fi
    if [ -n "$HITS" ]; then
      total=$(printf '%s\n' "$HITS" | grep -c . || true)
      shown=$(printf '%s\n' "$HITS" | head -20)
      while IFS= read -r h; do
        loc=$(printf '%s' "$h" | awk -F: '{ print $1 ":" $2 }'); txt=$(printf '%s' "$h" | cut -d: -f3- | sed 's/^[[:space:]]*//' | cut -c1-80)
        fail C1 Medium "$loc" "$id forbids /${CVAL[$i]}/: $txt"
      done <<EOF
$shown
EOF
      [ "$total" -le 20 ] || NOTES="${NOTES}NOTE  DEC-C1  -      ${CADR[$i]}  $((total - 20)) more match(es) of /${CVAL[$i]}/ not listed
"
    fi
  fi
  i=$((i + 1))
done

line() {  # CHECK COUNT FAILS TEXT NA
  if [ -n "$3" ]; then printf '%s' "$3"
  elif [ "$2" -gt 0 ]; then printf 'PASS  %-7s %s (%d checked)\n' "DEC-$1" "$4" "$2"
  else printf 'N/A   %-7s %s (%s)\n' "DEC-$1" "$4" "$5"; fi
}
line C1 "$CK1" "$F1" "no file matches a forbidden pattern" "no forbid constraint of an accepted ADR"
line C2 "$CK2" "$F2" "every required path exists" "no require constraint of an accepted ADR"
line C3 "$CK3" "$F3" "constraints name accepted ADRs" "no constraint declared"
printf '%s' "$NOTES"
printf 'check-decision-drift: %s, %d constraint(s), %d file(s) searched, %d failure(s); it checks only the constraints declared, not every way code can drift from a decision\n' "${DIR:-no ADR folder}" "$NC" "$(printf '%s\n' "$LIST" | grep -c . || true)" "$NFAIL"
[ "$NFAIL" -eq 0 ]
