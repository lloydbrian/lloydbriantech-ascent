#!/usr/bin/env bash
# Plugin gate (ADR-009). Checks every plugin under ROOT/plugins/:
#   T1  generated skills match a fresh `make plugins` build (no hand edits, no orphans)
#   T2  no <<PLACEHOLDER>> tokens anywhere in a plugin
#   T3  names and versions agree: directory, plugin.json, marketplace entry, skills;
#       every marketplace source resolves to a plugin directory
#   T4  agents are read-only: tools a subset of Read, Grep, Glob, and no frontmatter
#       keys beyond name, description, tools, model, color
#   T4b skills pre-approve only read tools: Read, Grep, Glob, Bash(git ls-files:*),
#       Bash(git log:*)
#   T5  every skill that classifies findings carries the shared severity table,
#       and all copies are identical; every copy of the architecture severity
#       table (arch-severity markers), the UX severity table (ux-severity markers),
#       the operations severity table (ops-severity markers) and the dependency
#       severity table (dep-severity markers) is identical too
#   T6  relative links inside a plugin resolve (anchors and titles stripped) and
#       never point at a template skill (ascent-*/SKILL.md)
#   T7  skill frontmatter passes qa-skill-frontmatter
#   T8  `claude plugin validate` passes (SKIP when the CLI is absent or skipped)
#   T9  every "<skill> Step N" an agent cites names a skill in its plugin and a
#       "### Step N" heading that exists; an agent must cite at least one step
#   T10 any change to a plugin's files comes with a plugin.json version bump:
#       make/plugins.lock records version and content hash (make/plugin-hash.sh);
#       same version with a different hash fails, as does an unrecorded version
#   T11 every plugin with hooks/ or scripts/ has behavior tests in
#       tests/plugins/<plugin>/test-*.sh that all pass; each test must end with
#       "<test-name>: N/N PASS" (N > 0). A plugin with hooks or scripts but no
#       tests fails, and so does a script no test file names. A plugin with
#       hooks/ also needs a hooks.json whose
#       ${CLAUDE_PLUGIN_ROOT} script paths exist.
#   T12 plugin.json uses only known manifest keys (a misspelled key such as
#       "dependencis" passes claude plugin validate but is silently ignored), and
#       every dependency on another marketplace is allowlisted in the
#       marketplace's allowCrossMarketplaceDependenciesOn (without it the plugin
#       installs but fails to load; ADR-012)
#   T13 the ownership registry docs/framework/OWNERSHIP.md matches the
#       repository (ADR-015): T13.1-T13.10 from make/check-ownership.sh, one
#       result each, and T13.0 runs that checker's own fixture tests
#       (tests/meta/test-check-ownership.sh)
#
# Usage: test-plugins.sh [ROOT]   (ROOT defaults to the repo root)
#        ASCENT_SKIP_CLAUDE_CLI=1 skips T8 (the negative controls use this so they
#        give the same answer with or without the CLI installed).
#        ASCENT_T11_ONLY=<plugin> runs T11 for that plugin only. make test-mutants sets it
#        when a control edits one plugin's files, which keeps the suite fast; running
#        fewer tests can only make a control harder to kill, never easier.
#        ASCENT_T13_SELFTEST=0 skips T13.0. make test-mutants sets it, except for the
#        controls that edit the ownership checker itself.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+.

set -euo pipefail

ROOT="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf "PASS  test-plugins: %s\n" "$1"; }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  test-plugins: %s\n" "$1"; }

# Skills that must carry the shared severity table (T5), as plugin:skill.
SEVERITY_SKILLS="ascent-security:security-audit ascent-security:sec-posture"

