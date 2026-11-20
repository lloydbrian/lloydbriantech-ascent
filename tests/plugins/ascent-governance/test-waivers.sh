#!/usr/bin/env bash
# Behavior test for the waiver view of plugins/ascent-governance/scripts/check-audit.sh
# (GOV-W1–W4, scripts/lib/audit.awk).
#
# A waiver is an entry of any section's waivers list in the contract. A good one
# (an accepted ADR, what it skips, a review date more than 14 days away) passes.
# Each rule then gets negative controls: a waiver broken in exactly one way
# fails that rule and no other. Also covers the 14-day and today edges, ADR
# files in three styles, a section's own ADR folder, waivers in five sections,
# acknowledged changes (listed, never expired), and text that would break a
# table.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-waivers: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-waivers
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
need "$CHECK" "$PLUGIN/scripts/lib/audit.awk" "$FIX/stub-checker.sh"

adr() { printf '# %s: %s\n\n%s\n\n## Context\n\nWhy.\n' "$2" "$3" "$4" > "$WORK/$1/$5"; }
# base NAME — a repository with ADRs in three styles, and the contract's head
base() {
  stubs; rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1/docs/adr" "$WORK/$1/.ascent"
  adr "$1" ADR-021 'Keep lodash in the build tool' '**Status:** Accepted' docs/adr/ADR-021-keep-lodash.md
  adr "$1" ADR-022 'Admin pages are internal' '**Status:** Accepted (amended 2026-10-01)' docs/adr/ADR-022-admin-pages.md
  adr "$1" ADR-023 'Skip the drill' '**Status:** Proposed' docs/adr/ADR-023-skip-the-drill.md
  printf '# 24. No mutation tests yet\n\n## Status\n\nAccepted\n\n## Context\n\nWhy.\n' > "$WORK/$1/docs/adr/0024-no-mutation-tests.md"
  adr "$1" ADR-025 'Old waiver' '**Status:** Superseded by ADR-026' docs/adr/ADR-025-old-waiver.md
  printf -- '---\nstatus: accepted\ndate: 2026-10-01\n---\n# No offline mode\n' > "$WORK/$1/docs/adr/0027-no-offline-mode.md"
  adr "$1" ADR-028 'Later' '**Status:** Proposed, to be accepted after the audit' docs/adr/ADR-028-later.md
  cat > "$WORK/$1/$CON" <<'EOC'
version: 1
governance:
  environments: [local]
  floors:
    local:
      checks: [ascent-security/check-env]
decisions:
  dir: docs/adr/
EOC
}
# one NAME ID REVIEW_BY [SKIPS] — the base with one security waiver
one() {
  base "$1"
  { printf 'security:\n  waivers:\n'; [ -n "$2" ] && printf '    - id: %s\n' "$2" || printf '    - owner: operator\n'
    printf '      skips: %s\n' "${4:-SEC-D7 for lodash 4.17.15 in a build-time tool}"; [ -n "$3" ] && printf '      review_by: %s\n' "$3"; } >> "$WORK/$1/$CON"
}

