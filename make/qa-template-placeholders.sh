#!/usr/bin/env bash
# Validate that all <<PLACEHOLDER>> tokens in template files belong to the
# canonical set from SLUG-CONVENTIONS.md + scaffold-time non-slug placeholders.
#
# Exits 0 with a clear message when the template directory doesn't exist yet.
# Compatible with bash 3.2.

set -euo pipefail

TEMPLATE_DIR="skills/lloydbriantech-ascent/assets/template"

# Canonical placeholder names.
# Slug-derived (per SLUG-CONVENTIONS.md derivation table):
#   PROJECT_SLUG, PROJECT_SLUG_UPPER, PROJECT_TITLE, PROJECT_PKG,
#   PROJECT_LABEL, CONTAINER_DEV, CONTAINER_PROD, IMAGE_DEV, IMAGE_PROD,
#   NETWORK_NAME, VOLUME_DATA, INSIDE_CONTAINER_MARKER, ENV_PREFIX, GH_REPO
# Scaffold-time (non-slug):
#   GH_OWNER, BRAND, SCAFFOLD_DATE, SCAFFOLD_YEAR, FRAMEWORK_VERSION
CANONICAL=(
  PROJECT_SLUG
  PROJECT_SLUG_UPPER
  PROJECT_TITLE
  PROJECT_PKG
  PROJECT_LABEL
  CONTAINER_DEV
  CONTAINER_PROD
  IMAGE_DEV
  IMAGE_PROD
  NETWORK_NAME
  VOLUME_DATA
  INSIDE_CONTAINER_MARKER
  ENV_PREFIX
  GH_REPO
  GH_OWNER
  BRAND
  SCAFFOLD_DATE
  SCAFFOLD_YEAR
  FRAMEWORK_VERSION
  PROJECT_VERSION
)

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "qa-template-placeholders: template directory not found at $TEMPLATE_DIR, nothing to validate — OK"
  exit 0
fi

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find "$TEMPLATE_DIR" -type f | LC_ALL=C sort)

if [ ${#files[@]} -eq 0 ]; then
  echo "qa-template-placeholders: no files found in $TEMPLATE_DIR, nothing to validate — OK"
  exit 0
fi

fail=0
total_placeholders=0
unique_placeholders=()

for f in "${files[@]}"; do
  while IFS= read -r placeholder; do
    [ -z "$placeholder" ] && continue
    total_placeholders=$((total_placeholders + 1))
    found=0
    for c in "${CANONICAL[@]}"; do
      if [ "$placeholder" = "$c" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      printf "  UNRECOGNIZED: %s -> <<%s>>\n" "$f" "$placeholder"
      fail=1
    fi
  done < <(grep -oE '<<[A-Z_]+>>' "$f" 2>/dev/null | sed 's/<<//;s/>>//' | LC_ALL=C sort -u || true)
done

if [ $fail -ne 0 ]; then
  echo "qa-template-placeholders: unrecognized placeholder(s) found — FAILED"
  exit 1
fi

if [ $total_placeholders -eq 0 ]; then
  echo "qa-template-placeholders: ${#files[@]} file(s) scanned, no placeholders found — OK"
else
  echo "qa-template-placeholders: ${#files[@]} file(s) scanned, ${total_placeholders} unique placeholder name(s) validated — OK"
fi