json_field() {  # FILE KEY — top-level "KEY": "value" (2-space indent) in a manifest
  sed -n "s/^  \"$2\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}

# marketplace_entry FILE NAME — prints the body of the plugins[] object whose
# "name" is NAME. Assumes one key per line, as written by hand and by `jq`.
marketplace_entry() {
  awk -v want="$2" '
    /"plugins"[[:space:]]*:/ { inp = 1; next }
    inp && !inent && /^[[:space:]]*\{/ { buf = ""; depth = 1; inent = 1; next }
    inent {
      if ($0 ~ /\{/) depth++
      if ($0 ~ /\}/) depth--
      if (depth == 0) {
        if (buf ~ ("\"name\":[[:space:]]*\"" want "\"")) { printf "%s", buf; exit }
        inent = 0; next
      }
      buf = buf $0 "\n"
    }' "$1"
}

PLUGINS=$(cd "$ROOT/plugins" 2>/dev/null && ls -d */ 2>/dev/null | tr -d / || true)
if [ -z "$PLUGINS" ]; then
  echo "test-plugins: no plugins under $ROOT/plugins"
  exit 1
fi
MKT="$ROOT/.claude-plugin/marketplace.json"

# T1 — drift and orphans
if bash "$ROOT/make/build-plugins.sh" "$WORK/fresh" >/dev/null; then
  DRIFT=""
  for f in $(cd "$WORK/fresh" && find plugins -name SKILL.md | LC_ALL=C sort); do
    cmp -s "$WORK/fresh/$f" "$ROOT/$f" || DRIFT="$DRIFT $f"
  done
  for f in $(cd "$ROOT" && grep -rl '^<!-- GENERATED by make plugins' plugins 2>/dev/null | LC_ALL=C sort); do
    [ -f "$WORK/fresh/$f" ] || DRIFT="$DRIFT $f(orphan)"
  done
  if [ -z "$DRIFT" ]; then ok "T1 generated skills match a fresh build"; else bad "T1 drift — edit the template source and run make plugins:$DRIFT"; fi
else
  bad "T1 build-plugins failed"
fi

# T2 — placeholders
LEFT=$(grep -rlE '<<[A-Z_]+>>' "$ROOT/plugins" 2>/dev/null || true)
if [ -z "$LEFT" ]; then ok "T2 no template placeholders in plugins"; else bad "T2 placeholders in: $LEFT"; fi

# T3 — names, versions and sources
for p in $PLUGINS; do
  PJ="$ROOT/plugins/$p/.claude-plugin/plugin.json"
  name=$(json_field "$PJ" name); ver=$(json_field "$PJ" version)
  entry=$(marketplace_entry "$MKT" "$p")
  mkt_ver=$(printf '%s\n' "$entry" | sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  mkt_src=$(printf '%s\n' "$entry" | sed -n 's/.*"source":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  problems=""
  [ -n "$ver" ] || problems="$problems plugin.json has no version;"
  [ "$name" = "$p" ] || problems="$problems plugin.json name '$name' != dir '$p';"
  if [ -z "$entry" ]; then
    problems="$problems no marketplace entry named '$p';"
  else
    [ "$mkt_src" = "./plugins/$p" ] || problems="$problems marketplace source '$mkt_src' != './plugins/$p';"
    [ "$mkt_ver" = "$ver" ] || problems="$problems marketplace version '$mkt_ver' != plugin.json '$ver';"
  fi
  for s in "$ROOT/plugins/$p"/skills/*/SKILL.md; do
    [ -f "$s" ] || continue
    sd=$(basename "$(dirname "$s")")
    sn=$(sed -n 's/^name:[[:space:]]*//p' "$s" | head -1)
    sv=$(sed -n 's/^version:[[:space:]]*//p' "$s" | head -1)
    [ "$sn" = "$sd" ] || problems="$problems skill $sd has name '$sn';"
    [ "$sv" = "$ver" ] || problems="$problems skill $sd version '$sv' != '$ver';"
  done
  if [ -z "$problems" ]; then ok "T3 $p: names, versions and marketplace source agree (v$ver)"; else bad "T3 $p:$problems"; fi
done
for src in $(sed -n 's/.*"source":[[:space:]]*"\(\.\/[^"]*\)".*/\1/p' "$MKT"); do
  [ -d "$ROOT/$src/.claude-plugin" ] || bad "T3 marketplace source $src is not a plugin directory"
done

# T4 — read-only agents
for a in "$ROOT"/plugins/*/agents/*.md; do
  [ -f "$a" ] || continue
  fm=$(awk '/^---$/{c++; next} c==1' "$a")
  tools=$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p')
  extra=$(printf '%s\n' "$tools" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE '^(Read|Grep|Glob)$' | grep -v '^$' || true)
  keys=$(printf '%s\n' "$fm" | sed -n 's/^\([A-Za-z_-]*\):.*/\1/p' | grep -vE '^(name|description|tools|model|color)$' || true)
  if [ -n "$tools" ] && [ -z "$extra" ] && [ -z "$keys" ]; then
    ok "T4 $(basename "$a" .md) is read-only ($tools)"
  else
    bad "T4 $(basename "$a" .md): tools must be a subset of Read, Grep, Glob (got '${tools:-none declared}'); unexpected keys: '$(printf '%s' "${keys:-none}" | tr '\n' ' ')'"
  fi
done

# T4b — skills pre-approve read tools only
for s in "$ROOT"/plugins/*/skills/*/SKILL.md; do
  [ -f "$s" ] || continue
  allowed=$(awk '/^---$/{c++; next} c!=1{next} /^allowed-tools:/{f=1; v=$0; sub(/^allowed-tools:[[:space:]]*/, "", v); if (v != "") print v; next} f && /^[[:space:]]+- /{sub(/^[[:space:]]+- /, ""); print; next} {f=0}' "$s" \
    | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"\(.*\)"$/\1/' | grep -v '^$' || true)
  wide=$(printf '%s\n' "$allowed" | grep -vE '^(Read|Grep|Glob|Bash\(git ls-files:\*\)|Bash\(git log:\*\))$' | grep -v '^$' || true)
  sk="$(basename "$(dirname "$(dirname "$(dirname "$s")")")")/$(basename "$(dirname "$s")")"
  if [ -z "$wide" ]; then ok "T4b $sk pre-approves read tools only"; else bad "T4b $sk pre-approves non-read tools: $(printf '%s' "$wide" | tr '\n' ' ')"; fi
done

# T5 — shared severity table in every skill that needs it, identical everywhere
table() { awk '/<!-- severity-table:start/{on=1; next} /<!-- severity-table:end/{on=0} on' "$1"; }
FIRST=""; T5_OK=1; N5=0
for ps in $SEVERITY_SKILLS; do
  f="$ROOT/plugins/${ps%%:*}/skills/${ps#*:}/SKILL.md"
  if [ ! -f "$f" ] || [ -z "$(table "$f" | grep '^|' || true)" ]; then T5_OK=0; bad "T5 $ps has no severity table"; continue; fi
  N5=$((N5 + 1))
  if [ -z "$FIRST" ]; then FIRST="$f"; elif [ "$(table "$f")" != "$(table "$FIRST")" ]; then T5_OK=0; bad "T5 severity table in $ps differs"; fi
done
for f in $(grep -rl 'severity-table:start' "$ROOT/plugins" "$ROOT/skills" 2>/dev/null | LC_ALL=C sort || true); do
  if [ -n "$FIRST" ] && [ "$(table "$f")" != "$(table "$FIRST")" ]; then T5_OK=0; bad "T5 severity table in ${f#"$ROOT"/} differs"; fi
done
[ "$T5_OK" -eq 1 ] && ok "T5 severity table present in $N5 plugin skills and identical everywhere"
# marked_table MARKER LABEL — every copy of a table between <!-- MARKER:start --> and
# <!-- MARKER:end --> in plugins/ is non-empty and identical to the first copy.
marked_table() {
  local m="$1" label="$2" f first="" n=0 good=1
  for f in $(grep -rl "$m:start" "$ROOT/plugins" 2>/dev/null | LC_ALL=C sort || true); do
    n=$((n + 1))
    if [ -z "$(awk -v m="$m" 'index($0, "<!-- " m ":start") {on=1; next} index($0, "<!-- " m ":end") {on=0} on' "$f" | grep '^|' || true)" ]; then good=0; bad "T5 $label severity table in ${f#"$ROOT"/} is empty"
    elif [ -z "$first" ]; then first="$f"
    elif [ "$(awk -v m="$m" 'index($0, "<!-- " m ":start") {on=1; next} index($0, "<!-- " m ":end") {on=0} on' "$f")" != "$(awk -v m="$m" 'index($0, "<!-- " m ":start") {on=1; next} index($0, "<!-- " m ":end") {on=0} on' "$first")" ]; then good=0; bad "T5 $label severity table in ${f#"$ROOT"/} differs from ${first#"$ROOT"/}"; fi
  done
  [ "$n" -gt 0 ] && [ "$good" -eq 1 ] && ok "T5 $label severity table identical in $n files"
  return 0
}
marked_table arch-severity architecture
marked_table ux-severity UX
marked_table ops-severity operations
marked_table dep-severity dependency

# T6 — links
BROKEN=""
for f in $(find "$ROOT/plugins" -name '*.md' | LC_ALL=C sort); do
  d=$(dirname "$f")
  rel=${f#"$ROOT"/}
  while IFS= read -r l; do
    l=${l%% \"*}; l=${l%%#*}
    case "$l" in ''|http:*|https:*|mailto:*) continue ;; esac
    case "$l" in *ascent-*/SKILL.md) BROKEN="$BROKEN $rel->$l(points-at-template)"; continue ;; esac
    case "$rel" in plugins/*/README.md) continue ;; esac
    [ -e "$d/$l" ] || BROKEN="$BROKEN $rel->$l"
  done <<EOF_LINKS
$(grep -oE '\]\([^)]+\)' "$f" | sed 's/^](//;s/)$//' || true)
EOF_LINKS
done
if [ -z "$BROKEN" ]; then ok "T6 plugin links resolve and stay inside the plugin"; else bad "T6 broken links:$BROKEN"; fi

# T7 — frontmatter
if bash "$ROOT/make/qa-skill-frontmatter.sh" "$ROOT/plugins" >/dev/null 2>&1; then ok "T7 plugin skill frontmatter valid"; else bad "T7 qa-skill-frontmatter failed on plugins/"; fi

# T8 — official validator
if [ "${ASCENT_SKIP_CLAUDE_CLI:-0}" != "1" ] && command -v claude >/dev/null 2>&1; then
  V=0
  for p in $PLUGINS; do claude plugin validate "$ROOT/plugins/$p" >/dev/null 2>&1 || { V=1; bad "T8 claude plugin validate plugins/$p"; }; done
  claude plugin validate "$ROOT" >/dev/null 2>&1 || { V=1; bad "T8 claude plugin validate marketplace"; }
  [ "$V" -eq 0 ] && ok "T8 claude plugin validate: plugins and marketplace"
else
  printf "SKIP  test-plugins: T8 claude CLI not installed or skipped — run 'claude plugin validate' before release\n"
fi

# T9 — agent step references ("security-audit Step 4", "env-audit Steps 2–3")
for a in "$ROOT"/plugins/*/agents/*.md; do
  [ -f "$a" ] || continue
  pdir=$(dirname "$(dirname "$a")")
  MISSING_REFS=""; NREFS=0
  refs=$(sed 's/`//g' "$a" | grep -oE '[a-z][a-z0-9]*-[a-z0-9-]+ Steps? [0-9][0-9, –-]*' || true)
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    skill=${ref%% Step*}
    if [ ! -f "$pdir/skills/$skill/SKILL.md" ]; then MISSING_REFS="$MISSING_REFS $skill(no such skill)"; continue; fi
    for n in $(printf '%s' "${ref#* Step}" | tr -cs '0-9' ' '); do
      NREFS=$((NREFS + 1))
      grep -q "^### Step $n " "$pdir/skills/$skill/SKILL.md" || MISSING_REFS="$MISSING_REFS $skill#$n"
    done
  done <<EOF_REFS
$refs
EOF_REFS
  if [ -n "$MISSING_REFS" ]; then bad "T9 $(basename "$a" .md) cites steps or skills that do not exist:$MISSING_REFS"
  elif [ "$NREFS" -eq 0 ]; then bad "T9 $(basename "$a" .md) cites no skill steps — an agent must trace its checks to skill steps"
  else ok "T9 $(basename "$a" .md): $NREFS step references resolve"; fi
done

# T10 — content changes need a version bump (make/plugins.lock)
LOCK="$ROOT/make/plugins.lock"
for p in $PLUGINS; do
  ver=$(json_field "$ROOT/plugins/$p/.claude-plugin/plugin.json" version)
  hash=$(bash "$ROOT/make/plugin-hash.sh" "$ROOT/plugins/$p")
  row=$([ -f "$LOCK" ] && awk -F'\t' -v p="$p" '$1 == p { print; exit }' "$LOCK" || true)
  lock_ver=$(printf '%s' "$row" | cut -f2); lock_hash=$(printf '%s' "$row" | cut -f3)
  if [ -z "$row" ] || [ "$lock_ver" != "$ver" ]; then
    bad "T10 $p: version $ver not recorded in make/plugins.lock — run make plugins"
  elif [ "$lock_hash" != "$hash" ]; then
    bad "T10 $p: content changed but version still $ver — bump the version"
  else
    ok "T10 $p: content matches the version recorded in make/plugins.lock (v$ver)"
  fi
done

# T11 — behavior tests for plugins that ship executable code (hooks or scripts)
for p in $PLUGINS; do
  [ -n "${ASCENT_T11_ONLY:-}" ] && [ "$p" != "$ASCENT_T11_ONLY" ] && continue
  [ -d "$ROOT/plugins/$p/hooks" ] || [ -d "$ROOT/plugins/$p/scripts" ] || continue
  problems=""
  if [ -d "$ROOT/plugins/$p/hooks" ]; then
    HJ="$ROOT/plugins/$p/hooks/hooks.json"
    if [ -f "$HJ" ]; then
      for ref in $(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$HJ" | sed 's|^\${CLAUDE_PLUGIN_ROOT}/||' | LC_ALL=C sort -u); do
        [ -f "$ROOT/plugins/$p/$ref" ] || problems="$problems hooks.json runs missing $ref;"
      done
    else
      problems="$problems hooks/ has no hooks.json;"
    fi
  fi
  TESTS=$(ls "$ROOT/tests/plugins/$p"/test-*.sh 2>/dev/null | LC_ALL=C sort || true)
  if [ -z "$TESTS" ]; then
    bad "T11 $p ships hooks/ or scripts/ but has no tests under tests/plugins/$p/ (test-*.sh)"; continue
  fi
  for sc in "$ROOT/plugins/$p"/scripts/*; do
    [ -f "$sc" ] || continue
    grep -qF "$(basename "$sc")" $TESTS 2>/dev/null || problems="$problems scripts/$(basename "$sc") is not exercised by any test;"
  done
  NTESTS=0; NCASES=0
  for t in $TESTS; do
    NTESTS=$((NTESTS + 1)); tn=$(basename "$t" .sh)
    if bash "$t" </dev/null >"$WORK/t11.out" 2>&1; then
      summary=$(sed -n "s/^$tn: \([0-9][0-9]*\)\/\([0-9][0-9]*\) PASS.*/\1 \2/p" "$WORK/t11.out" | tail -1)
      x=${summary%% *}; y=${summary##* }
      if [ -z "$summary" ] || [ "$x" != "$y" ] || [ "$y" -eq 0 ]; then
        problems="$problems $tn passed without a '$tn: N/N PASS' summary (N > 0);"
      else
        NCASES=$((NCASES + y))
      fi
    else
      # awk reads to the end: grep | head would die of SIGPIPE on long output, and
      # under set -e and pipefail this assignment would end the gate before T11 printed
      problems="$problems $tn failed: $(awk '/^FAIL/ { if (++n <= 3) print }' "$WORK/t11.out" | cut -c1-100 | tr '\n' ';')"
    fi
  done
  if [ -z "$problems" ]; then ok "T11 $p: $NTESTS behavior test file(s), $NCASES cases pass"; else bad "T11 $p:$problems"; fi
done

# T12 — manifest keys and cross-marketplace dependencies
KNOWN_KEYS=" name version description author homepage repository license keywords dependencies commands agents skills hooks mcpServers lspServers outputStyles icon userConfig defaultEnabled "
OWN_MKT=$(json_field "$MKT" name)
ALLOW=$(sed -n 's/^  "allowCrossMarketplaceDependenciesOn":[[:space:]]*\[\(.*\)\].*/\1/p' "$MKT" | tr -d ' "' | tr ',' ' ')
for p in $PLUGINS; do
  PJ="$ROOT/plugins/$p/.claude-plugin/plugin.json"
  problems=""
  for k in $(sed -n 's/^  "\([^"]*\)":.*/\1/p' "$PJ"); do
    case "$KNOWN_KEYS" in *" $k "*) ;; *) problems="$problems unknown manifest key '$k';" ;; esac
  done
  deps=$(awk '/^  "dependencies":[[:space:]]*\[/{on=1; next} on && /^  \]/{on=0} on' "$PJ")
  for m in $(printf '%s\n' "$deps" | sed -n 's/.*"[^"@]*@\([^"]*\)".*/\1/p; s/.*"marketplace":[[:space:]]*"\([^"]*\)".*/\1/p' | LC_ALL=C sort -u); do
    [ "$m" = "$OWN_MKT" ] && continue
    case " $ALLOW " in *" $m "*) ;; *) problems="$problems dependency marketplace '$m' is not in allowCrossMarketplaceDependenciesOn;" ;; esac
  done
  if [ -z "$problems" ]; then ok "T12 $p: manifest keys known, cross-marketplace dependencies allowlisted"; else bad "T12 $p:$problems"; fi
done

# T13 — ownership registry (ADR-015)
if [ "${ASCENT_T13_SELFTEST:-1}" != 0 ]; then
  ST="$ROOT/tests/meta/test-check-ownership.sh"
  if [ ! -f "$ST" ]; then bad "T13.0 checker self-test: tests/meta/test-check-ownership.sh not found"
  elif out=$(bash "$ST" "$ROOT/make/check-ownership.sh" 2>&1) && last=$(printf '%s\n' "$out" | tail -1) \
       && n=$(printf '%s' "$last" | sed -n 's|^test-check-ownership: \([1-9][0-9]*\)/\([0-9]*\) PASS.*|\1 \2|p') \
       && [ -n "$n" ] && [ "${n% *}" = "${n#* }" ]; then
    ok "T13.0 checker self-test: ${last#test-check-ownership: }"
  else
    bad "T13.0 checker self-test: $(printf '%s\n' "$out" | grep '^FAIL' | head -3 | tr '\n' ';')"
  fi
fi
N13=0
while IFS= read -r line; do
  case "$line" in
    "PASS  T13."*) N13=$((N13 + 1)); ok "${line#PASS  }" ;;
    "FAIL  T13."*) N13=$((N13 + 1)); bad "${line#FAIL  }" ;;
  esac
done <<EOF_T13
$(bash "$ROOT/make/check-ownership.sh" "$ROOT" 2>&1 || true)
EOF_T13
# A checker that stops early must not pass by printing less (T13.1 alone when the registry is missing).
[ "$N13" -ge 10 ] || bad "T13 ownership checker printed $N13 of 10 results"

printf "\ntest-plugins: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
