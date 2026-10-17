#!/usr/bin/env bash
# Render the project template into TARGET_DIR with fixed self-test values.
#
# Used by `make test-skills` and `make test-mutants` so the 28 embedded-skill
# tests run against a rendered project, the same shape a scaffolded project has.
# Portable (GNU/Linux and BSD/macOS, bash 3.2+). Fails loudly when any
# <<PLACEHOLDER>> survives rendering — the check the scratch scaffold lacked (F19).
#
# Not the Phase 4 scaffolder: no interview, no capability gating, fixed values.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 TARGET_DIR" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/skills/lloydbriantech-ascent/assets/template"
TARGET_DIR="$1"

if [ -e "$TARGET_DIR" ] && [ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
  echo "render-template: $TARGET_DIR exists and is not empty — refusing to overwrite" >&2
  exit 1
fi
mkdir -p "$TARGET_DIR"
cp -R "$TEMPLATE_DIR/." "$TARGET_DIR/"

# Rename *.tmpl files.
find "$TARGET_DIR" -name '*.tmpl' -type f | while IFS= read -r f; do
  mv "$f" "${f%.tmpl}"
done

# One sed script for every canonical placeholder (longest names first so that
# no shorter name can match inside a longer one).
SED_SCRIPT="$(mktemp)"
trap 'rm -f "$SED_SCRIPT"' EXIT
cat > "$SED_SCRIPT" << 'EOF'
s|<<INSIDE_CONTAINER_MARKER>>|ASCENT_SELFTEST_INSIDE_CONTAINER|g
s|<<PROJECT_SLUG_UPPER>>|ASCENT_SELFTEST|g
s|<<FRAMEWORK_VERSION>>|0.0.0-selftest|g
s|<<PROJECT_VERSION>>|0.1.0|g
s|<<CONTAINER_PROD>>|ascent-selftest-prod|g
s|<<CONTAINER_DEV>>|ascent-selftest-dev|g
s|<<PROJECT_TITLE>>|ASCENT Selftest|g
s|<<PROJECT_LABEL>>|ascent-selftest|g
s|<<PROJECT_SLUG>>|ascent-selftest|g
s|<<SCAFFOLD_DATE>>|2026-01-01|g
s|<<SCAFFOLD_YEAR>>|2026|g
s|<<NETWORK_NAME>>|ascent-selftest-net|g
s|<<PROJECT_PKG>>|ascent-selftest|g
s|<<VOLUME_DATA>>|ascent-selftest-data|g
s|<<IMAGE_PROD>>|ascent-selftest:prod|g
s|<<IMAGE_DEV>>|ascent-selftest:dev|g
s|<<ENV_PREFIX>>|ASCENT_SELFTEST|g
s|<<GH_OWNER>>|example-owner|g
s|<<GH_REPO>>|example-owner/ascent-selftest|g
s|<<BRAND>>|example-brand|g
EOF

# Substitute in text files only (grep -I treats binary files as non-matching).
find "$TARGET_DIR" -type f | while IFS= read -r f; do
  if grep -Iq . "$f" 2>/dev/null; then
    sed -i.render-bak -f "$SED_SCRIPT" "$f"
    rm -f "$f.render-bak"
  fi
done

LEFTOVER="$(grep -rIlE '<<[A-Z_]+>>' "$TARGET_DIR" 2>/dev/null || true)"
if [ -n "$LEFTOVER" ]; then
  echo "render-template: placeholders survived rendering in:" >&2
  printf '%s\n' "$LEFTOVER" | sed 's/^/  /' >&2
  exit 1
fi

echo "render-template: rendered template into $TARGET_DIR — OK"
