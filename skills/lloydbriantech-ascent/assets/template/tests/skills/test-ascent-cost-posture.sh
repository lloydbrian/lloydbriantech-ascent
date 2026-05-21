#!/usr/bin/env bash
# Test: ascent-cost-posture
# Verifies cost discipline checks: resource limit detection and IaC presence.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/cost-posture"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-cost-posture: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-cost-posture: %s\n" "$1"
}

# Reusable: detect resource limits in compose (matches skill Step 1 logic)
has_resource_limits() {
  local compose_file="$1"
  grep -qE 'mem_limit|cpus|deploy:|resources:' "$compose_file" 2>/dev/null
}

# Reusable: detect IaC presence (matches skill Step 3 logic)
detect_iac() {
  local project_dir="$1"
  [ -d "$project_dir/terraform" ] && echo "terraform" && return
  [ -d "$project_dir/pulumi" ] && echo "pulumi" && return
  [ -d "$project_dir/cdk" ] && echo "cdk" && return
  [ -d "$project_dir/cloudformation" ] && echo "cloudformation" && return
  [ -f "$project_dir/serverless.yml" ] && echo "serverless" && return
  local tf_count
  tf_count=$(find "$project_dir" -maxdepth 2 -name "*.tf" 2>/dev/null | wc -l | tr -d ' ')
  [ "$tf_count" -gt 0 ] && echo "terraform-files" && return
  echo "none"
}

# Test 1: Resource limit detection — limits present PASS, absent CONCERN
cleanup
mkdir -p "$FIXTURES_DIR"
cat > "$FIXTURES_DIR/docker-compose.yml" << 'EOF'
services:
  backend:
    build: ./backend
    mem_limit: 512m
    cpus: 0.5
  frontend:
    build: ./frontend
    mem_limit: 256m
EOF
LIMITS_PRESENT=false
has_resource_limits "$FIXTURES_DIR/docker-compose.yml" && LIMITS_PRESENT=true
cat > "$FIXTURES_DIR/docker-compose-no-limits.yml" << 'EOF'
services:
  backend:
    build: ./backend
    ports:
      - "3001:3001"
EOF
LIMITS_ABSENT=true
has_resource_limits "$FIXTURES_DIR/docker-compose-no-limits.yml" && LIMITS_ABSENT=false
if [ "$LIMITS_PRESENT" = true ] && [ "$LIMITS_ABSENT" = true ]; then
  assert_pass "resource limits: compose with limits=detected, compose without limits=not detected"
else
  assert_fail "limits: present=$LIMITS_PRESENT (want true), absent=$LIMITS_ABSENT (want true)"
fi

# Test 2: IaC presence — terraform dir detected, empty project returns none
cleanup
mkdir -p "$FIXTURES_DIR/terraform"
IAC_FOUND=$(detect_iac "$FIXTURES_DIR")
rm -rf "$FIXTURES_DIR/terraform"
IAC_NONE=$(detect_iac "$FIXTURES_DIR")
if [ "$IAC_FOUND" = "terraform" ] && [ "$IAC_NONE" = "none" ]; then
  assert_pass "IaC presence: terraform/ dir=terraform, empty project=none"
else
  assert_fail "IaC: found=$IAC_FOUND (want terraform), none=$IAC_NONE (want none)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-cost-posture tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
