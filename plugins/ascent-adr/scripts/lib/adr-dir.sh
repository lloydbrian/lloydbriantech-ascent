# adr-dir.sh — sourced by check-adrs.sh and check-decision-drift.sh, from the
# repository root, so both find the same ADR folder. adr_dir sets DIR (when --dir
# left it empty), LOOKED (the places searched) and SHARED (1 when the folder was
# found by its ADR-NNN files and holds other documents too).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

# An ADR by its file name; a numbered template such as 0000-template.md is not one.
isadr() { local b; b=$(basename "$1" | tr 'A-Z' 'a-z'); printf '%s\n' "$b" | grep -Eq '^(adr-)?[0-9]+[-_][^/]*\.md$' && ! printf '%s\n' "$b" | grep -Eq '^(adr-)?0+[-_]template'; }
adrs_in() { local f; [ -n "$1" ] || return 0; for f in "$1"/*.md; do [ -f "$f" ] && isadr "$f" && printf '%s\n' "$f"; done; return 0; }
adr_dir() {
  local c cands=()
  LOOKED=""; SHARED=0
  [ -z "$DIR" ] || return 0
  if [ -f .adr-dir ]; then c=$(head -1 .adr-dir | tr -d '\r'); case "$c" in ''|/*|*..*) ;; *) cands+=("${c%/}") ;; esac; fi
  cands+=(docs/adr docs/decisions doc/adr docs/architecture/decisions docs/adrs adr decisions)
  for c in "${cands[@]}"; do
    LOOKED="$LOOKED${LOOKED:+, }$c"
    if [ -d "$c" ] && [ -n "$(adrs_in "$c")" ]; then DIR="$c"; return 0; fi
  done
  # else the folder that holds the most ADR-NNN files, two at least (the root is ".")
  DIR=$(find . -name '*.md' ! -path '*/node_modules/*' ! -path '*/vendor/*' ! -path './.git/*' 2>/dev/null \
    | grep -iE '/adr-[0-9]+[-_][^/]*\.md$' | sed 's|^\./||; s|^[^/]*$|.|; s|/[^/]*$||' | sort | uniq -c | sort -rn \
    | awk 'NR == 1 && $1 >= 2 { sub(/^ *[0-9]+ /, ""); print }') || true
  LOOKED="$LOOKED, and for a folder of ADR-NNN files"
  if [ -n "$DIR" ]; then SHARED=1; return 0; fi
  for c in "${cands[@]}"; do [ -d "$c" ] && { DIR="$c"; return 0; }; done
  return 0
}
