#!/usr/bin/env bash
# Behavior test for the review log of plugins/ascent-governance/scripts/check-audit.sh
# (GOV-R1–R4) and for --launch.
#
# A review that needs Claude's reading leaves one dated row in the review log.
# A floor names the reviews it needs and how old each may be. A current row
# with a strong rating passes. Each rule then gets negative controls: a log
# broken in exactly one way fails that rule and no other. Also covers the age
# edges (30 days is current, 31 is not), --launch (a review that is due stops a
# launch; in CI it is a condition), open High findings and the waivers that
# cover them, rows that cannot be read, and rows lost or changed in the git
# history, on throwaway repositories.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-review-log: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-review-log
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
need "$CHECK" "$PLUGIN/scripts/lib/audit.awk" "$FIX/stub-checker.sh"
LOG=docs/governance/review-log.md
HEAD_ROW='| Date | Review | Commit | Rating | High | Medium | Low | Open High rules | Asked by |'

# base NAME — a ladder of three, a beta floor that needs sec-posture within 30 days
base() {
  stubs; rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1/docs/adr" "$WORK/$1/docs/governance" "$WORK/$1/.ascent"
  printf '# ADR-021: Accept the open redirect\n\n**Status:** Accepted\n' > "$WORK/$1/docs/adr/ADR-021-open-redirect.md"
  cat > "$WORK/$1/$CON" <<'EOC'
version: 1
governance:
  environments: [local, beta, prod]
  floors:
    local:
      checks: [ascent-security/check-env]
    beta:
      reviews: { sec-posture: 30 }
    prod:
      reviews: { sec-posture: 10, ux-review: 60 }
decisions:
  dir: docs/adr/
EOC
}
# rows NAME ROW... — the review log with these rows
rows() {
  local n="$1" r; shift
  { printf '# Review log\n\nOne row for each review. Rows are only added.\n\n%s\n|---|---|---|---|---|---|---|---|---|\n' "$HEAD_ROW"
    for r in "$@"; do printf '%s\n' "$r"; done; } > "$WORK/$n/$LOG"
}
rv() { local n="$1"; shift; base "$n"; rows "$n" "$@"; }
waiver() {  # NAME SKIPS REVIEW_BY
  printf 'security:\n  waivers:\n    - id: ADR-021\n      skips: %s\n      review_by: %s\n' "$2" "$3" >> "$WORK/$1/$CON"
}
copy() { rm -rf "${WORK:?}/$2"; cp -R "$WORK/$1" "$WORK/$2"; }
GOOD='| 2026-11-28 | sec-posture | 1a2b3c4 | strong | 0 | 1 | 2 | - | operator |'
both() { printf '%s\n' "$OUT" | grep -q "^FAIL  $2 " && printf '%s\n' "$OUT" | grep -q "^FAIL  $3 " && ok || bad "$1: expected both $2 and $3: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | tr '\n' ';')"; }

