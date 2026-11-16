#!/usr/bin/env bash
# Behavior test for make/gate-scope.sh (ADR-023): which slow checks a change runs.
#
# Runs the scope script on fixture changes (paths, and a diff of
# make/test-mutants.sh and Makefile) against a fixture list of controls and
# fixture behavior tests, and checks all five outputs of each case: what a rule
# must run, and that nothing else runs. Then checks that the repository's own
# behavior tests that read files outside their plugin are found. Then checks the repository's own list of controls (make/test-mutants.sh
# --list): eight fields a line, ids unique, the groups those of --groups-json, and
# every file a control edits present, so a control can be found by its file.
# Usage: test-gate-scope.sh [SCOPE]   (defaults to make/gate-scope.sh)
# Prints "test-gate-scope: N/N PASS" last (make/test-plugins.sh T15).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
SCOPE="${1:-$HERE/../../make/gate-scope.sh}"
[ -f "$SCOPE" ] || { echo "test-gate-scope: missing $SCOPE"; echo "test-gate-scope: 0/1 PASS"; exit 1; }
ROOT="$(cd "$(dirname "$SCOPE")/.." && pwd)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }

# The fixture controls: group, id, label, kind, file, T11 scope, T13.0, T14.
TAB=$(printf '\t')
cat > "$WORK/manifest" <<EOF
alpha${TAB}P901-alpha-script${TAB}T11${TAB}edit${TAB}plugins/alpha/scripts/a.sh${TAB}alpha${TAB}0${TAB}0
alpha-two${TAB}P902-alpha-skill${TAB}T7${TAB}edit${TAB}plugins/alpha/skills/x/SKILL.md${TAB}alpha${TAB}0${TAB}0
beta${TAB}P903-beta-script${TAB}T11${TAB}edit${TAB}plugins/beta/scripts/b.sh${TAB}beta${TAB}0${TAB}0
ownership${TAB}P904-own-readme${TAB}T13.11${TAB}edit${TAB}README.md${TAB}none${TAB}0${TAB}0
ownership${TAB}P911-own-registry${TAB}T13.2${TAB}edit${TAB}docs/framework/OWNERSHIP.md${TAB}none${TAB}0${TAB}0
ownership-checker${TAB}P905-own-checker${TAB}T13.0${TAB}edit${TAB}make/check-ownership.sh${TAB}none${TAB}1${TAB}0
ownership${TAB}P906-own-blueprint${TAB}T13.3${TAB}rm${TAB}plugins/beta/blueprints/site${TAB}none${TAB}0${TAB}0
harness${TAB}P907-harness-gate${TAB}T14.G2${TAB}edit${TAB}make/test-plugins.sh${TAB}all${TAB}0${TAB}1
harness${TAB}P908-harness-docs${TAB}T5${TAB}expect${TAB}docs/framework/PHILOSOPHY.md${TAB}all${TAB}0${TAB}0
harness${TAB}P910-harness-guides${TAB}T5${TAB}rm${TAB}docs/guides${TAB}none${TAB}0${TAB}0
scope${TAB}P909-scope-rule${TAB}T15${TAB}edit${TAB}make/gate-scope.sh${TAB}all${TAB}0${TAB}0
EOF
# Fixture behavior tests: alpha's read a template directory and a reference file
# outside the plugin (and its own files); beta's read every plugin's directory.
mkdir -p "$WORK/tests/alpha" "$WORK/tests/beta"
cat > "$WORK/tests/alpha/test-a.sh" <<'T'
ROOT="$HERE/../../.."
cat "$ROOT/skills/lloydbriantech-ascent/references/contract.md" "$ROOT/plugins/alpha/scripts/a.sh"
ls "$HERE/../../../skills/lloydbriantech-ascent/assets/template/"
T
cat > "$WORK/tests/beta/test-b.sh" <<'T'
for d in "$PLUGIN"/../ascent-*/; do echo "$d"; done
T
EVERY='[{"name":"core","group":"core","ids":""},{"name":"alpha","group":"alpha","ids":""},{"name":"alpha-two","group":"alpha-two","ids":""},{"name":"beta","group":"beta","ids":""},{"name":"ownership","group":"ownership","ids":""},{"name":"ownership-checker","group":"ownership-checker","ids":""},{"name":"harness","group":"harness","ids":""},{"name":"scope","group":"scope","ids":""}]'
FULLRUN="full=1 t11=all t13_selftest=1 harness=[\"test-gate-sections\",\"test-mutants-harness\"] targets=$EVERY"
g() { printf '{"name":"%s","group":"%s","ids":""}' "$1" "$1"; }   # GROUP — a whole group's target
sel() { printf '{"name":"selected","group":"all","ids":"%s"}' "$*"; }   # IDS — the selected controls' target

