#!/usr/bin/env bash
# Test inventory checks: which test types exist, whether CI runs them, and which
# integration boundaries no test reaches. Part of the ascent-quality plugin
# (quality-review Step 3, test-inventory Step 2). Read-only.
#
# Usage: check-test-inventory.sh [--types unit,integration,contract,e2e] PATH...
#
# PATH is the repository (or part of it). Test files are found as check-tests.sh
# finds them (lib/qa-files.sh) and typed by path, name and imports: e2e (e2e/,
# cypress/, playwright/, *.e2e.*, *.cy.*, or it imports Playwright, Cypress, Selenium,
# Puppeteer or WebdriverIO), contract (contract/, pact/, or it imports Pact),
# integration (integration/, it/, *integration*, *.int.*, @pytest.mark.integration, a
# Go integration build tag), otherwise unit. --types lists the types the contract
# requires (quality.tests.types_required); the default is unit,integration.
#
# Checks (severity from the quality-review severity table):
#   QA-I1  Medium  every type in --types has at least one test file
#   QA-I2  Medium  CI configuration exists and one of its steps runs the tests: a test
#                  runner, a test script or a make target that runs one (make recipes
#                  and package.json scripts are followed three levels deep)
#   QA-I3  Low     end-to-end and contract tests, when present, are run by a CI step
#                  that names their runner
#   QA-I4  Low     every database, queue or outbound HTTP client the source imports is
#                  reached by a test in the same language: a test names the client, or
#                  uses a test double of its kind (testcontainers, sqlmock, nock, msw,
#                  responses, httptest, ...). A heuristic, rated Low until trialled
#                  (ADR-014)
#   QA-I5  Low     every package.json declares a test script other than npm's placeholder;
#                  with no test script, a make target named test* is enough
#
# Output: FAIL lines (FAIL  QA-In  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A when a check found nothing to check, then
# "check-test-inventory: ...".
# Limits: static. A CI step is read line by line, so a command split over several
# YAML lines may be missed; a test command built at runtime is not seen. A test
# that reaches a boundary through the project's own wrapper is seen only when it
# names the client or uses a double.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
TYPES="unit,integration"
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --types)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      TYPES="$2"; shift 2
      for ty in $(printf '%s' "$TYPES" | tr ',' ' '); do
        case "$ty" in unit|integration|contract|e2e) ;; *) echo "check-test-inventory: unknown test type '$ty' (unit, integration, contract, e2e)" >&2; exit 2 ;; esac
      done ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-test-inventory: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || { usage >&2; exit 2; }

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in qa-files.sh qa-common.awk check-test-inventory.awk; do
  [ -f "$LIB/$f" ] || { echo "check-test-inventory: missing $LIB/$f" >&2; exit 2; }
done
# shellcheck source=lib/qa-files.sh
. "$LIB/qa-files.sh"

qa_collect check-test-inventory "t td s ci pkg make" "" "${PATHS[@]}"
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

QA_TYPES="$TYPES" QA_PATHS="${PATHS[*]}" \
  LC_ALL=C awk -f "$LIB/qa-common.awk" -f "$LIB/check-test-inventory.awk" "${ARGS[@]}"