matrix() {
  # a current review
  rv current "$GOOD"; chk current --env beta; expect_pass current; has current 'check-audit: beta: GO, '
  has current 'PASS  GOV-R1  sec-posture: strong on 2026-11-28 at 1a2b3c4, 4 days old (max 30)'
  has current 'PASS  GOV-R3'; has current 'N/A   GOV-R4'
  chk current --env local; expect_pass not-on-rung; lacks not-on-rung 'sec-posture'
  chk current --env beta --launch; expect_pass current-launch
  # a floor with no reviews does not read the log
  rv no-reviews-on-rung '| 2026-11-28 | sec-posture | zzz | good | 0 | 0 | 0 | - | operator |'; chk no-reviews-on-rung --env local; expect_pass no-reviews-on-rung; lacks no-reviews-on-rung 'GOV-R'

  # GOV-R1: the age edges, and --launch
  rv r1-edge-30 '| 2026-11-02 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'; chk r1-edge-30 --env beta; expect_pass r1-edge-30; has r1-edge-30 '30 days old (max 30)'
  rv r1-edge-31 '| 2026-11-01 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'; chk r1-edge-31 --env beta; expect_only r1-edge-31 GOV-R1 Medium
  has r1-edge-31 '31 days old (max 30)'; has r1-edge-31 'GO WITH CONDITIONS'; has r1-edge-31 'docs/governance/review-log.md:7'
  chk r1-edge-31 --env beta --launch; expect_only r1-launch GOV-R1 High; has r1-launch 'NO-GO'
  rv r1-missing-row '| 2026-11-28 | ux-review | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'; chk r1-missing-row --env beta; expect_only r1-missing-row GOV-R1 Medium
  has r1-missing-row 'sec-posture has no review record'
  chk r1-missing-row --env beta --launch; expect_only r1-missing-launch GOV-R1 High
  base r1-no-log; chk r1-no-log --env beta; expect_only r1-no-log GOV-R1 Medium; has r1-no-log 'N/A   GOV-R3'
  rv r1-newest-wins '| 2026-09-01 | sec-posture | 1a2b3c4 | weak | 3 | 0 | 0 | SEC-L4 | operator |' "$GOOD"; chk r1-newest-wins --env beta; expect_pass r1-newest-wins
  rv r1-newest-by-date "$GOOD" '| 2026-09-01 | sec-posture | 1a2b3c4 | weak | 3 | 0 | 0 | SEC-L4 | operator |'; chk r1-newest-by-date --env beta; expect_pass r1-newest-by-date
  rv r1-same-day '| 2026-11-28 | sec-posture | 1a2b3c4 | weak | 0 | 4 | 0 | - | operator |' "$GOOD"; chk r1-same-day --env beta; expect_pass r1-same-day

  # a higher rung may ask for a newer review, and for more reviews
  rv r1-tightened '| 2026-11-20 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |' '| 2026-11-01 | ux-review | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'
  chk r1-tightened --env beta; expect_pass r1-tightened-beta; lacks r1-tightened-beta 'ux-review'
  chk r1-tightened --env prod; expect_only r1-tightened GOV-R1 Medium; has r1-tightened '12 days old (max 10)'; has r1-tightened 'PASS  GOV-R1  ux-review'

  # a higher rung cannot loosen what a lower rung asks for
  rv r1-looser-above '| 2026-10-23 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |' '| 2026-11-28 | ux-review | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'
  edit r1-looser-above $CON "$(subst 'sec-posture: 10' 'sec-posture: 60')" && chk r1-looser-above --env prod && expect_only r1-looser-above GOV-R1 Medium
  has r1-looser-above '40 days old (max 30)'

  # GOV-R2: open High findings, and the waivers that cover them
  HIGH='| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 1 | 0 | 0 | SEC-L4 | operator |'
  rv r2-open-high "$HIGH"; chk r2-open-high --env beta; expect_only r2-open-high GOV-R2 High; has r2-open-high 'SEC-L4'; has r2-open-high 'NO-GO'
  rv r2-waived "$HIGH"; waiver r2-waived 'SEC-L4 on the legacy redirect' 2027-03-31; chk r2-waived --env beta; expect_pass r2-waived; has r2-waived 'SEC-L4 waived'
  rv r2-partly-waived '| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 2 | 0 | 0 | SEC-L4 UX-F2 | operator |'; waiver r2-partly-waived 'SEC-L4 on the legacy redirect' 2027-03-31
  chk r2-partly-waived --env beta; expect_only r2-partly-waived GOV-R2 High; has r2-partly-waived 'UX-F2'
  rv r2-commas '| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 2 | 0 | 0 | SEC-L4, SEC-L5 | operator |'; waiver r2-commas '"SEC-L4 and SEC-L5, both on the legacy redirect"' 2027-03-31
  chk r2-commas --env beta; expect_pass r2-commas
  rv r2-not-whole-word "$HIGH"; waiver r2-not-whole-word 'SEC-L40 and XSEC-L4 and SEC-L4-old' 2027-03-31; chk r2-not-whole-word --env beta; expect_only r2-not-whole-word GOV-R2 High
  rv r2-expired-waiver "$HIGH"; waiver r2-expired-waiver 'SEC-L4 on the legacy redirect' 2026-11-30; chk r2-expired-waiver --env beta; both r2-expired-waiver GOV-R2 GOV-W1; expect_rc r2-expired-waiver 1
  rv r2-undated-waiver "$HIGH"; printf 'security:\n  waivers:\n    - id: ADR-021\n      skips: SEC-L4\n' >> "$WORK/r2-undated-waiver/$CON"; chk r2-undated-waiver --env beta; expect_only r2-undated-waiver GOV-W3 Medium
  rv r2-weak-no-high '| 2026-11-28 | sec-posture | 1a2b3c4 | weak | 0 | 6 | 2 | - | operator |'; chk r2-weak-no-high --env beta; expect_only r2-weak-no-high GOV-R2 Medium; has r2-weak-no-high 'GO WITH CONDITIONS'
  rv r2-weak-waived '| 2026-11-28 | sec-posture | 1a2b3c4 | weak | 1 | 0 | 0 | SEC-L4 | operator |'; waiver r2-weak-waived 'SEC-L4 on the legacy redirect' 2027-03-31
  chk r2-weak-waived --env beta; expect_only r2-weak-waived GOV-R2 Medium
  rv r2-high-no-rules '| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 2 | 0 | 0 | - | operator |'; chk r2-high-no-rules --env beta; expect_only r2-high-no-rules GOV-R2 High; has r2-high-no-rules 'names no rule'
  # every High finding names its rule: a count above the rules named leaves a finding no waiver was asked to cover
  rv r2-fewer-rules '| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 2 | 0 | 0 | SEC-L4 | operator |'; waiver r2-fewer-rules 'SEC-L4 on the legacy redirect' 2027-03-31
  chk r2-fewer-rules --env beta; expect_only r2-fewer-rules GOV-R2 High; has r2-fewer-rules 'lists 2 High findings and names 1 rule'
  rv r2-same-rule-twice '| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 2 | 0 | 0 | SEC-L4 SEC-L4 | operator |'; waiver r2-same-rule-twice 'SEC-L4 on the legacy redirect' 2027-03-31
  chk r2-same-rule-twice --env beta; expect_pass r2-same-rule-twice
  rv r2-tab-in-cell "$(printf '| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 2 | 0 | 0 | SEC-L4\tUX-F2 | operator |')"; waiver r2-tab-in-cell 'SEC-L4 on the legacy redirect' 2027-03-31
  chk r2-tab-in-cell --env beta; expect_only r2-tab-in-cell GOV-R2 High; has r2-tab-in-cell 'UX-F2'
  # a waiver whose review date is not a date covers nothing
  rv r2-unreal-waiver "$HIGH"; waiver r2-unreal-waiver 'SEC-L4 on the legacy redirect' 2027-02-30; chk r2-unreal-waiver --env beta; both r2-unreal-waiver GOV-R2 GOV-W3; expect_rc r2-unreal-waiver 1
  rv r2-stale-open-high '| 2026-10-01 | sec-posture | 1a2b3c4 | moderate | 1 | 0 | 0 | SEC-L4 | operator |'; chk r2-stale-open-high --env beta; both r2-stale-open-high GOV-R1 GOV-R2; expect_rc r2-stale-open-high 1

  # GOV-R3: a row that cannot be read never counts as current
  for bad_row in 'r3-future|| 2026-12-03 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |' \
                 'r3-unreal|| 2026-02-30 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |' \
                 'r3-rating|| 2026-11-28 | sec-posture | 1a2b3c4 | good | 0 | 0 | 0 | - | operator |' \
                 'r3-commit|| 2026-11-28 | sec-posture | 12345 | strong | 0 | 0 | 0 | - | operator |' \
                 'r3-commit-word|| 2026-11-28 | sec-posture | pending | strong | 0 | 0 | 0 | - | operator |' \
                 'r3-count|| 2026-11-28 | sec-posture | 1a2b3c4 | strong | two | 0 | 0 | - | operator |' \
                 'r3-short|| 2026-11-28 | sec-posture | 1a2b3c4 | strong | 0 | 0 |' \
                 'r3-no-review|| 2026-11-28 |  | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'; do
    n="${bad_row%%||*}"; rv "$n" "| ${bad_row#*|| }"; chk "$n" --env beta; both "$n" GOV-R3 GOV-R1; expect_rc "$n" 0
    has "$n" 'FAIL  GOV-R3  Medium docs/governance/review-log.md:7'
  done
  chk r3-short --env beta; has r3-short '6 cells, not 9'
  rv r3-extra-cell '| 2026-11-28 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator | a note |'; chk r3-extra-cell --env beta; both r3-extra-cell GOV-R3 GOV-R1; has r3-extra-cell '10 cells, not 9'
  rv r3-long-commit '| 2026-11-28 | sec-posture | 1a2b3c4d5e6f7a8b9c0d1a2b3c4d5e6f7a8b9c0d | strong | 0 | 0 | 0 | - | operator |'; chk r3-long-commit --env beta; expect_pass r3-long-commit
  rv r3-other-review "$GOOD" '| 2026-11-28 | docs-review | zzz | strong | 0 | 0 | 0 | - | operator |'; chk r3-other-review --env beta; expect_only r3-other-review GOV-R3 Medium
  rv r3-older-valid "$GOOD" '| 2026-11-30 | sec-posture | 1a2b3c4 | excellent | 0 | 0 | 0 | - | operator |'; chk r3-older-valid --env beta; both r3-older-valid GOV-R3 GOV-R1
  # the newest row of a review cannot be read: the older record does not stand in for it
  has r3-older-valid 'FAIL  GOV-R1  Medium docs/governance/review-log.md:8'; has r3-older-valid 'a newer row of sec-posture (line 8) cannot be read'; expect_rc r3-older-valid 0
  chk r3-older-valid --env beta --launch; expect_rc r3-older-valid-launch 1; has r3-older-valid-launch 'FAIL  GOV-R1  High'
  rv r3-newer-valid '| 2026-11-20 | sec-posture | 1a2b3c4 | excellent | 0 | 0 | 0 | - | operator |' "$GOOD"; chk r3-newer-valid --env beta; expect_only r3-newer-valid GOV-R3 Medium
  rv r3-above-unreal-date '| 2026-11-31 | sec-posture | 1a2b3c4 | weak | 1 | 0 | 0 | SEC-L4 | operator |' "$GOOD"; chk r3-above-unreal-date --env beta; expect_only r3-above-unreal-date GOV-R3 Medium
  rv r3-newer-unreal-date "$GOOD" '| 2026-11-31 | sec-posture | 1a2b3c4 | weak | 1 | 0 | 0 | SEC-L4 | operator |'; chk r3-newer-unreal-date --env beta; both r3-newer-unreal-date GOV-R3 GOV-R1
  # a line that is not a row does not end the table: a row below it is read, never dropped
  WEAK='| 2026-11-30 | sec-posture | 1a2b3c4 | weak | 1 | 0 | 0 | SEC-L4 | operator |'
  rv r3-blank-line "$GOOD" '' "$WEAK"; chk r3-blank-line --env beta; expect_only r3-blank-line GOV-R2 High; has r3-blank-line '(2 rows)'
  rv r3-prose-between "$GOOD" 'A note someone added by hand.' "$WEAK"; chk r3-prose-between --env beta; expect_only r3-prose-between GOV-R2 High
  rv r3-second-header "$GOOD" '' "$HEAD_ROW" '|---|---|---|---|---|---|---|---|---|' '| 2026-11-30 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'
  chk r3-second-header --env beta; expect_pass r3-second-header; has r3-second-header '(2 rows)'; has r3-second-header 'strong on 2026-11-30'
  rv r3-other-table "$GOOD" '' '| Term | Meaning |' '|---|---|' '| strong | no High finding |'; chk r3-other-table --env beta; expect_only r3-other-table GOV-R3 Medium; has r3-other-table '2 cells, not 9'
  base r3-no-table; printf '# Review log\n\nsec-posture was run on 2026-11-28 and was strong.\n' > "$WORK/r3-no-table/$LOG"; chk r3-no-table --env beta; both r3-no-table GOV-R3 GOV-R1
  has r3-no-table 'has no table with the columns'

  # the table, as people write it
  base table-loose
  printf '# Review log\n\n| Other | Table |\n|---|---|\n| 2026-11-28 | sec-posture |\n\n|DATE|review|Commit|Rating|High|Medium|Low|Open high rules|Asked By|\n|:---|:---|:---|:---|---:|---:|---:|:---|:---|\n|2026-11-28|sec-posture|1A2B3C4|Strong|0|1|2||operator|\r\n\nNotes after the table.\n\n| 2020-01-01 | sec-posture | zzz | weak | 9 | 0 | 0 | X-Y1 | nobody |\n' > "$WORK/table-loose/$LOG"
  # the row under the note is still a row of the log: it is reported as one that cannot be read, and it is older, so the record stands
  chk table-loose --env beta; expect_only table-loose GOV-R3 Medium; has table-loose 'PASS  GOV-R1  sec-posture: strong on 2026-11-28'; has table-loose "review-log.md:13"
  rv table-custom-path "$GOOD"; mkdir -p "$WORK/table-custom-path/my docs"; mv "$WORK/table-custom-path/$LOG" "$WORK/table-custom-path/my docs/reviews.md"
  edit table-custom-path $CON '{ print } /^  environments:/ { print "  review_log: \"my docs/reviews.md\"" }' && chk table-custom-path --env beta && expect_pass table-custom-path

  # GOV-R4: rows are only added, in the git history
  rv r4 "$GOOD" '| 2026-10-01 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |'
  G r4 init -q; G r4 add -A; G r4 commit -q -m one
  GIT=1 chk r4 --env beta; expect_pass r4-committed; has r4-committed 'PASS  GOV-R4'
  printf '| 2026-12-01 | sec-posture | 2b3c4d5 | strong | 0 | 0 | 0 | - | operator |\n' >> "$WORK/r4/$LOG"
  GIT=1 chk r4 --env beta; expect_pass r4-appended-uncommitted
  G r4 add -A; G r4 commit -q -m two; GIT=1 chk r4 --env beta; expect_pass r4-appended; has r4-appended 'PASS  GOV-R4'
  copy r4 r4-row-removed; edit r4-row-removed $LOG "$(drop '| 2026-10-01 |')" && G r4-row-removed add -A && G r4-row-removed commit -q -m drop
  GIT=1 chk r4-row-removed --env beta; expect_only r4-row-removed GOV-R4 Medium; has r4-row-removed '2026-10-01'
  copy r4 r4-row-edited; edit r4-row-edited $LOG "$(subst '| 2026-11-28 | sec-posture | 1a2b3c4 | strong | 0 | 1 | 2 |' '| 2026-11-28 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 |')" && G r4-row-edited add -A && G r4-row-edited commit -q -m edit
  GIT=1 chk r4-row-edited --env beta; expect_only r4-row-edited GOV-R4 Medium
  copy r4 r4-uncommitted-removal; edit r4-uncommitted-removal $LOG "$(drop '| 2026-10-01 |')" && GIT=1 chk r4-uncommitted-removal --env beta && expect_only r4-uncommitted-removal GOV-R4 Medium
  copy r4 r4-restored; edit r4-restored $LOG "$(drop '| 2026-10-01 |')" && G r4-restored add -A && G r4-restored commit -q -m drop
  printf '| 2026-10-01 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |\n' >> "$WORK/r4-restored/$LOG"; G r4-restored add -A; G r4-restored commit -q -m restore
  GIT=1 chk r4-restored --env beta; expect_only r4-restored GOV-R4 Medium
  copy r4 r4-spacing; edit r4-spacing $LOG "$(subst '| 2026-10-01 | sec-posture | 1a2b3c4 | strong |' '|  2026-10-01  | sec-posture |1a2b3c4| strong |')" && G r4-spacing add -A && G r4-spacing commit -q -m align
  GIT=1 chk r4-spacing --env beta; expect_pass r4-spacing
  # rows added on two branches, then merged
  copy r4 r4-branches; G r4-branches checkout -q -b side
  printf '| 2026-12-02 | ux-review | 3c4d5e6 | strong | 0 | 0 | 0 | - | operator |\n' >> "$WORK/r4-branches/$LOG"; G r4-branches add -A; G r4-branches commit -q -m side
  G r4-branches checkout -q main; printf '\nA note.\n' >> "$WORK/r4-branches/README.md"; G r4-branches add -A; G r4-branches commit -q -m main-other
  G r4-branches merge -q --no-ff -m merge side
  G r4-branches checkout -q -b side2 HEAD~1; printf '| 2026-12-02 | docs-review | 4d5e6f7 | strong | 0 | 0 | 0 | - | operator |\n' >> "$WORK/r4-branches/$LOG"; G r4-branches add -A; G r4-branches commit -q -m side2
  G r4-branches checkout -q main; G r4-branches merge -q --no-ff -m merge2 -X union side2 || { cat "$WORK/r4/$LOG" > "$WORK/r4-branches/$LOG"; printf '| 2026-12-02 | ux-review | 3c4d5e6 | strong | 0 | 0 | 0 | - | operator |\n| 2026-12-02 | docs-review | 4d5e6f7 | strong | 0 | 0 | 0 | - | operator |\n' >> "$WORK/r4-branches/$LOG"; G r4-branches add -A; G r4-branches commit -q -m merge2; }
  if grep -q 'ux-review' "$WORK/r4-branches/$LOG" && grep -q 'docs-review' "$WORK/r4-branches/$LOG"; then ok; else bad "r4-branches: the merge did not keep both rows"; fi
  GIT=1 chk r4-branches --env beta; expect_pass r4-branches; has r4-branches 'PASS  GOV-R4'
  # where the history cannot be read
  chk r4 --env beta; expect_pass r4-no-git; has r4-no-git 'N/A   GOV-R4'; has r4-no-git '--no-git'
  rm -rf "$WORK/r4-shallow"; (cd "$WORK" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git clone -q --depth 1 "file://$WORK/r4-row-removed" r4-shallow) >/dev/null 2>&1
  GIT=1 chk r4-shallow --env beta; expect_pass r4-shallow; has r4-shallow 'N/A   GOV-R4'; has r4-shallow 'a shallow clone'
  rv r4-untracked "$GOOD"; G r4-untracked init -q; printf 'x\n' > "$WORK/r4-untracked/README.md"; G r4-untracked add README.md; G r4-untracked commit -q -m one
  GIT=1 chk r4-untracked --env beta; expect_pass r4-untracked; has r4-untracked 'N/A   GOV-R4'; has r4-untracked 'not tracked'
  rv r4-not-a-repo "$GOOD"; (cd "$WORK/r4-not-a-repo" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$WORK" STUB_LOG="$WORK/log" STUB_CTL="$WORK/ctl" GITHUB_STEP_SUMMARY= bash "$CHECK" --plugins "$WORK/stubs" --today 2026-12-02 --env beta .) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  expect_pass r4-not-a-repo; has r4-not-a-repo 'N/A   GOV-R4'; has r4-not-a-repo 'not a git repository'
}
run_matrix
