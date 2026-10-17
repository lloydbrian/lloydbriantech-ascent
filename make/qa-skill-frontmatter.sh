#!/usr/bin/env bash
# Validate frontmatter of every SKILL.md under skills/.
#
# Required fields per ADR-005 + Claude skill SDK conventions:
#   name, description, version, allowed-tools
# Routing rules (ADR-008, audit F35/F36):
#   - name matches the skill's directory name
#   - description leads with its trigger ("Use when …" / "Use for …"), because
#     Claude decides when to load a skill from this field alone
#   - description contains no <<PLACEHOLDER>> tokens (it must read correctly
#     before the template is rendered and when packaged as a plugin)
#
# Usage: qa-skill-frontmatter.sh [ROOT]   (ROOT defaults to skills)
#
# Exits 0 with a clear message when no SKILL.md files exist yet (Phase 1 Chunk 2
# is the first chunk that produces one — this script must not break Chunks 1
# and 2's CI by treating "no input" as failure).
#
# Compatible with bash 3.2.

set -euo pipefail

required_fields=(name description version allowed-tools)
ROOT="${1:-skills}"
files=()

if [ -d "$ROOT" ]; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$ROOT" -name SKILL.md -type f | LC_ALL=C sort)
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
  # name must match the directory
  name=$(printf "%s\n" "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  dir=$(basename "$(dirname "$f")")
  if [ -n "$name" ] && [ "$name" != "$dir" ]; then
    echo "  FAIL: name '$name' does not match directory '$dir'"
    fail=1
  fi
  # description: from 'description:' up to the next top-level key, joined
  desc=$(printf "%s\n" "$fm" | awk '/^description:/{on=1; sub(/^description:[[:space:]]*(>-|>|\|-|\|)?[[:space:]]*/,""); if(length) print; next} on && /^[A-Za-z_-]+:/{exit} on{sub(/^[[:space:]]+/,""); print}' | tr '\n' ' ')
  case "$desc" in
    "Use when "*|"Use for "*) : ;;
    *) echo "  FAIL: description must start with 'Use when' or 'Use for' (got: ${desc:0:60}…)"; fail=1 ;;
  esac
  if printf "%s" "$desc" | grep -qE '<<[A-Z_]+>>'; then
    echo "  FAIL: description contains a <<PLACEHOLDER>> token"
    fail=1
  fi
done

if [ $fail -ne 0 ]; then
  echo "qa-skill-frontmatter: validation FAILED"
  exit 1
fi

echo "qa-skill-frontmatter: ${#files[@]} file(s) validated — OK"
