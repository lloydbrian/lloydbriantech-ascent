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
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

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
    env_not_gitignored|env_committed|dockerfile_copies_env|hardcoded_credentials|privileged_container)
      echo "high" ;;
    env_not_dockerignored|env_example_value|missing_security_header|http_in_production)
      echo "medium" ;;
    undeclared_env_var|missing_env_example)
      echo "low" ;;
    deprecated_header_only|hsts_not_terminated_here)
      echo "info" ;;
    *)
      echo "unknown" ;;
  esac
}

# Reusable: check surface assessability (matches skill Step 1 logic)
check_surface_assessable() {
  local surface="$1" d="$2" x
  case "$surface" in
    env_scope|secret_inventory)
      return 0 ;;   # always assessable: absence is itself a finding
    credentials)
      for x in backend frontend server src app api; do [ -d "$d/$x" ] && return 0; done; return 1 ;;
    container)
      [ -n "$(find "$d" -maxdepth 2 \( -name '*compose*.yml' -o -name '*compose*.yaml' -o -name 'Dockerfile*' \) -not -path '*/node_modules/*' 2>/dev/null | head -1)" ] ;;
    nginx)
      [ -n "$(find "$d" \( -path '*/nginx/*.conf' -o -name 'nginx*.conf' \) -not -path '*/node_modules/*' -exec grep -l 'server[[:space:]]*{' {} + 2>/dev/null | head -1)" ] ;;
  esac
}

# Reusable: count critical coverage gaps (skill Steps 1 and 3). Env-file scope is
# always assessable. Container security with no compose files or Dockerfiles is
# "not present", never a gap. Only credential hygiene can be a critical gap.
critical_gaps() {
  local d="$1" n=0 s
  for s in credentials; do check_surface_assessable "$s" "$d" || n=$((n + 1)); done
  echo "$n"
}

# Reusable: posture rating (skill Step 4) — first matching rule wins.
# posture_rating HIGH MEDIUM CRITICAL_GAPS
posture_rating() {
  if [ "$1" -gt 0 ]; then echo "weak"
  elif [ "$2" -eq 0 ] && [ "$3" -eq 0 ]; then echo "strong"
  else echo "moderate"; fi
}

# Test 1: Severity classification — every row of the shared table
cleanup
mkdir -p "$FIXTURES_DIR"
GOT=""
for t in env_not_gitignored env_committed dockerfile_copies_env hardcoded_credentials privileged_container env_not_dockerignored env_example_value missing_security_header http_in_production undeclared_env_var missing_env_example deprecated_header_only hsts_not_terminated_here; do
  GOT="$GOT $t=$(classify_severity "$t")"
done
WANT=" env_not_gitignored=high env_committed=high dockerfile_copies_env=high hardcoded_credentials=high privileged_container=high env_not_dockerignored=medium env_example_value=medium missing_security_header=medium http_in_production=medium undeclared_env_var=low missing_env_example=low deprecated_header_only=info hsts_not_terminated_here=info"
if [ "$GOT" = "$WANT" ]; then
  assert_pass "severity classification matches the shared table (5 high, 4 medium, 2 low, 2 info)"
else
  assert_fail "severity:$GOT
  want:$WANT"
fi

# Test 2: Coverage — a non-ASCENT layout (src/, compose.yaml) is assessed; nginx
# absent is a gap; .gitignore and .env.example are always assessable
cleanup
mkdir -p "$FIXTURES_DIR/src"
echo "services:" > "$FIXTURES_DIR/compose.yaml"
# nginx config, .gitignore and .env.example intentionally NOT created
NGINX_ASSESSABLE=true
check_surface_assessable "nginx" "$FIXTURES_DIR" || NGINX_ASSESSABLE=false
ENV_ASSESSABLE=false
check_surface_assessable "env_scope" "$FIXTURES_DIR" && ENV_ASSESSABLE=true
CONTAINER_ASSESSABLE=false
check_surface_assessable "container" "$FIXTURES_DIR" && CONTAINER_ASSESSABLE=true
CRED_ASSESSABLE=false
check_surface_assessable "credentials" "$FIXTURES_DIR" && CRED_ASSESSABLE=true
mkdir -p "$FIXTURES_DIR/nginx"; printf 'gzip on;\n' > "$FIXTURES_DIR/nginx/gzip.conf"
SNIPPET_ASSESSABLE=true
check_surface_assessable "nginx" "$FIXTURES_DIR" || SNIPPET_ASSESSABLE=false
if [ "$NGINX_ASSESSABLE" = false ] && [ "$ENV_ASSESSABLE" = true ] && [ "$CONTAINER_ASSESSABLE" = true ] && \
   [ "$CRED_ASSESSABLE" = true ] && [ "$SNIPPET_ASSESSABLE" = false ]; then
  assert_pass "coverage: src/ and compose.yaml assessed; nginx (and a snippet-only nginx dir) a gap; env scope always assessable"
else
  assert_fail "gaps: nginx=$NGINX_ASSESSABLE (false) env=$ENV_ASSESSABLE (true) container=$CONTAINER_ASSESSABLE (true) creds=$CRED_ASSESSABLE (true) snippet=$SNIPPET_ASSESSABLE (false)"
fi

# Test 3: Posture rating — the rules cover every case and Low/Info never change it
R1=$(posture_rating 1 0 0); R2=$(posture_rating 0 0 0); R3=$(posture_rating 0 1 0); R4=$(posture_rating 0 0 1)
if [ "$R1" = "weak" ] && [ "$R2" = "strong" ] && [ "$R3" = "moderate" ] && [ "$R4" = "moderate" ]; then
  assert_pass "posture: any High=weak, clean=strong, one Medium=moderate, critical gap=moderate"
else
  assert_fail "posture: high=$R1 (weak) clean=$R2 (strong) medium=$R3 (moderate) gap=$R4 (moderate)"
fi

# Test 4: A project with no containers can still rate strong; a project whose
# source cannot be located cannot
cleanup
mkdir -p "$FIXTURES_DIR/nocontainers/app" "$FIXTURES_DIR/nosource/site"
echo "services:" > "$FIXTURES_DIR/nosource/compose.yaml"
G_NOCONT=$(critical_gaps "$FIXTURES_DIR/nocontainers")
G_NOSRC=$(critical_gaps "$FIXTURES_DIR/nosource")
CONT_PRESENT=true
check_surface_assessable "container" "$FIXTURES_DIR/nocontainers" || CONT_PRESENT=false
R_NOCONT=$(posture_rating 0 0 "$G_NOCONT"); R_NOSRC=$(posture_rating 0 0 "$G_NOSRC")
if [ "$CONT_PRESENT" = false ] && [ "$R_NOCONT" = "strong" ] && [ "$R_NOSRC" = "moderate" ]; then
  assert_pass "posture: no containers (not present) can be strong; source not located is a gap (moderate)"
else
  assert_fail "posture: containers-present=$CONT_PRESENT (false) no-containers=$R_NOCONT (strong) no-source=$R_NOSRC (moderate)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-sec-posture tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