paths() { printf '%s\n' "$@" > "$WORK/paths"; : > "$WORK/diff"; }   # PATH... — a new case's changed paths
diff_of() {  # FILE — the case's diff of FILE, from stdin (lines with + or -)
  { printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1 +1 @@\n' "$1" "$1" "$1" "$1"; cat; } >> "$WORK/diff"
}
# expect NAME [KEY=VALUE ...] [-- ARGS] — run the scope; the keys not named must
# be what an empty change gives: nothing beyond the cheap checks
expect() {
  local name=$1 kv want got rc=0; shift
  local full=0 t11=none t13_selftest=0 harness='[]' targets='[]' args=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --) shift; args="$*"; break ;;
      full=*) full=${1#*=} ;; t11=*) t11=${1#*=} ;; t13_selftest=*) t13_selftest=${1#*=} ;;
      harness=*) harness=${1#*=} ;; targets=*) targets=${1#*=} ;;
    esac
    shift
  done
  # shellcheck disable=SC2086
  ASCENT_SCOPE_MANIFEST="$WORK/manifest" ASCENT_SCOPE_PATHS="$WORK/paths" ASCENT_SCOPE_DIFF="$WORK/diff" \
    ASCENT_SCOPE_TESTS="${SCOPE_TESTS-$WORK/tests}" bash "$SCOPE" $args > "$WORK/out" 2> "$WORK/err" || rc=$?
  [ "$rc" -eq 0 ] || { bad "$name: exit $rc: $(head -2 "$WORK/err" | tr '\n' ';')"; return; }
  for kv in "full=$full" "t11=$t11" "t13_selftest=$t13_selftest" "harness=$harness" "targets=$targets"; do
    got=$(grep "^${kv%%=*}=" "$WORK/out")
    [ "$got" = "$kv" ] || { bad "$name: expected $kv, got '$got'"; return; }
  done
  ok
}
expect_full() { expect "$1" $FULLRUN; }   # NAME — the case must run everything

# Nothing beyond the cheap checks
paths; expect empty-change
paths CHANGELOG.md docs/framework/ROADMAP.md .github/PULL_REQUEST_TEMPLATE.md LICENSE-MIT tools/scratch/README.md .claude-plugin/marketplace.json make/plugins.lock
expect docs-only
paths skills/lloydbriantech-ascent/SKILL.md; expect parent-skill-not-template

# The controls whose file a path is, or whose directory it is in
paths README.md; expect readme-controls "targets=[$(sel P904-own-readme)]"
paths docs/framework/PHILOSOPHY.md README.md; expect two-files "targets=[$(sel P904-own-readme P908-harness-docs)]"
paths docs/guides/start.md; expect directory-control "targets=[$(sel P910-harness-guides)]"

