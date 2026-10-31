#!/usr/bin/env bash
# Section-independence test for make/test-plugins.sh (ADR-018).
#
# In fast mode a negative control runs only the gate section it names
# (ASCENT_ONLY), which gives the same verdict as the full gate only while no
# section depends on another. This runs the full gate once on the repository,
# then each section alone, and checks that every section prints exactly the same
# result lines both ways, and nothing from another section when it runs alone.
#
# Slow: one full gate plus every section once. make test-harness and the CI
# harness job run it; the plugin gate does not.
# Usage: test-gate-sections.sh [ROOT]   (defaults to this repository)
# Prints "test-gate-sections: N/N PASS" last. Uses set -u only: every section runs
# and reports, and the summary decides.
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${1:-$HERE/../..}" && pwd)"
GATE="$ROOT/make/test-plugins.sh"

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }

# results SECTION FILE — the result lines of one section, in order
results() {
  awk -v s="$1" '/^(PASS|FAIL|SKIP)  test-plugins: / { l = $3; sub(/\..*/, "", l); if (l == s) print }' "$2"
}

SECTIONS=$(sed -n 's/^SECTIONS=" \(.*\) "$/\1/p' "$GATE")
[ -n "$SECTIONS" ] || { echo "test-gate-sections: no SECTIONS list in $GATE"; echo "test-gate-sections: 0/1 PASS"; exit 1; }

ASCENT_SKIP_CLAUDE_CLI=1 bash "$GATE" "$ROOT" </dev/null >"$WORK/full" 2>&1 || true
for s in $SECTIONS; do
  ASCENT_SKIP_CLAUDE_CLI=1 ASCENT_ONLY=$s bash "$GATE" "$ROOT" </dev/null >"$WORK/only" 2>&1 || true
  results "$s" "$WORK/full" > "$WORK/a"
  results "$s" "$WORK/only" > "$WORK/b"
  others=$(grep -cE '^(PASS|FAIL|SKIP)  test-plugins: ' "$WORK/only" || true)
  if [ ! -s "$WORK/a" ]; then
    bad "$s printed no results in the full gate"
  elif ! cmp -s "$WORK/a" "$WORK/b"; then
    bad "$s alone differs from $s in the full gate: $(diff "$WORK/a" "$WORK/b" | grep '^[<>]' | head -3 | tr '\n' ';')"
  elif [ "$others" -ne "$(wc -l < "$WORK/b")" ]; then
    bad "$s alone also printed results of other sections"
  else
    ok
  fi
done

printf "test-gate-sections: %s/%s PASS (%s)\n" "$PASS" "$((PASS + FAIL))" "$(echo $SECTIONS)"
[ "$FAIL" -eq 0 ]
