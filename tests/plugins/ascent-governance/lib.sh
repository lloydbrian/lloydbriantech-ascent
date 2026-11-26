# Shared helpers for the ascent-governance behavior tests. Sourced, never run.
#
# A test sets NAME (its own name) and CHECK (the script under test) before
# sourcing, defines matrix(), then calls run_matrix. Every case runs with the
# default awk and every other awk found (mawk, gawk, BWK awk). Git cases use
# throwaway repositories inside the test's temporary folder, with git's global
# and system configuration switched off; the project's repository is never
# touched. Portable: bash 3.2+, GNU/Linux and BSD/macOS.

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
PLUGIN="$HERE/../../../plugins/ascent-governance"
FIX="$HERE/fixtures"

PASS=0; FAIL=0; AWKNAME=default; SHIM="$WORK/shim-default"
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
need() { for f in "$@"; do [ -e "$f" ] || { echo "FAIL  $NAME: missing $f"; echo "$NAME: 0/1 PASS"; exit 1; }; done; }

mk() { rm -rf "${WORK:?}/$1"; cp -R "$FIX/${2:-audit-good}" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {  # COPY FILE AWK
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
expect_only() {  # NAME RULE [SEVERITY] — exactly this rule fails; exit 1 when it is High
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  want=0; [ "${3:-}" = High ] && want=1
  if [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep -E '^FAIL|^check-' | head -2 | cut -c1-150 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  elif [ -n "${3:-}" ] && [ "$RC" -ne "$want" ]; then bad "$1: $2 $3 should exit $want, got $RC"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL '; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|^check-' | head -2 | cut -c1-150 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | cut -c1-150 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@") >/dev/null 2>&1; }
GD() { local d="$1"; shift; GIT_AUTHOR_DATE="$d 12:00:00 +0000" GIT_COMMITTER_DATE="$d 12:00:00 +0000" G "$@"; }
head_of() { (cd "$WORK/$1" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git log -1 --format=%h); }

# --- check-audit.sh with stand-in checkers --------------------------------------
# stubs builds $WORK/stubs/<plugin>/scripts/<script>.sh from fixtures/stub-checker.sh
# (and copies ascent-ai's real detect-ai.sh) and clears the log; no_ai removes
# ascent-ai; stub_rc CHECK N makes one of them exit N; chk NAME [ARGS] runs
# check-audit.sh in $WORK/NAME on 2026-12-02 with those stand-ins (PLUGINS_DIR picks
# another plugins folder, GIT=1 leaves git on, STEP_SUMMARY is the job summary file:
# the CI job's own is never written to); ran and notran read the log.
CON=.ascent/contract.yml
STUBS="ascent-ai/check-ai-design ascent-ai/check-ai-evidence ascent-ai/check-ai-runtime ascent-security/check-env ascent-security/check-dependencies ascent-security/check-threat-model ascent-security/check-redteam ascent-ux/check-flow-integrity ascent-docs/check-docs ascent-delivery/check-acceptance ascent-ops/check-drills ascent-quality/check-test-evidence ascent-adr/check-adrs"

stubs() {  # builds $WORK/stubs and clears the control folder and the log
  rm -rf "${WORK:?}/stubs" "${WORK:?}/ctl"; mkdir -p "$WORK/ctl"; : > "$WORK/log"
  for s in $STUBS; do mkdir -p "$WORK/stubs/${s%/*}/scripts"; cp "$FIX/stub-checker.sh" "$WORK/stubs/${s%/*}/scripts/${s#*/}.sh"; done
  # ascent-ai's detection is the real one: GOV-A1 reads which code belongs to which application
  mkdir -p "$WORK/stubs/ascent-ai/scripts/lib"; cp "$HERE/../../../plugins/ascent-ai/scripts/detect-ai.sh" "$WORK/stubs/ascent-ai/scripts/"
  cp "$HERE/../../../plugins/ascent-ai/scripts/lib/detect.awk" "$WORK/stubs/ascent-ai/scripts/lib/"
}
no_ai() { rm -rf "${WORK:?}/stubs/ascent-ai"; }   # ascent-ai is not installed
stub_rc() { echo "$2" > "$WORK/ctl/$(printf '%s' "$1" | sed 's|/|__|').rc"; }
chk() {  # NAME [ARGS]
  local n="$1"; shift
  (cd "$WORK/$n" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 STUB_LOG="$WORK/log" STUB_CTL="$WORK/ctl" GITHUB_STEP_SUMMARY="${STEP_SUMMARY:-}" \
    bash "$CHECK" --plugins "${PLUGINS_DIR:-$WORK/stubs}" --today "${TODAY:-2026-12-02}" $([ "${GIT:-0}" = 1 ] || echo --no-git) "$@" .) >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
ran()    { if grep -q "^$(printf '%s' "$2" | sed 's|/|__|')\( \|$\)" "$WORK/log"; then ok; else bad "$1: $2 did not run: $(cut -d' ' -f1 "$WORK/log" | tr '\n' ' ')"; fi; }
notran() { if grep -q "^$(printf '%s' "$2" | sed 's|/|__|')\( \|$\)" "$WORK/log"; then bad "$1: $2 ran, and should not have"; else ok; fi; }
contract() { mkdir -p "$WORK/$1/.ascent"; cat > "$WORK/$1/$CON"; }

realpath_of() {
  local p="$1" l
  while [ -L "$p" ]; do l=$(ls -l "$p" | sed 's/.* -> //'); case "$l" in /*) p="$l" ;; *) p="$(dirname "$p")/$l" ;; esac; done
  printf '%s' "$p"
}
run_matrix() {
  local a p r AWKS="default" SEEN
  SEEN=" $(realpath_of "$(command -v awk)") "
  [ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
    p=$(command -v "$a" 2>/dev/null) || continue
    r=$(realpath_of "$p")
    case "$SEEN" in *" $r "*) continue ;; esac
    SEEN="$SEEN$r "; AWKS="$AWKS $a"
  done
  mkdir -p "$WORK/home"
  for AWKNAME in $AWKS; do
    SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
    if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
    matrix
  done
  printf "%s: %s/%s PASS (awk: %s)\n" "$NAME" "$PASS" "$((PASS + FAIL))" "$AWKS"
  [ "$FAIL" -eq 0 ]
}
