#!/usr/bin/env bash
# Behavior test for plugins/ascent-governance/scripts/lib/contract.awk, which
# flattens the YAML subset .ascent/contract.yml uses into "path<TAB>value<TAB>line" lines:
# nested maps, inline lists and maps, block lists of scalars and of maps,
# comments, quotes, CRLF line ends. A tab used for indentation is an error.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-contract-reader: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-contract-reader
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
READER="$PLUGIN/scripts/lib/contract.awk"
need "$READER" "$FIX/contracts/governance.yml" "$HERE/../../../.ascent/contract.yml"
TAB="$(printf '\t')"

flat() {  # NAME: flattens $WORK/NAME.yml
  PATH="$SHIM:$PATH" awk -f "$READER" "$WORK/$1.yml" >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
line() { if cut -f1,2 "$WORK/out" | grep -qxF -- "$2$TAB$3"; then ok; else bad "$1: no line '$2<TAB>$3': $(tr '\t' '=' < "$WORK/out" | head -4 | tr '\n' ';')"; fi; }
at() { if grep -qxF -- "$2$TAB$3$TAB$4" "$WORK/out"; then ok; else bad "$1: $2 is not reported at line $4: $(grep -F -- "$2$TAB" "$WORK/out" | tr '\t' '=' | head -2 | tr '\n' ';')"; fi; }
count() { n=$(grep -c . "$WORK/out" || true); if [ "$n" -eq "$2" ]; then ok; else bad "$1: expected $2 line(s), got $n: $(tr '\t' '=' < "$WORK/out" | tr '\n' ';' | cut -c1-200)"; fi; }

matrix() {
  printf 'version: 1\n' > "$WORK/flat-scalars.yml"
  flat flat-scalars; expect_rc flat-scalars 0; line flat-scalars version 1; count flat-scalars 1

  cp "$FIX/contracts/governance.yml" "$WORK/nested-map.yml"
  flat nested-map; expect_rc nested-map 0
  line nested-map 'governance.environments[0]' local
  line nested-map 'governance.environments[2]' prod
  line nested-map 'governance.floors.beta.reviews.ux-review' 60
  line nested-map 'governance.floors.beta.checks[1]' ascent-security/check-threat-model
  line nested-map 'governance.floors.prod.sign_off' true
  line nested-map 'governance.review_log' docs/governance/review-log.md
  at nested-map 'governance.environments[1]' beta 4; at nested-map 'governance.floors.beta.checks[0]' ascent-security/check-dependencies 9
  at nested-map 'governance.floors.beta.checks[2]' ascent-ux/check-flow-integrity 9; at nested-map 'governance.floors.prod.sign_off' true 16

  printf 'g:\n  environments: [local, beta, prod]\n' > "$WORK/inline-list.yml"
  flat inline-list; line inline-list 'g.environments[0]' local; line inline-list 'g.environments[1]' beta; line inline-list 'g.environments[2]' prod; count inline-list 3

  printf 'g:\n  reviews: { sec-posture: 30, ux-review: 60 }\n' > "$WORK/inline-map.yml"
  flat inline-map; line inline-map g.reviews.sec-posture 30; line inline-map g.reviews.ux-review 60; count inline-map 2

  cat > "$WORK/block-list-of-maps.yml" <<'EOF'
security:
  waivers:
    - id: ADR-021
      skips: lodash 4.17.15 in a build-time tool
      review_by: 2027-03-31
    - id: ADR-022
      skips: the admin pages
      review_by: 2027-06-30
EOF
  flat block-list-of-maps; count block-list-of-maps 6
  line block-list-of-maps 'security.waivers[0].id' ADR-021
  line block-list-of-maps 'security.waivers[0].skips' 'lodash 4.17.15 in a build-time tool'
  line block-list-of-maps 'security.waivers[1].review_by' 2027-06-30
  at block-list-of-maps 'security.waivers[0].id' ADR-021 3; at block-list-of-maps 'security.waivers[1].id' ADR-022 6; at block-list-of-maps 'security.waivers[1].review_by' 2027-06-30 8

  printf 'a:\n  list:\n  - one\n  - two\n  after: x\n' > "$WORK/list-same-indent.yml"
  flat list-same-indent; line list-same-indent 'a.list[0]' one; line list-same-indent 'a.list[1]' two; line list-same-indent a.after x; count list-same-indent 3

  cat > "$WORK/nested-list-field.yml" <<'EOF'
security:
  waivers:
    - id: ADR-021
      advisories: [GHSA-35jh, CVE-2021-23337]
  after: yes
EOF
  flat nested-list-field; line nested-list-field 'security.waivers[0].advisories[1]' CVE-2021-23337; line nested-list-field security.after yes

  printf 'ux:\n  waivers: []\n  empty: {}\n  none:\n  tilde: ~\n  nothing: null\n' > "$WORK/empty-list.yml"
  flat empty-list; expect_rc empty-list 0; count empty-list 0

  cat > "$WORK/comments-and-quotes.yml" <<'EOF'
# a comment line
delivery:
  gate: make check   # the gate
  note: "quoted # value"
  url: http://localhost:3000/a#frag
  smoke: 'single: quoted'
  text: a value: with a colon
EOF
  flat comments-and-quotes; count comments-and-quotes 5
  line comments-and-quotes delivery.gate 'make check'
  line comments-and-quotes delivery.note 'quoted # value'
  line comments-and-quotes delivery.url 'http://localhost:3000/a#frag'
  line comments-and-quotes delivery.smoke 'single: quoted'
  line comments-and-quotes delivery.text 'a value: with a colon'

  printf 'a:\n  b: 1\r\n  c: [x, y]\r\n' > "$WORK/crlf.yml"
  flat crlf; line crlf a.b 1; line crlf 'a.c[1]' y; count crlf 3

  printf 'a:\n  text: |\n    line one\n    key: not a key\n  b: 2\n' > "$WORK/block-scalar.yml"
  flat block-scalar; line block-scalar a.b 2; count block-scalar 1

  printf 'a:\n\tb: 1\n' > "$WORK/tab-indent.yml"
  flat tab-indent; expect_rc tab-indent 2; has tab-indent 'line 2'; has tab-indent 'tab'

  cp "$HERE/../../../.ascent/contract.yml" "$WORK/this-repo.yml"
  flat this-repo; expect_rc this-repo 0
  line this-repo 'decisions.acknowledged_changes[0].adr' ADR-009
  line this-repo 'decisions.acknowledged_changes[0].commit' 0ac9d34
  line this-repo decisions.style ascent

  # a byte-order mark is not part of the first key
  printf '\357\273\277governance:\n  environments: [local]\n' > "$WORK/bom.yml"
  flat bom; expect_rc bom 0; line bom 'governance.environments[0]' local
  # an inline map may go on over several lines, like an inline list
  printf 'governance:\n  floors:\n    beta:\n      reviews: {\n        sec-posture: 30 }\n' > "$WORK/map-open.yml"
  flat map-open; expect_rc map-open 0; at map-open 'governance.floors.beta.reviews.sec-posture' 30 4
  printf 'governance:\n  floors:\n    beta:\n      reviews: {\n        sec-posture: 30\n' > "$WORK/map-never.yml"
  flat map-never; expect_rc map-never 2; has map-never 'line 4'; has map-never 'never closes'
  # a map inside a map, and a map in a list
  printf 'governance:\n  floors: { prod: { sign_off: true, checks: [a/b, c/d] } }\nops:\n  alerts: [{ name: cpu, page: true }]\n' > "$WORK/map-nested.yml"
  flat map-nested; expect_rc map-nested 0; line map-nested 'governance.floors.prod.sign_off' true; line map-nested 'governance.floors.prod.checks[1]' c/d
  line map-nested 'ops.alerts[0].name' cpu; line map-nested 'ops.alerts[0].page' true

}
run_matrix
