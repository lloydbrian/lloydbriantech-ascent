#!/usr/bin/env bash
# Checks that a repository's documentation can be found and is kept: links,
# anchors, stale markers, documents older than what they describe, the README, and
# persona entry points. Part of the ascent-docs plugin (docs-review Step 2,
# onboard Step 1). Read-only: it reads the files and, for DOC-L3 and DOC-L4,
# git ls-files, git log and git blame.
#
# Usage: check-docs.sh [--path P]... [--exclude P]... [--persona NAME=PATH]... [--max-clicks N] [--marker-days N] [--lag-days N] [--today YYYY-MM-DD] [--maturity LEVEL] [--no-git] [REPO]
#
# REPO is the repository root (default "."). The documents checked are the Markdown
# files under each --path (docs.paths; default README.md, CONTRIBUTING.md, docs/
# and doc/), less each --exclude (docs.exclude) and, always, ADR folders (a path
# segment adr, adrs or decisions: ascent-adr's) and the operations manuals,
# runbooks and drill records (ascent-ops's defaults; pass the contract's own with
# --exclude). Every Markdown file in the repository is read for headings and links,
# so a link into an excluded file is still checked. --persona (docs.personas) names
# a persona's entry point. --max-clicks (docs.max_clicks, default 3),
# --marker-days (docs.stale_marker_days, default 90) and --lag-days
# (docs.lag_days, default 180) set the limits. --no-git skips git dates.
#
# Checks (severity from the doc-severity table in docs-review):
#   DOC-L1  Medium  every relative link resolves to a file or folder in the
#                   repository, and none leaves it
#   DOC-L2  Low     every link anchor into a Markdown file names a heading there
#                   (GitHub slugs; HTML id and name attributes count)
#   DOC-L3  Low     no stale marker (TODO, TBD, FIXME, coming soon, a [STUB
#                   label or the doc-stub marker) older than --marker-days, dated
#                   by git blame; a younger one is a NOTE
#   DOC-L4  Low     no document last changed more than --lag-days before a
#                   non-Markdown file it links to (git log dates)
#   DOC-L5  Medium  a README.md at the repository root
#   DOC-P1  Medium  every persona's entry point exists
#   DOC-P2  Low     every document is reachable by links from the README or a
#                   persona entry point
#   DOC-P3  Low     the README has a getting-started section (install, setup,
#                   quick start or usage)
#   DOC-P4  Low     every reachable document is within --max-clicks links of the
#                   README or a persona entry point
# At prototype maturity every finding is a NOTE.
#
# Output: FAIL lines (FAIL  DOC-xx  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A, NOTE lines, then "check-docs: ...". Limits: it checks
# that documents can be found and are kept, not that they are right.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '8p' "$0" | sed 's/^# //'; }
PATHS=(); EXCL=(); PERS=""; CLICKS=3; MDAYS=90; LAG=180; TODAY=""; MATURITY=enterprise; NOGIT=""; POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
bad() { echo "check-docs: $1" >&2; exit 2; }
relpath() { case "$1" in ''|/*|*..*) bad "$2 is relative to the repository, without ..: '$1'" ;; esac; }
num() { case "$1" in ''|*[!0-9]*) bad "$2 must be a whole number" ;; esac; }
while [ $# -gt 0 ]; do
  case "$1" in
    --path) need $#; relpath "$2" --path; PATHS+=("$2"); shift 2 ;;
    --exclude) need $#; relpath "$2" --exclude; EXCL+=("$2"); shift 2 ;;
    --persona) need $#; case "$2" in [A-Za-z]*=?*) ;; *) bad "--persona must be NAME=PATH" ;; esac
      relpath "${2#*=}" --persona; PERS="$PERS$2
"; shift 2 ;;
    --max-clicks) need $#; num "$2" --max-clicks; CLICKS="$2"; shift 2 ;;
    --marker-days) need $#; num "$2" --marker-days; MDAYS="$2"; shift 2 ;;
    --lag-days) need $#; num "$2" --lag-days; LAG="$2"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --no-git) NOGIT="--no-git given"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) bad "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "not a directory: $REPO"
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
[ ${#PATHS[@]} -gt 0 ] || PATHS=(README.md CONTRIBUTING.md docs doc)

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in doc-set.sh md-common.awk doc-marks.awk check-docs.awk; do [ -f "$LIB/$f" ] || bad "missing $LIB/$f"; done
cd "$REPO"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
. "$LIB/doc-set.sh"

if [ -z "$NOGIT" ]; then
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then NOGIT="not a git repository"; fi
fi
doc_files; doc_set

# Git dates: each file's last change, and each stale marker's line.
: > "$T/dates"; : > "$T/marks"
if [ -z "$NOGIT" ]; then
  git -c core.quotePath=false log --format='@%cs' --name-only --relative -- . 2>/dev/null | awk '/^@/ { d = substr($0, 2); next } NF && !($0 in s) { s[$0] = 1; print $0 "\t" d }' > "$T/dates" || true
  if [ -s "$T/set" ]; then
    MARKFILES=(); while IFS= read -r f; do MARKFILES+=("$f"); done < "$T/set"
    awk -f "$LIB/md-common.awk" -f "$LIB/doc-marks.awk" "${MARKFILES[@]}" | head -200 > "$T/marklines" || true
    while IFS="$(printf '\t')" read -r f n; do
      t=$(git blame -L "$n,$n" --porcelain -- "$f" 2>/dev/null | awk '/^committer-time /{ print $2; exit }' || true)
      if [ -n "$t" ]; then d=$(awk -v t="$t" 'BEGIN { z = int(t / 86400) + 719468; era = int(z / 146097); doe = z - era * 146097
          yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365); y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
          mp = int((5 * doy + 2) / 153); d = doy - int((153 * mp + 2) / 5) + 1; m = mp < 10 ? mp + 3 : mp - 9; if (m <= 2) y++
          printf "%04d-%02d-%02d", y, m, d }')
      else d="$TODAY"; fi
      printf '%s\t%s\t%s\n' "$f" "$n" "$d"
    done < "$T/marklines" > "$T/marks"
  fi
else
  if [ -s "$T/set" ]; then
    MARKFILES=(); while IFS= read -r f; do MARKFILES+=("$f"); done < "$T/set"
    awk -f "$LIB/md-common.awk" -f "$LIB/doc-marks.awk" "${MARKFILES[@]}" | head -200 | awk -F'\t' '{ print $1 "\t" $2 "\t" }' > "$T/marks" || true
  fi
fi

MDIN=(); while IFS= read -r f; do [ -f "$f" ] && MDIN+=("./$f"); done < "$T/md"
CD_TODAY="$TODAY" CD_MATURITY="$MATURITY" CD_NOGIT="$NOGIT" CD_MAX_CLICKS="$CLICKS" CD_MARKER_DAYS="$MDAYS" CD_LAG_DAYS="$LAG" \
CD_FILES="$T/files" CD_SET="$T/set" CD_DATES="$T/dates" CD_MARKS="$T/marks" CD_PERSONAS="$PERS" \
  awk -f "$LIB/md-common.awk" -f "$LIB/check-docs.awk" "$T/files" "$T/set" "$T/dates" "$T/marks" ${MDIN[@]+"${MDIN[@]}"}
