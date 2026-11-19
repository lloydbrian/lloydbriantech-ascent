#!/usr/bin/env bash
# Behavior test for plugins/ascent-adr/scripts/check-adrs.sh.
#
# Three good fixtures, one per format (fixtures/adr-ascent with an index and a
# supersession, fixtures/adr-nygard in adr-tools' layout, fixtures/adr-madr with
# front matter and a README index), pass DEC-S1–S7. Each check then gets negative
# controls: a copy broken in exactly one way fails that check and no other. DEC-S8
# runs on throwaway git repositories inside this test's temporary folder, with git's
# global and system configuration switched off; the project's repository is never
# touched. Also covers the folder search, --style, an acknowledged change,
# prototype maturity and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-adrs: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-adr/scripts/check-adrs.sh"
FX="$HERE/fixtures"
for f in "$CHECK" "$FX/adr-ascent/docs/adr/INDEX.md" "$FX/adr-nygard/doc/adr/0002-keep-decisions-short.md" "$FX/adr-madr/docs/decisions/0001-use-markdown-adrs.md"; do
  [ -f "$f" ] || { echo "FAIL  test-check-adrs: missing $f"; echo "test-check-adrs: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# chk NAME [ARGS] — run on the copy NAME, no git unless GIT=1
chk() {
  local n="$1"; shift
  local a=(--today "${TODAY:-2026-11-20}" --maturity "${MATURITY:-enterprise}")
  [ "${GIT:-0}" = 1 ] || a+=(--no-git)
  (cd "$WORK/$n" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" "${a[@]}" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$FX/$2" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {  # COPY FILE AWK — one edit to one file of the copy
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
expect_only() {  # NAME CHECK [SEVERITY] — after chk
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-adrs' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-adrs:' | head -2 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@") >/dev/null 2>&1; }
A=docs/adr; A1=$A/ADR-001-use-mysql.md; A2=$A/ADR-002-cloudformation-for-infrastructure.md; A3=$A/ADR-003-use-postgresql.md; IDX=$A/INDEX.md
N=doc/adr; N1=$N/0001-record-architecture-decisions.md; N2=$N/0002-keep-decisions-short.md
M=docs/decisions; M1=$M/0001-use-markdown-adrs.md

matrix() {
  for fx in adr-ascent adr-nygard adr-madr; do
    mk good-$fx $fx; chk good-$fx
    if [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL'; then ok; else bad "good $fx should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL' | head -3 | tr '\n' ';')"; fi
    case $fx in
      adr-ascent) has good-$fx 'docs/adr, 3 ADR(s), ascent format'; has good-$fx 'it checks that decisions are recorded and kept, not that they are right' ;;
      adr-nygard) has good-$fx 'doc/adr, 2 ADR(s), nygard format' ;;
      adr-madr) has good-$fx 'docs/decisions, 2 ADR(s), madr format' ;;
    esac
  done

  # DEC-S1 — a decision record exists
  mkdir -p "$WORK/s1-none"; chk s1-none; expect_only s1-none DEC-S1 Medium
  has s1-none 'looked in docs/adr, docs/decisions'
  mkdir -p "$WORK/s1-empty/docs/adr"; chk s1-empty; expect_only s1-empty DEC-S1 Medium
  has s1-empty 'docs/adr holds no ADR'
  # Found by the trial: ADR-NNN files kept in a shared folder, a status and a date
  # on one line, Alternatives without Cost implications, a date in the status line
  adr1() { printf '# %s. %s\n\n%s\n\n## Context\n\nc\n\n## Decision\n\nd\n\n## Alternatives considered\n\na\n\n## Consequences\n\ne\n' "$1" "$2" "$3"; }
  mkdir -p "$WORK/s1-shared/docs"; adr1 1 One '**Date:** 2026-03-25 | **Status:** Accepted' > "$WORK/s1-shared/docs/ADR-0001-one.md"
  adr1 2 Two '**Date:** 2026-03-26 | **Status:** Proposed' > "$WORK/s1-shared/docs/ADR-0002-two.md"; printf '# API\n\nThe endpoints.\n' > "$WORK/s1-shared/docs/API.md"
  chk s1-shared; expect_pass s1-shared
  has s1-shared 'docs, 2 ADR(s), nygard format'
  lacks s1-shared 'API.md'
  mkdir -p "$WORK/s1-single/docs"; adr1 1 One '**Date:** 2026-03-25 | **Status:** Accepted' > "$WORK/s1-single/docs/ADR-0001-one.md"; chk s1-single; expect_only s1-single DEC-S1 Medium
  has s1-single 'and for a folder of ADR-NNN files'
  mkdir -p "$WORK/s7-instatus/docs/adr"; adr1 1 One '## Status

Accepted (2026-07-15)' > "$WORK/s7-instatus/docs/adr/0001-one.md"; chk s7-instatus; expect_pass s7-instatus
  has s7-instatus 'every ADR has a real date (1 checked)'
  # From the review: a folder name with a space, ADRs at the root, "supersedes" in prose
  mkdir -p "$WORK/s1-space/my docs"; adr1 1 One '**Date:** 2026-03-25 | **Status:** Accepted' > "$WORK/s1-space/my docs/ADR-0001-one.md"
  adr1 2 Two '**Date:** 2026-03-26 | **Status:** Accepted' > "$WORK/s1-space/my docs/ADR-0002-two.md"; chk s1-space; expect_pass s1-space
  has s1-space 'my docs, 2 ADR(s)'
  mkdir -p "$WORK/s1-root"; adr1 1 One '**Date:** 2026-03-25 | **Status:** Accepted' > "$WORK/s1-root/ADR-0001-one.md"
  adr1 2 Two '**Date:** 2026-03-26 | **Status:** Accepted' > "$WORK/s1-root/ADR-0002-two.md"; printf '# Project\n' > "$WORK/s1-root/README.md"; chk s1-root; expect_pass s1-root
  has s1-root ', 2 ADR(s), nygard format'
  mk s6-prose adr-ascent; edit s6-prose $A2 '{ print } /^## Context/ { print ""; print "This supersedes the approach we used since 2019, and ADR-3 supersedes nothing here." }' && chk s6-prose && expect_pass s6-prose
  mk s6-hash adr-ascent; edit s6-hash $A2 '{ print } /^## Context/ { print ""; print "It supersedes #9." }' && chk s6-hash && expect_only s6-hash DEC-S6 Medium
  mk s1-adrdir adr-nygard; mv "$WORK/s1-adrdir/doc/adr" "$WORK/s1-adrdir/decisions-log"; printf 'decisions-log\n' > "$WORK/s1-adrdir/.adr-dir"; chk s1-adrdir; expect_pass s1-adrdir
  has s1-adrdir 'decisions-log, 2 ADR(s)'

  # DEC-S2 — sections
  mk s2-cost adr-ascent; edit s2-cost $A2 "$(subst '## Cost implications' '## Costs')" && chk s2-cost && expect_only s2-cost DEC-S2 Medium
  has s2-cost 'ADR-2 is missing "## cost implications"'
  mk s2-madr adr-madr; edit s2-madr $M1 "$(subst '## Considered Options' '## Options')" && chk s2-madr && expect_only s2-madr DEC-S2 Medium
  mk s2-style adr-madr; chk s2-style --style nygard; expect_only s2-style DEC-S2 Medium
  mk s2-fence adr-ascent; edit s2-fence $A2 "$(subst '## Cost implications' '## Costs')" && printf '\n```markdown\n## Cost implications\n```\n' >> "$WORK/s2-fence/$A2" && chk s2-fence && expect_only s2-fence DEC-S2 Medium
  mk s2-nyg adr-nygard; edit s2-nyg $N2 "$(subst '## Consequences' '## Outcome')" && chk s2-nyg && expect_only s2-nyg DEC-S2 Medium

  # DEC-S3 — numbers, names and titles
  mk s3-dup adr-nygard; cp "$WORK/s3-dup/$N2" "$WORK/s3-dup/$N/0002-another.md"; chk s3-dup; expect_only s3-dup DEC-S3 Low
  has s3-dup 'has the same number as'
  mk s3-title adr-nygard; edit s3-title $N2 "$(subst '# 2. Keep' '# 3. Keep')" && chk s3-title && expect_only s3-title DEC-S3 Low
  mk s3-notitle adr-nygard; edit s3-notitle $N2 "$(subst '# 2. Keep decisions short' 'Keep decisions short')" && chk s3-notitle && expect_only s3-notitle DEC-S3 Low
  mk s3-name adr-nygard; printf '# Notes\n' > "$WORK/s3-name/$N/notes.md"; chk s3-name; expect_only s3-name DEC-S3 Low
  has s3-name 'not named NNNN-title.md'
  mk s3-tpl adr-nygard; printf '# Template\n' > "$WORK/s3-tpl/$N/0000-template.md"; chk s3-tpl; expect_pass s3-tpl

  # DEC-S4 — the index
  mk s4-row adr-ascent; edit s4-row $IDX "$(drop '[002](')" && chk s4-row && expect_only s4-row DEC-S4 Low
  has s4-row 'ADR-2 (ADR-002-cloudformation-for-infrastructure.md) is not in the index'
  mk s4-orphan adr-ascent; printf '| [009](ADR-009-gone.md) | Gone | Accepted | 2026-04-01 | - |\n' >> "$WORK/s4-orphan/$IDX"; chk s4-orphan; expect_only s4-orphan DEC-S4 Low
  mk s4-status adr-ascent; edit s4-status $IDX "$(subst 'infrastructure | Accepted |' 'infrastructure | Deprecated |')" && chk s4-status && expect_only s4-status DEC-S4 Low
  has s4-status 'the index says deprecated for ADR-002'
  mk s4-readme adr-madr; edit s4-readme $M/README.md "$(drop '0002-use-yarn')" && chk s4-readme && expect_only s4-readme DEC-S4 Low

  # DEC-S5 — status
  mk s5-unknown adr-nygard; edit s5-unknown $N2 "$(subst 'Accepted' 'Agreed')" && chk s5-unknown && expect_only s5-unknown DEC-S5 Medium
  mk s5-none adr-madr; edit s5-none $M1 "$(drop 'status: accepted')" && chk s5-none && expect_only s5-none DEC-S5 Medium
  has s5-none 'ADR-1 has no status'

  # DEC-S6 — supersession both ways
  mk s6-back adr-ascent; edit s6-back $A3 "$(subst 'This ADR supersedes ADR-001: Use MySQL for persistent data. ' '')" && chk s6-back && expect_only s6-back DEC-S6 Medium
  has s6-back 'but ADR-3 does not say it supersedes ADR-1'
  mk s6-missing adr-ascent; edit s6-missing $A1 "$(subst 'Superseded by ADR-003' 'Superseded by ADR-009')" && edit s6-missing $IDX "$(subst 'Superseded by ADR-003' 'Superseded by ADR-009')" && chk s6-missing && expect_only s6-missing DEC-S6 Medium
  has s6-missing 'is superseded by ADR-9, which does not exist'
  mk s6-active adr-nygard; edit s6-active $N1 "$(subst 'Superseded by [2. Record decisions in MADR-free plain form](0002-keep-decisions-short.md)' 'Accepted')" && chk s6-active && expect_only s6-active DEC-S6 Medium
  has s6-active 'but ADR-1 is still accepted'
  mk s6-nonum adr-nygard; edit s6-nonum $N1 "$(subst 'Superseded by [2. Record decisions in MADR-free plain form](0002-keep-decisions-short.md)' 'Superseded')" && chk s6-nonum && expect_only s6-nonum DEC-S6 Medium
  has s6-nonum 'its status names no replacement'
  mk s6-ghost adr-nygard; printf '\nThis also supersedes ADR-7.\n' >> "$WORK/s6-ghost/$N2"; chk s6-ghost; expect_only s6-ghost DEC-S6 Medium
  has s6-ghost 'ADR-2 supersedes ADR-7, which does not exist'
  mk s6-proposed adr-nygard; edit s6-proposed $N1 "$(subst 'Superseded by [2. Record decisions in MADR-free plain form](0002-keep-decisions-short.md)' 'Accepted')" && edit s6-proposed $N2 "$(subst 'Accepted' 'Proposed')" && chk s6-proposed && expect_pass s6-proposed

  # DEC-S7 — dates
  mk s7-none adr-ascent; edit s7-none $A2 "$(drop '**Date:**')" && chk s7-none && expect_only s7-none DEC-S7 Low
  has s7-none 'ADR-2 has no date'
  mk s7-fake adr-madr; edit s7-fake $M1 "$(subst 'date: 2025-09-03' 'date: 2025-02-30')" && chk s7-fake && expect_only s7-fake DEC-S7 Low
  mk s7-future adr-nygard; edit s7-future $N2 "$(subst 'Date: 2025-07-15' 'Date: 2027-01-05')" && chk s7-future && expect_only s7-future DEC-S7 Low
  mk s7-leap adr-madr; edit s7-leap $M1 "$(subst 'date: 2025-09-03' 'date: 2024-02-29')" && chk s7-leap && expect_pass s7-leap

  # DEC-S8 — accepted bodies unchanged, on throwaway git repositories
  mkdir -p "$WORK/home"
  mk s8 adr-ascent; edit s8 $A2 "$(subst '**Status:** Accepted' '**Status:** Proposed')"
  G s8 init -q && G s8 add -A && G s8 commit -qm proposed
  edit s8 $A2 "$(subst 'one way to do it.' 'one way to do it, reviewed.')" && G s8 commit -qam 'proposed, edited'
  edit s8 $A2 "$(subst '**Status:** Proposed' '**Status:** Accepted')" && G s8 commit -qam accepted
  GIT=1 chk s8; expect_pass s8-clean
  lacks s8-clean 'N/A   DEC-S8'
  edit s8 $A2 "$(subst 'Time: two weeks.' 'Time: three weeks.')" && GIT=1 chk s8 && expect_only s8-edited DEC-S8 Medium
  has s8-edited 'ADR-2 was accepted in'
  G s8 commit -qam 'edited after acceptance'; ACKC=$( (cd "$WORK/s8" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git log -1 --format=%h) )
  GIT=1 chk s8 --acknowledge "ADR-002=$ACKC"; expect_pass s8-ack
  has s8-ack "changes up to $ACKC are acknowledged"
  edit s8 $A2 "$(subst 'Money: no direct cost.' 'Money: a licence.')" && GIT=1 chk s8 --acknowledge "ADR-2=$ACKC" && expect_only s8-ack-later DEC-S8 Medium
  mk s8-status adr-ascent; G s8-status init -q && G s8-status add -A && G s8-status commit -qm first
  edit s8-status $A2 "$(subst '**Status:** Accepted' '**Status:** Accepted, reaffirmed 2026-06-01')" && GIT=1 chk s8-status && expect_pass s8-status-only
  has s8-status-only 'PASS  DEC-S8'
  edit s8-status $A2 "$(subst 'two weeks' 'two days')" && GIT=1 chk s8-status && expect_only s8-status-and-body DEC-S8 Medium
  mk s8-untracked adr-ascent; G s8-untracked init -q; GIT=1 chk s8-untracked; has s8-untracked 'N/A   DEC-S8'
  lacks s8-untracked 'PASS  DEC-S8'
  mk s8-nogit adr-ascent; GIT=1 chk s8-nogit; has s8-nogit 'N/A   DEC-S8'
  rm -rf "$WORK/s8-shallow"; (cd "$WORK" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git clone -q --depth 1 "file://$WORK/s8" s8-shallow) >/dev/null 2>&1
  GIT=1 chk s8-shallow; has s8-shallow 'a shallow clone'
  lacks s8-shallow 'PASS  DEC-S8'

  # Maturity, input
  mk proto adr-ascent; edit proto $A2 "$(subst '## Cost implications' '## Costs')" && MATURITY=prototype chk proto && expect_pass proto
  has proto 'NOTE  DEC-S2'
  mk in1 adr-ascent; chk in1 --style yaml; expect_rc in1 2
  chk in1 --dir ../elsewhere; expect_rc in1-dir 2
  chk in1 --today 2026-1-1; expect_rc in1-today 2
  chk in1 --acknowledge ADR-2; expect_rc in1-ack 2
  chk in1 --index docs/adr/NOPE.md; expect_rc in1-index 2
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

printf "test-check-adrs: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
