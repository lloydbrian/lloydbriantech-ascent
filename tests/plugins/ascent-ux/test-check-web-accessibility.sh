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

UTF8=$(locale -a 2>/dev/null | grep -iE '^(C|en_US)\.utf-?8$' | head -1); UTF8=${UTF8:-C.UTF-8}

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
  for k in UX-U1 UX-U2 UX-U3 UX-U4 UX-U5 UX-U6 UX-U7 UX-U8 UX-U9 UX-U10 UX-U11 UX-U12; do
    printf '%s\n' "$OUT" | grep -q "^PASS  $k " && ok || bad "good fixtures: $k is not PASS (every check must be exercised): $(printf '%s\n' "$OUT" | grep " $k " | head -1)"
  done
  # The good fixtures hide a bad <img> in an HTML comment, a JSX comment and a script
  # body. Unwrapping each one must make UX-U2 fail, which proves the wrapper was skipped.
  mutate cmt-html page.html 's/<!-- <img src="commented-out.png"> must be ignored -->/<img src="commented-out.png">/' && expect_only cmt-html UX-U2
  mutate cmt-jsx Widget.jsx 's/{\/\* <img src="ignored.png"> \*\/}/<img src="ignored.png">/' && expect_only cmt-jsx UX-U2
  mutate cmt-script page.html 's/<script>const fake = "<img src=x>";<\/script>/<img src=x>/' && expect_only cmt-script UX-U2

  mutate u1 page.html 's/<html lang="en">/<html>/' && expect_only u1 UX-U1 Medium
  mutate u2-html page.html 's/ alt="Court 3 at sunset"//' && expect_only u2-html UX-U2 Medium 'page.html:18'
  mutate u2-jsx Widget.jsx 's/ alt={label}//' && expect_only u2-jsx UX-U2
  mutate u2-vue Card.vue 's/ :alt="title"//' && expect_only u2-vue UX-U2
  mutate u2-svelte Item.svelte 's/ alt={name}//' && expect_only u2-svelte UX-U2
  mutate u3-placeholder page.html 's/<input type="text" aria-label="Search">/<input type="text" placeholder="Search">/' && expect_only u3-placeholder UX-U3 Medium 'a placeholder is not a label'
  mutate u3-for Widget.jsx 's/htmlFor="qty"/htmlFor="quantity"/' && expect_only u3-for UX-U3
  mutate u3-svelte Item.svelte 's/<label for="n">Name<\/label>//' && expect_only u3-svelte UX-U3
  mutate u4-html page.html 's/ aria-label="Close dialog"//' && expect_only u4-html UX-U4 Medium '<button> has no accessible name'
  mutate u4-link page.html 's/ alt="Home"/ alt=""/' && expect_only u4-link UX-U4 Medium '<a> has no accessible name'
  mutate u4-vue Card.vue "s/{{ t('open') }}//" && expect_only u4-vue UX-U4
  mutate u5-max page.html 's/initial-scale=1"/initial-scale=1, maximum-scale=1"/' && expect_only u5-max UX-U5 Medium
  mutate u5-scalable page.html 's/initial-scale=1"/initial-scale=1, user-scalable=no"/' && expect_only u5-scalable UX-U5
  mutate u6 page.html 's/tabindex="-1"/tabindex="2"/' && expect_only u6 UX-U6 Low
  mutate u6-jsx Widget.jsx 's/tabIndex={0}/tabIndex={3}/' && expect_only u6-jsx UX-U6
  mutate u7-skip page.html 's/<h3>Form<\/h3>/<h4>Form<\/h4>/' && expect_only u7-skip UX-U7 Low 'from h2 to h4'
  mutate u7-noh1 page.html 's/<h1>Fixture<\/h1>/<p>Fixture<\/p>/' && expect_only u7-noh1 UX-U7 Low 'no <h1>'
  mutate u8 page.html 's/<h2 id="photos">/<h2 id="email">/' && expect_only u8 UX-U8 Low 'duplicate id "email"'
  mutate u9-empty page.html 's/<title>Fixture page<\/title>/<title>  <\/title>/' && expect_only u9-empty UX-U9 Medium 'empty <title>'
  mutate u9-none page.html 's/<title>Fixture page<\/title>//' && expect_only u9-none UX-U9 Medium 'no <title>'
  mutate u10 page.html 's/autoplay muted controls/autoplay/' && expect_only u10 UX-U10 Medium 'no muted and controls'
  mutate u11 page.html 's/:focus-visible { outline: 3px solid #0a58ca; }//' site.css 's/a:focus-visible/a:hover/' Widget.jsx 's/ focus-visible:ring//' && expect_only u11 UX-U11 Medium
  mutate u11-attr page.html 's/:focus-visible { outline: 3px solid #0a58ca; }//' site.css 's/a:focus-visible/a:hover/' Widget.jsx 's/className="link focus-visible:ring"/className="link outline-none"/' && expect_only u11-attr UX-U11
  mutate u12-html page.html 's/ onkeydown="go()"//' && expect_only u12-html UX-U12 Medium 'no a key handler'
  mutate u12-jsx Widget.jsx 's/ role="button" tabIndex={0}//' && expect_only u12-jsx UX-U12 Medium 'no role, tabindex'
  mutate u12-svelte Item.svelte 's/ on:keydown={pick}//' && expect_only u12-svelte UX-U12

  # Template literals in JS views are checked (C1); the h2 -> h4 jump in views.js is
  # not a UX-U7 failure there, because a JS file holds many separate templates.
  mutate js-label views.js 's/<label for="zone-size">Size<\/label>/<span>Size<\/span>/' && expect_only js-label UX-U3 Medium '[js template]'
  mutate js-alt views.js 's/ alt="${zone.name}"//' && expect_only js-alt UX-U2 Medium 'views.js:9'
  mutate js-name views.js "s/\${t('save')}//" && expect_only js-name UX-U4

  # UX-U11 is per selector (C2): an outline removed on .card is not excused by a
  # :focus-visible rule for a different selector.
  mutate u11-selector page.html 's/:focus-visible { outline: 3px solid #0a58ca; }//' && expect_only u11-selector UX-U11 Medium 'removed on .card'
  printf '.x:focus { outline: none; }\n.x:focus-visible { outline: 2px solid; }\n' > "$WORK/covered.css"
  run "$WORK" ./covered.css; [ "$RC" -eq 0 ] && ok || bad "u11: .x:focus-visible must cover .x:focus outline removal: $(printf '%s' "$OUT" | grep FAIL)"
  printf '.x:focus { outline: none; }\n.y:focus-visible { outline: 2px solid; }\n' > "$WORK/uncovered.css"
  run "$WORK" ./uncovered.css; printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U11  Medium ./uncovered.css:1  focus outline removed on .x' && ok || bad "u11: .y:focus-visible must not cover .x"

  # A box-shadow ring in the same :focus rule replaces the outline when one of its
  # layers has 3:1 against the page background, in every theme the CSS defines (C20,
  # 0.3.1); it is a NOTE when the colour or the background cannot be read.
  printf '.x:focus { outline: none; box-shadow: 0 0 0 3px #0a58ca; }\n' > "$WORK/ring.css"
  run "$WORK" ./ring.css; [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^PASS  UX-U11 ' && ! printf '%s\n' "$OUT" | grep -q 'UX-U11.*box-shadow' && ok || bad "u11: a #0a58ca ring on white passes: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  printf '.x:focus { outline: none; box-shadow: 0 0 0 3px #dddddd; }\n' > "$WORK/ring-low.css"
  run "$WORK" ./ring-low.css; [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qF 'FAIL  UX-U11  Medium ./ring-low.css:1  outline on .x is replaced by a box-shadow ring (#dddddd) with 1.35:1 against the page background (white: none is set); a focus indicator needs 3:1 (1.4.11, 2.4.7)' && ok || bad "u11: a #dddddd ring on white fails at 1.35:1: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  printf ':root { --focus: #0a58ca; --bg: #ffffff; }\nbody { background: var(--bg); }\n.x:focus { outline: none; box-shadow: 0 0 0 2px var(--focus); }\n' > "$WORK/ring-token.css"
  run "$WORK" ./ring-token.css; [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q 'UX-U11.*box-shadow' && ok || bad "u11: a token ring on a token background passes: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  printf ':root { --focus: #0a58ca; --bg: #ffffff; }\n@media (prefers-color-scheme: dark) { :root { --bg: #0b1220; } }\nbody { background: var(--bg); }\n.x:focus { outline: none; box-shadow: 0 0 0 2px var(--focus); }\n' > "$WORK/ring-dark.css"
  run "$WORK" ./ring-dark.css; [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep '^FAIL  UX-U11  Medium ./ring-dark.css:4 ' | grep -qF 'against the page background (var(--bg)) in the dark theme' && ok || bad "u11: the same ring fails on the dark background: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  printf '.x:focus { outline: none; box-shadow: 0 0 0 2px #ffffff, 0 0 0 4px rgb(10, 88, 202); }\n' > "$WORK/ring-double.css"
  run "$WORK" ./ring-double.css; [ "$RC" -eq 0 ] && ok || bad "u11: a double ring passes when one layer has 3:1: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  printf '.x:focus { outline: none; box-shadow: 0 0 0 3px rgba(10, 88, 202, 0.3); }\n' > "$WORK/ring-alpha.css"
  run "$WORK" ./ring-alpha.css; [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U11  Medium ./ring-alpha.css:1  outline on .x is replaced by a box-shadow ring (rgba(10, 88, 202, 0.3)) with 1\.' && ok || bad "u11: a translucent ring is blended over the background and fails: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  printf '<html lang="en"><head><title>t</title><style>body { background-color: #000; } .x:focus { outline: none; box-shadow: 0 0 0 3px #222; }</style></head><body><h1>t</h1></body></html>\n' > "$WORK/ring-style.html"
  run "$WORK" ./ring-style.html; [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qF 'with 1.' && printf '%s\n' "$OUT" | grep -qF 'against the page background (#000)' && ok || bad "u11: a <style> block sets the page background: $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  for c in 'currentColor:the ring\047s colour is currentColor' 'teal:the ring\047s colour is a named colour' 'var(--nope):the ring\047s colour is no token nope' 'inset 0 0 0 2px #0a58ca:an inset ring sits on the element\047s own background'; do
    v=${c%%:*}; why=$(printf "${c#*:}")
    printf '.x:focus { outline: none; box-shadow: 0 0 0 3px %s; }\n' "$v" | sed 's/0 0 0 3px inset/inset/' > "$WORK/ring-note.css"
    run "$WORK" ./ring-note.css; [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "NOTE  UX-U11  -      ./ring-note.css:1  outline on .x is replaced by a box-shadow ring; its contrast is not computed: $why (confirm in the browser pass)" && ok || bad "u11: '$v' is a NOTE ($why): $(printf '%s' "$OUT" | grep UX-U11 | tr '\n' ';')"
  done
  printf '.x:focus { outline: none; box-shadow: none; }\n' > "$WORK/ring-none.css"
  run "$WORK" ./ring-none.css; printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U11  Medium ./ring-none.css:1' && ok || bad "u11: box-shadow: none must not replace the outline"
  printf '.x { outline: none; box-shadow: 0 1px 2px #000; }\n' > "$WORK/ring-base.css"
  run "$WORK" ./ring-base.css; printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U11  Medium ./ring-base.css:1' && ok || bad "u11: a shadow outside a :focus rule must not replace the outline"

  # Line numbers stay right after non-ASCII text, and neither valid nor invalid UTF-8
  # stops the scan, in a UTF-8 caller locale (C17). Thirty arrows put 60 more bytes
  # than characters ahead of eight short lines.
  ARROWS=$(printf '\342\206\222%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30)
  printf '/* %s */\n.a{}\n.b{}\n.c{}\n.d{}\n.e{}\n.f{}\n.g{}\n.h{}\n.x:focus { outline: none; }\n' "$ARROWS" > "$WORK/utf8.css"
  (cd "$WORK" && PATH="$SHIM:$PATH" LC_ALL="$UTF8" bash "$CHECK" ./utf8.css) >"$WORK/out" 2>&1; OUT=$(cat "$WORK/out")
  printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U11  Medium ./utf8.css:10 ' && ok || bad "utf8: UX-U11 line must be 10 after non-ASCII text: $(printf '%s' "$OUT" | tail -2 | tr '\n' ';')"
  printf '/* \377\376 */\n.x:focus { outline: none; }\n' > "$WORK/bad-utf8.css"
  (cd "$WORK" && PATH="$SHIM:$PATH" LC_ALL="$UTF8" bash "$CHECK" ./bad-utf8.css) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U11  Medium ./bad-utf8.css:2 ' && ok || bad "utf8: invalid UTF-8 must not stop the scan (exit $RC): $(printf '%s' "$OUT" | tail -2 | tr '\n' ';')"

  # An <h1> rendered only by a JS template is a NOTE on the page, not a FAIL (C18).
  mutate js-h1 page.html 's/<h1>Fixture<\/h1>/<p>Fixture<\/p>/' views.js 's/<h4>Notes<\/h4>/<h1>Notes<\/h1>/'
  run "$WORK/js-h1" .
  [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^NOTE  UX-U7   -      ./page.html:1  no static <h1>; a js template renders one at ./views.js:11 ' && ok || bad "js-h1: expected a UX-U7 NOTE naming views.js:11: $(printf '%s' "$OUT" | grep UX-U7 | tr '\n' ';')"

  # Delegated listeners (C19): the element a click listener finds with
  # e.target.closest() needs role and tabindex, and a key listener in the same file.
  mutate deleg-tab views.js 's/ role="button" tabindex="0" data-pick/ data-pick/' && expect_only deleg-tab UX-U12 Medium 'selector [data-pick] (line 20) but has no role, tabindex; use a <button> (2.1.1) [delegated]'
  mutate deleg-key views.js "/addEventListener('keydown'/d" && expect_only deleg-key UX-U12 Medium 'but has no a key listener'
  printf 'el.addEventListener("click", e => { e.target.closest(".row"); e.target.matches("#go"); e.target.closest(".hdr[data-open]"); other.closest(".card"); });\nconst v = `<div class="row x">a</div><span id="go">b</span><div class="hdr" data-open="1">c</div><div class="card">d</div>`;\n' > "$WORK/deleg.js"
  run "$WORK" ./deleg.js
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  UX-U12  Medium ./deleg.js:2  ')" = 3 ] && printf '%s\n' "$OUT" | grep -qF 'selector .row ' && printf '%s\n' "$OUT" | grep -qF 'selector #go ' && printf '%s\n' "$OUT" | grep -qF 'selector .hdr[data-open] ' && ! printf '%s\n' "$OUT" | grep -qF '.card' && ok || bad "deleg: expected .row, #go and .hdr[data-open], not .card: $(printf '%s' "$OUT" | grep UX-U12 | cut -c1-120 | tr '\n' ';')"
  printf 'el.addEventListener("mouseover", e => e.target.closest(".row"));\nconst v = `<div class="row">a</div>`;\n' > "$WORK/hover.js"
  run "$WORK" ./hover.js; [ "$RC" -eq 0 ] && ok || bad "deleg: closest() without a click listener must not fail UX-U12: $(printf '%s' "$OUT" | grep FAIL)"

  # 0.3.1: a delegated selector from any scanned file, compound selectors and lists;
  # combinators and pseudo-classes are skipped, and a bare tag only matches in its own file.
  rm -rf "$WORK/x"; mkdir -p "$WORK/x"
  printf 'document.body.addEventListener("click", e => { e.target.closest(".card, #go"); e.target.closest(\047div.tile[data-act="go"]\047); e.target.closest(".list > .item"); e.target.closest(".row:not(.off)"); e.target.closest("li"); });\nconst t = `<ul><li>own</li></ul>`;\n' > "$WORK/x/app.js"
  printf '<div class="card">a</div>\n<span id="go">b</span>\n<div class="tile" data-act="go">c</div>\n<div class="tile" data-act="stop">d</div>\n<span class="tile" data-act="go">e</span>\n<ul class="list"><li class="item">f</li></ul>\n<div class="row">g</div>\n<ul><li>h</li></ul>\n' > "$WORK/x/part.html"
  run "$WORK/x" .
  got=$(printf '%s\n' "$OUT" | grep '^FAIL  UX-U12 ' | sed 's/^FAIL  UX-U12  Medium //; s/  .*selector / /; s/ but has.*//' | tr '\n' ';')
  want='./app.js:2 li (line 1);./part.html:1 .card (./app.js:1);./part.html:2 #go (./app.js:1);./part.html:3 div.tile[data-act="go"] (./app.js:1);'
  [ "$got" = "$want" ] && ok || bad "deleg-cross: expected [$want], got [$got]"
  printf 'document.addEventListener("keydown", e => {});\n' >> "$WORK/x/app.js"
  run "$WORK/x" .
  [ "$(printf '%s\n' "$OUT" | grep '^FAIL  UX-U12 ' | grep -c 'a key listener')" = 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  UX-U12 ')" = 4 ] && ok || bad "deleg-cross: a key listener in the listener's file excuses the key handler: $(printf '%s' "$OUT" | grep UX-U12 | tr '\n' ';')"

  # --core raises UX-U3 and UX-U12 to High, and only in the named file.
  mutate core page.html 's/<input type="text" aria-label="Search">/<input type="text">/' page.html 's/ onkeydown="go()"//' Widget.jsx 's/ onKeyDown={save}//'
  run "$WORK/core" --core page.html .
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  UX-U3   High   ./page.html')" = 1 ] && ok || bad "core: UX-U3 in page.html is not High"
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  UX-U12  High   ./page.html')" = 1 ] && ok || bad "core: UX-U12 in page.html is not High"
  printf '%s\n' "$OUT" | grep -q '^FAIL  UX-U12  Medium ./Widget.jsx' && ok || bad "core: UX-U12 outside the core file must stay Medium"

  # --core accepts a leading ./ as well (C5).
  run "$GOOD" --core ./page.html .; [ "$RC" -eq 0 ] && ok || bad "--core ./page.html must be accepted: $(printf '%s' "$OUT" | tail -1)"

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
