#!/usr/bin/env bash
# Validate frontmatter of every SKILL.md under skills/.
#
# Required fields per ADR-005 + Claude skill SDK conventions:
#   name, description, version, allowed-tools
#
# Exits 0 with a clear message when no SKILL.md files exist yet (Phase 1 Chunk 2
# is the first chunk that produces one — this script must not break Chunks 1
# and 2's CI by treating "no input" as failure).
#
# Compatible with bash 3.2.

set -euo pipefail

required_fields=(name description version allowed-tools)
files=()

if [ -d skills ]; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(find skills -name SKILL.md -type f | LC_ALL=C sort)
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "qa-skill-frontmatter: no SKILL.md files found under skills/, nothing to validate — OK"
  exit 0
fi

fail=0
for f in "${files[@]}"; do
  echo "Checking: $f"
  # Extract YAML frontmatter: content between the first two `---` lines.
  fm=$(awk 'BEGIN{c=0} /^---$/{c++; next} c==1{print} c>=2{exit}' "$f")
  if [ -z "$fm" ]; then
    echo "  FAIL: no YAML frontmatter found (expected --- ... --- block at top of file)"
    fail=1
    continue
  fi
  for field in "${required_fields[@]}"; do
    if ! printf "%s\n" "$fm" | grep -qE "^${field}:"; then
      echo "  FAIL: missing required field '${field}'"
      fail=1
    fi
  done
done

if [ $fail -ne 0 ]; then
  echo "qa-skill-frontmatter: validation FAILED"
  exit 1
fi

echo "qa-skill-frontmatter: ${#files[@]} file(s) validated — OK"
