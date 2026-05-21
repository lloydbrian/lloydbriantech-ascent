#!/usr/bin/env bash
# Validate that artifacts claimed in a plan file actually exist in the repo.
# Structural-only: checks file existence, not content correctness.
#
# Usage: bash make/qa-claimed-vs-actual.sh <plan-file>
# Example: bash make/qa-claimed-vs-actual.sh docs/framework/PHASE-3-RETRO-PLAN.md
#
# Parses the plan's artifact catalog table (Section 2 format) and verifies
# each Path column value exists. Compound paths (e.g., "Makefile + SKILL.md")
# are split on " + " and verified independently.

set -euo pipefail

PLAN_FILE="${1:-}"

if [ -z "$PLAN_FILE" ]; then
  printf "Usage: bash make/qa-claimed-vs-actual.sh <plan-file>\n"
  printf "  or:  make qa-claimed-vs-actual PLAN=<plan-file>\n"
  exit 1
fi

if [ ! -f "$PLAN_FILE" ]; then
  printf "qa-claimed-vs-actual: plan file not found: %s\n" "$PLAN_FILE"
  exit 1
fi

printf "qa-claimed-vs-actual: parsing %s\n" "$PLAN_FILE"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

in_artifact_table=false
while IFS= read -r line; do
  if echo "$line" | grep -q '^| # | Artifact'; then
    in_artifact_table=true
    continue
  fi
  if echo "$line" | grep -q '^|---|'; then
    continue
  fi
  if [ "$in_artifact_table" = true ] && echo "$line" | grep -q '^| [0-9]'; then
    TOTAL=$((TOTAL + 1))

    type_col=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$5); print $5}')
    if echo "$type_col" | grep -qi "APPENDIX"; then
      printf "  SKIP: artifact %s (APPENDIX — self-reference)\n" "$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
      SKIP=$((SKIP + 1))
      continue
    fi

    path_col=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/`//g' | sed 's/^ *//;s/ *$//')

    if [ -z "$path_col" ]; then
      continue
    fi

    IFS='+' read -ra PATHS <<< "$path_col"
    all_exist=true
    path_count=0
    for p in "${PATHS[@]}"; do
      p=$(echo "$p" | sed 's/^ *//;s/ *$//')
      [ -z "$p" ] && continue
      path_count=$((path_count + 1))
      if [ -f "$p" ] || [ -d "$p" ]; then
        printf "  PASS: %s\n" "$p"
      else
        all_exist=false
        printf "  FAIL: %s (claimed but absent)\n" "$p"
      fi
    done

    if [ "$all_exist" = true ]; then
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1))
    fi
  elif [ "$in_artifact_table" = true ] && ! echo "$line" | grep -q '^|'; then
    in_artifact_table=false
  fi
done < "$PLAN_FILE"

printf "\nqa-claimed-vs-actual: %s artifacts claimed, %s PASS, %s FAIL, %s SKIP\n" "$TOTAL" "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
