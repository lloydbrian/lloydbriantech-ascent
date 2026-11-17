#!/usr/bin/env bash
# Behavior test for plugins/ascent-delivery/scripts/check-acceptance.sh (ADR-024).
#
# A good acceptance record passes all three checks. Each check then gets negative
# controls: a copy broken in exactly one way fails that check and no other. Also
# covers --draft (evidence only), listed acceptors (case and spacing ignored),
# evidence forms (path:line, a line range, several items, manual), paths outside the
# repository, escaped bars, CRLF, column order, the plugin's acceptance template, and
# bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-acceptance: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-delivery"
CHECK="$PLUGIN/scripts/check-acceptance.sh"
TEMPLATE="$PLUGIN/skills/delivery-loop/references/acceptance-template.md"
for f in "$CHECK" "$TEMPLATE"; do [ -f "$f" ] || { echo "test-check-acceptance: missing $f"; echo "test-check-acceptance: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { (cd "$REPO" && PATH="$SHIM:$PATH" bash "$CHECK" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }

# A repository with a test file of 50 lines, and a good record.
REPO="$WORK/repo"; mkdir -p "$REPO/tests" "$REPO/docs/delivery/acceptance"
awk 'BEGIN { for (i = 1; i <= 50; i++) print "line " i }' > "$REPO/tests/draft.test.js"
REC=docs/delivery/acceptance/2026-11-16-drafts.md
good() {
  cat > "$REPO/$REC" <<'EOF'
# Acceptance: drafts survive a reload

| # | Criterion | Evidence | Accepted by | Accepted on |
|---|---|---|---|---|
| 1 | A long form keeps its draft across a reload | `tests/draft.test.js:42` | Ana Lopez | 2026-11-15 |
| 2 | The draft is cleared after a submit | tests/draft.test.js:10-12; manual: submitted the form on beta in Firefox | sam-lee | 2026-11-16 |
| 3 | A draft never leaves the device | manual: checked the network log on beta, no draft request | Ana Lopez | 2026-11-16 |

Notes after the table are not rows.
EOF
}
# row N COLUMN VALUE: set one cell of the good record (columns 2-5: criterion,
# evidence, accepted by, accepted on); \| in VALUE stays a literal bar.
row() {
  good
  # the value goes through the environment: awk -v would read \| as an escape
  V="$3" awk -v n="$1" -v c="$2" -F'|' 'BEGIN { OFS = "|" } $2 ~ "^ " n " $" { $(c + 1) = " " ENVIRON["V"] " " } { print }' "$REPO/$REC" > "$WORK/rec.tmp" && mv "$WORK/rec.tmp" "$REPO/$REC"
}
# expect_only NAME CHECK [TEXT]: the last run failed CHECK (with TEXT) and no other check
expect_only() {
  local other
  other=$(printf '%s\n' "$OUT" | grep '^FAIL' | grep -v "^FAIL  $2 " | head -2 | tr '\n' ';')
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s' "$OUT" | tail -2 | tr '\n' ';')"
  elif ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 "; then bad "$1: $2 did not fail: $(printf '%s' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ -n "$other" ]; then bad "$1: expected only $2 to fail, also got: $other"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep "^FAIL  $2 " | grep -qF -- "$3"; then bad "$1: $2 message lacks '$3': $(printf '%s\n' "$OUT" | grep "^FAIL  $2 " | head -1)"
  else ok; fi
}
clean() { if [ "$RC" -eq 0 ]; then ok; else bad "$1: expected a clean run, got exit $RC: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -3 | tr '\n' ';')"; fi; }
has_line() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }

