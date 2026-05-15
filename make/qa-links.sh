#!/usr/bin/env bash
# Validate internal markdown links across the repo.
#
# Scope: root *.md (excluding LICENSE*), docs/**/*.md, skills/**/*.md
# Internal = relative-path target. External (http/https/mailto) and anchor-only
# links are skipped. Anchor fragments on internal paths are stripped before
# resolution (the path must exist; the anchor itself isn't checked).
#
# Limitations (documented, not enforced):
#   - Inline `[text](target)` only; reference-style `[t][r]` links not validated
#   - Links inside fenced code blocks are scanned (rare false positives)
#
# Exits 0 with a clear message when no markdown files in scope exist.
#
# Compatible with bash 3.2.

set -euo pipefail

files=()

# Root markdown (excluding LICENSE files).
while IFS= read -r f; do
  case "$(basename "$f")" in
    LICENSE|LICENSE-*) continue ;;
  esac
  files+=("$f")
done < <(find . -maxdepth 1 -name '*.md' -type f | LC_ALL=C sort)

if [ -d docs ]; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(find docs -name '*.md' -type f | LC_ALL=C sort)
fi

if [ -d skills ]; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(find skills -name '*.md' -type f | LC_ALL=C sort)
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "qa-links: no markdown files found in scope, nothing to validate — OK"
  exit 0
fi

total=0
broken=0

for f in "${files[@]}"; do
  dir=$(dirname "$f")
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    # Strip link title if present: "[t](path \"title\")" → "path"
    target="${target%% *}"
    case "$target" in
      http://*|https://*|mailto:*|'#'*) continue ;;
    esac
    path="${target%%#*}"
    [ -z "$path" ] && continue
    total=$((total + 1))
    if [ "${path:0:1}" = "/" ]; then
      resolved=".${path}"
    else
      resolved="$dir/$path"
    fi
    if [ ! -e "$resolved" ]; then
      printf "  BROKEN: %s -> %s  (resolved: %s)\n" "$f" "$target" "$resolved"
      broken=$((broken + 1))
    fi
  done < <(grep -oE '\[[^]]+\]\([^)]+\)' "$f" \
    | sed -E 's/^\[[^]]+\]\(([^)]+)\)$/\1/' || true)
done

if [ $broken -gt 0 ]; then
  echo "qa-links: ${broken} broken link(s) out of ${total} internal link(s) across ${#files[@]} file(s) — FAILED"
  exit 1
fi

if [ $total -eq 0 ]; then
  echo "qa-links: ${#files[@]} file(s) scanned, no internal links found — OK"
else
  echo "qa-links: ${#files[@]} file(s) scanned, ${total} internal link(s) validated — OK"
fi
