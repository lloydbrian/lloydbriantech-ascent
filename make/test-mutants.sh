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
# ASCENT_MUTANT_MODE=full runs every control on the whole gate, as before v0.4.10;
# ASCENT_MUTANT_JOBS=<n> sets how many controls run at once (default: the number
# of cores); ASCENT_MUTANT_RAW=1 makes the harness group report its expect_case
# controls as they are, not as confirmed (tests/meta/test-mutants-harness.sh).
# While controls run, a progress bar on stderr shows how many are done and running,
# how many were not killed, and the time left, when stderr is a terminal;
# ASCENT_MUTANT_PROGRESS=0 turns it off and =1 forces it. Every run ends with a
# summary block above the totals line.
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
GROUP="${ASCENT_MUTANT_GROUP:-all}"
case " all $GROUPS_ALL " in *" $GROUP "*) ;; *) echo "test-mutants: unknown group '$GROUP' (groups: all $GROUPS_ALL)" >&2; exit 2 ;; esac
MODE="${ASCENT_MUTANT_MODE:-fast}"
case "$MODE" in fast|full) ;; *) echo "test-mutants: unknown mode '$MODE' (fast or full)" >&2; exit 2 ;; esac
JOBS="${ASCENT_MUTANT_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"
case "$JOBS" in ''|*[!0-9]*|0) echo "test-mutants: ASCENT_MUTANT_JOBS must be a positive number, got '$JOBS'" >&2; exit 2 ;; esac
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
CUR_GROUP=core
mutant_group() { CUR_GROUP="$1"; }
in_group() { [ "$GROUP" = all ] || [ "$GROUP" = "$CUR_GROUP" ]; }
killed=0; survived=0; missed=0; total=0
# Every finished control adds a line, seconds<TAB>status<TAB>id, to $WORK/done
# (core rows to $WORK/done-core, untimed): the progress bar and the summary read them.
T0=$SECONDS
: > "$WORK/done"; : > "$WORK/done-core"
note_core() { printf -- '-\t%s\t%s\n' "$1" "$2" >> "$WORK/done-core"; }  # STATUS ID
clock() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }  # SECONDS -> m:ss

