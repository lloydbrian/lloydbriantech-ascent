#!/usr/bin/env bash
# Which of the slow checks a change needs (ADR-023).
#
# CI runs this on every pull request, and make gate-changed runs it locally: it
# reads the paths the change touches and prints what to run for it. The cheap
# checks always run, on both platforms: make qa, make test-skills and the plugin
# gate (make test-plugins). The scope decides the slow parts:
#   t11           the plugins whose behavior tests T11 runs: all, none or a list
#   t13_selftest  1 when T13.0, the ownership checker's fixture tests, runs
#   harness       the harness self-tests to run (a JSON list)
#   targets       the negative-control jobs (a JSON list): a whole group, or the
#                 controls named by id, all in one "selected" job
#
# The rules, for each changed path:
#   every path          the controls whose file it is (their anchors and kills),
#                       and T11 for the plugins whose behavior tests read it: a
#                       "$ROOT/<path>" (or "$HERE/../../../<path>") in a plugin's
#                       tests reads that path; a glob over every plugin's directory
#                       ("../ascent-*") reads every plugins/ path
#   plugins/<p>/, tests/plugins/<p>/
#                       T11 for <p>, the groups <p> and <p>-*, and ownership
#   make/check-ownership.sh, tests/meta/test-check-ownership.sh
#                       T13.0, the ownership and ownership-checker groups
#   docs/framework/OWNERSHIP.md                       the ownership group
#   make/mutants.tsv, skills/lloydbriantech-ascent/assets/   the core group
#   tests/meta/test-gate-fast.sh                      the harness group (T14's controls)
#   tests/meta/test-gate-scope.sh                     the scope group
#   tests/meta/test-gate-sections.sh, tests/meta/test-mutants-harness.sh
#                       that harness self-test
#   make/test-mutants.sh  a changed control line: that control (validator_case
#                       lines: the core group; a harness-group control also runs
#                       test-mutants-harness); any other changed line, or no
#                       changed line found: everything
#   Makefile            a FRAMEWORK_VERSION line only: nothing more; else everything
#   docs, *.md outside plugins and tests, LICENSE*, .github/ (not workflows),
#   .claude-plugin/, .vscode/, tools/, make/plugins.lock, other skills/ files
#                       nothing more: the gate checks them
#   anything else, including the gate, the harness, this file, make/*.mk and
#   workflows           everything
# --full (a push to main, the weekly run, a manual run) runs everything.
#
# Usage: gate-scope.sh [--full] [--base REF] [--explain] [--run]
#   --base REF  compare with the merge base of REF and HEAD (default origin/main):
#               the working tree, with untracked files, so uncommitted work counts
#   --explain   print, on stderr, each path's rule and what will run
#   --run       print that, then run it (make gate-changed); fails if any step fails
# Prints full=, t11=, t13_selftest=, harness= and targets= lines on stdout.
# Tests set ASCENT_SCOPE_PATHS (a file of paths), ASCENT_SCOPE_DIFF (a -U0 diff
# of make/test-mutants.sh and Makefile), ASCENT_SCOPE_MANIFEST (the output of
# make/test-mutants.sh --list) and ASCENT_SCOPE_TESTS (a tests/plugins directory)
# in place of git, the harness and the repository's behavior tests.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+.

set -euo pipefail
export LC_ALL=C
case "${1:-}" in -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL=0; BASE=origin/main; EXPLAIN=0; RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1 ;;
    --base) [ $# -ge 2 ] || { echo "gate-scope: --base needs a ref" >&2; exit 2; }; BASE=$2; shift ;;
    --explain) EXPLAIN=1 ;;
    --run) RUN=1; EXPLAIN=1 ;;
    *) echo "gate-scope: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
  shift
done
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# The controls (group, id, label, kind, file, ...) and the groups, core first.
if [ -n "${ASCENT_SCOPE_MANIFEST:-}" ]; then cp "$ASCENT_SCOPE_MANIFEST" "$W/manifest"
else ASCENT_MUTANT_GROUP= ASCENT_MUTANT_IDS= bash "$ROOT/make/test-mutants.sh" --list > "$W/manifest"; fi
GROUPS_ALL="core $(awk -F'\t' '!seen[$1]++ { print $1 }' "$W/manifest" | tr '\n' ' ')"

