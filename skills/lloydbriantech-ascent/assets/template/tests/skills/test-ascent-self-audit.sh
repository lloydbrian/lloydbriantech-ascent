#!/usr/bin/env bash
# Test: ascent-self-audit
# Verifies the umbrella audit composes component checks and validates direct invariants.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
#
# Composition test discipline (per Cluster 1 refinement):
#   - Runs component tests as smoke test for the delegation pattern
#   - Runs direct invariant checks on the project AND on broken fixtures, so
#     every check is shown to both pass and fail (Principle §16)
#   - Does NOT mock results or test aggregation logic (v0.4.x hardening)
set -euo pipefail

COMPONENT_SKILLS=("ascent-layering-check" "ascent-env-audit" "ascent-observability-check")
FIXTURES_DIR="tests/skills/.fixtures/self-audit"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

assert_pass() {
  local desc="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-self-audit: %s\n" "$desc"
}

assert_fail() {
  local desc="$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-self-audit: %s\n" "$desc"
}

# Test 1: Component tests pass (composition smoke test)
# Runs the three component tests. If any fails, the composition is broken.
COMPONENT_PASS=true
for skill in "${COMPONENT_SKILLS[@]}"; do
  TEST_SCRIPT="tests/skills/test-${skill}.sh"
  if [ -f "$TEST_SCRIPT" ]; then
    if bash "$TEST_SCRIPT" > /dev/null 2>&1; then
      : # component passed
    else
      assert_fail "component test $skill failed — composition broken"
      COMPONENT_PASS=false
    fi
  else
    assert_fail "component test $TEST_SCRIPT not found"
    COMPONENT_PASS=false
  fi
done
if [ "$COMPONENT_PASS" = true ]; then
  assert_pass "all 3 component tests pass (composition validated)"
fi

# Stand-in for the skill's direct invariant checks (Steps 4-16 subset).
# audit_dir DIR — prints one "PASS §N" or "FAIL §N" line per checked invariant.
audit_dir() {
  local d="$1" services labels
  if [ -f "$d/backend/Dockerfile" ]; then echo "PASS §1"; else echo "FAIL §1"; fi
  if [ -f "$d/Makefile" ]; then echo "PASS §2"; else echo "FAIL §2"; fi
  if [ -f "$d/docs/architecture/decisions/INDEX.md" ]; then echo "PASS §7"; else echo "FAIL §7"; fi
  if [ -f "$d/.ascent-meta.json" ] && [ "$(count_matches '"phase"[[:space:]]*:[[:space:]]*"[^"]+"' "$d/.ascent-meta.json")" -ge 1 ]; then
    echo "PASS §8"
  else
    echo "FAIL §8"
  fi
  services=$(count_matches 'container_name:' "$d/docker-compose.yml")
  labels=$(count_matches 'project:' "$d/docker-compose.yml")
  if [ "$services" -gt 0 ] && [ "$labels" -ge "$services" ]; then echo "PASS §9"; else echo "FAIL §9"; fi
}

result_for() { printf '%s\n' "$1" | grep -E " $2\$" | cut -d' ' -f1; }

# Test 2: The project itself passes every direct invariant check
PROJECT_RESULTS=$(audit_dir ".")
PROJECT_FAILS=$(printf '%s\n' "$PROJECT_RESULTS" | grep -c '^FAIL' || true)
if [ "$PROJECT_FAILS" -eq 0 ]; then
  assert_pass "project passes §1 §2 §7 §8 §9 direct checks"
else
  assert_fail "project direct checks: $(printf '%s' "$PROJECT_RESULTS" | grep '^FAIL' | tr '\n' ' ')"
fi

# Test 3: §9 label check fails when a compose service has no project label
cleanup
mkdir -p "$FIXTURES_DIR"
cat > "$FIXTURES_DIR/docker-compose.yml" << 'EOF'
services:
  backend:
    container_name: app-backend
    labels:
      project: app
  worker:
    container_name: app-worker
EOF
if [ "$(result_for "$(audit_dir "$FIXTURES_DIR")" '§9')" = "FAIL" ]; then
  assert_pass "§9 label check flags an unlabeled compose service"
else
  assert_fail "§9 should FAIL when one of two services is unlabeled"
fi

# Test 3b: §8 fails when .ascent-meta.json has an empty phase value
cleanup
mkdir -p "$FIXTURES_DIR"
printf '{\n  "framework": "lloydbriantech-ascent",\n  "phase": ""\n}\n' > "$FIXTURES_DIR/.ascent-meta.json"
if [ "$(result_for "$(audit_dir "$FIXTURES_DIR")" '§8')" = "FAIL" ]; then
  assert_pass "§8 phase check flags an empty phase value"
else
  assert_fail "§8 should FAIL when phase is empty"
fi

# Test 4: Partial-state project — an empty directory reports FAIL for every
# checked invariant instead of crashing or passing.
cleanup
mkdir -p "$FIXTURES_DIR"
EMPTY_RESULTS=$(audit_dir "$FIXTURES_DIR")
EMPTY_FAILS=$(printf '%s\n' "$EMPTY_RESULTS" | grep -c '^FAIL' || true)
if [ "$EMPTY_FAILS" -eq 5 ]; then
  assert_pass "partial-state handling: empty project reports 5/5 FAIL without crashing"
else
  assert_fail "empty project should report 5 FAIL lines, got $EMPTY_FAILS: $EMPTY_RESULTS"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-self-audit tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