matrix() {
  # Baseline: the good record passes every check.
  good; run --acceptor 'Ana Lopez' --acceptor sam-lee "$REC"; clean "good record"
  for k in DEL-A1 DEL-A2 DEL-A3; do printf '%s\n' "$OUT" | grep -q "^PASS  $k " && ok || bad "good record: $k is not PASS: $(printf '%s\n' "$OUT" | grep " $k " | head -1)"; done
  has_line "summary" "check-acceptance: $REC, 3 criteria, 0 failure(s)"
  has_line "count" "PASS  DEL-A1  every criterion has evidence (3 checked)"
  run "$REC"; clean "no acceptors listed: any name counts"; has_line "a3-na" "N/A   DEL-A3  every acceptor is listed in the contract (the contract lists no acceptors)"
  run --acceptor ' ANA   lopez ' --acceptor 'SAM-LEE' "$REC"; clean "acceptors match whatever the case and spacing"

  # DEL-A1: evidence.
  row 1 3 ''; run "$REC"; expect_only a1-empty DEL-A1 'criterion 1 has no evidence'
  row 1 3 'TBD'; run "$REC"; expect_only a1-placeholder DEL-A1 'criterion 1 has no evidence'
  row 1 3 '<tests/x.test.js:1>'; run "$REC"; expect_only a1-template DEL-A1 'criterion 1 has no evidence'
  row 1 3 'tests/missing.test.js:4'; run "$REC"; expect_only a1-no-file DEL-A1 'tests/missing.test.js does not exist'
  row 1 3 'tests/draft.test.js:51'; run "$REC"; expect_only a1-past-eof DEL-A1 'tests/draft.test.js has 50 line(s), so line 51 does not exist'
  row 1 3 'tests/draft.test.js:50'; run "$REC"; clean "a1: the last line exists"
  row 1 3 'tests/draft.test.js:40-60'; run "$REC"; expect_only a1-range-past-eof DEL-A1 'line 60 does not exist'
  row 1 3 'tests/draft.test.js:9-3'; run "$REC"; expect_only a1-range-backwards DEL-A1 'names no line'
  row 1 3 'tests/draft.test.js:0'; run "$REC"; expect_only a1-line-zero DEL-A1 'names no line'
  row 1 3 'tests/draft.test.js'; run "$REC"; expect_only a1-no-line DEL-A1 'is neither path:line nor'
  row 1 3 'it works'; run "$REC"; expect_only a1-prose DEL-A1 'is neither path:line nor'
  row 1 3 "$REPO/tests/draft.test.js:3"; run "$REC"; expect_only a1-absolute DEL-A1 'is not a path inside the repository'
  row 1 3 'tests/../../outside.js:1'; run "$REC"; expect_only a1-climbs DEL-A1 'is not a path inside the repository'
  row 1 3 'manual: ok'; run "$REC"; expect_only a1-manual-short DEL-A1 '"manual:" needs what was checked and where'
  row 1 3 'tests/draft.test.js:42; tests/draft.test.js:99'; run "$REC"; expect_only a1-one-bad-item DEL-A1 'line 99 does not exist'
  row 1 3 'tests/draft.test.js:42;'; run "$REC"; clean "a1: an empty item after ; is ignored"
  printf '# Acceptance\n\n| # | Criterion | Evidence | Accepted by | Accepted on |\n|---|---|---|---|---|\n\nNo rows.\n' > "$REPO/$REC"
  run "$REC"; expect_only a1-no-criteria DEL-A1 'the record lists no criteria'

  # DEL-A2: a person, by name, on a date.
  row 2 4 ''; run "$REC"; expect_only a2-no-name DEL-A2 'criterion 2 is not accepted: "Accepted by" is empty'
  row 2 4 '—'; run "$REC"; expect_only a2-dash DEL-A2 'is not accepted'
  row 2 4 '<name>'; run "$REC"; expect_only a2-template DEL-A2 'is not accepted'
  row 2 4 'Claude'; run "$REC"; expect_only a2-claude DEL-A2 'which is not a person'
  row 2 4 'Claude (on behalf of Ana)'; run "$REC"; expect_only a2-on-behalf DEL-A2 'which is not a person'
  row 2 4 'AI assistant'; run "$REC"; expect_only a2-assistant DEL-A2 'which is not a person'
  row 2 4 'Claudette Moreau'; run "$REC"; clean "a2: a name that starts with Claude is a person"
  row 2 5 ''; run "$REC"; expect_only a2-no-date DEL-A2 'criterion 2 has no "Accepted on" date'
  row 2 5 '16/11/2026'; run "$REC"; expect_only a2-date-format DEL-A2 'not a date as YYYY-MM-DD'
  row 2 5 '2026-02-30'; run "$REC"; expect_only a2-date-unreal DEL-A2 'not a date as YYYY-MM-DD'
  row 2 5 '2028-02-29'; run "$REC"; expect_only a2-date-future DEL-A2 'after today'
  row 2 5 '2024-02-29'; run "$REC"; clean "a2: a leap day is a date"
  row 2 5 '2023-02-29'; run "$REC"; expect_only a2-not-leap DEL-A2 'not a date as YYYY-MM-DD'

  # DEL-A3: a listed acceptor.
  good; run --acceptor 'Ana Lopez' "$REC"; expect_only a3-unlisted DEL-A3 'criterion 2 is accepted by sam-lee, who is not among'
  row 2 4 'Claude'; run --acceptor 'Ana Lopez' --acceptor sam-lee "$REC"
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  DEL-A3 ')" = 0 ] && ok || bad "a3: a name that is not a person is DEL-A2 only"

  # --draft: evidence only; the record need not be signed yet.
  row 1 4 ''; run --draft --acceptor 'Ana Lopez' "$REC"; clean "draft: an unsigned record passes"
  has_line "draft-a2" "N/A   DEL-A2  every criterion is accepted by a person, by name and date (--draft: not signed yet)"
  has_line "draft-a3" "N/A   DEL-A3  every acceptor is listed in the contract (--draft: not signed yet)"
  has_line "draft-summary" "0 failure(s) (draft: evidence only)"
  row 1 3 'tests/missing.test.js:1'; run --draft "$REC"; expect_only draft-a1 DEL-A1 'does not exist'

  # Shapes: escaped bars, CRLF, column order, a second table, the line of the finding.
  row 1 2 'Shows a \| in the label'; run "$REC"; clean "an escaped bar stays in its cell"
  good; sed 's/$/\r/' "$REPO/$REC" > "$WORK/crlf" && mv "$WORK/crlf" "$REPO/$REC"; run "$REC"; clean "a CRLF record"
  printf '# A\n\n| Accepted on | Accepted by | Evidence | Criterion |\n|---|---|---|---|\n| 2026-11-16 | Ana | tests/draft.test.js:1 | One |\n\n| Criterion | Evidence | Accepted by | Accepted on |\n|---|---|---|---|\n| Two | | | |\n' > "$REPO/$REC"
  run "$REC"; clean "columns in any order; only the first table is read"
  row 3 3 'tests/nope.js:1'; run "$REC"; has_line "line" "FAIL  DEL-A1  High   $REC:7  criterion 3: tests/nope.js does not exist"
  good; run --root "$REPO" "$REC"; clean "--root"

  # The plugin's template, as shipped, is a draft with no evidence: it fails DEL-A1.
  cp "$TEMPLATE" "$REPO/template.md"; run --draft template.md
  [ "$RC" -eq 1 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  DEL-A1 ')" = 2 ] && ok || bad "template: both placeholder rows fail DEL-A1: $(printf '%s' "$OUT" | tr '\n' ';')"

  # Bad input stops with exit 2; --help prints the usage.
  run nope.md; [ "$RC" -eq 2 ] && ok || bad "a missing record exits 2, got $RC"
  printf '# Not a record\n\n| a | b |\n|---|---|\n| 1 | 2 |\n' > "$REPO/other.md"; run other.md
  [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q 'has no acceptance table' && ok || bad "no acceptance table exits 2: $RC $(printf '%s' "$OUT" | head -1)"
  run; [ "$RC" -eq 2 ] && ok || bad "no record exits 2, got $RC"
  good; run --frobnicate "$REC"; [ "$RC" -eq 2 ] && ok || bad "an unknown option exits 2, got $RC"
  run "$REC" "$REC"; [ "$RC" -eq 2 ] && ok || bad "two records exit 2, got $RC"
  run --root /nonexistent-dir "$REC"; [ "$RC" -eq 2 ] && ok || bad "a missing --root exits 2, got $RC"
  run --acceptor; [ "$RC" -eq 2 ] && ok || bad "--acceptor without a name exits 2, got $RC"
  run --help; [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-acceptance.sh' && ok || bad "--help prints the usage: $RC"
}

realpath_of() {
  local p="$1" l
  while [ -L "$p" ]; do l=$(ls -l "$p" | sed 's/.* -> //'); case "$l" in /*) p="$l" ;; *) p="$(dirname "$p")/$l" ;; esac; done
  printf '%s' "$p"
}
AWKS="default"; SEEN=" $(realpath_of "$(command -v awk)") "
[ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
  p=$(command -v "$a" 2>/dev/null) || continue
  r=$(realpath_of "$p")
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; AWKS="$AWKS $a"
done
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-check-acceptance: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