: > "$W/paths"; : > "$W/diff"; FROM="--full"
if [ "$FULL" = 0 ]; then
  if [ -n "${ASCENT_SCOPE_PATHS:-}" ]; then
    grep -v '^$' "$ASCENT_SCOPE_PATHS" | sort -u > "$W/paths" || true
    [ -z "${ASCENT_SCOPE_DIFF:-}" ] || cp "$ASCENT_SCOPE_DIFF" "$W/diff"
    FROM="the test input"
  else
    # The operator's git settings must not change what is read: no colour, no
    # external diff, the a/ and b/ prefixes the parser expects
    g() { git -C "$ROOT" -c color.ui=false -c color.diff=false -c diff.noprefix=false -c diff.mnemonicPrefix=false "$@"; }
    mb=$(g merge-base "$BASE" HEAD 2>/dev/null) \
      || { echo "gate-scope: no merge base of $BASE and HEAD (fetch $BASE, or pass --full)" >&2; exit 2; }
    { g diff --name-only --no-renames --no-ext-diff "$mb"; g ls-files --others --exclude-standard; } \
      | sort -u > "$W/paths"
    g diff -U0 --no-renames --no-ext-diff --src-prefix=a/ --dst-prefix=b/ "$mb" -- make/test-mutants.sh Makefile > "$W/diff"
    FROM="$BASE (merge base $(printf '%s' "$mb" | cut -c1-7))"
  fi
fi

# What each plugin's behavior tests read outside the plugin: plugin<TAB>path lines,
# and the plugins whose tests read every plugin's directory.
TESTS=${ASCENT_SCOPE_TESTS:-$ROOT/tests/plugins}
: > "$W/readers"; : > "$W/allreaders"
for d in "$TESTS"/*/; do
  [ -d "$d" ] || continue
  q=$(basename "$d")
  { grep -ohE '(\$\{?ROOT\}?|\$HERE/\.\./\.\./\.\.)/[A-Za-z0-9_.][A-Za-z0-9_./-]*' "$d"*.sh 2>/dev/null || true; } \
    | sed -E 's#^(\$\{?ROOT\}?|\$HERE/\.\./\.\./\.\.)/##; s#/+$##' | sort -u \
    | awk -v q="$q" '$0 != "plugins/" q && index($0, "plugins/" q "/") != 1 { print q "\t" $0 }' >> "$W/readers"
  if grep -qE '(\.\./|plugins/)ascent-\*|plugins/\*' "$d"*.sh 2>/dev/null; then echo "$q" >> "$W/allreaders"; fi
done

T11=""; T11ALL=0; T13=0; HARN=""; WHOLE=" "; IDS=""
why() { printf '  %-52s %s\n' "$1" "$2" >> "$W/why"; }
add_t11() { case " $T11 " in *" $1 "*) ;; *) T11="$T11 $1" ;; esac; }
readers() {  # PATH — T11 for the plugins whose behavior tests read PATH
  local q r
  while IFS="$(printf '\t')" read -r q r; do
    case "$1" in "$r"|"$r"/*) add_t11 "$q"; why "$1" "read by $q's behavior tests: T11 for $q" ;; esac
  done < "$W/readers"
  case "$1" in
    plugins/*/*) while IFS= read -r q; do add_t11 "$q"; why "$1" "$q's behavior tests read every plugin: T11 for $q"; done < "$W/allreaders" ;;
  esac
}
everything() { FULL=1; why "$1" "everything: $2"; }
group() { case "$WHOLE" in *" $1 "*) ;; *) WHOLE="$WHOLE$1 " ;; esac; }
harness_test() { case " $HARN " in *" $1 "*) ;; *) HARN="$HARN $1" ;; esac; }
plugin() {  # PATH PLUGIN — T11 for the plugin, its groups and ownership
  local g gs=""
  add_t11 "$2"
  for g in $GROUPS_ALL; do case "$g" in "$2"|"$2"-*) group "$g"; gs="$gs $g" ;; esac; done
  group ownership
  why "$1" "plugin $2: T11 for $2, groups${gs:- (none)} ownership"
}
# changed FILE — the lines the diff adds or removes in FILE, with their sign
changed() {
  awk -v f="$1" '/^diff --git / { on = ($NF == "b/" f) ; next } on && /^(\+\+\+|---) / { next } on && /^[+-]/' "$W/diff"
}
harness_lines() {  # control lines run their controls; any other changed line runs everything
  local line body id g other=0
  changed make/test-mutants.sh > "$W/harness-lines"
  # A changed file with no changed line found (a mode change, a diff not parsed) fails closed
  [ -s "$W/harness-lines" ] || other=1
  while IFS= read -r line; do
    body=${line#?}
    if grep -qE '^[[:space:]]*(#|$)' <<< "$body"; then continue; fi
    if grep -qE '^([A-Z][A-Z0-9_]*=[^ ]* )*(plugin_case|plugin_case_rm|expect_case) ' <<< "$body"; then
      [ "${line%"$body"}" = + ] || continue   # a removed control needs no run; T13.11 checks the count
      id=$(awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^P[0-9]+-/) { print $i; exit } }' <<< "$body")
      g=$(awk -F'\t' -v id="$id" '$2 == id { print $1; exit }' "$W/manifest")
      if [ -n "$id" ] && [ -n "$g" ]; then
        IDS="$IDS $id"
        # test-mutants-harness runs the harness group whole and counts its results
        if [ "$g" = harness ]; then harness_test test-mutants-harness; fi
      else other=1; fi
    elif grep -qE '^validator_case ' <<< "$body"; then group core
    else other=1; fi
  done < "$W/harness-lines"
  if [ "$other" = 1 ]; then everything make/test-mutants.sh "a change to the harness, not only to control lines"
  else why make/test-mutants.sh "control lines only: those controls"; fi
}