if in_group; then

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
plugin_copy() {  # DIR — fresh copy of the repository without .git
  rm -rf "$1"; mkdir -p "$1"
  (cd "$REPO_ROOT" && tar --exclude ./.git -cf - .) | (cd "$1" && tar -xf -)
}
# T13.0 (the ownership checker's fixture tests) and T14 (the fast-mode self-test)
# are skipped unless a control sets T13_SELFTEST=1 or T14_SELFTEST=1: only the
# controls that edit the checker, fast mode or their tests need them.
plugin_gate() {  # DIR [fast LABEL EDITED-FILE] — run test-plugins on a copy; output in DIR.out
  local only="" t11fast=0 first=""
  if [ "${2:-}" = fast ]; then
    # MUTANT_FAULT=fast-pass makes fast mode pass everything: only the harness
    # group sets it, to prove that a disagreement between the modes is reported
    if [ "${MUTANT_FAULT:-}" = fast-pass ]; then : > "$1.out"; return 0; fi
    only=$3; t11fast=1; first=$(basename "$4")
  fi
  ASCENT_SKIP_CLAUDE_CLI=1 ASCENT_HOOK_TEST_ONE_AWK=1 ASCENT_T11_ONLY="${T11_ONLY:-}" \
    ASCENT_T13_SELFTEST="${T13_SELFTEST:-0}" ASCENT_T14_SELFTEST="${T14_SELFTEST:-0}" \
    ASCENT_ONLY="$only" ASCENT_T11_FAST="$t11fast" ASCENT_T11_FIRST="$first" \
    bash "$1/make/test-plugins.sh" "$1" </dev/null >"$1.out" 2>&1
}
# fails OUT — its FAIL lines, each with up to 5 of the indented reason lines the
# gate prints under it (T7), all indented
fails() { awk 'BEGIN { d = -1 } /^FAIL/ { print; d = 0; next } d >= 0 && d < 5 && /^      / { print; d++; next } { d = -1 }' "$1" | sed 's/^/                 /'; }
plugin_baseline() {  # ID COPY [NOTE] — the unmodified copy must pass the full gate
  if plugin_gate "$2"; then
    printf "  control      %-28s unmodified copy passes test-plugins%s\n" "$1" "${3:-}"
  else
    printf "  CONTROL FAIL %-28s unmodified copy fails test-plugins%s:\n" "$1" "${3:-}"
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
PLANNED=$(awk -v g="$GROUP" -v mode="$MODE" '
  /^mutant_group [a-z0-9-]+$/ { cur = $2; next }
  cur == "" || (g != "all" && g != cur) { next }
  /^([A-Z0-9_]+=[^ ]* )*(plugin_case|plugin_case_rm|expect_case) / || /^ *([A-Z0-9_]+=[^ ]* )*launch plugin_baseline P00-/ { n++ }
  END { if (g != "core") n += 1 + (mode == "fast"); print n + 0 }' "$0")
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
# record SECONDS RESULT — the line for $WORK/done: the result's status and id sit
# at fixed columns of its first line ("  %-12s %-28s")
record() {
  awk -v t="$1" 'NR == 1 { st = substr($0, 3, 12); sub(/ +$/, "", st); id = substr($0, 16); sub(/ .*/, "", id); print t "\t" st "\t" id }
    END { if (NR == 0) print t "\t?\t?" }' "$2"
}
flush() {
  while [ -f "$WORK/r/$next" ]; do unbar; cat "$WORK/r/$next"; next=$((next + 1)); done
  bar
}
launch() {  # COMMAND ARGS... — run one control in the background, at most $JOBS at a time
  local n
  seq=$((seq + 1)); total=$((total + 1))
  while n=$(jobs -pr | wc -l) && [ $((n)) -ge "$JOBS" ]; do flush; sleep 0.2; done
  ( s=$SECONDS; "$@" >"$WORK/r/$seq.part" 2>&1 || true
    record $((SECONDS - s)) "$WORK/r/$seq.part" >> "$WORK/done"
    mv "$WORK/r/$seq.part" "$WORK/r/$seq" ) &
  flush
}
# The baseline runs alongside the controls, on its own copy: a control's verdict
# counts only if the baseline passes, and a failed baseline fails the run. In fast
# mode a second baseline runs every behavior test unmutated the way fast mode runs
# them (own process group and TMPDIR, stopped at a FAIL line): a test that failed
# only there would otherwise turn every T11 control into a kill.
plugin_fast_baseline() {  # ID COPY
  if plugin_gate "$2" fast T11 ""; then
    printf "  control      %-28s unmodified copy passes T11 in fast mode\n" "$1"
  else
    printf "  CONTROL FAIL %-28s unmodified copy fails T11 in fast mode:\n" "$1"
    fails "$2.out"; return 1
  fi
}
if [ "$GROUP" != core ]; then
plugin_copy "$WORK/p-baseline"
T11_ONLY=""
launch plugin_baseline P00-baseline "$WORK/p-baseline"
if [ "$MODE" = fast ]; then
  plugin_copy "$WORK/p-fast-baseline"
  launch plugin_fast_baseline P00-fast-baseline "$WORK/p-fast-baseline"
fi
fi

# control_run KIND ID LABEL PATH [SED [rebuild]] — one control on its own copy;
# KIND is edit (apply SED to PATH) or rm (delete PATH). Prints its result.
control_run() {
  local kind=$1 id=$2 label=$3 path=$4 copy="$WORK/p-$2"
  plugin_copy "$copy"
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
  plugin_verdict "$id" "$label" "$copy" "$path"
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
  in_group || return 0
  t11_scope "$3"
  launch control_run edit "$@"
}
plugin_case_rm() {  # ID EXPECT-LABEL PATH(relative to repo) — the control deletes PATH
  in_group || return 0
  t11_scope "$3"
  launch control_run rm "$@"
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
plugin_case P292-dep-skill-version-drift T3 "$DCK" 's/^version: 0\.2\.0$/version: 0.1.9/'
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
mutant_group ascent-delivery
DEL=plugins/ascent-delivery
HOOK="$DEL/hooks/operator-boundary.sh"
VERIFIER="$DEL/agents/finding-verifier.md"
plugin_case P15-hook-allows-git-push T11 "$HOOK" 's/GIT_READ = " status /GIT_READ = " push status /'
plugin_case P16-hook-ignores-contract T11 "$HOOK" 's/cur = (key == "deploy_beta" || key == "deploy_prod") ? key : ""/cur = ""/'
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
# The gate must report a behavior test that fails with more output than a pipe holds.
# T11 once quoted the first FAIL lines through grep | head under set -e and pipefail,
# and SIGPIPE ended the gate before T11 printed (seen as P246, P255, P265 surviving).
plugin_case P358-t11-long-failure-output T11 tests/plugins/ascent-delivery/test-delivery-rules.sh '1a\
for i in $(seq 1 3000); do echo "FAIL  line $i: padding so a failing behavior test prints more than a pipe holds"; done; exit 1'
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
plugin_case P111-web-delegated-ignored T11 "$UXW" 's/(d = delegated(tag)) != ""/0/'
plugin_case P112-web-delegated-key-assumed T11 "$UXW" 's/if (!(FILE in DKEY) \&\& /if (0 \&\& /'
plugin_case P113-web-ring-without-focus T11 "$UXW" 's/if (sel ~ \/:focus\/ \&\& ring(full, p))/if (ring(full, p))/'
plugin_case P114-web-ring-none-accepted T11 "$UXW" 's/return v ~ \/\[1-9\]\/ \&\& v/return 1 || v/'
plugin_case P115-web-notes-dropped T11 "$UXW" '/^    printf "%s", NOTES\[k\]$/d'
plugin_case P116-ux-review-notes-rated T11 "$UXR" 's/Each `NOTE` line is unrated/Each `NOTE` line is Low/'
plugin_case P117-agent-delegated-dropped T11 "$UXA" 's/That includes delegated listeners/It covers inline handlers/'
plugin_case P202-tokens-to-css-no-help T11 "$UX/scripts/tokens-to-css.sh" '/^case "\${1:-}" in -h|--help)/d'
# ascent-ops runs as five groups so each CI job stays well inside its timeout:
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
plugin_case P178-iac-local-override-is-prod T11 "$OPI" 's/ && lc(FN) !~ \/local|dev|test|example\/) fail/) fail/'
plugin_case P179-scripts-token-is-a-guard T11 "$OPZ" 's/\^(confirm|confirmation|answer|reply|ok|yn|yesno|proceed|sure)\$/(confirm|answer|ok|yn)/'
plugin_case P180-scripts-prompt-not-parsed T11 "$OPZ" 's/( +-\[A-Za-z\]+( +P)?)\*/( +-[A-Za-z]+)*/'
plugin_case P181-scripts-prints-the-line T11 "$OPZ" 's/DESTC\[NDEST\] = destword(line)/DESTC[NDEST] = line/'
plugin_case P182-scripts-build-not-exempt T11 "$OPZ" 's/if (!cBuild) {/if (1) {/'
plugin_case P183-scripts-alpine-not-floating T11 "$OPZ" 's/ || t ~ \/:\[A-Za-z_-\]+\$\/ }/ }/'
plugin_case P184-scripts-git-ssh-is-registry T11 "$OPZ" 's/|git::|git@|github/|git::|github/'
plugin_case P185-manuals-fm-comment-kept T11 "$OPM" 's/^    sub(\/\[ \\t\]+#\.\*\$\/, "", line)$//'
plugin_case P186-manuals-fm-comment-kept-in-bash T11 "$OPS/scripts/check-ops-manuals.sh" 's/{ sub(\/\[ \\t\]+#\.\*\$\/, ""); print }/{ print }/'
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

# Ownership gate T13 (ADR-015). Every control expects one T13 rule; T11 is
# skipped (T11_FORCE names no plugin) because no control here is about behavior
# tests. The checker-code controls at the end set T13_SELFTEST=1 and expect the
# fixture tests (T13.0) to catch them.
mutant_group ownership
T11_FORCE=none
OWN=docs/framework/OWNERSHIP.md
CHKO=make/check-ownership.sh
DLS=plugins/ascent-delivery/skills/delivery-loop
# The T13.0 controls below are judged on T13.0, so T13.0 must pass unmutated first.
if in_group; then
  plugin_copy "$WORK/p-ownership-baseline"; T11_ONLY=none
  T13_SELFTEST=1 launch plugin_baseline P00-ownership-baseline "$WORK/p-ownership-baseline" " with T13.0"
fi
plugin_case_rm P205-registry-removed T13.1 "$OWN"
plugin_case P206-registry-end-marker-dropped T13.1 "$OWN" '/^<!-- ownership:lenses:end -->$/d'
plugin_case P207-registry-row-short T13.1 "$OWN" 's/^| `QA-I` | `ascent-quality` | v0.4.11 |$/| `QA-I` | `ascent-quality` |/'
plugin_case P208-plugin-row-dropped T13.2 "$OWN" '/^| `ascent-ops` | `OPS` | released /d'
plugin_case P209-planned-marked-released T13.2 "$OWN" 's/^| `ascent-quality` | `QA` | planned |/| `ascent-quality` | `QA` | released |/'
plugin_case P210-marketplace-entry-renamed T13.2 .claude-plugin/marketplace.json 's/"name": "ascent-ops",/"name": "ascent-operations",/'
plugin_case P211-signal-row-dropped T13.2 "$OWN" '/^| HTML, JSX, Vue or Svelte templates/d'
plugin_case P212-skill-unregistered T13.3 "$OWN" '/^| `ascent-ops` | skill | `ops-manuals` |$/d'
plugin_case P213-hook-unregistered T13.3 "$OWN" '/^| `ascent-delivery` | hook | `operator-boundary` |$/d'
plugin_case P214-agent-misnamed T13.3 "$OWN" 's/^| `ascent-delivery` | agent | `finding-verifier` |$/| `ascent-delivery` | agent | `finding-checker` |/'
plugin_case P215-code-duplicated T13.4 "$OWN" 's/^| `ascent-governance` | `GOV` |/| `ascent-governance` | `OPS` |/'
plugin_case P216-family-wrong-plugin T13.4 "$OWN" 's/^| `UX-H` | `ascent-ux` |/| `UX-H` | `ascent-ops` |/'
plugin_case P217-family-definition-lost T13.4 "$OWN" 's#^\(| `UX-H` | `ascent-ux` | catalogue | `plugins/ascent-ux/references/\)usability-heuristics.md#\1design-tokens.md#'
plugin_case P218-reserved-wrong-plugin T13.4 "$OWN" 's/^| `OPS-R` | `ascent-ops` |/| `OPS-R` | `ascent-quality` |/'
plugin_case P219-family-duplicated T13.4 "$OWN" 's/^| `ARC-B` | .*$/&\
&/'
plugin_case P220-contract-extra-section T13.5 plugins/ascent-ux/references/contract-template.yml '$a\
quality:\
  maturity_target: enterprise'
plugin_case P221-contract-section-claimed-twice T13.5 "$OWN" 's/^| `ascent-quality` | `QA` | planned | hand-written | `quality` |/| `ascent-quality` | `QA` | planned | hand-written | `ux` |/'
plugin_case P222-marker-names-planned T13.6 plugins/ascent-ops/references/runbook-standard.md 's/(→ ascent-security)/(→ ascent-quality)/'
plugin_case P223-domain-duplicated T13.7 "$OWN" 's/^| design principles |/| design tokens and contrast |/'
plugin_case P224-domain-owner-unknown T13.7 "$OWN" 's/^| mutation evidence | — | `ascent-quality` |/| mutation evidence | — | `ascent-qualty` |/'
plugin_case P225-lens-dropped-in-skill T13.8 "$DLS/SKILL.md" '/^| Architecture and cost | /d'
plugin_case P226-lens-order-in-reference T13.8 "$DLS/references/review-lenses.md" 's/`ascent-ux:ux-reviewer`, `design:accessibility-review`/`design:accessibility-review`, `ascent-ux:ux-reviewer`/'
plugin_case P227-lens-dropped-in-readme T13.8 plugins/ascent-delivery/README.md '/^| UX and navigation | /d'
plugin_case P228-lens-provider-unregistered T13.8 "$OWN" 's/^| `ascent-architecture` | agent | `architecture-reviewer` |$/| `ascent-architecture` | agent | `architecture-critic` |/'
plugin_case P229-readme-version-stale T13.9 README.md 's#^| \[`ascent-ops`\](plugins/ascent-ops/README.md) | 0.2.0 |#| [`ascent-ops`](plugins/ascent-ops/README.md) | 0.1.0 |#'
plugin_case P230-pillars-unknown-plugin T13.9 docs/framework/PILLARS.md 's/^\(| Change safety | `ascent-ops` (`runbook-check`)\); `ascent-delivery` |/\1; `ascent-delivry` |/'
plugin_case P231-pillars-unknown-component T13.9 docs/framework/PILLARS.md 's/| Change safety | `ascent-ops` (`runbook-check`)/| Change safety | `ascent-ops` (`runbook-checks`)/'
plugin_case P232-rule-cell-unqualified T13.10 plugins/ascent-ops/references/secure-config-rules.md 's/^| OPS-S1 | High |/| S1 | High |/'
plugin_case P233-script-header-unqualified T13.10 plugins/ascent-architecture/scripts/check-cfn-static-site.sh 's/^#   ARC-C8  High /#   C8  High /'
plugin_case P234-prefix-unregistered T13.10 plugins/ascent-ux/references/contract-template.yml 's/^  direction: UX-D1 /  direction: UX-Q1 /'
plugin_case P235-checker-stops-early T13 "$CHKO" 's/^# T13.6 — cross-plugin markers$/exit 0/'
T13_SELFTEST=1 plugin_case P236-checker-keeps-cr T13.0 "$CHKO" 's/sub(\/\\r\$\/, "", line)/sub(\/NEVERCR\/, "", line)/g'
T13_SELFTEST=1 plugin_case P237-checker-ignores-cell-count T13.0 "$CHKO" 's/if (NC != want) printf/if (0) printf/'
T13_SELFTEST=1 plugin_case P238-checker-ignores-lens-claims T13.0 "$CHKO" "s/| grep -q 'delivery-loop review lens' || continue/| grep -q 'never-matches' || continue/"
T13_SELFTEST=1 plugin_case P239-checker-skips-readme-lenses T13.0 "$CHKO" 's# "$ROOT/plugins/ascent-delivery/README.md"; do$#; do#'
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
# T14 must pass unmutated for its controls to mean anything.
if in_group; then
  plugin_copy "$WORK/p-harness-baseline"; T11_ONLY=none
  T14_SELFTEST=1 launch plugin_baseline P00-harness-baseline "$WORK/p-harness-baseline" " with T14"
fi
expect_case() {  # STATUS ID LABEL FILE SED — the harness must report STATUS for this control
  in_group || return 0
  t11_scope "$4"
  launch expect_run "$@"
}
expect_run() {
  local want=$1 out line got; shift
  [ "$MODE" = full ] && [ "$want" = "MODES DIFFER" ] && want=killed   # full mode has nothing to compare
  if [ "$want" = "CONTROL FAIL" ]; then
    plugin_copy "$WORK/p-$1"
    sed -i.mut-bak -e "$4" "$WORK/p-$1/$3" && rm -f "$WORK/p-$1/$3.mut-bak"
    out=$(plugin_baseline "$1" "$WORK/p-$1" || true); rm -rf "$WORK/p-$1" "$WORK/p-$1.out"
  else
    out=$(control_run edit "$@")
  fi
  if [ "${ASCENT_MUTANT_RAW:-0}" = 1 ]; then printf '%s\n' "$out"; return; fi
  line=${out%%$'\n'*}; got=$(echo "${line:2:12}" | sed 's/ *$//')
  if [ "$got" = "$want" ]; then
    printf "  confirmed    %-28s harness reported %s\n" "$1" "$want"
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
expect_case SURVIVED P373-harness-other-subcheck T13.4 docs/framework/OWNERSHIP.md '/^| HTML, JSX, Vue or Svelte templates/d'
T14_SELFTEST=1 plugin_case P364-fast-never-stops-test T14.G2 "$GATEP" 's/kill -TERM -- "-\$pid"/true/'
T14_SELFTEST=1 plugin_case P365-fail-line-exit-0-passes T14.G5 "$GATEP" "s/if grep -q '^FAIL' \"\$WORK\/t11.out\"; then/if false; then/"
T14_SELFTEST=1 plugin_case P366-unknown-label-accepted T14.G8 "$GATEP" 's/ >&2; exit 2 ;; esac$/ >\&2 ;; esac/'
T14_SELFTEST=1 plugin_case P367-t11-runs-on-after-failure T14.G3 "$GATEP" 's/\[ "\$FAST" = 1 \] && break  # T11 has failed; the remaining tests/: # T11 has failed; the remaining tests/'
T14_SELFTEST=1 plugin_case P368-first-tests-last T14.G4 "$GATEP" 's/TESTS="\$FIRST \$REST"/TESTS="\$REST \$FIRST"/'
T14_SELFTEST=1 plugin_case P369-only-runs-everything T14.G8 "$GATEP" 's/^run() { \[ -z "\$ONLY" \] ||/run() { true ||/'
T14_SELFTEST=1 plugin_case P370-shared-tmpdir T14.G7 "$GATEP" 's/  TMPDIR="\$tmp" bash "\$1"/  bash "$1"/'
T14_SELFTEST=1 plugin_case P371-fail-line-not-watched T14.G2 "$GATEP" "s/if grep -q '^FAIL' \"\$2\"; then/if grep -q '^NEVER' \"\$2\"; then/"
T14_SELFTEST=1 plugin_case_rm P372-gate-self-test-removed T14 tests/meta/test-gate-fast.sh
T14_SELFTEST=1 plugin_case P374-t7-reasons-dropped T14.G10 "$GATEP" "s/^  printf '%s\\\\n' \"\$t7out\" | awk /  printf '' | awk /"
FMQA=make/qa-skill-frontmatter.sh
T14_SELFTEST=1 plugin_case P375-frontmatter-field-pipe T14.G12 "$FMQA" 's/if ! grep -qE "^\${field}:" <<< "\$fm"; then/if ! printf "%s\\n" "$fm" | grep -qE "^${field}:"; then/'
T14_SELFTEST=1 plugin_case P376-frontmatter-description-pipe T14.G12 "$FMQA" 's/desc=\$(awk /desc=$(printf "%s\\n" "$fm" | awk /; s/}'\'' <<< "\$fm" | tr /}'\'' | tr /'

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
    *) survived=$((survived + 1)) ;;
  esac
done

# The summary: counts by kind (the totals line below counts control and confirmed
# as killed, and MODES DIFFER and CONTROL FAIL as survived), what was not killed,
# the time and the three slowest controls.
if [ "$total" -gt 0 ]; then
  cat "$WORK/done-core" "$WORK/done" | awk -F'\t' -v rule="$RULE" -v group="$GROUP" -v mode="$MODE" -v jobs="$JOBS" -v time="$(clock $((SECONDS - T0)))" '
    function rep(n,  r) { r = ""; while (n-- > 0) r = r rule; return r }
    { if ($2 == "killed" || $2 == "confirmed") k++; else if ($2 == "control") c++; else if ($2 == "ANCHOR MISS") a++
      else if ($2 == "MODES DIFFER") d++; else if ($2 == "CONTROL FAIL") f++; else s++
      if ($2 !~ /^(killed|confirmed|control)$/) nk[++nn] = sprintf("          %-13s %s", $2, $3)
      if ($1 != "-") { t[++nt] = $1 + 0; id[nt] = $3 } }
    END {
      print ""; print rep(16) " summary " rep(16)
      printf " group    %-20s mode  %s\n jobs     %-20s time  %s\n", group, mode, jobs, time
      printf " killed   %d   control %d   survived %d\n", k, c, s
      printf " modes differ %d   anchor miss %d   control fail %d\n", d, a, f
      for (j = 1; j <= 3 && j <= nt; j++) {
        m = 0; for (i = 1; i <= nt; i++) if (!(i in used) && (m == 0 || t[i] > t[m])) m = i
        used[m] = 1; printf " %-8s %-30s %ds\n", (j == 1 ? "slowest" : ""), id[m], t[m]
      }
      if (nn) { print " not killed"; for (i = 1; i <= nn; i++) print nk[i] }
      print " result   " ((s + d + f + a == 0 && NR > 0) ? "PASS" : "FAIL")
      print rep(41)
    }'
fi
[ "$total" -gt 0 ] || echo "test-mutants: group '$GROUP' ran no controls"
printf "\ntest-mutants: %s mutants — %s killed, %s survived, %s anchor misses (group: %s, mode: %s)\n" \
  "$total" "$killed" "$survived" "$missed" "$GROUP" "$MODE"
[ "$survived" -eq 0 ] && [ "$missed" -eq 0 ] && [ "$total" -gt 0 ]
