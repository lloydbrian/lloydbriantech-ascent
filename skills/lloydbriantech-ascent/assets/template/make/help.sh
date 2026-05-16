#!/usr/bin/env bash
# Render SDLC-sectioned help by parsing make targets annotated with `## SECTION: description`.
#
# Project-level section order per MAKE-NAMING.md:
#   META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA
#
# Compatible with bash 3.2.

set -euo pipefail

SECTIONS=(META DEV TEST QA SEC VALIDATE DOCS INFRA)

FILES=()
[ -f Makefile ] && FILES+=(Makefile)
if [ -d make ]; then
  while IFS= read -r f; do
    FILES+=("$f")
  done < <(find make -maxdepth 1 -name '*.mk' -type f | LC_ALL=C sort)
fi

entries=$(grep -hE '^[a-zA-Z][a-zA-Z0-9_-]*:.*##[[:space:]]+[A-Z]+:' "${FILES[@]}" 2>/dev/null \
  | sed -E 's/^([a-zA-Z0-9_-]+):[^#]*##[[:space:]]+([A-Z]+):[[:space:]]*(.*)$/\2|\1|\3/' \
  || true)

SLUG="${PROJECT_SLUG:-<<PROJECT_SLUG>>}"
VERSION="${PROJECT_VERSION:-<<PROJECT_VERSION>>}"

printf "\n"
printf "  %s — Make operator vocabulary\n" "$SLUG"
printf "  v%s\n" "$VERSION"
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
