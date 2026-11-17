#!/usr/bin/env bash
# Behavior test for plugins/ascent-ux/scripts/check-flow-integrity.sh (ADR-022).
#
# The good fixtures (a plain HTML site, React Router, Vue Router and SvelteKit) must
# pass UX-F1, F2, F3, F4 and F7, with every check exercised (PASS, never N/A). Then
# each check gets negative controls: a copy of the fixtures broken in exactly one way
# must fail that check and no other, in each syntax where the check applies. Also
# covers severities (core files High), --base, comments ignored, runtime-built links
# as NOTEs, route and component steps as NOTEs, line numbers after non-ASCII text,
# and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-flow-integrity: N/N PASS" last (make/test-plugins.sh T11).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ux"
CHECK="$PLUGIN/scripts/check-flow-integrity.sh"
GOOD="$HERE/fixtures/flows-good"
for f in "$CHECK" "$GOOD/site/index.html" "$GOOD/react/src/main.jsx"; do [ -e "$f" ] || { echo "test-check-flow-integrity: missing $f"; echo "test-check-flow-integrity: 0/1 PASS"; exit 1; }; done

UTF8=$(locale -a 2>/dev/null | grep -iE '^(C|en_US)\.utf-?8$' | head -1); UTF8=${UTF8:-C.UTF-8}
FLOW="enter-score=site/index.html,site/score.html,site/confirm.html"
BROWSERS="last-2-evergreen,ios-safari-17"

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { (cd "$1" && PATH="$SHIM:$PATH" bash "$CHECK" "${@:2}") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); }
# The standard run: the enter-score flow and the contract browsers.
std() { run "$1" --flow "$FLOW" --browsers "$BROWSERS" "${@:2}" .; }

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
# verdict NAME CHECKS [SEVERITY] [TEXT]: the last run failed every check in CHECKS
# (space-separated) and nothing else; SEVERITY and TEXT apply to the first check.
verdict() {
  local name="$1" checks="$2" first other c
  first=${checks%% *}
  other=$(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-70)
  for c in $checks; do other=$(printf '%s\n' "$other" | grep -v "^FAIL  $c " || true); done
  other=$(printf '%s' "$other" | tr '\n' ';')
  if [ "$RC" -ne 1 ]; then bad "$name: expected exit 1, got $RC: $(printf '%s' "$OUT" | tail -2 | tr '\n' ';')"; return; fi
  for c in $checks; do printf '%s\n' "$OUT" | grep -q "^FAIL  $c " || { bad "$name: $c did not fail"; return; }; done
  if [ -n "$other" ]; then bad "$name: expected only $checks to fail, also got: $other"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep "^FAIL  $first " | grep -q " $3 "; then bad "$name: $first is not $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $first " | head -1)"
  elif [ -n "${4:-}" ] && ! printf '%s\n' "$OUT" | grep "^FAIL  $first " | grep -qF -- "$4"; then bad "$name: $first message lacks '$4': $(printf '%s\n' "$OUT" | grep "^FAIL  $first " | head -1)"
  else ok; fi
}
# expect NAME CHECKS [SEVERITY] [TEXT]: the standard run on mutant NAME.
expect() { std "$WORK/$1"; verdict "$@"; }
clean() { if [ "$RC" -eq 0 ]; then ok; else bad "$1: expected a clean run, got exit $RC: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -3 | tr '\n' ';')"; fi; }
has_line() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
# passes NAME RULE: the last run printed PASS for RULE, so the rule ran and was met.
passes() { if printf '%s\n' "$OUT" | grep -q "^PASS  $2 "; then ok; else bad "$1: $2 did not pass: $(printf '%s\n' "$OUT" | grep " $2 " | head -1)"; fi; }

