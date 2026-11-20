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
# Groups (one CI job each, run in parallel): "core" holds the embedded-skill rows
# and the validator controls; each "mutant_group <name>" line below starts a
# plugin's controls (a plugin with slow tests splits into several groups).
# ASCENT_MUTANT_GROUP (make test-mutants GROUP=<g>) runs one group; unset runs
# every group. --groups-json prints the group list for the CI matrix, so a new
# plugin section joins CI without a workflow change.
#
# ASCENT_MUTANT_IDS="<id> ..." runs only the named plugin controls of the group (CI
# runs the controls whose files a change touches this way, ADR-023); an id the
# group does not have is an error. --list prints the controls the run would
# launch, one line each, without running them: group, id, label, kind, file, T11
# scope and the T13.0 and T14 switches, tab-separated (make/gate-scope.sh reads it).
#
# ASCENT_MUTANT_MODE=full runs every control on the whole gate, as before v0.4.10;
# ASCENT_MUTANT_JOBS=<n> sets how many controls run at once (default: the number
# of cores); ASCENT_MUTANT_RAW=1 makes the harness group report its expect_case
# controls as they are, not as confirmed (tests/meta/test-mutants-harness.sh).
# While controls run, a progress bar on stderr shows how many are done and running,
# how many were not killed, and the time left, when stderr is a terminal;
# ASCENT_MUTANT_PROGRESS=0 turns it off and =1 forces it. Every run ends with a
# summary block above the totals line: the three slowest controls, and the three
# checks and groups that took the most time. ASCENT_MUTANT_TIMES=<file> also writes
# every timed control, slowest first: seconds, status, id, group, check, cached (ADR-025);
# the baselines are in group and check "baseline".
#
# ASCENT_MUTANT_CACHE=<dir> reuses kills on local reruns (ADR-025): a T11 control
# of one plugin that was killed before is reported "killed … (cached)" without
# running, when nothing it can read has changed: the control itself, the plugin,
# its behavior tests, skills/, the marketplace, make/test-plugins.sh, this harness
# (without the other controls' declarations), bash and awk. Only kills are kept;
# a survivor, an anchor miss or a copy failure always runs again. Controls of
# several plugins, of T13.0 or T14, with a fault or a rebuild, the expect_case
# controls and full mode never use it. The baselines always run. CI never sets it.
#
# Portable: GNU/Linux and BSD/macOS, bash 3.2+.

set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;; esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTANTS="$REPO_ROOT/make/mutants.tsv"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Background jobs ignore SIGINT, so an interrupt sends TERM to the whole process
# group: every running control and its gate stop, and EXIT removes $WORK.
trap 'trap "" INT TERM; kill -TERM 0 2>/dev/null; exit 130' INT TERM

GROUPS_ALL="core $(awk '/^mutant_group [a-z0-9-]+$/ { print $2 }' "$0" | tr '\n' ' ' | sed 's/ $//')"
if [ "${1:-}" = --groups-json ]; then
  printf '%s\n' "$GROUPS_ALL" | awk '{ s = "["; for (i = 1; i <= NF; i++) s = s (i > 1 ? "," : "") "\"" $i "\""; print s "]" }'
  exit 0
fi
LIST=0; [ "${1:-}" = --list ] && LIST=1
GROUP="${ASCENT_MUTANT_GROUP:-all}"
case " all $GROUPS_ALL " in *" $GROUP "*) ;; *) echo "test-mutants: unknown group '$GROUP' (groups: all $GROUPS_ALL)" >&2; exit 2 ;; esac
MODE="${ASCENT_MUTANT_MODE:-fast}"
case "$MODE" in fast|full) ;; *) echo "test-mutants: unknown mode '$MODE' (fast or full)" >&2; exit 2 ;; esac
JOBS="${ASCENT_MUTANT_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"
case "$JOBS" in ''|*[!0-9]*|0) echo "test-mutants: ASCENT_MUTANT_JOBS must be a positive number, got '$JOBS'" >&2; exit 2 ;; esac
CACHE="${ASCENT_MUTANT_CACHE:-}"
if [ -n "$CACHE" ]; then
  if [ "$MODE" = full ]; then echo "test-mutants: ASCENT_MUTANT_CACHE is ignored in full mode" >&2; CACHE=""
  elif ! mkdir -p "$CACHE" 2>/dev/null || [ ! -w "$CACHE" ]; then echo "test-mutants: cannot write ASCENT_MUTANT_CACHE directory '$CACHE'" >&2; exit 2
  else CACHE=$(cd "$CACHE" && pwd); fi
fi
TIMES="${ASCENT_MUTANT_TIMES:-}"
if [ -n "$TIMES" ] && ! : 2>/dev/null >> "$TIMES"; then echo "test-mutants: cannot write ASCENT_MUTANT_TIMES file '$TIMES'" >&2; exit 2; fi
PROGRESS="${ASCENT_MUTANT_PROGRESS:-auto}"
case "$PROGRESS" in
  auto) if [ -t 2 ]; then PROGRESS=1; else PROGRESS=0; fi ;;
  0|1) ;;
  *) echo "test-mutants: ASCENT_MUTANT_PROGRESS must be 0 or 1, got '$PROGRESS'" >&2; exit 2 ;;
esac
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) FULL='█'; EMPTY='░'; DOT='·'; RULE='─' ;;
  *) FULL='#'; EMPTY='-'; DOT='|'; RULE='-' ;;
esac
IDS=$(printf '%s' "${ASCENT_MUTANT_IDS:-}" | tr -s ' \t\n' '   ' | sed 's/^ //; s/ $//')
CUR_GROUP=core
mutant_group() { CUR_GROUP="$1"; }
in_group() { [ "$GROUP" = all ] || [ "$GROUP" = "$CUR_GROUP" ]; }
selected() { [ -z "$IDS" ] || case " $IDS " in *" $1 "*) true ;; *) false ;; esac; }  # ID — is it in the run?
# listed KIND ID LABEL FILE — in list mode, print the control's line instead of running it
listed() {
  [ "$LIST" = 1 ] || return 1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$CUR_GROUP" "$2" "$3" "$1" "$4" "${T11_ONLY:-all}" "${T13_SELFTEST:-0}" "${T14_SELFTEST:-0}"
}
killed=0; survived=0; missed=0; copyfail=0; total=0
# Every finished control adds a line, seconds<TAB>status<TAB>id, to $WORK/done
# (core rows to $WORK/done-core, untimed): the progress bar and the summary read them.
T0=$SECONDS
: > "$WORK/done"; : > "$WORK/done-core"
note_core() { printf -- '-\t%s\t%s\n' "$1" "$2" >> "$WORK/done-core"; }  # STATUS ID
clock() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }  # SECONDS -> m:ss

if in_group && [ "$LIST" = 0 ] && [ -z "$IDS" ]; then

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

expected_rows=$(grep -v '^#' "$MUTANTS" | grep -c . || true)
while IFS="$(printf '\t')" read -r id file expr test desc; do
  case "$id" in ''|\#*) continue ;; esac
  total=$((total + 1))
  rm -rf "$WORK/m"
  cp -R "$WORK/base" "$WORK/m"
  target="$WORK/m/$file"
  if [ ! -f "$target" ]; then
    printf "  ANCHOR MISS  %-28s %s not found\n" "$id" "$file"
    missed=$((missed + 1)); note_core "ANCHOR MISS" "$id"; continue
  fi
  cp "$target" "$WORK/before"
  sed -i.mut-bak -e "$expr" "$target" && rm -f "$target.mut-bak"
  if cmp -s "$WORK/before" "$target"; then
    printf "  ANCHOR MISS  %-28s sed changed nothing in %s\n" "$id" "$file"
    missed=$((missed + 1)); note_core "ANCHOR MISS" "$id"; continue
  fi
  if (cd "$WORK/m" && bash "tests/skills/$test" </dev/null >/dev/null 2>&1); then
    printf "  SURVIVED     %-28s %s — %s still passes\n" "$id" "$desc" "$test"
    survived=$((survived + 1)); note_core SURVIVED "$id"
  else
    printf "  killed       %-28s by %s\n" "$id" "$test"
    killed=$((killed + 1)); note_core killed "$id"
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
    killed=$((killed + 1)); note_core confirmed "$1"
  else
    printf "  SURVIVED     %-28s validator answered %s, expected %s\n" "$1" "$got" "$2"
    survived=$((survived + 1)); note_core SURVIVED "$1"
  fi
}
validator_case V00-wellformed pass ascent-x ascent-x "Use when asked to do x. Does x."
validator_case V01-no-trigger fail ascent-x ascent-x "Does x for the project."
validator_case V02-placeholder fail ascent-x ascent-x "Use when asked to do x for <<PROJECT_TITLE>>."
validator_case V03-name-mismatch fail ascent-y ascent-x "Use when asked to do x. Does x."
fi

# Plugin controls (ADR-009): make/test-plugins.sh must fail on each broken copy
# of the repository, and fail with the check named in EXPECT, so a control
# cannot pass because some other check happened to break. A baseline copy with
# no change must pass, or every control below would be meaningless: it runs
# alongside the controls, and a failed baseline fails the run.
#
# Fast mode (the default, ADR-018) runs only the named check, stops T11 at its
# first failure and runs controls in parallel, $JOBS at a time, each on its own
# copy; results print in control order. A control fast mode does not kill reruns
# in full mode, the whole gate as before, and its report carries the FAIL lines
# of both runs. If full mode kills it, the two modes disagree: that is reported
# as MODES DIFFER and fails the run, never counted as a kill.
# ASCENT_MUTANT_MODE=full runs every control in full mode only.
#
# A copy that fails (a full disk: tar's "Write error") is an infrastructure error,
# not a verdict: tar's messages go to DIR.copy-err, never into the control's result,
# and the control is reported as COPY FAIL, counted apart, and fails the run.
# MUTANT_FAULT=copy-fail makes every copy fail: only the harness group sets it.
plugin_copy() {  # DIR — fresh copy of the repository without .git; fails if the copy fails
  rm -rf "$1" "$1.copy-err"; mkdir -p "$1"
  if [ "${MUTANT_FAULT:-}" = copy-fail ]; then echo "tar: Write error (MUTANT_FAULT=copy-fail)" > "$1.copy-err"; return 1; fi
  if (cd "$REPO_ROOT" && tar --exclude ./.git -cf - .) 2>"$1.copy-err" | (cd "$1" && tar -xf -) 2>>"$1.copy-err"; then
    rm -f "$1.copy-err"; return 0
  fi
  [ -s "$1.copy-err" ] || echo "tar failed without a message" > "$1.copy-err"
  return 1
}
copy_failed() {  # ID DIR — if DIR's copy failed, print COPY FAIL with tar's first message
  [ -f "$2.copy-err" ] || return 1
  printf "  COPY FAIL    %-28s copying the repository failed: %s\n" "$1" "$(head -1 "$2.copy-err" | cut -c1-80)"
  rm -rf "$2" "$2.copy-err"
}
# T13.0 (the ownership checker's fixture tests) and T14 (the fast-mode self-test)
# are skipped unless a control sets T13_SELFTEST=1 or T14_SELFTEST=1: only the
# controls that edit the checker, fast mode or their tests need them.
# A baseline (base) runs what the run's controls are judged by, from the BASE_
# settings below: in fast mode only their checks and their plugins' behavior
# tests, in full mode the whole gate; T13.0 and T14 when a control needs them.
plugin_gate() {  # DIR [fast LABEL EDITED-FILE | base] — run test-plugins on a copy; output in DIR.out
  local only="" t11fast=0 first="" t11=${T11_ONLY:-} t13=${T13_SELFTEST:-0} t14=${T14_SELFTEST:-0}
  if [ "${2:-}" = fast ]; then
    # MUTANT_FAULT=fast-pass makes fast mode pass everything: only the harness
    # group sets it, to prove that a disagreement between the modes is reported
    if [ "${MUTANT_FAULT:-}" = fast-pass ]; then : > "$1.out"; return 0; fi
    # the edited path relative to its plugin, so T11 runs the tests that name it first
    only=$3; t11fast=1
    case "$4" in plugins/*/*) first=${4#plugins/*/} ;; tests/plugins/*/*) first=${4#tests/plugins/*/} ;; *) first=$(basename "$4") ;; esac
  elif [ "${2:-}" = base ]; then
    only=$BASE_ONLY; t11=$BASE_T11; t13=$BASE_T13; t14=$BASE_T14
  fi
  # One awk and one shard for T13.0's fixture tests: the controls already run in parallel
  ASCENT_SKIP_CLAUDE_CLI=1 ASCENT_HOOK_TEST_ONE_AWK=1 ASCENT_TEST_JOBS=1 ASCENT_T11_ONLY="$t11" \
    ASCENT_T13_SELFTEST="$t13" ASCENT_T14_SELFTEST="$t14" \
    ASCENT_ONLY="$only" ASCENT_T11_FAST="$t11fast" ASCENT_T11_FIRST="$first" \
    bash "$1/make/test-plugins.sh" "$1" </dev/null >"$1.out" 2>&1
}
# fails OUT — its FAIL lines, each with up to 5 of the indented reason lines the
# gate prints under it (T7), all indented
fails() { awk 'BEGIN { d = -1 } /^FAIL/ { print; d = 0; next } d >= 0 && d < 5 && /^      / { print; d++; next } { d = -1 }' "$1" | sed 's/^/                 /'; }
plugin_baseline() {  # ID COPY — the unmodified copy must pass what the run's controls are judged by
  if copy_failed "$1" "$2"; then return 1; fi
  if plugin_gate "$2" base; then
    printf "  control      %-28s unmodified copy passes test-plugins%s\n" "$1" "$BASE_NOTE"
  else
    printf "  CONTROL FAIL %-28s unmodified copy fails test-plugins%s:\n" "$1" "$BASE_NOTE"
    fails "$2.out"; return 1
  fi
}
t11_scope() {  # PATH -> the plugin whose files it is in, or empty (run every plugin's tests)
  if [ -n "${T11_FORCE:-}" ]; then T11_ONLY=$T11_FORCE; return; fi   # set by a group whose controls never need T11
  case "$1" in
    plugins/*) T11_ONLY=${1#plugins/}; T11_ONLY=${T11_ONLY%%/*} ;;
    tests/plugins/*) T11_ONLY=${1#tests/plugins/}; T11_ONLY=${T11_ONLY%%/*} ;;
    *) T11_ONLY="" ;;
  esac
}

# Parallel runs. Each control runs in the background and writes its result to
# $WORK/r/<n>; flush prints finished results in control order, and the totals
# are counted from the results once every control is done.
mkdir -p "$WORK/r"
seq=0; next=1; T1=$SECONDS; BARRED=0
# The number of controls this run launches, counted from the declarations in this
# file so the bar knows its end; the run fails if it launched a different number.
# A control's id is the first P<n>- word of its line and its label the word after;
# the fast-mode T11 baseline runs only when a control is judged by T11.
PLANNED=$(awk -v g="$GROUP" -v mode="$MODE" -v ids=" $IDS " '
  /^mutant_group [a-z0-9-]+$/ { cur = $2; next }
  cur == "" || (g != "all" && g != cur) { next }
  /^([A-Z0-9_]+=[^ ]* )*(plugin_case|plugin_case_rm|expect_case) / {
    id = ""; for (i = 1; i < NF; i++) if ($i ~ /^P[0-9]+-/) { id = $i; label = $(i + 1); break }
    if (ids != "  " && index(ids, " " id " ") == 0) next
    n++; if (label == "T11") t11 = 1 }
  END { if (g != "core") n += 1 + (mode == "fast" && t11); print n + 0 }' "$0")
unbar() { if [ "$BARRED" = 1 ]; then printf '\r\033[K' >&2; BARRED=0; fi; }
bar() {  # [final] — redraw the progress bar on stderr
  [ "$PROGRESS" = 1 ] && [ "$seq" -gt 0 ] || return 0
  local fin nk run tot w=20 i=0 fill s="" el left=""
  fin=$(wc -l < "$WORK/done"); fin=$((fin))
  nk=$(awk -F'\t' '$2 !~ /^(killed|confirmed|control)$/ { n++ } END { print n + 0 }' "$WORK/done")
  run=$(jobs -pr | wc -l); run=$((run))
  tot=$PLANNED; if [ "$seq" -gt "$tot" ]; then tot=$seq; fi
  fill=$((fin * w / tot))
  while [ "$i" -lt "$w" ]; do if [ "$i" -lt "$fill" ]; then s="$s$FULL"; else s="$s$EMPTY"; fi; i=$((i + 1)); done
  el=$((SECONDS - T1))
  if [ "${1:-}" = final ]; then
    printf '\r\033[K[%s] %d/%d %3d%% %s %s\n' "$s" "$fin" "$tot" $((fin * 100 / tot)) "$DOT" "$(clock "$el")" >&2
    BARRED=0; return 0
  fi
  if [ "$fin" -gt 0 ] && [ "$fin" -lt "$tot" ]; then left=" $DOT ~$(clock $((el * (tot - fin) / fin))) left"; fi
  printf '\r\033[K[%s] %3d/%d %3d%% %s %d running %s %d not killed %s %s%s' \
    "$s" "$fin" "$tot" $((fin * 100 / tot)) "$DOT" "$run" "$DOT" "$nk" "$DOT" "$(clock "$el")" "$left" >&2
  BARRED=1
}
# record SECONDS RESULT GROUP CHECK — the line for $WORK/done: the result's status
# and id sit at fixed columns of its first line ("  %-12s %-28s")
record() {
  awk -v t="$1" -v g="$3" -v c="$4" 'NR == 1 { st = substr($0, 3, 12); sub(/ +$/, "", st); id = substr($0, 16); sub(/ .*/, "", id); print t "\t" st "\t" id "\t" g "\t" c "\t" (/ \(cached\)$/ ? "cached" : "") }
    END { if (NR == 0) print t "\t?\t?\t" g "\t" c }' "$2"
}
flush() {
  while [ -f "$WORK/r/$next" ]; do unbar; cat "$WORK/r/$next"; next=$((next + 1)); done
  bar
}
launch() {  # COMMAND ARGS... — run one control in the background, at most $JOBS at a time
  local n grp=$CUR_GROUP chk=baseline
  # control_run KIND ID LABEL … and expect_run STATUS ID LABEL …: the check is $4
  case "$1" in control_run|expect_run) chk=$4 ;; *) grp=baseline ;; esac
  seq=$((seq + 1)); total=$((total + 1))
  while n=$(jobs -pr | wc -l) && [ $((n)) -ge "$JOBS" ]; do flush; sleep 0.2; done
  # stderr goes below the result, indented, so the first line is always its status
  ( s=$SECONDS; "$@" >"$WORK/r/$seq.part" 2>"$WORK/r/$seq.err" || true
    if [ -s "$WORK/r/$seq.err" ]; then sed 's/^/               stderr: /' "$WORK/r/$seq.err" >> "$WORK/r/$seq.part"; fi
    rm -f "$WORK/r/$seq.err"
    record $((SECONDS - s)) "$WORK/r/$seq.part" "$grp" "$chk" >> "$WORK/done"
    mv "$WORK/r/$seq.part" "$WORK/r/$seq" ) &
  flush
}
# The baseline runs alongside the controls, on its own copy: a control's verdict
# counts only if the baseline passes, and a failed baseline fails the run. In fast
# mode a second baseline runs every behavior test unmutated the way fast mode runs
# them (own process group and TMPDIR, stopped at a FAIL line): a test that failed
# only there would otherwise turn every T11 control into a kill.
plugin_fast_baseline() {  # ID COPY
  if copy_failed "$1" "$2"; then return 1; fi
  T11_ONLY=$BASE_T11
  if plugin_gate "$2" fast T11 ""; then
    printf "  control      %-28s unmodified copy passes T11 in fast mode\n" "$1"
  else
    printf "  CONTROL FAIL %-28s unmodified copy fails T11 in fast mode:\n" "$1"
    fails "$2.out"; return 1
  fi
}
# What the baselines run comes from the run's own controls (--list): the checks
# they are judged by, the plugins whose behavior tests their T11 controls run,
# and T13.0 and T14 when a control needs them (ADR-023). Full mode runs the whole
# gate. Before v0.4.18 every group's baseline ran the whole gate.
BASE_ONLY=""; BASE_T11=""; BASE_T13=0; BASE_T14=0; BASE_NOTE=""
if [ "$LIST" = 0 ] && { [ "$GROUP" != core ] || [ -n "$IDS" ]; }; then
  if ! bash "$0" --list > "$WORK/manifest" 2> "$WORK/manifest.err"; then
    echo "test-mutants: listing the controls failed: $(head -3 "$WORK/manifest.err" | tr '\n' ';')"; exit 2
  fi
  for id in $IDS; do
    awk -F'\t' -v id="$id" '$2 == id { f = 1 } END { exit !f }' "$WORK/manifest" \
      || { echo "test-mutants: unknown control id '$id' (group: $GROUP)" >&2; exit 2; }
  done
  [ -s "$WORK/manifest" ] || { echo "test-mutants: group '$GROUP' has no plugin controls to run" >&2; exit 2; }
  BASE_T13=$(awk -F'\t' '$7 == 1 { f = 1 } END { print f + 0 }' "$WORK/manifest")
  BASE_T14=$(awk -F'\t' '$8 == 1 { f = 1 } END { print f + 0 }' "$WORK/manifest")
  if [ "$MODE" = fast ]; then
    BASE_ONLY=$(awk -F'\t' '{ s = $3; sub(/\..*/, "", s); if (!(s in seen)) { seen[s] = 1; o = o (o == "" ? "" : " ") s } } END { print o }' "$WORK/manifest")
    BASE_T11=$(awk -F'\t' '$3 == "T11" { n++; if ($6 == "all") all = 1; else if ($6 != "none" && !($6 in seen)) { seen[$6] = 1; o = o (o == "" ? "" : " ") $6 } }
      END { print (n == 0 ? "none" : all ? "" : (o == "" ? "none" : o)) }' "$WORK/manifest")
    BASE_NOTE=" (fast mode: $BASE_ONLY; T11: ${BASE_T11:-all})"
  fi
fi
if [ "$LIST" = 0 ] && [ "$GROUP" != core ]; then
plugin_copy "$WORK/p-baseline" || true   # a failed copy is reported by the baseline
launch plugin_baseline P00-baseline "$WORK/p-baseline"
if [ "$MODE" = fast ] && awk -F'\t' '$3 == "T11" { f = 1 } END { exit !f }' "$WORK/manifest"; then
  plugin_copy "$WORK/p-fast-baseline" || true
  launch plugin_fast_baseline P00-fast-baseline "$WORK/p-fast-baseline"
fi
fi

# The cache's digests (ADR-025), once per run: one per plugin, over every file a
# T11 control of that plugin can read, the harness without the controls'
# declarations, and the bash and awk that run them.
if command -v shasum >/dev/null 2>&1; then SUMS="shasum -a 256"; else SUMS=sha256sum; fi
sha() { $SUMS | awk '{ print $1 }'; }
tree_sha() {  # PATH... (relative to the repository) — one hash over the files' paths and contents
  (cd "$REPO_ROOT" && find "$@" -type f ! -name .DS_Store 2>/dev/null | LC_ALL=C sort | tr '\n' '\0' | xargs -0 $SUMS 2>/dev/null || true) | sha
}
if [ -n "$CACHE" ] && [ "$LIST" = 0 ]; then
  mkdir -p "$WORK/digest"
  COMMON=$( { tree_sha make/test-plugins.sh .claude-plugin skills
    grep -vE '(^|[ =])(plugin_case|plugin_case_rm) P[0-9]' "$0" | sha
    printf '%s\n' "$BASH_VERSION" "$(uname -s)"; ls -lL "$(command -v awk)"; } | sha)
  for d in "$REPO_ROOT"/plugins/*/; do
    p=$(basename "$d")
    # ascent-governance's tests run every plugin's checkers and read this repository's contract
    case "$p" in ascent-governance) more="plugins .ascent" ;; *) more="plugins/$p" ;; esac
    # shellcheck disable=SC2086
    { echo "$COMMON"; tree_sha $more "tests/plugins/$p"; } | sha > "$WORK/digest/$p"
  done
fi
cache_key() {  # KIND ID LABEL PATH [SED [rebuild]] — the control's key, or nothing when it may not use the cache
  [ -n "$CACHE" ] && [ "$3" = T11 ] && [ -n "${T11_ONLY:-}" ] && [ -f "$WORK/digest/$T11_ONLY" ] \
    && [ "${T13_SELFTEST:-0}" = 0 ] && [ "${T14_SELFTEST:-0}" = 0 ] && [ -z "${MUTANT_FAULT:-}" ] && [ "${6:-}" != rebuild ] || return 0
  { echo "v1 $T11_ONLY"; cat "$WORK/digest/$T11_ONLY"; printf '%s\n' "$@"; } | sha
}

# control_run KIND ID LABEL PATH [SED [rebuild]] — one control on its own copy;
# KIND is edit (apply SED to PATH) or rm (delete PATH). Prints its result.
control_run() {
  local kind=$1 id=$2 label=$3 path=$4 copy="$WORK/p-$2" key out
  key=$(cache_key "$@")
  if [ -n "$key" ] && [ -f "$CACHE/$key" ]; then
    printf "  killed       %-28s by test-plugins %s (cached)\n" "$id" "$label"; return
  fi
  plugin_copy "$copy" || { copy_failed "$id" "$copy"; return; }
  if [ "$kind" = rm ]; then
    if [ ! -e "$copy/$path" ]; then printf "  ANCHOR MISS  %-28s %s not found\n" "$id" "$path"; rm -rf "$copy"; return; fi
    rm -rf "${copy:?}/$path"
  else
    cp "$copy/$path" "$copy.before"
    sed -i.mut-bak -e "$5" "$copy/$path" && rm -f "$copy/$path.mut-bak"
    if cmp -s "$copy.before" "$copy/$path"; then
      printf "  ANCHOR MISS  %-28s sed changed nothing in %s\n" "$id" "$path"; rm -rf "$copy" "$copy.before"; return
    fi
    if [ "${6:-}" = rebuild ] && ! bash "$copy/make/build-plugins.sh" >/dev/null 2>&1; then
      printf "  SURVIVED     %-28s rebuild failed before the gate ran\n" "$id"; rm -rf "$copy" "$copy.before"; return
    fi
  fi
  out=$(plugin_verdict "$id" "$label" "$copy" "$path")
  printf '%s\n' "$out"
  case "$out" in "  killed "*) [ -z "$key" ] || : > "$CACHE/$key" ;; esac   # only kills are kept
  rm -rf "$copy" "$copy.before" "$copy.out" "$copy.fast"
}
plugin_verdict() {  # ID EXPECT-LABEL COPY EDITED-PATH — run the gate and classify the result
  if [ "$MODE" = fast ]; then
    if ! plugin_gate "$3" fast "$2" "$4" && grep -q "^FAIL  test-plugins: $2 " "$3.out"; then
      printf "  killed       %-28s by test-plugins %s\n" "$1" "$2"; return
    fi
    mv "$3.out" "$3.fast"
  fi
  if plugin_gate "$3"; then
    printf "  SURVIVED     %-28s test-plugins still passes\n" "$1"
  elif grep -q "^FAIL  test-plugins: $2 " "$3.out"; then
    if [ "$MODE" = full ]; then printf "  killed       %-28s by test-plugins %s\n" "$1" "$2"; return; fi
    printf "  MODES DIFFER %-28s full mode killed it by %s, fast mode did not\n" "$1" "$2"
  else
    printf "  SURVIVED     %-28s failed, but not on %s: %s%s\n" "$1" "$2" \
      "$(grep '^FAIL' "$3.out" | sed 's/^FAIL  test-plugins: //' | cut -c1-60 | tr '\n' ';')" \
      "$(grep -q '^test-plugins: [0-9]*/[0-9]* PASS' "$3.out" || echo ' (the gate ended early, before its summary)')"
  fi
  if [ -f "$3.fast" ]; then
    echo "               fast mode (only $2):"; fails "$3.fast"
    [ -n "$(grep '^FAIL' "$3.fast" || true)" ] || echo "                 (no FAIL lines)"
  fi
  echo "               full mode:"; fails "$3.out"
  [ -n "$(grep '^FAIL' "$3.out" || true)" ] || echo "                 (no FAIL lines)"
}
plugin_case() {  # ID EXPECT-LABEL FILE(relative to repo) SED-EXPRESSION [rebuild]
  in_group && selected "$1" || return 0
  t11_scope "$3"
  listed edit "$1" "$2" "$3" || launch control_run edit "$@"
}
plugin_case_rm() {  # ID EXPECT-LABEL PATH(relative to repo) — the control deletes PATH
  in_group && selected "$1" || return 0
  t11_scope "$3"
  listed rm "$1" "$2" "$3" || launch control_run rm "$@"
}
mutant_group ascent-security
SEC=plugins/ascent-security
TPL=skills/lloydbriantech-ascent/assets/template/.claude/skills
AGENT="$SEC/agents/security-auditor.md"
plugin_case P01-hand-edited-skill T1 "$SEC/skills/env-audit/SKILL.md" '$a\
Hand edit that bypasses the template source.'
plugin_case P02-agent-can-write T4 "$AGENT" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P03-severity-drift T5 "$TPL/ascent-sec-posture/SKILL.md" 's/| No `.env.example` (no secrets inventory) | Low |/| No `.env.example` (no secrets inventory) | Medium |/' rebuild
plugin_case P04-version-mismatch T3 .claude-plugin/marketplace.json 's/"version": "\([0-9][0-9.]*\)"/"version": "\1-x"/'
plugin_case P05-agent-links-template T6 "$AGENT" '$a\
See [sec-posture](../skills/ascent-sec-posture/SKILL.md).'
plugin_case P06-source-not-rebuilt T1 "$TPL/ascent-env-audit/SKILL.md" 's/never echo the value/never print the value/'
plugin_case P07-agent-cites-missing-step T9 "$AGENT" 's/(security-audit Step 4)/(security-audit Step 9)/'
plugin_case P08-agent-extra-key T4 "$AGENT" 's/^model: inherit$/model: inherit\
permissionMode: bypassPermissions/'
plugin_case P09-skill-wide-tools T4b "$TPL/ascent-security-audit/SKILL.md" 's/^  - Glob$/  - Glob\
  - Bash/' rebuild
plugin_case P10-marketplace-bad-source T3 .claude-plugin/marketplace.json 's|"source": "./plugins/ascent-security"|"source": "./plugins/ascent-securty"|'
plugin_case P11-agent-cites-unknown-skill T9 "$AGENT" 's/(security-audit Step 5)/(secrets-audit Step 5)/'
plugin_case P12-agent-cites-nothing T9 "$AGENT" 's/Step/Stage/g'
plugin_case P13-severity-table-removed T5 "$TPL/ascent-sec-posture/SKILL.md" '/severity-table:start/d' rebuild
plugin_case P14-content-changed-no-bump T10 "$AGENT" '$a\
A line added without bumping the plugin version.'
mutant_group ascent-security-deps
SDEP=plugins/ascent-security/scripts
CDA="$SDEP/lib/check-dependencies.awk"
CDS="$SDEP/check-dependencies.sh"
plugin_case P241-deps-no-lockfile-ok T11 "$CDA" 's/else fail("D1", "Medium", f ":1", NDEP\[f\]/else if (0) fail("D1", "Medium", f ":1", NDEP[f]/'
plugin_case P242-deps-workspace-uncovered-ok T11 "$CDA" 's/if (!cov \&\& LOCKREQ == "yes") fail(/if (0) fail(/'
plugin_case P243-deps-untracked-lock-ok T11 "$CDA" 's/if (untracked(a\[i\])) { UNTR = a\[i\]; continue }/if (0) { UNTR = a[i]; continue }/'
plugin_case P244-deps-python-no-lock-ok T11 "$CDA" 's/if (LOCKREQ == "yes") fail("D1", "Medium", f ":1", (UNTR != "" ? "the lockfile " UNTR " is not tracked by git" : NPY/if (0) fail("D1", "Medium", f ":1", (UNTR != "" ? "the lockfile " UNTR " is not tracked by git" : NPY/'
plugin_case P245-deps-go-cargo-no-lock-ok T11 "$CDA" 's/if (locks == "" \&\& LOCKREQ == "yes") fail(/if (0) fail(/'
plugin_case P246-deps-pinned-reqs-not-lock T11 "$CDA" 's/if (PK == "py-req" \&\& RQALL)/if (0 \&\& RQALL)/'
plugin_case P247-deps-npm-ranges-ok T11 "$CDA" 's/(PINNING == "exact" ? !npm_exact(sp) : unbounded(sp))/(PINNING == "exact" ? 0 : unbounded(sp))/'
plugin_case P248-deps-open-range-bounded T11 "$CDA" 's/if (a\[i\] ~ \/>\/ \&\& a\[i\] !~ \/<\/) return 1/if (0) return 1/'
plugin_case P249-deps-pep-ranges-exact T11 "$CDA" 's/function pep_exact(sp) { return sp ~ \/^===? \*\[0-9A-Za-z.!+-\]+\$\/ }/function pep_exact(sp) { return 1 }/'
plugin_case P250-deps-npm-range-drift-ok T11 "$CDA" 's/else if (LDEP\[lk, rel, nm\] != sp) {/else if (0) {/'
plugin_case P251-deps-lock-extra-ok T11 "$CDA" 's/if (!((f, nm) in DEP)) {/if (0) {/'
plugin_case P252-deps-yarn-drift-ok T11 "$CDA" 's/if (!((lk, nm "@" sp) in YD)/if (0 \&\& !((lk, nm "@" sp) in YD)/'
plugin_case P253-deps-python-drift-ok T11 "$CDA" 's/if (!hit) { miss++;/if (0) { miss++;/'
plugin_case P254-deps-no-engine-ok T11 "$CDA" 's/if (!ENG\[f\] \&\& !engine_near("npm", d)) fail("D4"/if (0) fail("D4"/'
plugin_case P255-deps-engine-not-inherited T11 "$CDA" '/ENGDIR\["npm", dirof(f)\] = 1$/d'
plugin_case P256-deps-npmrc-registry-ok T11 "$CDA" 's/if (!allowed(u)) fail("D5", srcsev(u), FN ":" FNR, "the registry "/if (0) fail("D5", srcsev(u), FN ":" FNR, "the registry "/'
plugin_case P257-deps-lock-source-ok T11 "$CDA" 's/^  if (allowed(u)) return$/  return/'
plugin_case P258-deps-http-not-high T11 "$CDA" 's/? "High" : "Medium" }$/? "Medium" : "Medium" }/'
plugin_case P259-deps-url-unmasked T11 "$CDA" 's/if (match(auth, \/\.\*@\/)) auth = "\*\*\*@" substr(auth, RLENGTH + 1)/auth = auth/'
plugin_case P260-deps-trusted-host-ok T11 "$CDA" 's/chk("D5"); fail("D5", "Medium", FN ":" l0, "--trusted-host "/chk("D5"); 0 \&\& fail("D5", "Medium", FN ":" l0, "--trusted-host "/'
plugin_case P261-deps-go-replace-ok T11 "$CDA" 's/if (to !~ \/^(\\.|\\\/)\/ \&\& fa\[1\] != ta\[1\]) fail("D5"/if (0) fail("D5"/'
plugin_case P262-deps-cargo-git-ok T11 "$CDA" 's/{ chk("D5"); fail("D5", srcsev(g), FN ":" l, nm " comes from git/{ chk("D5"); 0 \&\& fail("D5", srcsev(g), FN ":" l, nm " comes from git/'
plugin_case P263-deps-licence-or-ignored T11 "$CDA" 's/r = lic_and(); if (r) ok = 1/r = lic_and(); if (!r) ok = 0/'
plugin_case P264-deps-licences-unchecked T11 "$CDA" 's/^  if (!HAVEDENY) return$/  return/'
plugin_case P265-deps-waiver-ignored T11 "$CDA" 's/if (toupper(id) in WAIVE) { info(/if (0) { info(/'
plugin_case P266-deps-expiry-ignored T11 "$CDA" 's/if (IGEXP\[i\] != "" \&\& days(IGEXP\[i\]) >= 0 \&\& days(IGEXP\[i\]) < days(TODAY))/if (0)/'
plugin_case P267-deps-prototype-rates-ignores T11 "$CDA" 's/if (MATURITY == "prototype") note("D10"/if (0) note("D10"/'
plugin_case P268-deps-nsprc-unread T11 "$CDA" 's/if (FN ~ \/(^|\\\/)\\.nsprc\$\/ \&\& n >= 1)/if (0)/'
plugin_case P269-json-array-index-stuck T11 "$SDEP/lib/json.awk" 's/if (JST\[JSP\] == "a") JIX\[JSP\]++; else JEK\[JSP\] = 1/if (JST[JSP] == "a") JIX[JSP] += 0; else JEK[JSP] = 1/'
plugin_case P270-deps-reads-tests T11 "$CDS" 's/ -o -name tests -o -name test -o -name __tests__/ -o -name __tests__/'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1588-next-sentence-missing-security T11 plugins/ascent-security/skills/threat-model/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
plugin_case P1592-next-sentence-twice T11 plugins/ascent-security/skills/dependency-check/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/p'
mutant_group ascent-security-scan
VSS="$SDEP/run-vuln-scan.sh"
NVA="$SDEP/lib/normalise-vulns.awk"
DCK=plugins/ascent-security/skills/dependency-check/SKILL.md
plugin_case P271-scan-online-trivy T11 "$VSS" 's/ --skip-java-db-update --offline-scan / --skip-java-db-update /'
plugin_case P272-scan-image-from-registry T11 "$VSS" 's/ --image-src docker,containerd,podman -- "\$i"/ -- "$i"/'
plugin_case P273-scan-network-unasked T11 "$VSS" 's/^  if \[ "\$NET" = 1 \]; then$/  if true; then/'
plugin_case P274-scan-dry-run-runs T11 "$VSS" 's/^  if \[ "\$DRY" = 1 \]; then$/  if false; then/'
plugin_case P275-scan-pip-audit-ranges T11 "$VSS" 's/SKIPPED="\$SKIPPED|\$r: not scanned by pip-audit: not every requirement is pinned with =="; continue/:/'
plugin_case P276-scan-threshold-ignored T11 "$NVA" 's/if (VS\[i\] > 0 \&\& VS\[i\] < TR || TR == 99)/if (TR == 99)/'
plugin_case P277-scan-no-fix-still-high T11 "$NVA" 's/sev = (fix ? "High" : "Medium")/sev = "High"/'
plugin_case P278-scan-unknown-severity-low T11 "$NVA" 's/if (VS\[i\] == 0) sev = "Medium"/if (VS[i] == 0) sev = "Low"/'
plugin_case P279-scan-duplicates-kept T11 "$NVA" 's/if ((key, a\[i\]) in SEEN) idx = SEEN\[key, a\[i\]\]/if (0) idx = SEEN[key, a[i]]/'
plugin_case P280-scan-waiver-ignored T11 "$NVA" 's/if (toupper(a\[j\]) in WAIVE) w = 1/if (0) w = 1/'
plugin_case P281-scan-stale-db-ok T11 "$NVA" 's/> MAXAGE + 0) r8/> 99999) r8/'
plugin_case P282-scan-unmeasured-ok T11 "$NVA" 's/if (NSRC == 0) r8 =/if (0) r8 =/'
plugin_case P283-scan-prototype-rates-db T11 "$NVA" 's/if (MATURITY == "prototype") note("D8", r8)/if (0) note("D8", r8)/'
plugin_case P284-scan-image-is-d7 T11 "$NVA" 's/ACHK = (IMAGE ? "D9" : "D7")/ACHK = "D7"/'
plugin_case P285-scan-no-cap T11 "$NVA" 's/if (++PERW\[VW\[i\]\] > 25)/if (++PERW[VW[i]] > 100000)/'
plugin_case P286-scan-line-lookup-lost T11 "$NVA" 's/{ nl = n; break }/{ nl = 0; break }/'
plugin_case P287-scan-lock-version-lost T11 "$NVA" 's/if (index(ln, "\\"node_modules\/" pkg "\\"")) on = 1/if (0) on = 1/'
plugin_case P288-scan-eosl-ignored T11 "$NVA" 's/if (jseg(p, 3) == "EOSL" \&\& v == "true")/if (jseg(p, 3) == "EOSL" \&\& v == "yes")/'
plugin_case P289-dep-table-drift T5 plugins/ascent-security/agents/security-auditor.md 's/^| A licence the contract denies (SEC-D6) | High |$/| A licence the contract denies (SEC-D6) | Medium |/'
plugin_case P290-agent-cites-missing-dep-step T9 plugins/ascent-security/agents/security-auditor.md 's/(SEC-D7–D9, dependency-check Step 3)/(SEC-D7–D9, dependency-check Step 7)/'
plugin_case P291-dep-skill-wide-tools T4b "$DCK" 's/^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$/allowed-tools: Read, Grep, Glob, Bash/'
plugin_case P292-dep-skill-version-drift T3 "$DCK" 's/^version: 0\.4\.0$/version: 0.3.9/'
plugin_case P293-dep-skill-changed-no-bump T10 "$DCK" '$a\
A line added without bumping the plugin version.'
plugin_case P294-scan-test-emptied T11 tests/plugins/ascent-security/test-run-vuln-scan.sh '1,$d'
plugin_case P295-dep-skill-unregistered T13.3 docs/framework/OWNERSHIP.md '/^| `ascent-security` | skill | `dependency-check` |$/d'
plugin_case P296-dep-family-definition-lost T13.4 docs/framework/OWNERSHIP.md 's#^| `SEC-D` | `ascent-security` | rule | `plugins/ascent-security/scripts/check-dependencies.sh` |$#| `SEC-D` | `ascent-security` | rule | `plugins/ascent-security/scripts/check-deps.sh` |#'
plugin_case P297-security-contract-extra-section T13.5 plugins/ascent-security/references/contract-template.yml '$a\
ops:\
  maturity_target: enterprise'
plugin_case P298-dep-header-unqualified T13.10 "$CDS" 's/^#   SEC-D1  Medium /#   D1  Medium /'
# One control per defect the v0.4.9 review found, in three groups so each macOS job
# stays well inside its timeout: registries, masking, licences and npm, pnpm and
# Python readers (-1); requirements, Go, Cargo, osv, lockfile sources and the tree walk (-2);
# the scan (-3).
mutant_group ascent-security-regressions-1
SDEP=plugins/ascent-security/scripts
CDA="$SDEP/lib/check-dependencies.awk"
CDS="$SDEP/check-dependencies.sh"
VSS="$SDEP/run-vuln-scan.sh"
NVA="$SDEP/lib/normalise-vulns.awk"
plugin_case P299-deps-registry-no-boundary T11 "$CDA" 's#index(u, r) == 1 \&\& (r ~#index(u, r) == 1 \&\& (1 || r ~#'
plugin_case P300-deps-public-needs-slash T11 "$CDA" 's@pythonhosted\\.org)(\[\\/?#\]|\$)/)@pythonhosted\\.org)\\//)@'
plugin_case P301-deps-registry-case-kept T11 "$CDA" 's/h = tolower(substr(u, 1, RLENGTH)); r = /h = substr(u, 1, RLENGTH); r = /'
plugin_case P302-deps-mask-first-at T11 "$CDA" 's/if (match(auth, \/\.\*@\/)) auth/if (match(auth, \/[^@]*@\/)) auth/'
plugin_case P303-deps-path-token-shown T11 "$CDA" 's/if (length(a\[i\]) >= 20 /if (0 \&\& length(a[i]) >= 20 /'
plugin_case P304-deps-d3-spec-unmasked T11 "$CDA" 's/nm ": manifest " safeurl(sp) ", lockfile " safeurl(LDEP\[lk, rel, nm\])/nm ": manifest " sp ", lockfile " LDEP[lk, rel, nm]/'
plugin_case P305-deps-licence-and-as-or T11 "$CDA" 's/r = lic_atom(); if (!r) ok = 0/r = lic_atom(); if (r) ok = 1/'
plugin_case P306-deps-licence-paren-open T11 "$CDA" 's/if (LTP <= LTN \&\& LT\[LTP\] == ")") LTP++; return ok/return ok/'
plugin_case P307-deps-root-licence-checked T11 "$CDA" 's/if (n == 3 \&\& s3 == "license" \&\& s2 != "")/if (n == 3 \&\& s3 == "license")/'
plugin_case P308-deps-v2-legacy-counted T11 "$CDA" 's/if (s1 == "dependencies" \&\& n == 3 \&\& LVER\[FN\] + 0 < 2 \&\& jseg(p, 3) == "resolved")/if (s1 == "dependencies" \&\& n == 3 \&\& jseg(p, 3) == "resolved")/'
plugin_case P309-deps-berry-header-quoted T11 "$CDA" 's/sub(\/^"\/, "", x); sub(\/"\$\/, "", x);/x = unq(x);/'
plugin_case P310-deps-pnpm-single-unread T11 "$CDA" 's/^  if (PIMP == "." \&\& PTOP != "specifiers") {$/  if (0) {/'
plugin_case P311-deps-pnpm-v5-specifier-lost T11 "$CDA" 's/if (PSECT == "specifiers") PSP\[FN, imp, PNAME\] = /if (0) PSP[FN, imp, PNAME] = /'
plugin_case P312-deps-setup-cfg-unread T11 "$CDA" 's/^K == "py-setup" \&\& FN ~ /K == "none" \&\& FN ~ /'
plugin_case P313-deps-setup-py-unread T11 "$CDA" 's/if (!match(s, \/install_requires/if (1 || !match(s, \/install_requires/'
plugin_case P314-deps-array-ends-at-extras T11 "$CDA" 's/^function arr_closes(v) { gsub(/function arr_closes(v) { return v ~ \/\\]\/; gsub(/'
plugin_case P315-deps-include-group-dep T11 "$CDA" 's/^function arr_feed(v, l) { gsub(\/\\{\[^}\]\*\\}\/, "", v); /function arr_feed(v, l) { /'
mutant_group ascent-security-regressions-2
plugin_case P316-deps-editable-self-flagged T11 "$CDA" 's/ next  # a local project/ RQALL = 0  # a local project/'
plugin_case P317-deps-editable-long-skipped T11 "$CDA" 's/if (match(s, \/^--editable\[ =\]+\/)) s =/if (0) s =/'
plugin_case P318-deps-find-links-ok T11 "$CDA" 's/py_source(FN, u, l0, "the find-links location")/0/'
plugin_case P319-deps-go-sum-above-ok T11 "$CDA" 's/locks = ((here \&\& /locks = ((0 \&\& /'
plugin_case P320-deps-go-same-module-flagged T11 "$CDA" 's/ \&\& fa\[1\] != ta\[1\]) fail("D5"/) fail("D5"/'
plugin_case P321-deps-cargo-patch-ok T11 "$CDA" 's/fail("D5", srcsev(g), FN ":" l, k " is patched from git/0 \&\& fail("D5", srcsev(g), FN ":" l, k " is patched from git/'
plugin_case P322-deps-cargo-lock-unread T11 "$CDA" 's/sub(\/^(registry|sparse)\\+\/, "", u); lock_source(FN, CLNAME, u, l) }/}/'
plugin_case P323-deps-osv-entries-merged T11 "$CDA" 's/{ if (K == "ignore-osv") osv_ignore_end(); SEC = trim(s)/{ SEC = trim(s)/'
plugin_case P324-deps-relative-path-not-local T11 "$CDA" 's/^function npm_local(s) { return s ~ \/^(file|link|workspace|portal|patch):\/ || /function npm_local(s) { return s ~ \/^(file|link|workspace|portal|patch):\/ || 0 \&\& /'
plugin_case P325-deps-alias-range-hidden T11 "$CDA" 's/^  sub(\/^npm:(@\[^\\\/\]+\\\/)?\[^@\]+@\/, "", s)$/  s = s/'
plugin_case P326-deps-root-pruned T11 "$CDS" 's/find "\$p" -mindepth 1 \$SKIP/find "$p" $SKIP/'
plugin_case P327-deps-trailing-slash-kept T11 "$CDS" 's/^  while \[ "\${p%\/}" != "\$p" \] \&\& \[ "\$p" != \/ \]; do p="\${p%\/}"; done$/  :/'
plugin_case P328-deps-git-global T11 "$CDS" 's/^    ingit "\$f" || continue$/    :/'
plugin_case P329-deps-newline-name-split T11 "$CDS" 's/ ! -name "\*\$NL\*" -print/ -print/'
plugin_case P330-deps-licence-cap-lost T11 "$CDA" 's/if (++NDL\[f\] <= 10) fail(/if (++NDL[f] <= 100) fail(/'
plugin_case P331-deps-npm-untracked-unnamed T11 "$CDA" 's/if (UNTR != "") fail("D1", "Medium", f ":1", "the lockfile " UNTR " is not tracked by git, so/if (0) fail("D1", "Medium", f ":1", "the lockfile " UNTR " is not tracked by git, so/'
plugin_case P332-deps-pnpm-tarball-ok T11 "$CDA" 's/if (match(line, \/tarball: \*\[^,}\]+\/))/if (0)/'
plugin_case P333-deps-req-direct-url-ok T11 "$CDA" 's/if (!allowed(u)) fail("D5", srcsev(u), FN ":" l0, nm " comes from a direct URL/if (0) fail("D5", srcsev(u), FN ":" l0, nm " comes from a direct URL/'
plugin_case P334-deps-cargo-table-git-ok T11 "$CDA" 's/if (k == "git") { nm = SEC;/if (0) { nm = SEC;/'
plugin_case P335-deps-go-replace-block-ok T11 "$CDA" 's/^  if (s ~ \/^replace\[ \\t\]\*\\(\$\/) { GOB = "replace"; next }$/  if (0) { GOB = "replace"; next }/'
plugin_case P336-deps-berry-npm-resolution T11 "$CDA" 's/if (u ~ \/^npm:\/ || u ~ \/^workspace:\/ || u ~ \/^(file|link|portal|patch):\/) next/if (0) next/'
mutant_group ascent-security-regressions-3
plugin_case P337-scan-repo-config-applies T11 "$VSS" 's/^  --config "\$WORK\/trivy.yaml" --ignorefile "\$WORK\/trivyignore")$/  )/'
plugin_case P338-scan-runs-in-repo T11 "$VSS" 's/(cd "\$WORK" \&\& "\$@")/("$@")/'
plugin_case P339-scan-image-option-ok T11 "$VSS" 's/case "\$2" in -\*) echo "run-vuln-scan: --image names/case "$2" in -NEVER) echo "run-vuln-scan: --image names/'
plugin_case P340-scan-image-no-separator T11 "$VSS" 's/--image-src docker,containerd,podman -- "\$i"/--image-src docker,containerd,podman "$i"/'
plugin_case P341-scan-bad-report-clean T11 "$NVA" 's/^  if (why != "") {$/  if (0) {/'
plugin_case P342-scan-npm-error-unnamed T11 "$NVA" 's/if (s1 == "error") FERR = 1;/;/'
plugin_case P343-scan-cut-short-ok T11 "$NVA" 's/if (JBAD || JSP > 0) why =/if (0) why =/'
plugin_case P344-scan-failure-only-note T11 "$NVA" 's/else emit("D8", "Low", "scan", BADS\[j\] ": that part of the scan is unmeasured")/else note("D8", BADS[j])/'
plugin_case P345-scan-skips-silent T11 "$NVA" 's/^  n = split(SKIPPED, a, "|"); for (j = 1; j <= n; j++) if (a\[j\] != "") note("D8", a\[j\])$/  n = 0/'
plugin_case P346-scan-dry-run-asks-osv T11 "$VSS" 's/^    elif \[ "\$DRY" = 1 \]; then  # the dry run/    elif false; then  # the dry run/'
plugin_case P347-scan-stderr-unmasked T11 "$VSS" 's/| cut -c1-160 | mask)/| cut -c1-160)/'
plugin_case P348-scan-fix-across-locks T11 "$NVA" 's/NFIXA\[ALOCK, s2\] = v/NFIXA[s2] = v/'
plugin_case P349-scan-dry-run-silent T11 "$VSS" 's/\[ -z "\$m" \] || echo "NOTE  \$m"/:/'
plugin_case P350-scan-from-at-split T11 "$VSS" 's/^  if \[ ! -f "\$f" \]; then case "\$f" in/  if true; then case "$f" in/'
plugin_case P351-scan-trailing-slash-kept T11 "$VSS" 's/^while \[ "\${ROOT%\/}" != "\$ROOT" \] \&\& \[ "\$ROOT" != \/ \]; do ROOT="\${ROOT%\/}"; done$/:/'
plugin_case P352-scan-root-pruned T11 "$VSS" 's/find "\$ROOT" -mindepth 1 \$PRUNE -prune -o -name package-lock.json/find "$ROOT" $PRUNE -prune -o -name package-lock.json/'
plugin_case P353-scan-age-boundary T11 "$NVA" 's/days(TODAY) - days(DBDATE) > MAXAGE + 0) r8/days(TODAY) - days(DBDATE) >= MAXAGE + 0) r8/'
plugin_case P354-scan-absolute-target-kept T11 "$NVA" 's/^function rel(p) { if (ROOTABS != "" /function rel(p) { return p; if (ROOTABS != "" /'
plugin_case P355-scan-osv-v1-syntax T11 "$VSS" 's/else scan network osv "" "osv-scanner" osv-scanner --format json -r "\$ROOTABS"; fi/else scan network osv "" "osv-scanner" osv-scanner scan source -r --format json "$ROOTABS"; fi/'
plugin_case P357-scan-no-target-passes T11 "$NVA" 's/if (k == "D7" \&\& NFS > 0 \&\& NTGT > 0) printf/if (k == "D7" \&\& NFS > 0) printf/'
plugin_case P356-scan-version-unprinted T11 "$NVA" 's/(TVER != "" ? " (trivy " TVER ")" : "")/""/'
# Live checks and the threat model (ADR-026): one control per rule and guard, in two
# groups: the live script and its rater (-live), the threat model, the skills and
# their registration (-threat).
mutant_group ascent-security-live
CLA="$SDEP/lib/check-live-results.awk"
CLS="$SDEP/check-live-results.sh"
RLC="$SDEP/run-live-checks.sh"
plugin_case P917-live-l1-missing-ignored T11 "$CLA" 's/fail("L1", sev, w, "missing " mh\[j\], "SEC-L1:" mh\[j\])/count("L1")/'
plugin_case P918-live-l1-referrer-medium T11 "$CLA" 's/sev = (mh\[j\] == "referrer-policy" || mh\[j\] == "permissions-policy") ? "Low" : "Medium"/sev = "Medium"/'
plugin_case P919-live-l2-echo-low T11 "$CLA" 's/fail("L2", "Medium", w/fail("L2", "Low", w/'
plugin_case P920-live-l2-trace-ok T11 "$CLA" 's/else if (is2xx(s)) fail("L2", "Low"/else if (0) fail("L2", "Low"/'
plugin_case P921-live-l3-leak-ignored T11 "$CLA" 's#if (d ~ /leak=1/) fail#if (0) fail#'
plugin_case P922-live-l4-write-ok T11 "$CLA" 's/if (is2xx(s)) fail("L4"/if (0) fail("L4"/'
plugin_case P923-live-l5-5xx-ok T11 "$CLA" 's#if (is2xx(s) || s ~ /^5/ || s == "000") fail("L5"#if (is2xx(s)) fail("L5"#'
plugin_case P924-live-l6-secret-ignored T11 "$CLA" 's#if (d ~ /secret|git|env/ \&\& is2xx(s)) {#if (0) {#'
plugin_case P925-live-l6-trace-ignored T11 "$CLA" 's#if (d ~ /trace/) fail("L6"#if (0) fail("L6"#'
plugin_case P926-live-l6-banner-ignored T11 "$CLA" 's#else if (part\[i\] ~ /^banner=/) fail#else if (0) fail#'
plugin_case P927-live-l7-canary-ignored T11 "$CLA" 's#if (d ~ /canary=1/) fail#if (0) fail#'
plugin_case P928-live-l8-unlimited-ok T11 "$CLA" 's/else if (lim == 0 \&\& gate < tot) fail/else if (0) fail/'
plugin_case P929-live-l8-5xx-ok T11 "$CLA" 's/if (err > 0) fail("L8"/if (0) fail("L8"/'
plugin_case P930-live-l9-threshold-ignored T11 "$CLA" 's/if (RANK\[sev\] < RANK\[THR\]) { BELOW\[sc\]++; return }/if (0) return/'
plugin_case P931-live-l9-critical-low T11 "$CLA" 's/rated = (sev == "Critical") ? "High" : sev/rated = (sev == "Critical") ? "Low" : sev/'
plugin_case P932-live-zap-info-rated T11 "$CLA" 's/if (r == 0) continue/if (r < 0) continue/'
plugin_case P933-live-dalfox-verified-medium T11 "$CLA" 's/sev = (t == "V") ? "High"/sev = (t == "V") ? "Medium"/'
plugin_case P934-live-dalfox-info-rated T11 "$CLA" 's/if (t == "" || t == "I") {/if (t == "") {/'
plugin_case P935-live-nuclei-info-rated T11 "$CLA" 's/(s == "info") ? "" : "Medium"/(s == "info") ? "Low" : "Medium"/'
plugin_case P936-live-waiver-ignored T11 "$CLA" 's/if (id != "" \&\& waived(id))/if (0)/'
plugin_case P937-live-prototype-rated T11 "$CLA" 's/if (MAT == "prototype") { NOTES/if (0) { NOTES/'
plugin_case P938-live-l10-absent-ok T11 "$CLA" 's/if (NRES == 0 \&\& !BADRES) {/if (0) {/'
plugin_case P939-live-l10-stale-ok T11 "$CLA" 's/if (age > MAXAGE) fail("L10"/if (0) fail("L10"/'
plugin_case P940-live-l10-future-ok T11 "$CLA" 's/else if (age < 0) fail("L10"/else if (0) fail("L10"/'
plugin_case P941-live-l10-url-ignored T11 "$CLA" 's/if (H\["url"\] != URL) fail/if (0) fail/'
plugin_case P942-live-l10-target-ignored T11 "$CLA" 's/if (H\["target"\] != TGT) fail/if (0) fail/'
plugin_case P943-live-l10-writes-skipped-ok T11 "$CLA" 's/if (HASW \&\& ("unauth-write" in SKIP))/if (0)/'
plugin_case P944-live-l10-ai-skipped-ok T11 "$CLA" 's/if (HASAI \&\& ("canary" in SKIP))/if (0)/'
plugin_case P945-live-l10-any-first-line T11 "$CLA" 's/\$0 != "# ascent-live-results 1" { BADRES = 1 }/0 { BADRES = 1 }/'
plugin_case P946-live-credentials-shown T11 "$CLA" 's#; gsub(/:#; if (0) gsub(/:#'
plugin_case P947-live-exit-zero T11 "$CLA" 's/exit (NFAIL > 0 ? 1 : 0)/exit 0/'
plugin_case P948-live-oldest-results T11 "$CLS" 's/| LC_ALL=C sort | tail -n 1/| LC_ALL=C sort | head -n 1/'
plugin_case P949-live-writes-unknown T11 "$CLS" 's/\[ "\$3" = required \] \&\& HASW=1/HASW=0/'
plugin_case P1000-live-open-writes-unmeasured-ok T11 "$CLA" 's/else if (HASANYW \&\& ("oversize" in SKIP)/else if (0 \&\& ("oversize" in SKIP)/'
plugin_case P950-run-claude-any-host T11 "$RLC" 's/^if \[ -n "\${CLAUDECODE:-}" \] \&\& \[ "\$LOOP" = 0 \]; then$/if false; then/'
plugin_case P951-run-any-host T11 "$RLC" 's/\[ "\$ok" = 1 \] || bad "refused/true || bad "refused/'
plugin_case P952-run-prod-allowed T11 "$RLC" 's/\[ "\$PROD" = 0 \] || \[ "\$ALLOWPROD" = 1 \] || bad/true || bad/'
plugin_case P953-run-credentials-in-url T11 "$RLC" 's/case "\$auth" in \*@\*) bad/case "$auth" in *@nothing*) bad/'
plugin_case P954-run-writes-ungated T11 "$RLC" 's/^if \[ "\$WRITES" = 1 \]; then$/if true; then/'
plugin_case P955-run-ai-ungated T11 "$RLC" 's/^if \[ "\$AI" = 1 \] \&\& \[ -s "\$WORK\/ailist" \]; then$/if [ -s "$WORK\/ailist" ]; then/'
plugin_case P956-run-dry-run-sends T11 "$RLC" 's/^  if \[ "\$DRY" = 1 \]; then printf /  if false; then printf /'
plugin_case P957-run-path-normalised T11 "$RLC" 's/ --path-as-is / /'
plugin_case P958-run-trace-echo-missed T11 "$RLC" 's/\&\& d="echo=1"/\&\& d=-/'
plugin_case P959-run-leak-missed T11 "$RLC" 's/\&\& d="leak=1"/\&\& d=-/'
plugin_case P960-run-canary-missed T11 "$RLC" 's/\&\& d="canary=1"/\&\& d=-/'
plugin_case P961-run-secret-missed T11 "$RLC" 's/\&\& m="\${m}secret,"/\&\& m="$m"/'
plugin_case P962-run-git-missed T11 "$RLC" 's/\&\& m="\${m}git,"/\&\& m="$m"/'
plugin_case P963-run-env-missed T11 "$RLC" 's/-ge 2 \] \&\& m="\${m}env,"/-ge 99 ] \&\& m="${m}env,"/'
plugin_case P964-run-trace-missed T11 "$RLC" 's/\&\& m="\${m}trace,"/\&\& m="$m"/'
plugin_case P965-run-csp-missed T11 "$RLC" 's/\[ -n "\$csp" \] || miss=/true || miss=/'
plugin_case P966-run-banner-missed T11 "$RLC" 's/then ban=\$(/then ban=; : $(/'
plugin_case P967-run-burst-short T11 "$RLC" 's/for i in 1 2 3 4 5 6 7 8 9 10; do req burst/for i in 1; do req burst/'
plugin_case P968-run-oversize-small T11 "$RLC" 's/head -c \$((MAXBODY + 102400))/head -c 10/'
plugin_case P969-run-body-in-results T11 "$RLC" 's/^  cat "\$ROWS"$/  cat "$ROWS"; cat "$WORK\/body"/'
plugin_case P970-run-sends-credential T11 "$RLC" 's/ --max-filesize 2000000 / --max-filesize 2000000 -H "Authorization: Bearer x" /'
mutant_group ascent-security-threat
CTA="$SDEP/lib/check-threat-model.awk"
CTS="$SDEP/check-threat-model.sh"
STK=plugins/ascent-security/skills/security-test/SKILL.md
TMK=plugins/ascent-security/skills/threat-model/SKILL.md
plugin_case P971-tm-absent-ok T11 "$CTA" 's/if (!SEEN) fail("T1"/if (0) fail("T1"/'
plugin_case P972-tm-method-any T11 "$CTA" 's/else if (toupper(FIELD\["method"\]) != "STRIDE") fail/else if (0) fail/'
plugin_case P973-tm-no-entry-points-ok T11 "$CTA" 's/if (!EPSEC) fail/if (0) fail/'
plugin_case P974-tm-no-threats-ok T11 "$CTA" 's/if (!THSEC) fail("T1"/if (0) fail("T1"/'
plugin_case P975-tm-short-row-ok T11 "$CTA" 's/for (i = 1; i <= NBAD; i++) fail/for (i = 1; i <= 0; i++) fail/'
plugin_case P976-tm-endpoint-unmatched-ok T11 "$CTA" 's/if (!(norm(EPP\[i\]) in EPATH)) fail/if (0) fail/'
plugin_case P977-tm-paths-not-normalised T11 "$CTA" 's/function norm(p) { gsub/function norm(p) { return p; gsub/'
plugin_case P978-tm-entry-point-unthreatened-ok T11 "$CTA" 's/if (!(EID\[i\] in HIT) \&\& !HIT\["all"\] \&\& !HIT\["\*"\]) fail/if (0) fail/'
plugin_case P979-tm-unknown-entry-point-ok T11 "$CTA" 's/if (!(te\[k\] in ISEP) \&\& te\[k\] != "all"/if (0 \&\& te[k] != "all"/'
plugin_case P980-tm-stride-any T11 "$CTA" 's#if (s !~ /^\[STRIDE\]$/) fail#if (0) fail#'
plugin_case P981-tm-open-low T11 "$CTA" 's/if (st == "open") fail("T3", "Medium"/if (0) fail("T3", "Medium"/'
plugin_case P982-tm-mitigation-unchecked T11 "$CTA" 's/if (!ok) fail("T3"/if (0) fail("T3"/'
plugin_case P983-tm-adr-missing-ok T11 "$CTA" 's/if (!(a in ADRS)) fail/if (0) fail/'
plugin_case P984-tm-accepted-no-adr-ok T11 "$CTA" 's/else fail("T3", "Low", TL\[j\], TID\[j\] " is accepted with no ADR/else if (0) fail("T3", "Low", TL[j], TID[j] " is accepted with no ADR/'
plugin_case P985-tm-review-date-any T11 "$CTA" 's#if (d !~ /^\[0-9\]\[0-9\]\[0-9\]\[0-9\]-\[0-9\]\[0-9\]-\[0-9\]\[0-9\]$/) fail("T4"#if (d !~ /./) fail("T4"#'
plugin_case P986-tm-stale-review-ok T11 "$CTA" 's/if (age > MAXAGE) fail("T4"/if (0) fail("T4"/'
plugin_case P987-tm-claude-reviewer-ok T11 "$CTA" 's/|<\.\*>|claude|Claude)/|<.*>)/'
plugin_case P988-tm-prototype-rated T11 "$CTA" 's/if (MAT == "prototype") { NOTES/if (0) { NOTES/'
plugin_case P989-tm-stride-note-lost T11 "$CTA" 's/if (miss != "") NOTES/if (0) NOTES/'
plugin_case P990-tm-exit-zero T11 "$CTA" 's/exit (NFAIL > 0 ? 1 : 0)/exit 0/'
plugin_case P991-tm-outside-paths-found T11 "$CTS" 's/case "\$p" in \/\*|\*\.\.\*) continue ;; esac/:/'
plugin_case P992-live-table-drift T5 "$AGENT" 's/^| An open threat (SEC-T3) | Medium |$/| An open threat (SEC-T3) | Low |/'
plugin_case P993-agent-cites-missing-live-step T9 "$AGENT" 's/(security-test Step 4)/(security-test Step 8)/'
plugin_case P994-live-skill-wide-tools T4b "$STK" 's/^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$/allowed-tools: Read, Grep, Glob, Bash/'
plugin_case P995-threat-skill-version-drift T3 "$TMK" 's/^version: 0\.4\.0$/version: 0.3.9/'
plugin_case P996-threat-skill-unregistered T13.3 docs/framework/OWNERSHIP.md '/^| `ascent-security` | skill | `threat-model` |$/d'
plugin_case P997-live-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `SEC-L` | /d'
plugin_case P998-live-skill-runs-scanners T11 "$STK" 's/Claude never runs `run-live-checks.sh`, ZAP, nuclei or dalfox against a target/Claude runs the checks/'
plugin_case P999-live-image-unpinned T11 "$STK" 's/zap-stable:2\.17\.0 zap-baseline/zap-stable:latest zap-baseline/'
mutant_group ascent-security-env
CEV=plugins/ascent-security/scripts/check-env.sh
plugin_case P1296-env-e1-tracked-ok T11 "$CEV" 's/n=\$((n + 1)); fail SEC-E1 High "\$f"/: SEC-E1 High "$f"/'
plugin_case P1297-env-e1-root-only T11 "$CEV" 's/  done < <(git ls-files -z -- \. 2>\/dev\/null)/  done < <(git ls-files -z -- .env 2>\/dev\/null)/'
plugin_case P1298-env-e1-staged-missed T11 "$CEV" 's/  done < <(git ls-files -z -- \. 2>\/dev\/null)/  done < <(git ls-tree -r -z --name-only HEAD -- . 2>\/dev\/null)/'
plugin_case P1299-env-e1-not-high T11 "$CEV" 's/fail SEC-E1 High "\$f"/fail SEC-E1 Medium "$f"/'
plugin_case P1300-env-example-flagged T11 "$CEV" 's/^  case "\$b" in \*\.example|\*\.sample|.*) return 1 ;; esac$/  :/'
plugin_case P1301-env-any-dotenv-prefix T11 "$CEV" 's/^  case "\$b" in \.env|\.env\.\*) ;; \*) return 1 ;; esac$/  case "$b" in .env*) ;; *) return 1 ;; esac/'
plugin_case P1302-env-e2-unignored-ok T11 "$CEV" 's/^    git check-ignore -q -- "\$f" 2>\/dev\/null \&\& continue$/    continue/'
plugin_case P1303-env-e2-root-only T11 "$CEV" "s/| sed 's|^\\\\.\\/||' | sort > \"\\\$T\\/envs\"/| sed 's|^\\\\.\\/||' | awk '!\\/\\\\\\/\\/' | sort > \"\$T\\/envs\"/"
plugin_case P1304-env-e2-dependency-folders-searched T11 "$CEV" 's/^find \. \\( -name \.git -o -name node_modules -o /find . \\( -name .git -o /'
plugin_case P1305-env-e2-tracked-reported-twice T11 "$CEV" 's/^    \[ -n "\$(git ls-files -- "\$f" 2>\/dev\/null)" \] \&\& continue  /    :  /'
plugin_case P1306-env-e2-not-high T11 "$CEV" 's/fail SEC-E2 High "\$f"/fail SEC-E2 Low "$f"/'
plugin_case P1307-env-e3-not-excluded-ok T11 "$CEV" 's/^  excludes_env "\$f" \&\& continue$/  continue/'
plugin_case P1308-env-e3-reinclude-ignored T11 "$CEV" 's/^    neg=0; case "\$line" in '"'"'!'"'"'\*) neg=1; line="\${line#!}" ;; esac$/    neg=0; case "$line" in '"'"'!'"'"'*) continue ;; esac/'
plugin_case P1309-env-e3-anchored-patterns-missed T11 "$CEV" 's/^    pat="\${line#\/}"; pat="\${pat#\\\*\\\*\/}"; /    pat="$line"; /'
plugin_case P1310-env-e3-padding-kept T11 "$CEV" '/^    line="\${line#"\${line%%\[!\[:space:\]\]\*}"}"; /d'
plugin_case P1311-env-e3-nested-dockerignore-missed T11 "$CEV" 's/^  case "\${f##\*\/}" in \*\.dockerignore) ;; \*) continue ;; esac/  case "$f" in *\/*) continue ;; *.dockerignore) ;; *) continue ;; esac/'
plugin_case P1312-env-e3-dockerfile-alone-ok T11 "$CEV" 's/^  if \[ -n "\$first" \]; then n=\$((n + 1)); fail SEC-E3 Medium/  if false; then n=$((n + 1)); fail SEC-E3 Medium/'
plugin_case P1313-env-e3-not-medium T11 "$CEV" 's/fail SEC-E3 Medium "\$f"/fail SEC-E3 High "$f"/'
plugin_case P1314-env-no-git-still-reads-git T11 "$CEV" 's/^if \[ "\$NOGIT" -eq 1 \]; then WHY="--no-git"$/if false; then WHY="--no-git"/'
plugin_case P1315-env-outside-repo-passes T11 "$CEV" 's/^elif ! git rev-parse --is-inside-work-tree >\/dev\/null 2>\&1; then WHY=/elif false; then WHY=/'
plugin_case P1316-env-failures-exit-0 T11 "$CEV" 's/^\[ "\$NFAIL" -eq 0 \]$/true/'
plugin_case P1317-env-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `SEC-E` | /d'
plugin_case P1613-env-e3-one-line-hint-dropped T11 "$CEV" 's/NF > 1 { for (i = 1; i <= NF; i++)/NF > 99 { for (i = 1; i <= NF; i++)/'
plugin_case P1666-env-path-read-by-line T11 "$CEV" 's/git ls-files -z -- \. 2/git ls-files -- . 2/'
plugin_case P1667-env-named-ignore-not-read T11 "$CEV" 's/in \*\.dockerignore) ;; \*) continue ;; esac/in .dockerignore) ;; *) continue ;; esac/'

mutant_group ascent-delivery
DEL=plugins/ascent-delivery
HOOK="$DEL/hooks/operator-boundary.sh"
VERIFIER="$DEL/agents/finding-verifier.md"
plugin_case P15-hook-allows-git-push T11 "$HOOK" 's/GIT_READ = " status /GIT_READ = " push status /'
plugin_case P16-hook-ignores-contract T11 "$HOOK" 's/cur = (key == "deploy_beta" || key == "deploy_prod") ? /cur = (0) ? /'
plugin_case P17-hook-test-emptied T11 tests/plugins/ascent-delivery/test-operator-boundary.sh '1,$d'
plugin_case_rm P18-hook-tests-removed T11 tests/plugins/ascent-delivery
plugin_case P19-verifier-can-write T4 "$VERIFIER" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P20-skill-links-missing-ref T6 "$DEL/skills/delivery-loop/SKILL.md" 's|(references/review-lenses.md)|(references/review-lens.md)|'
plugin_case P21-hooks-json-missing-script T11 "$DEL/hooks/hooks.json" 's|hooks/operator-boundary.sh|hooks/operator-guard.sh|'
plugin_case P22-verifier-cites-missing-step T9 "$VERIFIER" 's/(delivery-loop Step 4)/(delivery-loop Step 9)/'
plugin_case P23-hook-skips-substitutions T11 "$HOOK" 's/for (k = 1; k <= NSUB; k++) enqueue(SUBS\[k\])/k = 0/'
plugin_case P24-hook-skips-git-global-opts T11 "$HOOK" 's/if (has(" -C -c --git-dir --work-tree --namespace --super-prefix --config-env --attr-source ", SW\[j\])) j += 2; else j++/j++/'
plugin_case P25-hook-heredoc-in-substitution T11 "$HOOK" 's/if (!arith \&\& c == "<" \&\& A\[i + 1\] == "<") {/if (0) {/'
plugin_case P26-hook-no-size-guard T11 "$HOOK" 's/if (nb > MAXB) {/if (0) {/'
plugin_case P27-hook-ignores-stdin-shells T11 "$HOOK" 's/if (j > SN) { STDIN_SHELL = 1; return 0 }/if (j > SN) return 0/'
plugin_case P28-hook-skips-unquoted-heredocs T11 "$HOOK" 's/if (!HQ\[k\]) scan_subs(b, HDBEND, 0)/if (0) scan_subs(b, HDBEND, 0)/'
plugin_case P29-contract-denies-whole-chain T11 "$HOOK" 's/if (SN > 0 \&\& !inpipe) { dn = SN;/if (SN > 0 \&\& !inpipe \&\& dn == 0) { dn = SN;/'
plugin_case P203-runbook-stacked-pr-rule-dropped T11 "$DEL/skills/delivery-loop/references/runbook-template.md" '/^- \*\*Stacked pull requests\.\*\*/,/Flag the force push as destructive/d'
plugin_case P204-hook-exemption-unstated T11 "$HOOK" '/^# Exempt from ascent-ops OPS-Z2 and OPS-Z3 on purpose/d'
# ascent-delivery 0.2.0 (ADR-024): the union of contracts, the acceptance check, and the
# skill and runbook rules (test-operator-boundary, test-check-acceptance, test-delivery-rules D4-D8).
plugin_case P881-hook-ignores-project-contract T11 "$HOOK" '/find_up(".ascent\/contract.yml")/d'
plugin_case P882-hook-ignores-claude-contract T11 "$HOOK" '/find_up(".claude\/contract.yml")/d'
plugin_case P883-hook-drops-legacy-contract T11 "$HOOK" '/find_up(".delivery-loop.yml")/d'
plugin_case P884-hook-reads-every-section T11 "$HOOK" 's/insec = (key == sec); cur = ""; continue/insec = 1; cur = ""; continue/'
plugin_case P885-hook-section-never-ends T11 "$HOOK" 's/insec = (key == sec); cur = ""; continue/insec = insec || (key == sec); cur = ""; continue/'
plugin_case P886-hook-message-names-no-file T11 "$HOOK" 's/ " in " label : ""/ : ""/'
ACC="$DEL/scripts/check-acceptance.sh"
plugin_case P887-accept-evidence-unchecked T11 "$ACC" 's/^    else if (bad != "") fail("A1"/    else if (0) fail("A1"/'
plugin_case P888-accept-line-unchecked T11 "$ACC" 's/if (n < b) { WHY = /if (0) { WHY = /'
plugin_case P889-accept-absolute-path T11 "$ACC" 's# || p ~ /^\\// || # || #'
plugin_case P890-accept-climb-allowed T11 "$ACC" 's# || p ~ /(^|\\/)\\\.\\\.(\\/|[$])/##'
plugin_case P891-accept-claude-signs T11 "$ACC" 's/(claude|assistant|copilot|chatgpt|gemini|llm|bot)/(nobody)/'
plugin_case P892-accept-name-unchecked T11 "$ACC" 's/^    if (placeholder(lw)) fail("A2"/    if (0) fail("A2"/'
plugin_case P893-accept-date-unchecked T11 "$ACC" 's/^    else if (!real_date(when)) fail("A2"/    else if (0) fail("A2"/'
plugin_case P894-accept-future-date T11 "$ACC" 's/^    else if (when > TODAY) fail("A2"/    else if (0) fail("A2"/'
plugin_case P895-accept-every-year-leap T11 "$ACC" 's/(y % 4 == 0 \&\& (y % 100 != 0 || y % 400 == 0)) ? 29 : 28/29/'
plugin_case P896-accept-acceptor-unchecked T11 "$ACC" 's/if (!(norm(who) in ACC)) fail("A3"/if (0) fail("A3"/'
plugin_case P897-accept-acceptor-exact T11 "$ACC" 's/ACC\[norm(al\[i\])\] = 1/ACC[al[i]] = 1/'
plugin_case P898-accept-draft-checks-signature T11 "$ACC" '/^    if (DRAFT) continue$/d'
plugin_case P899-accept-no-criteria-passes T11 "$ACC" 's/^  if (nrow == 0) {/  if (0) {/'
plugin_case P900-accept-escaped-bar-splits T11 "$ACC" 's#gsub(/\\\\\\|/, "\\001", line); ##'
plugin_case P901-acceptance-template-columns T11 "$DEL/skills/delivery-loop/references/acceptance-template.md" 's/| Accepted by | Accepted on |$/| Signed by | Accepted on |/'
plugin_case P902-skill-claude-may-sign T11 "$DEL/skills/delivery-loop/SKILL.md" 's/Claude never fills either column, even when asked: say who must, and why\./Claude may fill them in when the operator says who accepted./'
plugin_case P903-skill-done-skips-evidence T11 "$DEL/skills/delivery-loop/SKILL.md" 's/check-acceptance.sh" --draft --root \./check-acceptance.sh" --root ./'
plugin_case P904-runbook-prod-check-dropped T11 "$DEL/skills/delivery-loop/references/runbook-template.md" '/^### P1\. \[C\] The acceptance record passes$/d'
plugin_case P905-runbook-step-unlabelled T11 "$DEL/skills/delivery-loop/references/runbook-template.md" 's/^### 2\. \[O\] Commit and push$/### 2. Commit and push/'
plugin_case P906-skill-legacy-contract-unread T11 "$DEL/skills/delivery-loop/SKILL.md" 's/keeps working: read it when there is no `delivery:` section\./is no longer read./'
plugin_case P907-contract-template-extra-section T11 "$DEL/references/contract-template.yml" '$a\
ops:\
  maturity_target: enterprise'
# The gate must report a behavior test that fails with more output than a pipe holds.
# T11 once quoted the first FAIL lines through grep | head under set -e and pipefail,
# and SIGPIPE ended the gate before T11 printed (seen as P246, P255, P265 surviving).
plugin_case P358-t11-long-failure-output T11 tests/plugins/ascent-delivery/test-delivery-rules.sh '1a\
for i in $(seq 1 3000); do echo "FAIL  line $i: padding so a failing behavior test prints more than a pipe holds"; done; exit 1'
# launch evidence before prod (ADR-028)
DLOOP=plugins/ascent-delivery/skills/delivery-loop/SKILL.md
plugin_case P1600-launch-evidence-without-a-governance-section T11 "$DLOOP" 's/^- \*\*Launch evidence\.\*\* When the contract has a `governance` section, the prod runbook/- **Launch evidence.** The prod runbook/'
plugin_case P1601-launch-evidence-never-stops-prod T11 "$DLOOP" 's/labelled C; its \*\*Stop if\*\* is `NO-GO`, or any exit other than 0 (the script exits 2, with no verdict, when it cannot read what it was given)\./labelled C./'
plugin_case P1602-launch-evidence-missing-plugin-blocks T11 "$DLOOP" 's/When `ascent-governance` isn.t available, say so and skip it/When `ascent-governance` is missing, stop/'
plugin_case P1603-launch-evidence-not-a-stop-condition T11 "$DLOOP" '/^- the launch evidence check prints `NO-GO`, or exits with anything but 0 (Step 7);$/d'
plugin_case P1663-launch-evidence-exit-2-not-a-stop T11 "$DLOOP" 's/is `NO-GO`, or any exit other than 0 (the script exits 2, with no verdict, when it cannot read what it was given)\./is `NO-GO`./'
plugin_case P1604-launch-evidence-for-beta T11 "$DLOOP" 's/`check-audit\.sh --env prod \.` (with/`check-audit.sh --env beta .` (with/'
plugin_case P1605-launch-evidence-script-path-wrong T11 "$DLOOP" 's|`\$PLUGIN_ROOT/\.\./ascent-governance/scripts/check-audit\.sh`|`$PLUGIN_ROOT/../ascent-audit/scripts/check-audit.sh`|'
mutant_group ascent-architecture
ARC=plugins/ascent-architecture
ARC_AGENT="$ARC/agents/architecture-reviewer.md"
EST="$ARC/scripts/estimate-cost.sh"
CFN="$ARC/scripts/check-cfn-static-site.sh"
BPT="$ARC/blueprints/static-site-serverless-aws"
plugin_case P30-arch-agent-can-write T4 "$ARC_AGENT" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Edit/'
plugin_case P31-arch-agent-cites-missing-step T9 "$ARC_AGENT" 's/(architecture-review Step 4)/(architecture-review Step 9)/'
plugin_case P32-estimate-ignores-free-tier T11 "$EST" 's/^      f = fr\[k\] + 0$/      f = 0/'
plugin_case P33-estimate-drops-unknown-key T11 "$EST" 's/if (!(k in per)) fail("unknown usage key/if (!(k in per)) next; if (0) fail("unknown usage key/'
plugin_case P34-estimate-no-stale-warning T11 "$EST" 's/if (age > 90) printf/if (age > 900) printf/'
plugin_case P35-cfn-allows-http T11 "$CFN" 's/allow-all") || !has(r, "ViewerProtocolPolicy:")) f3/never-matches") || !has(r, "ViewerProtocolPolicy:")) f3/'
plugin_case P36-cfn-reads-comments T11 "$CFN" 's/^  if (line ~ \/\^ \*#\/) line = ""$//;s/^  sub(\/ +#\.\*\$\/, "", line)$//'
plugin_case P37-cfn-pitr-not-required T11 "$CFN" 's/if (ty == "AWS::DynamoDB::Table" \&\& !has(r, "PointInTimeRecoveryEnabled/if (0 \&\& !has(r, "PointInTimeRecoveryEnabled/'
plugin_case P38-blueprint-public-bucket T11 "$BPT/template.yaml" 's/RestrictPublicBuckets: true/RestrictPublicBuckets: false/'
plugin_case P39-blueprint-data-not-retained T11 "$BPT/template.yaml" '/^    DeletionPolicy: Retain$/d'
plugin_case P40-blueprint-readme-cost-drift T11 "$BPT/README.md" 's/\*\*0\.86 USD\*\*/**0.80 USD**/'
plugin_case P41-pricing-changed-no-bump T10 "$ARC/pricing/aws-us-east-1.tsv" 's/^\(lambda_requests.\{1,20\}\)0\.20/\10.25/'
plugin_case_rm P42-arch-tests-removed T11 tests/plugins/ascent-architecture
plugin_case P43-arch-skill-links-missing-ref T6 "$ARC/skills/architecture-review/SKILL.md" 's|(../../references/architecture-principles.md)|(../../references/architecture-principle.md)|'
plugin_case P44-cfn-severity-drift T11 "$CFN" 's/^#   ARC-C8  High /#   ARC-C8  Medium /'
plugin_case P45-estimate-ignores-pools T11 "$EST" 's/if (pool\[k\] != "") { if (f > left\[pool\[k\]\]) f = left\[pool\[k\]\] }/if (0) f = 0/'
plugin_case P46-estimate-ignores-plan-needs T11 "$EST" 's/if (pr\[col\[nl\[j\]\]\] != "yes") fits = 0/if (0) fits = 0/'
plugin_case P47-cfn-one-oac-hides-another T11 "$CFN" 's/nbad = s3_without_oac(r)/nbad = ncfg - noac/'
plugin_case P48-cfn-skips-flow-resources T11 "$CFN" 's/if (line !~ \/\^ \*\[A-Za-z0-9\]+: \*\$\/) die(/if (0) die(/'
plugin_case P49-arch-severity-copy-drift T5 "$ARC_AGENT" 's/| Log groups without retention, or no access logs at the CDN | Low |/| Log groups without retention, or no access logs at the CDN | Medium |/'
REVIEW="$ARC/skills/architecture-review/SKILL.md"
DEPLOY="$ARC/skills/deployment-options/SKILL.md"
plugin_case P50-arch-new-row-drift T5 "$ARC_AGENT" 's/leaves partial state (section 4, API design) | Medium |/leaves partial state (section 4, API design) | Low |/'
plugin_case P51-review-pricing-path-wrong T11 "$REVIEW" 's|\$PLUGIN_ROOT/pricing/aws-us-east-1.tsv|$PLUGIN_ROOT/references/aws-us-east-1.tsv|g'
plugin_case P52-review-invents-maturity-value T11 "$REVIEW" 's/is one of enterprise, standard or prototype/is one of enterprise, standard or club-static/'
plugin_case P53-agent-rates-off-table T11 "$ARC_AGENT" 's/goes under \*\*Other observations (unrated)\*\*/gets the nearest severity/'
plugin_case P54-unset-target-rated-met T11 "$REVIEW" 's/unmeasured, never met/unmeasured or met/'
plugin_case P55-review-carries-findings-over T11 "$REVIEW" '/^- \*\*Fresh evidence\.\*\*/d'
plugin_case P56-deploy-report-path-only T11 "$DEPLOY" '/^- \*\*Everything in the report\.\*\*/d'
plugin_case P57-deploy-cites-missing-step T11 "$DEPLOY" 's/architecture-review Step 0/architecture-review Step 9/'
plugin_case P58-review-skips-client-secrets T11 "$REVIEW" 's/, and secrets in client code: search the served HTML and JavaScript and the templates for credential-like assignments/, and secrets in templates/'
plugin_case P59-agent-secrets-only-when-published T11 "$ARC_AGENT" 's/a hit is High whether or not the page is published yet/a hit is High once the page is published/'
plugin_case P60-review-drops-security-referral T11 "$REVIEW" 's/ Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`\.//'
plugin_case P61-agent-at-risk-rule-removed T11 "$ARC_AGENT" 's/; it is at risk instead when the evidence shows a gap\././'
plugin_case P200-quality-attributes-calls-ux-planned T11 "$ARC/skills/quality-attributes/SKILL.md" 's/that is the `ascent-ux` plugin and/that is the `ascent-ux` plugin (planned) and/'
plugin_case P201-cfn-check-no-help T11 "$ARC/scripts/check-cfn-static-site.sh" '/^case "\${1:-}" in -h|--help)/d'
# ascent-architecture 0.2.1 (test-skill-rules R12, R13).
plugin_case P872-review-drops-ops-referral T11 "$REVIEW" 's/ Recommended next names `ascent-ops` whenever any item is marked `→ ascent-ops`\.//'
plugin_case P873-agent-drops-ops-referral T11 "$ARC_AGENT" 's/ Recommended next names `ascent-ops` whenever any item is marked `→ ascent-ops`\.//'
plugin_case P874-agent-ops-concerns-unmarked T11 "$ARC_AGENT" 's/, or `→ ascent-ops` when it is operations-only ([^)]*)//'
plugin_case P875-readme-calls-ux-planned T11 "$ARC/README.md" 's/accessibility and UX are `ascent-ux`;/accessibility and UX are `ascent-ux` (planned);/'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1583-next-sentence-missing-architecture T11 plugins/ascent-architecture/skills/architecture-review/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
mutant_group ascent-ux
UX=plugins/ascent-ux
UXW="$UX/scripts/check-web-accessibility.sh"
UXC="$UX/scripts/check-token-contrast.sh"
UXT="$UX/scripts/tokens-to-css.sh"
UXL="$UX/scripts/lib/tokens.awk"
UXR="$UX/skills/ux-review/SKILL.md"
UXD="$UX/skills/design-directions/SKILL.md"
UXA="$UX/agents/ux-reviewer.md"
UXB="$UX/blueprints/accessible-page"
plugin_case P62-web-ignores-lang T11 "$UXW" 's/if (!has(tag, "lang")) fail("U1"/if (0) fail("U1"/'
plugin_case P63-web-ignores-alt T11 "$UXW" 's/if (!has(tag, "alt") \&\&/if (0 \&\&/'
plugin_case P64-web-label-for-ignored T11 "$UXW" 's/(v in LABELFOR)/(0)/'
plugin_case P65-web-empty-name-passes T11 "$UXW" 's/^  return c != ""$/  return 1/'
plugin_case P66-web-zoom-block-missed T11 "$UXW" 's/maximum-scale=(0|1)/maximum-scale=(9)/'
plugin_case P67-web-outline-none-allowed T11 "$UXW" 's/^  if (covered(sel)) return$/  return/'
plugin_case P68-web-no-key-handler-needed T11 "$UXW" 's/if (!has(tag, "onkeydown|onkeyup|onkeypress|keydown|keyup|keypress")) c = /if (0) c = /'
plugin_case P69-web-core-not-high T11 "$UXW" 's/ISCORE ? "High" : ""/""/g'
plugin_case P70-web-scans-comments T11 "$UXW" 's/^  blank_between("<!--", "-->", 0)$//'
plugin_case P71-contrast-no-linearization T11 "$UXC" 's/((c + 0.055) \/ 1.055) ^ 2.4/c/'
plugin_case P72-contrast-text-threshold T11 "$UXC" 's/if (kind == "text") return 4.5/if (kind == "text") return 4.4/'
plugin_case P73-contrast-rounds-up T11 "$UXC" 's/int(r \* 100) \/ 100/r/'
plugin_case P74-tokens-alias-unresolved T11 "$UXL" 's/^    v = lookup(theme, ref); depth++$/    depth++/'
plugin_case P75-tokens-no-light-fallback T11 "$UXL" 's/if (theme != "light" /if (0 \&\& theme != "light" /'
plugin_case P76-css-dark-media-ignored T11 "$UXL" 's/prefers-color-scheme:\[ \]\*dark/prefers-color-scheme:[ ]*never/'
plugin_case P77-contrast-on-accent-on-surface T11 "$UXC" 's/x = substr(a, RSTART + 4)/x = "surface"/'
plugin_case P78-css-dark-block-dropped T11 "$UXT" 's/^  print "@media (prefers-color-scheme: dark) {"$//'
plugin_case P79-direction-contrast-regression T11 "$UX/directions/D3-editorial.light.tokens.json" 's/"#57534e"/"#a8a29e"/'
plugin_case P80-blueprint-tokens-drift T11 "$UXB/tokens.css" 's/--color-text-primary: #1f2328;/--color-text-primary: #1f2329;/'
plugin_case P81-blueprint-loses-lang T11 "$UXB/index.html" 's/<html lang="en">/<html>/'
plugin_case P82-ux-severity-copy-drift T5 "$UXA" 's/| Content that flashes more than three times a second (2.3.1) | High |/| Content that flashes more than three times a second (2.3.1) | Medium |/'
plugin_case P83-dependency-not-allowlisted T12 .claude-plugin/marketplace.json 's/, "anthropic-plugin-directory"\]/]/'
plugin_case P84-manifest-key-misspelled T12 "$UX/.claude-plugin/plugin.json" 's/"dependencies"/"dependencis"/'
plugin_case P85-ux-review-rates-off-table T11 "$UXR" 's/goes under \*\*Other observations (unrated)\*\*/gets the nearest severity/'
plugin_case P86-browser-pass-real-data T11 "$UXR" '/\*\*Never\*\* submit forms with real data/d'
plugin_case P87-directions-writes-repo T11 "$UXD" 's/Never write tracked files/Write the token files/'
plugin_case P88-conformance-claimed T11 "$UXR" 's/\*\*No conformance claims from automation\.\*\*/**Conformance from automation.**/'
plugin_case P89-law-map-undated T11 "$UX/references/accessibility-law-map.md" 's/\*\*as_of: /**updated: /'
plugin_case P90-ux-agent-cites-missing-step T9 "$UXA" 's/(ux-review Step 4)/(ux-review Step 9)/'
plugin_case P91-ux-agent-can-write T4 "$UXA" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P92-directions-catalog-drift T11 "$UXD" '/^| UX-D5 | Dense professional/d'
plugin_case_rm P93-ux-tests-removed T11 tests/plugins/ascent-ux
plugin_case P94-web-skips-js-templates T11 "$UXW" 's/^  if (ISJS) B = js_templates(B)$/  if (ISJS) B = blank(B)/'
plugin_case P95-web-u11-global-again T11 "$UXW" 's/^  if (FVALL) return 1$/  return 1/'
plugin_case P96-web-core-needs-exact-path T11 "$UXW" 's/grep -qxF "\${c#\.\/}"/grep -qxF "$c"/'
plugin_case P97-css-root-called-light T11 "$UXL" 's/^  return "base"$/  return "light"/'
plugin_case P98-contrast-names-narrowed T11 "$UXC" 's/(color-)?(text|fg|foreground)(-|$)/^color-text-/'
plugin_case P99-pairs-keep-dashes T11 "$UXC" '/sub(\/^--\/, "", c\[1\]); sub(\/^--\/, "", c\[2\])/d'
plugin_case P100-blueprint-table-overflows T11 "$UXB/page.css" 's/\.table-wrap { overflow-x: auto; max-width: 100%; }//'
plugin_case P101-browser-pass-optional T11 "$UXR" 's/the browser pass is \*\*not optional\*\*/the browser pass is optional/'
plugin_case P102-guessed-flows-unlabelled T11 "$UXR" '/\*\*Guessed core flows are labelled\.\*\*/d'
plugin_case P103-agent-rates-estimates T11 "$UXA" 's/suspected low contrast, not computed/estimated contrast, rated Medium/'
plugin_case P104-agent-key-drift T11 "$UXA" 's/`direction`, //'
plugin_case P105-playwright-files-deleted T11 "$UXR" 's/ Never delete files in the reviewed repository yourself\.//'
plugin_case P106-no-brand-option T11 "$UXD" '/^\*\*Brand-adapted option\.\*\*/d'
plugin_case P107-contrast-per-pair T11 "$UX/skills/design-system-check/SKILL.md" 's/each failing foreground token is one Medium finding/each FAIL is a Medium finding/'
plugin_case P108-web-locale-dependent T11 "$UXW" 's/ LC_ALL=C awk "\$PROG" "\${ARGS\[@\]}"/ awk "$PROG" "${ARGS[@]}"/'
plugin_case P109-tokens-locale-dependent T11 "$UXC" 's/ LC_ALL=C awk "\$PROG" </ awk "$PROG" </'
plugin_case P110-web-js-h1-ignored T11 "$UXW" 's/if (!hasH1 \&\& JSH1 != "") note/if (0) note/'
plugin_case P111-web-delegated-ignored T11 "$UXW" 's/(d = delegated(tag, lname)) != ""/0/'
plugin_case P112-web-delegated-key-assumed T11 "$UXW" 's/if (!DSK\[DHIT\] \&\& /if (0 \&\& /'
plugin_case P113-web-ring-without-focus T11 "$UXW" 's/if (sel ~ \/:focus\/ \&\& ring(full, p))/if (ring(full, p))/'
plugin_case P114-web-ring-none-accepted T11 "$UXW" 's/return v ~ \/\[1-9\]\/ \&\& v/return 1 || v/'
plugin_case P115-web-notes-dropped T11 "$UXW" '/^    printf "%s", NOTES\[k\]$/d'
plugin_case P116-ux-review-notes-rated T11 "$UXR" 's/Each `NOTE` line is unrated/Each `NOTE` line is Low/'
plugin_case P840-web-deleg-other-files-ignored T11 "$UXW" 's/^    if (DSF\[n\] != FILE \&\& DID\[n\] == "" \&\& DCLS\[n\] == "" \&\& DATN\[n\] == 0) continue$/    if (DSF[n] != FILE) continue/'
plugin_case P841-web-deleg-bare-tag-everywhere T11 "$UXW" '/^    if (DSF\[n\] != FILE \&\& DID\[n\] == "" \&\& DCLS\[n\] == "" \&\& DATN\[n\] == 0) continue$/d'
plugin_case P842-web-deleg-classes-unchecked T11 "$UXW" '/^    for (i = 1; i <= nc; i++) if (index(cl, " " cs\[i\] " ") == 0) return 0$/d'
plugin_case P843-web-deleg-attr-value-unchecked T11 "$UXW" 's/^    if (DAX\[n, i\]) { v = /    if (0) { v = /'
plugin_case P844-web-deleg-list-unsplit T11 "$UXW" 's/^    np = split(s, parts, ",")$/    np = 1; parts[1] = s/'
plugin_case P845-web-deleg-quote-unaware T11 "$UXW" 's/("\[^"\]+"|\\047\[^\\047\]+\\047)/["\\047][^"\\047]+["\\047]/'
plugin_case P846-web-deleg-key-from-element-file T11 "$UXW" 's/if (!DSK\[DHIT\] \&\& /if (!(FILE in DKEY) \&\& /'
plugin_case P847-web-ring-contrast-unchecked T11 "$UXW" 's/^        if (rc ~ \/\^F\/) fail("U11"/        if (0) fail("U11"/'
plugin_case P848-web-ring-threshold-off T11 "$UXW" 's/^    if (best < 3) {$/    if (best < 2.5) {/'
plugin_case P849-web-ring-alpha-unblended T11 "$UXW" '/^      if (CA < 1) { CR = CA \* CR /d'
plugin_case P850-web-ring-dark-theme-skipped T11 "$UXW" 's/if (NAMES\["dark"\] != "" || ("dark" in BGV)) ths = ths " dark"; //'
plugin_case P851-web-ring-page-background-ignored T11 "$UXW" 's/{ css_load(T0); bg_load(T0) }/{ css_load(T0) }/'
plugin_case P852-web-ring-first-layer-only T11 "$UXW" 's/^      if (rt > best) { best = rt; bestc = trim(col) }$/      if (bestc == "") { best = rt; bestc = trim(col) }/'
plugin_case P853-web-ring-inset-counted T11 "$UXW" '/^      if (tolower(L\[i\]) ~ .*inset/d'
plugin_case P854-web-ring-unresolved-passes T11 "$UXW" 's/^    if (bestc == "") return "N" unres$/    if (bestc == "") return ""/'
plugin_case P117-agent-delegated-dropped T11 "$UXA" 's/That includes delegated listeners/It covers inline handlers/'
plugin_case P202-tokens-to-css-no-help T11 "$UX/scripts/tokens-to-css.sh" '/^case "\${1:-}" in -h|--help)/d'
# ascent-ux 0.3.0 skills (ADR-022): the ladder, the walk and flow-check (test-ux-rules R25–R33).
UXK="$UX/skills/flow-check/SKILL.md"
UXF_REF="$UX/references/flow-and-reliability.md"
plugin_case P704-review-ladder-rates T11 "$UXR" 's/The ladder orders the report; it never changes a severity\./The ladder sets the severity./'
plugin_case P705-review-lens-dropped T11 "$UXR" '/^- \*\*Reliability:\*\* scripted submits/d'
plugin_case P706-review-groups-merged T11 "$UXR" 's/^\*\*Reliable\*\*$/**Functional, continued**/'
plugin_case P707-review-pleasant-met T11 "$UXR" 's/as \*\*observed\*\* or \*\*at risk\*\*, never met\./as **met** or **at risk**./'
plugin_case P708-agent-pleasant-met T11 "$UXA" 's/A UX-P rule that passes is "observed", never "met"\./A UX-P rule that passes is "met"./'
plugin_case P709-flowcheck-walk-submits T11 "$UXK" 's/\*\*The walk navigates; it never acts for real\.\*\*/**The walk submits forms.**/'
plugin_case P710-review-walk-submits T11 "$UXR" 's/ and the target is `localhost`; on a URL the operator names, navigation only\./; it may submit on any URL./'
plugin_case P711-flowcheck-engine-passed T11 "$UXK" 's/An engine the operator does not run is unmeasured, never passed\./An engine the operator does not run passes./'
plugin_case P712-flowcheck-imports-unread T11 "$UXK" 's/read the hook or service the file imports/rate it as printed/'
plugin_case P713-flowcheck-option-dropped T11 "$UXK" 's/ \[--motion-tokens\] <src directory>/ <src directory>/'
plugin_case P714-flowcheck-option-invented T11 "$UXK" 's/--browsers <browsers, comma-separated>/--browsers <browsers, comma-separated> --strict/'
plugin_case P715-reference-rule-unrated T11 "$UXF_REF" 's/^| UX-R7 | static |/| UX-R8 | static |/'
plugin_case P716-readme-skill-missing T11 "$UX/README.md" '/^| `flow-check` | skill |/d'
plugin_case P717-review-no-flowcheck T11 "$UXR" 's/recommend \[flow-check\](\.\.\/flow-check\/SKILL\.md)\./recommend accessibility-audit./'
plugin_case P718-resilience-pleasant-met T11 "$UX/scripts/check-ux-resilience.sh" 's/"; observed, never met"/""/'
# ascent-ux 0.3.1 (test-ux-rules R39).
plugin_case P868-agent-ring-contrast-unrated T11 "$UXA" 's/ Under 3:1 it is a finding;/ Its contrast is not computed;/'
plugin_case P869-agent-deleg-own-file-only T11 "$UXA" 's/a click listener in any scanned file finds/a click listener in the same file finds/'
plugin_case P870-agent-dead-end-unrated T11 "$UXA" 's/ is a dead end: Low, Medium in a core file\./ is an observation./'
plugin_case P871-flowcheck-imports-not-read T11 "$UXK" 's/For UX-R1 and UX-R2 the script also reads the local modules a file imports/The script reads one file at a time/'
plugin_case P908-readme-latest-playwright T11 plugins/ascent-ux/README.md 's/^npx -y "playwright@\$PW" install firefox webkit$/npx playwright install firefox webkit/'
plugin_case P909-readme-untrialled-again T11 plugins/ascent-ux/README.md 's/beside the companion\. Install the browsers/beside the companion (Firefox and WebKit have not been trialled yet). Install the browsers/'
plugin_case P910-flowcheck-webkit-plain-tab T11 "$UXK" 's/Check keyboard reach in WebKit with `Alt+Tab`\./Check keyboard reach in WebKit with Tab./'
plugin_case P911-flowcheck-console-only T11 "$UXK" 's/never from the console alone\./or from the console./'
plugin_case P912-flowcheck-tls-reported T11 "$UXK" 's/Reload once: report it only if it comes back\./Report it as UX-F5./'
# Review before release, second pass (2026-11-13): the headline, no-contract noise,
# untrusted repositories, other engines and the browser rules (test-ux-rules R25, R34–R38).
plugin_case P774-review-headline-not-met T11 "$UXR" 's/lowest at risk: <principle or "none">; unmeasured: <principle (missing key), … or "none">/lowest not met: <principle or "none">/'
plugin_case P775-review-no-contract-flood T11 "$UXR" 's/ One exception: with no confirmed contract, the unmeasured targets, and the maturity gaps that a missing key alone causes, are one Low finding,.*$//'
plugin_case P776-review-values-unquoted T11 "$UXR" 's/\*\*Quote contract values\.\*\* Single-quote every value/Pass every value/'
plugin_case P777-flowcheck-fixture-anywhere T11 "$UXK" 's/The fixture must be a file inside the reviewed repository, never `\.env\*`, a key or a credentials file; //'
plugin_case P778-review-git-status T11 "$UXR" 's/check with Glob whether `\.playwright-mcp\/` exists in the reviewed repository: the Playwright server may write snapshots there\. Never run `git status` there; an untrusted repository.s git config can run commands\./run `git status` in the reviewed repository./'
plugin_case P779-flowcheck-submit-anywhere T11 "$UXK" 's/; on a URL the operator names it navigates only, with no submit and none of the localhost-only checks below\./; it also runs on any URL the operator names./'
plugin_case P780-review-devserver-unwarned T11 "$UXR" 's/ A dev server runs the reviewed repository.s own code: [^.]*\.//'
plugin_case P781-flowcheck-engine-restart T11 "$UXK" 's/Ask the operator to add a Playwright server for that engine, as the plugin README.s \[Other engines\](\.\.\/\.\.\/README\.md#other-engines) shows,/Ask the operator to restart the Playwright MCP server with `--browser firefox` (or `--browser webkit`),/'
plugin_case P782-readme-engine-recipe T11 "$UX/README.md" 's/^claude mcp add --scope local playwright-firefox .*$/claude mcp add playwright-firefox/'
plugin_case P783-review-f5-off-core-low T11 "$UXR" 's/a dead script on a page off the core flows (UX-F5) | Medium |/a dead script on a page off the core flows (UX-F5) | Low |/'
plugin_case P784-review-f3-off-core-unrated T11 "$UXR" 's/, a page off the core flows that no link reaches or that has no way back (UX-F3)//'
plugin_case P785-flowcheck-note-rated T11 "$UXK" 's/is unrated: list it under Other observations and settle it in the walk/is a Low finding/'
plugin_case P786-flowcheck-f5-5xx-only T11 "$UXK" 's/A same-origin 4xx or 5xx, or an uncaught error, is a UX-F5 finding/A same-origin 5xx is a UX-F5 finding/'
plugin_case P787-flowcheck-f6-layout-low T11 "$UXK" 's/a layout or focus defect that does not block it is Medium\./a layout or focus defect that does not block it is Low./'
plugin_case P788-flowcheck-r5-noted T11 "$UXK" 's/The view state comes back from the URL, or it is a confirmed UX-R5 finding\./The view state is noted./'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1589-next-sentence-missing-ux T11 plugins/ascent-ux/skills/flow-check/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
plugin_case P1591-next-sentence-without-its-link T11 plugins/ascent-ux/skills/ux-review/SKILL.md 's| The file is \[plugin-signals\.md\](\.\./\.\./references/plugin-signals\.md)\.$||'
# ascent-ux 0.3.0 flow integrity (UX-F1–F4, F7; ADR-022): its own group so the ux
# jobs stay inside the CI timeout.
mutant_group ascent-ux-flows
UXF="$UX/scripts/check-flow-integrity.sh"
plugin_case P612-flows-root-link-unchecked T11 "$UXF" 's/^    fail("F1", f, lnat(pos), "link \\"" d "\\" resolves to no file or route", sev); return$/    return/'
plugin_case P613-flows-relative-link-unchecked T11 "$UXF" 's/^  fail("F1", f, lnat(pos), "link \\"" d "\\" resolves to no file" (q/  if (0) fail("F1", f, lnat(pos), "link \\"" d "\\" resolves to no file" (q/'
plugin_case P614-flows-catchall-resolves T11 "$UXF" '/^    if (catchall(first)) continue$/d'
plugin_case P615-flows-no-served-root T11 "$UXF" 's/; if (hit == "") hit = existing_suffix(substr(p, 2))$//'
plugin_case P616-flows-no-html-extension T11 "$UXF" '/^  if ((s ".html") in EXIST) return s ".html"$/d'
plugin_case P617-flows-no-directory-index T11 "$UXF" '/^  if ((s "\/index.html") in EXIST) return s "\/index.html"$/d'
plugin_case P618-flows-climb-allowed T11 "$UXF" 's/if (m == 0) return "\\001"; m--; continue/if (m == 0) continue; m--; continue/'
plugin_case P619-flows-query-kept T11 "$UXF" 's/^  p = v; sub(\/\[?#\]\.\*\$\/, "", p)$/  p = v/'
plugin_case P620-flows-external-checked T11 "$UXF" 's#^  if (v == "" || v ~ /^\[A-Za-z\]\[A-Za-z0-9+.-\]\*:/ || v ~ /^\\/\\//)#  if (v == "")#'
plugin_case P621-flows-dynamic-segment-literal T11 "$UXF" 's/^function dynseg(x) { return x ~/function dynseg(x) { return 0 \&\& x ~/'
plugin_case P622-flows-base-ignored T11 "$UXF" 's/^    if (BASE != "" \&\& (p == BASE/    if (0 \&\& (p == BASE/'
plugin_case P623-flows-router-link-ignored T11 "$UXF" 's/(link|navlink|router-link|routerlink|/(link|navlink|routerlink|/'
plugin_case P624-flows-bound-literal-dynamic T11 "$UXF" 's/^    if ((c == "\\047" || c == "`") \&\& length(v) > 1/    if (0 \&\& length(v) > 1/'
plugin_case P625-flows-brace-literal-dynamic T11 "$UXF" 's/^    if ((c == "\\"" || c == "\\047" || c == "`") \&\& length(v) > 1/    if (0 \&\& length(v) > 1/'
plugin_case P626-flows-navigate-ignored T11 "$UXF" 's/|\[^A-Za-z0-9_.\]navigate\\(|/|/'
plugin_case P627-flows-goto-ignored T11 "$UXF" 's/|\[^A-Za-z0-9_.\]goto\\()\[ \\t\]\*/)[ \\t]*/'
plugin_case P628-flows-html-comments-scanned T11 "$UXF" '/^  t = blank_between(t, "<!--", "-->")$/d'
plugin_case P629-flows-jsx-comments-scanned T11 "$UXF" 's/{ t = blank_between(t, "\/\*", "\*\/"); return (f ~/{ return (f ~/'
plugin_case P630-flows-anchor-unchecked T11 "$UXF" 's/^          else pend_f2(f, lnat(pos), "anchor/          else if (0) pend_f2(f, lnat(pos), "anchor/'
plugin_case P631-flows-aria-unchecked T11 "$UXF" 's/^          else pend_f2(f, lnat(pos), parts\[i\]/          else if (0) pend_f2(f, lnat(pos), parts[i]/'
plugin_case P632-flows-top-needs-target T11 "$UXF" 's/if (tolower(v) != "top" \&\& !(v in ids))/if (!(v in ids))/'
plugin_case P633-flows-runtime-id-fails T11 "$UXF" 's/^          if (dynid) note("F2", f, lnat(pos), parts\[i\]/          if (0) note("F2", f, lnat(pos), parts[i]/'
plugin_case P634-flows-core-not-high T11 "$UXF" 's/(f in COREF) ? "High" : ""/""/g'
plugin_case P635-flows-steps-not-core T11 "$UXF" 's/; if (s !~ \/^\\\/\/) COREF\[s\] = 1 }$/ }/'
plugin_case P636-flows-forward-unchecked T11 "$UXF" 's/^        if (!fwd) fail("F3"/        if (0) fail("F3"/'
plugin_case P637-flows-way-out-unchecked T11 "$UXF" 's/^      if (!hasout) fail("F3"/      if (0) fail("F3"/'
plugin_case P638-flows-history-back-ignored T11 "$UXF" '/^  if (lt ~ \/history\\.(back|go)\\(|router\\.back\\(\/) BACK\[f\] = 1$/d'
plugin_case P639-flows-cancel-button-ignored T11 "$UXF" '/^    if (lname == "button" \&\& tolower(tag)/d'
plugin_case P855-flows-dead-end-unchecked T11 "$UXF" 's/^    fail("F3", f, 1, "the page has no link/    if (0) fail("F3", f, 1, "the page has no link/'
plugin_case P856-flows-dead-end-single-page T11 "$UXF" 's/^  if (np > 1) for /  if (np > 0) for /'
plugin_case P857-flows-dead-end-script-ignored T11 "$UXF" 's/<(script|button|form)\[/<(button|form)[/'
plugin_case P858-flows-dead-end-links-ignored T11 "$UXF" '/LANY\[f\] = 1$/d'
plugin_case P859-flows-dead-end-refresh-ignored T11 "$UXF" 's/|http-equiv\[/|http-equivx[/'
plugin_case P860-flows-dead-end-steps-twice T11 "$UXF" 's/ || (f in STEP) || / || /'
plugin_case P867-flows-dead-end-core-low T11 "$UXF" 's/(a dead end)", (f in COREF) ? "Medium" : "Low")/(a dead end)", "Low")/'
plugin_case P640-flows-loaded-scripts-ignored T11 "$UXF" 's/) SCRIPTS\[f\] = SCRIPTS\[f\] SUBSEP v }$/) v = v }/'
plugin_case P641-flows-file-routes-ignored T11 "$UXF" 's/^    if ((r = file_route(f)) != "") { add_route(r); FROUTE\[f\] = r }$//'
plugin_case P642-flows-route-groups-kept T11 "$UXF" 's/if (seg\[i\] ~ \/^\\(\.\*\\)\$\/ || seg\[i\] ~ \/^@\/ || seg\[i\] == "") continue/if (seg[i] ~ \/^@\/ || seg[i] == "") continue/'
plugin_case P643-flows-notfound-file-ignored T11 "$UXF" '/^    if (basename(f) ~ \/^(404|not-found|notfound|_error|\\+error)\\.\/) NOTFOUND/d'
plugin_case P644-flows-catchall-not-notfound T11 "$UXF" 's/^  if (r ~ \/(^|\\\/)(\\\*\\\*?|/  if (0 \&\& r ~ \/(^|\\\/)(\\\*\\\*?|/'
plugin_case P645-flows-nginx-ignored T11 "$UXF" 's/if (t ~ \/error_page\[ \\t\]+/if (t ~ \/error_pages[ \\t]+/'
plugin_case P646-flows-notfound-unchecked T11 "$UXF" 's/if (NOTFOUND == "") fail("F4"/if (0) fail("F4"/'
plugin_case P647-flows-targets-unchecked T11 "$UXF" 's/^  if (decl == "") { fail("F7"/  if (0) { fail("F7"/'
plugin_case P648-flows-exclusion-ignored T11 "$UXF" 's/^      if (ex) fail("F7"/      if (0) fail("F7"/'
plugin_case P649-flows-family-gap-ignored T11 "$UXF" 's/^      else if (only \&\& !at) fail("F7"/      else if (0) fail("F7"/'
plugin_case P650-flows-browserslistrc-ignored T11 "$UXF" 's/(basename(f) == ".browserslistrc")/(basename(f) == ".browserslistrc-off")/'
plugin_case P651-flows-locale-dependent T11 "$UXF" 's/^  LC_ALL=C awk "\$PROG" "\${cd_args\[@\]}"$/  awk "$PROG" "${cd_args[@]}"/'
plugin_case P652-flows-notes-dropped T11 "$UXF" '/^    printf "%s", NOTES\[k\]$/d'
plugin_case P653-flows-no-help T11 "$UXF" '/^    -h|--help) usage ;;$/d'
plugin_case P654-flows-bad-flow-accepted T11 "$UXF" 's/\*) echo "check-flow-integrity: --flow needs NAME=STEP,STEP,...: \$2" >\&2; exit 2 ;;/*) ;;/'
plugin_case P655-flows-missing-step-accepted T11 "$UXF" 's/grep -qxF -e "\$s" <<< "\$ALL" || { echo "check-flow-integrity: flow step/true || { echo "check-flow-integrity: flow step/'
# Trial calibration (2026-11-13, five repositories): shapes real code uses.
plugin_case P719-flows-prose-comment T11 "$UXF" 's/^  if (f !~ \/\\.(html|htm|eta|ejs|hbs|njk|vue|svelte|astro)\$\/) { t = /  if (1) { t = /'
plugin_case P720-flows-concat-literal T11 "$UXF" '/^  if (v ~ \/^\[ \\t\]\*\[\\047"`\]\[ \\t\]\*\\+|/d'
plugin_case P721-flows-template-unserved T11 "$UXF" 's/if (hit == "" \&\& f ~ \/\\.(eta|ejs|hbs|njk)\$\/)/if (0)/'
plugin_case P722-flows-other-file-id-fails T11 "$UXF" 's/^    if ((pp\[4\] in GID) \&\& GID\[pp\[4\]\] != pp\[1\]) note(/    if (0) note(/'
plugin_case P723-flows-escaped-quotes-misread T11 "$UXF" 's/^  if (c == "\\\\" \&\& substr(v, 2, 1)/  if (0 \&\& substr(v, 2, 1)/'
plugin_case P724-flows-pages-always-routes T11 "$UXF" 's/else if (PAGESROUTER \&\& f ~ /else if (f ~ /'
plugin_case P725-flows-pages-never-routes T11 "$UXF" 's/if (x ~ \/"(next|nuxt|astro|gatsby)"/if (x ~ \/"(nextx)"/'
plugin_case P726-flows-single-page-needs-404 T11 "$UXF" 's/if (pages > 1 || NR_ > 0)/if (pages > 0 || NR_ > 0)/'
# Review before release (2026-11-13): paths, route sources and inputs ordinary projects have.
plugin_case P743-flows-abs-path-loses-root T11 "$UXF" 's/^  return pre out (rel/  return out (rel/'
plugin_case P744-flows-jsx-routes-unread T11 "$UXF" 's/^    if (r != "") add_route(r)$//'
plugin_case P745-flows-child-not-joined T11 "$UXF" 's/r = child_route(nst > 0 ? sp\[nst\] : "", substr(v, 1, i - 1))/r = substr(v, 1, i - 1)/'
plugin_case P746-flows-jsx-child-not-joined T11 "$UXF" 's/: child_route(nst > 0 ? sp\[nst\] : "", v)$/: v/'
plugin_case P747-flows-hash-router-anchor T11 "$UXF" 's/^      if (v ~ \/^#!\/ || /      if (0 \&\& v ~ \/^#!\/ || 0 \&\& /'
plugin_case P748-flows-server-routes-unread T11 "$UXF" 's/(app|router|server|fastify|api)\\.(get|post/(appx)\\.(get|post/'
plugin_case P749-flows-dep-browserslist T11 "$UXF" 's/if (x ~ \/^\[\[{\]\/ || (x ~/if (1 || (x ~/'
plugin_case P750-flows-upper-case-id T11 "$UXF" 's/rest = t; lrest = lt; off = 0/rest = t; lrest = t; off = 0/'
plugin_case P751-flows-unquoted-id T11 "$UXF" 's/) { match(v, \/^\[^ /) { break; match(v, \/^[^ /'
plugin_case P752-flows-big-file-read T11 "$UXF" 's/if (length(T) > 524288) { big = 1; break }/if (0) { big = 1; break }/'
plugin_case P753-flows-core-split-on-space T11 "$UXF" 's/^while IFS= read -r c; do \[ -n "$c" \] || continue;/while IFS= read -r c; do [ -n "$c" ] || continue; c=${c%% *};/'
plugin_case P754-flows-symlink-not-followed T11 "$UXF" 's/ALL="$ALL$(find -H "$p"/ALL="$ALL$(find "$p"/'
# Review before release, second pass (2026-11-13): speed on dense pages, untrusted input.
plugin_case P767-flows-line-count-restarts T11 "$UXF" 's/LA_L += gsub/LA_L = 1 + gsub/'
plugin_case P768-flows-query-printed T11 "$UXF" 's/  d = v; sub(/  d = v; if (0) sub(/'
plugin_case P769-flows-newline-path-read T11 "$UXF" 's/ ! -path "$NLNAME" / /'
plugin_case P770-flows-value-read-as-option T11 "$UXF" 's/grep -qxF -e "$c"/grep -qxF "$c"/'
plugin_case P771-flows-id-copy-drifts T11 "$UXF" 's/lrest = substr(lrest, at)$/lrest = substr(lrest, at + 1)/'
plugin_case P789-flows-step-list-piped T11 "$UXF" 's/grep -qxF -e "\$s" <<< "\$ALL"/printf "%s\\n" "$ALL" | grep -qxF -e "$s"/'
# ascent-ux 0.3.0 reliability and pleasantness (UX-R1–R7, UX-P1–P4; ADR-022).
mutant_group ascent-ux-resilience
UXS="$UX/scripts/check-ux-resilience.sh"
plugin_case P656-res-request-line-off T11 "$UXS" '/^  if (req \&\& substr(t, req, 1) ~ /d'
plugin_case P657-res-hooks-ignored T11 "$UXS" 's/^  hooks = match(t, \/use(Query|SWR|Mutation|Fetch|AsyncData)\\(\/); hk = RSTART$/  hooks = 0; hk = 0/'
plugin_case P658-res-branch-unchecked T11 "$UXS" 's/if (!visible(b) \&\& !handed_on(b)) fail("R2"/if (0) fail("R2"/'
plugin_case P659-res-no-path-unchecked T11 "$UXS" 's/^    else if (nb == 0 \&\& t !~/    else if (0 \&\& t !~/'
plugin_case P660-res-console-visible T11 "$UXS" '/^  gsub(\/console\\.\[a-z\]+\\(\[^)\]\*\\)\/, "", b)$/d'
plugin_case P661-res-everything-visible T11 "$UXS" 's/^  return b ~ \/set\[A-Z\]/  return 1 || b ~ \/set[A-Z]/'
plugin_case P662-res-success-status-branch T11 "$UXS" 's/!==?\[ \\t\]\*2)|onError/!==?[ \\t]*2|===?[ \\t]*2)|onError/'
plugin_case P663-res-status-ignored T11 "$UXS" 's/|\\.status\[ \\t\]\*(>=\[ \\t\]\*\[45\]|!==?\[ \\t\]\*2)|/|/'
plugin_case P664-res-ok-ignored T11 "$UXS" 's/|!(res|resp|response|r)\\.ok|/|/'
plugin_case P665-res-onerror-ignored T11 "$UXS" 's/|onError\[ \\t\]\*\[:=(\]|\\.onerror/|\\.onerror/'
plugin_case P666-res-hook-error-unread T11 "$UXS" 's/hooks \&\& t ~ \/isError|/hooks \&\& t ~ \/isErrorx|/'
plugin_case P667-res-retry-unchecked T11 "$UXS" 's/if (lt !~ \/retry|try again/if (0 \&\& lt !~ \/retry|try again/'
plugin_case P668-res-retry-everywhere T11 "$UXS" 's/^    if (core \&\& nb > 0) { CHK\["R3"\]++/    if (nb > 0) { CHK["R3"]++/'
plugin_case P669-res-double-submit-unchecked T11 "$UXS" 's/^      fail("R1", f, ln, /      if (0) fail("R1", f, ln, /'
plugin_case P670-res-dom-guard-ignored T11 "$UXS" 's/return lt ~ \/\\.disabled\[ \\t\]\*=\[ \\t\]\*true|/return lt ~ \/\\.disabledx|/'
plugin_case P671-res-bound-guard-ignored T11 "$UXS" 's/|\[ \\t:\]disabled\[ \\t\]\*=/|[ \\t]disabledx=/'
plugin_case P672-res-core-not-medium T11 "$UXS" 's/sev = core ? "" : "Low"/sev = "Low"/'
plugin_case P673-res-elsewhere-not-low T11 "$UXS" 's/sev = core ? "" : "Low"/sev = ""/'
plugin_case P674-res-submit-unseen T11 "$UXS" 's/^  sub_ = (lt ~ /  sub_ = 0 \&\& (lt ~ /'
plugin_case P675-res-progress-unchecked T11 "$UXS" 's/if (core) { CHK\["P1"\]++; if (lt !~ /if (core) { CHK["P1"]++; if (0 \&\& lt !~ /'
plugin_case P676-res-draft-unchecked T11 "$UXS" 's/^          fail("R4"/          if (0) fail("R4"/'
plugin_case P677-res-hidden-fields-counted T11 "$UXS" 's/^        if (tag !~ \/type\[ \\t\]\*=\[ \\t\]\*\["\\047\]?(hidden|submit|button|reset|image)\/) cnt++$/        cnt++/'
plugin_case P678-res-draft-threshold-off T11 "$UXS" 's/if (cnt >= DRAFT)/if (cnt > DRAFT)/'
plugin_case P679-res-draft-write-only T11 "$UXS" 's/|\\\/draft\/ \&\& lt ~ /|\\\/draft\/ || lt ~ /'
plugin_case P680-res-url-state-unchecked T11 "$UXS" 's/^      fail("R5"/      if (0) fail("R5"/'
plugin_case P681-res-vue-query-ignored T11 "$UXS" 's/|useSearchParams|route\\.query|/|useSearchParams|/'
plugin_case P682-res-offline-unchecked T11 "$UXS" 's/if (!ONLINE) fail("R6"/if (0) fail("R6"/'
plugin_case P683-res-offline-not-on-entry T11 "$UXS" '/^    if (ENTRY == "" \&\& f ~ /d'
plugin_case P684-res-offline-optional-applied T11 "$UXS" 's/if (OFFLINE == "required") { CHK\["R6"\]++/if (OFFLINE != "none") { CHK["R6"]++/'
plugin_case P685-res-offline-listeners-ignored T11 "$UXS" 's/|addeventlistener\\(\[ \\t\]\*\["\\047\](offline|online)|/|/'
plugin_case P686-res-rollback-unchecked T11 "$UXS" 's/if (t !~ \/onError\[ \\t\]\*\[:(\]\/) fail("R7"/if (0) fail("R7"/'
plugin_case P687-res-motion-unchecked T11 "$UXS" 's/CHK\["P2"\]++; fail("P2"/CHK["P2"]++; if (0) fail("P2"/'
plugin_case P861-res-import-guard-ignored T11 "$UXS" 's/^    if (!has_guard(lt) \&\& imp_with(f, "guard") == "")$/    if (!has_guard(lt))/'
plugin_case P862-res-import-shows-ignored T11 "$UXS" 's/^      if (imp_with(f, "shows") == "") fail("R2"/      fail("R2"/'
plugin_case P863-res-import-throw-shows T11 "$UXS" 's/^function shows_user(b) { gsub(.*); return visible(b) }$/function shows_user(b) { return visible(b) }/'
plugin_case P864-res-import-index-unresolved T11 "$UXS" '/(q "\/index" ex\[e\]) in FIDX/d'
plugin_case P865-res-import-unnamed T11 "$UXS" 's/ imp_note(f), sev)/, sev)/g'
plugin_case P866-res-import-extension-needed T11 "$UXS" '/for (e = 1; e <= n; e++) if ((q ex\[e\]) in FIDX) return q ex\[e\]$/d'
plugin_case P688-res-motion-always T11 "$UXS" 's/^    if (MOTION) check_motion(f, T)$/    check_motion(f, T)/'
plugin_case P689-res-css-comments-scanned T11 "$UXS" 's/{ t = blank_between(t, "\/\*", "\*\/"); return (f ~/{ return (f ~/'
plugin_case P690-res-line-comments-scanned T11 "$UXS" 's/; if (cl == "<\/script>") seg = blank_line_comments(seg)//'
plugin_case P691-res-html-comments-scanned T11 "$UXS" 's/ T = blank_between(T, "<!--", "-->");//'
plugin_case P692-res-consent-unchecked T11 "$UXS" 's/^          fail("P3"/          if (0) fail("P3"/'
plugin_case P693-res-default-checked-ignored T11 "$UXS" 's/(checked|defaultchecked)/(checked)/'
plugin_case P694-res-vue-checked-ignored T11 "$UXS" 's/|:checked\[ \\t\]\*=\[ \\t\]\*"true"\//\//'
plugin_case P695-res-label-ignored T11 "$UXS" 's/^      nm = x " " nm$/      nm = x/'
plugin_case P696-res-way-out-unchecked T11 "$UXS" 's/if (!WAYOUT) fail("P4"/if (0) fail("P4"/'
plugin_case P697-res-register-is-sign-up T11 "$UXS" 's/match(lt, \/<(a|button|label)/match(lt, \/register|<(a|button|label)/'
plugin_case P698-res-locale-dependent T11 "$UXS" 's/^  LC_ALL=C awk "\$PROG" "\${ARGS\[@\]}"$/  awk "$PROG" "${ARGS[@]}"/'
plugin_case P699-res-no-help T11 "$UXS" '/^    -h|--help) usage ;;$/d'
plugin_case P700-res-bad-offline-accepted T11 "$UXS" 's/\*) echo "check-ux-resilience: --offline is required, optional or none: \$2" >\&2; exit 2 ;;/*) OFFLINE="$2" ;;/'
plugin_case P701-res-zero-fields-accepted T11 "$UXS" "s/''|\\*\\[!0-9\\]\\*|0)/''|*[!0-9]*)/"
plugin_case P702-res-core-outside-accepted T11 "$UXS" 's/grep -qxF -e "\$c" <<< "\$FILES" || { echo/true || { echo/'
plugin_case P703-res-text-file-accepted T11 "$UXS" 's/|| { echo "check-ux-resilience: not a markup/|| true || { echo "check-ux-resilience: not a markup/'
# Trial calibration (2026-11-13, five repositories): catch blocks that are not request
# failures, failures handed on, and sign-up controls.
plugin_case P727-res-prose-comment T11 "$UXS" 's/^  if (f !~ \/\\.(html|htm|eta|ejs|hbs|njk|vue|svelte|astro)\$\/) { t = /  if (1) { t = /'
plugin_case P728-res-any-catch-is-request T11 "$UXS" '/^      if (!has_req(try_body(t, at))) continue$/d'
plugin_case P729-res-parse-fallback-rated T11 "$UXS" 's/ || x ~ \/\\.(json|text|blob|arrayBuffer)\\(\\)\[ \\t\\r\\n\]\*\$\/) continue/) continue/'
plugin_case P730-res-handed-on-ignored T11 "$UXS" 's/if (!visible(b) \&\& !handed_on(b)) fail("R2"/if (!visible(b)) fail("R2"/'
plugin_case P731-res-finally-ignored T11 "$UXS" '/^      if (match(x, \/^\[ \\t\\r\\n\]\*finally/d'
plugin_case P732-res-expression-ok-is-branch T11 "$UXS" '/^    if (m ~ \/\\.ok\$|status\/ \&\& rest !~/d'
plugin_case P733-res-result-objects-ignored T11 "$UXS" 's/ \&\& t !~ \/\\.kind\[ \\t\]\*\[!=\]/ \&\& t !~ \/\\.kindx[ \\t]*[!=]/'
plugin_case P734-res-template-brace-is-block T11 "$UXS" 's/ \&\& substr(r, RLENGTH - 1, 1) != "\$"//'
plugin_case P735-res-fallback-variable-rated T11 "$UXS" 's/|`|\[A-Za-z_\$\]\[A-Za-z0-9_\$.\]\*\[ \\t\\r\\n\]\*\$)/|`)/'
plugin_case P736-res-rerender-unseen T11 "$UXS" 's/|render\[A-Za-z\]\*\\(|/|/'
plugin_case P737-res-notice-unseen T11 "$UXS" 's/|\[Nn\]otice|\[Aa\]lert|\[Ww\]arning|\[Bb\]anner)/)/'
plugin_case P738-res-error-flag-case T11 "$UXS" 's/(\[Ee\]rror|\[Ee\]rr|/(error|err|/'
plugin_case P739-res-api-client-unseen T11 "$UXS" 's/|(^|\[^A-Za-z0-9_\])\[A-Za-z_\]\*(\[Aa\]pi|API)\\.\[A-Za-z_\]+\\(\/) ? RSTART : 0/\/) ? RSTART : 0/'
plugin_case P740-res-debounce-unseen T11 "$UXS" 's/|debounce|throttle|toosoon|/|/'
plugin_case P741-res-any-text-is-sign-up T11 "$UXS" 's/match(lt, \/<(a|button|label)(\[ \\t\\n\]\[^>\]\*)?>/match(lt, \/<[a-z0-9]+([ \\t\\n][^>]*)?>/'
plugin_case P742-res-sign-up-label-missed T11 "$UXS" 's/match(lt, \/<(a|button|label)(/match(lt, \/<(a|button)(/'
# Review before release (2026-11-13): idioms from library docs, label text, and paths.
plugin_case P755-res-flag-through-object T11 "$UXS" 's/!?\[a-z0-9_$\]\*\[\.\]?(issubmitting|/!?(issubmitting|/'
plugin_case P756-res-status-error-unread T11 "$UXS" 's/|\[^A-Za-z_.\]error\\.message|status\[ \\t\]\*===?\[ \\t\]\*\["\\047`\]error|/|/'
plugin_case P757-res-hook-line-lost T11 "$UXS" 's/line_at(t, req ? req : hk)/line_at(t, req)/'
plugin_case P758-res-motion-reset-rated T11 "$UXS" 's/ \&\& d !~ \/:\[ \\t\]\*0?\\\.\[0-9\]+ms|/ \&\& d ~ \/:[ \\t]*0?\\.[0-9]+ms|/'
plugin_case P759-res-tag-cut-at-arrow T11 "$UXS" 's/ms = RSTART; k = tag_end(substr(rest, ms)); if (k == 0) break/ms = RSTART; k = index(substr(rest, ms), ">"); if (k == 0) break/'
plugin_case P760-res-label-overreach T11 "$UXS" 's/; if ((i = index(nm, "<\/label")) > 0) nm = substr(nm, 1, i - 1)$//'
plugin_case P761-res-share-as-substring T11 "$UXS" 's/|share (my|your|our)|sharing|/|share|/'
plugin_case P762-res-join-anything T11 "$UXS" 's/join\[ \\t\]+(now|today|free|us|our|the|for)/join[ \\t]+([a-z]+)/'
plugin_case P763-res-join-now-missed T11 "$UXS" 's/|join\[ \\t\]+(now|/|joinx[ \\t]+(now|/'
plugin_case P764-res-big-file-read T11 "$UXS" 's/if (length(T) > 524288) { big = 1; break }/if (0) { big = 1; break }/'
plugin_case P765-res-core-split-on-space T11 "$UXS" 's/^while IFS= read -r c; do \[ -n "$c" \] || continue;/while IFS= read -r c; do [ -n "$c" ] || continue; c=${c%% *};/'
plugin_case P766-res-symlink-not-followed T11 "$UXS" 's/FILES="$FILES$(find -H "$p"/FILES="$FILES$(find "$p"/'
# Review before release, second pass (2026-11-13): a shown hook error is a check met.
plugin_case P772-res-hook-error-not-counted T11 "$UXS" 's/) CHK\["R2"\]++$/) nb = 0/'
plugin_case P773-res-newline-path-read T11 "$UXS" 's/ ! -path "$NLNAME" / /'
plugin_case P790-res-core-list-piped T11 "$UXS" 's/grep -qxF -e "\$c" <<< "\$FILES"/printf "%s\\n" "$FILES" | grep -qxF -e "$c"/'
# ascent-ops runs as six groups so each CI job stays well inside its timeout:
# one control runs the ops tests (about 20 s), against 7 s for the other plugins.
OPS=plugins/ascent-ops
OPI="$OPS/scripts/lib/check-iac-config.awk"
OPZ="$OPS/scripts/lib/check-ops-scripts.awk"
OPM="$OPS/scripts/lib/check-ops-manuals.awk"
OPR="$OPS/skills/ops-review/SKILL.md"
OPN="$OPS/skills/ops-manuals/SKILL.md"
OPA="$OPS/agents/ops-reviewer.md"
OPB="$OPS/blueprints/operable-service"
mutant_group ascent-ops-config
plugin_case P118-iac-noecho-ignored T11 "$OPI" 's/if (YK == "NoEcho" && /if (0 \&\& /'
plugin_case P119-iac-literal-default-missed T11 "$OPI" 's/if (YK == "Default" && secretish(item)/if (0 \&\& secretish(item)/'
plugin_case P120-iac-wildcard-allowed T11 "$OPI" 's/return tok == "\*" || /return 0 \&\& /'
plugin_case P121-iac-policy-doc-wildcard-missed T11 "$OPI" 's/if (wildany(YV)) { if (rtype/if (0) { if (rtype/'
plugin_case P122-iac-ignore-changes-missed T11 "$OPI" 's/if (line ~ \/ignore_changes \*= \*all\/)/if (0)/'
plugin_case P123-iac-state-file-ignored T11 "$OPI" 's/if (ST\[j\] != "")/if (0)/'
plugin_case P124-iac-backend-unencrypted T11 "$OPI" 's/if (!BENC) fail/if (0) fail/'
plugin_case P125-iac-rotation-ignored T11 "$OPI" 's/if (!(SECRET\[j\] in ROT)) fail/if (0) fail/'
plugin_case P126-iac-env-file-in-image T11 "$OPI" 's/fail("S8", "High", FN ":" dl, "an env file (" t ") is copied into the image"); break/break/'
plugin_case P127-iac-password-not-secret T11 "$OPI" 's/return l ~ \/(password|passwd/return l ~ \/(xpassword|passwd/'
plugin_case P128-iac-manual-not-compared T11 "$OPI" 's/if (nm > 0) fail("S10"/if (0) fail("S10"/'
plugin_case P129-iac-severity-off-table T11 "$OPI" 's/fail("S6", "Low"/fail("S6", "Info"/'
plugin_case P162-blueprint-latest-image T11 "$OPB/compose.yml" 's/nginx:1.27.2-alpine/nginx:latest/'
plugin_case P163-blueprint-echoes-token T11 "$OPB/ops-script-template.sh" 's/read -rs -p "Registry token/read -r -p "Registry token/'
plugin_case P164-blueprint-rotation-dropped T11 "$OPB/secure-parameters.yaml" '/^  DatabaseSecretRotation:$/,/^$/d'
plugin_case P165-blueprint-deployment-diagram-dropped T11 "$OPB/MAINTENANCE-AND-OPERATIONS.md" 's/C4Deployment/flowchart LR/'
mutant_group ascent-ops-scripts
plugin_case P130-scripts-shebang-ignored T11 "$OPZ" 's/if (!SHEBANG) fail("Z1"/if (0) fail("Z1"/'
plugin_case P131-scripts-pipefail-optional T11 "$OPZ" 's/(SP || POSIX)))/(1 || POSIX)))/'
plugin_case P132-scripts-dry-run-ignored T11 "$OPZ" 's/if (!DRY) fail("Z4"/if (0) fail("Z4"/'
plugin_case P133-scripts-read-always-silent T11 "$OPZ" 's/if (T\[j\] ~ \/^-\[A-Za-z\]\*s\/) silent = 1/silent = 1/'
plugin_case P134-scripts-argument-secret-ok T11 "$OPZ" 's/fail("Z5", "High", at(), s " comes from/0 \&\& fail("Z5", "High", at(), s " comes from/'
plugin_case P135-scripts-unguarded-destroy-ok T11 "$OPZ" 's/if (NDEST > 0 && !GUARD)/if (0)/'
plugin_case P136-scripts-latest-from-ok T11 "$OPZ" 's/else if (floattag(t)) fail("Z8", "Medium", at(), "FROM/else if (0) fail("Z8", "Medium", at(), "FROM/'
plugin_case P137-scripts-branch-action-ok T11 "$OPZ" 's/u ~ \/@(main|master|latest|HEAD|dev|develop|trunk)\$\/ ||/0 ||/'
plugin_case P138-scripts-curl-pipe-ok T11 "$OPZ" 's/if (s ~ \/(curl|wget)/if (0 \&\& s ~ \/(curl|wget)/'
plugin_case P139-scripts-unbounded-provider-ok T11 "$OPZ" 's/else if (v ~ \/>\/ && v !~ \/<\/ && v !~ \/~>\/) fail/else if (0) fail/'
plugin_case P140-scripts-make-help-ignored T11 "$OPZ" 's/for (t in MT) if (!(t in MDOC)/for (t in MT) if (0/'
plugin_case P141-scripts-herestring-is-heredoc T11 "$OPZ" 's/\/(^|\[^<\])<<-?/\/<<-?/'
# The scaffold template passes the scripts check (v0.4.20; test-check-ops-scripts "a fresh scaffold").
T11_FORCE=ascent-ops plugin_case P876-template-nginx-floating T11 skills/lloydbriantech-ascent/assets/template/docker-compose.yml 's/image: nginx:1\.30-alpine$/image: nginx:alpine/'
T11_FORCE=ascent-ops plugin_case P877-template-dockerfile-floating T11 skills/lloydbriantech-ascent/assets/template/frontend/Dockerfile 's/^FROM nginx:1\.30-alpine /FROM nginx:alpine /'
T11_FORCE=ascent-ops plugin_case P878-template-dist-backend-untagged T11 skills/lloydbriantech-ascent/assets/template/docker-compose.dist.yml 's/-backend-\${PROJECT_VERSION}$/-backend/'
T11_FORCE=ascent-ops plugin_case P879-template-prod-backend-untagged T11 skills/lloydbriantech-ascent/assets/template/docker-compose.prod.yml 's/-backend-\${PROJECT_VERSION}$/-backend/'
T11_FORCE=ascent-ops plugin_case P880-template-help-no-usage T11 skills/lloydbriantech-ascent/assets/template/make/help.sh '/^case "\${1:-}" in -h|--help)/d'
plugin_case P151-review-recommends-z-names T11 "$OPR" 's/Never recommend a `z`-suffixed name\./Prefer `z`-suffixed names./'
plugin_case P152-manuals-skill-writes-more T11 "$OPN" 's/\*\*Two files only\.\*\*/**Files as needed.**/'
plugin_case P153-runbook-check-runs-dry-run T11 "$OPS/skills/runbook-check/SKILL.md" 's/\*\*Never run the scripts or the runbook steps\*\*/**Run the scripts with --dry-run**/'
plugin_case P154-iac-check-prints-values T11 "$OPS/skills/iac-config-check/SKILL.md" 's/\*\*Never print a value\.\*\*/**Print masked values.**/'
plugin_case P155-ops-agent-drops-security-referral T11 "$OPA" 's/ Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`\.//'
mutant_group ascent-ops-manuals
plugin_case P142-manuals-access-key-missed T11 "$OPM" 's/if (line ~ \/AKIA/if (0 \&\& line ~ \/AKIA/'
plugin_case P143-manuals-private-key-missed T11 "$OPM" 's/if (line ~ \/-----BEGIN/if (0 \&\& line ~ \/-----BEGIN/'
plugin_case P144-manuals-age-ignored T11 "$OPM" 's/if (age > MAXAGE) fail/if (0) fail/'
plugin_case P145-manuals-source-commits-ignored T11 "$OPM" 's/if (G\[1\] + 0 > 0) fail/if (0) fail/'
plugin_case P146-manuals-days-ignore-day T11 "$OPM" 's/+ int((153 \* mm + 2) \/ 5) + dd - 719469/+ int((153 * mm + 2) \/ 5) - 719469/'
plugin_case P147-manuals-context-level-missed T11 "$OPM" 's/if (t ~ \/^C4Context\/ || /if (0 \&\& /'
plugin_case P148-manuals-undrawn-services-ok T11 "$OPM" 's/if (nm > 0) fail("M4"/if (0) fail("M4"/'
plugin_case P149-manuals-front-matter-ignored T11 "$OPM" 's/if (!HASFM\[m\]) fail/if (0) fail/'
plugin_case P150-manuals-symptom-columns T11 "$OPM" 's/SYMCOLS < 4/SYMCOLS < 1/'
plugin_case P156-ops-agent-key-drift T11 "$OPA" 's/`started_path`, `slos`/`slos`/'
plugin_case P157-ops-severity-copy-drift T5 "$OPA" 's/| A destructive command with no confirmation or explicit flag (OPS-Z6) | High |/| A destructive command with no confirmation or explicit flag (OPS-Z6) | Medium |/'
plugin_case P158-ops-agent-can-write T4 "$OPA" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P159-ops-agent-cites-missing-step T9 "$OPA" 's/(ops-review Step 4)/(ops-review Step 9)/'
plugin_case P160-ops-skill-pre-approves-writes T4b "$OPN" 's/^allowed-tools: Read, Grep, Glob, /allowed-tools: Read, Grep, Glob, Write, /'
plugin_case P161-ops-version-not-bumped T3 "$OPS/.claude-plugin/plugin.json" 's/"version": "\([0-9][0-9.]*\)"/"version": "\1-x"/'
plugin_case_rm P166-ops-tests-removed T11 tests/plugins/ascent-ops
mutant_group ascent-ops-review
plugin_case P167-iac-kms-root-ignored T11 "$OPI" 's/kmsWild != "" && !kmsRoot/kmsWild != ""/'
plugin_case P168-iac-kms-whole-key-exempt T11 "$OPI" 's/function kmsFlush() { if (kmsWild != "" \&\&/function kmsFlush() { if (0 \&\&/'
plugin_case P169-iac-taskjson-env-never-closes T11 "$OPI" 's/else if (ch == "]" && --envDep == 0) { inEnv = 0; break }/else if (ch == "]") --envDep/'
plugin_case P170-iac-docker-continuation-dropped T11 "$OPI" 's/dacc = dacc line; next/next/'
plugin_case P171-iac-one-line-block-ignored T11 "$OPI" 's/one = (pre == 0 && tfB != "" && no > 0 && tfD == 0)/one = 0/'
plugin_case P172-iac-inline-map-ignored T11 "$OPI" 's/if (!found && line ~ \/\\{\.\*/if (0 \&\& line ~ \/\\{.*/'
plugin_case P173-iac-version-counts-as-rotation T11 "$OPI" 's/tfT == "aws_secretsmanager_secret_rotation" && match/match/'
plugin_case P174-iac-store-type-ignored T11 "$OPI" 's/{ entStore = 1; penName = ""; next }/{ next }/'
plugin_case P175-iac-time-units-are-secrets T11 "$OPI" 's/(seconds|minutes|hours|days)/(never)/'
plugin_case P176-iac-drift-comments-count T11 "$OPI" 's/^  if (raw ~ \/^ \*(#|\\\/\\\/)\/) next$//'
plugin_case P177-iac-drift-tests-count T11 "$OPS/scripts/check-iac-config.sh" 's#\*/tests/\*|#*/never/*|#'
plugin_case P178-iac-local-override-is-prod T11 "$OPI" 's/ && lc(RP) !~ \/local|dev|test|example\/) fail/) fail/'
plugin_case P179-scripts-token-is-a-guard T11 "$OPZ" 's/\^(confirm|confirmation|answer|reply|ok|yn|yesno|proceed|sure)\$/(confirm|answer|ok|yn)/'
plugin_case P180-scripts-prompt-not-parsed T11 "$OPZ" 's/( +-\[A-Za-z\]+( +P)?)\*/( +-[A-Za-z]+)*/'
plugin_case P181-scripts-prints-the-line T11 "$OPZ" 's/DESTC\[NDEST\] = destword(line)/DESTC[NDEST] = line/'
plugin_case P182-scripts-build-not-exempt T11 "$OPZ" 's/if (!cBuild) {/if (1) {/'
plugin_case P183-scripts-alpine-not-floating T11 "$OPZ" 's/ || t ~ \/:\[A-Za-z_-\]+\$\/ }/ }/'
plugin_case P184-scripts-git-ssh-is-registry T11 "$OPZ" 's/|git::|git@|github/|git::|github/'
plugin_case P185-manuals-fm-comment-kept T11 "$OPM" 's/^    sub(\/\[ \\t\]+#\.\*\$\/, "", line)$//'
plugin_case P186-manuals-fm-comment-kept-in-bash T11 "$OPS/scripts/check-ops-manuals.sh" 's/{ sub(\/\[ \\t\]+#\.\*\$\/, ""); print }/{ print }/'
# R13 in one awk pass (ADR-025): a row that names an id outright, and a range that names one
plugin_case P915-r13-named-severity-drift T11 "$OPR" 's/reads it without -s or prints it (OPS-Z5) | High |/reads it without -s or prints it (OPS-Z5) | Medium |/'
plugin_case P916-r13-range-shortened T11 "$OPR" 's/(OPS-M1–M4, OPS-M6, OPS-M7)/(OPS-M1, OPS-M6, OPS-M7)/'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1586-next-sentence-missing-ops T11 plugins/ascent-ops/skills/ops-review/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
plugin_case P1590-next-sentence-reworded T11 plugins/ascent-ops/skills/recovery-drill/SKILL.md 's/whose signal this repository shows and whose skills are not available in this session, with its reason\./that might help./'
plugin_case P1594-signals-copy-not-generated T11 plugins/ascent-ops/references/plugin-signals.md '1d'
mutant_group ascent-ops-calibration
plugin_case P187-scripts-help-helper-ignored T11 "$OPZ" 's/\[Hh\]elp\[A-Za-z0-9_\]\* +/[Hh]elpNEVER[A-Za-z0-9_]* +/'
plugin_case P188-scripts-apply-not-a-dry-run T11 "$OPZ" 's/|--apply|(^|\[^A-Za-z_\])APPLY=|--preview|PREVIEW\//\//'
plugin_case P189-scripts-quoted-text-is-a-command T11 "$OPZ" 's/"P", cl)/"P", cx)/'
plugin_case P190-scripts-comment-is-a-command T11 "$OPZ" 's/^  sub(\/\[ \\t\]+#\.\*\$\/, "", cl)$//'
plugin_case P191-scripts-ssh-text-masked T11 "$OPZ" 's/(ssh|(ba|z|da)?sh +-c|eval|sudo|su +-c|xargs)/(nevermatch)/'
plugin_case P192-scripts-pre-by-position-ignored T11 "$OPZ" 's/if (CKMIN > 0 && CKMIN < CL) PRE = 1/PRE = PRE/'
plugin_case P193-scripts-post-by-position-ignored T11 "$OPZ" 's/if (CKMAX > CF) POST = 1/POST = POST/'
plugin_case P194-scripts-variable-command-missed T11 "$OPZ" 's/if (!hit) for (v in CMDV)/if (0) for (v in CMDV)/'
plugin_case P195-scripts-required-version-ignored T11 "$OPZ" 's/fail("Z8", "Medium", at(), "terraform required_version/0 \&\& fail("Z8", "Medium", at(), "terraform required_version/'
plugin_case P196-scripts-binary-read-as-script T11 "$OPS/scripts/check-ops-scripts.sh" 's/^    LC_ALL=C grep -Iq \. "\$f" 2>\/dev\/null || return 0$//'
plugin_case P197-review-rollback-always-high T11 "$OPR" 's/\*\*Rollback is rated by what exists\.\*\*/**Rollback is always High.**/'
plugin_case P198-review-proposes-z-paths T11 "$OPR" 's/Never propose a `z`-suffixed value\./Propose the detected value./'
plugin_case P199-iac-trivy-runs-online T11 "$OPS/skills/iac-config-check/SKILL.md" 's/--skip-check-update --skip-version-check --quiet/--quiet/'
# OPS-S8 classified on the absolute path: a checkout under a folder named "dev" or
# "Developer" hid every production env file (fixed in v0.4.12, ADR-020).
plugin_case P501-iac-s8-absolute-path T11 "$OPI" 's/if (lc(RP) ~ \/prod\/ \&\& lc(RP) !~/if (lc(FN) ~ \/prod\/ \&\& lc(FN) !~/'
plugin_case P502-iac-env-folder-absolute-path T11 "$OPS/scripts/check-iac-config.sh" 's#^  case "\$(rel "\$f")" in \*/environments/\*#  case "$f" in */environments/*#'
plugin_case P505-iac-s8-relative-folder-dropped T11 "$OPS/scripts/check-iac-config.sh" 's|printf '\''/%s/%s'\'' "[$]{t#./}" "[$]{1#"[$]t"/}"|printf '\''/%s'\'' "${1#"$t"/}"|'
plugin_case P506-iac-s8-absolute-folder-dropped T11 "$OPS/scripts/check-iac-config.sh" 's|printf '\''/%s/%s'\'' "[$]{t##\*/}" "[$]{1#|printf '\''/%s'\'' "${1#|'
# ascent-ops 0.3.0: recovery drills and readiness exercises (OPS-R, OPS-X; ADR-020).
OPD="$OPS/scripts/lib/check-drills.awk"
OPDS="$OPS/scripts/check-drills.sh"
OPDK="$OPS/skills/recovery-drill/SKILL.md"
mutant_group ascent-ops-drills
plugin_case P461-drills-private-key-missed T11 "$OPD" 's/if (line ~ \/-----BEGIN \[A-Z \]\*PRIVATE KEY-----\/) fail/if (0) fail/'
plugin_case P462-drills-access-key-missed T11 "$OPD" 's/if (line ~ \/AKIA/if (0 \&\& line ~ \/AKIA/'
plugin_case P463-drills-secret-value-missed T11 "$OPD" 's/if (!secretish(k) || !match/if (1 || !match/'
plugin_case P464-drills-email-missed T11 "$OPD" 's/fail("R5", "Medium", where, "an email/0 \&\& fail("R5", "Medium", where, "an email/'
plugin_case P465-drills-phone-missed T11 "$OPD" 's/fail("R5", "Medium", where, "a phone/0 \&\& fail("R5", "Medium", where, "a phone/'
plugin_case P466-drills-prose-is-a-secret T11 "$OPD" '/^    if (!eq \&\& substr(rest, 1, 1) == " " /d'
plugin_case P467-drills-evidence-outside-ok T11 "$OPD" 's/{ fail("R5", "Medium", at(i, "evidence"), "evidence " safe(e) " is outside/{ 0 \&\& fail("R5", "Medium", at(i, "evidence"), "evidence " safe(e) " is outside/'
plugin_case P468-drills-evidence-missing-ok T11 "$OPD" 's/if (rc < 0 && !got) fail/if (0) fail/'
plugin_case P469-drills-no-evidence-ok T11 "$OPD" 's/if (ev == "") fail/if (0) fail/'
plugin_case P470-drills-follow-up-ignored T11 "$OPD" 's/if (!later) fail("R6"/if (0) fail("R6"/'
plugin_case P471-drills-later-pass-ignored T11 "$OPD" 's/V\[j, "result"\] == "pass" && V\[j, "date"\] > d) later = 1/V[j, "result"] == "pass") later = 1/'
plugin_case P472-drills-runbook-missing-ok T11 "$OPD" 's/else if (!(PR\[p\] in RBSEEN)) fail/else if (0) fail/'
plugin_case P473-drills-rollback-optional T11 "$OPD" 's/if (!RBBACK\[PR\[p\]\]) miss/if (0) miss/'
plugin_case P474-drills-stop-if-assumed T11 "$OPD" 's/if (l ~ \/stop if\/) RBSTOP/if (1) RBSTOP/'
plugin_case P475-drills-age-ignored T11 "$OPD" 's/if (fresh \&\& (days(TODAY) - days(V\[i, "date"\]) > MAXAGE || /if (fresh \&\& (/'
plugin_case P476-drills-name-date-mismatch-ok T11 "$OPD" 's/if (substr(b, 1, 10) != d) fail/if (0) fail/'
plugin_case P477-drills-future-date-ok T11 "$OPD" 's/if (d > TODAY) fail("R3"/if (0) fail("R3"/'
plugin_case P478-drills-missing-fields-ok T11 "$OPD" 's/if (miss != "") fail("R3"/if (0) fail("R3"/'
plugin_case P479-drills-rto-exceeded-ok T11 "$OPD" 's/else if (mm > mt) fail/else if (0) fail/'
plugin_case P480-drills-hours-as-minutes T11 "$OPD" 's/u == "h" ? 3600/u == "h" ? 60/'
plugin_case P481-drills-failed-drill-current T11 "$OPD" 's/b = newest(PN\[p\], PK\[p\], "pass", 1)/b = newest(PN[p], PK[p], "", 1)/'
plugin_case P482-drills-manual-link-date T11 "$OPD" 's/^    t = line; gsub(.*$/    t = line/'
plugin_case P483-drills-manual-behind-ok T11 "$OPD" 's/else if (MDATE < V\[rs, "date"\]) fail/else if (0) fail/'
plugin_case P484-drills-failover-path-ignored T11 "$OPD" 's/if (!has) { w = ""/if (0) { w = ""/'
plugin_case P485-drills-backups-unmeasured-ok T11 "$OPD" 's/if (NP == 0 && NBK > 0) {/if (0) {/'
plugin_case P486-drills-alarm-role-ignored T11 "$OPD" 's/else if (V\[b, "reached"\] == "") fail/else if (0) fail/'
plugin_case P487-drills-stale-alarm-counts T11 "$OPD" 's/b = newest(AN\[a\], "alarm", "pass", 1)/b = newest(AN[a], "alarm", "pass", 0)/'
plugin_case P488-drills-readiness-2xx-ok T11 "$OPD" 's/ && st !~ \/^2\/) best = i/) best = i/'
plugin_case P489-drills-readiness-any-probe T11 "$OPD" 's/if ((pr == READY || /if ((1 || /'
plugin_case P490-drills-dry-run-ignored T11 "$OPD" 's/if (!got) fail("X3"/if (0) fail("X3"/'
plugin_case P491-drills-standard-requires-all T11 "$OPD" 's/(MAT == "standard" && i <= 5)/(MAT == "standard")/'
plugin_case P492-drills-prototype-hides-credentials T11 "$OPD" 's/if (k == "R5" && HIGH\[k\] != "")/if (0)/'
plugin_case P493-drills-days-ignore-day T11 "$OPD" 's/+ int((153 \* mm + 2) \/ 5) + dd - 719469/+ int((153 * mm + 2) \/ 5) - 719469/'
plugin_case P494-drills-bad-kind-accepted T11 "$OPDS" 's/  case "\$kind" in restore|failover) ;; \*) bad/  case "$kind" in *) ;; restore) bad/'
plugin_case P495-drills-bad-maturity-accepted T11 "$OPDS" 's/^case "\$MATURITY" in enterprise|standard|prototype) ;; \*) bad/case "$MATURITY" in *) ;; enterprise) bad/'
plugin_case P496-drills-compose-not-read T11 "$OPDS" 's/^      docker-compose\*\.yml|docker-compose\*\.yaml|compose\*\.yml|compose\*\.yaml|podman-compose\*\.yml|podman-compose\*\.yaml)/      nevermatch)/'
plugin_case P497-drills-skill-runs-drills T11 "$OPDK" 's/\*\*Never run a drill\.\*\*/**Run the drill with care.**/'
plugin_case P498-drills-skill-writes-records T11 "$OPDK" 's/\*\*Never write a drill record\.\*\*/**Fill in the drill record.**/'
plugin_case P499-drills-skill-pre-approves-writes T4b "$OPDK" 's/^allowed-tools: Read, Grep, Glob, /allowed-tools: Read, Grep, Glob, Write, /'
plugin_case P500-drills-severity-copy-drift T5 "$OPA" 's/| A drill that missed the rto or rpo target (OPS-R4), or a failed drill with no follow-up (OPS-R6) | Medium |/| A drill that missed the rto or rpo target (OPS-R4), or a failed drill with no follow-up (OPS-R6) | Low |/'
plugin_case P503-drills-header-severity-off-table T11 "$OPDS" 's/^#   OPS-R7  Low     the manual/#   OPS-R7  Medium  the manual/'
plugin_case P504-drills-agent-key-drift T11 "$OPA" 's/`drills` (`dir`, `max_age_days` and `paths`), //'
plugin_case P507-drills-url-credential-missed T11 "$OPD" 's/{ fail("R5", "High", where, "a credential in a URL/{ 0 \&\& fail("R5", "High", where, "a credential in a URL/'
plugin_case P508-drills-bearer-token-missed T11 "$OPD" 's/ \&\& RLENGTH >= 22) fail("R5"/ \&\& 0) fail("R5"/'
plugin_case P509-drills-table-row-secret-missed T11 "$OPD" 's/if (n >= 4 \&\& secretish(k) \&\& cell/if (0 \&\& cell/'
plugin_case P510-drills-command-after-equals-is-prose T11 "$OPD" 's/if (!eq \&\& substr(rest, 1, 1)/if (substr(rest, 1, 1)/'
plugin_case P511-drills-values-printed T11 "$OPD" 's/^function safe(v) { return .*$/function safe(v) { return v }/'
plugin_case P512-drills-planned-restore-date-counts T11 "$OPD" 's/if (d <= TODAY \&\& d > MDATE)/if (d > MDATE)/'
plugin_case P513-drills-february-31-accepted T11 "$OPD" '/^  if (m == 2) return dd <= 28/d'
plugin_case P514-drills-result-carries-over T11 "$OPD" 's/ res = ""; rty = "";//'
plugin_case P515-drills-stale-readiness-counts T11 "$OPD" 's/ || days(TODAY) - days(V\[i, "date"\]) > MAXAGE || V\[i, "date"\] > TODAY) continue/ || V[i, "date"] > TODAY) continue/'
plugin_case P516-drills-bad-duration-accepted T11 "$OPDS" 's/^  \[ -z "[$]t" \]/  true || [ -z "$t" ]/'
plugin_case P517-drills-dash-path-is-an-expression T11 "$OPDS" 's|^nodash() { case "[$]1" in -\*) printf '\''./%s'\''|nodash() { case "$1" in -*) printf '\''%s'\''|'
plugin_case P518-drills-today-february-30-accepted T11 "$OPDS" 's/2) ml=28; /2) ml=31; /'

mutant_group ascent-quality-inventory
QAS=plugins/ascent-quality
QAI="$QAS/scripts/lib/check-test-inventory.awk"
QAT="$QAS/scripts/lib/check-tests.awk"
QAC="$QAS/scripts/lib/qa-common.awk"
QAF="$QAS/scripts/lib/qa-files.sh"
QAR="$QAS/skills/quality-review/SKILL.md"
QAN="$QAS/skills/test-inventory/SKILL.md"
QAK="$QAS/skills/test-check/SKILL.md"
QAA="$QAS/agents/quality-reviewer.md"
plugin_case P377-inv-type-missing-ok T11 "$QAI" 's/if (CNT\[y\] == 0) fail("I1"/if (0) fail("I1"/'
plugin_case P378-inv-no-ci-ok T11 "$QAI" 's/if (KN\["ci"\] == 0) fail("I2"/if (0) fail("I2"/'
plugin_case P379-inv-ci-not-running-ok T11 "$QAI" 's/else if (!CIRUN) fail("I2"/else if (0) fail("I2"/'
plugin_case P380-inv-make-not-followed T11 "$QAC" 's#if (W\[j\] != "" && W\[j\] !~ /^-|=/ && (W\[j\] in MR || W\[j\] in MP)) out#if (0) out#'
plugin_case P381-inv-npm-script-not-followed T11 "$QAC" 's/if (w in SCR) out = out " ; " expand/if (0) out = out " ; " expand/'
plugin_case P382-inv-e2e-unrun-ok T11 "$QAI" 's/fail("I3", "Low", TFIRST\["e2e"\]/0 \&\& fail("I3", "Low", TFIRST["e2e"]/'
plugin_case P383-inv-contract-unrun-ok T11 "$QAI" 's/fail("I3", "Low", TFIRST\["contract"\]/0 \&\& fail("I3", "Low", TFIRST["contract"]/'
plugin_case P384-inv-boundary-ok T11 "$QAI" 's/if (!hit) fail("I4"/if (0) fail("I4"/'
plugin_case P385-inv-doubles-any-language T11 "$QAI" 's/TOKL\[lg, W\[i\]\] = 1/TOKL["js", W[i]] = TOKL["py", W[i]] = TOKL["go", W[i]] = 1/'
plugin_case P386-inv-go-http-client-missed T11 "$QAI" 's/&& !(0 in GOHTTP)) GOHTTP\[0\]/\&\& 0) GOHTTP[0]/'
plugin_case P387-inv-placeholder-script-ok T11 "$QAI" 's/else if (PKGTEST\[f\] ~ \/no test specified\/) fail/else if (0) fail/'
plugin_case P388-inv-make-test-not-accepted T11 "$QAI" 's/if (!MAKETEST) fail("I5"/fail("I5"/'
plugin_case P389-inv-no-script-ok T11 "$QAI" 's/if (!(f in PKGTEST)) { if (!MAKETEST) fail/if (0) { if (!MAKETEST) fail/'
plugin_case P390-inv-e2e-by-import-missed T11 "$QAC" 's/E2EC\[FN\] = 1/E2ECX[FN] = 1/'
plugin_case P391-inv-integration-path-missed T11 "$QAC" 's#(integration|integration-tests|it)\\/#(nevermatch)\\/#'
plugin_case P392-inv-fixtures-not-skipped T11 "$QAF" 's/ -o -name fixtures -o -name testdata//'
plugin_case P393-inv-ci-comment-counts T11 "$QAI" 's/if (t ~ \/^#\/ || t ~/if (t ~/'
plugin_case P394-inv-unknown-type-accepted T11 "$QAS/scripts/check-test-inventory.sh" 's/case "\$ty" in unit|integration|contract|e2e) ;;/case "$ty" in *) ;;/'
plugin_case P457-inv-prerequisite-cycle T11 "$QAC" 's/^  if (depth > 3 || ++EXPN > 500) return ""   # also ends/  if (0) return ""   # also ends/'
plugin_case P458-inv-install-runs-tests T11 "$QAC" 's/^  gsub(\/(pip3?|pipx/  0 \&\& gsub(\/(pip3?|pipx/'
plugin_case P459-inv-contract-substring T11 "$QAC" 's/b ~ \/(^|\[-_.\])(contract|contracts|pact)(\[-_.\]|\$)\//b ~ \/contract|pact\//'
plugin_case P460-inv-one-line-package-json T11 "$QAC" 's/{ INSCR = 1; line = substr(line, RSTART + RLENGTH) }/{ INSCR = 1; return }/'
mutant_group ascent-quality-trace
plugin_case P395-trace-criterion-untested-ok T11 "$QAT" 's/if (!hit) fail("T1"/if (0) fail("T1"/'
plugin_case P396-trace-parent-not-covered T11 "$QAT" 's/if (!hit) for (r in REF) if (index(r, id ".") == 1)/if (0) for (r in REF) if (index(r, id ".") == 1)/'
plugin_case P397-trace-undefined-id-ok T11 "$QAT" 's/if (!hit) fail("T2"/if (0) fail("T2"/'
plugin_case P398-trace-no-ids-ok T11 "$QAT" 's/CHK\["T3"\]++; fail("T3"/CHK["T3"]++; 0 \&\& fail("T3"/'
plugin_case P399-trace-fence-ids-count T11 "$QAT" 's/if (FENCE) next/if (0) next/'
plugin_case P400-trace-id-inside-word T11 "$QAT" 's/if (pre !~ \/\[A-Za-z0-9_-\]\/ && post/if (1 \&\& post/'
plugin_case P401-trace-core-untested-ok T11 "$QAT" 's/if (!hit) fail("T4"/if (0) fail("T4"/'
plugin_case P402-trace-core-index-not-dir T11 "$QAT" 's/if (key ~ \/^(index|main|__init__|mod|lib)\$\/) { key = d/if (0) { key = d/'
plugin_case P403-trace-go-dir-ignored T11 "$QAT" 's/ || (lang(f) == "go" && (d in GODIR))//'
plugin_case P404-trace-empty-id-pattern-ok T11 "$QAS/scripts/check-tests.sh" 's/an empty string: \$IDP" >&2; exit 2/an empty string: $IDP" >\&2/'
plugin_case P405-trace-helper-not-validated T11 "$QAS/scripts/check-tests.sh" 's/case "\$2" in \*\[!A-Za-z0-9_.\]\*) echo/case "$2" in NEVER) echo/'
plugin_case P406-trace-severity-off-table T11 "$QAT" 's/fail("T2", "Low"/fail("T2", "Info"/'
plugin_case P452-trace-dotted-names-missed T11 "$QAC" 's/if (W\[i\] ~ \/\[A-Za-z0-9\]\\\.\[A-Za-z0-9\]\/)/if (0)/'
plugin_case P453-trace-ancestor-test-dir T11 "$QAF" 's/qa_kind "\${f#"\$p"}"/qa_kind "$f"/'
plugin_case P454-trace-dash-path-to-find T11 "$QAF" 's#^    case "\$p" in \.|\.\.|/\*|\./\*|\.\./\*) ;; \*) p="\./\$p" ;; esac$##'
plugin_case P455-trace-guard-ignores-pattern T11 "$QAS/scripts/check-tests.sh" 's/ENVIRON\["QA_RE"\]/re/'
plugin_case P456-trace-core-na-text T11 "$QAT" 's/ENVIRON\["QA_CORE"\] == ""/1/'
mutant_group ascent-quality-hygiene
plugin_case P407-hyg-focused-ok T11 "$QAT" 's/fail("H1", "High"/0 \&\& fail("H1", "High"/'
plugin_case P408-hyg-fit-ok T11 "$QAT" 's/f(it|describe|context)\[/f(NEVER)[/'
plugin_case P409-hyg-pytest-only-ok T11 "$QAT" 's/pytest\\\.mark\\\.only/pytest\\.mark\\.NEVER/'
plugin_case P410-hyg-skip-reason-ignored T11 "$QAT" 's/if (skipreason(raw, LG)) note/if (0) note/'
plugin_case P411-hyg-unexplained-skip-ok T11 "$QAT" 's/else fail("H2", "Medium"/else 0 \&\& fail("H2", "Medium"/'
plugin_case P412-hyg-comment-not-a-reason T11 "$QAT" 's/if (HADCOM || PREVCOM) return 1/if (0) return 1/'
plugin_case P413-hyg-comment-reason-sticks T11 "$QAT" 's/^  else if (t != "") PREVCOM = 0$//'
plugin_case P414-hyg-no-assertion-ok T11 "$QAT" 's/if (!BASSERT) fail("H3"/if (0) fail("H3"/'
plugin_case P415-hyg-skipped-not-exempt T11 "$QAT" 's/if (BSKIP || !BFN) return/if (!BFN) return/'
plugin_case P416-hyg-start-line-assert-missed T11 "$QAT" '/PYSIG = 0; if (LG == "py")/{n;s/^    if (hasassert(m, LG)) BASSERT = 1$//;}'
plugin_case P417-hyg-go-one-line-open T11 "$QAT" 's/if (BDEPTH <= 0 && index(m, "{")) { endblock(); PREVCOM = 0; next }//'
plugin_case P418-hyg-js-block-never-ends T11 "$QAT" 's#BDEPTH += gsub(/\\(/, "(", m) - gsub(/\\)/, ")", m)#BDEPTH += 1#'
plugin_case P419-hyg-py-indent-ignored T11 "$QAT" 's/if (INB && LG == "py" && t != "")/if (0)/'
plugin_case P420-hyg-bats-end-ignored T11 "$QAT" 's/ else if (LG == "bats" && raw ~ \/^}\/) endblock()//'
plugin_case P421-hyg-runner-retries-ok T11 "$QAT" 's/) fail("H4", "Low", at(), "the test runner retries/) 0 \&\& fail("H4", "Low", at(), "the test runner retries/'
plugin_case P422-hyg-test-retries-ok T11 "$QAT" 's/) fail("H4", "Low", at(), "the test retries/) 0 \&\& fail("H4", "Low", at(), "the test retries/'
plugin_case P423-hyg-ci-reruns-ok T11 "$QAT" 's/{ fail("H4", "Low", at(), "CI reruns/{ 0 \&\& fail("H4", "Low", at(), "CI reruns/'
plugin_case P424-hyg-strings-not-masked T11 "$QAC" 's/^    if (q != "") {$/    if (0) {/'
plugin_case P425-hyg-comments-not-masked T11 "$QAC" 's/if (nx == "\/\/") { HADCOM = 1; break }/if (0) { HADCOM = 1; break }/'
plugin_case P448-hyg-py-signature-ends-test T11 "$QAT" 's/if (PYSIG > 0) { p = m;/if (0) { p = m;/'
plugin_case P449-hyg-triple-quote-not-carried T11 "$QAC" 's/if (q == "`" || length(q) == 3) MQ = q/if (q == "`") MQ = q/'
plugin_case P450-hyg-string-line-ends-test T11 "$QAT" 's/else if (!MSTART) {/else {/'
plugin_case P451-hyg-option-retries-flagged T11 "$QAT" 's#(describe|test)\\\.configure\[ \\t\]\*\\(\[^)\]\*retries#retries#'
mutant_group ascent-quality-rules
plugin_case P426-quality-severity-copy-drift T5 "$QAA" 's/^| A test with no assertion (QA-H3) | Medium |$/| A test with no assertion (QA-H3) | Low |/'
plugin_case P427-quality-agent-can-write T4 "$QAA" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P428-quality-agent-cites-missing-step T9 "$QAA" 's/(quality-review Step 4)/(quality-review Step 9)/'
plugin_case P429-quality-skill-pre-approves-writes T4b "$QAK" 's/^allowed-tools: Read, Grep, Glob, /allowed-tools: Read, Grep, Glob, Write, /'
plugin_case P430-quality-version-not-bumped T3 "$QAS/.claude-plugin/plugin.json" 's/"version": "\([0-9][0-9.]*\)"/"version": "\1-x"/'
plugin_case_rm P431-quality-tests-removed T11 tests/plugins/ascent-quality
plugin_case P432-review-runs-the-suite T11 "$QAR" 's/write or fix a test, run the test suite, or install a test tool\./write or fix a test, or install a test tool./'
plugin_case P433-inventory-runs-ci T11 "$QAN" 's/\*\*Never run the tests or CI\*\*/**Run the tests when needed**/'
plugin_case P434-check-unskips-tests T11 "$QAK" 's/\*\*Never edit, unskip or run a test\.\*\*/**Unskip a test when needed.**/'
plugin_case P435-review-heuristics-unread T11 "$QAR" 's/\*\*QA-H3 and QA-I4 are heuristics\.\*\* Open each hit before you rate it\./**QA-H3 and QA-I4 are heuristics.**/'
plugin_case P436-review-na-is-a-pass T11 "$QAR" 's/`N\/A` is never a pass\./`N\/A` counts as a pass./'
plugin_case P437-agent-drops-security-referral T11 "$QAA" 's/ Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`\.//'
plugin_case P438-review-unmeasured-is-met T11 "$QAR" 's/ A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap\.//'
plugin_case P439-agent-key-drift T11 "$QAA" 's/`assertion_helpers`//'
plugin_case P440-check-names-missing-script T11 "$QAK" 's#"\$PLUGIN_ROOT/scripts/check-tests.sh"#"$PLUGIN_ROOT/scripts/check-test.sh"#'
plugin_case P441-review-maturity-values-drift T11 "$QAR" 's/`maturity_target` is one of enterprise, standard or prototype/`maturity_target` is one of enterprise or standard/'
plugin_case P442-agent-invents-severities T11 "$QAA" 's/Never invent a severity\.//'
plugin_case P443-review-drops-fresh-evidence T11 "$QAR" 's/\*\*Fresh evidence\.\*\*/**Evidence.**/'
plugin_case P444-inventory-cites-missing-step T11 "$QAN" 's/Use the `quality-review` Step 5 format/Use the `quality-review` Step 9 format/'
plugin_case P445-strategy-names-unchecked-rule T11 "$QAS/references/test-strategy.md" 's/^| QA-H4 retries |/| QA-H9 retries |/'
plugin_case P446-inventory-values-unquoted T11 "$QAN" 's/\*\*Quote every contract value\.\*\*/Quote values./'
plugin_case P447-review-git-log-writes T11 "$QAR" 's/, never with `--output`, `--ext-diff` or `--textconv`//'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1587-next-sentence-missing-quality T11 plugins/ascent-quality/skills/quality-review/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
plugin_case_rm P1593-signals-copy-missing T11 plugins/ascent-quality/references/plugin-signals.md
mutant_group ascent-quality-load
QEA="$QAS/scripts/lib/check-test-evidence.awk"
QES="$QAS/scripts/check-test-evidence.sh"
QEK="$QAS/skills/test-evidence/SKILL.md"
plugin_case P519-load-missing-ok T11 "$QEA" 's/if (NL == 0) fail("L1"/if (0) fail("L1"/'
plugin_case P520-load-no-p95-ok T11 "$QEA" 's/if (best < 0) fail("L2"/if (0) fail("L2"/'
plugin_case P521-load-loose-p95-ok T11 "$QEA" 's/else if (best > P95 + 0) fail("L2"/else if (0) fail("L2"/'
plugin_case P522-load-tag-beats-untagged T11 "$QEA" 's/if (f in K6ALL) { v = K6ALL\[f\]; a = K6ALLAT\[f\] } else if (f in K6TAG)/if (0) { v = 0 } else if (f in K6TAG)/'
plugin_case P523-load-tightest-tag-wins T11 "$QEA" 's/if (!(FN in K6TAG) || v > K6TAG\[FN\])/if (!(FN in K6TAG) || v < K6TAG[FN])/'
plugin_case P524-load-threshold-one-line-only T11 "$QEA" 's/^      if (!e) break$/      if (!e) { INTH = 0; break }/'
plugin_case P525-load-artillery-p95-missed T11 "$QEA" 's/(!(FN in AP95) || v < AP95\[FN\])/(0)/'
plugin_case P526-load-locust-p95-missed T11 "$QEA" 's/(!(FN in LP95) || v < LP95\[FN\])/(0)/'
plugin_case P527-load-low-rate-ok T11 "$QEA" 's/if (best < RPS + 0) fail("L3"/if (0) fail("L3"/'
plugin_case P528-load-time-unit-ignored T11 "$QEA" 's/r = SR \/ (STU > 0 ? STU : 1)/r = SR/'
plugin_case P529-load-vus-read-as-rate T11 "$QEA" 's/if (SCN && SEX ~ \/arrival-rate\/ && SR >= 0)/if (SCN \&\& SR >= 0)/'
plugin_case P530-load-rate-note-dropped T11 "$QEA" 's/if (best < 0) note("L3", /if (best < 0) 0 \&\& note("L3", /'
plugin_case P531-load-locust-users-ignored T11 "$QEA" 's/if (v > LUSERS) LUSERS = v/if (0) LUSERS = v/'
plugin_case P532-load-pacing-read-as-rate T11 "$QEA" 's/LTP\[FN\] = 1 \/ v;/LTP[FN] = v;/'
plugin_case P533-load-ramp-to-ignored T11 "$QEA" 's/"(arrivalRate|rampTo)\[/"(arrivalRate)[/'
plugin_case P534-load-no-error-threshold-ok T11 "$QEA" 's/if (!got) fail("L4"/if (0) fail("L4"/'
plugin_case P535-load-k6-checks-missed T11 "$QEA" 's/(base == "checks" && /(0 \&\& /'
plugin_case P536-load-unrun-ok T11 "$QEA" 's/if (!LRUN) fail("L5"/if (0) fail("L5"/'
plugin_case P537-load-runbook-not-read T11 "$QEA" 's/^K == "doc" { runs(raw, 0); /K == "doc" { /'
plugin_case P538-load-package-script-not-read T11 "$QEA" 's/^  for (nm in SCR) runs(SCR\[nm\], 0)$//'
plugin_case P539-load-scripts-unsorted T11 "$QEA" 's/^  for (i = 2; i <= NL; i++) { x = LF\[i\].*$//'
plugin_case P540-load-bad-p95-accepted T11 "$QES" 's/|| bad "--p95 is a number/|| true "--p95 is a number/'
plugin_case P541-load-severity-header-drift T11 "$QES" 's/^#   QA-L4  Low /#   QA-L4  Medium /'
plugin_case P542-load-severity-off-table T11 "$QEA" 's/fail("L5", "Low"/fail("L5", "Info"/'
plugin_case P543-load-severity-copy-drift T5 "$QAA" 's/^| A load test with no error-rate threshold (QA-L4) | Low |$/| A load test with no error-rate threshold (QA-L4) | Medium |/'
plugin_case P544-evidence-runs-load-test T11 "$QEK" 's/\*\*Never run a load test or a mutation tool\.\*\*/**Run the load test when needed.**/'
plugin_case P545-evidence-note-is-a-pass T11 "$QEK" 's/\*\*A NOTE is never a pass\.\*\*/A NOTE counts./'
plugin_case P546-evidence-values-unquoted T11 "$QEK" 's/\*\*Quote every contract value\.\*\*/Quote values./'
plugin_case P576-load-block-comment-read T11 "$QEA" 's/^    if (!e) { s = substr(s, 1, b - 1); INBC = 1; break }$/    if (!e) break/'
plugin_case P577-load-line-comment-read T11 "$QEA" 's/if (t == "" || t ~ \/^(\\\/\\\/|\\\*)\/) next/if (t == "") next/'
plugin_case P578-load-one-threshold-per-line T11 "$QEA" 's/^      INTH = 0; x = substr(x, e + 1)$/      INTH = 0; break/'
plugin_case P579-load-first-p95-only T11 "$QEA" 's/^  while (base == "http_req_duration" && /  if (base == "http_req_duration" \&\& /'
plugin_case P580-load-hours-read-as-minutes T11 "$QEA" 's/q == "h" ? 3600/q == "h" ? 60/'
plugin_case P581-load-start-rate-missed T11 "$QEA" 's/(rate|startRate|target)/(rate)/'
plugin_case P582-load-docker-user-read T11 "$QEA" 's/v = num(substr(s, i), "(^|/v = num(s, "(^|/'
plugin_case P583-load-install-is-a-run T11 "$QEA" '/^function runs(s, ci) {$/{n;s/^  s = noinstall(s)$//;}'
plugin_case P584-load-prose-is-a-run T11 "$QEA" 's/locust(\[ \\t\]+-|\[ \\t\]\*[$]|\[ \\t\]\*\[;&|\])/locust([ \\t]|$)/'
plugin_case P585-load-error-url-counts T11 "$QEA" 's/\[ \\t\]\*(:|<|>|==|!=)\/) ERR/[ \\t]*\/) ERR/'
plugin_case P586-load-vusers-failed-missed T11 "$QEA" 's/(vusers\\\.failed|errors/(errors/'
plugin_case P587-load-num-failures-missed T11 "$QEA" 's/fail_ratio\[ \\t\]\*>|num_failures\[ \\t\]\*>/fail_ratio[ \\t]*>/'
plugin_case P588-load-artillery-needs-no-scenarios T11 "$QEA" 's/for (f in ACFG) if (f in ASCN)/for (f in ACFG) if (1)/'
plugin_case P589-load-standard-drops-l2 T11 "$QEA" 's/(k == "L1" || k == "L2" || k == "M1")/(k == "L1" || k == "M1")/'
plugin_case P590-load-missing-value-unguarded T11 "$QES" 's/^      \[ [$]# -ge 2 \] || { usage >&2; exit 2; }$/      true/'
mutant_group ascent-quality-mutation
plugin_case P547-mut-none-ok T11 "$QEA" 's/if (NTOOL == 0) fail("M1"/if (0) fail("M1"/'
plugin_case P548-mut-no-break-ok T11 "$QEA" 's/if (!(tl in MBRK)) fail("M2"/if (0) fail("M2"/'
plugin_case P549-mut-low-break-ok T11 "$QEA" 's/else if (MBRK\[tl\] < MIN) fail("M2"/else if (0) fail("M2"/'
plugin_case P550-mut-mutmut-needs-break T11 "$QEA" 's/if (tl == "mutmut" || tl == "go-mutesting") { note/if (0) { note/'
plugin_case P551-mut-stryker-break-missed T11 "$QEA" 's/brk("stryker", num(/brk("strykerX", num(/'
plugin_case P552-mut-pit-threshold-missed T11 "$QEA" 's/brk("pit", num(s, "<mutationThreshold>/brk("pitX", num(s, "<mutationThreshold>/'
plugin_case P553-mut-gremlins-flag-missed T11 "$QEA" 's/brk("gremlins", num(s, "--threshold-efficacy/brk("gremlinsX", num(s, "--threshold-efficacy/'
plugin_case P554-mut-not-in-ci-ok T11 "$QEA" 's/if (!MRUN) fail("M3"/if (0) fail("M3"/'
plugin_case P555-mut-make-counts-as-ci T11 "$QEA" 's/if (raw ~ \/^\\t\/) { runs(raw, 0);/if (raw ~ \/^\\t\/) { runs(raw, 1);/'
plugin_case P556-mut-package-script-counts-as-ci T11 "$QEA" 's/for (nm in SCR) runs(SCR\[nm\], 0)/for (nm in SCR) runs(SCR[nm], 1)/'
plugin_case P557-mut-ci-make-not-followed T11 "$QEA" 's/runs(expand(CIL\[j\], 0), 1)/runs(CIL[j], 1)/'
plugin_case P558-mut-no-report-ok T11 "$QEA" 's/if (NREP == 0) fail("M4"/if (0) fail("M4"/'
plugin_case P559-mut-stale-report-ok T11 "$QEA" 's/if (days(TODAY) - days(BD) > MAXAGE) fail/if (0) fail/'
plugin_case P560-mut-low-score-ok T11 "$QEA" 's/else if (BS < MIN) fail("M4"/else if (0) fail("M4"/'
plugin_case P561-mut-undated-ok T11 "$QEA" 's/if (d == "") { np++;/if (0) { np++;/'
plugin_case P562-mut-future-ok T11 "$QEA" 's/if (d > TODAY) { np++;/if (0) { np++;/'
plugin_case P563-mut-unreadable-ok T11 "$QEA" 's/else { np++; PW\[np\] = f ":1"; PM\[np\] = "no mutation score/else { continue; PW[np] = f ":1"; PM[np] = "no mutation score/'
plugin_case P564-mut-oldest-report-wins T11 "$QEA" 's/if (!nb || d > BD)/if (!nb || d < BD)/'
plugin_case P565-mut-february-30-accepted T11 "$QEA" 's/if (m == 2) return dd <= 28/if (m == 2) return dd <= 31/'
plugin_case P566-mut-survivors-not-counted T11 "$QEA" 's/"(Survived|NoCoverage)"/"(NeverStatus)"/'
plugin_case P567-mut-pit-survivors-not-counted T11 "$QEA" 's/(SURVIVED|NO_COVERAGE)/(NEVER_STATUS)/'
plugin_case P568-mut-fraction-not-scaled T11 "$QEA" 's/if (!pct && v <= 1 && m ~/if (0 \&\& v <= 1 \&\& m ~/'
plugin_case P569-mut-commit-date-ignored T11 "$QEA" 's/if (d == "" && isdate(RDATE\[f\])) d = RDATE\[f\]//'
plugin_case P570-mut-standard-requires-all T11 "$QEA" 's/(MAT == "standard" && (k == "L1" || k == "L2" || k == "M1"))/(MAT == "standard")/'
plugin_case P571-mut-missing-report-accepted T11 "$QES" 's/  \[ -f "[$]r" \] || bad "no such report/  true || bad "no such report/'
plugin_case P572-mut-min-score-over-100 T11 "$QES" 's/ \&\& \[ "[$]{MINS%%\.\*}" -le 100 \]//'
plugin_case P573-mut-today-february-30-accepted T11 "$QES" 's/2) ml=28; /2) ml=31; /'
plugin_case P574-mut-severity-copy-drift T5 "$QAA" 's/^| No mutation tool configured (QA-M1) | Medium |$/| No mutation tool configured (QA-M1) | Low |/'
plugin_case P575-review-runs-mutation-tool T11 "$QAR" 's/Never run a load test or a mutation tool\./Run the mutation tool when needed./'
plugin_case P591-mut-config-comment-read T11 "$QEA" '/a commented-out threshold is not a threshold/,/^  b = FN/s/^  if (t ~ .*) next$//'
plugin_case P592-mut-xml-comment-read T11 "$QEA" 's/if (!e) { s = substr(s, 1, b - 1); INXC = 1; break }/if (!e) break/'
plugin_case P593-mut-target-line-is-the-score T11 "$QEA" 's/ && l !~ \/minimum|min\[_ -\]|threshold|target|required|at least|break\///'
plugin_case P594-mut-stray-report-fails T11 "$QEA" 's/^      if (nb) note("M4", PW\[i\], PM\[i\] "; not counted")$/      if (0) note("M4", PW[i], PM[i] "; not counted")/'
plugin_case P595-mut-shallow-dates-reports T11 "$QES" 's/then SHALLOW=1; else GITOK=1; fi/then GITOK=1; else GITOK=1; fi/'
plugin_case P596-mut-git-without-safety T11 "$QES" 's/^GITC="-c safe.bareRepository=explicit -c log.showSignature=false -c core.fsmonitor=false"$/GITC=""/'
plugin_case P597-mut-committer-date T11 "$QES" 's/--format=%as/--format=%cs/'
plugin_case P598-mut-report-outside-accepted T11 "$QES" 's/) bad "--report must be a path inside/) true "--report must be a path inside/'
plugin_case P599-mut-report-symlink-accepted T11 "$QES" 's/\[ ! -L "[$]r" \] || bad/true || bad/'
plugin_case P600-mut-code-named-as-report T11 "$QAF" 's/^    \*\.js|\*\.jsx|\*\.ts|\*\.tsx|\*\.mjs|\*\.cjs|\*\.mts|\*\.cts|\*\.py|\*\.go|\*\.sh|\*\.bats) ;;$//'
plugin_case P601-mut-java-project-na T11 "$QEA" 's/KN\["td"\] + KN\["mut"\] + NTOOL/KN["td"] + NTOOL/'
plugin_case P602-mut-go-install-is-a-tool T11 "$QAC" 's/|brew|go|cargo)\[ \\t\]+/|brew)[ \\t]+/'
plugin_case P603-mut-gradle-threshold-missed T11 "$QEA" 's/brk("pit", num(s, "mutationThreshold/brk("pitX", num(s, "mutationThreshold/'
plugin_case P604-mut-package-stryker-missed T11 "$QEA" 's/if (raw ~ \/"@stryker-mutator\\\/core"\/) tool("stryker")/if (0) tool("stryker")/'
plugin_case P605-mut-mutmut-config-missed T11 "$QEA" 's/if (raw ~ \/^\\\[(tool\\\.)?mutmut\\\]\/) tool("mutmut")/if (0) tool("mutmut")/'
plugin_case P606-mut-ci-step-name-runs T11 "$QEA" 's/ || t ~ \/^-?\[ \\t\]\*(name|description)\[ \\t\]\*:\///'
plugin_case P607-mut-report-without-tool-skipped T11 "$QEA" 's/if (NTOOL > 0 || NREP > 0) {/if (NTOOL > 0) {/'
plugin_case P608-mut-leap-report-date T11 "$QEA" 's/return dd <= 28 + ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)/return dd <= 28/'
plugin_case P609-mut-leap-today T11 "$QES" 's/ \] && ml=29/ ] \&\& ml=28/'
plugin_case P610-mut-standard-drops-m1 T11 "$QEA" 's/(k == "L1" || k == "L2" || k == "M1")/(k == "L1" || k == "L2")/'

# Ownership gate T13 (ADR-015). Every control expects one T13 rule; T11 is
# skipped (T11_FORCE names no plugin) because no control here is about behavior
# tests. The checker-code controls, in the ownership-checker group below, set
# T13_SELFTEST=1 and expect the fixture tests (T13.0) to catch them.
mutant_group ascent-adr
ADRP=plugins/ascent-adr
CAA="$ADRP/scripts/lib/check-adrs.awk"
ACM="$ADRP/scripts/lib/adr-common.awk"
CAS="$ADRP/scripts/check-adrs.sh"
ADS="$ADRP/scripts/lib/adr-dir.sh"
ADK="$ADRP/skills/adr-check/SKILL.md"
ADW="$ADRP/skills/adr-write/SKILL.md"
DDK="$ADRP/skills/decision-drift/SKILL.md"
DRV="$ADRP/agents/decision-reviewer.md"
plugin_case P1001-adr-absent-ok T11 "$CAA" 's/if (NF_ADR == 0) fail("S1"/if (0) fail("S1"/'
plugin_case P1002-adr-sections-unchecked T11 "$CAA" 's/if (miss != "") fail("S2"/if (0) fail("S2"/'
plugin_case P1003-adr-madr-options-optional T11 "$CAA" 's/REQ\["madr"\] = "context and problem statement|considered options|decision outcome"/REQ["madr"] = "context and problem statement|decision outcome"/'
plugin_case P1004-adr-duplicate-number-ok T11 "$CAA" 's/if (FIRST\[i\] != i) fail("S3"/if (0) fail("S3"/'
plugin_case P1005-adr-no-title-ok T11 "$CAA" 's/if (!TIL\[i\]) fail("S3"/if (0) fail("S3"/'
plugin_case P1006-adr-title-number-unchecked T11 "$CAA" 's/if (tn + 0 != NUM\[i\]) fail("S3"/if (0) fail("S3"/'
plugin_case P1007-adr-misnamed-file-ok T11 "$CAA" 's/CHK\["S3"\]++; fail("S3", "Low", shown(OTHER/CHK["S3"]++; if (0) fail("S3", "Low", shown(OTHER/'
plugin_case P1008-adr-index-orphan-ok T11 "$CAA" 's/if (!(ILINK\[j\] in BYBASE)) fail("S4"/if (0) fail("S4"/'
plugin_case P1009-adr-index-status-unchecked T11 "$CAA" 's/else if (ICL\[j\] != ""/else if (0 \&\& ICL[j] != ""/'
plugin_case P1010-adr-unindexed-ok T11 "$CAA" 's/if (!(BASE\[i\] in LISTED)) fail("S4"/if (0) fail("S4"/'
plugin_case P1011-adr-no-status-ok T11 "$CAA" 's/if (!STL\[i\]) fail("S5"/if (0) fail("S5"/'
plugin_case P1012-adr-unknown-status-ok T11 "$CAA" 's/else if (CL\[i\] == "") fail("S5"/else if (0) fail("S5"/'
plugin_case P1013-adr-superseded-no-number-ok T11 "$CAA" 's/if (to < 0) fail("S6"/if (0) fail("S6"/'
plugin_case P1014-adr-replacement-missing-ok T11 "$CAA" 's/else if (!(to in BYNUM)) fail("S6"/else if (0) fail("S6"/'
plugin_case P1015-adr-back-link-unchecked T11 "$CAA" 's/if (index(" " SUPS\[k\], ":" NUM\[i\] " ") == 0) fail("S6"/if (0) fail("S6"/'
plugin_case P1016-adr-supersedes-missing-ok T11 "$CAA" 's/if (!(o in BYNUM)) fail("S6"/if (0) fail("S6"/'
plugin_case P1017-adr-old-still-active-ok T11 "$CAA" 's/else if (CL\[FIRST\[o\]\] != "superseded") fail("S6"/else if (0) fail("S6"/'
plugin_case P1018-adr-proposed-replacement-checked T11 "$CAA" 's/if (CL\[i\] != "proposed" \&\& CL\[i\] != "rejected") {/if (1) {/'
plugin_case P1019-adr-no-date-ok T11 "$CAA" 's/if (!DTL\[i\]) fail("S7"/if (0) fail("S7"/'
plugin_case P1020-adr-unreal-date-ok T11 "$CAA" 's/else if (!adr_realdate(DT\[i\])) fail("S7"/else if (0) fail("S7"/'
plugin_case P1021-adr-future-date-ok T11 "$CAA" 's/> adr_days(TODAY)) fail("S7"/> adr_days(TODAY) \&\& 0) fail("S7"/'
plugin_case P1022-adr-changed-body-ok T11 "$CAA" 's/if (f in DRIFT) fail("S8"/if (0) fail("S8"/'
plugin_case P1023-adr-acknowledgement-silent T11 "$CAA" 's/if (f in ACKED) NOTES = NOTES/if (0) NOTES = NOTES/'
plugin_case P1024-adr-prototype-rated T11 "$CAA" 's/if (MAT == "prototype") { NOTES/if (0) { NOTES/'
plugin_case P1025-adr-exit-zero T11 "$CAA" 's/exit (NFAIL > 0 ? 1 : 0)/exit 0/'
plugin_case P1026-adr-style-vote-ignored T11 "$CAA" 's/if (VOTE\["madr"\] + 0 > best)/if (0)/'
plugin_case P1027-adr-uncompared-counted T11 "$CAA" 's/if (NOGIT == "" \&\& f in COMPARED) {/if (NOGIT == "") {/'
plugin_case P1028-adr-madr-status-ignored T11 "$ACM" 's/if (k == "status" \&\& !A_STATUS_L)/if (0)/'
plugin_case P1029-adr-status-section-ignored T11 "$ACM" 's/if (!A_STATUS_L \&\& adr_trim(s) != "") { A_STATUS = adr_strip(s)/if (0) { A_STATUS = adr_strip(s)/'
plugin_case P1030-adr-fences-read T11 "$ACM" 's/if (A_FENCE) return/if (0) return/'
plugin_case P1031-adr-supersedes-unread T11 "$ACM" 's/if (tolower(s) ~ \/supersedes\/) {/if (0) {/'
plugin_case P1032-adr-leap-day-rejected T11 "$ACM" 's/if (m == 2 \&\& ((y % 4 == 0/if (m == 2 \&\& ((y % 4 == 9/'
plugin_case P1033-adr-adr-dir-ignored T11 "$ADS" 's/if \[ -f .adr-dir \]; then c=/if false; then c=/'
plugin_case P1034-adr-shallow-compared T11 "$CAS" 's/elif \[ "\$(git rev-parse --is-shallow-repository 2>\/dev\/null)" = true \]; then/elif false; then/'
plugin_case P1035-adr-acknowledgement-ignored T11 "$CAS" 's/if \[ -n "\$a" \]; then/if false; then/'
plugin_case P1036-adr-bad-acknowledgement-ok T11 "$CAS" 's/|| bad "--acknowledge must be ADR-N=COMMIT/|| true "--acknowledge must be ADR-N=COMMIT/'
plugin_case P1037-adr-dir-climb-ok T11 "$CAS" 's/\*\.\.\*) bad "--dir and --index are relative/*..*) true "--dir and --index are relative/'
plugin_case P1038-adr-index-not-found T11 "$CAS" 's/for c in INDEX.md index.md; do/for c in NONE.md; do/'
plugin_case P1039-adr-template-read T11 "$ADS" 's/ \&\& ! printf .%s\\n. "\$b" | grep -Eq .\^(adr-)?0+\[-_\]template.; }/; }/'
CDD="$ADRP/scripts/check-decision-drift.sh"
plugin_case P1040-drift-forbid-ok T11 "$CDD" 's/fail C1 Medium "\$loc"/true C1 Medium "$loc"/'
plugin_case P1041-drift-under-ignored T11 "$CDD" 's/if (n == 0) { print; next }/print; next/'
plugin_case P1042-drift-cap-removed T11 "$CDD" 's/head -20)/head -1000)/'
plugin_case P1043-drift-adr-folder-searched T11 "$CDD" 's/(d == "\/" || index(\$0, d) != 1)/1/'
plugin_case P1044-drift-binary-searched T11 "$CDD" 's/grep -IHnE/grep -aHnE/'
plugin_case P1045-drift-require-ok T11 "$CDD" 's/\[ -e "\$p" \] || fail C2/[ -e "$p" ] || true C2/'
plugin_case P1046-drift-inactive-enforced T11 "$CDD" 's/if \[ "\$st" != accepted \]; then/if false; then/'
plugin_case P1047-drift-missing-adr-ok T11 "$CDD" 's/if \[ "\$st" = missing \]; then fail C3/if [ "$st" = missing ]; then true C3/'
plugin_case P1048-drift-new-files-skipped T11 "$CDD" 's/git ls-files --cached --others --exclude-standard -- \./git ls-files/'
plugin_case P1049-drift-ignored-searched T11 "$CDD" 's/--others --exclude-standard/--others/'
plugin_case P1050-drift-bad-regex-ok T11 "$CDD" 's/\[ "\$r" -le 1 \] || bad/[ "$r" -le 1 ] || true/'
plugin_case P1051-drift-prototype-rated T11 "$CDD" 's/if \[ "\$MATURITY" = prototype \]; then NOTES=/if false; then NOTES=/'
plugin_case P1052-drift-exit-zero T11 "$CDD" 's/^\[ "\$NFAIL" -eq 0 \]$/true/'
plugin_case P1053-dec-table-drift T5 "$DRV" 's/(DEC-S5) | Medium |$/(DEC-S5) | Low |/'
plugin_case P1054-dec-agent-cites-missing-step T9 "$DRV" 's/(adr-check Step 2, by reading)/(adr-check Step 9, by reading)/'
plugin_case P1055-adr-write-wide-tools T4b "$ADW" 's/^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$/allowed-tools: Read, Grep, Glob, Write/'
plugin_case P1056-adr-skill-version-drift T3 "$ADK" 's/^version: 0\.1\.1$/version: 0.1.0/'
plugin_case P1057-adr-skill-unregistered T13.3 docs/framework/OWNERSHIP.md '/^| `ascent-adr` | skill | `decision-drift` |$/d'
plugin_case P1058-dec-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `DEC-C` | /d'
plugin_case P1059-dec-rule-severity-drift T11 "$ADRP/references/decision-rules.md" 's/^| DEC-S7 | Low |/| DEC-S7 | Medium |/'
plugin_case P1060-adr-write-edits-bodies T11 "$ADW" 's/Never edit an accepted ADR.s body\./Edit accepted ADRs freely./'
plugin_case P1061-dec-agent-claims-s8 T11 "$DRV" 's/Not assessed: DEC-S8 (needs git history)/DEC-S8 (by reading)/'
plugin_case P1062-dec-contract-key-renamed T11 "$ADRP/references/contract-template.yml" 's/^  acknowledged_changes: \[\]$/  acknowledged: []/'
plugin_case P1063-dec-header-severity-drift T11 "$CAS" 's/^#   DEC-S7  Low     every ADR/#   DEC-S7  Medium  every ADR/'
plugin_case P1064-dec-skill-names-missing-script T11 "$DDK" 's/scripts\/check-decision-drift\.sh" --dir/scripts\/check-drift.sh" --dir/'
plugin_case P1065-dec-unrated-route-lost T11 "$DDK" 's/Other observations (unrated)/Other observations/g'
# from the read-only trial (v0.4.23)
plugin_case P1202-adr-pipe-line-unsplit T11 "$ACM" 's/  if (index(t, "|") \&\& t !~ \/^\\|\/) {/  if (0) {/'
plugin_case P1203-adr-alternatives-votes-ascent T11 "$CAA" 's/if (h ~ \/\\|cost implications\\|\/) VOTE\["ascent"\]++/if (h ~ \/\\|alternatives considered\/) VOTE["ascent"]++/'
plugin_case P1204-adr-shared-folder-unfound T11 "$ADS" 's/NR == 1 \&\& \$1 >= 2 {/NR == 0 {/'
plugin_case P1205-adr-shared-folder-one-file T11 "$ADS" 's/NR == 1 \&\& \$1 >= 2 {/NR == 1 \&\& $1 >= 1 {/'
plugin_case P1206-adr-shared-folder-others T11 "$CAS" 's/\[ "\$SHARED" = 1 \] || isadr/isadr/'
plugin_case P1207-adr-status-date-unread T11 "$CAA" 's/if (!A_DATE_L \&\& match(A_STATUS,/if (0 \&\& match(A_STATUS,/'
# from the independent review (v0.4.23)
plugin_case P1218-adr-supersedes-any-number T11 "$ACM" 's/(adr\[- \]?|#)?\[0-9\]+\/)) {/(adr[- ]?|#)?[0-9]+\/) || match(t, \/[0-9]+\/)) {/'
plugin_case P1219-adr-supersedes-hash-unread T11 "$ACM" 's/(adr\[- \]?|#)?\[0-9\]+\/)) {/(adr[- ]?)?[0-9]+\/)) {/'
plugin_case P1220-adr-root-folder-unfound T11 "$ADS" 's/ s|^\[^\/\]\*\$|\.|;//'
plugin_case P1221-adr-folder-space-cut T11 "$ADS" 's/{ sub(\/^ \*\[0-9\]+ \/, ""); print }/{ print $2 }/'
plugin_case P1222-drift-first-existing-folder T11 "$CDD" 's/^\. "\$LIB\/adr-dir\.sh"; adr_dir$/. "$LIB\/adr-dir.sh"; DIR=${DIR:-docs\/adr}/'
plugin_case P1223-drift-shared-folder-excluded T11 "$CDD" 's/^if \[ "\$SHARED" = 1 \]; then XD=/if false; then XD=/'
plugin_case_rm P1066-adr-tests-removed T11 tests/plugins/ascent-adr
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1582-next-sentence-missing-adr T11 plugins/ascent-adr/skills/adr-check/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
mutant_group ascent-session
SESP=plugins/ascent-session
CSA="$SESP/scripts/lib/check-session.awk"
CSS="$SESP/scripts/check-session.sh"
MEA="$SESP/scripts/lib/memory-entries.awk"
SRS="$SESP/skills/session-resume/SKILL.md"
SCP="$SESP/skills/session-capture/SKILL.md"
SHO="$SESP/skills/handoff/SKILL.md"
plugin_case P1067-ses-memory-absent-ok T11 "$CSA" 's/if (!HAVEM) fail("S1"/if (0) fail("S1"/'
plugin_case P1068-ses-decisions-section-optional T11 "$CSA" 's/if (!MDEC) fail("S1"/if (0) fail("S1"/'
plugin_case P1069-ses-undated-decision-ok T11 "$CSA" 's/&& SEC != "decisions") next/) next/'
plugin_case P1070-ses-unreal-date-ok T11 "$CSA" 's/if (!realdate(d)) fail("S2"/if (0) fail("S2"/'
plugin_case P1071-ses-future-entry-ok T11 "$CSA" 's/else if (days(d) > days(TODAY)) fail("S2"/else if (0) fail("S2"/'
plugin_case P1072-ses-order-unchecked T11 "$CSA" 's/if ((SEC in LASTD) \&\& d < LASTD\[SEC\]) fail("S2"/if (0) fail("S2"/'
plugin_case P1073-ses-leap-rule-wrong T11 "$CSA" 's/if (m == 2 \&\& ((y % 4 == 0/if (m == 2 \&\& ((y % 4 == 1/'
plugin_case P1074-ses-lost-entry-ok T11 "$CSA" 's/if (LOST\[i\] != "") { split/if (0) { split/'
plugin_case P1075-ses-tracked-state-ok T11 "$CSA" 's/if (TRACKED == 1) fail("S4"/if (0) fail("S4"/'
plugin_case P1076-ses-unignored-state-ok T11 "$CSA" 's/else if (IGNORED != 1) fail("S4"/else if (0) fail("S4"/'
plugin_case P1077-ses-s4-before-records T11 "$CSA" 's/if (NOGIT == "" \&\& (HAVEM || HAVES)) {/if (NOGIT == "") {/'
plugin_case P1078-ses-state-sections-unchecked T11 "$CSA" 's/if (miss != "") fail("S5"/if (0) fail("S5"/'
plugin_case P1079-ses-placeholder-ok T11 "$CSA" 's/if (SFILL) fail("S5"/if (0) fail("S5"/'
plugin_case P1080-ses-no-capture-ok T11 "$CSA" 's/if (!SCAP) fail("S5"/if (0) fail("S5"/'
plugin_case P1081-ses-stale-state-ok T11 "$CSA" 's/> MAXAGE) fail("S5"/> MAXAGE + 999) fail("S5"/'
plugin_case P1082-ses-handoff-sections-unchecked T11 "$CSA" 's/if (miss != "") fail("S6"/if (0) fail("S6"/'
plugin_case P1083-ses-handoff-undated-ok T11 "$CSA" 's/if (!HGEN) fail("S6"/if (0) fail("S6"/'
plugin_case P1084-ses-old-handoff-ok T11 "$CSA" 's/else if (NEWEST != "" \&\& HGEN < NEWEST) fail("S6"/else if (0) fail("S6"/'
plugin_case P1085-ses-required-handoff-ignored T11 "$CSA" 's/} else if (REQH) {/} else if (0) {/'
plugin_case P1086-ses-prototype-rated T11 "$CSA" 's/if (MAT == "prototype") { NOTES/if (0) { NOTES/'
plugin_case P1087-ses-exit-zero T11 "$CSA" 's/exit (NFAIL > 0 ? 1 : 0)/exit 0/'
plugin_case P1088-ses-fences-read T11 "$CSA" 's/^FENCE { next }$/0 { next }/'
plugin_case P1089-ses-entries-trimmed-wrong T11 "$MEA" 's/^sec != "" \&\& \/\^\[-\*\] \/ {/sec != "" \&\& \/^- X\/ {/'
plugin_case P1090-ses-history-skipped T11 "$CSS" 's/^      for p in \$ps; do$/      for p in; do/'
plugin_case P1241-ses-working-copy-unchecked T11 "$CSS" 's/if git cat-file -e "HEAD:\.\/\$MEM" 2>\/dev\/null; then/if false; then/'
plugin_case P1091-ses-shallow-compared T11 "$CSS" 's/if \[ "\$(git rev-parse --is-shallow-repository 2>\/dev\/null)" = true \]; then SHALLOW=1/if false; then SHALLOW=1/'
plugin_case P1092-ses-since-ignored T11 "$CSS" 's/if \[ -n "\$SINCE" \]; then RANGE=/if false; then RANGE=/'
plugin_case P1093-ses-tracked-unchecked T11 "$CSS" 's/git ls-files --error-unmatch -- "\$ST" >\/dev\/null 2>\&1 \&\& TRACKED=1/true/'
plugin_case P1094-ses-ignore-unchecked T11 "$CSS" 's/git check-ignore -q --no-index -- "\$ST" 2>\/dev\/null \&\& IGNORED=1/IGNORED=1/'
plugin_case P1095-ses-path-climb-ok T11 "$CSS" "s/''|\/\*|\*\.\.\*) bad \"--memory/''|\/*) bad \"--memory/"
plugin_case P1096-ses-bad-age-ok T11 "$CSS" 's/\*\[!0-9\]\*) bad "--max-age/x) bad "--max-age/'
plugin_case P1097-ses-bad-since-ok T11 "$CSS" 's/\*\[!0-9a-f\]\*) bad "--since must be a commit id"/x) bad "--since must be a commit id"/'
plugin_case P1098-ses-table-drift T11 "$SRS" 's/(SES-S4) | Medium |$/(SES-S4) | Low |/'
plugin_case P1099-ses-skill-wide-tools T4b "$SCP" 's/^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$/allowed-tools: Read, Grep, Glob, Write, Edit/'
plugin_case P1100-ses-skill-version-drift T3 "$SHO" 's/^version: 0\.1\.0$/version: 0.0.9/'
plugin_case P1101-ses-skill-unregistered T13.3 docs/framework/OWNERSHIP.md '/^| `ascent-session` | skill | `handoff` |$/d'
plugin_case P1102-ses-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `SES-S` | /d'
plugin_case P1103-ses-rule-severity-drift T11 "$SESP/references/session-rules.md" 's/^| SES-S5 | Low |/| SES-S5 | Medium |/'
plugin_case P1104-ses-capture-rewrites T11 "$SCP" 's/Never change or remove a working-memory entry\./Tidy the working memory as needed./'
plugin_case P1105-ses-capture-commits T11 "$SCP" 's/Any other path is a failure of this skill\. Never commit\./Any other path is a failure of this skill./'
plugin_case P1106-ses-resume-uncited T11 "$SRS" 's/Cite or say "not recorded"\./Summarize from memory./'
plugin_case P1107-ses-resume-proposes-since T11 "$SRS" 's/Never propose `memory_since` on your own/Propose `memory_since` when convenient/'
plugin_case P1108-ses-unrated-route-lost T11 "$SRS" 's/Other observations (unrated)/Other observations/g'
plugin_case P1109-ses-cited-step-missing T11 "$SHO" 's/run session-resume Step 1: SES-S6/run session-resume Step 9: SES-S6/'
plugin_case P1110-ses-contract-key-renamed T11 "$SESP/references/contract-template.yml" 's/^  state_max_age_days: 7$/  max_age: 7/'
plugin_case P1111-ses-header-severity-drift T11 "$CSS" 's/^#   SES-S4  Medium  once/#   SES-S4  Low     once/'
plugin_case P1112-ses-skill-names-missing-script T11 "$SRS" 's/scripts\/check-session\.sh" --memory/scripts\/check-records.sh" --memory/'
plugin_case_rm P1113-ses-tests-removed T11 tests/plugins/ascent-session
mutant_group ascent-docs
DOCP=plugins/ascent-docs
CDA="$DOCP/scripts/lib/check-docs.awk"
CDS="$DOCP/scripts/check-docs.sh"
MDC="$DOCP/scripts/lib/md-common.awk"
DMK="$DOCP/scripts/lib/doc-marks.awk"
DST="$DOCP/scripts/lib/doc-set.sh"
DDA="$DOCP/scripts/lib/check-doc-drift.awk"
DDS="$DOCP/scripts/check-doc-drift.sh"
DSB="$DOCP/scripts/doc-stub.sh"
DRK="$DOCP/skills/docs-review/SKILL.md"
DDK="$DOCP/skills/doc-drift/SKILL.md"
DSK="$DOCP/skills/doc-stub/SKILL.md"
ONB="$DOCP/skills/onboard/SKILL.md"
DRA="$DOCP/agents/docs-reviewer.md"
plugin_case P1114-doc-missing-link-ok T11 "$CDA" 's/if (t != "" \&\& !(t in EXISTS)) { fail("L1"/if (0) { fail("L1"/'
plugin_case P1115-doc-climb-ok T11 "$CDA" 's/if (LCLIMB\[i\]) { fail("L1"/if (0) { fail("L1"/'
plugin_case P1116-doc-anchor-unchecked T11 "$CDA" 's/fail("L2", "Low", w, "the link "/if (0) fail("L2", "Low", w, "the link "/'
plugin_case P1117-doc-marker-age-ignored T11 "$CDA" 's/if (age > MDAYS) fail("L3"/if (0) fail("L3"/'
plugin_case P1118-doc-undated-marker-ok T11 "$CDA" 's/if (NOGIT != "" || d == "") { fail("L3"/if (NOGIT != "" || d == "") { CHK["L3"]--; continue; fail("L3"/'
plugin_case P1119-doc-lag-ignored T11 "$CDA" 's/if (lag > LAG) fail("L4"/if (0) fail("L4"/'
plugin_case P1120-doc-readme-optional T11 "$CDA" 's/if (!("README.md" in EXISTS)) fail("L5"/if (0) fail("L5"/'
plugin_case P1121-doc-persona-entry-optional T11 "$CDA" 's/if (!(md_norm(q\[2\]) in EXISTS)) fail("P1"/if (0) fail("P1"/'
plugin_case P1122-doc-orphan-ok T11 "$CDA" 's/if (!(s in DIST)) { fail("P2"/if (!(s in DIST)) { if (0) fail("P2"/'
plugin_case P1123-doc-start-section-optional T11 "$CDA" 's/if (!README_START) fail("P3"/if (0) fail("P3"/'
plugin_case P1124-doc-depth-ignored T11 "$CDA" 's/if (DIST\[s\] > CLICKS) fail("P4"/if (0) fail("P4"/'
plugin_case P1125-doc-persona-not-root T11 "$CDA" 's/ROOT\[md_norm(q\[2\])\] = q\[1\]/PROOT[md_norm(q[2])] = q[1]/'
plugin_case P1126-doc-dir-readme-unfollowed T11 "$CDA" 's/if ((t (t == "" ? "" : "\/") "README.md") in ISMD)/if (0)/'
plugin_case P1127-doc-prototype-rated T11 "$CDA" 's/if (MAT == "prototype") { NOTES/if (0) { NOTES/'
plugin_case P1128-doc-exit-zero T11 "$CDA" 's/exit (NFAIL > 0 ? 1 : 0)/exit 0/'
plugin_case P1129-doc-fences-read T11 "$MDC" 's/if (MD_FENCE) { if (substr(t, 1, 3) == MD_MARK)/if (0) { if (substr(t, 1, 3) == MD_MARK)/'
plugin_case P1130-doc-inline-code-read T11 "$MDC" 's/^function md_nocode(s) { gsub(\/`\[^`\]\*`\/, "", s); return s }$/function md_nocode(s) { return s }/'
plugin_case P1131-doc-urls-checked T11 "$MDC" 's/return (t ~ \/^\[A-Za-z\]\[A-Za-z0-9+.-\]\*:\/ ||/return (0 ||/'
plugin_case P1132-doc-refdefs-unread T11 "$MDC" 's/if (s ~ \/^ ? ? ?\\\[\[^\]\]+\\\]:\[ \\t\]\*\[^ \\t\]\/) {/if (0) {/'
plugin_case P1133-doc-duplicate-slug-wrong T11 "$MDC" 's/s = s "-" k }/s = s }/'
plugin_case P1134-doc-html-ids-ignored T11 "$MDC" 's/MD_ANCH\[doc SUBSEP s\] = 1; \$0 = substr/$0 = substr/'
plugin_case P1135-doc-dash-kept T11 "$MDC" 's/gsub(\/\\342\\200\\224|/gsub(\/\\377|/'
plugin_case P1136-doc-climb-allowed T11 "$MDC" 's/if (a\[i\] == "..") { if (k > 0 \&\& o\[k\] != "..") k--; else o\[++k\] = ".."; continue }/if (a[i] == "..") { if (k > 0) k--; continue }/'
plugin_case P1137-doc-loose-anchor-checked T11 "$CDA" 's/ || (m in MD_LOOSEDOC)) continue/) continue/'
plugin_case P1138-doc-marker-todo-missed T11 "$DMK" 's/(TODO|TBD|FIXME)/(TBD|FIXME)/'
plugin_case P1139-doc-marker-word-boundary T11 "$DMK" 's/(^|\[^A-Za-z0-9_\])(TODO|TBD|FIXME)(\[^A-Za-z0-9_\]|\$)/(TODO|TBD|FIXME)/'
plugin_case P1140-doc-adr-folders-checked T11 "$DST" 's/(^|\/)(adr|adrs|decisions|DECISIONS)\/|//'
plugin_case P1141-doc-exclude-ignored T11 "$DST" 's/x="\${x%\/}"; awk -v p="\$x"/x="${x%\/}"; continue; awk -v p="$x"/'
plugin_case P1142-doc-blame-skipped T11 "$CDS" 's/t=\$(git blame -L/t=$(true git blame -L/'
plugin_case P1143-doc-epoch-date-wrong T11 "$CDS" 's/z = int(t \/ 86400) + 719468/z = int(t \/ 86400) + 719000/'
plugin_case P1144-doc-bad-persona-ok T11 "$CDS" 's/\*) bad "--persona must be NAME=PATH"/*) true "--persona must be NAME=PATH"/'
plugin_case P1145-doc-bad-number-ok T11 "$CDS" 's/num() { case "\$1" in .*) bad "\$2 must be a whole number" ;; esac; }/num() { :; }/'
plugin_case P1146-drift-path-ok T11 "$DDA" 's/fail("R1", "Medium", w, "names "/if (0) fail("R1", "Medium", w, "names "/'
plugin_case P1147-drift-path-folder-ignored T11 "$DDA" 's/d = md_dir(p); if (!(d in EXISTS)) return/d = md_dir(p)/'
plugin_case P1148-drift-target-ok T11 "$DDA" 's/if (!(t\[i\] in TARGET)) fail("R2"/if (0) fail("R2"/'
plugin_case P1149-drift-make-midline T11 "$DDA" 's/if (start \&\& (t\[i\] == "make" || t\[i\] == "gmake"))/if ((t[i] == "make" || t[i] == "gmake"))/'
plugin_case P1150-drift-chain-unsplit T11 "$DDA" 's/if (t\[i\] == ";") { sawmake = 0; start = 1; continue }/if (t[i] == ";") { continue }/'
plugin_case P1151-drift-script-ok T11 "$DDA" 's/if (!(cmd in SCRIPT)) fail("R3"/if (0) fail("R3"/'
plugin_case P1152-drift-env-ok T11 "$DDA" 's/if (!(e in ENVN)) fail("R4"/if (0) fail("R4"/'
plugin_case P1153-drift-env-ignore-unread T11 "$DDA" 's/if (e in IGNENV || e ~/if (e ~/'
plugin_case P1154-drift-version-ok T11 "$DDA" 's/if (v != VER) fail("R5"/if (0) fail("R5"/'
plugin_case P1155-drift-node-ok T11 "$DDA" 's/if ((ge \&\& num + 0 > NODE + 0) || (!ge \&\& num + 0 != NODE + 0)) fail("R6"/if (0) fail("R6"/'
plugin_case P1156-drift-range-as-exact T11 "$DDA" 's/ge = (index(m, ">=") > 0 || substr(s, 1, 1) == "+")/ge = 0/'
plugin_case P1157-drift-python-ok T11 "$DDA" 's/|| (!ge \&\& num + 0 != pm + 0)) fail("R6"/) fail("R6"/'
plugin_case P1158-drift-other-fences-read T11 "$DDA" 's/if (MD_FENCE \&\& (MD_LANG == "" || MD_LANG ~ \/^(sh|bash|shell|console|zsh|terminal|make)\$\/)) {/if (MD_FENCE) {/'
plugin_case P1159-drift-ignore-unread T11 "$DDA" 's/if (t\[i\] in IGN) continue/if (0) continue/'
plugin_case P1160-drift-exit-zero T11 "$DDA" 's/exit (NFAIL > 0 ? 1 : 0)/exit 0/'
plugin_case P1161-drift-include-unread T11 "$DDS" 's/for g in \$inc; do \[ -f "\$g" \] \&\& MKS+=("\$g"); done/:/'
plugin_case P1162-drift-changelog-checked T11 "$DDS" 's/(CHANGELOG|CHANGES|HISTORY|RELEASE-NOTES|RELEASES)\[^\/\]\*\\.md\$/NOMATCH$/'
plugin_case P1163-drift-env-from-markdown T11 "$DDS" 's/grep -vE .\\.md\$. "\$T\/files" | while/cat "$T\/files" | while/'
plugin_case P1164-drift-code-env-unread T11 "$DDS" "s/| xargs -0 grep -ohIE '\[A-Z\]\[A-Z0-9\]\*(_\[A-Z0-9\]+)+' 2>\/dev\/null || true/| true/"
plugin_case P1165-drift-version-file-ignored T11 "$DDS" 's/^if \[ -n "\$VFILE" \]; then$/if false; then/'
plugin_case P1166-drift-engines-unread T11 "$DDS" 's/^if \[ -z "\$NODE" \] \&\& \[ -f package.json \]; then$/if false; then/'
plugin_case P1167-drift-bad-ignore-ok T11 "$DDS" 's/bad "--ignore takes a path, target or script name"/true/'
plugin_case P1168-stub-overwrites T11 "$DSB" 's/^\[ ! -e "\$OUT" \] \&\& \[ ! -L "\$OUT" \] || bad "\$OUT exists: doc-stub never overwrites a document"$/rm -f "$OUT"/'
plugin_case P1169-stub-noclobber-off T11 "$DSB" 's/( set -C; render > "\$OUT" )/( render > "$OUT" )/'
plugin_case P1170-stub-no-marker T11 "$DSB" "s/printf '<!-- doc-stub: %s %s -->\\\\n' \"\$TYPE\" \"\$TODAY\"/:/"
plugin_case P1171-stub-climb-ok T11 "$DSB" 's/case "\$OUT" in \/\*|\*\.\.\*|.*) bad "--out and --dir are relative/case "$OUT" in NONE) bad "--out and --dir are relative/'
plugin_case P1172-stub-dry-run-writes T11 "$DSB" 's/if \[ "\$DRY" = 1 \]; then echo "doc-stub: would write \$OUT"; render; exit 0; fi/:/'
plugin_case P1173-stub-entry-no-persona T11 "$DSB" 's/if \[ "\$TYPE" = entry \] \&\& \[ -z "\$PERSONA" \]; then bad/if false; then bad/'
plugin_case P1174-stub-section-dropped T11 "$DOCP/references/stubs/how-to.md" '/^## If something goes wrong$/,/^## Related$/{/^## Related$/!d;}'
plugin_case P1175-stub-bare-todo T11 "$DOCP/references/stubs/reference.md" 's/^One sentence on what this covers.*$/TODO/'
plugin_case P1176-make-doc-stub-unwired T11 make/docs.mk 's|plugins/ascent-docs/scripts/doc-stub.sh|plugins/ascent-docs/scripts/stub.sh|'
plugin_case P1177-doc-table-drift T5 "$DRA" 's/(DOC-R4) | Low |$/(DOC-R4) | Medium |/'
plugin_case P1178-doc-agent-cites-missing-step T9 "$DRA" 's/(doc-drift Step 1, by reading)/(doc-drift Step 7, by reading)/'
plugin_case P1179-doc-skill-wide-tools T4b "$DSK" 's/^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$/allowed-tools: Read, Grep, Glob, Bash/'
plugin_case P1180-doc-skill-version-drift T3 "$ONB" 's/^version: 0\.1\.1$/version: 0.1.0/'
plugin_case P1181-doc-agent-unregistered T13.3 docs/framework/OWNERSHIP.md '/^| `ascent-docs` | agent | `docs-reviewer` |$/d'
plugin_case P1182-doc-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `DOC-R` | /d'
plugin_case P1183-doc-rule-severity-drift T11 "$DOCP/references/docs-rules.md" 's/^| DOC-L1 | Medium |/| DOC-L1 | Low |/'
plugin_case P1184-doc-header-severity-drift T11 "$DDS" 's/^#   DOC-R4  Low     every/#   DOC-R4  Medium  every/'
plugin_case P1185-doc-drift-edits-code T11 "$DDK" 's/Write only after approval, and only documents:/Write after approval:/'
plugin_case P1186-doc-drift-ignores-freely T11 "$DDK" 's/Never add to `docs.ignore` on your own\./Add to `docs.ignore` when convenient./'
plugin_case P1187-doc-stub-skill-commits T11 "$DSK" 's/Never overwrite a document: the script refuses, and so do you\. Never commit\./Never overwrite a document: the script refuses, and so do you./'
plugin_case P1188-doc-agent-claims-dates T11 "$DRA" 's/Not assessed: DOC-L3, DOC-L4 (need git dates)/DOC-L3, DOC-L4 (by reading)/'
plugin_case P1189-doc-onboard-uncited T11 "$ONB" 's/\*\*From the documents, cited\.\*\*/**From general knowledge.**/'
plugin_case P1190-doc-unrated-route-lost T11 "$DRK" 's/Other observations (unrated)/Other observations/g'
plugin_case P1191-doc-contract-key-renamed T11 "$DOCP/references/contract-template.yml" 's/^  stale_marker_days: 90$/  marker_days: 90/'
plugin_case P1192-doc-skill-names-missing-script T11 "$DRK" 's/scripts\/check-docs\.sh" --path/scripts\/check-doc.sh" --path/'
# from the read-only trial (v0.4.23)
plugin_case P1208-doc-adr-file-in-set T11 "$DST" 's/\[Aa\]\[Dd\]\[Rr\]-\[0-9\]/[Aa][Dd][Rr]-NEVER[0-9]/'
plugin_case P1209-drift-aligned-description-read T11 "$DDA" 's/; sub(\/(  |\\t)\.\*\$\/, "", s)$//'
plugin_case P1210-drift-placeholder-path-read T11 "$DDA" 's/(N+|X+)/(QQ)/'
plugin_case P1211-drift-one-letter-name-read T11 "$DDA" 's/if (length(b) == 1 || b ~/if (b ~/'
plugin_case P1212-drift-example-name-read T11 "$DDA" 's/\^(foo|bar|baz|whatever|example|sample|something)\$/^NEVER$/'
plugin_case P1213-drift-version-any-document T11 "$DDA" 's/tolower(doc) ~ \/(^|\\\/)readme\\.md\$\/ \&\& //'
plugin_case P1214-drift-version-root-readme-only T11 "$DDA" 's/tolower(doc) ~ \/(^|\\\/)readme/tolower(doc) ~ \/^readme/'
plugin_case P1215-drift-brace-in-script-ends T11 "$DDS" 's/l = \$0; gsub([^;]*; if (index(l/l = $0; if (index(l/'
plugin_case P1216-drift-root-package-only T11 "$DDS" "s/grep -E '(^|\\/)package\\\\\\.json\\\$'/grep -E '^package\\\\.json\$'/"
plugin_case P1217-doc-commands-not-start T11 "$CDA" 's/|how to use|commands|development/|how to use|development/'
# from the independent review (v0.4.23)
plugin_case P1224-stub-symlink-followed T11 "$DSB" 's/in "\$(pwd -P)"\/\*) ;;/in *) ;;/'
plugin_case P1225-stub-persona-noname T11 "$DSB" 's/\[ -n "\$(slug "\$PERSONA")" \] || bad "the persona gives no folder name; pass --out"; //'
plugin_case P1226-stub-make-title-unquoted T11 make/docs.mk "s/--title '\$(call sq,\$(TITLE))'/--title \"\$(TITLE)\"/"
plugin_case P1227-md-regex-interval T11 "$MDC" 's/return s ~ \/^ ? ? ?#+\[ \\t\]\//return s ~ \/^ {0,3}#+[ \\t]\//'
plugin_case P1228-md-seven-hashes-heading T11 "$MDC" 's/ \&\& s !~ \/^ ? ? ?#######\/ }/ }/'
plugin_case P1229-md-indented-code-prose T11 "$MDC" 's/if (\$0 ~ \/^(    |\\t)\/ \&\& !blank/if (0 \&\& !blank/'
plugin_case P1230-md-list-continuation-code T11 "$MDC" 's/(MD_PBLANK \&\& !MD_LIST)/(MD_PBLANK)/'
plugin_case P1231-md-paragraph-continuation-code T11 "$MDC" 's/(MD_PBLANK \&\& !MD_LIST)/(!MD_LIST)/'
plugin_case P1232-doc-quoted-file-names T11 "$DST" 's/git -c core\.quotePath=false ls-files/git ls-files/'
plugin_case P1233-doc-history-top-level-paths T11 "$CDS" 's/ --name-only --relative / --name-only /'
plugin_case P1234-drift-make-dir-targets T11 "$DDA" 's/if (t\[i\] ~ \/^-\[Cf\]\/ || t\[i\] ~ \/^--(directory|file|makefile)\/) {/if (0) {/'
plugin_case P1235-drift-make-option-argument T11 "$DDA" 's/if (t\[i\] ~ \/^-\[IoW\]\$\/) { i++; continue }/if (0) { i++; continue }/'
plugin_case P1236-drift-prerelease-cut T11 "$DDA" 's/sub(\/\[^0-9A-Za-z\.+-\]\.\*\$\/, "", v)/sub(\/[^0-9.].*$\/, "", v)/'
plugin_case P1237-drift-version-v-stripped T11 "$DDS" "s/^plainver() { head -1 \"\\\$1\" | sed .*\$/plainver() { head -1 \"\$1\" | tr -d ' \\\\tv'; }/"
plugin_case P1238-drift-node-plus-exact T11 "$DDA" 's/ || substr(s, 1, 1) == "+")/)/'
plugin_case P1239-drift-wildcard-include-lost T11 "$DDS" 's/; gsub(\/\\)\/, "", s)  # \$(wildcard/; # $(wildcard/'
plugin_case P1240-drift-makefile-over-gnumakefile T11 "$DDS" 's/\[ -f "\$m" \] \&\& { MK="\$m"; break; }/[ -f "$m" ] \&\& MK="$m"/'
plugin_case_rm P1193-doc-tests-removed T11 tests/plugins/ascent-docs
plugin_case P1199-own-adr-unindexed T16 docs/framework/DECISIONS/INDEX.md '/ADR-026-live-security-testing-and-threat-model.md/d'
plugin_case P1200-own-adr-status-dropped T16 docs/framework/DECISIONS/ADR-027-decision-session-and-documentation-plugins.md '/^\*\*Status:\*\*/d'
plugin_case P1201-own-contract-wrong-dir T16 .ascent/contract.yml 's|^  dir: docs/framework/DECISIONS/$|  dir: docs/adr/|'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1584-next-sentence-missing-docs T11 plugins/ascent-docs/skills/docs-review/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
plugin_case P1595-signals-copy-without-its-table T11 plugins/ascent-docs/references/plugin-signals.md '/^| /d'
mutant_group ascent-governance
GOVP=plugins/ascent-governance
GCA="$GOVP/scripts/lib/contract.awk"
GCS="$GOVP/scripts/check-audit.sh"
GRA="$GOVP/scripts/lib/render.awk"
GAD="$GOVP/scripts/lib/adapters.tsv"
plugin_case P1242-contract-tab-indent-read T11 "$GCA" 's/ fail("a tab is used for indentation; use spaces")/ sub(\/\\t\/, "  ", raw)/'
plugin_case P1243-contract-comment-kept T11 "$GCA" 's/    else if (c == "#" \&\& prev ~ \/\[ \\t\]\/) break/    else if (0) break/'
plugin_case P1244-contract-hash-in-word-cut T11 "$GCA" 's/    else if (c == "#" \&\& prev ~ \/\[ \\t\]\/) break/    else if (c == "#") break/'
plugin_case P1245-contract-hash-in-quotes-cut T11 "$GCA" 's/    if (q != "") { if (c == q) q = "" }$/    if (0) { }/'
plugin_case P1246-contract-quotes-kept T11 "$GCA" 's/ a == z) s = substr(s, 2, length(s) - 2)/ a == z) s = s/'
plugin_case P1247-contract-inline-list-one-value T11 "$GCA" 's/^  if (v ~ \/^\\\[\.\*\\\]\$\/) {$/  if (0) {/'
plugin_case P1248-contract-inline-map-one-value T11 "$GCA" 's/^  if (v ~ \/^\\{\.\*\\}\$\/) {$/  if (0) {/'
plugin_case P1249-contract-null-a-value T11 "$GCA" 's/if (v == "" || v == "~" || v == "null") return/if (v == "") return/'
plugin_case P1250-contract-list-split-lines-lost T11 "$GCA" 's/^  if ((v ~ .*) { open = full; openv = v; openline = NR; closer = .*; return }$/  if (0) { }/'
plugin_case P1251-contract-crlf-kept T11 "$GCA" 's/^  sub(\/\\r\$\/, "")$/  sub(\/\\f$\/, "")/'
plugin_case P1252-contract-item-index-stuck T11 "$GCA" 's/(CNT\[parent\] + 0) "\]"; CNT\[parent\]++/(CNT[parent] + 0) "]"/'
plugin_case P1253-contract-map-item-keys-flat T11 "$GCA" 's/      depth++; IND\[depth\] = ind; PATH\[depth\] = item; KIND\[depth\] = "item"$/      depth = depth/'
plugin_case P1254-contract-sibling-under-last-key T11 "$GCA" 's/  while (depth > 0 \&\& IND\[depth\] >= ind) depth--/  while (depth > 0 \&\& IND[depth] > ind) depth--/'
plugin_case P1255-contract-block-scalar-read T11 "$GCA" 's/  if (v ~ \/^\[|>\]\[+-\]?\$\/) { skip = ind; return }/  if (0) { }/'
plugin_case P1256-contract-list-at-key-indent-lost T11 "$GCA" 's/ || (IND\[depth\] == ind \&\& KIND\[depth\] != "key"))) depth--/ || IND[depth] == ind)) depth--/'
plugin_case P1257-contract-colon-in-value-split T11 "$GCA" 's/^  k = match(s, \/:(\[ \\t\]|\$)\/)$/  k = match(s, \/:[^:]*$\/)/'
plugin_case P1258-gov-s1-floor-off-ladder-ok T11 "$GCS" 's/\*) S1=1; item setup GOV-S1 fail High "\$CNAME" "governance.floors has a floor for/*) : "governance.floors has a floor for/'
plugin_case P1259-gov-s1-any-age T11 "$GCS" "s/grep -Eq '^\\[1-9\\]\\[0-9\\]\\*\\$'; then printf 'review/grep -Eq '.'; then printf 'review/"
plugin_case P1260-gov-s1-zero-age T11 "$GCS" "s/grep -Eq '^\\[1-9\\]\\[0-9\\]\\*\\$'; then printf 'review/grep -Eq '^[0-9][0-9]*\$'; then printf 'review/"
plugin_case P1261-gov-s1-any-check-name T11 "$GCS" "s/grep -Eq '^\\[a-z0-9\\]\\[a-z0-9-\\]\\*\\/\\[a-z0-9\\]\\[a-z0-9-\\]\\*\\$'; then printf 'check/grep -Eq '.'; then printf 'check/"
plugin_case P1262-gov-s1-unreadable-as-absent T11 "$GCS" 's/^if \[ -n "\$UNREADABLE" \]; then$/if false; then/'
plugin_case P1263-gov-s1-not-high T11 "$GCS" 's/item setup GOV-S1 fail High "\$CNAME" "governance.floors.\$e.reviews/item setup GOV-S1 fail Low "$CNAME" "governance.floors.$e.reviews/'
plugin_case P1264-gov-s2-no-adapter-runs T11 "$GCS" 's/^  return \$found$/  return 0/'
plugin_case P1265-gov-s2-usage-is-failure T11 "$GCS" 's/^    1) item check GOV-L1 fail High/    1|2) item check GOV-L1 fail High/'
plugin_case P1266-gov-l1-failure-passes T11 "$GCS" 's/^    1) item check GOV-L1 fail High "\$c" "\$c failed: /    1) item check GOV-L1 pass - "$c" "$c failed: /'
plugin_case P1267-gov-l1-not-high T11 "$GCS" 's/^    1) item check GOV-L1 fail High/    1) item check GOV-L1 fail Medium/'
plugin_case P1268-gov-l1-findings-not-cited T11 "$GCS" "s/^  awk '\/^FAIL \/ { sub(/  awk '\/^NEVER \/ { sub(/"
plugin_case P1269-gov-l2-missing-plugin-fails T11 "$GCS" 's/item check GOV-L2 unmeasured Low "\$c" "\$c is unmeasured: \$plugin is not available here"/item check GOV-L1 fail High "$c" "$c is unmeasured: $plugin is not available here"/'
plugin_case P1270-gov-plugins-dir-not-exclusive T11 "$GCS" 's/ \[ -f "\$p" \] \&\& { printf '"'"'%s'"'"' "\$p"; return 0; }; return 1; fi$/ [ -f "$p" ] \&\& { printf '"'"'%s'"'"' "$p"; return 0; }; fi/'
plugin_case P1271-gov-verdict-unmeasured-is-go T11 "$GRA" 's/(cond + unmeasured > 0 ? /(cond > 0 ? /'
plugin_case P1272-gov-verdict-high-exits-0 T11 "$GCS" 's/ \&\& \$4 == "High" { f = 1 } END { exit !f }/ \&\& $4 == "Never" { f = 1 } END { exit !f }/'
plugin_case P1273-gov-verdict-medium-exits-1 T11 "$GCS" 's/(\$3 == "fail" || \$3 == "due") \&\& \$4 == "High" { f = 1 }/($3 == "fail" || $3 == "due") { f = 1 }/'
plugin_case P1274-gov-verdict-medium-is-nogo T11 "$GRA" 's/{ if (\$4 == "High") high++; else cond++ }/{ high++ }/'
plugin_case P1275-gov-rung-inherits-nothing T11 "$GCS" 's/^RUNGS=""; for e in \$LADDER; do RUNGS="\$RUNGS\$e "; \[ "\$e" = "\$ENVNAME" \] \&\& break; done/RUNGS="$ENVNAME "/'
plugin_case P1276-gov-rung-takes-higher-floors T11 "$GCS" 's/RUNGS="\$RUNGS\$e "; \[ "\$e" = "\$ENVNAME" \] \&\& break; done/RUNGS="$RUNGS$e "; done/'
plugin_case P1277-gov-skip-ignored T11 "$GCS" 's/^  case "\$SKIP" in \*" \$c "\*)/  case "$SKIP" in *" never "*)/'
plugin_case P1278-gov-gate-failure-passes T11 "$GCS" 's/^    else item check GOV-L1 fail High "\$c" "\$c failed: \$cmd exited \$rc"; fi/    else item check GOV-L1 pass - "$c" "$c failed: $cmd exited $rc"; fi/'
plugin_case P1279-gov-gate-absent-fails T11 "$GCS" 's/item check GOV-L2 unmeasured Low "\$c" "\$c is unmeasured: the contract has no delivery.gate"/item check GOV-L1 fail High "$c" "$c is unmeasured: the contract has no delivery.gate"/'
plugin_case P1280-gov-gate-not-run T11 "$GCS" 's/^    ASCENT_GOVERNANCE_GATE=1 sh -c "\$cmd" > "\$T\/run.out" 2>\&1 <\/dev\/null || rc=\$?/    : "$cmd"/'
plugin_case P1281-gov-defaults-ux-without-ui T11 "$GCS" "s/^    ascent-ux\\/\\*|ux-review) has_file /    ascent-ux\\/*|ux-review) true || has_file /"
plugin_case P1282-gov-defaults-ops-without-iac T11 "$GCS" 's/^    ascent-ops\/\*|ops-review|architecture-review) chas architecture\. || /    ascent-ops\/*|ops-review|architecture-review) true || /'
plugin_case P1283-gov-defaults-ui-not-seen T11 "$GCS" "s/^    ascent-ux\\/\\*|ux-review) has_file /    ascent-ux\\/*|ux-review) false \\&\\& has_file /"
# The maturity, the ladder and its environments, this repository's own evidence and the
# section's shape: split from ascent-governance so each macOS job keeps inside 25 minutes
mutant_group ascent-governance-ladder
plugin_case P1284-gov-maturity-last-wins T11 "$GCS" 's/\[ "\$r" -gt 0 \] \&\& \[ "\$r" -lt "\$best" \] \&\& {/[ "$r" -gt 0 ] \&\& {/'
plugin_case P1285-gov-maturity-own-target-ignored T11 "$GCS" 's/^MATURITY=\$(cget governance.maturity_target); /MATURITY=""; /'
plugin_case P1286-gov-prototype-full-floor T11 "$GCS" 's/^    \[ "\$MATURITY" = prototype \] \&\& continue$/    :/'
plugin_case P1287-gov-no-contract-not-prototype T11 "$GCS" 's/^  MATURITY=prototype$/  MATURITY=enterprise/'
plugin_case P1288-gov-default-env-not-first T11 "$GCS" 's/^\[ -n "\$ENVNAME" \] || ENVNAME="\${LADDER%% \*}"/[ -n "$ENVNAME" ] || ENVNAME=prod/'
plugin_case P1289-gov-unknown-env-accepted T11 "$GCS" 's/^\[ "\$ONLADDER" -eq 1 \] || bad "unknown environment /true || bad "unknown environment /'
plugin_case P1290-gov-two-rung-ladder-no-beta-floor T11 "$GCS" 's/^      \[ "\$NRUNGS" -le 2 \] \&\& default_tier B "\$e" >> "\$T\/floor.tsv"$/      :/'
plugin_case P1291-gov-floors-without-ladder-order T11 "$GCS" 's/^    case " \$RUNGS" in \*" \$e "\*) ;; \*) continue ;; esac$/    :/'
plugin_case P1292-gov-impossible-date-accepted T11 "$GCS" 's/  exit !(m >= 1 \&\& m <= 12 \&\& d >= 1 \&\& d <= n) }/  exit !(m >= 1 \&\& m <= 12 \&\& d >= 1 \&\& d <= 31) }/'
plugin_case P1293-gov-missing-contract-file-ignored T11 "$GCS" 's/^  \[ -f "\$CONTRACT" \] || bad "--contract \$CONTRACT not found"$/  [ -f "$CONTRACT" ] || CONTRACT=""/'
plugin_case P1294-gov-adapter-row-dropped T11 "$GAD" '/^ascent-docs\/check-docs	/d'
plugin_case P1318-gov-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `GOV-S` | /d'
plugin_case_rm P1295-gov-tests-removed T11 tests/plugins/ascent-governance
# T17: this repository's own release evidence (ADR-028)
plugin_case P1606-own-floor-check-has-no-adapter T17 .ascent/contract.yml 's|checks: \[ascent-adr/check-adrs\]|checks: [ascent-adr/check-adr]|'
plugin_case P1607-own-adr-status-dropped-at-release T17 docs/framework/DECISIONS/ADR-027-decision-session-and-documentation-plugins.md '/^\*\*Status:\*\*/d'
plugin_case P1608-own-floor-for-an-unknown-environment T17 .ascent/contract.yml 's/^    release:$/    staging:/'
plugin_case_rm P1609-own-release-checker-unavailable T17 plugins/ascent-adr/scripts/check-adrs.sh
# v0.4.24 review: the section's shape, the ladder, exit codes, what a checker left out
plugin_case P1614-gov-section-shape-unchecked T11 "$GCS" 's/    if (why != "") printf "%s\\t%s %s\\n", \$3, k, why }/    if (0) printf "%s\\t%s %s\\n", $3, k, why }/'
plugin_case P1615-gov-sign-off-any-word T11 "$GCS" 's/{ if (v != "true" \&\& v != "false") why = /{ if (0) why = /'
plugin_case P1616-gov-maturity-any-word T11 "$GCS" 's/{ if (v != "prototype" \&\& v != "standard" \&\& v != "enterprise") why = /{ if (0) why = /'
plugin_case P1617-gov-records-outside-repo T11 "$GCS" 's/k == "governance.launch_dir") { if (v ~/k == "governance.launch_dir") { if (0 \&\& v ~/'
plugin_case P1618-gov-scalar-where-a-list-is T11 "$GCS" 's/) why = "is " q v q "; it is a list/) x = "is " q v q "; it is a list/'
plugin_case P1619-gov-reviews-not-a-map T11 "$GCS" 's/) why = "is not a map of each review/) x = "is not a map of each review/'
plugin_case P1620-gov-env-name-unchecked T11 "$GCS" 's/^if \[ -n "\$BADENV" \]; then$/if false; then/'
plugin_case P1621-gov-env-two-names-accepted T11 "$GCS" 's/^ONLADDER=0; for e in \$LADDER; do .*$/ONLADDER=0; case " $LADDER" in *" $ENVNAME "*) ONLADDER=1 ;; esac/'
plugin_case P1622-gov-one-rung-local-only T11 "$GCS" 's/\[ "\$NRUNGS" -le 2 \] \&\& default_tier B/[ "$NRUNGS" -eq 2 ] \&\& default_tier B/'
plugin_case P1623-gov-crash-is-a-usage-error T11 "$GCS" 's/^    2) item check GOV-S2 fail Medium "\$c" "\$c could not be run/    *) item check GOV-S2 fail Medium "$c" "$c could not be run/'
plugin_case P1624-gov-nothing-checked-passes T11 "$GCS" 's/^       if \[ -n "\$na" \] \&\& ! grep -q .*; then item check GOV-L2/       if false; then item check GOV-L2/'
plugin_case P1625-gov-left-out-rules-not-named T11 "$GCS" 's/^       elif \[ -n "\$na" \]; then item check GOV-L1 pass/       elif false; then item check GOV-L1 pass/'
plugin_case P1626-gov-gate-runs-inside-itself T11 "$GCS" 's/^    \[ -z "\${ASCENT_GOVERNANCE_GATE:-}" \] || {/    true || {/'
plugin_case P1627-gov-gate-not-marked T11 "$GCS" 's/    ASCENT_GOVERNANCE_GATE=1 sh -c "\$cmd"/    sh -c "$cmd"/'
plugin_case P1628-gov-cache-version-as-text T11 "$GCS" 's/sort -t\. -k1,1n -k2,2n -k3,3n/sort/'
plugin_case P1629-contract-bom-in-first-key T11 "$GCA" 's/^  if (NR == 1 \&\& index(\$0, /  if (0 \&\& index($0, /'
plugin_case P1630-contract-map-never-continued T11 "$GCA" 's/closer = (v ~ \/^\\\[\/) ? "\]" : "}"/closer = "]"/'
plugin_case P1631-contract-nested-map-is-text T11 "$GCA" 's/if (k > 1) value(path "\." unquote/if (k > 1) emit(path "." unquote/'
plugin_case P1632-contract-map-in-list-is-text T11 "$GCA" 's/for (i = 1; i <= n; i++) value(path "\[" (i - 1) "\]", P\[i\])/for (i = 1; i <= n; i++) emit(path "[" (i - 1) "]", P[i])/'

mutant_group ascent-governance-adapters
GAA="$GOVP/scripts/lib/adapt.awk"
plugin_case P1319-adapt-env-no-git-dropped T11 "$GAD" '/^ascent-security\/check-env[[:space:]]--no-git[[:space:]]/d'
plugin_case P1320-adapt-deps-waived-dropped T11 "$GAD" '/^ascent-security\/check-dependencies[[:space:]]--waived[[:space:]]/d'
plugin_case P1321-adapt-deps-pinning-other-key T11 "$GAD" 's/ops\.version_pinning/security.dependencies.pinning/'
plugin_case P1322-adapt-threat-endpoints-dropped T11 "$GAD" '/^ascent-security\/check-threat-model[[:space:]]--endpoint[[:space:]]/d'
plugin_case P1323-adapt-threat-model-path-fixed T11 "$GAD" 's/security\.threat_model\.path/-/'
plugin_case P1324-adapt-ux-flows-dropped T11 "$GAD" '/^ascent-ux\/check-flow-integrity[[:space:]]--flow[[:space:]]/d'
plugin_case P1325-adapt-docs-personas-dropped T11 "$GAD" '/^ascent-docs\/check-docs[[:space:]]--persona[[:space:]]/d'
plugin_case P1326-adapt-docs-option-renamed T11 "$GAD" 's/--marker-days/--stale-days/'
plugin_case P1327-adapt-acceptance-acceptors-dropped T11 "$GAD" '/^ascent-delivery\/check-acceptance[[:space:]]--acceptor[[:space:]]/d'
plugin_case P1328-adapt-drills-alerts-dropped T11 "$GAD" '/^ascent-ops\/check-drills[[:space:]]--alert[[:space:]]/d'
plugin_case P1329-adapt-drills-rto-from-ops T11 "$GAD" 's/architecture\.quality_targets\.rto/ops.rto/'
plugin_case P1330-adapt-evidence-reports-dropped T11 "$GAD" '/^ascent-quality\/check-test-evidence[[:space:]]--report[[:space:]]/d'
plugin_case P1331-adapt-adrs-acknowledge-dropped T11 "$GAD" '/^ascent-adr\/check-adrs[[:space:]]--acknowledge[[:space:]]/d'
plugin_case P1332-adapt-adrs-acknowledge-colon T11 "$GAD" 's/{adr}={commit}/{adr}:{commit}/'
T11_FORCE=ascent-governance plugin_case P1333-adapt-checker-option-renamed T11 plugins/ascent-docs/scripts/check-docs.sh 's/^\(# Usage: .*\)\[--marker-days N\]/\1[--stale-days N]/'
plugin_case P1334-adapt-empty-scalar-given T11 "$GAA" 's/if (kind == "scalar") { v = field(key); if (v != "") {/if (kind == "scalar") { v = field(key); if (1) {/'
plugin_case P1335-adapt-nested-list-first-index-only T11 "$GAA" 's/^function star(k) { gsub(/function star(k) { sub(/'
plugin_case P1336-adapt-csv-joined-by-space T11 "$GAA" 's/s = s (i > 1 ? "," : "") V\[i\]/s = s (i > 1 ? " " : "") V[i]/'
plugin_case P1337-adapt-empty-list-field-no-dash T11 "$GAA" 's/out = out (v == "" ? "-" : v)/out = out v/'
plugin_case P1338-adapt-flag-text-always T11 "$GAA" 's/if (v == "true" || v == "yes") out = out substr(tok, q + 1)/out = out substr(tok, q + 1)/'
plugin_case P1339-adapt-missing-field-not-reported T11 "$GAA" 's/if (MISSING != "") print "E\\t" item/if (0) print "E\\t" item/'
plugin_case P1340-adapt-missing-list-field-accepted T11 "$GAA" 's/if (v == "" \&\& MISSING == "") MISSING = k$/if (0) MISSING = k/'
plugin_case P1341-adapt-first-entry-only T11 "$GAA" 's/^    for (m = 0; ; m++) {$/    for (m = 0; m < 1; m++) {/'
plugin_case P1342-adapt-const-value-dropped T11 "$GAA" 's/{ print "F\\t" opt; if (last != "") print "F\\t" last }/{ print "F\\t" opt }/'
plugin_case P1343-adapt-no-git-always T11 "$GAA" 's/if (nogit == 1) print "F\\t" opt/print "F\\t" opt/'
plugin_case P1344-adapt-no-git-never T11 "$GAA" 's/if (nogit == 1) print "F\\t" opt/if (nogit == 2) print "F\\t" opt/'
plugin_case P1345-adapt-input-dash-as-option T11 "$GAA" 's/^function pos(v) { if (substr(v, 1, 1) == "-") v = "\.\/" v; /function pos(v) { /'
plugin_case P1346-adapt-input-default-lost T11 "$GAA" 's/pos(v == "" ? last : v) }$/pos(v) }/'
plugin_case P1347-adapt-glob-given-whole T11 "$GAA" 's/      if (match(v, \/\[\*?\\\[\]\/)) {/      if (0) {/'
plugin_case P1348-adapt-glob-folder-partial-name T11 "$GAA" 's/sub(\/\[^\\\/\]\*\$\/, "", v); //'
plugin_case P1349-adapt-glob-folders-repeated T11 "$GAA" 's/if (!(v in DONE)) { DONE\[v\] = 1; pos(v); k++ }/{ pos(v); k++ }/'
plugin_case P1350-adapt-pages-unset-not-said T11 "$GAA" 's/^    if (k == 0) { sub/    if (0) { sub/'
plugin_case P1351-adapt-records-folder-fixed T11 "$GAA" 's/print "D\\t" (v == "" ? last : v) }/print "D\\t" last }/'
plugin_case P1352-adapt-today-not-the-runs T11 "$GCS" 's/-v today="\$TODAY" -v nogit=/-v today="$(date +%Y-%m-%d)" -v nogit=/'
plugin_case P1353-adapt-absent-files-given T11 "$GCS" 's/X) for f in \$b; do \[ -f "\$f" \] \&\& ARGS+=/X) for f in $b; do ARGS+=/'
plugin_case P1354-adapt-inputs-not-given T11 "$GCS" 's/^  bash "\$path" \${ARGS\[@\]+"\${ARGS\[@\]}"} \${INPUTS\[@\]+"\${INPUTS\[@\]}"} > /  bash "$path" ${ARGS[@]+"${ARGS[@]}"} > /'
plugin_case P1355-each-records-before-launch-run T11 "$GCS" 's/\[ -n "\$since" \] \&\& \[ "\${b:0:10}" \\< "\$since" \] \&\& continue/:/'
plugin_case P1356-each-same-day-record-skipped T11 "$GCS" 's/\[ "\${b:0:10}" \\< "\$since" \] \&\& continue/[ ! "${b:0:10}" \\> "$since" ] \&\& continue/'
plugin_case P1357-each-any-environments-launch T11 "$GCS" 's/^for f in "\$LAUNCH_DIR"\/\[0-9\].*-"\$ENVNAME"\.md; do$/for f in "$LAUNCH_DIR"\/*.md; do/'
plugin_case P1358-each-unsigned-launch-counts T11 "$GCS" 's/^  \[ "\$s" != - \] \&\& { \[ "\$v" = GO \]/  { [ "$v" = GO ]/'
plugin_case P1359-each-nogo-launch-counts T11 "$GCS" 's/ \&\& { \[ "\$v" = GO \] || \[ "\$v" = "GO WITH CONDITIONS" \]; } \&\& realdate/ \&\& realdate/'
plugin_case P1360-each-future-launch-counts T11 "$GCS" 's/ \&\& realdate "\$d" \&\& \[ ! "\$d" \\> "\$TODAY" \] \&\& SIGNED_ON=/ \&\& realdate "$d" \&\& SIGNED_ON=/'
plugin_case P1361-each-unreal-launch-date-counts T11 "$GCS" 's/ \&\& realdate "\$d" \&\& \[ ! "\$d" \\> "\$TODAY" \] \&\& SIGNED_ON=/ \&\& [ ! "$d" \\> "$TODAY" ] \&\& SIGNED_ON=/'
plugin_case P1362-each-older-launch-wins T11 "$GCS" 's/if signed "\$f" \&\& \[ "\$SIGNED_ON" \\> "\$best" \]; then best=/if signed "$f" \&\& [ -z "$best" ]; then best=/'
plugin_case P1363-each-no-records-fails T11 "$GCS" 's/^  if \[ "\$all" -eq 0 \]; then item check GOV-L2 unmeasured Low /  if [ "$all" -eq 0 ]; then item check GOV-L1 fail High /'
plugin_case P1364-each-none-since-unmeasured T11 "$GCS" 's/^  elif \[ "\$n" -eq 0 \]; then item check GOV-L1 na - /  elif [ "$n" -eq 0 ]; then item check GOV-L2 unmeasured Low /'
plugin_case P1365-each-record-failure-lost T11 "$GCS" 's/^      1) \[ -n "\$failed" \] || failed="\$f: \$(fails_of "\$T\/run.out")" ;;$/      1) : ;;/'
plugin_case P1366-each-usage-error-a-failure T11 "$GCS" 's/^      2) \[ -n "\$unread" \] || unread="\$f: /      2) [ -n "$failed" ] || failed="$f: /'
plugin_case P1367-each-undated-files-run T11 "$GCS" 's/^  for f in "\$EACH_DIR"\/\[0-9\]\[0-9\]\[0-9\]\[0-9\]-\[0-9\]\[0-9\]-\[0-9\]\[0-9\]-\*\.md; do$/  for f in "$EACH_DIR"\/*.md; do/'
plugin_case P1368-gov-l1-first-findings-cited T11 "$GCS" 's/R\[n\] = (\$2 == "High" ? 1 : (\$2 == "Medium" ? 2 : 3)) }/R[n] = 1 }/'
plugin_case P1369-gov-l1-more-findings-not-counted T11 "$GCS" 's/if (n > 3) printf " (and %d more)", n - 3 }/}/'
plugin_case P1610-adapt-pages-unset-is-an-error T11 "$GAA" 's/print "U\\t" key }/print "E\\t" key }/'
plugin_case P1611-gov-pages-unset-still-run T11 "$GCS" 's/^      U) UNSET="\$a" ;;$/      U) : ;;/'
plugin_case P1612-each-usage-error-drops-with-failure T11 "$GCS" 's/^      2) \[ -n "\$unread" \] || unread=/      2) [ -n "$failed$unread" ] || unread=/'
plugin_case P1633-each-failure-hidden-by-usage-error T11 "$GCS" 's/^    \[ -z "\$failed" \] || item check GOV-L1/    [ -n "$unread" ] || item check GOV-L1/'
plugin_case P1634-each-crash-is-a-usage-error T11 "$GCS" 's/^      \*) \[ -n "\$failed" \] || failed="\$f: its checker exited/      *) [ -n "$unread" ] || unread="$f: its checker exited/'
mutant_group ascent-governance-waivers
GAU="$GOVP/scripts/lib/audit.awk"
plugin_case P1370-w1-expired-waiver-in-force T11 "$GAU" 's/      if (left < 0) { state = "expired"; /      if (left < -99999) { state = "expired"; /'
plugin_case P1371-w1-due-today-expired T11 "$GAU" 's/      if (left < 0) { state = "expired"; /      if (left <= 0) { state = "expired"; /'
plugin_case P1372-w1-not-high T11 "$GAU" 's/fail(1, "High", src, name " expired "/fail(1, "Medium", src, name " expired "/'
plugin_case P1373-w2-day-14-missed T11 "$GAU" 's/        if (left <= 14) fail(2, /        if (left < 14) fail(2, /'
plugin_case P1374-w2-day-15-flagged T11 "$GAU" 's/        if (left <= 14) fail(2, /        if (left <= 15) fail(2, /'
plugin_case P1375-w2-never-due T11 "$GAU" 's/        if (left <= 14) fail(2, /        if (0) fail(2, /'
plugin_case P1376-w3-undated-not-named T11 "$GAU" 's/    if (rb == "") fail(3, /    if (0) fail(3, /'
plugin_case P1377-w3-unreal-date-counted T11 "$GAU" 's/    else if (!realdate(rb)) { EXPIRED\[w\] = 1; fail(3, /    else if (0) { EXPIRED[w] = 1; fail(3, /'
plugin_case P1378-w3-any-day-of-month T11 "$GAU" 's/  return m >= 1 \&\& m <= 12 \&\& d >= 1 \&\& d <= n$/  return m >= 1 \&\& m <= 12 \&\& d >= 1 \&\& d <= 31/'
plugin_case P1379-w3-no-leap-years T11 "$GAU" 's/((y % 4 == 0 \&\& y % 100 != 0) || y % 400 == 0 ? 29 : 28)/(28)/'
plugin_case P1380-w3-days-left-off-by-one T11 "$GAU" 's/      left = days(rb) - days(today)$/      left = days(rb) - days(today) - 1/'
plugin_case P1381-w4-any-id T11 "$GAU" 's/    else if (id !~ \/^ADR-\[0-9\]+\$\/) fail(4, /    else if (0) fail(4, /'
plugin_case P1382-w4-missing-id-not-named T11 "$GAU" 's/    if (id == "") fail(4, /    if (0) fail(4, /'
plugin_case P1383-w4-missing-adr-not-named T11 "$GAU" 's/      if (!((dir, num) in ADR)) fail(4, /      if (0) fail(4, /'
plugin_case P1384-w4-unaccepted-adr-ok T11 "$GAU" 's/      else if (ADR\[dir, num\] != 1) fail(4, /      else if (0) fail(4, /'
plugin_case P1385-w4-not-medium T11 "$GAU" 's/fail(4, "Medium", ADRFILE\[dir, num\]/fail(4, "High", ADRFILE[dir, num]/'
plugin_case P1386-w4-section-folder-ignored T11 "$GAU" 's/^    dir = ((sec "\.adr_dir") in C \&\& C\[sec "\.adr_dir"\] != "") ? C\[sec "\.adr_dir"\] : fallback$/    dir = fallback/'
plugin_case P1387-w4-no-folder-fails T11 "$GAU" 's/    else if (dir == "") NOADR++/    else if (0) NOADR++/'
plugin_case P1388-w4-leading-zeros-differ T11 "$GAU" 's/      num = substr(id, 5) + 0$/      num = substr(id, 5)/'
plugin_case P1389-waivers-one-section-only T11 "$GAU" 's/  if (\$1 ~ \/^\[A-Za-z_-\]+\\\.waivers\\\[\[0-9\]+\\\]\/) {/  if ($1 ~ \/^security\\.waivers\\[[0-9]+\\]\/) {/'
plugin_case P1390-waivers-first-only T11 "$GAU" 's/^  for (i = 1; i <= NW; i++) {$/  for (i = 1; i <= 1; i++) {/'
plugin_case P1391-waivers-fields-as-waivers T11 "$GAU" 's/    if (!(w in SEEN)) { SEEN\[w\] = 1; NW++; /    if (1) { SEEN[w] = 1; NW++; /'
plugin_case P1392-ack-not-listed T11 "$GAU" 's/^  for (i = 1; i <= NA; i++) {$/  for (i = 1; i <= 0; i++) {/'
plugin_case P1393-ack-read-as-waiver T11 "$GAU" 's/  } else if (\$1 ~ \/^decisions\\\.acknowledged_changes\\\[\[0-9\]+\\\]\\\.\/) {/  } else if (0) {/'
plugin_case P1394-adr-status-heading-unread T11 "$GCS" 's/if (l == "") pend = 1; else judge(l) } }/if (l == "") done = 1; else judge(l) } }/'
plugin_case P1395-adr-accepted-anywhere-in-status T11 "$GCS" 's/acc = (v ~ \/^accepted\/) ? 1 : 0; done = 1 }/acc = (v ~ \/accepted\/) ? 1 : 0; done = 1 }/'
plugin_case P1396-adr-numbered-files-unread T11 "$GCS" 's/ else if (b !~ \/^\[0-9\]\/) exit$/ else exit/'
plugin_case P1397-adr-default-folders-unread T11 "$GCS" 's/; \[ -n "\$ADR_FALLBACK" \] || ADR_FALLBACK=\$(adr_dir || true)$//'
plugin_case P1398-waiver-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `GOV-W` | /d'
plugin_case P1643-waiver-no-skips-passes T11 "$GAU" 's/^    if (skips == "") fail(4,/    if (0) fail(4,/'

mutant_group ascent-governance-reviews-1
GLR="$GOVP/scripts/lib/log-rows.awk"
plugin_case P1399-r1-launch-not-high T11 "$GAU" 's/  sev = launch ? "High" : "Medium"; st = "due"/  sev = "Medium"; st = "due"/'
plugin_case P1400-r1-always-high T11 "$GAU" 's/  sev = launch ? "High" : "Medium"; st = "due"/  sev = "High"; st = "due"/'
plugin_case P1401-r1-day-31-current T11 "$GAU" 's/    else if (age > max) rfail(1, /    else if (age > max + 1) rfail(1, /'
plugin_case P1402-r1-day-30-due T11 "$GAU" 's/    else if (age > max) rfail(1, /    else if (age >= max) rfail(1, /'
plugin_case P1403-r1-missing-row-not-named T11 "$GAU" 's/^    if (!(name in NEWEST)) {$/    if (0) {/'
plugin_case P1404-r1-oldest-row-wins T11 "$GAU" 's/  if (!(name in NEWEST) || d >= RDATE\[name\]) {/  if (!(name in NEWEST) || d <= RDATE[name]) {/'
plugin_case P1405-r1-first-row-of-a-day-wins T11 "$GAU" 's/  if (!(name in NEWEST) || d >= RDATE\[name\]) {/  if (!(name in NEWEST) || d > RDATE[name]) {/'
plugin_case P1406-r1-last-row-in-file-wins T11 "$GAU" 's/  if (!(name in NEWEST) || d >= RDATE\[name\]) {/  if (1) {/'
plugin_case P1407-r1-lowest-rung-age-wins T11 "$GAU" 's/  else if (\$3 + 0 < MAXAGE\[\$2\]) MAXAGE\[\$2\] = \$3 + 0/  else if (0) MAXAGE[$2] = $3 + 0/'
plugin_case P1408-r1-highest-rung-age-wins T11 "$GAU" 's/  else if (\$3 + 0 < MAXAGE\[\$2\]) MAXAGE\[\$2\] = \$3 + 0/  else if (1) MAXAGE[$2] = $3 + 0/'
plugin_case P1409-r2-open-high-ignored T11 "$GAU" 's/    else if (r != "") rfail(2, "fail", "High", /    else if (0) rfail(2, "fail", "High", /'
plugin_case P1410-r2-open-high-not-high T11 "$GAU" 's/    else if (r != "") rfail(2, "fail", "High", /    else if (r != "") rfail(2, "fail", "Medium", /'
plugin_case P1411-r2-waivers-unread T11 "$GAU" 's/      if (waived(T\[k\])) covered = /      if (0) covered = /'
plugin_case P1412-r2-expired-waiver-covers T11 "$GAU" '/^    if (EXPIRED\[w\]) continue$/d'
plugin_case P1413-r2-waiver-matches-part-of-an-id T11 "$GAU" 's/      if (a !~ \/\[A-Za-z0-9_-\]\/ \&\& b !~ \/\[A-Za-z0-9_-\]\/) return 1/      if (1) return 1/'
plugin_case P1414-r2-waiver-left-edge-unchecked T11 "$GAU" 's/      if (a !~ \/\[A-Za-z0-9_-\]\/ \&\& b !~ /      if (b !~ /'
plugin_case P1415-r2-waiver-right-edge-unchecked T11 "$GAU" 's/ \&\& b !~ \/\[A-Za-z0-9_-\]\/) return 1/) return 1/'
plugin_case P1416-r2-weak-rating-ok T11 "$GAU" 's/    else if (RRATING\[name\] == "weak") rfail(2, "fail", "Medium", /    else if (0) rfail(2, "fail", "Medium", /'
plugin_case P1417-r2-weak-rating-high T11 "$GAU" 's/    else if (RRATING\[name\] == "weak") rfail(2, "fail", "Medium", /    else if (RRATING[name] == "weak") rfail(2, "fail", "High", /'
plugin_case P1418-r2-high-count-without-rules-ok T11 "$GAU" 's/    if (RHIGH\[name\] > 0 \&\& named == 0) rfail(2, /    if (0) rfail(2, /'
plugin_case P1419-r2-commas-not-split T11 "$GAU" 's/open = ROPEN\[name\]; gsub(\/\[,;\]\/, " ", open); /open = ROPEN[name]; /'
plugin_case P1420-r2-dash-read-as-rule T11 "$GAU" '/^      if (T\[k\] == "-") continue$/d'
plugin_case P1421-r3-future-row-counts T11 "$GAU" 's/  else if (d > today) why = /  else if (0) why = /'
plugin_case P1422-r3-unreal-date-counts T11 "$GAU" 's/  else if (!realdate(d)) why = /  else if (0) why = /'
plugin_case P1423-r3-any-rating T11 "$GAU" 's/  else if (rating != "strong" \&\& rating != "moderate" \&\& rating != "weak") why = /  else if (0) why = /'
plugin_case P1424-r3-any-commit T11 "$GAU" 's/  else if (commit !~ \/^\[0-9A-Fa-f\]+\$\/ || length(commit) < 7 || length(commit) > 40) why = /  else if (0) why = /'
plugin_case P1425-r3-five-digit-commit T11 "$GAU" 's/ || length(commit) < 7 || / || length(commit) < 5 || /'
plugin_case P1426-r3-full-commit-refused T11 "$GAU" 's/ || length(commit) > 40) why = / || length(commit) > 39) why = /'
plugin_case P1427-r3-counts-unchecked T11 "$GAU" 's/  else if (\$8 !~ \/^\[0-9\]+\$\/ || \$9 !~ /  else if (0 \&\& \$9 !~ /'
plugin_case P1428-r3-cell-count-unchecked T11 "$GAU" 's/  if (\$3 + 0 != 9) why = /  if (0) why = /'
plugin_case P1429-r3-unnamed-review-counts T11 "$GAU" 's/  else if (name == "") why = /  else if (0) why = /'
plugin_case P1430-r3-unreadable-row-is-current T11 "$GAU" 's/BADDATE\[NBAD\] = realdate(d) ? d : ""; next }/BADDATE[NBAD] = realdate(d) ? d : "" }/'
plugin_case P1431-r3-not-medium T11 "$GAU" 's/rfail(3, "fail", "Medium", BADSRC\[i\], /rfail(3, "fail", "High", BADSRC[i], /'
plugin_case P1432-r3-no-table-silent T11 "$GAU" 's/  if (haslog \&\& !TABLE) rfail(3, /  if (0) rfail(3, /'
plugin_case P1433-r3-no-log-passes T11 "$GAU" 's/  if (!haslog) row("setup", "GOV-R3", "na", /  if (0) row("setup", "GOV-R3", "na", /'
plugin_case P1434-reviews-read-off-the-floor T11 "$GAU" 's/  if (NREV > 0) reviews()/  if (1) reviews()/'
plugin_case P1435-log-first-table-read T11 "$GLR" 's/  if (n == 9 \&\& tolower(c\[1\]) == "date" /  if (n >= 2 || tolower(c[1]) == "date" /'
plugin_case P1436-log-row-cells-not-counted T11 "$GLR" 's/printf "R\\t%d\\t%d", FNR, n$/printf "R\\t%d\\t%d", FNR, 9/'
mutant_group ascent-governance-reviews-2
plugin_case P1437-log-rule-row-read T11 "$GLR" '/^  if (rule) next$/d'
plugin_case P1438-log-header-case T11 "$GLR" 's/tolower(c\[1\]) == "date"/c[1] == "Date"/'
plugin_case P1439-log-crlf-unread T11 "$GLR" 's/  line = \$0; sub(\/\\r\$\/, "", line)/  line = $0/'
plugin_case P1440-log-cells-untrimmed T11 "$GLR" '/^  for (i = 1; i <= n; i++) c\[i\] = trim(c\[i\])$/d'
plugin_case P1441-r4-lost-rows-ignored T11 "$GCS" 's/^    if \[ -s "\$T\/lost1" \]; then$/    if false; then/'
plugin_case P1442-r4-not-medium T11 "$GCS" 's/item review GOV-R4 fail Medium "\$REVIEW_LOG" "a row of/item review GOV-R4 fail High "$REVIEW_LOG" "a row of/'
plugin_case P1443-r4-history-unread T11 "$GCS" 's/^      for p in \$ps; do$/      for p in; do/'
plugin_case P1444-r4-working-copy-unread T11 "$GCS" 's/^    if git cat-file -e "HEAD:\.\/\$REVIEW_LOG" 2>\/dev\/null; then  # the working copy/    if false; then  # the working copy/'
plugin_case P1445-r4-shallow-clone-read T11 "$GCS" 's/  elif \[ "\$(git rev-parse --is-shallow-repository 2>\/dev\/null)" = true \]; then R4NA=/  elif false; then R4NA=/'
plugin_case P1446-r4-untracked-log-read T11 "$GCS" 's/  elif ! git ls-files --error-unmatch -- "\$REVIEW_LOG" >\/dev\/null 2>\&1; then R4NA=/  elif false; then R4NA=/'
plugin_case P1447-r4-no-git-ignored T11 "$GCS" 's/  elif \[ "\$NOGIT" -eq 1 \]; then R4NA="--no-git given"/  elif false; then R4NA="--no-git given"/'
mutant_group ascent-governance-reviews-3
plugin_case P1448-r4-outside-git-unnamed T11 "$GCS" 's/  elif ! command -v git >\/dev\/null 2>\&1 || ! git rev-parse --is-inside-work-tree >\/dev\/null 2>\&1; then R4NA="not a git repository"/  elif false; then R4NA="not a git repository"/'
plugin_case P1449-r4-checked-off-the-floor T11 "$GCS" 's/^if grep -q "^review\$TAB" "\$T\/floor.tsv"; then$/if true; then/'
plugin_case P1450-review-log-path-ignored T11 "$GCS" 's/^REVIEW_LOG=\$(cget governance.review_log); /REVIEW_LOG=""; /'
plugin_case P1451-launch-flag-ignored T11 "$GCS" 's/    --launch) LAUNCH=1; shift ;;/    --launch) LAUNCH=0; shift ;;/'
plugin_case P1452-review-family-unregistered T13.10 docs/framework/OWNERSHIP.md '/^| `GOV-R` | /d'
# v0.4.24 review: a newer row that cannot be read, rows after a gap, a rule for each High finding
plugin_case P1635-rev-unread-newer-row-ignored T11 "$GAU" 's/^    if (u) rfail(1, st, sev,/    if (0) rfail(1, st, sev,/'
plugin_case P1636-rev-unread-row-above-counts T11 "$GAU" 's/ \&\& BADLN\[i\] + 0 > NEWEST\[name\] + 0//'
plugin_case P1637-rev-unread-older-row-counts T11 "$GAU" 's/ \&\& (BADDATE\[i\] == "" || BADDATE\[i\] >= RDATE\[name\])//'
plugin_case P1638-rev-fewer-rules-than-highs-passes T11 "$GAU" 's/^    else if (RHIGH\[name\] > named) rfail/    else if (0) rfail/'
plugin_case P1639-logrows-table-ends-at-a-gap T11 "$GLR" 's/^  if (line !~ \/^ \*\\|\/) next$/  if (line !~ \/^ *\\|\/) { if (found) exit; next }/'
plugin_case P1640-logrows-tab-ends-a-cell T11 "$GLR" '/^  gsub(\/\\t\/, " ", line)/d'
plugin_case P1641-logrows-second-header-is-a-row T11 "$GLR" '/^  if (head) next$/d'
plugin_case P1642-waiver-unreal-date-still-covers T11 "$GAU" 's/else if (!realdate(rb)) { EXPIRED\[w\] = 1; fail(3/else if (!realdate(rb)) { fail(3/'

mutant_group ascent-governance-launch-1
plugin_case P1453-record-overwrites T11 "$GCS" 's/^  \[ ! -e "\$RECORD" \] || bad /  true || bad /'
plugin_case P1454-record-of-a-changed-working-copy T11 "$GCS" 's/^  if \[ -s "\$T\/dirty" \]; then$/  if false; then/'
plugin_case P1455-record-untracked-files-unseen T11 "$GCS" 's/; git -c core.quotepath=off ls-files --others --exclude-standard -- \. 2>\/dev\/null; } | not_records/; } | not_records/'
plugin_case P1456-record-tracked-changes-unseen T11 "$GCS" 's/^  { git -c core.quotepath=off diff --no-renames --name-only --relative HEAD -- \. 2>\/dev\/null; git /  { git /'
plugin_case P1457-record-any-file-name T11 "$GCS" 's/^  \[ -n "\$RECORD" \] || bad "--record \$RECORD_ARG: /  true || bad "--record $RECORD_ARG: /'
plugin_case P1458-record-without-git T11 "$GCS" 's/^  in_git || bad "--record needs git/  true || bad "--record needs git/'
plugin_case P1459-record-does-not-ask-the-launch-question T11 "$GCS" 's/    --record) need \$#; RECORD="\$2"; LAUNCH=1; shift 2 ;;/    --record) need $#; RECORD="$2"; shift 2 ;;/'
plugin_case P1460-records-review-log-counts-as-a-change T11 "$GCS" "s/ \\&\\& \\\$0 != log_'; }/'; }/"
plugin_case P1461-records-launch-folder-counts-as-a-change T11 "$GCS" "s/'NF \\&\\& index(\\\$0, ld) != 1 \\&\\& /'NF \\&\\& /"
plugin_case P1462-records-lookalike-folder-exempt T11 "$GCS" 's/^not_records() { awk -v ld="\$LAUNCH_DIR\/" /not_records() { awk -v ld="$LAUNCH_DIR" /'
mutant_group ascent-governance-launch-2
plugin_case P1463-record-signed-by-the-script T11 "$GRA" 's/      printf "\*\*Signed:\*\*\\n\\n\*\*Date:\*\*\\n"/      printf "**Signed:** Claude\\n\\n**Date:**\\n"/'
plugin_case P1464-record-dated-by-the-script T11 "$GRA" 's/      printf "\*\*Signed:\*\*\\n\\n\*\*Date:\*\*\\n"/      printf "**Signed:**\\n\\n**Date:** %s\\n", date/'
plugin_case P1465-record-without-summary-place T11 "$GRA" '/^    if (sign) printf "## In plain words/d'
plugin_case P1466-record-without-commit T11 "$GCS" 's/ -v env="\$ENVNAME" -v date="\$TODAY" -v commit="\$2" \\$/ -v env="$ENVNAME" -v date="$TODAY" -v commit="" \\/'
plugin_case P1467-record-pipe-unescaped T11 "$GRA" 's/out = out ((c == "\\\\" || c == "|" || c == "<" || /out = out ((c == "\\\\" || c == "<" || /'
plugin_case P1468-record-tag-unescaped T11 "$GRA" 's/ || c == "|" || c == "<" || c == "\[" / || c == "|" || c == "[" /'
plugin_case P1469-record-conditions-in-file-order T11 "$GRA" 's/      rank = (SEV\[i\] == "High") ? 1 : (SEV\[i\] == "Medium" ? 2 : 3)/      rank = 1/'
plugin_case P1470-record-unmeasured-not-a-condition T11 "$GRA" 's/      if (ST\[i\] != "fail" \&\& ST\[i\] != "due" \&\& ST\[i\] != "unmeasured") continue/      if (ST[i] != "fail" \&\& ST[i] != "due") continue/'
plugin_case P1471-record-due-review-not-a-condition T11 "$GRA" 's/      if (ST\[i\] != "fail" \&\& ST\[i\] != "due" \&\& ST\[i\] != "unmeasured") continue/      if (ST[i] != "fail" \&\& ST[i] != "unmeasured") continue/'
plugin_case P1472-record-reviews-not-evidence T11 "$GRA" 's/      if (KIND\[i\] == "check" || KIND\[i\] == "review" || /      if (KIND[i] == "check" || /'
plugin_case P1473-record-expired-waiver-shows-days T11 "$GRA" 's/(LEFT\[i\] ~ \/^-\[0-9\]\/ ? "expired" : LEFT\[i\])/LEFT[i]/'
plugin_case P1474-record-acknowledged-changes-read-as-none T11 "$GRA" 's/^    if (!k \&\& !a) printf "None\.\\n"/    if (!k) printf "None.\\n"/'
plugin_case P1475-record-acknowledged-changes-left-out T11 "$GRA" 's/^    for (i = 1; i <= n; i++) if (KIND\[i\] == "ack") {$/    for (i = 1; i <= 0; i++) if (KIND[i] == "ack") {/'
plugin_case P1476-l3-off T11 "$GCS" 's/^if grep -q "^signoff\$TAB" "\$T\/floor.tsv"; then$/if false; then/'
plugin_case P1477-l3-no-record-not-high T11 "$GCS" 's/      item launch GOV-L3 fail High "\$LAUNCH_DIR" "no launch record/      item launch GOV-L3 fail Medium "$LAUNCH_DIR" "no launch record/'
plugin_case P1478-l3-not-high T11 "$GCS" 's/then item launch GOV-L3 fail High "\$NEWEST" "the newest launch record/then item launch GOV-L3 fail Medium "$NEWEST" "the newest launch record/'
plugin_case P1479-l3-unsigned-record-counts T11 "$GCS" 's/      elif \[ "\$ls" = - \]; then why=/      elif false; then why=/'
plugin_case P1480-l3-undated-message T11 "$GCS" 's/      elif \[ "\$ld" = - \]; then why=/      elif false; then why=/'
plugin_case P1481-l3-unreal-date-counts T11 "$GCS" 's/      elif ! realdate "\$ld"; then why=/      elif false; then why=/'
plugin_case P1482-l3-future-date-counts T11 "$GCS" 's/      elif \[ "\$ld" \\> "\$TODAY" \]; then why=/      elif false; then why=/'
plugin_case P1483-l3-nogo-message T11 "$GCS" 's/      elif \[ "\$lv" = NO-GO \]; then why=/      elif false; then why=/'
mutant_group ascent-governance-launch-3
plugin_case P1484-l3-any-verdict-counts T11 "$GCS" 's/      elif \[ "\$lv" != GO \] \&\& \[ "\$lv" != "GO WITH CONDITIONS" \]; then why=/      elif [ "$lv" = NO-GO ]; then why=/'
plugin_case P1485-l3-no-verdict-message T11 "$GCS" 's/      if \[ "\$lv" = - \]; then why=/      if false; then why=/'
plugin_case P1486-l3-oldest-record-wins T11 "$GCS" 's/^    NEWEST=\$(tail -1 "\$T\/records")$/    NEWEST=$(head -1 "$T\/records")/'
plugin_case P1487-l3-other-environments-record T11 "$GCS" 's/^for f in "\$LAUNCH_DIR"\/\[0-9\]\(.*\)-"\$ENVNAME"\.md; do$/for f in "$LAUNCH_DIR"\/[0-9]\1-*"$ENVNAME".md; do/'
plugin_case P1488-l3-launch-question-checks-the-signature T11 "$GCS" 's/^  if \[ "\$LAUNCH" -eq 1 \]; then$/  if false; then/'
plugin_case P1489-l4-off T11 "$GCS" "s/        elif clist governance.approvers | awk -v s=\"\\\$ls\" 'tolower(\\\$0) == tolower(s) { f = 1 } END { exit !f }'; then /        elif true; then /"
plugin_case P1490-l4-case-matters T11 "$GCS" "s/awk -v s=\"\\\$ls\" 'tolower(\\\$0) == tolower(s) { f = 1 }/awk -v s=\"\$ls\" '\$0 == s { f = 1 }/"
plugin_case P1491-l4-part-of-a-name T11 "$GCS" "s/awk -v s=\"\\\$ls\" 'tolower(\\\$0) == tolower(s) { f = 1 }/awk -v s=\"\$ls\" 'index(tolower(\$0), tolower(s)) { f = 1 }/"
plugin_case P1492-l4-not-high T11 "$GCS" 's/        else item launch GOV-L4 fail High /        else item launch GOV-L4 fail Medium /'
plugin_case P1493-l4-empty-list-refuses T11 "$GCS" 's/        if \[ -z "\$(clist governance.approvers)" \]; then item launch GOV-L4 na /        if false; then item launch GOV-L4 na /'
plugin_case P1494-l5-off T11 "$GCS" 's/^          if \[ -s "\$T\/changed" \]; then$/          if false; then/'
plugin_case P1495-l5-not-high T11 "$GCS" 's/            item launch GOV-L5 fail High "\$NEWEST" "\$nc path(s) changed/            item launch GOV-L5 fail Medium "$NEWEST" "$nc path(s) changed/'
plugin_case P1496-l5-record-without-commit-message T11 "$GCS" 's/        elif \[ -z "\$lc" \]; then item launch GOV-L5 fail High /        elif false; then item launch GOV-L5 fail High /'
plugin_case P1497-l5-unknown-commit-passes T11 "$GCS" 's/        elif ! git cat-file -e "\$lc^{commit}" 2>\/dev\/null; then$/        elif false; then/'
plugin_case P1498-l5-shallow-clone-unexplained T11 "$GCS" 's/          if \[ "\$(git rev-parse --is-shallow-repository 2>\/dev\/null)" = true \]; then item launch GOV-L5 fail High /          if false; then item launch GOV-L5 fail High /'
mutant_group ascent-governance-launch-4
plugin_case P1499-l5-outside-git-unexplained T11 "$GCS" 's/        elif ! in_git; then item launch GOV-L5 fail High /        elif false; then item launch GOV-L5 fail High /'
plugin_case P1500-l5-no-git-fails T11 "$GCS" 's/        if \[ "\$NOGIT" -eq 1 \]; then item launch GOV-L5 na /        if false; then item launch GOV-L5 na /'
plugin_case P1501-r4-signed-launch-does-not-reset T11 "$GCS" 's/^    \[ -z "\$SIGNED_COMMIT" \] || { RANGE=/    true || { RANGE=/'
plugin_case P1502-r4-unsigned-record-resets T11 "$GCS" 's/^  if signed "\$f"; then SIGNED_REC="\$f"; fi$/  if true; then SIGNED_REC="$f"; fi/'
# v0.4.24 review: who signed, which files are records, renames, the record's path
plugin_case P1644-sign-blank-line-is-a-name T11 "$GCS" 's/(named ? s : "-")/s/'
plugin_case P1645-sign-other-alphabet-refused T11 "$GCS" 's/if (c ~ \/\[A-Za-z\]\/ || c > "~") named = 1/if (c ~ \/[A-Za-z]\/) named = 1/'
plugin_case P1646-record-dated-after-today-read T11 "$GCS" 's/is dated after today (\$TODAY)"; continue; fi$/is dated after today ($TODAY)"; fi/'
plugin_case P1647-record-unreal-name-read T11 "$GCS" 's/its name is not a real date"; continue; fi$/its name is not a real date"; fi/'
plugin_case P1648-l5-move-hides-a-change T11 "$GCS" 's/diff --no-renames --name-only --relative "\$lc" HEAD/diff --name-only --relative "$lc" HEAD/'
plugin_case P1649-record-move-hides-a-change T11 "$GCS" 's/diff --no-renames --name-only --relative HEAD/diff --name-only --relative HEAD/'
plugin_case P1650-record-path-read-as-typed T11 "$GCS" 's/^  rp=\$(lexical "\$RECORD") /  rp="$RECORD" /'
plugin_case P1651-record-path-from-the-repo T11 "$GCS" '/^\[ -z "\$RECORD" \] || RECORD=\$(abspath "\$RECORD")$/d'
plugin_case P1652-l3-message-names-no-file T11 "$GCS" 's/--record \$LAUNCH_DIR\/\$TODAY-\$ENVNAME\.md, then a person signs it/--record, then a person signs it/'

mutant_group ascent-governance-views-1
GMH="$GOVP/scripts/lib/md-html.awk"
plugin_case P1503-html-tag-not-escaped T11 "$GMH" '/^    else if (c == "<") out = out "&lt;"$/d'
plugin_case P1504-html-ampersand-not-escaped T11 "$GMH" 's/^    if (c == "&") out = out /    if (0) out = out /'
plugin_case P1505-html-quote-not-escaped T11 "$GMH" '/^    else if (c == "\\"") out = out "&quot;"$/d'
plugin_case P1506-html-closing-bracket-not-escaped T11 "$GMH" '/^    else if (c == ">") out = out "&gt;"$/d'
plugin_case P1507-html-record-escapes-shown T11 "$GMH" 's/^    if (c == "\\\\" && i < n && index(/    if (0 \&\& index(/'
plugin_case P1508-html-escaped-pipe-splits-a-cell T11 "$GMH" '/^    if (c == "\\\\" && i < n) { cur = cur c substr(line, i + 1, 1); i++; continue }$/d'
plugin_case P1509-html-title-not-escaped T11 "$GMH" 's/  printf "<title>%s<\/title>\\n", html(title)/  printf "<title>%s<\/title>\\n", title/'
plugin_case P1510-html-comment-line-shown T11 "$GMH" '/^\/^<!--\.\*-->\[ \\t\]\*\$\/ { next }$/d'
plugin_case P1511-html-with-a-script T11 "$GMH" 's/^  print "<\/style>"$/  print "<\/style><script><\/script>"/'
plugin_case P1512-html-fetches-a-stylesheet T11 "$GMH" 's/^  print "<style>"$/  print "<link rel=\\"stylesheet\\" href=\\"https:\/\/fonts.example\/x.css\\"><style>"/'
plugin_case P1513-html-no-dark-theme T11 "$GMH" '/prefers-color-scheme: dark/d'
plugin_case P1514-html-no-print-style T11 "$GMH" 's/^  print "@media print { /  print "@media screen { /'
plugin_case P1515-html-no-viewport T11 "$GMH" '/name=\\"viewport\\"/d'
plugin_case P1516-html-tables-do-not-scroll T11 "$GMH" '/^  print "\.wrap { overflow-x: auto; }"$/d'
plugin_case P1517-html-table-left-open T11 "$GMH" 's/  if (table) { printf "<\/tbody>\\n<\/table>\\n<\/div>\\n"; table = 0 }/  if (table) { table = 0 }/'
plugin_case P1518-html-list-left-open T11 "$GMH" 's/  if (list != "") { printf "<\/%s>\\n", list; list = "" }/  if (list != "") { list = "" }/'
plugin_case P1519-html-nogo-shown-as-go T11 "$GMH" 's/cls = (para ~ \/NO-GO\/) ? /cls = (0) ? /'
plugin_case P1520-html-bold-not-read T11 "$GMH" 's/^function inline(s) { return pairs(pairs(html(s), "\*\*", "strong"), "`", "code") }$/function inline(s) { return pairs(html(s), "`", "code") }/'
plugin_case P1521-html-code-not-read T11 "$GMH" 's/^function inline(s) { return pairs(pairs(html(s), "\*\*", "strong"), "`", "code") }$/function inline(s) { return pairs(html(s), "**", "strong") }/'
plugin_case P1522-html-lone-mark-opens-a-tag T11 "$GMH" 's/^    if (q <= 1) break$/    if (q < 0) break/'
plugin_case P1523-html-rule-row-shown T11 "$GMH" '/^  if (rule) next$/d'
plugin_case P1524-html-page-not-marked T11 "$GMH" '/^  print "<!-- generated by ascent-governance check-audit.sh/d'
plugin_case P1525-html-launch-folder-by-name T11 "$GCS" 's/^  case "\$hp" in "\$lp"\/\*) bad /  case "$hp" in "$lp"\/NEVER\/*) bad /'
plugin_case P1526-html-launch-folder-through-a-link T11 "$GCS" 's/^    if \[ "\$hd" -ef "\$LAUNCH_DIR" \]; then bad "\$inld"; fi$/    :/'
plugin_case P1527-html-over-another-file T11 "$GCS" 's/^  if \[ -e "\$HTML" \] \&\& ! sed -n .2p. "\$HTML" 2>\/dev\/null | grep -qF -- "\$MARK"; then bad /  if false; then bad /'
plugin_case P1528-html-from-any-file T11 "$GCS" "s/^    head -1 \"\\\$FROM\" | grep -q '^# Launch record: ' || bad /    true || bad /"
plugin_case P1529-html-from-runs-the-checks T11 "$GCS" '/^    exit 0$/d'
plugin_case P1530-from-without-html T11 "$GCS" 's/^\[ -z "\$FROM" \] || \[ -n "\$HTML" \] || bad /true || bad /'
plugin_case P1531-html-folder-not-made T11 "$GCS" 's/^  mkdir -p "\$(dirname "\$HTML")" || bad /  true || bad /'
plugin_case P1532-html-run-as-a-record T11 "$GCS" 's/^if \[ -n "\$HTML" \]; then markdown 0 /if [ -n "$HTML" ]; then markdown 1 /'
plugin_case P1533-summary-written-when-unset T11 "$GCS" 's/^if \[ -n "\${GITHUB_STEP_SUMMARY:-}" \]; then$/if true; then/'
plugin_case P1534-summary-overwrites-the-job-s T11 "$GCS" 's/echo; } >> "\$GITHUB_STEP_SUMMARY"; }/echo; } > "$GITHUB_STEP_SUMMARY"; }/'
mutant_group ascent-governance-views-2
plugin_case P1535-summary-as-a-record T11 "$GCS" 's/^  { { markdown 0 "\$NOW_COMMIT"; echo; }/  { { markdown 1 "$NOW_COMMIT"; echo; }/'
plugin_case P1536-summary-failure-fails-the-run T11 "$GCS" 's/; } 2>\/dev\/null || echo "check-audit: could not write the job summary to \$GITHUB_STEP_SUMMARY" >\&2$/; } 2>\/dev\/null/'
plugin_case P1537-summary-titled-as-a-record T11 "$GRA" 's/(sign ? "Launch record" : "Launch readiness")/"Launch record"/'
# v0.4.24 review: where the page is written, and what a contract value can forge
plugin_case P1653-html-through-a-link T11 "$GCS" '/^  \[ ! -L "\$HTML" \] || bad /d'
plugin_case P1654-html-new-folder-under-a-link T11 "$GCS" 's/^  hd=\$(dirname "\$HTML"); while .*$/  hd=$(dirname "$HTML")/'
plugin_case P1655-html-launch-folder-other-case T11 "$GCS" 's/^  hp=\$(lexical "\$HTML" | tr .A-Z. .a-z.); lp=\$(lexical "\$LAUNCH_DIR" | tr .A-Z. .a-z.)$/  hp=$(lexical "$HTML"); lp=$(lexical "$LAUNCH_DIR")/'
plugin_case P1656-html-mark-anywhere-in-file T11 "$GCS" 's/! sed -n .2p. "\$HTML" 2>\/dev\/null | grep -qF -- "\$MARK"/! grep -qF -- "$MARK" "$HTML" 2>\/dev\/null/'
plugin_case P1657-html-path-from-the-repo T11 "$GCS" '/^\[ -z "\$HTML" \] || HTML=\$(abspath "\$HTML")$/d'
plugin_case P1658-from-path-from-the-repo T11 "$GCS" '/^\[ -z "\$FROM" \] || FROM=\$(abspath "\$FROM")$/d'
plugin_case P1659-render-backslash-forges-a-cell T11 "$GRA" 's/(c == "\\\\" || c == "|" || /(c == "|" || /'
plugin_case P1660-render-link-and-bold-not-escaped T11 "$GRA" 's/ || c == "\[" || c == "\*" || c == "`")/)/'
plugin_case P1661-page-escaped-star-is-bold T11 "$GMH" '/if (c == "\*") { out = out "&#42;"; continue }/d'
plugin_case P1662-page-escaped-bracket-keeps-backslash T11 "$GMH" 's/index("\\\\|<\[\*`", substr(s, i + 1, 1)) > 0/index("|<", substr(s, i + 1, 1)) > 0/'

mutant_group ascent-governance-rules
GLS="$GOVP/skills/launch-readiness/SKILL.md"
GRS="$GOVP/skills/governance-review/SKILL.md"
GRC="$GOVP/skills/review-record/SKILL.md"
GAG="$GOVP/agents/governance-conductor.md"
GRU="$GOVP/references/governance-rules.md"
GRM="$GOVP/README.md"
plugin_case P1538-gov-rule-dropped-from-reference T11 "$GRU" '/^| GOV-W2 | Low |/d'
plugin_case P1539-gov-rule-severity-drift T11 "$GRU" 's/^| GOV-R3 | Medium |/| GOV-R3 | Low |/'
plugin_case P1540-gov-header-severity-drift T11 "$GCS" 's/^#   GOV-W2  Low     no waiver/#   GOV-W2  Medium  no waiver/'
plugin_case P1541-gov-table-severity-drift T11 "$GLS" 's/(GOV-L4) | High |$/(GOV-L4) | Medium |/'
plugin_case P1542-gov-table-row-dropped T11 "$GLS" '/(GOV-R4) | Medium |$/d'
plugin_case P1543-gov-table-drift T5 "$GAG" 's/(GOV-W2) | Low |$/(GOV-W2) | Medium |/'
plugin_case P1544-gov-table-differs-in-the-agent T11 "$GAG" 's/(GOV-S2) | Medium |$/(GOV-S2) | Low |/'
plugin_case P1545-gov-verdict-softened T11 "$GLS" 's/NO-GO: any High\. GO WITH CONDITIONS/NO-GO: more than one High. GO WITH CONDITIONS/'
plugin_case P1546-gov-unrated-findings-rated T11 "$GLS" '/^- \*\*Rate only with the severity table below\.\*\*/d'
plugin_case P1547-gov-agent-gets-a-shell T11 "$GAG" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Bash/'
plugin_case P1548-gov-agent-may-edit T11 "$GAG" 's/^- Read-only: never edit, never propose to run a command yourself\.$/- Edit the review log when a row is wrong./'
plugin_case P1549-gov-agent-says-go T11 "$GAG" 's/Never say GO: a GO needs/Say GO when nothing blocks: a GO needs/'
plugin_case P1550-gov-agent-may-sign T11 "$GAG" '/^- Never sign, and never suggest a name or a date for/d'
plugin_case P1551-gov-agent-hides-what-it-did-not-assess T11 "$GAG" '/^Not assessed: GOV-L1, GOV-L2 and GOV-S2/d'
plugin_case P1552-gov-skill-signs T11 "$GLS" 's/^- \*\*Claude never signs\.\*\* Never write anything after/- **Claude signs when asked.** Write the name after/'
plugin_case P1553-gov-skill-fills-the-signature T11 "$GLS" 's/ Change nothing else in the file\.$/ Then fill in Signed: from git config./'
plugin_case P1554-gov-skill-commits-the-record T11 "$GLS" 's/, and never commit a record\./, then commit the record./'
plugin_case P1555-gov-skill-removes-a-draft T11 "$GLS" 's/the operator removes it; never remove it yourself\./remove it and write a new one./'
plugin_case P1556-gov-skill-edits-the-evidence T11 "$GLS" 's/ Never edit the verdict, the evidence table, the waivers or the conditions of a record: the script wrote them\.$//'
plugin_case P1557-gov-skill-writes-without-approval T11 "$GLS" 's/^- \*\*Write only these, and only after approval:\*\*/- **Write these:**/'
plugin_case P1558-gov-skill-unknown-option T11 "$GLS" "s/--env '<environment>' --launch \\.\$/--env '<environment>' --launch --strict ./"
plugin_case P1559-gov-skill-script-missing T11 "$GLS" "s|scripts/check-audit.sh\" --env '<environment>' --launch|scripts/check-launch.sh\" --env '<environment>' --launch|"
plugin_case P1560-gov-skill-unknown-contract-key T11 "$GLS" 's/`governance\.environments`, `floors`,/`governance.environments`, `governance.signers`, `floors`,/'
plugin_case P1561-gov-skill-cites-a-missing-step T11 "$GLS" 's/review-record Step 2 to Step 4 do/review-record Step 2 to Step 9 do/'
plugin_case P1562-gov-skill-claims-goodness T11 "$GLS" 's/^It checks that the evidence exists and is current, not that the system is good\.$/A GO means the system is good./'
plugin_case P1563-gov-review-writes-the-log T11 "$GRS" 's/^- \*\*Read-only\.\*\* Never write the review log, a launch record or the contract here, and never run a review/- Append what is missing to the review log, and run a review/'
plugin_case P1564-gov-review-writes-the-contract T11 "$GRS" 's/The proposal is text for the operator; never write it\./Write the proposal to the contract./'
plugin_case P1565-gov-review-asks-the-launch-question T11 "$GRS" "s/check-audit.sh\" --env '<environment>' \\.\$/check-audit.sh\" --env '<environment>' --launch ./"
plugin_case P1566-gov-review-no-recommended-next T11 "$GRS" '/^Recommended next: </d'
plugin_case P1567-gov-record-changes-rows T11 "$GRC" 's/^- \*\*Never change or remove a row\.\*\*/- **Correct a row in place.**/'
plugin_case P1568-gov-record-guesses-the-rating T11 "$GRC" 's/^- \*\*Refuse without a rating and a commit\.\*\*/- **Guess the rating when it is missing.**/'
plugin_case P1569-gov-record-commits T11 "$GRC" 's/ Any other path is a failure of this skill\. Never commit\.$/ Commit the row./'
plugin_case P1570-gov-record-writes-before-approval T11 "$GRC" 's/^### Step 3 .* After confirmation only$/### Step 3 - Write the row/'
plugin_case P1571-gov-record-drops-a-high-finding T11 "$GRC" 's/never leave out an open High finding/leave out findings the operator calls minor/'
plugin_case P1572-gov-record-gets-a-shell T11 "$GRC" 's/^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$/allowed-tools: Read, Grep, Glob, Bash/'
plugin_case P1573-gov-reference-anyone-writes-the-log T11 "$GRU" 's/Only `launch-readiness` and `review-record` write it/Any skill may write it/'
plugin_case P1574-gov-reference-review-skill-renamed T11 "$GRU" 's/^  | `ux-review` | `ascent-ux:ux-review` |/  | `ux-review` | `ascent-ux:ux-audit` |/'
plugin_case P1575-gov-reference-default-review-dropped T11 "$GRU" '/^  | `quality-review` | `ascent-quality:quality-review` |/d'
plugin_case P1576-gov-readme-follows-a-branch T11 "$GRM" 's/--branch v0\.4\.24 https/--branch main https/'
plugin_case P1577-gov-readme-shallow-checkout T11 "$GRM" '/^          fetch-depth: 0 /d'
plugin_case P1578-gov-readme-script-signs T11 "$GRM" 's/No skill, agent or script here writes after `Signed:` or `Date:`\./The skill fills in `Signed:` when asked./'
plugin_case P1579-gov-readme-rule-family-missing T11 "$GRM" 's/GOV-W1–W4 and GOV-R1–R4; /GOV-W1–W4; /'
plugin_case P1580-gov-description-not-use-when T11 "$GAG" 's/^  Use when an independent, read-only view/  An independent, read-only view/'
plugin_case P1581-gov-record-script-fills-the-signature T11 "$GRA" 's/printf "\*\*Signed:\*\*\\n\\n\*\*Date:\*\*\\n"/printf "**Signed:** the operator\\n\\n**Date:**\\n"/'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1585-next-sentence-missing-governance T11 plugins/ascent-governance/skills/launch-readiness/SKILL.md '/^Also name any plugin in `references\/plugin-signals\.md`/d'
plugin_case P1596-signals-copy-stale T1 plugins/ascent-governance/references/plugin-signals.md 's/never blocked/never stopped/'
plugin_case P1597-registry-copy-stale T1 plugins/ascent-governance/references/registry.md 's/^# Ownership registry$/# Ownership registry, edited/'
plugin_case_rm P1599-registry-copy-missing T1 plugins/ascent-governance/references/registry.md
plugin_case P1664-launch-nogo-record-written-anyway T11 "$GLS" '/^When Step 3.s answer is NO-GO, do not write the record/d'
plugin_case P1665-record-one-id-for-many-findings T11 "$GRC" 's/, one id for each finding, separated by spaces/, separated by spaces/'

mutant_group ascent-delivery-lenses
DLS2=plugins/ascent-delivery/skills/delivery-loop
plugin_case P1194-lens-decisions-dropped T13.8 "$DLS2/SKILL.md" '/^| Decisions | /d'
plugin_case P1195-lens-docs-provider-wrong T13.8 "$DLS2/references/review-lenses.md" 's/| Documentation | `ascent-docs:docs-reviewer` |/| Documentation | `ascent-docs:doc-reviewer` |/'
plugin_case P1196-lens-docs-dropped-in-readme T13.8 plugins/ascent-delivery/README.md '/^| Documentation | /d'
plugin_case P1197-lens-decisions-unregistered T13.8 docs/framework/OWNERSHIP.md '/^| Decisions | `ascent-adr:decision-reviewer` |/d'
plugin_case P1198-delivery-version-drift T10 plugins/ascent-delivery/README.md 's/\$/ /'
mutant_group ownership
T11_FORCE=none
OWN=docs/framework/OWNERSHIP.md
CHKO=make/check-ownership.sh
DLS=plugins/ascent-delivery/skills/delivery-loop
plugin_case_rm P205-registry-removed T13.1 "$OWN"
plugin_case P206-registry-end-marker-dropped T13.1 "$OWN" '/^<!-- ownership:lenses:end -->$/d'
plugin_case P207-registry-row-short T13.1 "$OWN" 's/^| `OPS-R` | `ascent-ops` | rule | `plugins\/ascent-ops\/scripts\/check-drills.sh` |$/| `OPS-R` | `ascent-ops` | rule |/'
plugin_case P208-plugin-row-dropped T13.2 "$OWN" '/^| `ascent-ops` | `OPS` | released /d'
plugin_case P209-planned-marked-released T13.2 "$OWN" 's/^| `ascent-governance` | `GOV` | released |/| `ascent-node-stack` | `GOV` | released |/'
plugin_case P210-marketplace-entry-renamed T13.2 .claude-plugin/marketplace.json 's/"name": "ascent-ops",/"name": "ascent-operations",/'
plugin_case P211-signal-row-dropped T13.2 "$OWN" '/^| HTML, JSX, Vue or Svelte templates/d'
plugin_case P212-skill-unregistered T13.3 "$OWN" '/^| `ascent-ops` | skill | `ops-manuals` |$/d'
plugin_case P213-hook-unregistered T13.3 "$OWN" '/^| `ascent-delivery` | hook | `operator-boundary` |$/d'
plugin_case P214-agent-misnamed T13.3 "$OWN" 's/^| `ascent-delivery` | agent | `finding-verifier` |$/| `ascent-delivery` | agent | `finding-checker` |/'
plugin_case P215-code-duplicated T13.4 "$OWN" 's/^| `ascent-governance` | `GOV` |/| `ascent-governance` | `OPS` |/'
plugin_case P216-family-wrong-plugin T13.4 "$OWN" 's/^| `UX-H` | `ascent-ux` |/| `UX-H` | `ascent-ops` |/'
plugin_case P217-family-definition-lost T13.4 "$OWN" 's#^\(| `UX-H` | `ascent-ux` | catalogue | `plugins/ascent-ux/references/\)usability-heuristics.md#\1design-tokens.md#'
plugin_case P218-reserved-wrong-plugin T13.4 "$OWN" '/^| Reserved | For | Release |$/{n;a\
| `OPS-R` | `ascent-quality` | v0.4.13 |
}'
plugin_case P219-family-duplicated T13.4 "$OWN" 's/^| `ARC-B` | .*$/&\
&/'
plugin_case P220-contract-extra-section T13.5 plugins/ascent-ux/references/contract-template.yml '$a\
quality:\
  maturity_target: enterprise'
plugin_case P221-contract-section-claimed-twice T13.5 "$OWN" 's/^| `ascent-quality` | `QA` | released | hand-written | `quality` |/| `ascent-quality` | `QA` | released | hand-written | `ux` |/'
plugin_case P222-marker-names-planned T13.6 plugins/ascent-ops/references/runbook-standard.md 's/(→ ascent-security)/(→ ascent-node-stack)/'
plugin_case P223-domain-duplicated T13.7 "$OWN" 's/^| design principles |/| design tokens and contrast |/'
plugin_case P224-domain-owner-unknown T13.7 "$OWN" 's/^| mutation evidence | — | `ascent-quality` |/| mutation evidence | — | `ascent-qualty` |/'
plugin_case P225-lens-dropped-in-skill T13.8 "$DLS/SKILL.md" '/^| Architecture and cost | /d'
plugin_case P226-lens-order-in-reference T13.8 "$DLS/references/review-lenses.md" 's/`ascent-ux:ux-reviewer`, `design:accessibility-review`/`design:accessibility-review`, `ascent-ux:ux-reviewer`/'
plugin_case P227-lens-dropped-in-readme T13.8 plugins/ascent-delivery/README.md '/^| UX and navigation | /d'
plugin_case P228-lens-provider-unregistered T13.8 "$OWN" 's/^| `ascent-architecture` | agent | `architecture-reviewer` |$/| `ascent-architecture` | agent | `architecture-critic` |/'
plugin_case P229-readme-version-stale T13.9 README.md 's#^| \[`ascent-ops`\](plugins/ascent-ops/README.md) | 0.3.1 |#| [`ascent-ops`](plugins/ascent-ops/README.md) | 0.3.0 |#'
plugin_case P230-pillars-unknown-plugin T13.9 docs/framework/PILLARS.md 's/^\(| Change safety | `ascent-ops` (`runbook-check`)\); `ascent-delivery` |/\1; `ascent-delivry` |/'
plugin_case P231-pillars-unknown-component T13.9 docs/framework/PILLARS.md 's/| Change safety | `ascent-ops` (`runbook-check`)/| Change safety | `ascent-ops` (`runbook-checks`)/'
plugin_case P232-rule-cell-unqualified T13.10 plugins/ascent-ops/references/secure-config-rules.md 's/^| OPS-S1 | High |/| S1 | High |/'
plugin_case P233-script-header-unqualified T13.10 plugins/ascent-architecture/scripts/check-cfn-static-site.sh 's/^#   ARC-C8  High /#   C8  High /'
plugin_case P234-prefix-unregistered T13.10 plugins/ascent-ux/references/contract-template.yml 's/^  direction: UX-D1 /  direction: UX-Q1 /'
plugin_case P791-map-version-stale T13.11 docs/framework/CAPABILITY-MAP.md 's/^| `ascent-ops` | Plugin · 5 skills, 1 agent | 0.3.1 |/| `ascent-ops` | Plugin · 5 skills, 1 agent | 0.3.0 |/'
plugin_case P792-map-skill-count-stale T13.11 docs/framework/CAPABILITY-MAP.md 's/^| `ascent-ux` | Plugin · 5 skills, 1 agent |/| `ascent-ux` | Plugin · 4 skills, 1 agent |/'
plugin_case P793-map-heading-stale T13.11 docs/framework/CAPABILITY-MAP.md 's/^### `ascent-quality` 0.2.1 ·/### `ascent-quality` 0.2.0 ·/'
plugin_case P794-map-parent-version-stale T13.11 docs/framework/CAPABILITY-MAP.md 's/ 28 embedded skills | [0-9.]* |/ 28 embedded skills | 0.0.1 |/'
plugin_case P795-readme-controls-stale T13.11 README.md 's/, [0-9][0-9,]* negative controls,/, 1 negative controls,/'
plugin_case P796-map-adrs-stale T13.11 docs/framework/CAPABILITY-MAP.md 's/\*\*[0-9]*\*\*<br>decision records/**1**<br>decision records/'
plugin_case P797-readme-badge-stale T13.11 README.md 's#badge/plugins-10-#badge/plugins-9-#'
plugin_case P798-skill-version-stale T13.11 skills/lloydbriantech-ascent/SKILL.md 's/^version: [0-9.]*$/version: 0.0.1/'
plugin_case_rm P799-map-removed T13.11 docs/framework/CAPABILITY-MAP.md
plugin_case P804-banner-light-figure-stale T13.11 docs/assets/ascent-banner-light.svg 's/>[0-9]* plugins · />5 plugins · /'
plugin_case P805-banner-dark-figure-stale T13.11 docs/assets/ascent-banner-dark.svg 's/ · [0-9][0-9,]* negative controls · / · 1 negative controls · /'
plugin_case P806-banner-description-stale T13.11 docs/assets/ascent-banner-light.svg 's/, [0-9]* ADRs\.</, 1 ADRs.</'
plugin_case P807-banner-quality-dropped T13.11 docs/assets/ascent-banner-dark.svg 's/ · docs · governance</ · docs</'
plugin_case P808-banner-figures-line-removed T13.11 docs/assets/ascent-banner-light.svg '/>[0-9]* plugins · /d'
plugin_case_rm P809-banner-removed T13.11 docs/assets/ascent-banner-dark.svg
plugin_case P235-checker-stops-early T13 "$CHKO" 's/^# T13.6 — cross-plugin markers$/exit 0/'
# the missing-plugin sentence and the generated copies of the registry (ADR-028)
plugin_case P1598-registry-source-not-rebuilt T1 docs/framework/OWNERSHIP.md 's/^| any repository with git | /| any repository under git | /'
# The ownership checker's own code (ADR-023 moved these out of ownership: they
# depend on the checker and its fixture tests only, so a plugin or registry change
# need not run them). Judged on T13.0, so the baseline runs T13.0.
mutant_group ownership-checker
T13_SELFTEST=1 plugin_case P236-checker-keeps-cr T13.0 "$CHKO" 's/sub(\/\\r\$\/, "", line)/sub(\/NEVERCR\/, "", line)/g'
T13_SELFTEST=1 plugin_case P237-checker-ignores-cell-count T13.0 "$CHKO" 's/if (NC != want) printf/if (0) printf/'
T13_SELFTEST=1 plugin_case P238-checker-ignores-lens-claims T13.0 "$CHKO" "s/| grep -q 'delivery-loop review lens' || continue/| grep -q 'never-matches' || continue/"
T13_SELFTEST=1 plugin_case P239-checker-skips-readme-lenses T13.0 "$CHKO" 's# "$ROOT/plugins/ascent-delivery/README.md"; do$#; do#'
T13_SELFTEST=1 plugin_case P800-checker-ignores-map-versions T13.0 "$CHKO" 's/\[ "\$mv" = "\$v" \] ||/true ||/'
T13_SELFTEST=1 plugin_case P801-checker-ignores-figures T13.0 "$CHKO" 's/elif \[ "\$got" != "\$want" \]; then/elif false; then/'
T13_SELFTEST=1 plugin_case P802-checker-ignores-badge T13.0 "$CHKO" 's/\[ "\$bn" = "\$NREL" \] ||/true ||/'
T13_SELFTEST=1 plugin_case P803-checker-ignores-skill-version T13.0 "$CHKO" 's/\[ "\$SKV" = "\$FV" \] ||/true ||/'
T13_SELFTEST=1 plugin_case P810-checker-ignores-banner-plugins T13.0 "$CHKO" 's/\$(comm -23 "\$W\/t11-plugins" "\$W\/t11-line")/$(true)/'
T13_SELFTEST=1 plugin_case P811-checker-ignores-banner-figures T13.0 "$CHKO" 's/\[ "\$got" = "\$want" \] || echo "\$doc says/true || echo "$doc says/'
T13_SELFTEST=1 plugin_case P812-checker-ignores-figures-line T13.0 "$CHKO" 's/|| echo "\$doc has no figures line"/|| true/'
T13_SELFTEST=1 plugin_case P832-checker-tests-shard-skips-cases T13.0 tests/meta/test-check-ownership.sh 's/if \[ \$(((NCASE - 1) % NSHARD)) -eq "\$SHARD" \]; then/if [ $(((NCASE - 1) % NSHARD)) -eq 99 ]; then/'
T13_SELFTEST=1 plugin_case_rm P240-checker-tests-removed T13.0 tests/meta/test-check-ownership.sh
T11_FORCE=""

# The harness checks itself (ADR-018). expect_case runs a control and confirms the
# harness reported STATUS for it, so a fast mode that turned a survivor, a kill on
# the wrong check, an anchor miss, a broken baseline or a disagreement between the
# modes into a kill fails here. The other controls break fast mode in
# make/test-plugins.sh and must be caught by T14, its self-test.
mutant_group harness
ARCHT=plugins/ascent-architecture/scripts/estimate-cost.sh
GATEP=make/test-plugins.sh
# T14 must pass unmutated for its controls to mean anything: they set T14_SELFTEST=1, so the baseline runs T14.
expect_case() {  # STATUS ID LABEL FILE SED — the harness must report STATUS for this control
  in_group && selected "$2" || return 0
  t11_scope "$4"
  listed expect "$2" "$3" "$4" || launch expect_run "$@"
}
expect_run() {
  local want=$1 out line got; shift
  [ "$MODE" = full ] && [ "$want" = "MODES DIFFER" ] && want=killed   # full mode has nothing to compare
  if [ "$want" = "CONTROL FAIL" ]; then
    plugin_copy "$WORK/p-$1" || { copy_failed "$1" "$WORK/p-$1"; return; }
    sed -i.mut-bak -e "$4" "$WORK/p-$1/$3" && rm -f "$WORK/p-$1/$3.mut-bak"
    out=$(plugin_baseline "$1" "$WORK/p-$1" || true); rm -rf "$WORK/p-$1" "$WORK/p-$1.out"
  else
    out=$(control_run edit "$@")
  fi
  if [ "${ASCENT_MUTANT_RAW:-0}" = 1 ]; then printf '%s\n' "$out"; return; fi
  line=${out%%$'\n'*}; got=$(echo "${line:2:12}" | sed 's/ *$//')
  if [ "$got" = "$want" ]; then
    printf "  confirmed    %-28s harness reported %s\n" "$1" "$want"
  elif [ "$got" = "COPY FAIL" ]; then
    printf '%s\n' "$out"   # an infrastructure error, not the harness's verdict
  else
    printf "  SURVIVED     %-28s harness reported '%s', expected %s:\n" "$1" "$got" "$want"
    printf '%s\n' "$out" | sed 's/^/  /'
  fi
}
expect_case SURVIVED P359-harness-survivor T5 docs/framework/PHILOSOPHY.md '$a\
A line that no gate check reads.'
expect_case SURVIVED P360-harness-wrong-check T11 plugins/ascent-architecture/README.md '$a\
A plugin edit without a version bump fails T10, not the T11 this control names.'
expect_case "ANCHOR MISS" P361-harness-anchor-miss T11 "$ARCHT" 's/text that is not in the file/x/'
MUTANT_FAULT=fast-pass expect_case "MODES DIFFER" P362-harness-modes-differ T11 "$ARCHT" 's/^      f = fr\[k\] + 0$/      f = 0/'
expect_case "CONTROL FAIL" P363-harness-baseline-broken T2 plugins/ascent-architecture/README.md '$a\
<<UNRENDERED>>'
MUTANT_FAULT=copy-fail expect_case "COPY FAIL" P611-harness-copy-fail T5 docs/framework/PHILOSOPHY.md '$a\
A copy that fails is an infrastructure error, never a verdict.'
expect_case SURVIVED P373-harness-other-subcheck T13.4 docs/framework/OWNERSHIP.md '/^| HTML, JSX, Vue or Svelte templates/d'
T14_SELFTEST=1 plugin_case P364-fast-never-stops-test T14.G2 "$GATEP" 's/kill -TERM -- "-\$pid"/true/'
T14_SELFTEST=1 plugin_case P365-fail-line-exit-0-passes T14.G5 "$GATEP" "s/if grep -q '^FAIL' \"\$WORK\/t11.out\"; then/if false; then/"
T14_SELFTEST=1 plugin_case P366-unknown-label-accepted T14.G8 "$GATEP" 's/ >&2; exit 2 ;; esac$/ >\&2 ;; esac/'
T14_SELFTEST=1 plugin_case P367-t11-runs-on-after-failure T14.G3 "$GATEP" 's/\[ "\$FAST" = 1 \] && break  # T11 has failed; the remaining tests/: # T11 has failed; the remaining tests/'
T14_SELFTEST=1 plugin_case P368-first-tests-last T14.G4 "$GATEP" 's/TESTS="\$FIRST \$NEXT \$REST"/TESTS="\$REST \$NEXT \$FIRST"/'
T14_SELFTEST=1 plugin_case P913-first-path-tier-dropped T14.G4 "$GATEP" 's/TESTS="\$FIRST \$NEXT \$REST"/TESTS="\$NEXT \$FIRST \$REST"/'
T14_SELFTEST=1 plugin_case P914-first-no-file-name-fallback T14.G4 "$GATEP" 's/F2=\$(basename "\$F1")/F2=\$F1/'
T14_SELFTEST=1 plugin_case P369-only-runs-everything T14.G8 "$GATEP" 's/^run() { \[ -z "\$ONLY" \] ||/run() { true ||/'
T14_SELFTEST=1 plugin_case P370-shared-tmpdir T14.G7 "$GATEP" 's/  TMPDIR="\$tmp" bash "\$1"/  bash "$1"/'
T14_SELFTEST=1 plugin_case P371-fail-line-not-watched T14.G2 "$GATEP" "s/if grep -q '^FAIL' \"\$2\"; then/if grep -q '^NEVER' \"\$2\"; then/"
T14_SELFTEST=1 plugin_case_rm P372-gate-self-test-removed T14 tests/meta/test-gate-fast.sh
T14_SELFTEST=1 plugin_case P374-t7-reasons-dropped T14.G10 "$GATEP" "s/^  printf '%s\\\\n' \"\$t7out\" | awk /  printf '' | awk /"
FMQA=make/qa-skill-frontmatter.sh
T14_SELFTEST=1 plugin_case P375-frontmatter-field-pipe T14.G12 "$FMQA" 's/if ! grep -qE "^\${field}:" <<< "\$fm"; then/if ! printf "%s\\n" "$fm" | grep -qE "^${field}:"; then/'
T14_SELFTEST=1 plugin_case P376-frontmatter-description-pipe T14.G12 "$FMQA" 's/desc=\$(awk /desc=$(printf "%s\\n" "$fm" | awk /; s/}'\'' <<< "\$fm" | tr /}'\'' | tr /'
T14_SELFTEST=1 plugin_case P833-only-list-first-label T14.G13 "$GATEP" 's/^for l in \${ASCENT_ONLY:-}; do$/for l in ${ASCENT_ONLY%% *}; do/'
T14_SELFTEST=1 plugin_case P834-t11-only-first-plugin T14.G14 "$GATEP" 's/case " \$ASCENT_T11_ONLY " in/case " ${ASCENT_T11_ONLY%% *} " in/'
# The baseline runs the behavior tests of the plugins the run's T11 controls edit: a
# copy with a broken behavior test must fail it (the harness reports CONTROL FAIL).
expect_case "CONTROL FAIL" P835-harness-baseline-t11 T11 "$ARCHT" 's/^      f = fr\[k\] + 0$/      f = 0/'

# Which slow checks a change runs (ADR-023). Every control narrows the scope, the
# direction that would let a change skip a check it needs, and T15, the scope
# self-test, must catch it. T11 is skipped: no control here is about behavior tests.
mutant_group scope
T11_FORCE=none
SCO=make/gate-scope.sh
plugin_case P813-scope-plugin-no-t11 T15 "$SCO" 's/^add_t11() { case " \$T11 " in \*" \$1 "\*) ;; \*) T11="\$T11 \$1" ;; esac; }/add_t11() { :; }/'
plugin_case P814-scope-plugin-groups-dropped T15 "$SCO" 's/  for g in \$GROUPS_ALL; do case "\$g" in "\$2"|"\$2"-\*) group "\$g"; gs="\$gs \$g" ;; esac; done/  :/'
plugin_case P815-scope-plugin-no-ownership T15 "$SCO" 's/^  group ownership$/  :/'
plugin_case P816-scope-unknown-path-narrow T15 "$SCO" 's/^    \*) everything "\$p" "no rule for this path" ;;/    *) why "$p" "no rule" ;;/'
plugin_case P817-scope-harness-line-narrow T15 "$SCO" 's/  if \[ "\$other" = 1 \]; then everything make\/test-mutants.sh/  if false; then everything make\/test-mutants.sh/'
plugin_case P818-scope-checker-no-selftest T15 "$SCO" 's/      T13=1; group ownership;/      group ownership;/'
plugin_case P819-scope-file-controls-dropped T15 "$SCO" 's/  { if (\$5 in p) {/  { if (0) {/'
plugin_case P820-scope-dir-controls-dropped T15 "$SCO" 's/for (q in p) if (index(q, \$5 "\/") == 1)/for (q in p) if (0)/'
plugin_case P821-scope-full-flag-ignored T15 "$SCO" 's/^    --full) FULL=1 ;;/    --full) ;;/'
plugin_case P822-scope-full-not-every-group T15 "$SCO" 's/WHOLE=" \$GROUPS_ALL "; IDS=""/IDS=""/'
plugin_case P823-scope-makefile-any-line T15 "$SCO" 's/if \[ -s "\$W\/make-lines" \] && ! grep/if true || ! grep/'
plugin_case P824-scope-validator-not-core T15 "$SCO" 's/; then group core$/; then :/'
plugin_case P825-scope-template-not-core T15 "$SCO" 's/^\(    make\/mutants.tsv|skills\/lloydbriantech-ascent\/assets\/\*)\) group core;/\1/'
plugin_case P826-scope-harness-tests-dropped T15 "$SCO" 's/t=\${p#tests\/meta\/}; harness_test "\${t%.sh}";/t=${p#tests\/meta\/};/'
plugin_case P827-scope-gate-narrow T15 "$SCO" 's/^    make\/test-plugins.sh) everything /    make\/test-plugins.sh) why /'
plugin_case P828-scope-workflow-narrow T15 "$SCO" 's/^    .github\/workflows\/\*) everything /    .github\/workflows\/*) why /'
plugin_case P829-scope-selected-dropped T15 "$SCO" 's/\[ -z "\$SEL" \] || targets=/[ -n "$SEL" ] || targets=/'
plugin_case P830-scope-docs-rule-too-wide T15 "$SCO" 's/^    tests\/\*|make\/\*) everything /    tests\/*|make\/*) why /'
plugin_case P836-scope-readers-dropped T15 "$SCO" 's/^  done < "\$W\/readers"$/  done < \/dev\/null/'
plugin_case P837-scope-every-plugin-readers-dropped T15 "$SCO" 's/; done < "\$W\/allreaders" ;;/; done < \/dev\/null ;;/'
plugin_case P838-scope-harness-group-no-selftest T15 "$SCO" 's/if \[ "\$g" = harness \]; then harness_test test-mutants-harness; fi/:/'
plugin_case P839-scope-no-diff-narrow T15 "$SCO" 's/^  \[ -s "\$W\/harness-lines" \] || other=1$/  :/'
plugin_case_rm P831-scope-tests-removed T15 tests/meta/test-gate-scope.sh
T11_FORCE=""

[ "$LIST" = 0 ] || exit 0

# Every control has finished: print the rest and count the results.
while [ -n "$(jobs -pr)" ]; do flush; sleep 0.2; done
wait; flush; bar final
if [ "$next" -le "$seq" ]; then
  echo "test-mutants: control $next of $seq left no result — the harness failed"; exit 1
fi
if [ "$seq" -ne "$PLANNED" ]; then
  echo "test-mutants: counted $PLANNED controls before the run but launched $seq — the count no longer matches how controls are declared"; exit 1
fi
for f in "$WORK"/r/*; do
  [ -f "$f" ] || continue
  read -r status _ < "$f" || true
  case "$status" in
    killed|confirmed|control) killed=$((killed + 1)) ;;
    ANCHOR) missed=$((missed + 1)) ;;
    COPY) copyfail=$((copyfail + 1)) ;;
    *) survived=$((survived + 1)) ;;
  esac
done

# The summary: counts by kind (the totals line below counts control and confirmed
# as killed, and MODES DIFFER and CONTROL FAIL as survived; COPY FAIL is neither),
# what was not killed, the time and the three slowest controls.
if [ "$total" -gt 0 ]; then
  cat "$WORK/done-core" "$WORK/done" | awk -F'\t' -v rule="$RULE" -v dot="$DOT" -v group="$GROUP" -v mode="$MODE" -v jobs="$JOBS" -v time="$(clock $((SECONDS - T0)))" '
    function rep(n,  r) { r = ""; while (n-- > 0) r = r rule; return r }
    { if ($2 == "killed" || $2 == "confirmed") k++; else if ($2 == "control") c++; else if ($2 == "ANCHOR MISS") a++
      else if ($2 == "MODES DIFFER") d++; else if ($2 == "CONTROL FAIL") f++; else if ($2 == "COPY FAIL") x++; else s++
      if ($2 !~ /^(killed|confirmed|control)$/) nk[++nn] = sprintf("          %-13s %s", $2, $3)
      if ($6 == "cached") cached++
      if ($1 != "-") { t[++nt] = $1 + 0; id[nt] = $3; ct[$5] += $1; cn[$5]++; gt[$4] += $1; gn[$4]++ } }
    # top3 TIMES COUNTS — the three largest totals, "name m:ss (n)", joined by the dot
    function top3(tt, nn,  k, m, j, r, done) {
      r = ""
      for (j = 1; j <= 3; j++) {
        m = ""; for (k in tt) if (!(k in done) && (m == "" || tt[k] > tt[m])) m = k
        if (m == "") break
        done[m] = 1; r = r (j > 1 ? " " dot " " : "") sprintf("%s %d:%02d (%d)", m, int(tt[m] / 60), tt[m] % 60, nn[m])
      }
      return r
    }
    END {
      print ""; print rep(16) " summary " rep(16)
      printf " group    %-20s mode  %s\n jobs     %-20s time  %s\n", group, mode, jobs, time
      printf " killed   %d   control %d   survived %d\n", k, c, s
      printf " modes differ %d   anchor miss %d   control fail %d   copy fail %d\n", d, a, f, x
      if (cached) printf " cached   %d kills reused, not rerun (ASCENT_MUTANT_CACHE)\n", cached
      for (j = 1; j <= 3 && j <= nt; j++) {
        m = 0; for (i = 1; i <= nt; i++) if (!(i in used) && (m == 0 || t[i] > t[m])) m = i
        used[m] = 1; printf " %-8s %-30s %ds\n", (j == 1 ? "slowest" : ""), id[m], t[m]
      }
      if (nt) { printf " by check %s\n", top3(ct, cn); printf " by group %s\n", top3(gt, gn) }
      if (nn) { print " not killed"; for (i = 1; i <= nn; i++) print nk[i] }
      print " result   " ((s + d + f + a + x == 0 && NR > 0) ? "PASS" : "FAIL")
      print rep(41)
    }'
fi
if [ -n "$TIMES" ]; then
  { printf 'seconds\tstatus\tid\tgroup\tcheck\tcached\n'; LC_ALL=C sort -t "$(printf '\t')" -k1,1nr "$WORK/done"; } > "$TIMES"
  echo "test-mutants: times of $(wc -l < "$WORK/done" | tr -d ' ') controls written to $TIMES" >&2
fi
[ "$total" -gt 0 ] || echo "test-mutants: group '$GROUP' ran no controls"
printf "\ntest-mutants: %s mutants — %s killed, %s survived, %s anchor misses (group: %s, mode: %s)\n" \
  "$total" "$killed" "$survived" "$missed" "$GROUP" "$MODE"
if [ "$copyfail" -gt 0 ]; then
  echo "test-mutants: $copyfail control(s) could not copy the repository (COPY FAIL) — an infrastructure error such as a full disk, not a verdict; rerun the group"
fi
[ "$survived" -eq 0 ] && [ "$missed" -eq 0 ] && [ "$copyfail" -eq 0 ] && [ "$total" -gt 0 ]