matrix() {
  # no waivers
  base none; chk none; expect_pass none; has none 'N/A   GOV-W1  the contract has no waivers'; lacks none 'NOTE  waiver'; has none 'check-audit: local: GO, '
  base none-empty; printf 'security:\n  waivers: []\nux:\n  waivers: []\n' >> "$WORK/none-empty/$CON"; chk none-empty; expect_pass none-empty; has none-empty 'N/A   GOV-W1'

  # a good waiver
  one good ADR-021 2027-03-31; chk good; expect_pass good; has good 'check-audit: local: GO, '
  for k in 1 2 3 4; do has good "PASS  GOV-W$k"; done
  has good 'NOTE  waiver security ADR-021: SEC-D7 for lodash 4.17.15 in a build-time tool; review by 2027-03-31 (119 days left)'

  # GOV-W1: past its review date
  one w1-expired ADR-021 2026-12-01; chk w1-expired; expect_only w1-expired GOV-W1 High; has w1-expired 'NO-GO'
  has w1-expired 'expired 1 day ago'; has w1-expired '.ascent/contract.yml:11'; has w1-expired '(expired)'
  one w1-long-expired ADR-021 2026-11-02; chk w1-long-expired; expect_only w1-long-expired GOV-W1 High; has w1-long-expired 'expired 30 days ago'
  one w1-last-year ADR-021 2025-12-02; chk w1-last-year; expect_only w1-last-year GOV-W1 High; has w1-last-year 'expired 365 days ago'

  # GOV-W2: due within 14 days; today is day 0 and not expired
  one w1-today ADR-021 2026-12-02; chk w1-today; expect_only w1-today GOV-W2 Low; has w1-today 'is due for review today'; has w1-today 'GO WITH CONDITIONS'
  one w2-13-days ADR-021 2026-12-15; chk w2-13-days; expect_only w2-13-days GOV-W2 Low; has w2-13-days 'in 13 days'
  one w2-14-days ADR-021 2026-12-16; chk w2-14-days; expect_only w2-14-days GOV-W2 Low; has w2-14-days 'in 14 days'
  one w2-15-days ADR-021 2026-12-17; chk w2-15-days; expect_pass w2-15-days; has w2-15-days '(15 days left)'
  one w2-1-day ADR-021 2026-12-03; chk w2-1-day; expect_only w2-1-day GOV-W2 Low; has w2-1-day 'in 1 day ('
  one w2-year-end ADR-021 2027-01-01; chk w2-year-end; expect_pass w2-year-end; has w2-year-end '(30 days left)'

  # GOV-W3: no review date, or not a real one
  one w3-missing ADR-021 ''; chk w3-missing; expect_only w3-missing GOV-W3 Medium; has w3-missing 'GO WITH CONDITIONS'; has w3-missing '(no review date)'; has w3-missing 'has no review_by'
  one w3-unreal ADR-021 2026-02-30; chk w3-unreal; expect_only w3-unreal GOV-W3 Medium; has w3-unreal "'2026-02-30'"
  one w3-format ADR-021 31/03/2027; chk w3-format; expect_only w3-format GOV-W3 Medium
  one w3-leap ADR-021 2028-02-29; chk w3-leap; expect_pass w3-leap

  # GOV-W4: the waiver's ADR
  base w4-no-skips; printf 'security:\n  waivers:\n    - id: ADR-021\n      review_by: 2027-03-31\n' >> "$WORK/w4-no-skips/$CON"
  chk w4-no-skips; expect_only w4-no-skips GOV-W4 Medium; has w4-no-skips 'does not say what it skips'; has w4-no-skips 'GO WITH CONDITIONS'
  one w4-not-adr TODO 2027-03-31; chk w4-not-adr; expect_only w4-not-adr GOV-W4 Medium; has w4-not-adr "'TODO'"
  one w4-no-id '' 2027-03-31; chk w4-no-id; expect_only w4-no-id GOV-W4 Medium; has w4-no-id 'has no id'
  one w4-no-file ADR-099 2027-03-31; chk w4-no-file; expect_only w4-no-file GOV-W4 Medium; has w4-no-file 'no ADR-099 in docs/adr'
  one w4-proposed ADR-023 2027-03-31; chk w4-proposed; expect_only w4-proposed GOV-W4 Medium; has w4-proposed 'docs/adr/ADR-023-skip-the-drill.md'; has w4-proposed 'not accepted'
  one w4-superseded ADR-025 2027-03-31; chk w4-superseded; expect_only w4-superseded GOV-W4 Medium
  one w4-proposed-for-now ADR-028 2027-03-31; chk w4-proposed-for-now; expect_only w4-proposed-for-now GOV-W4 Medium
  one w4-status-heading ADR-024 2027-03-31; chk w4-status-heading; expect_pass w4-status-heading
  one w4-front-matter ADR-027 2027-03-31; chk w4-front-matter; expect_pass w4-front-matter
  one w4-leading-zeros ADR-0021 2027-03-31; chk w4-leading-zeros; expect_pass w4-leading-zeros
  one w4-amended ADR-022 2027-03-31; chk w4-amended; expect_pass w4-amended
  one w4-no-folder ADR-021 2027-03-31; rm -rf "${WORK:?}/w4-no-folder/docs"; edit w4-no-folder $CON "$(drop '  dir: docs/adr/')" && chk w4-no-folder && expect_pass w4-no-folder
  has w4-no-folder 'N/A   GOV-W4'; has w4-no-folder 'no ADR folder'
  one w4-default-folder ADR-023 2027-03-31; edit w4-default-folder $CON "$(drop '  dir: docs/adr/')" && chk w4-default-folder && expect_only w4-default-folder GOV-W4 Medium
  one w4-section-folder ADR-021 2027-03-31; printf '  adr_dir: docs/sec-adr/\n' >> "$WORK/w4-section-folder/$CON"; chk w4-section-folder; expect_only w4-section-folder GOV-W4 Medium
  has w4-section-folder 'no ADR-021 in docs/sec-adr'
  mkdir -p "$WORK/w4-section-folder/docs/sec-adr"; adr w4-section-folder ADR-021 'Keep lodash' '**Status:** Accepted' docs/sec-adr/ADR-021-keep-lodash.md
  rm -f "$WORK/w4-section-folder/docs/adr/ADR-021-keep-lodash.md"; chk w4-section-folder; expect_pass w4-section-folder-found

  # two findings on one waiver, and two waivers
  one w1-and-w4 ADR-099 2026-11-01; chk w1-and-w4; has w1-and-w4 'FAIL  GOV-W1  High'; has w1-and-w4 'FAIL  GOV-W4  Medium'; expect_rc w1-and-w4 1
  one two ADR-021 2026-11-01; printf '    - id: ADR-022\n      skips: UX-U3 on the admin pages\n      review_by: 2027-06-30\n' >> "$WORK/two/$CON"
  chk two; expect_only two GOV-W1 High; has two 'NOTE  waiver security ADR-022: UX-U3 on the admin pages; review by 2027-06-30 (210 days left)'
  has two 'PASS  GOV-W3  every waiver has a real review date (2 waivers)'

  # every section's waivers are read
  base sections
  for s in security ux ops quality; do printf '%s:\n  waivers:\n    - id: ADR-021\n      skips: something in %s\n      review_by: 2027-03-31\n' "$s" "$s" >> "$WORK/sections/$CON"; done
  awk '{ print } /^governance:$/ { print "  waivers:"; print "    - id: ADR-022"; print "      skips: a governance waiver"; print "      review_by: 2027-03-31" }' "$WORK/sections/$CON" > "$WORK/sections.tmp" && mv "$WORK/sections.tmp" "$WORK/sections/$CON"
  chk sections; expect_pass sections
  for s in security ux ops quality; do has sections "NOTE  waiver $s ADR-021: something in $s"; done
  has sections 'NOTE  waiver governance ADR-022: a governance waiver'; has sections '(5 waivers)'
  if [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE  waiver ')" -eq 5 ]; then ok; else bad "sections: expected five waiver lines"; fi

  # acknowledged changes are listed, and are not waivers
  base ack-listed; printf '  acknowledged_changes:\n    - adr: ADR-009\n      commit: 0ac9d34\n' >> "$WORK/ack-listed/$CON"
  chk ack-listed; expect_pass ack-listed; has ack-listed 'NOTE  acknowledged change ADR-009 at 0ac9d34 (decisions.acknowledged_changes: not a waiver, never expires)'
  has ack-listed 'N/A   GOV-W1  the contract has no waivers'; lacks ack-listed 'GOV-W3'

  # text that would break a table stays one line, unchanged
  one special ADR-021 2027-03-31 '"a|b `c` <script>alert(1)</script> & d"'; chk special; expect_pass special
  has special 'NOTE  waiver security ADR-021: a|b `c` <script>alert(1)</script> & d; review by 2027-03-31'
  if [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE  waiver ')" -eq 1 ]; then ok; else bad "special: expected one waiver line"; fi
  one extra-fields ADR-021 2027-03-31; printf '      advisories: [GHSA-35jh-r3h4-6jhm, CVE-2021-23337]\n      owner: operator\n' >> "$WORK/extra-fields/$CON"; chk extra-fields; expect_pass extra-fields
  if [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE  waiver ')" -eq 1 ]; then ok; else bad "extra-fields: expected one waiver line"; fi
}
run_matrix