matrix() {
  # Baseline: every check runs and passes on the good fixtures.
  std "$GOOD"; clean "good fixtures"
  for k in UX-F1 UX-F2 UX-F3 UX-F4 UX-F7; do
    printf '%s\n' "$OUT" | grep -q "^PASS  $k " && ok || bad "good fixtures: $k is not PASS (every check must be exercised): $(printf '%s\n' "$OUT" | grep " $k " | head -1)"
  done
  # Runtime-built links are NOTEs, never failures.
  has_line "notes" "NOTE  UX-F1   -      ./react/src/Teams.jsx:11  1 link(s) not resolved statically"
  has_line "notes" "NOTE  UX-F1   -      ./vue/src/App.vue:5  1 link(s) not resolved statically"

  # Comments are skipped: unwrapping each one must make UX-F1 fail.
  mutate cmt-html site/index.html 's/<!-- <a href="old-page.html">must be ignored<\/a> -->/<a href="old-page.html">x<\/a>/' && expect cmt-html UX-F1 High 'old-page.html'
  mutate cmt-jsx react/src/Teams.jsx 's/{\/\* <Link to="\/archive">must be ignored<\/Link> \*\/}/<Link to="\/archive">x<\/Link>/' && expect cmt-jsx UX-F1 Medium '"/archive"'

  # UX-F1: links, form actions, router links and navigation calls.
  mutate f1-html site/index.html 's/<a href="score.html">/<a href="scores.html">/' && expect f1-html UX-F1 High 'site/index.html:6  link "scores.html" resolves to no file'
  mutate f1-root site/index.html 's|href="/score.html?court=3#form"|href="/nope.html?court=3#form"|' && expect f1-root UX-F1 High '"/nope.html?...#form" resolves to no file or route'
  mutate f1-help site/help/index.html 's|<a href="../score.html">|<a href="../scorez.html">|' && expect f1-help UX-F1 Medium 'site/help/index.html:4'
  mutate f1-climb site/help/index.html 's|<a href="../index.html">|<a href="../../../index.html">|' && expect f1-climb UX-F1 Medium 'climbs above the scanned tree'
  mutate f1-form site/score.html 's/action="confirm.html"/action="confirmed.html"/' && expect f1-form UX-F1 High '"confirmed.html"'
  mutate f1-react react/src/Teams.jsx 's|<Link to="/teams/3">|<Link to="/players/3">|' && expect f1-react UX-F1 Medium '"/players/3"'
  mutate f1-react-brace react/src/Teams.jsx 's|to={"/teams/7/players"}|to={"/teams/7/roster"}|' && expect f1-react-brace UX-F1 Medium '"/teams/7/roster"'
  mutate f1-navigate react/src/Teams.jsx 's|navigate("/teams/9")|navigate("/team/9")|' && expect f1-navigate UX-F1 Medium '"/team/9"'
  mutate f1-vue vue/src/App.vue 's|<router-link to="/about">|<router-link to="/abut">|' && expect f1-vue UX-F1 Medium '"/abut"'
  mutate f1-vue-bound vue/src/App.vue "s|:to=\"'/scores/4'\"|:to=\"'/score/4'\"|" && expect f1-vue-bound UX-F1 Medium '"/score/4"'
  mutate f1-vue-child vue/src/App.vue 's|to="/scores/4/edit"|to="/scores/4/delete"|' && expect f1-vue-child UX-F1 Medium '"/scores/4/delete"'
  mutate f1-svelte svelte/src/routes/+page.svelte 's|<a href="/scores/7">|<a href="/score/7">|' && expect f1-svelte UX-F1 Medium '"/score/7"'
  mutate f1-goto svelte/src/routes/+page.svelte "s|goto('/scores/8')|goto('/scorez/8')|" && expect f1-goto UX-F1 Medium '"/scorez/8"'
  mutate f1-dynamic-route react/src/main.jsx 's|{ path: "/teams/:teamId", element: <Teams /> },||' && expect f1-dynamic-route UX-F1 Medium '"/teams/3"'

  # --base strips the deployment base path; without it the link fails.
  mutate base site/index.html 's|href="/score.html?court=3#form"|href="/app/score.html?court=3#form"|'
  std "$WORK/base" --base /app; clean "base: --base /app resolves /app/score.html"
  std "$WORK/base"; verdict base-missing UX-F1 High '"/app/score.html?...#form"'

  # UX-F2: in-page anchors and ARIA targets.
  mutate f2-anchor site/index.html 's/<a href="#main" class="skip">/<a href="#content" class="skip">/' && expect f2-anchor UX-F2 High 'anchor "#content" has no element with that id'
  mutate f2-controls site/index.html 's/aria-controls="menu"/aria-controls="menus"/' && expect f2-controls UX-F2 High 'aria-controls "menus" names no element'
  mutate f2-describedby site/score.html 's/aria-describedby="home-hint"/aria-describedby="home-help"/' && expect f2-describedby UX-F2 High '"home-help"'
  mutate f2-labelledby react/src/Teams.jsx 's/aria-labelledby="teams-title"/aria-labelledby="team-title"/' && expect f2-labelledby UX-F2 Medium '"team-title"'
  mutate f2-vue vue/src/App.vue 's/aria-controls="panel"/aria-controls="panels"/' && expect f2-vue UX-F2 Medium '"panels"'
  mutate f2-svelte svelte/src/routes/+page.svelte 's/aria-describedby="q-hint"/aria-describedby="q-help"/' && expect f2-svelte UX-F2 Medium '"q-help"'
  mutate f2-top site/index.html 's/<a href="#main" class="skip">/<a href="#top" class="skip">/'
  std "$WORK/f2-top"; clean "f2: #top needs no target"
  mutate f2-dynid react/src/Teams.jsx 's/aria-labelledby="teams-title"/aria-labelledby="team-title"/' react/src/Teams.jsx 's/<h2 id="teams-title">/<h2 id={titleId}>/'
  std "$WORK/f2-dynid"; clean "f2: a runtime id makes a missing target a NOTE"
  has_line "f2-dynid" 'NOTE  UX-F2   -      ./react/src/Teams.jsx:6  aria-labelledby "team-title" has no static target'

  # UX-F3: a way forward (High) and a way back or out (Medium).
  mutate f3-script site/score.html 's/<form id="form" action="confirm.html" method="post">/<form id="form" method="post">/'
  std "$WORK/f3-script"; clean "f3: a navigation in a script the page loads is a way forward"
  mutate f3-forward site/score.html 's/<form id="form" action="confirm.html" method="post">/<form id="form" method="post">/' site/score.html 's|<script src="js/app.js"></script>||' && expect f3-forward UX-F3 High 'step 2 has no link, form or navigation to the next step site/confirm.html'
  mutate f3-out site/confirm.html 's|<a href="./">Back to the league</a>||' && expect f3-out UX-F3 Medium 'step 3 has no way back or out'
  mutate f3-out-mid site/score.html 's|<a href="index.html">Cancel</a>||' && expect f3-out-mid UX-F3 Medium 'step 2 has no way back or out'
  mutate f3-back-label site/score.html 's|<a href="index.html">Cancel</a>|<button type="button" aria-label="Cancel">x</button>|'
  std "$WORK/f3-back-label"; clean "f3: a button labelled Cancel is a way out"
  mutate f3-back-history site/score.html 's|<a href="index.html">Cancel</a>|<button type="button" onclick="history.back()">x</button>|'
  std "$WORK/f3-back-history"; clean "f3: history.back() is a way out"
  SFLOW="browse=svelte/src/routes/+page.svelte,svelte/src/routes/scores/[id]/+page.svelte"
  run "$GOOD" --flow "$SFLOW" --browsers "$BROWSERS" .; clean "f3: a SvelteKit flow reaches /scores/[id]"
  mutate f3-svelte svelte/src/routes/+page.svelte 's|<a href="/scores/7">|<a href="/">|' svelte/src/routes/+page.svelte "s|goto('/scores/8')|goto('/')|"
  run "$WORK/f3-svelte" --flow "$SFLOW" --browsers "$BROWSERS" .; verdict f3-svelte UX-F3 High 'next step svelte/src/routes/scores/[id]/+page.svelte'
  run "$GOOD" --flow "spa=/teams,/teams/3" --browsers "$BROWSERS" .
  clean "f3: route steps are not failed"; has_line "f3-route" 'step /teams is a route, not a file; the browser walk (UX-F5) checks it'
  run "$GOOD" --flow "spa=react/src/Teams.jsx,react/src/main.jsx" --browsers "$BROWSERS" .
  clean "f3: component steps are not failed"; has_line "f3-component" 'is a component without a file-based route'

  # UX-F3, 0.3.1 (from the 0.3.0 trial): with more than one HTML page, a full page with no
  # link, form, button, script, back control or refresh is a dead end (Low; Medium in a
  # --core file, like a core step with no way out). One page
  # alone, a page with a script, an external link or a refresh, and a flow step are not.
  rm -rf "$WORK/dead"; mkdir -p "$WORK/dead"
  printf '<html lang="en"><head><title>Home</title></head><body><h1>Home</h1><a href="thanks.html">Thanks</a> <a href="ext.html">e</a> <a href="spa.html">s</a> <a href="refresh.html">r</a></body></html>\n' > "$WORK/dead/index.html"
  printf '<html lang="en"><head><title>Thanks</title></head><body><h1>Thanks</h1><p>All done.</p></body></html>\n' > "$WORK/dead/thanks.html"
  printf '<html lang="en"><head><title>E</title></head><body><a href="https://example.org/">Elsewhere</a></body></html>\n' > "$WORK/dead/ext.html"
  printf '<html lang="en"><head><title>S</title></head><body><div id="root"></div><script src="main.js"></script></body></html>\n' > "$WORK/dead/spa.html"
  printf 'console.log(1)\n' > "$WORK/dead/main.js"
  printf '<html lang="en"><head><title>R</title><meta http-equiv="refresh" content="3; url=index.html"></head><body><p>Moving.</p></body></html>\n' > "$WORK/dead/refresh.html"
  run "$WORK/dead" .
  [ "$RC" -eq 1 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  UX-F3 ')" = 1 ] && printf '%s\n' "$OUT" | grep -qF "FAIL  UX-F3   Low    ./thanks.html:1  the page has no link, form, button or script: a user can leave it only with the browser's back button (a dead end)" && ok || bad "f3-dead: only thanks.html is a dead end: $(printf '%s' "$OUT" | grep 'UX-F3' | tr '\n' ';')"
  run "$WORK/dead" --core thanks.html .
  printf '%s\n' "$OUT" | grep -q '^FAIL  UX-F3   Medium \./thanks\.html:1  the page has no link' && ok || bad "f3-dead: a dead end in a --core file is Medium: $(printf '%s' "$OUT" | grep 'UX-F3' | tr '\n' ';')"
  run "$WORK/dead" --flow "done=index.html,thanks.html" .
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  UX-F3 ')" = 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL  UX-F3   Medium .\/thanks.html:1  flow done: step 2 has no way back or out' && ok || bad "f3-dead: a flow step is reported once, by the flow rule: $(printf '%s' "$OUT" | grep 'UX-F3' | tr '\n' ';')"
  run "$WORK/dead" ./thanks.html
  ! printf '%s\n' "$OUT" | grep -q '^FAIL  UX-F3 ' && ok || bad "f3-dead: one page alone is not a dead end: $(printf '%s' "$OUT" | grep 'UX-F3' | tr '\n' ';')"

  # UX-F4: a not-found page, a catch-all route or a server fallback, per app.
  for app in site react vue svelte; do run "$GOOD/$app" .; printf '%s\n' "$OUT" | grep -q '^PASS  UX-F4 ' && ok || bad "f4: $app alone must pass UX-F4: $(printf '%s\n' "$OUT" | grep UX-F4)"; done
  rm -rf "$WORK/f4"; cp -R "$GOOD/site" "$WORK/f4"; rm "$WORK/f4/404.html"
  run "$WORK/f4" .; verdict f4-site UX-F4 Low 'the app has no not-found page'
  printf 'server {\n  error_page 404 /404.html;\n}\n' > "$WORK/f4/nginx.conf"; run "$WORK/f4" .; clean "f4: nginx error_page 404"; passes f4-nginx UX-F4
  rm "$WORK/f4/nginx.conf"; printf '/*  /404.html  404\n' > "$WORK/f4/_redirects"; run "$WORK/f4" .; clean "f4: _redirects 404"; passes f4-redirects UX-F4
  mutate f4-react react/src/main.jsx 's|{ path: "\*", element: <p>Not found</p> },||' && { run "$WORK/f4-react/react" .; verdict f4-react UX-F4 Low; }
  mutate f4-vue vue/src/router/index.js "s|{ path: '/:pathMatch(.\*)\*', component: Home },||" && { run "$WORK/f4-vue/vue" .; verdict f4-vue UX-F4 Low; }
  rm -rf "$WORK/f4-svelte"; cp -R "$GOOD/svelte" "$WORK/f4-svelte"; rm "$WORK/f4-svelte/src/routes/+error.svelte"
  run "$WORK/f4-svelte" .; verdict f4-svelte UX-F4 Low

  # UX-F7: build targets against the contract browsers.
  mutate f7-none react/package.json '/"browserslist"/d' react/package.json 's/"devDependencies": { "vite": "5.4.8" },/"devDependencies": { "vite": "5.4.8" }/' && expect f7-none UX-F7 Low 'declares no browser targets'
  mutate f7-exclude react/package.json 's/"last 2 safari versions"/"not safari"/' && expect f7-exclude UX-F7 Low 'exclude safari'
  mutate f7-only react/package.json 's/"browserslist": \[.*\]/"browserslist": ["chrome >= 120"]/' && expect f7-only UX-F7 Low 'leave out firefox'
  mutate f7-defaults react/package.json 's/"browserslist": \[.*\]/"browserslist": ["defaults"]/'; std "$WORK/f7-defaults"; clean "f7: defaults covers the contract"
  mutate f7-string react/package.json 's/"browserslist": \[.*\]/"browserslist": "chrome >= 120, firefox >= 120, edge >= 120, safari >= 17, ios_saf >= 17"/'; std "$WORK/f7-string"; clean "f7: a string browserslist naming every family"
  mutate f7-rc react/package.json '/"browserslist"/d' react/package.json 's/"devDependencies": { "vite": "5.4.8" },/"devDependencies": { "vite": "5.4.8" }/'
  printf '# targets\nlast 2 versions\nnot dead\n' > "$WORK/f7-rc/react/.browserslistrc"; std "$WORK/f7-rc"; clean "f7: a .browserslistrc declares targets"
  printf 'not firefox\n' >> "$WORK/f7-rc/react/.browserslistrc"; std "$WORK/f7-rc"; verdict f7-rc-exclude UX-F7 Low 'exclude firefox'
  mutate f7-nobuild react/package.json '/"browserslist"/d' react/package.json 's/"scripts": { "build": "vite build" },//' react/package.json 's/,$//' react/package.json 's/"devDependencies": { "vite": "5.4.8" }//'
  std "$WORK/f7-nobuild"; printf '%s\n' "$OUT" | grep -q '^N/A   UX-F7 ' && ok || bad "f7: no build step must be N/A: $(printf '%s\n' "$OUT" | grep UX-F7)"
  run "$GOOD" .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-F7 ' && ok || bad "f7: no --browsers must be N/A"

  # --core raises UX-F1 and UX-F2 to High in the named file only.
  mutate core site/help/index.html 's|<a href="../score.html">|<a href="../scorez.html">|'
  std "$WORK/core" --core site/help/index.html; verdict core UX-F1 High 'site/help/index.html:4'
  run "$GOOD" --core ./site/help/index.html .; clean "--core ./path is accepted"

  # Trial calibration (2026-11-13): shapes found in real repositories.
  mkdir -p "$WORK/tr/site/public" "$WORK/tr/site/views" "$WORK/tr/site/js"
  printf '<!doctype html>\n<a href="#later">Later</a>\n<p>Reset: <code>rm -rf /conf/* \&\& reboot</code></p>\n<h2 id="later">Later</h2>\n<script>\n/* a real comment */ const x = 1;\nel.innerHTML = %s<a href="%s + url + %s">x</a>%s;\n</script>\n' "'" "'" "'" "'" > "$WORK/tr/site/public/index.html"
  printf '<!doctype html>\n<p>About</p>\n<a href="index.html">Home</a>\n' > "$WORK/tr/site/public/about.html"
  printf '<a href="about.html">About</a>\n<a href="index.html">Home</a>\n' > "$WORK/tr/site/views/home.eta"
  printf 'const b = document.createElement("button");\nb.setAttribute("x", "y");\nheader.innerHTML = "<button aria-controls=\\"nav\\">Menu</button>";\n' > "$WORK/tr/site/js/header.js"
  printf '<!doctype html>\n<nav id="nav"></nav>\n<a href="about.html">About</a>\n' > "$WORK/tr/site/public/shell.html"
  printf 'server { error_page 404 /index.html; }\n' > "$WORK/tr/site/nginx.conf"
  run "$WORK/tr/site" .; clean "trial: prose /* , concatenated href, template served from public/, id in another file"
  has_line "trial-concat" 'NOTE  UX-F1   -      ./public/index.html:7  1 link(s) not resolved statically'
  has_line "trial-crossid" 'NOTE  UX-F2   -      ./js/header.js:3  aria-controls "nav" is not in this file; public/shell.html defines it, so confirm in the browser'
  printf '<a href="missing.html">Gone</a>\n' >> "$WORK/tr/site/views/home.eta"
  run "$WORK/tr/site" .; verdict trial-eta-missing UX-F1 Medium 'views/home.eta:3  link "missing.html" resolves to no file'
  # pages/ is a folder name in a Vite app, and file routes in Next
  mkdir -p "$WORK/tr/vite/src/pages"; printf '<!doctype html><div id="root"></div>\n' > "$WORK/tr/vite/index.html"
  printf 'export default function A() { return <p>a</p>; }\n' > "$WORK/tr/vite/src/pages/Registration.jsx"
  printf '{ "dependencies": { "react": "19.1.0" }, "devDependencies": { "vite": "6.3.5" } }\n' > "$WORK/tr/vite/package.json"
  run "$WORK/tr/vite" .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-F4 ' && ok || bad "trial: a single page with a pages/ folder and no router must be N/A for UX-F4: $(printf '%s\n' "$OUT" | grep UX-F4)"
  printf '{ "dependencies": { "next": "15.0.0", "react": "19.1.0" } }\n' > "$WORK/tr/vite/package.json"
  run "$WORK/tr/vite" .; verdict trial-next-pages UX-F4 Low

  # Review before release (2026-11-13): inputs that ordinary projects have.
  R="$WORK/rv"; mkdir -p "$R/abs/site" "$R/abs/sub" "$R/rr/src/components" "$R/rr/src/routes" "$R/vue/src" "$R/hash" "$R/ex/views" "$R/bl" "$R/ids" "$R/big"
  printf '<a href="b.html">b</a>\n' > "$R/abs/site/a.html"; printf '<a href="a.html">a</a>\n' > "$R/abs/site/b.html"; printf '<p>gone</p>\n' > "$R/abs/site/404.html"
  run "$R/abs" "$R/abs/site"; clean "review: an absolute PATH resolves relative links"
  run "$R/abs/sub" ../site; clean "review: a ../ PATH resolves relative links"
  printf 'export const Header = () => <nav><Link to="/about">About</Link><Link to="/invoices/7">Invoice</Link></nav>;\n' > "$R/rr/src/components/Header.jsx"
  printf 'export const AppRoutes = () => (\n  <Routes>\n    <Route path="/about" element={<About />} />\n    <Route path="invoices" element={<Invoices />}>\n      <Route path=":invoiceId" element={<Invoice />} />\n    </Route>\n    <Route path="*" element={<NotFound />} />\n  </Routes>\n);\n' > "$R/rr/src/routes/AppRoutes.jsx"
  run "$R/rr" .; clean "review: JSX routes in a file scanned after the link, and a nested dynamic route"
  printf 'export const Bad = () => <Link to="/nowhere">x</Link>;\n' > "$R/rr/src/components/Bad.jsx"
  run "$R/rr" .; verdict review-jsx-unknown UX-F1 Medium 'Bad.jsx:1  link "/nowhere"'
  rm "$R/rr/src/components/Bad.jsx"
  # a child route lives under its parent only: /reports is not /admin/reports
  rm -rf "$R/nest"; mkdir -p "$R/nest/src"; printf 'export const A = () => (\n  <Routes>\n    <Route path="/admin" element={<Admin />}>\n      <Route path="reports" element={<Reports />} />\n    </Route>\n    <Route path="*" element={<NotFound />} />\n  </Routes>\n);\nexport const L = () => <><Link to="/admin/reports">R</Link><Link to="/reports">X</Link></>;\n' > "$R/nest/src/App.jsx"
  run "$R/nest" .; verdict review-jsx-parent UX-F1 Medium 'App.jsx:9  link "/reports"'
  printf "const routes = [{ path: '/admin', children: [{ path: 'users/:id' }] }, { path: '*' }]\n" > "$R/nest/src/router.js"; printf '<template><router-link to="/admin/users/4">A</router-link><router-link to="/users/4">B</router-link></template>\n' > "$R/nest/src/Nav.vue"; rm "$R/nest/src/App.jsx"
  run "$R/nest" .; verdict review-vue-parent UX-F1 Medium 'Nav.vue:1  link "/users/4"'
  printf "const routes = [\n  { path: '/', component: Layout, children: [\n    { path: 'users/:id(\\\\\\\\d+)', component: User },\n    { path: ':pathMatch(.*)*', component: NotFound },\n  ] },\n  { path: 'a{2' },\n]\n" > "$R/vue/src/router.js"
  printf '<template><router-link to="/users/42">U</router-link></template>\n' > "$R/vue/src/Nav.vue"
  run "$R/vue" .; clean "review: a Vue child route joined to its parent, a nested catch-all, a { in a path"
  printf '%s\n' "$OUT" | grep -q '^PASS  UX-F4 ' && ok || bad "review: a nested catch-all is the not-found route: $(printf '%s\n' "$OUT" | grep UX-F4)"
  printf '<a href="#/settings">Settings</a>\n<a href="#!/about">About</a>\n<a href="#!">x</a>\n' > "$R/hash/index.html"
  run "$R/hash" .; clean "review: hash-router links are not in-page anchors"
  printf 'app.post("/login", login);\napp.get("/logout", logout);\n' > "$R/ex/server.js"
  printf '<form action="/login" method="post"></form>\n<a href="/logout">Sign out</a>\n' > "$R/ex/views/index.ejs"; printf '<p>Not found</p>\n' > "$R/ex/views/404.ejs"
  run "$R/ex" .; clean "review: links to server routes in a server template"
  printf '{\n  "scripts": { "build": "vite build" },\n  "devDependencies": { "browserslist": "^4.23.0", "vite": "^5.0.0" },\n  "browserslist": ["chrome >= 100", "firefox >= 100"]\n}\n' > "$R/bl/package.json"; printf '<p>x</p>\n' > "$R/bl/index.html"
  run "$R/bl" --browsers chrome,firefox,safari .; verdict review-browserslist-dep UX-F7 Low 'leave out safari'
  printf '<a href=#main>Skip</a>\n<main id=main><input aria-describedby=hint><p id=hint>Hint</p></main>\n<button aria-controls="menu">Menu</button><ul ID="menu"></ul>\n' > "$R/ids/index.html"
  run "$R/ids" .; clean "review: unquoted and upper-case ids"
  rm -f "$R/idslink"; ln -s "$R/ids" "$R/idslink"; run "$R" idslink; clean "review: a symlinked directory is followed"; passes review-symlink UX-F2
  mkdir -p "$R/sp/my pages"; printf '<p>x</p>\n' > "$R/sp/my pages/a b.html"
  run "$R/sp" --core "my pages/a b.html" .; clean "review: a --core path with spaces"; has_line review-spaces '1 file(s)'
  # Before release (2026-11-13): a query string is never echoed, a path with a newline is
  # skipped, a value that looks like an option is a value, and a dense page stays fast.
  mkdir -p "$R/qs"; printf '<a href="/reset?token=SECRET123#top">Reset</a>\n<p>Not found</p>\n' > "$R/qs/index.html"; printf '<p>x</p>\n' > "$R/qs/404.html"
  run "$R/qs" .; verdict review-query UX-F1 Medium '"/reset?...#top" resolves'
  printf '%s\n' "$OUT" | grep -q SECRET123 && bad "review: a query string was printed: $(printf '%s\n' "$OUT" | grep SECRET123)" || ok
  rm -rf "$R/nl"; mkdir -p "$R/nl/x
"; printf '<p>x</p>\n' > "$R/nl/index.html"; printf '<p>x</p>\n' > "$R/nl/404.html"; printf '<a href="/gone">x</a>\n' > "$R/nl/x
/z.html"
  run "$R/nl" .; clean "review: a path with a newline is skipped"; has_line review-newline '2 file(s)'
  run "$GOOD" --core -x.html .; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q -- '--core -x.html is not among the scanned files' && ! printf '%s\n' "$OUT" | grep -qi usage && ok || bad "review: --core -x.html must be read as a file name: $OUT"
  mkdir -p "$R/lines"; printf '<p>x</p>\n' > "$R/lines/404.html"
  printf '<a href="/a">a</a>\n<p>x</p>\n<a href="/b">b</a>\n<p>x</p>\n<p>x</p>\n<a href="#nope">c</a>\n' > "$R/lines/index.html"
  run "$R/lines" .; has_line review-line-1 './index.html:1  link "/a"'; has_line review-line-3 './index.html:3  link "/b"'; has_line review-line-6 './index.html:6  anchor "#nope"'
  rm -rf "$R/dense"; mkdir -p "$R/dense"; printf '<p>x</p>\n' > "$R/dense/404.html"
  i=0; while [ $i -lt 6000 ]; do printf '<a href="/p%d" id="i%d">x</a><input id="n%d">\n' $i $i $i; i=$((i + 1)); done > "$R/dense/index.html"
  t0=$SECONDS; run "$R/dense" .; dt=$((SECONDS - t0))
  [ "$RC" -eq 1 ] && [ $dt -le 60 ] && ok || bad "review: a page with 6000 links took ${dt}s (limit 60s), exit $RC"
  { printf 'location.href = "/x";\n'; head -c 600000 /dev/zero | tr '\0' 'a'; printf '\n'; } > "$R/big/bundle.js"; printf '<p>x</p>\n' > "$R/big/index.html"
  run "$R/big" .; has_line review-big 'NOTE  UX-F1   -      ./bundle.js:1  not read: larger than 512 KB'

  # Line numbers stay right after non-ASCII text, in a UTF-8 caller locale.
  ARROWS=$(printf '\342\206\222%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30)
  mkdir -p "$WORK/utf8"; printf '<p>%s</p>\n\n\n\n\n\n\n\n\n<a href="gone.html">x</a>\n' "$ARROWS" > "$WORK/utf8/index.html"; printf '<p>x</p>\n' > "$WORK/utf8/404.html"
  (cd "$WORK/utf8" && PATH="$SHIM:$PATH" LC_ALL="$UTF8" bash "$CHECK" .) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  verdict utf8 UX-F1 Medium './index.html:10 '
  printf '<p>\377\376</p>\n<a href="gone.html">x</a>\n' > "$WORK/utf8/index.html"
  (cd "$WORK/utf8" && PATH="$SHIM:$PATH" LC_ALL="$UTF8" bash "$CHECK" .) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  verdict bad-utf8 UX-F1 Medium './index.html:2 '

  # Bad input stops with exit 2.
  run "$WORK" ./no-such-dir; [ "$RC" -eq 2 ] && ok || bad "missing path: expected exit 2, got $RC"
  run "$GOOD" --frobnicate .; [ "$RC" -eq 2 ] && ok || bad "unknown option: expected exit 2, got $RC"
  mkdir -p "$WORK/empty"; printf 'x\n' > "$WORK/empty/notes.txt"; run "$WORK/empty" .; [ "$RC" -eq 2 ] && ok || bad "no markup: expected exit 2, got $RC"
  run "$GOOD" --core site/missing.html .; [ "$RC" -eq 2 ] && ok || bad "--core outside the scan: expected exit 2, got $RC"
  run "$GOOD" --flow "no-steps=" .; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q 'needs NAME=STEP' && ok || bad "--flow without steps: expected exit 2 naming NAME=STEP, got $RC"
  run "$GOOD" --flow "x=site/index.html,site/missing.html" .; [ "$RC" -eq 2 ] && ok || bad "--flow step outside the scan: expected exit 2, got $RC"
  run "$GOOD" --base app .; [ "$RC" -eq 2 ] && ok || bad "--base without a leading /: expected exit 2, got $RC"
  run "$GOOD" --help; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-flow-integrity.sh' && ok || bad "--help must print the usage line"
}

# Static: the script runs under pipefail, so it never pipes into grep -q. grep -q stops at
# the first match and the writer's broken pipe fails the pipeline at random (the CI flake
# of PR #72); lists are read from a here-string.
AWKNAME=static
if grep -nE '\|[ \t]*grep[ \t]+-[A-Za-z]*q' "$CHECK" >"$WORK/pipes"; then bad "a pipe into grep -q can fail at random under pipefail: $(head -1 "$WORK/pipes" | cut -c1-80)"; else ok; fi

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

printf "test-check-flow-integrity: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
