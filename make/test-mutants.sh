#!/usr/bin/env bash
# Negative-control harness for the embedded-skill tests (ADR-008).
#
# A test that has never failed proves nothing. For every row in make/mutants.tsv
# this script:
#   1. copies a freshly rendered project,
#   2. applies the mutant's sed expression and confirms it changed the file
#      (a stale anchor is reported as ANCHOR MISS, never as a pass),
#   3. runs the named test and expects it to FAIL ("killed").
# Before any mutant runs, every named test must pass on the unmutated project,
# so a kill always means the mutation was detected, not that the test was broken.
#
# Portable: GNU/Linux and BSD/macOS, bash 3.2+.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTANTS="$REPO_ROOT/make/mutants.tsv"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

bash "$REPO_ROOT/make/render-template.sh" "$WORK/base" >/dev/null

# Control run: each named test passes unmutated.
tests_named=$(grep -v '^#' "$MUTANTS" | awk -F'\t' 'NF>=4 {print $4}' | LC_ALL=C sort -u)
for t in $tests_named; do
  if ! (cd "$WORK/base" && bash "tests/skills/$t" </dev/null >/dev/null 2>&1); then
    echo "test-mutants: control run failed — $t does not pass on the unmutated project:"
    (cd "$WORK/base" && bash "tests/skills/$t" </dev/null) || true
    exit 1
  fi
done

killed=0; survived=0; missed=0; total=0
expected_rows=$(grep -v '^#' "$MUTANTS" | grep -c . || true)
while IFS="$(printf '\t')" read -r id file expr test desc; do
  case "$id" in ''|\#*) continue ;; esac
  total=$((total + 1))
  rm -rf "$WORK/m"
  cp -R "$WORK/base" "$WORK/m"
  target="$WORK/m/$file"
  if [ ! -f "$target" ]; then
    printf "  ANCHOR MISS  %-28s %s not found\n" "$id" "$file"
    missed=$((missed + 1)); continue
  fi
  cp "$target" "$WORK/before"
  sed -i.mut-bak -e "$expr" "$target" && rm -f "$target.mut-bak"
  if cmp -s "$WORK/before" "$target"; then
    printf "  ANCHOR MISS  %-28s sed changed nothing in %s\n" "$id" "$file"
    missed=$((missed + 1)); continue
  fi
  if (cd "$WORK/m" && bash "tests/skills/$test" </dev/null >/dev/null 2>&1); then
    printf "  SURVIVED     %-28s %s — %s still passes\n" "$id" "$desc" "$test"
    survived=$((survived + 1))
  else
    printf "  killed       %-28s by %s\n" "$id" "$test"
    killed=$((killed + 1))
  fi
done < "$MUTANTS"
mutant_rows=$total

if [ "$mutant_rows" -ne "$expected_rows" ]; then
  echo "test-mutants: ran $mutant_rows of $expected_rows mutant rows — a row was skipped or malformed"
  exit 1
fi

# Validator controls: qa-skill-frontmatter must reject each broken SKILL.md
# and accept the well-formed one.
write_skill() {  # DIR NAME DESCRIPTION
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: >-\n  %s\nversion: 0.0.0\nallowed-tools:\n  - Read\n---\n# body\n' "$2" "$3" > "$1/SKILL.md"
}
validator_case() {  # ID EXPECT(pass|fail) NAME DIRNAME DESCRIPTION
  local root="$WORK/v-$1"
  rm -rf "$root"
  write_skill "$root/$4" "$3" "$5"
  total=$((total + 1))
  if bash "$REPO_ROOT/make/qa-skill-frontmatter.sh" "$root" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$2" ]; then
    printf "  confirmed    %-28s validator answered %s\n" "$1" "$got"
    killed=$((killed + 1))
  else
    printf "  SURVIVED     %-28s validator answered %s, expected %s\n" "$1" "$got" "$2"
    survived=$((survived + 1))
  fi
}
validator_case V00-wellformed pass ascent-x ascent-x "Use when asked to do x. Does x."
validator_case V01-no-trigger fail ascent-x ascent-x "Does x for the project."
validator_case V02-placeholder fail ascent-x ascent-x "Use when asked to do x for <<PROJECT_TITLE>>."
validator_case V03-name-mismatch fail ascent-y ascent-x "Use when asked to do x. Does x."

printf "\ntest-mutants: %s mutants — %s killed, %s survived, %s anchor misses\n" \
  "$total" "$killed" "$survived" "$missed"
[ "$survived" -eq 0 ] && [ "$missed" -eq 0 ] && [ "$total" -gt 0 ]
