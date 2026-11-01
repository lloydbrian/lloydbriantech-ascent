#!/usr/bin/env bash
# Traceability and hygiene checks for a repository's tests. Part of the
# ascent-quality plugin (quality-review Step 3, test-check Step 2). Read-only.
#
# Usage: check-tests.sh [--criteria PATH]... [--id-pattern ERE] [--core PATH]... [--helper NAME]... PATH...
#
# PATH is the repository (or part of it) to search for tests. Test files are found
# by name (*.test.*, *.spec.*, test_*.py, *_test.go, *.bats, test-*.sh, ...) and, for
# JS, TS, Python and Go, by sitting under tests/, test/, spec/, __tests__/, e2e/ or
# cypress/. Criteria documents are the Markdown files under each --criteria PATH,
# or every Markdown file under PATH when none is given; ids inside a code fence are
# examples and do not count. Skipped: dependencies,
# build output, virtualenvs and test fixtures (see lib/qa-files.sh).
#
# Checks (severity from the quality-review severity table):
#   QA-T1  Medium  every criterion id a criteria document holds is named by a test (a
#                  test naming AC-2.1 covers AC-2.1 and counts for AC-2)
#   QA-T2  Low     every criterion id a test names is defined in a criteria document
#                  (or its parent is: AC-2 defines AC-2.1)
#   QA-T3  Low     criterion ids exist at all; with none, traceability is unmeasured
#   QA-T4  Medium  every source file under a --core PATH is named by a test: an
#                  import or a word equal to its base name (the directory's name for
#                  index, main, __init__, mod, lib), a test file named after it, or for
#                  Go a _test.go file in its directory
#   QA-H1  High    no focused tests: .only, fit, fdescribe (JS, TS), @pytest.mark.only
#   QA-H2  Medium  a skipped test (.skip, xit, test.todo, test.fixme, @pytest.mark.skip,
#                  pytest.skip, t.Skip, bats skip) gives a reason: a message, or a
#                  comment on its line or the line above. One that does is a NOTE
#   QA-H3  Medium  every test block (it, test, def test_*, func TestX, @test) holds an
#                  assertion: expect, assert*, should, t.Error and t.Fatal, pytest.raises,
#                  a helper given t (Go), any checked command (bats), or a --helper
#                  NAME. Skipped tests are exempt; shell test-*.sh files are not read
#                  as blocks
#   QA-H4  Low     no retries: jest.retryTimes, this.retries, retries in a runner
#                  config, @pytest.mark.flaky, --reruns, --retries in CI
#
# Output: FAIL lines (FAIL  QA-Xn  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A when a check found nothing to check, NOTE lines
# (unrated), then "check-tests: ...".
# Limits: static and line-based. A test block ends where its parentheses (JS),
# braces (Go), indentation (Python) or closing brace in column 1 (bats) say; a
# regular expression with an unbalanced parenthesis or brace can move that end.
# Ids, names and imports are matched as words, so a word that happens to equal a
# core file's name counts as naming it.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '5p' "$0" | sed 's/^# //'; }
CRIT=(); CORE=(); PATHS=(); IDP=""; HELPERS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --criteria) [ $# -ge 2 ] || { usage >&2; exit 2; }; CRIT+=("$2"); shift 2 ;;
    --core) [ $# -ge 2 ] || { usage >&2; exit 2; }; CORE+=("$2"); shift 2 ;;
    --id-pattern) [ $# -ge 2 ] || { usage >&2; exit 2; }; IDP="$2"; shift 2 ;;
    --helper)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      case "$2" in [A-Za-z_]*) ;; *) echo "check-tests: --helper takes a function name: $2" >&2; exit 2 ;; esac
      case "$2" in *[!A-Za-z0-9_.]*) echo "check-tests: --helper takes a function name: $2" >&2; exit 2 ;; esac
      HELPERS="${HELPERS:+$HELPERS,}$(printf '%s' "$2" | sed 's/\./\\./g')"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-tests: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || { usage >&2; exit 2; }
if [ -n "$IDP" ]; then
  # An id pattern that matches the empty string would match everywhere.
  # Read from ENVIRON, as the check reads it (awk -v would process escapes first).
  if QA_RE="$IDP" LC_ALL=C awk 'BEGIN { exit (match("", ENVIRON["QA_RE"]) ? 0 : 1) }' 2>/dev/null; then
    echo "check-tests: --id-pattern must not match an empty string: $IDP" >&2; exit 2
  fi
fi

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in qa-files.sh qa-common.awk check-tests.awk; do
  [ -f "$LIB/$f" ] || { echo "check-tests: missing $LIB/$f" >&2; exit 2; }
done
# shellcheck source=lib/qa-files.sh
. "$LIB/qa-files.sh"

if [ ${#CRIT[@]} -gt 0 ]; then
  qa_collect check-tests "t td cfg pkg ci" "" "${PATHS[@]}"
  qa_collect check-tests "doc" "" "${CRIT[@]}"
  DOCS="${CRIT[*]}"
else
  qa_collect check-tests "t td cfg pkg ci doc" "" "${PATHS[@]}"
  DOCS="*.md under ${PATHS[*]}"
fi
[ ${#CORE[@]} -eq 0 ] || qa_collect check-tests "s" core "${CORE[@]}"
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

QA_CORE=""; [ ${#CORE[@]} -eq 0 ] || QA_CORE="${CORE[*]}"
QA_ID_PATTERN="$IDP" QA_HELPERS="$HELPERS" QA_DOCS="$DOCS" QA_CORE="$QA_CORE" \
  LC_ALL=C awk -f "$LIB/qa-common.awk" -f "$LIB/check-tests.awk" "${ARGS[@]}"
