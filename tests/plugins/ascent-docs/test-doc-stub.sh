#!/usr/bin/env bash
# Behavior test for plugins/ascent-docs/scripts/doc-stub.sh.
#
# Each type writes one new document at its default path, with the doc-stub marker,
# the title and the persona filled in, every section of its stub, and nothing
# left as a placeholder; a written stub is then found by check-docs.sh (DOC-L3,
# its marker; DOC-P2, until it is linked). It never overwrites a file, --dry-run
# writes nothing, and bad input exits 2 with nothing written. Also checks that
# every stub has guidance in each section, never a bare TODO (the "substantive
# content, not skeletons" rule), and that this repository's make doc-stub runs it.
#
# Prints "test-doc-stub: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
STUBSH="$ROOT/plugins/ascent-docs/scripts/doc-stub.sh"
CHECK="$ROOT/plugins/ascent-docs/scripts/check-docs.sh"
STUBS="$ROOT/plugins/ascent-docs/references/stubs"
for f in "$STUBSH" "$CHECK" "$STUBS/tutorial.md"; do
  [ -f "$f" ] || { echo "FAIL  test-doc-stub: missing $f"; echo "test-doc-stub: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
run() { (cd "$WORK/r" && bash "$STUBSH" "$@") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); }
fresh() { rm -rf "$WORK/r"; mkdir -p "$WORK/r"; printf '# Project\n\n## Getting started\n\nRun it.\n' > "$WORK/r/README.md"; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $OUT"; fi; }
fhas() { if grep -qF -- "$3" "$WORK/r/$2" 2>/dev/null; then ok; else bad "$1: $2 lacks: $3"; fi; }

# Each type, at its default path
for t in tutorial how-to reference explanation; do
  fresh; run --type "$t" --title "Search the Catalog!" --persona Developer --today 2026-11-18; expect_rc "$t" 0
  case "$t" in tutorial) d=tutorials ;; *) d=$t ;; esac
  p="docs/$d/search-the-catalog.md"
  if [ -f "$WORK/r/$p" ]; then ok; else bad "$t: $p not written: $OUT"; continue; fi
  if [ "$(head -1 "$WORK/r/$p")" = "<!-- doc-stub: $t 2026-11-18 -->" ]; then ok; else bad "$t: first line is not the doc-stub marker"; fi
  fhas "$t" "$p" '# Search the Catalog!'
  fhas "$t" "$p" 'For: Developer.'
  if grep -q '{{' "$WORK/r/$p"; then bad "$t: a placeholder is left"; else ok; fi
  case "$t" in tutorial) want=6 ;; reference) want=4 ;; *) want=5 ;; esac
  n2=$(grep -c '^## ' "$WORK/r/$p")
  if [ "$n2" -eq "$want" ]; then ok; else bad "$t: $n2 sections written, $want expected"; fi
done
fresh; run --type entry --title "Operators start here" --persona "Site Operator"; expect_rc entry 0
fhas entry docs/site-operator/README.md 'This page is where a Site Operator starts.'
fresh; run --type how-to --title "Rotate keys" --out guides/keys.md; expect_rc out 0
fhas out guides/keys.md 'For: everyone.'
fresh; run --type how-to --title "Rotate keys" --dir handbook/; expect_rc dir 0
fhas dir handbook/how-to/rotate-keys.md '# Rotate keys'

# Never overwrites; --dry-run writes nothing
fresh; mkdir -p "$WORK/r/docs/how-to"; printf 'mine\n' > "$WORK/r/docs/how-to/rotate-keys.md"
run --type how-to --title "Rotate keys"; expect_rc overwrite 2
if [ "$(cat "$WORK/r/docs/how-to/rotate-keys.md")" = mine ]; then ok; else bad "overwrite: the existing file changed"; fi
fresh; run --type reference --title "Settings" --dry-run; expect_rc dry 0
if [ ! -e "$WORK/r/docs/reference/settings.md" ] && printf '%s' "$OUT" | grep -q 'would write docs/reference/settings.md'; then ok; else bad "dry-run: wrote a file or did not say where: $OUT"; fi

