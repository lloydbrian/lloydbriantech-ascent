#!/usr/bin/env bash
# Behavior test for plugins/ascent-session/scripts/check-session.sh.
#
# The good fixture (fixtures/session-good: a working memory with dated entries in
# its three sections, a fresh session state ignored by git, a current handoff)
# passes SES-S1–S6. Each check then gets negative controls: a copy broken in exactly
# one way fails that check and no other. SES-S3 and SES-S4 run on throwaway git
# repositories inside this test's temporary folder, with git's global and system
# configuration switched off; the project's repository is never touched. Also
# covers --since, a shallow clone, --require-handoff, prototype maturity and bad
# input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-session: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-session/scripts/check-session.sh"
GOOD="$HERE/fixtures/session-good"
MEM=docs/delivery/working-memory.md; ST=docs/delivery/session-state.md; HO=docs/delivery/HANDOFF.md
for f in "$CHECK" "$GOOD/$MEM" "$GOOD/$ST" "$GOOD/$HO" "$GOOD/.gitignore"; do
  [ -f "$f" ] || { echo "FAIL  test-check-session: missing $f"; echo "test-check-session: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
chk() {  # NAME [ARGS] — no git unless GIT=1
  local n="$1"; shift
  local a=(--today "${TODAY:-2026-11-20}" --maturity "${MATURITY:-enterprise}")
  [ "${GIT:-0}" = 1 ] || a+=(--no-git)
  (cd "$WORK/$n" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" "${a[@]}" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {  # COPY FILE AWK
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
expect_only() {  # NAME CHECK [SEVERITY]
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-session' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-session:' | head -2 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@") >/dev/null 2>&1; }
head_of() { (cd "$WORK/$1" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git log -1 --format=%h); }

matrix() {
  mk good; chk good
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 4 ]; then ok; else bad "good fixture should pass 4 without git: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'it checks that the records are kept, not that they are accurate'
  has good '5 entries, newest 2026-11-12'

  # SES-S1 — the working memory
  mk s1; rm "$WORK/s1/$MEM"; chk s1; expect_only s1 SES-S1 Medium
  has s1 'no working memory: decisions made in one session are lost'
  mk s1-dec; edit s1-dec $MEM "$(subst '## Decisions' '## Choices')" && chk s1-dec && expect_only s1-dec SES-S1 Medium

  # SES-S2 — dated entries in order
  mk s2-undated; edit s2-undated $MEM "$(subst '- 2026-10-09: The catalog' '- The catalog')" && chk s2-undated && expect_only s2-undated SES-S2 Low
  mk s2-fake; edit s2-fake $MEM "$(subst '2026-10-09:' '2026-02-30:')" && chk s2-fake && expect_only s2-fake SES-S2 Low
  has s2-fake 'is dated 2026-02-30, not a real date'
  mk s2-leap; edit s2-leap $MEM "$(subst '- 2026-10-20: A cache' '- 2024-02-29: A cache')" && chk s2-leap && expect_pass s2-leap
  mk s2-noleap; edit s2-noleap $MEM "$(subst '- 2026-10-20: A cache' '- 2025-02-29: A cache')" && chk s2-noleap && expect_only s2-noleap SES-S2 Low
  mk s2-future; edit s2-future $MEM "$(subst '2026-11-12:' '2027-01-02:')" && chk s2-future && expect_only s2-future SES-S2 Low
  mk s2-order; edit s2-order $MEM "$(subst '2026-10-09:' '2026-09-01:')" && chk s2-order && expect_only s2-order SES-S2 Low
  has s2-order 'before the entry above it (2026-10-02)'
  mk s2-sections; edit s2-sections $MEM "$(subst '- 2026-10-20: A cache' '- 2026-09-30: A cache')" && chk s2-sections && expect_pass s2-sections
  mk s2-pattern; edit s2-pattern $MEM "$(subst '- 2026-10-05: Every handler' '- Every handler')" && chk s2-pattern && expect_pass s2-pattern
  mk s2-pattern-fake; edit s2-pattern-fake $MEM "$(subst '2026-10-05:' '2026-13-05:')" && chk s2-pattern-fake && expect_only s2-pattern-fake SES-S2 Low
  mk s2-fence; printf '\n```\n## Decisions\n- not an entry\n```\n' >> "$WORK/s2-fence/$MEM"; chk s2-fence; expect_pass s2-fence

  # SES-S5 — the session state
  mk s5-sec; edit s5-sec $ST "$(subst '## Blockers' '## Problems')" && chk s5-sec && expect_only s5-sec SES-S5 Low
  mk s5-fill; edit s5-fill $ST "$(subst 'None currently.' "(fill in: what's preventing progress, if anything)")" && chk s5-fill && expect_only s5-fill SES-S5 Low
  has s5-fill 'placeholder from make session-snapshot'
  mk s5-nocap; edit s5-nocap $ST "$(drop 'Captured:')" && chk s5-nocap && expect_only s5-nocap SES-S5 Low
  has s5-nocap 'has no "Captured: YYYY-MM-DD" line'
  mk s5-stale; TODAY=2026-11-30 chk s5-stale; expect_only s5-stale SES-S5 Low
  has s5-stale 'captured 12 days ago (max 7)'
  mk s5-age; TODAY=2026-11-30 chk s5-age --max-age 14; expect_pass s5-age
  mk s5-none; rm "$WORK/s5-none/$ST"; chk s5-none; expect_pass s5-none
  has s5-none 'the next session starts cold'

  # SES-S6 — the handoff
  mk s6-old; edit s6-old $HO "$(subst 'Generated: 2026-11-15' 'Generated: 2026-11-01')" && chk s6-old && expect_only s6-old SES-S6 Low
  has s6-old 'before the newest working-memory entry (2026-11-12)'
  mk s6-sec; edit s6-sec $HO "$(subst '## Where to start' '## Start')" && chk s6-sec && expect_only s6-sec SES-S6 Low
  mk s6-nodate; edit s6-nodate $HO "$(drop 'Generated:')" && chk s6-nodate && expect_only s6-nodate SES-S6 Low
  has s6-nodate 'has no "Generated: YYYY-MM-DD" line'
  mk s6-none; rm "$WORK/s6-none/$HO"; chk s6-none; expect_pass s6-none
  chk s6-none --require-handoff; expect_only s6-required SES-S6 Low

  # SES-S3 and SES-S4 — git history and ignore rules, on throwaway repositories
  mkdir -p "$WORK/home"
  mk g; edit g $MEM "$(drop '2026-11-12: Search')" && G g init -q && G g add -A && G g commit -qm first
  printf -- '- 2026-11-12: Search uses Postgres full-text search until it needs more (see ADR-004).\n' > "$WORK/g.add"
  awk -v add="$(cat "$WORK/g.add")" '{ print } /2026-10-09: The catalog/ { print add }' "$WORK/g/$MEM" > "$WORK/g.tmp" && mv "$WORK/g.tmp" "$WORK/g/$MEM" && G g commit -qam appended
  GIT=1 chk g; expect_pass g-appended
  has g-appended 'PASS  SES-S3'
  has g-appended 'PASS  SES-S4'
  edit g $MEM "$(subst 'stored in cents as integers' 'stored in cents')" && GIT=1 chk g && expect_only g-rewritten SES-S3 Medium
  has g-rewritten 'record a correction as a new dated entry'
  G g commit -qam rewritten; GIT=1 chk g; expect_only g-rewritten-committed SES-S3 Medium
  GIT=1 chk g --since "$(head_of g)"; expect_pass g-since
  mk gb; G gb init -q -b main && G gb add -A && GIT_AUTHOR_DATE=2026-11-13T10:00:00 GIT_COMMITTER_DATE=2026-11-13T10:00:00 G gb commit -qm first
  G gb checkout -qb a; awk '{ print } /2026-11-12: Search/ { print "- 2026-11-14: Orders are idempotent by request id." }' "$WORK/gb/$MEM" > "$WORK/gb.tmp" && mv "$WORK/gb.tmp" "$WORK/gb/$MEM"
  GIT_AUTHOR_DATE=2026-11-14T10:00:00 GIT_COMMITTER_DATE=2026-11-14T10:00:00 G gb commit -qam a
  G gb checkout -q main; G gb checkout -qb b; printf -- '- 2026-11-15: A queue for e-mail: rejected, the volume is low.\n' >> "$WORK/gb/$MEM"
  GIT_AUTHOR_DATE=2026-11-15T10:00:00 GIT_COMMITTER_DATE=2026-11-15T10:00:00 G gb commit -qam b
  G gb checkout -q main; G gb merge -q --no-edit a; GIT_AUTHOR_DATE=2026-11-16T10:00:00 GIT_COMMITTER_DATE=2026-11-16T10:00:00 G gb merge -q --no-edit b
  if grep -q 'idempotent' "$WORK/gb/$MEM" && grep -q 'queue for e-mail' "$WORK/gb/$MEM"; then ok; else bad "gb: the branch fixture did not merge both entries"; fi
  GIT=1 chk gb; expect_pass g-branches
  has g-branches 'PASS  SES-S3'
  mk g4; G g4 init -q && G g4 add -A && G g4 add -f "$ST" && G g4 commit -qm first; GIT=1 chk g4; expect_only g4-tracked SES-S4 Medium
  has g4-tracked 'the session state is tracked by git'
  mk g4i; rm "$WORK/g4i/.gitignore"; G g4i init -q; GIT=1 chk g4i; expect_only g4-unignored SES-S4 Medium
  rm -rf "$WORK/g-shallow"; (cd "$WORK" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git clone -q --depth 1 "file://$WORK/g" g-shallow) >/dev/null 2>&1
  GIT=1 chk g-shallow; has g-shallow 'a shallow clone'
  lacks g-shallow 'PASS  SES-S3'
  mk g-none; rm -rf "$WORK/g-none/docs" "$WORK/g-none/.gitignore"; G g-none init -q; GIT=1 chk g-none; expect_only g-none SES-S1 Medium
  has g-none 'no session records yet'

  # Maturity, input
  mk proto; rm "$WORK/proto/$MEM"; MATURITY=prototype chk proto; expect_pass proto
  has proto 'NOTE  SES-S1'
  mk in1; chk in1 --memory ../x.md; expect_rc in1-path 2
  chk in1 --max-age soon; expect_rc in1-age 2
  chk in1 --since 'HEAD~1'; expect_rc in1-since 2
  chk in1 --since 'abcd~12'; expect_rc in1-since-tail 2
  chk in1 --maturity high; expect_rc in1-maturity 2
  GIT=1 chk g --since abcdef1; expect_rc in1-since-missing 2
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

printf "test-check-session: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
