#!/usr/bin/env bash
# Checks a repository's architecture decision records. Part of the ascent-adr plugin
# (adr-check Step 2, adr-write Step 6). Read-only: it reads the ADR files and, for
# DEC-S8, the repository's history with git log and git show.
#
# Usage: check-adrs.sh [--dir DIR] [--index FILE] [--style auto|ascent|nygard|madr] [--today YYYY-MM-DD] [--maturity LEVEL] [--no-git] [--acknowledge ADR-N=COMMIT]... [REPO]
#
# REPO is the repository root (default "."). --dir is the ADR folder relative to it
# (decisions.dir); without it the first of .adr-dir's folder, docs/adr,
# docs/decisions, doc/adr, docs/architecture/decisions, docs/adrs, adr and decisions
# that holds an ADR is used, else the folder holding the most ADR-NNN files (two at
# least), such as docs/ADR-0001-title.md. ADR files are named NNNN-title.md or ADR-NNN-title.md;
# a numbered template (0000-template.md) is skipped. --index is the index file (default the
# folder's INDEX.md or index.md, else its README.md when it links to an ADR).
# --style is the format every ADR must follow (decisions.style; default auto: the
# format most ADRs use). --no-git skips DEC-S8; so does a shallow clone, whose history
# is incomplete. --acknowledge ADR-N=COMMIT (each of
# decisions.acknowledged_changes) records that a change to an accepted ADR, up to
# COMMIT, is known and accepted: DEC-S8 then compares with that commit, so any later
# change still fails, and a NOTE names the acknowledgement.
#
# Checks (severity from the dec-severity table in adr-check):
#   DEC-S1  Medium  a decision record exists: an ADR folder holding an ADR
#   DEC-S2  Medium  every ADR has its format's sections (ascent: Context, Decision,
#                   Alternatives considered, Consequences, Cost implications;
#                   nygard: Context, Decision, Consequences; madr: Context and
#                   Problem Statement, Considered Options, Decision Outcome)
#   DEC-S3  Low     numbers are unique, every Markdown file in the folder is named
#                   as an ADR (not checked in a folder found by its ADR-NNN files,
#                   which holds other documents too), and a number in a title
#                   matches its file
#   DEC-S4  Low     the index lists every ADR, links to no missing file, and gives
#                   the status the ADR gives
#   DEC-S5  Medium  every ADR has a status: proposed, accepted, rejected,
#                   deprecated or superseded
#   DEC-S6  Medium  a superseded ADR names a replacement that exists and says it
#                   supersedes it; an ADR that supersedes another has marked it
#                   superseded
#   DEC-S7  Low     every ADR has a real date, not after today (a date field, or
#                   a date in the status line)
#   DEC-S8  Medium  an accepted ADR's body is unchanged since the commit that first
#                   recorded it as accepted; only its status may change
# At prototype maturity every finding is a NOTE.
#
# Output: FAIL lines (FAIL  DEC-Sk  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A, NOTE lines, then "check-adrs: ...". Limits: it checks
# that decisions are recorded and kept, not that they are right.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
DIR=""; INDEX=""; STYLE=auto; TODAY=""; MATURITY=enterprise; NOGIT=""; ACK=""; POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) need $#; DIR="$2"; shift 2 ;;
    --index) need $#; INDEX="$2"; shift 2 ;;
    --style) need $#; STYLE="$2"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --no-git) NOGIT="--no-git given"; shift ;;
    --acknowledge) need $#; ACK="$ACK$2
"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-adrs: unknown option $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
bad() { echo "check-adrs: $1" >&2; exit 2; }
[ ${#POS[@]} -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "not a directory: $REPO"
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
case "$STYLE" in auto|ascent|nygard|madr) ;; *) bad "--style must be auto, ascent, nygard or madr" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
ACKN=""
while IFS= read -r a; do
  [ -n "$a" ] || continue
  printf '%s\n' "$a" | grep -Eq '^[Aa][Dd][Rr]-?[0-9]+=[0-9a-f]{4,40}$' || bad "--acknowledge must be ADR-N=COMMIT, got '$a'"
  n=${a%%=*}; n=$(printf '%s' "$n" | tr -dc '0-9' | sed 's/^0*//'); ACKN="$ACKN${n:-0}=${a#*=}