while IFS= read -r p; do
  readers "$p"
  case "$p" in
    .github/workflows/*) everything "$p" "a workflow" ;;
    make/test-plugins.sh) everything "$p" "the gate's own code" ;;
    make/gate-scope.sh) everything "$p" "the scope rules themselves" ;;
    make/test-mutants.sh) harness_lines ;;
    make/check-ownership.sh|tests/meta/test-check-ownership.sh)
      T13=1; group ownership; group ownership-checker; why "$p" "the ownership checker: T13.0, groups ownership ownership-checker" ;;
    docs/framework/OWNERSHIP.md) group ownership; why "$p" "the registry: the ownership group" ;;
    make/mutants.tsv|skills/lloydbriantech-ascent/assets/*) group core; why "$p" "the template: the core group" ;;
    tests/meta/test-gate-fast.sh) group harness; why "$p" "T14's fixture: the harness group" ;;
    tests/meta/test-gate-scope.sh) group scope; why "$p" "the scope tests: the scope group" ;;
    tests/meta/test-gate-sections.sh|tests/meta/test-mutants-harness.sh)
      t=${p#tests/meta/}; harness_test "${t%.sh}"; why "$p" "a harness self-test: ${t%.sh}" ;;
    plugins/*/*|tests/plugins/*/*) q=${p#plugins/}; q=${q#tests/plugins/}; plugin "$p" "${q%%/*}" ;;
    Makefile)
      changed Makefile > "$W/make-lines"
      if [ -s "$W/make-lines" ] && ! grep -qvE '^[+-]FRAMEWORK_VERSION := ' "$W/make-lines"; then
        why "$p" "the version line only: the gate checks it"
      else everything "$p" "a make change"; fi ;;
    plugins/*|tests/plugins/*) everything "$p" "no rule for this path" ;;
    make/plugins.lock) why "$p" "the plugin lock: the gate checks it (T10)" ;;
    tests/*|make/*) everything "$p" "no rule for this path" ;;
    *.md|docs/*|LICENSE*|.github/*|.claude-plugin/*|.vscode/*|tools/*|skills/*|.editorconfig|.gitignore)
      why "$p" "docs and metadata: the gate checks them" ;;
    *) everything "$p" "no rule for this path" ;;
  esac
done < "$W/paths"

# The controls whose file a path is (or a directory a path is in).
awk -F'\t' 'NR == FNR { p[$0] = 1; next }
  { if ($5 in p) { print $1 "\t" $2 "\t" $5; next }
    for (q in p) if (index(q, $5 "/") == 1) { print $1 "\t" $2 "\t" $5; next } }' "$W/paths" "$W/manifest" > "$W/byfile"
if [ -s "$W/byfile" ]; then
  IDS="$IDS $(cut -f2 "$W/byfile" | tr '\n' ' ')"
  cut -f3 "$W/byfile" | sort | uniq -c | while read -r n f; do why "$f" "$n control(s) edit it"; done
fi

if [ "$FULL" = 1 ]; then
  T11ALL=1; T13=1; HARN=" test-gate-sections test-mutants-harness"; WHOLE=" $GROUPS_ALL "; IDS=""
fi
# The selected controls not in a group that runs whole, in manifest order, once each.
SEL=$(awk -F'\t' -v ids=" $IDS " -v whole="$WHOLE" 'index(ids, " " $2 " ") && !index(whole, " " $1 " ") && !seen[$2]++ { print $2 }' "$W/manifest" | tr '\n' ' ' | sed 's/ $//')

t11=all
[ "$T11ALL" = 1 ] || t11=$(printf '%s' "${T11# }" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')
[ -n "$t11" ] || t11=none
harness="[$(for h in $HARN; do printf '"%s",' "$h"; done | sed 's/,$//')]"
targets="["
for g in $GROUPS_ALL; do case "$WHOLE" in *" $g "*) targets="$targets{\"name\":\"$g\",\"group\":\"$g\",\"ids\":\"\"}," ;; esac; done
[ -z "$SEL" ] || targets="$targets{\"name\":\"selected\",\"group\":\"all\",\"ids\":\"$SEL\"},"
targets="${targets%,}]"

printf 'full=%s\nt11=%s\nt13_selftest=%s\nharness=%s\ntargets=%s\n' "$FULL" "$t11" "$T13" "$harness" "$targets"

if [ "$EXPLAIN" = 1 ]; then
  # No case statement inside $( ): bash 3.2 reads its ")" as the end of the substitution
  gl=""; for g in $GROUPS_ALL; do case "$WHOLE" in *" $g "*) gl="$gl $g" ;; esac; done; gl=${gl# }
  {
    if [ "$FROM" = --full ]; then echo "gate-scope: --full, everything runs"
    else echo "gate-scope: $(wc -l < "$W/paths" | tr -d ' ') changed path(s), from $FROM"; fi
    [ ! -s "$W/why" ] || sort -s -k1,1 "$W/why"
    echo "runs:"
    echo "  always         make qa, make test-skills, make test-plugins"
    echo "  T11            $t11"
    echo "  T13.0          $([ "$T13" = 1 ] && echo yes || echo no)"
    echo "  harness tests  $([ -n "$HARN" ] && echo ${HARN} || echo none)"
    echo "  groups         ${gl:-none}"
    echo "  controls       ${SEL:-none}"
  } >&2
fi
[ "$RUN" = 1 ] || exit 0

# --run: every step runs, and the summary says which failed.
t11_only=$t11; [ "$t11" != all ] || t11_only=""
: > "$W/steps"
step() {  # NAME COMMAND... — run one step, record its result
  local name=$1 rc=0; shift
  printf '\n== %s\n' "$name" >&2
  "$@" || rc=$?
  printf '%s\t%s\n' "$([ "$rc" = 0 ] && echo PASS || echo FAIL)" "$name" >> "$W/steps"
}
step "make qa" make -C "$ROOT" --no-print-directory qa
step "make test-skills" make -C "$ROOT" --no-print-directory test-skills
step "make test-plugins (T11: $t11, T13.0: $T13)" env ASCENT_T11_ONLY="$t11_only" ASCENT_T13_SELFTEST="$T13" bash "$ROOT/make/test-plugins.sh"
for h in $HARN; do step "$h" bash "$ROOT/tests/meta/$h.sh"; done
for g in $GROUPS_ALL; do
  case "$WHOLE" in *" $g "*) step "negative controls: $g" env ASCENT_MUTANT_GROUP="$g" ASCENT_MUTANT_IDS="" bash "$ROOT/make/test-mutants.sh" ;; esac
done
[ -z "$SEL" ] || step "negative controls: selected" env ASCENT_MUTANT_GROUP=all ASCENT_MUTANT_IDS="$SEL" bash "$ROOT/make/test-mutants.sh"
printf '\ngate-scope: %s\n' "what ran:" >&2; sed 's/^/  /' "$W/steps" >&2
! grep -q '^FAIL' "$W/steps"
