#!/usr/bin/env bash
# Render SDLC-sectioned help by parsing make targets annotated with `## SECTION: description`.
#
# Section order (META · DEV · TEST · QA · DOCS · DIST · RELEASE) is the meta-repo convention
# per CLAUDE.md. Targets without a recognized section prefix are silently omitted.
#
# Compatible with bash 3.2 (macOS system bash) — no globstar, no associative arrays.

set -euo pipefail

SECTIONS=(META DEV TEST QA DOCS DIST RELEASE)

FILES=()
[ -f Makefile ] && FILES+=(Makefile)
if [ -d make ]; then
  while IFS= read -r f; do
    FILES+=("$f")
  done < <(find make -maxdepth 1 -name '*.mk' -type f | LC_ALL=C sort)
fi

# Collect "SECTION|target|description" entries from all sources.
entries=$(grep -hE '^[a-zA-Z][a-zA-Z0-9_-]*:.*##[[:space:]]+[A-Z]+:' "${FILES[@]}" 2>/dev/null \
  | sed -E 's/^([a-zA-Z0-9_-]+):[^#]*##[[:space:]]+([A-Z]+):[[:space:]]*(.*)$/\2|\1|\3/' \
  || true)

NAME="${FRAMEWORK_NAME:-lloydbriantech-ascent}"
VERSION="${FRAMEWORK_VERSION:-unknown}"

printf "\n"
printf "  ASCENT framework — Make operator vocabulary\n"
printf "  %s v%s\n" "$NAME" "$VERSION"
printf "\n"

for section in "${SECTIONS[@]}"; do
  matched=$(printf "%s\n" "$entries" | awk -F'|' -v s="$section" 'NF==3 && $1==s')
  if [ -n "$matched" ]; then
    printf "  %s\n" "$section"
    printf "%s\n" "$matched" | awk -F'|' '{ printf "    %-30s %s\n", $2, $3 }'
    printf "\n"
  fi
done

printf "  Run 'make <target>' to invoke. Bare 'make' runs 'make help'.\n"
printf "\n"