"
done <<EOF
$ACK
EOF
for p in "$DIR" "$INDEX"; do case "$p" in /*|*..*) bad "--dir and --index are relative to the repository, without ..: $p" ;; esac; done

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in adr-dir.sh adr-common.awk adr-tool.awk check-adrs.awk; do [ -f "$LIB/$f" ] || bad "missing $LIB/$f"; done
cd "$REPO"
. "$LIB/adr-dir.sh"; adr_dir
DIR="${DIR%/}"

FILES=""; OTHERS=""
if [ -n "$DIR" ] && [ -d "$DIR" ]; then
  FILES=$(adrs_in "$DIR" | LC_ALL=C sort)
  for f in "$DIR"/*.md; do
    [ -f "$f" ] || continue
    b=$(basename "$f" | tr 'A-Z' 'a-z')
    case "$b" in index.md|readme.md|*template*) continue ;; esac
    [ "$SHARED" = 1 ] || isadr "$f" || OTHERS="$OTHERS$f
"
  done
  if [ -z "$INDEX" ]; then
    for c in INDEX.md index.md; do [ -f "$DIR/$c" ] && { INDEX="$DIR/$c"; break; }; done
    if [ -z "$INDEX" ] && [ -f "$DIR/README.md" ] && grep -Eiq '\]\([^)]*(adr-)?[0-9]+[-_][^)]*\.md' "$DIR/README.md"; then INDEX="$DIR/README.md"; fi
  fi
fi
[ -z "$INDEX" ] || [ -f "$INDEX" ] || bad "no index file at $INDEX"

# DEC-S8: compare each accepted ADR with the version that first recorded it as accepted.
DRIFT=""
if [ -z "$NOGIT" ]; then
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then NOGIT="not a git repository"
  elif [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then NOGIT="a shallow clone: the history is incomplete; fetch it with git fetch --unshallow"; fi
fi
if [ -z "$NOGIT" ] && [ -n "$FILES" ]; then
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$(LC_ALL=C awk -v MODE=status -f "$LIB/adr-common.awk" -f "$LIB/adr-tool.awk" "$f")" in accepted|superseded) ;; *) continue ;; esac
    git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || continue
    base=""
    n=$(basename "$f" | sed 's/^[Aa][Dd][Rr]-//; s/[^0-9].*//; s/^0*//'); a=$(printf '%s' "$ACKN" | sed -n "s/^${n:-0}=//p" | head -1)
    if [ -n "$a" ]; then
      git show "$a:./$f" > "$T/v" 2>/dev/null || bad "--acknowledge ADR-${n:-0}=$a: $f is not in commit $a"
      ACKED="${ACKED:-}$f	$a
"; base="$a"
    fi
    [ -n "$base" ] || for c in $(git log --reverse --format=%h -- "$f"); do
      git show "$c:./$f" > "$T/v" 2>/dev/null || continue
      if [ "$(LC_ALL=C awk -v MODE=status -f "$LIB/adr-common.awk" -f "$LIB/adr-tool.awk" "$T/v")" = accepted ]; then base="$c"; break; fi
    done
    [ -n "$base" ] || continue
    COMPARED="${COMPARED:-}$f
"
    LC_ALL=C awk -v MODE=body -f "$LIB/adr-common.awk" -f "$LIB/adr-tool.awk" "$T/v" > "$T/a"
    LC_ALL=C awk -v MODE=body -f "$LIB/adr-common.awk" -f "$LIB/adr-tool.awk" "$f" > "$T/b"
    cmp -s "$T/a" "$T/b" || DRIFT="$DRIFT$f	$base
"
  done <<EOF
$FILES
EOF
fi

ARGS=()
[ -n "$INDEX" ] && ARGS+=("./$INDEX")
while IFS= read -r f; do [ -n "$f" ] && ARGS+=("./$f"); done <<EOF
$FILES
EOF
[ ${#ARGS[@]} -gt 0 ] || ARGS=(/dev/null)
CA_TODAY="$TODAY" CA_MATURITY="$MATURITY" CA_STYLE="$STYLE" CA_INDEX="${INDEX:+./$INDEX}" CA_DIR="$DIR" CA_NOGIT="$NOGIT" \
CA_DRIFT="$DRIFT" CA_ACKED="${ACKED:-}" CA_COMPARED="${COMPARED:-}" CA_OTHERS="$OTHERS" CA_LOOKED="$LOOKED" \
  LC_ALL=C awk -f "$LIB/adr-common.awk" -f "$LIB/check-adrs.awk" "${ARGS[@]}"
