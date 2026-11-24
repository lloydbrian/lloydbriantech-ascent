#!/usr/bin/env bash
# Behavior test for plugins/ascent-governance/scripts/check-audit.sh: the ladder,
# the floors and the verdict.
#
# The good fixture (fixtures/audit-good: a contract with a three-rung ladder and
# a floor for each rung) is GO for local, beta and prod. The other plugins'
# checkers are stand-ins (fixtures/stub-checker.sh) that log how they were run
# and exit as the case tells them, so this test does not depend on what those
# checkers find. Each rule then gets negative controls: a copy broken in exactly
# one way fails that rule and no other. Also covers inheritance down the ladder,
# custom ladders, --skip, the contract's own gate, the defaults when a contract
# has no governance section, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-audit: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-check-audit
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
need "$CHECK" "$FIX/audit-good/.ascent/contract.yml" "$FIX/stub-checker.sh"
matrix() {
  # the good fixture, one rung at a time
  for e in local beta prod; do
    stubs; mk "good-$e"; chk "good-$e" --env "$e"; expect_pass "good-$e"; has "good-$e" "check-audit: $e: GO, "
    lacks "good-$e" 'GO WITH CONDITIONS'
  done
  has good-prod 'it checks that the evidence exists and is current, not that the system is good'
  stubs; mk good-default; chk good-default; has good-default 'check-audit: local: GO, '

  # GOV-L1: a checker of the rung fails
  stubs; mk l1; stub_rc ascent-docs/check-docs 1; chk l1 --env beta; expect_only l1 GOV-L1 High
  has l1 'check-audit: beta: NO-GO, '; has l1 'ascent-docs/check-docs'; has l1 'the stub ascent-docs__check-docs found a fault'

  stubs; mk l1-worst-first; stub_rc ascent-docs/check-docs 1
  printf 'FAIL  DOC-P3  Low    README.md:1  low one\nFAIL  DOC-P4  Low    README.md:2  low two\nFAIL  DOC-L2  Medium docs/a.md:3  medium one\nPASS  DOC-L1  fine\nFAIL  DOC-L5  High   docs/b.md:4  high one\nFAIL  DOC-P5  Low    README.md:9  low three\n' > "$WORK/ctl/ascent-docs__check-docs.out"
  chk l1-worst-first --env beta; expect_only l1-worst-first GOV-L1 High
  has l1-worst-first 'failed: DOC-L5 High docs/b.md:4 high one; DOC-L2 Medium docs/a.md:3 medium one; DOC-P3 Low README.md:1 low one (and 2 more)'

  # GOV-L1 follows the checker's findings (ADR-029): a check that fails with only
  # Medium or Low findings is Medium or Low, as its most severe finding is, and the
  # verdict is GO WITH CONDITIONS; a finding of no known severity, or none, is High
  l1_out() {  # NAME LINES — check-docs exits 1 and prints LINES (a printf format)
    stubs; mk "$1"; stub_rc ascent-docs/check-docs 1; printf "$2" > "$WORK/ctl/ascent-docs__check-docs.out"
  }
  l1_out l1-medium 'FAIL  DOC-L2  Medium docs/a.md:3  medium one\nFAIL  DOC-P3  Low    README.md:1  low one\n'
  chk l1-medium --env beta; expect_only l1-medium GOV-L1 Medium; has l1-medium 'check-audit: beta: GO WITH CONDITIONS, '
  has l1-medium 'failed: DOC-L2 Medium docs/a.md:3 medium one; DOC-P3 Low README.md:1 low one'
  l1_out l1-low 'FAIL  DOC-P3  Low    README.md:1  low one\nFAIL  DOC-P4  Low    README.md:2  low two\n'
  chk l1-low --env beta; expect_only l1-low GOV-L1 Low; has l1-low 'check-audit: beta: GO WITH CONDITIONS, '
  l1_out l1-low-then-medium 'FAIL  DOC-P3  Low    README.md:1  low one\nFAIL  DOC-L2  Medium docs/a.md:3  medium one\n'
  chk l1-low-then-medium --env beta; expect_only l1-low-then-medium GOV-L1 Medium
  l1_out l1-no-severity 'FAIL  DOC-L2  docs/a.md:3  no column\n'
  chk l1-no-severity --env beta; expect_only l1-no-severity GOV-L1 High; has l1-no-severity 'check-audit: beta: NO-GO, '
  l1_out l1-lowercase 'FAIL  DOC-L2  medium docs/a.md:3  lowercase\n'
  chk l1-lowercase --env beta; expect_only l1-lowercase GOV-L1 High
  # a finding of no known severity is cited first, as High, so the message matches GOV-L1
  l1_out l1-unknown-cited 'FAIL  DOC-P3  Low    README.md:1  low one\nFAIL  DOC-P4  Low    README.md:2  low two\nFAIL  DOC-P1  Low    README.md:3  low three\nFAIL  DOC-L2  medium docs/a.md:3  odd one\n'
  chk l1-unknown-cited --env beta; expect_only l1-unknown-cited GOV-L1 High; has l1-unknown-cited 'failed: DOC-L2 medium docs/a.md:3 odd one; DOC-P3 Low'
  l1_out l1-crlf 'FAIL  DOC-L2  Medium docs/a.md:3  a CRLF line\r\n'
  chk l1-crlf --env beta; expect_only l1-crlf GOV-L1 Medium
  l1_out l1-crlf-at-severity 'FAIL  DOC-L2  Medium\r\n'
  chk l1-crlf-at-severity --env beta; expect_only l1-crlf-at-severity GOV-L1 High
  l1_out l1-no-fail-line 'PASS  DOC-L1  fine\n'
  chk l1-no-fail-line --env beta; expect_only l1-no-fail-line GOV-L1 High; has l1-no-fail-line 'check-audit: beta: NO-GO, '
  # a checker that dies under set -e exits 1 with an error on stderr and no FAIL line
  stubs; mk l1-stderr-only
  printf '#!/usr/bin/env bash\necho "check-docs.sh: line 9: DIR: unbound variable" >&2\nexit 1\n' > "$WORK/stubs/ascent-docs/scripts/check-docs.sh"
  chk l1-stderr-only --env beta; expect_only l1-stderr-only GOV-L1 High; has l1-stderr-only 'check-audit: beta: NO-GO, '
  # well-formed FAIL lines are read wherever the checker prints them: stderr too
  stubs; mk l1-stderr-findings
  printf '#!/usr/bin/env bash\necho "FAIL  DOC-L2  Medium docs/a.md:3  on stderr" >&2\nexit 1\n' > "$WORK/stubs/ascent-docs/scripts/check-docs.sh"
  chk l1-stderr-findings --env beta; expect_only l1-stderr-findings GOV-L1 Medium; has l1-stderr-findings 'failed: DOC-L2 Medium docs/a.md:3 on stderr'
  # the same rule at every rung, prod included, and in CI the job stays green
  stubs; mk l1-local; stub_rc ascent-security/check-env 1
  printf 'FAIL  SEC-E3  Medium .dockerignore:2  a pattern that matches nothing\n' > "$WORK/ctl/ascent-security__check-env.out"
  chk l1-local --env local; expect_only l1-local GOV-L1 Medium; has l1-local 'check-audit: local: GO WITH CONDITIONS, '
  stubs; mk l1-prod; stub_rc ascent-ops/check-drills 1
  printf 'FAIL  OPS-R5  Low    docs/ops/drills/2026-10-01-restore.md:1  the record names no runbook\n' > "$WORK/ctl/ascent-ops__check-drills.out"
  chk l1-prod --env prod; expect_only l1-prod GOV-L1 Low; has l1-prod 'check-audit: prod: GO WITH CONDITIONS, '
  l1_out l1-ci 'FAIL  DOC-L2  Medium docs/a.md:3  medium one\n'; rm -f "$WORK/sum-l1.md"
  STEP_SUMMARY="$WORK/sum-l1.md" chk l1-ci --env beta; expect_only l1-ci GOV-L1 Medium
  if grep -q 'GOV-L1' "$WORK/sum-l1.md" 2>/dev/null && grep -q 'GO WITH CONDITIONS' "$WORK/sum-l1.md"; then ok
  else bad "l1-ci: the job summary lacks the GOV-L1 line or GO WITH CONDITIONS: $(head -3 "$WORK/sum-l1.md" 2>/dev/null | tr '\n' ';')"; fi

  # GOV-L2: a plugin that is not available is unmeasured, never NO-GO
  stubs; mk l2; mkdir -p "$WORK/empty"; PLUGINS_DIR="$WORK/empty" chk l2 --env beta; expect_rc l2 0
  has l2 'GO WITH CONDITIONS'; has l2 'unmeasured'; lacks l2 'NO-GO'; lacks l2 'FAIL  GOV-L1'
  has l2 'FAIL  GOV-L2  Low'

  # GOV-S2: a broken adapter is not a NO-GO
  stubs; mk s2-usage; stub_rc ascent-docs/check-docs 2; chk s2-usage --env beta; expect_only s2-usage GOV-S2 Medium
  has s2-usage 'GO WITH CONDITIONS'; lacks s2-usage 'FAIL  GOV-L1'
  # exit 2 is a usage error only when its first line is the checker's own message,
  # <name>: or Usage: <name>.sh; awk and bash also exit 2 when they fail (ADR-030)
  x2_out() {  # NAME LINES — check-docs exits 2 and prints LINES (a printf format) on stderr
    stubs; mk "$1"; stub_rc ascent-docs/check-docs 2; printf "$2" > "$WORK/ctl/ascent-docs__check-docs.out"
  }
  x2_out l1-crash-2 'awk: division by zero\n source line number 3\n'
  chk l1-crash-2 --env beta; expect_only l1-crash-2 GOV-L1 High; has l1-crash-2 'check-audit: beta: NO-GO, '
  has l1-crash-2 'exited 2 without finishing (awk: division by zero)'
  x2_out l1-crash-2-bash "$WORK/stubs/ascent-docs/scripts/check-docs.sh: line 9: syntax error near unexpected token\n"
  chk l1-crash-2-bash --env beta; expect_only l1-crash-2-bash GOV-L1 High
  x2_out l1-crash-2-bash-bare 'check-docs.sh: line 9: syntax error near unexpected token\n'
  chk l1-crash-2-bash-bare --env beta; expect_only l1-crash-2-bash-bare GOV-L1 High
  x2_out l1-crash-2-silent ''
  chk l1-crash-2-silent --env beta; expect_only l1-crash-2-silent GOV-L1 High; has l1-crash-2-silent 'exited 2 without finishing'
  x2_out s2-own-name "check-docs: --maturity: unknown value 'x'\n"
  chk s2-own-name --env beta; expect_only s2-own-name GOV-S2 Medium; has s2-own-name 'GO WITH CONDITIONS'
  has s2-own-name "usage error (check-docs: --maturity: unknown value 'x')"
  x2_out s2-other-name 'check-env: unknown option --x\n'
  chk s2-other-name --env beta; expect_only s2-other-name GOV-L1 High
  x2_out s2-other-usage 'Usage: check-env.sh [--no-git] [REPO]\n'
  chk s2-other-usage --env beta; expect_only s2-other-usage GOV-L1 High
  # the known limit (ADR-030): only the first line is read, so a crash after a line
  # that starts with the checker's name still reads as a usage error
  x2_out l1-crash-after-summary 'check-docs: 0 failure(s)\nawk: run time error\n'
  chk l1-crash-after-summary --env beta; expect_only l1-crash-after-summary GOV-S2 Medium
  stubs; mk s2-no-adapter; edit s2-no-adapter $CON "$(subst 'ascent-docs/check-docs]' 'ascent-docs/check-docs, ascent-ops/check-ops-scripts]')" \
    && chk s2-no-adapter --env beta && expect_only s2-no-adapter GOV-S2 Medium
  has s2-no-adapter 'ascent-ops/check-ops-scripts'

  # GOV-S1: a governance section that does not say what its author thinks
  stubs; mk s1-bad-age; edit s1-bad-age $CON "$(subst 'ux-review: 60' 'ux-review: soon')" && chk s1-bad-age --env beta && expect_only s1-bad-age GOV-S1 High
  stubs; mk s1-zero-age; edit s1-zero-age $CON "$(subst 'ux-review: 60' 'ux-review: 0')" && chk s1-zero-age --env beta && expect_only s1-zero-age GOV-S1 High
  stubs; mk s1-unknown-env-floor; edit s1-unknown-env-floor $CON "$(subst '    beta:' '    staging:')" && chk s1-unknown-env-floor --env prod && expect_only s1-unknown-env-floor GOV-S1 High
  has s1-unknown-env-floor 'staging'
  stubs; mk s1-bad-check-name; edit s1-bad-check-name $CON "$(subst 'ascent-docs/check-docs]' 'check-docs.sh]')" && chk s1-bad-check-name --env beta && expect_only s1-bad-check-name GOV-S1 High
  stubs; mk s1-unreadable; printf 'governance:\n\tenvironments: [local]\n' > "$WORK/s1-unreadable/$CON"; chk s1-unreadable; expect_only s1-unreadable GOV-S1 High
  has s1-unreadable 'line 2'

  # each rung inherits the rungs below it
  stubs; mk inherit; chk inherit --env prod; ran inherit ascent-security/check-env; ran inherit ascent-docs/check-docs; ran inherit ascent-adr/check-adrs
  stubs; mk inherit-beta; chk inherit-beta --env beta; ran inherit-beta ascent-security/check-env; ran inherit-beta ascent-docs/check-docs; notran inherit-beta ascent-adr/check-adrs
  stubs; mk inherit-local; chk inherit-local --env local; ran inherit-local ascent-security/check-env; notran inherit-local ascent-docs/check-docs

  # --skip
  stubs; mk skip; chk skip --env beta --skip ascent-docs/check-docs; expect_pass skip; notran skip ascent-docs/check-docs
  has skip 'ascent-docs/check-docs was skipped'
  stubs; mk skip-fail; stub_rc ascent-docs/check-docs 1; chk skip-fail --env beta --skip ascent-docs/check-docs; expect_pass skip-fail

  # delivery/gate runs the contract's own gate
  stubs; mk gate-pass; chk gate-pass; expect_pass gate-pass; has gate-pass 'delivery/gate'
  stubs; mk gate-fail; edit gate-fail $CON "$(subst 'gate: "true"' 'gate: "echo gate output; false"')" && chk gate-fail && expect_only gate-fail GOV-L1 High
  has gate-fail 'delivery/gate'
  stubs; mk gate-absent; edit gate-absent $CON "$(drop 'gate: "true"')" && chk gate-absent && expect_only gate-absent GOV-L2 Low
  has gate-absent 'the contract has no delivery.gate'

  # no contract, or nothing in it about governance: prototype, the local floor, GO
  stubs; mkdir -p "$WORK/no-contract"; chk no-contract; expect_pass no-contract
  has no-contract 'check-audit: local: GO, '; has no-contract 'maturity prototype'; has no-contract 'no contract'
  ran no-contract ascent-security/check-env
  stubs; mkdir -p "$WORK/no-gov"; contract no-gov <<'EOF'
version: 1
delivery:
  release_log: docs/RELEASES.md
EOF
  mkdir -p "$WORK/no-gov/docs/adr"; printf '# Readme\n' > "$WORK/no-gov/README.md"; printf '{ "name": "x" }\n' > "$WORK/no-gov/package.json"
  chk no-gov; expect_pass no-gov; has no-gov 'maturity prototype'; has no-gov 'check-audit: local: GO, '
  stubs; chk no-gov --env prod; expect_pass no-gov-prod; notran no-gov-prod ascent-docs/check-docs; notran no-gov-prod ascent-adr/check-adrs

  # defaults follow the most lenient maturity_target, and what the repository shows
  stubs; rm -rf "${WORK:?}/defaults"; mkdir -p "$WORK/defaults/docs/adr" "$WORK/defaults/src"; contract defaults <<'EOF'
version: 1
security:
  maturity_target: enterprise
docs:
  maturity_target: standard
EOF
  printf '# Readme\n' > "$WORK/defaults/README.md"; printf '{ "name": "x" }\n' > "$WORK/defaults/package.json"
  printf '# ADR-001: One\n\n**Status:** Accepted\n' > "$WORK/defaults/docs/adr/ADR-001-one.md"
  chk defaults --env prod; has defaults 'maturity standard'; has defaults 'docs.maturity_target'
  ran defaults ascent-security/check-env; ran defaults ascent-security/check-dependencies; ran defaults ascent-docs/check-docs; ran defaults ascent-adr/check-adrs
  notran defaults ascent-ux/check-flow-integrity; notran defaults ascent-ops/check-drills; notran defaults ascent-quality/check-test-evidence
  lacks defaults 'ascent-ux'; lacks defaults 'ux-review'
  stubs; printf '<html></html>\n' > "$WORK/defaults/src/index.html"; chk defaults --env prod; notran defaults-ui ascent-ux/check-flow-integrity
  has defaults-ui 'ascent-ux/check-flow-integrity is unmeasured: the contract has no ux.pages'; lacks defaults-ui 'FAIL  GOV-L1'
  stubs; printf 'ux:\n  pages: ["src/*.html"]\n' >> "$WORK/defaults/$CON"; chk defaults --env prod; ran defaults-pages ascent-ux/check-flow-integrity
  lacks defaults-pages 'ascent-ux/check-flow-integrity is unmeasured'
  stubs; mkdir -p "$WORK/defaults-gov"; contract defaults-gov <<'EOF'
governance:
  maturity_target: standard
security:
  maturity_target: prototype
EOF
  chk defaults-gov --env prod; has defaults-gov 'maturity standard (governance.maturity_target)'
  stubs; mkdir -p "$WORK/defaults-order"; contract defaults-order <<'EOF'
docs:
  maturity_target: standard
security:
  maturity_target: enterprise
EOF
  chk defaults-order --env prod; has defaults-order 'maturity standard (docs.maturity_target, the most lenient)'

  # custom ladders
  stubs; mkdir -p "$WORK/ladder-two"; contract ladder-two <<'EOF'
governance:
  environments: [local, prod]
  floors:
    local:
      checks: [ascent-security/check-env]
    prod:
      checks: [ascent-adr/check-adrs]
EOF
  chk ladder-two --env prod; expect_pass ladder-two; ran ladder-two ascent-security/check-env; ran ladder-two ascent-adr/check-adrs
  has ladder-two 'check-audit: prod: GO, '
  stubs; mkdir -p "$WORK/ladder-custom"; contract ladder-custom <<'EOF'
governance:
  environments: [dev, staging, live]
  floors:
    dev:
      checks: [ascent-security/check-env]
    staging:
      checks: [ascent-docs/check-docs]
    live:
      checks: [ascent-adr/check-adrs]
EOF
  chk ladder-custom --env live; expect_pass ladder-custom; ran ladder-custom ascent-security/check-env; ran ladder-custom ascent-docs/check-docs; ran ladder-custom ascent-adr/check-adrs
  stubs; chk ladder-custom --env staging; notran ladder-staging ascent-adr/check-adrs; ran ladder-staging ascent-docs/check-docs
  stubs; chk ladder-custom; has ladder-default 'check-audit: dev: GO, '
  stubs; chk ladder-custom --env prod; expect_rc env-unknown 2; has env-unknown 'dev, staging, live'; has env-unknown "'prod'"
  stubs; mkdir -p "$WORK/ladder-nofloors"; contract ladder-nofloors <<'EOF'
governance:
  maturity_target: standard
  environments: [dev, live]
EOF
  printf '# Readme\n' > "$WORK/ladder-nofloors/README.md"
  chk ladder-nofloors --env live; ran ladder-nofloors ascent-security/check-env; ran ladder-nofloors ascent-docs/check-docs
  stubs; chk ladder-nofloors --env dev; notran ladder-nofloors-dev ascent-docs/check-docs

  # a repository path with a space
  stubs; rm -rf "$WORK/with space"; cp -R "$FIX/audit-good" "$WORK/with space"; chk "with space" --env prod; expect_pass with-space

  # GOV-S1: a section in a shape this version does not read fails; nothing is dropped in silence
  stubs; mk s1-signoff-yes; edit s1-signoff-yes $CON "$(subst 'sign_off: true' 'sign_off: yes')" && chk s1-signoff-yes --env prod && expect_only s1-signoff-yes GOV-S1 High
  has s1-signoff-yes 'governance.floors.prod.sign_off'; has s1-signoff-yes 'true or false'
  stubs; mk s1-unknown-key; edit s1-unknown-key $CON "$(subst 'sign_off: true' 'signoff: true')" && chk s1-unknown-key --env prod && expect_only s1-unknown-key GOV-S1 High
  has s1-unknown-key 'governance.floors.prod.signoff'; has s1-unknown-key "$CON:16"
  stubs; mk s1-unknown-key-above; edit s1-unknown-key-above $CON "$(subst 'sign_off: true' 'signoff: true')" && chk s1-unknown-key-above --env local && expect_only s1-unknown-key-above GOV-S1 High
  stubs; mk s1-reviews-list; edit s1-reviews-list $CON "$(subst 'reviews: { sec-posture: 30, ux-review: 60 }' 'reviews: [sec-posture, ux-review]')" && chk s1-reviews-list --env beta && expect_only s1-reviews-list GOV-S1 High
  has s1-reviews-list 'governance.floors.beta.reviews'
  stubs; mk s1-checks-scalar; edit s1-checks-scalar $CON "$(subst 'checks: [ascent-security/check-env, delivery/gate]' 'checks: ascent-security/check-env')" && chk s1-checks-scalar && expect_only s1-checks-scalar GOV-S1 High
  has s1-checks-scalar 'governance.floors.local.checks'
  stubs; mk s1-approvers-scalar; edit s1-approvers-scalar $CON "$(subst 'approvers: []' 'approvers: ana-lopez')" && chk s1-approvers-scalar && expect_only s1-approvers-scalar GOV-S1 High
  has s1-approvers-scalar 'governance.approvers'; has s1-approvers-scalar 'a list'
  stubs; mk s1-maturity; edit s1-maturity $CON "$(subst 'approvers: []' 'maturity_target: Enterprise')" && chk s1-maturity && expect_only s1-maturity GOV-S1 High
  has s1-maturity "'Enterprise'"; has s1-maturity 'prototype, standard or enterprise'
  stubs; mk s1-map-open; edit s1-map-open $CON "$(subst 'reviews: { sec-posture: 30, ux-review: 60 }' 'reviews: {')" && chk s1-map-open --env beta && expect_rc s1-map-open 1
  has s1-map-open 'FAIL  GOV-S1  High'; has s1-map-open 'governance.floors.beta.reviews.prod'     # the map ran on into the next floor
  stubs; mk s1-map-nested; awk '/^  floors:/ { print "  floors: { prod: { sign_off: true } }"; skip = 1; next } skip && /^  approvers/ { skip = 0 } !skip { print }' "$FIX/audit-good/$CON" > "$WORK/s1-map-nested/$CON"
  chk s1-map-nested --env prod; expect_pass s1-map-nested; has s1-map-nested 'PASS  GOV-L3'     # a map inside a map is read
  stubs; mk s1-map-lines; edit s1-map-lines $CON "$(subst 'reviews: { sec-posture: 30, ux-review: 60 }' 'reviews: { sec-posture: 30,')" && edit s1-map-lines $CON '{ print } /sec-posture: 30,$/ { print "                 ux-review: 60 }" }'
  chk s1-map-lines --env beta; expect_pass s1-map-lines; has s1-map-lines 'sec-posture: '; has s1-map-lines 'ux-review: '
  stubs; mk s1-env-space; edit s1-env-space $CON "$(subst 'environments: [local, beta, prod]' 'environments: [local, "be ta", prod]')" && chk s1-env-space && expect_only s1-env-space GOV-S1 High
  has s1-env-space "'be ta'"
  stubs; mk s1-env-glob; edit s1-env-glob $CON "$(subst 'environments: [local, beta, prod]' 'environments: [local, "*", prod]')" && chk s1-env-glob && expect_only s1-env-glob GOV-S1 High
  stubs; mk s1-launch-dir-up; edit s1-launch-dir-up $CON "$(subst 'launch_dir: docs/governance/launches/' 'launch_dir: ../launches/')" && chk s1-launch-dir-up && expect_only s1-launch-dir-up GOV-S1 High
  has s1-launch-dir-up 'governance.launch_dir'; has s1-launch-dir-up 'inside the repository'
  stubs; mk s1-log-abs; edit s1-log-abs $CON "$(subst 'review_log: docs/governance/review-log.md' 'review_log: /tmp/review-log.md')" && chk s1-log-abs && expect_only s1-log-abs GOV-S1 High
  stubs; mk s1-adr-dir; edit s1-adr-dir $CON "$(subst 'approvers: []' 'adr_dir: docs/adr')" && chk s1-adr-dir && expect_pass s1-adr-dir
  # a byte-order mark before the first key does not hide the section
  stubs; mk bom; { printf '\357\273\277'; awk 'NR > 2' "$FIX/audit-good/$CON"; } > "$WORK/bom/$CON"; chk bom; expect_pass bom; has bom 'floor from governance.floors'

  # --env is one whole name of the ladder
  stubs; chk ladder-custom --env 'dev staging'; expect_rc env-two-names 2; has env-two-names "'dev staging'"

  # a ladder of one rung carries every tier
  stubs; mkdir -p "$WORK/ladder-one"; contract ladder-one <<'EOF'
governance:
  maturity_target: standard
  environments: [prod]
EOF
  printf '# Readme\n' > "$WORK/ladder-one/README.md"
  chk ladder-one --env prod; ran ladder-one ascent-security/check-env; ran ladder-one ascent-docs/check-docs; has ladder-one 'FAIL  GOV-L3'; has ladder-one 'sec-posture'

  # a checker's exit code: 1 is a failure, 2 a broken adapter, anything else a checker that did not finish
  stubs; mk l1-crash; stub_rc ascent-docs/check-docs 139; chk l1-crash --env beta; expect_only l1-crash GOV-L1 High; has l1-crash 'exited 139'; has l1-crash 'NO-GO'
  stubs; mk l1-exit3; stub_rc ascent-docs/check-docs 3; chk l1-exit3 --env beta; expect_only l1-exit3 GOV-L1 High

  # a checker that could check nothing is unmeasured; one that left rules out says which
  stubs; mk l2-all-na; printf 'N/A   SEC-E1  not a git repository: whether a .env file is tracked was not checked\nN/A   SEC-E2  not a git repository\nN/A   SEC-E3  no .dockerignore and no Dockerfile\n' > "$WORK/ctl/ascent-security__check-env.out"
  chk l2-all-na; expect_only l2-all-na GOV-L2 Low; has l2-all-na 'ascent-security/check-env is unmeasured: it had nothing it could check here (SEC-E1, SEC-E2, SEC-E3)'; lacks l2-all-na 'check-env passes'
  stubs; mk l1-some-na; printf 'PASS  SEC-E3  every .dockerignore excludes .env (1)\nN/A   SEC-E1  --no-git: not checked\nN/A   SEC-E2  --no-git: not checked\n' > "$WORK/ctl/ascent-security__check-env.out"
  chk l1-some-na; expect_pass l1-some-na; has l1-some-na 'PASS  GOV-L1  ascent-security/check-env passes (not checked here: SEC-E1, SEC-E2)'

  # the contract's gate may itself ask this question: it is not run a second time
  stubs; mk gate-marked; edit gate-marked $CON "$(subst 'gate: "true"' 'gate: "printenv ASCENT_GOVERNANCE_GATE"')" && chk gate-marked && expect_pass gate-marked
  stubs; mk gate-inner; edit gate-inner $CON "$(subst 'gate: "true"' 'gate: "false"')" && ASCENT_GOVERNANCE_GATE=1 chk gate-inner && expect_pass gate-inner
  has gate-inner 'delivery/gate is not run again'

  # in the plugin cache, a checker is the one of the highest version, by number
  c="$WORK/cache"; rm -rf "$c"; mkdir -p "$c/ascent-governance" "$c/ascent-docs/0.9.0/scripts" "$c/ascent-docs/0.10.0/scripts" "$WORK/cache-version"; cp -R "$PLUGIN" "$c/ascent-governance/0.1.0"
  printf '#!/usr/bin/env bash\necho "FAIL  DOC-S1  High   x  the 0.9.0 checker ran"; exit 1\n' > "$c/ascent-docs/0.9.0/scripts/check-docs.sh"
  printf '#!/usr/bin/env bash\necho "PASS  DOC-S1  the 0.10.0 checker ran"\n' > "$c/ascent-docs/0.10.0/scripts/check-docs.sh"
  contract cache-version <<'EOF'
governance:
  environments: [local]
  floors:
    local:
      checks: [ascent-docs/check-docs]
EOF
  (cd "$WORK/cache-version" && PATH="$SHIM:$PATH" bash "$c/ascent-governance/0.1.0/scripts/check-audit.sh" --today 2026-12-02 --no-git .) >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err")
  expect_pass cache-version; has cache-version 'PASS  GOV-L1  ascent-docs/check-docs passes'

  # usage
  chk good-prod --help; expect_rc help 0
  for o in --env --launch --contract --plugins --skip --today --no-git; do has help "$o"; done
  chk good-prod --frobnicate; expect_rc bad-option 2
  chk good-prod --today 2026-02-30; expect_rc bad-today 2
  chk good-prod --env; expect_rc missing-value 2
  stubs; chk good-prod --contract "$WORK/nowhere.yml"; expect_rc contract-missing 2
}
run_matrix