# Plugins: T11 for the plugin, its groups and ownership
paths plugins/alpha/scripts/a.sh
expect plugin-alpha "t11=alpha beta" "targets=[$(g alpha),$(g alpha-two),$(g ownership)]"
paths tests/plugins/beta/test-b.sh; expect plugin-tests-beta t11=beta "targets=[$(g beta),$(g ownership)]"
paths plugins/beta/scripts/b.sh plugins/alpha/README.md
expect two-plugins "t11=alpha beta" "targets=[$(g alpha),$(g alpha-two),$(g beta),$(g ownership)]"
paths plugins/beta/blueprints/site/main.yaml docs/framework/PHILOSOPHY.md
expect plugin-and-docs t11=beta "targets=[$(g beta),$(g ownership),$(sel P908-harness-docs)]"
paths plugins/gamma/x.sh; expect new-plugin "t11=beta gamma" "targets=[$(g ownership)]"

# Behavior tests that read files outside their plugin
paths skills/lloydbriantech-ascent/references/contract.md; expect reader-file t11=alpha
paths skills/lloydbriantech-ascent/references/other.md; expect reader-other-file
paths skills/lloydbriantech-ascent/assets/template/backend/health.js
expect reader-directory t11=alpha "targets=[$(g core)]"

# The ownership checker, the registry, the template and the meta tests
paths make/check-ownership.sh; expect checker t13_selftest=1 "targets=[$(g ownership),$(g ownership-checker)]"
paths tests/meta/test-check-ownership.sh; expect checker-tests t13_selftest=1 "targets=[$(g ownership),$(g ownership-checker)]"
paths docs/framework/OWNERSHIP.md; expect registry "targets=[$(g ownership)]"
paths make/mutants.tsv; expect mutants-tsv "targets=[$(g core)]"
paths make/render-template.sh; expect_full render-template
paths tests/meta/test-gate-fast.sh; expect gate-fast-tests "targets=[$(g harness)]"
paths tests/meta/test-gate-scope.sh; expect scope-tests "targets=[$(g scope)]"
paths tests/meta/test-gate-sections.sh; expect sections-test 'harness=["test-gate-sections"]'
paths tests/meta/test-mutants-harness.sh; expect harness-test 'harness=["test-mutants-harness"]'

# Everything
for p in make/test-plugins.sh make/gate-scope.sh .github/workflows/validate-skills.yml make/test.mk \
         make/qa-links.sh tests/meta/new-test.sh plugins/README.md scripts/new.sh; do
  paths "$p"; expect_full "everything: $p"
done
paths README.md; expect full-flag $FULLRUN -- --full

# Makefile: the version line alone runs nothing more
paths Makefile
diff_of Makefile <<'D'
-FRAMEWORK_VERSION := 0.4.17
+FRAMEWORK_VERSION := 0.4.18
D
expect makefile-version
paths Makefile
diff_of Makefile <<'D'
+include make/extra.mk
D
expect_full makefile-other
paths Makefile; expect_full makefile-no-diff

# make/test-mutants.sh: control lines run their controls, anything else everything
paths make/test-mutants.sh
diff_of make/test-mutants.sh <<'D'
-plugin_case P901-alpha-script T11 "$A" 's/x/y/'
+plugin_case P901-alpha-script T11 "$A" 's/x/z/'
+T13_SELFTEST=1 plugin_case P905-own-checker T13.0 "$CHKO" 's/a/b/'
D
expect harness-control-lines "targets=[$(sel P901-alpha-script P905-own-checker)]"
paths make/test-mutants.sh
diff_of make/test-mutants.sh <<'D'
+expect_case SURVIVED P908-harness-docs T5 docs/framework/PHILOSOPHY.md 's/a/b/'
D
expect harness-group-control 'harness=["test-mutants-harness"]' "targets=[$(sel P908-harness-docs)]"
paths make/test-mutants.sh; expect_full harness-no-diff-found
paths make/check-ownership.sh docs/framework/OWNERSHIP.md README.md
expect checker-whole-groups t13_selftest=1 "targets=[$(g ownership),$(g ownership-checker)]"
paths make/test-mutants.sh
diff_of make/test-mutants.sh <<'D'
-plugin_case P999-removed T11 "$A" 's/x/y/'
+# a comment
+
D
expect harness-removed-and-comment
paths make/test-mutants.sh
diff_of make/test-mutants.sh <<'D'
+validator_case V09-new pass ascent-x ascent-x "Use when asked to do x."
D
expect harness-validator "targets=[$(g core)]"
paths make/test-mutants.sh
diff_of make/test-mutants.sh <<'D'
+plugin_case P901-alpha-script T11 "$A" 's/x/z/'
+JOBS=2
D
expect_full harness-other-line
paths make/test-mutants.sh
diff_of make/test-mutants.sh <<'D'
+plugin_case P998-not-listed T11 "$A" 's/x/z/'
D
expect_full harness-unlisted-control

