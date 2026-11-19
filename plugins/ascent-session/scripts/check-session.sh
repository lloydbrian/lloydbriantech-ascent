#!/usr/bin/env bash
# Checks a repository's session records: the working memory the team shares, the
# session state each person keeps, and the handoff. Part of the ascent-session plugin
# (session-resume Step 1, session-capture Step 6, handoff Step 5). Read-only: it reads
# the files and, for SES-S3 and SES-S4, git log, git show, git ls-files and
# git check-ignore.
#
# Usage: check-session.sh [--memory FILE] [--state FILE] [--handoff FILE] [--max-age DAYS] [--today YYYY-MM-DD] [--maturity LEVEL] [--since COMMIT] [--require-handoff] [--no-git] [REPO]
#
# REPO is the repository root (default "."). The files are relative to it:
# --memory session.memory (default docs/delivery/working-memory.md), --state
# session.state (default docs/delivery/session-state.md), --handoff session.handoff
# (default docs/delivery/HANDOFF.md). --max-age is the days a session state stays
# fresh (session.state_max_age_days, default 7). --since COMMIT
# (session.memory_since) starts the history check after a known rewrite of the
# working memory. --require-handoff (session.handoff_required) makes a missing
# handoff a finding. --no-git skips SES-S3 and SES-S4.
#
# Checks (severity from the ses-severity table in session-resume):
#   SES-S1  Medium  the working memory exists, with a "## Decisions" section
#   SES-S2  Low     every entry under Decisions starts "YYYY-MM-DD: "; every dated
#                   entry (patterns may be undated) has a real date not after
#                   today, and no entry is dated before the one above it
#   SES-S3  Medium  entries are only appended: every entry of every earlier version
#                   in the git history is still there, unchanged, in its section
#   SES-S4  Medium  once the project keeps session records, the session state is
#                   not tracked by git and is ignored by it
#   SES-S5  Low     the session state, when present, has Current focus, Active
#                   decisions, Blockers and Next actions, no "(fill in: ...)"
#                   placeholder left by make session-snapshot, and was captured
#                   within --max-age days
#   SES-S6  Low     the handoff, when present (or required), has Where to start,
#                   Project state and Project conventions, and was generated no
#                   earlier than the newest working-memory entry
# At prototype maturity every finding is a NOTE.
#
# Output: FAIL lines (FAIL  SES-Sk  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A, NOTE lines, then "check-session: ...". Limits: it
# checks that the records are kept, not that they are accurate.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '8p' "$0" | sed 's/^# //'; }
MEM=docs/delivery/working-memory.md; ST=docs/delivery/session-state.md; HO=docs/delivery/HANDOFF.md
MAXAGE=7; TODAY=""; MATURITY=enterprise; SINCE=""; REQH=0; NOGIT=""; POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
bad() { echo "check-session: $1" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --memory) need $#; MEM="$2"; shift 2 ;;
    --state) need $#; ST="$2"; shift 2 ;;
    --handoff) need $#; HO="$2"; shift 2 ;;
    --max-age) need $#; MAXAGE="$2"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --since) need $#; SINCE="$2"; shift 2 ;;
    --require-handoff) REQH=1; shift ;;
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
case "$MAXAGE" in ''|*[!0-9]*) bad "--max-age must be a number of days" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
for p in "$MEM" "$ST" "$HO"; do case "$p" in ''|/*|*..*) bad "--memory, --state and --handoff are relative to the repository, without ..: '$p'" ;; esac; done
case "$SINCE" in ''|[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;; *) bad "--since must be a commit id" ;; esac
case "$SINCE" in *[!0-9a-f]*) bad "--since must be a commit id" ;; esac

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in memory-entries.awk check-session.awk; do [ -f "$LIB/$f" ] || bad "missing $LIB/$f"; done
cd "$REPO"

if [ -z "$NOGIT" ]; then
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then NOGIT="not a git repository"; fi
fi

# SES-S3: every entry of each version in the history must survive into each version
# made from it (on any branch), and into the working copy. A lost entry is reported once, with the version it was in.
LOST=""; HCHECKED=0; SHALLOW=""
if [ -z "$NOGIT" ] && [ -f "$MEM" ] && git ls-files --error-unmatch -- "$MEM" >/dev/null 2>&1; then
  if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then SHALLOW=1
  else
    [ -z "$SINCE" ] || git cat-file -e "$SINCE^{commit}" 2>/dev/null || bad "--since $SINCE: no such commit"
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
    # Each version against the version(s) it was made from, its parents in the file's
    # history, so entries appended on parallel branches are not read as lost.
    ents() { git show "$1:./$MEM" 2>/dev/null | awk -f "$LIB/memory-entries.awk" | sort -u; }
    if [ -n "$SINCE" ]; then RANGE="$SINCE..HEAD"; else RANGE=HEAD; fi
    git log --parents --format='%h %p' "$RANGE" -- "$MEM" > "$T/revs" 2>/dev/null || : > "$T/revs"
    : > "$T/lost"
    while read -r c ps; do
      for p in $ps; do
        ents "$p" > "$T/prev"; ents "$c" > "$T/cur"; HCHECKED=$((HCHECKED + 1))
        comm -23 "$T/prev" "$T/cur" | while IFS= read -r e; do printf '%s\t%s\n' "$p" "$e"; done >> "$T/lost"
      done
    done < "$T/revs"
    if git cat-file -e "HEAD:./$MEM" 2>/dev/null; then  # the working copy against HEAD's version
      ents HEAD > "$T/prev"; awk -f "$LIB/memory-entries.awk" "$MEM" | sort -u > "$T/cur"; HCHECKED=$((HCHECKED + 1))
      h=$(git rev-parse --short HEAD)
      comm -23 "$T/prev" "$T/cur" | while IFS= read -r e; do printf '%s\t%s\n' "$h" "$e"; done >> "$T/lost"
    fi
    [ -f "$T/lost" ] && LOST=$(awk -F'\t' '!seen[$2 FS $3]++' "$T/lost" | head -10)
  fi
fi

# SES-S4: the session state is neither tracked nor committable.
TRACKED=0; IGNORED=0
if [ -z "$NOGIT" ]; then
  git ls-files --error-unmatch -- "$ST" >/dev/null 2>&1 && TRACKED=1
  git check-ignore -q --no-index -- "$ST" 2>/dev/null && IGNORED=1
fi

S3NOGIT="$NOGIT"; [ -n "$SHALLOW" ] && S3NOGIT="a shallow clone: the history is incomplete; fetch it with git fetch --unshallow"
IN=(); HM=0; HS=0; HH=0
dot() { printf './%s' "$1"; }
[ -f "$MEM" ] && { HM=1; IN+=("$(dot "$MEM")"); }
[ -f "$ST" ] && { HS=1; IN+=("$(dot "$ST")"); }
[ -f "$HO" ] && { HH=1; IN+=("$(dot "$HO")"); }
[ ${#IN[@]} -gt 0 ] || IN=(/dev/null)
CS_TODAY="$TODAY" CS_MAXAGE="$MAXAGE" CS_MATURITY="$MATURITY" CS_MEMORY="$MEM" CS_STATE="$ST" CS_HANDOFF="$HO" \
CS_MEMORY_IN="$(dot "$MEM")" CS_STATE_IN="$(dot "$ST")" CS_HANDOFF_IN="$(dot "$HO")" \
CS_HAVE_MEMORY="$HM" CS_HAVE_STATE="$HS" CS_HAVE_HANDOFF="$HH" CS_NOGIT="$NOGIT" CS_S3NOGIT="$S3NOGIT" CS_REQUIRE_HANDOFF="$REQH" \
CS_LOST="$LOST" CS_STATE_TRACKED="$TRACKED" CS_STATE_IGNORED="$IGNORED" CS_HISTORY_CHECKED="$HCHECKED" \
  awk -f "$LIB/check-session.awk" "${IN[@]}"
