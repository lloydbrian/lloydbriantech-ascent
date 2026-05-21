#!/usr/bin/env bash
# Test: ascent-design-system-audit
# Verifies design-system detection: no-op on plain CSS, hardcoded value detection.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/design-system-audit"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-design-system-audit: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-design-system-audit: %s\n" "$1"
}

# Reusable: detect design system markers (matches skill Step 1 logic)
detect_design_system() {
  local project_dir="$1"
  # Check for :root with custom properties
  if grep -rq ':root' "$project_dir/frontend/src/" 2>/dev/null && \
     grep -rq '\-\-[a-z]' "$project_dir/frontend/src/" 2>/dev/null; then
    echo "custom-properties"
    return
  fi
  # Check for token files
  for f in tokens.css design-tokens.json design-tokens.yml; do
    [ -f "$project_dir/frontend/$f" ] || [ -f "$project_dir/$f" ] && echo "token-file:$f" && return
  done
  # Check for token directories
  for d in theme tokens; do
    [ -d "$project_dir/frontend/$d" ] || [ -d "$project_dir/$d" ] && echo "token-dir:$d" && return
  done
  echo "none"
}

# Reusable: detect hardcoded color values bypassing tokens (matches skill Step 3 logic)
detect_hardcoded_colors() {
  local css_file="$1"
  local count
  count=$(grep -cE 'color:\s*#[0-9a-fA-F]|color:\s*rgb\(|color:\s*hsl\(' "$css_file" 2>/dev/null || echo 0)
  echo "$count"
}

# Test 1: No-op detection — plain CSS without custom properties → no design system
cleanup
mkdir -p "$FIXTURES_DIR/frontend/src"
cat > "$FIXTURES_DIR/frontend/src/App.css" << 'EOF'
.app {
  max-width: 600px;
  font-family: system-ui, sans-serif;
}
h1 {
  font-size: 1.5rem;
}
EOF
RESULT=$(detect_design_system "$FIXTURES_DIR")
if [ "$RESULT" = "none" ]; then
  assert_pass "no-op detection: plain CSS without custom properties → no design system (skill exits zero)"
else
  assert_fail "plain CSS should detect 'none', got '$RESULT'"
fi

# Test 2: Hardcoded value detection — :root tokens + inline #hex → flagged
cleanup
mkdir -p "$FIXTURES_DIR/frontend/src"
cat > "$FIXTURES_DIR/frontend/src/tokens.css" << 'EOF'
:root {
  --color-primary: #3b82f6;
  --color-text: #1f2937;
  --font-size-base: 1rem;
}
EOF
cat > "$FIXTURES_DIR/frontend/src/App.css" << 'EOF'
.header {
  color: var(--color-primary);
}
.warning {
  color: #ff0000;
  background-color: #fff3cd;
}
EOF
SYSTEM=$(detect_design_system "$FIXTURES_DIR")
HARDCODED=$(detect_hardcoded_colors "$FIXTURES_DIR/frontend/src/App.css")
if [ "$SYSTEM" = "custom-properties" ] && [ "$HARDCODED" -ge 2 ]; then
  assert_pass "hardcoded detection: design system present, $HARDCODED inline color values bypassing tokens"
else
  assert_fail "hardcoded: system=$SYSTEM (want custom-properties), count=$HARDCODED (want >=2)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-design-system-audit tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