# Errors
rc=0; bash "$SCOPE" --no-such-flag >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then ok; else bad "unknown argument: exit $rc, expected 2"; fi
paths plugins/alpha/scripts/a.sh
ASCENT_SCOPE_MANIFEST="$WORK/manifest" ASCENT_SCOPE_PATHS="$WORK/paths" ASCENT_SCOPE_TESTS="$WORK/none" bash "$SCOPE" --explain >/dev/null 2>"$WORK/err"
if grep -q '^  plugins/alpha/scripts/a.sh  *plugin alpha: T11 for alpha' "$WORK/err" && grep -q '^  T11  *alpha$' "$WORK/err"; then ok
else bad "--explain does not give the path's rule and what runs: $(head -3 "$WORK/err" | tr '\n' ';')"; fi

# The repository's own behavior tests: ascent-ops reads the observability
# contract and the template, and ascent-architecture reads every plugin's directory
SCOPE_TESTS="" ; paths skills/lloydbriantech-ascent/references/observability-contract.md
expect real-reader-ops t11=ascent-ops
paths skills/lloydbriantech-ascent/assets/template/backend/routes/health.js
expect real-reader-template t11=ascent-ops "targets=[$(g core)]"
paths plugins/gamma/x.sh; expect real-reader-every-plugin "t11=ascent-architecture gamma" "targets=[$(g ownership)]"
unset SCOPE_TESTS

# The repository's own controls
# every group, whatever group the caller runs (a negative control runs this inside one)
export ASCENT_MUTANT_GROUP= ASCENT_MUTANT_IDS=
if bash "$ROOT/make/test-mutants.sh" --list > "$WORK/real" 2> "$WORK/real.err" && [ -s "$WORK/real" ]; then
  if awk -F'\t' 'NF != 8 || $2 !~ /^P[0-9]+-/ || $4 !~ /^(edit|rm|expect)$/ || $7 !~ /^[01]$/ || $8 !~ /^[01]$/ { bad = 1 } END { exit bad }' "$WORK/real"; then ok
  else bad "a --list line is malformed: $(awk -F'\t' 'NF != 8 || $2 !~ /^P[0-9]+-/' "$WORK/real" | head -1)"; fi
  dup=$(cut -f2 "$WORK/real" | sort | uniq -d | head -3 | tr '\n' ' ')
  if [ -z "$dup" ]; then ok; else bad "control ids used twice: $dup"; fi
  want=$(bash "$ROOT/make/test-mutants.sh" --groups-json | tr -d '[]"' | tr ',' ' ' | sed 's/^core //')
  have=$(awk -F'\t' '!seen[$1]++ { print $1 }' "$WORK/real" | tr '\n' ' ' | sed 's/ $//')
  if [ "$want" = "$have" ]; then ok; else bad "the listed groups ($have) are not --groups-json's ($want)"; fi
  missing=$(cut -f5 "$WORK/real" | sort -u | while IFS= read -r f; do [ -e "$ROOT/$f" ] || printf '%s ' "$f"; done)
  if [ -z "$missing" ]; then ok; else bad "controls edit files that do not exist: $missing"; fi
else
  bad "make/test-mutants.sh --list failed: $(head -2 "$WORK/real.err" | tr '\n' ';')"
fi

printf "test-gate-scope: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