# Bad input: exit 2, nothing written
for args in "--type guide --title X" "--type how-to" "--type how-to --title ' '" "--type entry --title X" \
  "--type how-to --title X --out ../x.md" "--type how-to --title X --out /tmp/x.md" "--type how-to --title X --out x.txt" \
  "--type how-to --title '<x>'" "--type how-to --title X --today 18-11-2026" "--type how-to --title !!!"; do
  fresh; eval "run $args"; expect_rc "bad: $args" 2
  if [ -z "$(cd "$WORK/r" && find . -name '*.md' ! -name README.md)" ]; then ok; else bad "bad: $args wrote a file"; fi
done

# A stub is found by check-docs: its marker (DOC-L3) and, until linked, DOC-P2
fresh; run --type how-to --title "Rotate keys"
(cd "$WORK/r" && bash "$CHECK" --no-git) > "$WORK/chk" 2>&1
if grep -q '^FAIL  DOC-L3 .*docs/how-to/rotate-keys.md:1 ' "$WORK/chk"; then ok; else bad "check-docs does not report the stub's marker: $(grep -E '^(FAIL|N/A)' "$WORK/chk" | tr '\n' ';')"; fi
if grep -q '^FAIL  DOC-P2 .*docs/how-to/rotate-keys.md:1 ' "$WORK/chk"; then ok; else bad "check-docs does not report the unlinked stub"; fi

# Substantive stubs: guidance under every heading, no bare TODO
for f in "$STUBS"/*.md; do
  b=$(basename "$f")
  if grep -qE '(^|[^A-Za-z])(TODO|TBD|FIXME)([^A-Za-z]|$)' "$f"; then bad "$b holds a TODO, TBD or FIXME"; else ok; fi
  empty=$(awk '/^## /{ if (h != "" && n == 0) print h; h = $0; n = 0; next } NF { n++ } END { if (h != "" && n == 0) print h }' "$f")
  if [ -z "$empty" ]; then ok; else bad "$b has a section with no guidance: $empty"; fi
  if grep -q '{{TITLE}}' "$f" && grep -q '{{PERSONA}}' "$f"; then ok; else bad "$b lacks {{TITLE}} or {{PERSONA}}"; fi
done

# From the review: a symlinked folder that leads out, a persona with no ASCII name
fresh; mkdir -p "$WORK/outside" "$WORK/r/docs"; ln -s "$WORK/outside" "$WORK/r/docs/how-to"
run --type how-to --title 'Escape'; expect_rc stub-symlink 2
if [ ! -e "$WORK/outside/escape.md" ]; then ok; else bad "stub-symlink: wrote outside the repository"; fi
case "$OUT" in *'leads outside the repository'*) ok ;; *) bad "stub-symlink: message: $OUT" ;; esac
fresh; run --type entry --title 'Start here' --persona '开发者'; expect_rc stub-persona-noname 2
fresh; run --type how-to --title 'Inside' --out docs/../inside.md; expect_rc stub-climb-inside 2
if [ ! -e "$WORK/r/docs/README.md" ]; then ok; else bad "stub-persona-noname: wrote docs/README.md"; fi

# This repository's make doc-stub runs the plugin's script
if [ -f "$ROOT/make/docs.mk" ]; then
  if grep -q 'plugins/ascent-docs/scripts/doc-stub.sh' "$ROOT/make/docs.mk" && ! grep -q 'STUB' "$ROOT/make/docs.mk"; then ok; else bad "make/docs.mk does not run plugins/ascent-docs/scripts/doc-stub.sh, or still says STUB"; fi
  # a title is passed in single quotes and never tested by the shell: nothing in it runs
  if command -v make >/dev/null 2>&1; then
    t=$(cd "$ROOT" && make -n -f make/docs.mk doc-stub TYPE=how-to TITLE='Run `id` it'"'"'s' 2>&1)
    case "$t" in *"--title 'Run \`id\` it'\\''s'"*) ok ;; *) bad "make doc-stub does not single-quote the title: $t" ;; esac
  fi
fi

echo "test-doc-stub: $PASS/$((PASS + FAIL)) PASS"
[ "$FAIL" -eq 0 ]
