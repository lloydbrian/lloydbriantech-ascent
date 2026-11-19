#!/usr/bin/env bash
# Creates one new document from a stub: a tutorial, how-to guide, reference page,
# explanation or persona entry point, with guidance in every section for the
# person who fills it in. Part of the ascent-docs plugin (doc-stub Step 4); this
# repository's make doc-stub runs it. It writes one new file and never overwrites
# one; it never commits.
#
# Usage: doc-stub.sh --type TYPE --title TITLE [--persona NAME] [--out PATH] [--dir DIR] [--today YYYY-MM-DD] [--dry-run] [REPO]
#
# TYPE is tutorial, how-to, reference, explanation or entry. --out is the new
# file, relative to REPO (default "."); without it the file goes under --dir
# (docs.dir, default docs): <dir>/tutorials/, how-to/, reference/ or explanation/,
# named from the title, or <dir>/<persona>/README.md for an entry point. --persona
# names the reader (default "everyone", or the persona of an entry point, which
# needs one). --dry-run prints the path and the document instead of writing.
#
# The document starts with "<!-- doc-stub: TYPE YYYY-MM-DD -->", which check-docs.sh
# reports as a stale marker (DOC-L3) once it is older than docs.stale_marker_days:
# delete the line when the document is written.
# Exit: 0 written (or printed); 2 bad input, or the file exists.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '8p' "$0" | sed 's/^# //'; }
TYPE=""; TITLE=""; PERSONA=""; OUT=""; DIR=docs; TODAY=""; DRY=0; POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
bad() { echo "doc-stub: $1" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --type) need $#; TYPE="$2"; shift 2 ;;
    --title) need $#; TITLE="$2"; shift 2 ;;
    --persona) need $#; PERSONA="$2"; shift 2 ;;
    --out) need $#; OUT="$2"; shift 2 ;;
    --dir) need $#; DIR="${2%/}"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) bad "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "not a directory: $REPO"
case "$TYPE" in tutorial|how-to|reference|explanation|entry) ;; '') bad "--type is required: tutorial, how-to, reference, explanation or entry" ;; *) bad "unknown type '$TYPE': tutorial, how-to, reference, explanation or entry" ;; esac
[ -n "$(printf '%s' "$TITLE" | tr -d ' \t')" ] || bad "--title is required"
case "$TITLE$PERSONA" in *'
'*|*'<'*|*'>'*|*'{{'*) bad "--title and --persona are one line of text, without <, > or {{" ;; esac
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
if [ "$TYPE" = entry ] && [ -z "$PERSONA" ]; then bad "an entry point needs --persona"; fi
[ -n "$PERSONA" ] || PERSONA=everyone

slug() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//'; }
if [ -z "$OUT" ]; then
  case "$TYPE" in
    tutorial) OUT="$DIR/tutorials/$(slug "$TITLE").md" ;;
    how-to) OUT="$DIR/how-to/$(slug "$TITLE").md" ;;
    reference) OUT="$DIR/reference/$(slug "$TITLE").md" ;;
    explanation) OUT="$DIR/explanation/$(slug "$TITLE").md" ;;
    entry) [ -n "$(slug "$PERSONA")" ] || bad "the persona gives no folder name; pass --out"; OUT="$DIR/$(slug "$PERSONA")/README.md" ;;
  esac
fi
case "$OUT" in /*|*..*|'') bad "--out and --dir are relative to the repository, without ..: '$OUT'" ;; esac
case "$OUT" in *.md) ;; *) bad "--out must end in .md: '$OUT'" ;; esac
case "$(basename "$OUT")" in .md|-*) bad "the title gives no file name; pass --out" ;; esac

STUB="$(cd "$(dirname "$0")/.." && pwd)/references/stubs/$TYPE.md"
[ -f "$STUB" ] || bad "missing $STUB"
cd "$REPO"
[ ! -e "$OUT" ] && [ ! -L "$OUT" ] || bad "$OUT exists: doc-stub never overwrites a document"
# a folder on the way may be a symlink: the nearest existing one must resolve inside the repository
d=$(dirname "$OUT"); while [ ! -d "$d" ]; do d=$(dirname "$d"); done
case "$(cd "$d" && pwd -P)/" in "$(pwd -P)"/*) ;; *) bad "$OUT leads outside the repository (through a symlinked folder): doc-stub writes only inside it" ;; esac

render() {
  printf '<!-- doc-stub: %s %s -->\n' "$TYPE" "$TODAY"
  T="$TITLE" P="$PERSONA" awk '{ while ((i = index($0, "{{TITLE}}")) > 0) $0 = substr($0, 1, i - 1) ENVIRON["T"] substr($0, i + 9)
    while ((i = index($0, "{{PERSONA}}")) > 0) $0 = substr($0, 1, i - 1) ENVIRON["P"] substr($0, i + 11); print }' "$STUB"
}
if [ "$DRY" = 1 ]; then echo "doc-stub: would write $OUT"; render; exit 0; fi
mkdir -p "$(dirname "$OUT")"
( set -C; render > "$OUT" ) 2>/dev/null || bad "$OUT exists: doc-stub never overwrites a document"
echo "doc-stub: wrote $OUT ($TYPE, for $PERSONA); fill in each section, then delete the doc-stub line. Link it from an entry point, or check-docs.sh reports it (DOC-P2). Nothing is committed."
