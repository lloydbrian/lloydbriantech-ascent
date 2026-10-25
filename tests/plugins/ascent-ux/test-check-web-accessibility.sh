#!/usr/bin/env bash
# Behavior test for plugins/ascent-ux/scripts/check-web-accessibility.sh.
#
# The good fixtures (HTML, JSX, Vue, Svelte and CSS) must pass all 12 checks, with
# every check exercised (PASS, never N/A). Then each check gets negative controls: a
# copy of the fixtures broken in exactly one way must fail that check and no other,
# in each template syntax where the check applies. Also covers --core severities,
# comments and script bodies ignored, capitalized components skipped, the shipped
# blueprint, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-web-accessibility: N/N PASS" last (make/test-plugins.sh T11).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ux"
CHECK="$PLUGIN/scripts/check-web-accessibility.sh"
GOOD="$HERE/fixtures/good"
BP="$PLUGIN/blueprints/accessible-page"
for f in "$CHECK" "$GOOD/page.html" "$BP/index.html"; do [ -e "$f" ] || { echo "test-check-web-accessibility: missing $f"; echo "test-check-web-accessibility: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { (cd "$1" && PATH="$SHIM:$PATH" bash "$CHECK" "${@:2}") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); }

# mutate NAME FILE SED-EXPR [FILE SED-EXPR ...]: a copy of the good fixtures with each
# FILE edited; an edit that changes nothing is reported as a stale anchor.
mutate() {
  local name="$1"; shift
  rm -rf "$WORK/$name"; cp -R "$GOOD" "$WORK/$name"
  while [ $# -ge 2 ]; do
    sed "$2" "$WORK/$name/$1" > "$WORK/tmp" && mv "$WORK/tmp" "$WORK/$name/$1.new"
    if cmp -s "$WORK/$name/$1" "$WORK/$name/$1.new"; then bad "$name: edit to $1 changed nothing (stale anchor)"; rm -f "$WORK/$name/$1.new"; return 1; fi
    mv "$WORK/$name/$1.new" "$WORK/$name/$1"; shift 2
  done
}
# expect_only NAME CHECK [SEVERITY] [TEXT]: the mutant fails exactly CHECK (once or more), nothing else.
expect_only() {
  run "$WORK/$1" .
  local nf other
  nf=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  other=$(printf '%s\n' "$OUT" | grep '^FAIL' | grep -v "^FAIL  $2 " | cut -c1-70 | tr '\n' ';')
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s' "$OUT" | tail -2 | tr '\n' ';')"
  elif [ "$nf" -lt 1 ]; then bad "$1: $2 did not fail"
  elif [ -n "$other" ]; then bad "$1: expected only $2 to fail, also got: $other"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep "^FAIL  $2 " | grep -q " $3 "; then bad "$1: $2 is not $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2 " | head -1)"
  elif [ -n "${4:-}" ] && ! printf '%s\n' "$OUT" | grep "^FAIL  $2 " | grep -qF "$4"; then bad "$1: $2 message lacks '$4'"
  else ok; fi
}

matrix() {
  # Baseline: every check runs and passes on the good fixtures.
  run "$GOOD" .
  if [ "$RC" -ne 0 ]; then bad "good fixtures fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -3 | tr '\n' ';')"; else ok; fi
  for k in U1 U2 U3 U4 U5 U6 U7 U8 U9 U10 U11 U12; do
    printf '%s\n' "$OUT" | grep -q "^PASS  $k " && ok || bad "good fixtures: $k is not PASS (every check must be exercised): $(printf '%s\n' "$OUT" | grep " $k " | head -1)"
  done
  # The good fixtures hide a bad <img> in an HTML comment, a JSX comment and a script
  # body. Unwrapping each one must make U2 fail, which proves the wrapper was skipped.
  mutate cmt-html page.html 's/<!-- <img src="commented-out.png"> must be ignored -->/<img src="commented-out.png">/' && expect_only cmt-html U2
  mutate cmt-jsx Widget.jsx 's/{\/\* <img src="ignored.png"> \*\/}/<img src="ignored.png">/' && expect_only cmt-jsx U2
  mutate cmt-script page.html 's/<script>const fake = "<img src=x>";<\/script>/<img src=x>/' && expect_only cmt-script U2

  mutate u1 page.html 's/<html lang="en">/<html>/' && expect_only u1 U1 Medium
  mutate u2-html page.html 's/ alt="Court 3 at sunset"//' && expect_only u2-html U2 Medium 'page.html:18'
  mutate u2-jsx Widget.jsx 's/ alt={label}//' && expect_only u2-jsx U2
  mutate u2-vue Card.vue 's/ :alt="title"//' && expect_only u2-vue U2
  mutate u2-svelte Item.svelte 's/ alt={name}//' && expect_only u2-svelte U2
  mutate u3-placeholder page.html 's/<input type="text" aria-label="Search">/<input type="text" placeholder="Search">/' && expect_only u3-placeholder U3 Medium 'a placeholder is not a label'
  mutate u3-for Widget.jsx 's/htmlFor="qty"/htmlFor="quantity"/' && expect_only u3-for U3
  mutate u3-svelte Item.svelte 's/<label for="n">Name<\/label>//' && expect_only u3-svelte U3
  mutate u4-html page.html 's/ aria-label="Close dialog"//' && expect_only u4-html U4 Medium '<button> has no accessible name'
  mutate u4-link page.html 's/ alt="Home"/ alt=""/' && expect_only u4-link U4 Medium '<a> has no accessible name'
  mutate u4-vue Card.vue "s/{{ t('open') }}//" && expect_only u4-vue U4
  mutate u5-max page.html 's/initial-scale=1"/initial-scale=1, maximum-scale=1"/' && expect_only u5-max U5 Medium
  mutate u5-scalable page.html 's/initial-scale=1"/initial-scale=1, user-scalable=no"/' && expect_only u5-scalable U5
  mutate u6 page.html 's/tabindex="-1"/tabindex="2"/' && expect_only u6 U6 Low
  mutate u6-jsx Widget.jsx 's/tabIndex={0}/tabIndex={3}/' && expect_only u6-jsx U6
  mutate u7-skip page.html 's/<h3>Form<\/h3>/<h4>Form<\/h4>/' && expect_only u7-skip U7 Low 'from h2 to h4'
  mutate u7-noh1 page.html 's/<h1>Fixture<\/h1>/<p>Fixture<\/p>/' && expect_only u7-noh1 U7 Low 'no <h1>'
  mutate u8 page.html 's/<h2 id="photos">/<h2 id="email">/' && expect_only u8 U8 Low 'duplicate id "email"'
  mutate u9-empty page.html 's/<title>Fixture page<\/title>/<title>  <\/title>/' && expect_only u9-empty U9 Medium 'empty <title>'
  mutate u9-none page.html 's/<title>Fixture page<\/title>//' && expect_only u9-none U9 Medium 'no <title>'
  mutate u10 page.html 's/autoplay muted controls/autoplay/' && expect_only u10 U10 Medium 'no muted and controls'
  mutate u11 page.html 's/:focus-visible { outline: 3px solid #0a58ca; }//' site.css 's/a:focus-visible/a:hover/' Widget.jsx 's/ focus-visible:ring//' && expect_only u11 U11 Medium
  mutate u11-attr page.html 's/:focus-visible { outline: 3px solid #0a58ca; }//' site.css 's/a:focus-visible/a:hover/' Widget.jsx 's/className="link focus-visible:ring"/className="link outline-none"/' && expect_only u11-attr U11
  mutate u12-html page.html 's/ onkeydown="go()"//' && expect_only u12-html U12 Medium 'no a key handler'
  mutate u12-jsx Widget.jsx 's/ role="button" tabIndex={0}//' && expect_only u12-jsx U12 Medium 'no role, tabindex'
  mutate u12-svelte Item.svelte 's/ on:keydown={pick}//' && expect_only u12-svelte U12

  # --core raises U3 and U12 to High, and only in the named file.
  mutate core page.html 's/<input type="text" aria-label="Search">/<input type="text">/' page.html 's/ onkeydown="go()"//' Widget.jsx 's/ onKeyDown={save}//'
  run "$WORK/core" --core ./page.html .
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  U3   High   ./page.html')" = 1 ] && ok || bad "core: U3 in page.html is not High"
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  U12  High   ./page.html')" = 1 ] && ok || bad "core: U12 in page.html is not High"
  printf '%s\n' "$OUT" | grep -q '^FAIL  U12  Medium ./Widget.jsx' && ok || bad "core: U12 outside the core file must stay Medium"

  # Capitalized components are skipped; a lowercase element with the same problem is not.
  mutate comp Widget.jsx 's/<Button onClick={save}>Save<\/Button>/<Button onClick={save} \/>/'
  run "$WORK/comp" .; [ "$RC" -eq 0 ] && ok || bad "comp: a capitalized component was checked as a <button>"

  # The shipped blueprint passes.
  run "$BP" .
  [ "$RC" -eq 0 ] && ok || bad "blueprint fails: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -3 | tr '\n' ';')"

  # Bad input stops with exit 2.
  run "$WORK" ./no-such-dir; [ "$RC" -eq 2 ] && ok || bad "missing path: expected exit 2, got $RC"
  printf 'x\n' > "$WORK/notes.txt"; run "$WORK" ./notes.txt; [ "$RC" -eq 2 ] && ok || bad "unsupported file: expected exit 2, got $RC"
  mkdir -p "$WORK/empty"; run "$WORK/empty" .; [ "$RC" -eq 2 ] && ok || bad "no markup: expected exit 2, got $RC"
  run "$GOOD" --core ./missing.html .; [ "$RC" -eq 2 ] && ok || bad "--core outside the scan: expected exit 2, got $RC"
}

realpath_of() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")"); }
AWKS="default"; SEEN=" $(realpath_of "$(command -v awk)") "
[ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
  p=$(command -v "$a" 2>/dev/null) || continue
  r=$(realpath_of "$p")
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; AWKS="$AWKS $a"
done
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-check-web-accessibility: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
