#!/usr/bin/env bash
# Test: ascent-sec-posture
# Verifies posture summary: severity classification and coverage gap detection.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/sec-posture"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-sec-posture: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-sec-posture: %s\n" "$1"
}

# Reusable: classify finding severity (matches skill Step 2 logic)
classify_severity() {
  local finding_type="$1"
  case "$finding_type" in
    env_not_gitignored|hardcoded_credentials|privileged_container)
      echo "high" ;;
    missing_security_header|http_in_production)
      echo "medium" ;;
    missing_env_example)
      echo "low" ;;
    *)
      echo "unknown" ;;
  esac
}

# Reusable: check surface assessability (matches skill Step 1 logic)
check_surface_assessable() {
  local surface="$1"
  local fixture_dir="$2"
  case "$surface" in
    env_scope)      [ -f "$fixture_dir/.gitignore" ] ;;
    credentials)    [ -d "$fixture_dir/backend" ] ;;
    container)      [ -f "$fixture_dir/docker-compose.yml" ] ;;
    nginx)          [ -f "$fixture_dir/nginx/nginx.prod.conf" ] ;;
    secret_inventory) [ -f "$fixture_dir/.env.example" ] ;;
  esac
}

# Test 1: Severity classification — high vs medium vs low
cleanup
mkdir -p "$FIXTURES_DIR"
SEV_HIGH=$(classify_severity "hardcoded_credentials")
SEV_MED=$(classify_severity "missing_security_header")
SEV_LOW=$(classify_severity "missing_env_example")
if [ "$SEV_HIGH" = "high" ] && [ "$SEV_MED" = "medium" ] && [ "$SEV_LOW" = "low" ]; then
  assert_pass "severity classification: credentials=high, missing header=medium, no .env.example=low"
else
  assert_fail "severity: high=$SEV_HIGH, med=$SEV_MED, low=$SEV_LOW"
fi

# Test 2: Coverage gap detection — nginx missing → not assessed
cleanup
mkdir -p "$FIXTURES_DIR/backend"
printf '.env\n' > "$FIXTURES_DIR/.gitignore"
echo "services:" > "$FIXTURES_DIR/docker-compose.yml"
printf 'PORT=\n' > "$FIXTURES_DIR/.env.example"
# nginx config intentionally NOT created → coverage gap
NGINX_ASSESSABLE=true
check_surface_assessable "nginx" "$FIXTURES_DIR" || NGINX_ASSESSABLE=false
ENV_ASSESSABLE=false
check_surface_assessable "env_scope" "$FIXTURES_DIR" && ENV_ASSESSABLE=true
CONTAINER_ASSESSABLE=false
check_surface_assessable "container" "$FIXTURES_DIR" && CONTAINER_ASSESSABLE=true
if [ "$NGINX_ASSESSABLE" = false ] && [ "$ENV_ASSESSABLE" = true ] && [ "$CONTAINER_ASSESSABLE" = true ]; then
  assert_pass "coverage gap: nginx=not assessable (gap), env_scope=assessable, container=assessable"
else
  assert_fail "gaps: nginx=$NGINX_ASSESSABLE (want false), env=$ENV_ASSESSABLE (want true), container=$CONTAINER_ASSESSABLE (want true)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-sec-posture tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
