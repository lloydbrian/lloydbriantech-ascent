#!/usr/bin/env bash
# Behavior test for plugins/ascent-ux/scripts/check-ux-resilience.sh (ADR-022).
#
# The good fixtures (plain HTML and JS, React with React Query and axios, Vue) must
# pass UX-R1 to R7 and UX-P1 to P4, with every check exercised (PASS, never N/A).
# Then each check gets negative controls: a copy of the fixtures broken in exactly
# one way must fail that check and no other, in each syntax where the check applies.
# Also covers severities (core files Medium, others Low), contract options that turn
# a check off (N/A), comments ignored, line numbers after non-ASCII text, and bad
# input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-ux-resilience: N/N PASS" last (make/test-plugins.sh T11).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ux"
CHECK="$PLUGIN/scripts/check-ux-resilience.sh"
GOOD="$HERE/fixtures/resilience-good"
for f in "$CHECK" "$GOOD/plain/signup.html" "$GOOD/react/src/Teams.jsx"; do [ -e "$f" ] || { echo "test-check-ux-resilience: missing $f"; echo "test-check-ux-resilience: 0/1 PASS"; exit 1; }; done

UTF8=$(locale -a 2>/dev/null | grep -iE '^(C|en_US)\.utf-?8$' | head -1); UTF8=${UTF8:-C.UTF-8}

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { (cd "$1" && PATH="$SHIM:$PATH" bash "$CHECK" "${@:2}") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); }
# The standard run: the contract's core files, url_state pages, offline: required
# and motion tokens.
std() { run "$1" --core plain/signup.html --core react/src/Teams.jsx --url-state react/src/Teams.jsx \
  --url-state vue/src/ScoreList.vue --offline required --motion-tokens "${@:2}" .; }

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
  for k in UX-R1 UX-R2 UX-R3 UX-R4 UX-R5 UX-R6 UX-R7 UX-P1 UX-P2 UX-P3 UX-P4; do
    printf '%s\n' "$OUT" | grep -q "^PASS  $k " && ok || bad "good fixtures: $k is not PASS (every check must be exercised): $(printf '%s\n' "$OUT" | grep " $k " | head -1)"
  done
  # A passing pleasant rule is observed, never met.
  has_line "pleasant" "PASS  UX-P3   consent boxes are not checked by default (4 checked; observed, never met)"

  # Comments are skipped: unwrapping each one must make its check fail.
  mutate cmt-js plain/signup.html 's|^// console.log only; this comment is ignored: } catch (e) { console.error(e) } <input type="checkbox" name="consent" checked>$|try { await fetch("/api/x"); } catch (e) { console.error(e) }|' && expect cmt-js UX-R2 Medium 'signup.html:25 '
  mutate cmt-html plain/signup.html 's|  <!-- <input type="checkbox" name="consent" checked> an old pre-checked box, ignored -->|  <input type="checkbox" name="consent" checked>|' && expect cmt-html UX-P3 Medium 'signup.html:16 '
  mutate cmt-css plain/css/app.css 's|^/\* transition: opacity 300ms ease; in a comment is ignored \*/$|.x { transition: opacity 300ms ease; }|' && expect cmt-css UX-P2 Low 'app.css:3 '

  # UX-R1: a scripted submit guards against a second click.
  mutate r1-plain plain/signup.html '/^  button.disabled = true;$/d' && expect r1-plain UX-R1 Medium 'signup.html:45  this form is submitted by a script with no guard'
  mutate r1-react react/src/NewTeam.jsx 's/ disabled={saving}//' && expect r1-react UX-R1 Low 'NewTeam.jsx:'
  mutate r1-vue vue/src/ScoreList.vue 's/ :disabled="busy"//' && expect r1-vue UX-R1 Low 'ScoreList.vue:'

  # UX-R2: a failed request changes what the user sees.
  mutate r2-plain plain/signup.html "s|document.getElementById('status').textContent = 'We could not send your request.';|console.error('send failed: status =', err);|" plain/signup.html "/document.getElementById('again').hidden = false;/d" && expect r2-plain UX-R2 Medium 'signup.html:38  a failed request shows nothing to the user'
  mutate r2-react react/src/NewTeam.jsx "s|.catch(() => setProblem('The team was not created.'))|.catch((err) => console.log(err))|" && expect r2-react UX-R2 Low 'NewTeam.jsx:13 '
  mutate r2-vue vue/src/ScoreList.vue "s|error.value = 'The score was not saved.';|console.warn(e);|" && expect r2-vue UX-R2 Low 'ScoreList.vue:31 '
  mutate r2-ok plain/signup.html "s|if (!res.ok) throw new Error('join');|if (!res.ok) return;|" && expect r2-ok UX-R2 Medium 'signup.html:35  a failed request shows nothing'
  mutate r2-status vue/src/ScoreList.vue "s|if (res.status >= 400) { error.value = 'Scores did not load.'; return; }|if (res.status >= 400) { return; }|" && expect r2-status UX-R2 Low 'ScoreList.vue:17 '
  mutate r2-onerror react/src/Teams.jsx "s|      qc.setQueryData(\['teams', division\], ctx.previous);|      console.error(err);|" react/src/Teams.jsx "/setNotice('The new name was not saved.');/d" && expect r2-onerror UX-R2 Medium 'Teams.jsx:21 '
  mutate r2-nopath react/src/NewTeam.jsx "/.catch(() => setProblem/d" && expect r2-nopath UX-R2 Low 'NewTeam.jsx:11  this request has no failure path'
  rm -rf "$WORK/r2-hook"; cp -R "$GOOD" "$WORK/r2-hook"
  printf "import { useQuery } from '@tanstack/react-query';\nexport default function Players() {\n  const players = useQuery({ queryKey: ['players'], queryFn: getPlayers });\n  return <ul>{(players.data ?? []).map((p) => <li key={p.id}>{p.name}</li>)}</ul>;\n}\n" > "$WORK/r2-hook/react/src/Players.jsx"
  expect r2-hook UX-R2 Low 'Players.jsx:3  this request has no failure path'
  sed 's|  return <ul>|  if (players.isError) return <p role="alert">Players did not load.</p>;\n  return <ul>|' "$WORK/r2-hook/react/src/Players.jsx" > "$WORK/tmp" && mv "$WORK/tmp" "$WORK/r2-hook/react/src/Players.jsx"
  std "$WORK/r2-hook"; clean "r2: a data hook that reads isError"

  # UX-R3: a core flow that handles failures offers a retry.
  mutate r3 plain/signup.html 's|>Try again</button>|>Dismiss</button>|' && expect r3 UX-R3 Low 'signup.html:34  failed requests in a core flow offer no way to try again'

  # UX-R4: a long core-flow form keeps a draft.
  mutate r4 plain/signup.html "/^form.addEventListener('input'/d" && expect r4 UX-R4 Medium 'signup.html:7  a core-flow form with 7 fields keeps no draft'
  std "$GOOD" --draft-fields 7; clean "r4: 7 fields at --draft-fields 7"
  printf '%s\n' "$OUT" | grep -q '^PASS  UX-R4 ' && ok || bad "r4: 7 fields at --draft-fields 7 must be checked: $(printf '%s\n' "$OUT" | grep UX-R4)"
  mutate r4-norestore plain/signup.html "/^const saved = JSON.parse(localStorage.getItem(KEY)/d" plain/signup.html "/^for (const \[k, v\] of Object.entries(saved))/d" && expect r4-norestore UX-R4 Medium 'signup.html:7 '
  std "$GOOD" --draft-fields 8; clean "r4: 7 fields under --draft-fields 8"
  printf '%s\n' "$OUT" | grep -q '^N/A   UX-R4 ' && ok || bad "r4: a short form must be N/A: $(printf '%s\n' "$OUT" | grep UX-R4)"

  # UX-R5: listed pages keep their view state in the URL.
  mutate r5-react react/src/Teams.jsx 's/useSearchParams/useFilterState/g' && expect r5-react UX-R5 Medium 'Teams.jsx:1  view state on this page'
  mutate r5-vue vue/src/ScoreList.vue 's/route\.query/route.params/g' && expect r5-vue UX-R5 Medium 'ScoreList.vue:1 '

  # UX-R6: with offline: required, the app tells the user it is offline.
  mutate r6 plain/js/offline.js '/addEventListener/d' plain/js/offline.js 's/navigator.onLine/false/' && expect r6 UX-R6 Medium 'plain/index.html:1  the contract requires an offline notice'
  printf '<!doctype html>\n<title>About</title>\n<p>About the league</p>\n' > "$WORK/r6/plain/about.html"
  std "$WORK/r6"; verdict r6-entry UX-R6 Medium 'plain/index.html:1 '
  mutate r6-listeners plain/js/offline.js 's/navigator.onLine/!document.hidden/'; std "$WORK/r6-listeners"; clean "r6: online and offline listeners alone count"
  run "$WORK/r6" --offline optional .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-R6 ' && ok || bad "r6: offline optional must be N/A"

  # UX-R7: an optimistic update rolls back.
  mutate r7 react/src/Teams.jsx '/^    onError: (err, vars, ctx) => {$/,/^    },$/d' && expect r7 UX-R7 Low 'Teams.jsx:16  an optimistic update (onMutate) has no onError rollback'

  # UX-P1: a core-flow async action shows progress.
  mutate p1 plain/signup.html 's/aria-busy/data-state/g' && expect p1 UX-P1 Low 'signup.html:46  an async action in a core flow shows no progress'

  # UX-P2: with motion tokens, motion uses them.
  mutate p2 plain/css/app.css 's/opacity var(--motion-fast) var(--ease-out)/opacity 200ms ease-out/' && expect p2 UX-P2 Low 'app.css:2  motion with a literal duration'
  run "$WORK/p2" .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-P2 ' && ok || bad "p2: no --motion-tokens must be N/A"

  # UX-P3: consent boxes are never checked by default.
  mutate p3-plain plain/signup.html 's/name="marketing">/name="marketing" checked>/' && expect p3-plain UX-P3 Medium 'signup.html:14  a consent or marketing checkbox is checked by default'
  mutate p3-react react/src/NewTeam.jsx 's|name="newsletter" />|name="newsletter" defaultChecked />|' && expect p3-react UX-P3 Medium 'NewTeam.jsx:19 '
  mutate p3-vue vue/src/ScoreList.vue 's|v-model="consent">|v-model="consent" :checked="true">|' && expect p3-vue UX-P3 Medium 'ScoreList.vue:42 '
  mutate p3-label vue/src/ScoreList.vue 's|v-model="updates">|v-model="updates" checked>|' && expect p3-label UX-P3 Medium 'ScoreList.vue:43 '
  mutate p3-bound react/src/NewTeam.jsx 's|name="newsletter" />|name="newsletter" checked={agreed} />|'; std "$WORK/p3-bound"; clean "p3: a box bound to state is not pre-checked"

  # UX-P4: sign-up has a way out.
  mutate p4 plain/index.html '/Delete my account/d' && expect p4 UX-P4 Low 'plain/index.html:6  the app has a sign-up or subscribe action and no way to cancel'

  rm -rf "$WORK/p4-sw"; cp -R "$GOOD/react" "$WORK/p4-sw"; printf "navigator.serviceWorker.register('/sw.js');\n" > "$WORK/p4-sw/src/sw.js"
  run "$WORK/p4-sw" .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-P4 ' && ok || bad "p4: serviceWorker.register is not a sign-up: $(printf '%s\n' "$OUT" | grep UX-P4)"

  # Trial calibration (2026-11-13): catch blocks that are not request failures, failures
  # handed to the caller, and sign-up words in code samples.
  mkdir -p "$WORK/tr"; rm -f "$WORK/tr"/*
  cat > "$WORK/tr/svc.js" <<'EOF_JS'
export function tab() { try { return sessionStorage.getItem('tab'); } catch { return null; } }
export async function items() {
  const res = await fetch('/api/items');
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.message || 'failed');
  }
  return res.json();
}
export async function weather() { try { const r = await fetch('/api/w'); return await r.json(); } catch { return null; } }
export const list = () => api.listTournaments().catch(() => []);
export const raw = (url, init) => fetch(url, init);
export function get(url) { return fetch(url); }
export async function status(view) {
  try { view.data = await (await fetch('/api/status')).json(); } catch { view.data = null; } finally { view.renderBanner(); }
}
EOF_JS
  printf '<p><span class="cm"># Subscribe to enrichment requests</span></p>\n' > "$WORK/tr/doc.html"
  cat > "$WORK/tr/extra.js" <<'EOF_JS'
export function emit(fn) { try { fn(); } catch (err) { console.warn('listener threw', err); } }
export async function detail() { const body = await (await fetch('/api/z')).json().catch((e) => console.warn(e)); return body; }
export async function sync(api) { const out = await api.push(); if (out.kind === "ok") return 1; return 0; }
EOF_JS
  cat > "$WORK/tr/flow.js" <<'EOF_JS'
export async function events(io) {
  const out = await io.api.listEvents().catch(() => lost);
  if (out.kind === "ok") return out.events;
  return [];
}
export async function save(io) {
  let notice = "";
  try {
    const r = await io.api.save();
    io.setNotice(!r.ok ? "Could not save." : "Saved.");
  } catch { notice = offlineOrRefused(); }
  return notice;
}
export async function load() {
  const res = await fetch('/api/x');
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
export async function loadAll() { let ok = false; try { await fetch('/api/y'); ok = true; } catch { tournamentsError = true; } return ok; }
EOF_JS
  run "$WORK/tr" .; clean "trial: storage catch, parse fallback, returned null, fallback value or variable, forwarded fetch, finally render, notice, !ok in an expression, a template string in a throw, an Error flag"
  printf '%s\n' "$OUT" | grep -q '^N/A   UX-P4 ' && ok || bad "trial: a sign-up word in a code sample is not a sign-up: $(printf '%s\n' "$OUT" | grep UX-P4)"
  printf "export async function save() { try { await fetch('/api/save', { method: 'POST' }); } catch (e) { return; } }\n" > "$WORK/tr/bare.js"
  run "$WORK/tr" .; verdict trial-bare-return UX-R2 Low 'bare.js:1  a failed request shows nothing'
  rm "$WORK/tr/bare.js"; printf "export const list2 = () => api.listTeams().catch((e) => console.log(e));\n" > "$WORK/tr/client.js"
  run "$WORK/tr" .; verdict trial-api-client UX-R2 Low 'client.js:1 '
  rm "$WORK/tr/client.js"
  printf "const send = debounce(() => fetch('/api/x', { method: 'POST' }).catch(() => setError('x')), 300);\nform.addEventListener('submit', (e) => { e.preventDefault(); send(); });\n" > "$WORK/tr/form.js"
  run "$WORK/tr" .; clean "trial: a debounced submit is guarded"
  printf '%s\n' "$OUT" | grep -q '^PASS  UX-R1 ' && ok || bad "trial: the debounced submit must be checked: $(printf '%s\n' "$OUT" | grep UX-R1)"

  printf '<h1>Create your account</h1>\n<li>Join our group chat</li>\n' > "$WORK/tr/doc.html"
  run "$WORK/tr" .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-P4 ' && ok || bad "trial: a heading or list text is not a sign-up control: $(printf '%s\n' "$OUT" | grep UX-P4)"
  printf '<input type="radio" id="m-signup">\n<label for="m-signup" role="tab">Create account</label>\n' > "$WORK/tr/doc.html"
  run "$WORK/tr" .; verdict trial-signup-label UX-P4 Low 'doc.html:2 '
  printf '<p>Reset with <code>rm -rf /conf/*</code></p>\n<input type="checkbox" name="marketing" checked>\n' > "$WORK/tr/doc.html"
  run "$WORK/tr" .; verdict trial-prose-comment UX-P3 Medium 'doc.html:2 '
  rm "$WORK/tr/doc.html"

  # Review before release (2026-11-13): idioms the docs of common libraries use.
  R="$WORK/rv"; rm -rf "$R"; mkdir -p "$R/q" "$R/m" "$R/c" "$R/j" "$R/big" "$R/sp/my pages"
  cat > "$R/q/Login.tsx" <<'EOF_TSX'
export function Login() {
  const mutation = useMutation({ mutationFn: login });
  return <form onSubmit={(e) => { e.preventDefault(); mutation.mutate(); }}>
    <button type="submit" disabled={mutation.isPending}>Sign in</button>
    {mutation.isError && <p role="alert">Sign-in failed. Try again.</p>}
  </form>;
}
EOF_TSX
  cat > "$R/q/Todos.tsx" <<'EOF_TSX'
export function Todos() {
  const { status, data, error } = useQuery({ queryKey: ['todos'], queryFn: fetchTodos });
  if (status === "error") return <span>Error: {error.message}</span>;
  return <ul>{data.map((t) => <li key={t.id}>{t.title}</li>)}</ul>;
}
EOF_TSX
  run "$R/q" .; clean "review: disabled={mutation.isPending}, and status === \"error\""; passes review-q-r1 UX-R1; passes review-q-r2 UX-R2
  printf '.card { transition: transform var(--motion-fast); }\n@media (prefers-reduced-motion: reduce) { * { transition-duration: 0.01ms !important; animation-duration: 0.01ms !important; } }\n' > "$R/m/app.css"
  run "$R/m" --motion-tokens .; clean "review: the reduced-motion reset is not motion"; passes review-motion UX-P2
  printf 'export const S = () => <label><input type="checkbox" onChange={(e) => setOptIn(e.target.checked)} defaultChecked name="newsletter" /> Send me the newsletter</label>;\n' > "$R/c/Signup.jsx"
  run "$R/c" .; verdict review-p3-arrow UX-P3 Medium 'Signup.jsx:1 '
  printf '<label><input type="checkbox" name="remember" checked> Keep me signed in (do not use on a shared computer)</label>\n' > "$R/c/Signup.jsx"
  run "$R/c" .; clean "review: shared computer is not data sharing"; has_line review-shared 'N/A   UX-P3 '
  printf '<label><input type="checkbox" name="remember" checked> Keep me signed in</label>\n<p>Our newsletter is monthly.</p>\n' > "$R/c/Signup.jsx"
  run "$R/c" .; clean "review: the words beside a box end at its label"; has_line review-label 'N/A   UX-P3 '
  printf '<template><button @click="enter">Join call</button><button>Register device</button></template>\n' > "$R/j/Lobby.vue"
  run "$R/j" .; printf '%s\n' "$OUT" | grep -q '^N/A   UX-P4 ' && ok || bad "review: Join call is not a sign-up: $(printf '%s\n' "$OUT" | grep UX-P4)"
  printf '<template><button @click="enter">Join call</button><a href="/start">Join now</a></template>\n' > "$R/j/Lobby.vue"
  run "$R/j" .; verdict review-join-now UX-P4 Low 'Lobby.vue:1 '
  printf '<button>Save</button>\n' > "$R/sp/my pages/a b.html"
  run "$R/sp" --core "my pages/a b.html" .; clean "review: a --core path with spaces"; has_line review-spaces '1 file(s)'
  rm -f "$R/splink"; ln -s "$R/sp" "$R/splink"; run "$R" splink; clean "review: a symlinked directory is followed"; has_line review-symlink '1 file(s)'
  rm -rf "$R/nl"; mkdir -p "$R/nl/x
"; printf '<button>Save</button>\n' > "$R/nl/index.html"; printf '<input type="checkbox" name="consent" checked> Share my data\n' > "$R/nl/x
/z.html"
  run "$R/nl" .; clean "review: a path with a newline is skipped"; has_line review-newline '1 file(s)'
  { printf 'fetch("/x");\n'; head -c 600000 /dev/zero | tr '\0' 'a'; printf '\n'; } > "$R/big/bundle.js"; printf '<p>x</p>\n' > "$R/big/index.html"
  run "$R/big" .; has_line review-big 'NOTE  UX-R    -      ./bundle.js:1  not read: larger than 512 KB'

  # 0.3.1: UX-R1 and UX-R2 read the local modules a file imports (one level): a guard
  # in an imported hook counts, and so does a service that shows every failure it
  # catches; a service that only throws does not. A finding names the modules read.
  form() { mkdir -p "$1"; printf '%s\n' "import { useSave } from \"$2\";" 'export function Form() {' '  const { save } = useSave();' '  async function onSubmit(e) { e.preventDefault(); try { await api.save(1) } catch (err) { setError(err.message) } }' '  return <form onSubmit={onSubmit}><input name="a" /><button>Save</button></form>;' '}' > "$1/Form.jsx"; }
  page() { mkdir -p "$1/src"; printf '%s\n' "import api from \"$2\";" 'export function Page() { api.load(1); return <p>x</p>; }' > "$1/src/Page.jsx"; }
  GUARDED='export function useSave() { let pending = false; return { save: async (x) => { if (pending) return; pending = true; } }; }'
  SHOWS='export default { load(id) { return fetch("/x/" + id).catch(e => { showToast("Could not load"); }) } };'
  THROWS='export default { async load(id) { const r = await fetch("/x/" + id); if (!r.ok) throw new Error("load failed"); return r.json(); } };'
  rm -rf "$WORK/imp"; mkdir -p "$WORK/imp"
  form "$WORK/imp/guard" ./useSave; printf '%s\n' "$GUARDED" > "$WORK/imp/guard/useSave.js"
  run "$WORK/imp/guard" .; clean "imp: a guard in the imported hook counts for UX-R1"; passes "imp-guard" UX-R1
  form "$WORK/imp/noguard" ./useSave; printf '%s\n' 'export function useSave() { return { save: async (x) => x }; }' > "$WORK/imp/noguard/useSave.js"
  run "$WORK/imp/noguard" .; verdict imp-noguard UX-R1 Low 'pending flag); the local modules it imports were read too: ./useSave.js'
  form "$WORK/imp/deep" ./mid; printf '%s\n' 'export { useSave } from "./useSave";' > "$WORK/imp/deep/mid.js"; printf '%s\n' "$GUARDED" > "$WORK/imp/deep/useSave.js"
  run "$WORK/imp/deep" .; verdict imp-deep UX-R1 Low 'the local modules it imports were read too: ./mid.js'
  page "$WORK/imp/shows" ../lib/api; mkdir -p "$WORK/imp/shows/lib"; printf '%s\n' "$SHOWS" > "$WORK/imp/shows/lib/api.js"
  run "$WORK/imp/shows" .; clean "imp: a service that shows its failures serves the request"; passes "imp-shows" UX-R2
  page "$WORK/imp/throws" ../lib/api; mkdir -p "$WORK/imp/throws/lib"; printf '%s\n' "$THROWS" > "$WORK/imp/throws/lib/api.js"
  run "$WORK/imp/throws" .; verdict imp-throws UX-R2 Low 'a failure is invisible; the local modules it imports were read too: ./lib/api.js'
  page "$WORK/imp/index" ./svc; mkdir -p "$WORK/imp/index/src/svc"; printf '%s\n' "$SHOWS" > "$WORK/imp/index/src/svc/index.js"
  run "$WORK/imp/index" .; clean "imp: ./svc resolves to svc/index.js"
  page "$WORK/imp/missing" ./nowhere
  run "$WORK/imp/missing" .; verdict imp-missing UX-R2 Low 'a failure is invisible'
  printf '%s\n' "$OUT" | grep '^FAIL  UX-R2 ' | grep -q 'local modules' && bad "imp-missing: an import that resolves to no scanned file is not named" || ok

  # Line numbers stay right after non-ASCII text, in a UTF-8 caller locale.
  ARROWS=$(printf '\342\206\222%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30)
  mkdir -p "$WORK/utf8"; printf "const label = '%s';\n\n\n\n\n\n\n\n\nfetch('/api/x').then((r) => r.json());\n" "$ARROWS" > "$WORK/utf8/index.js"
  (cd "$WORK/utf8" && PATH="$SHIM:$PATH" LC_ALL="$UTF8" bash "$CHECK" .) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  verdict utf8 UX-R2 Low './index.js:10 '
  printf "const label = '\377\376';\nfetch('/api/x').then((r) => r.json());\n" > "$WORK/utf8/index.js"
  (cd "$WORK/utf8" && PATH="$SHIM:$PATH" LC_ALL="$UTF8" bash "$CHECK" .) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  verdict bad-utf8 UX-R2 Low './index.js:2 '

  # Bad input stops with exit 2.
  run "$WORK" ./no-such-dir; [ "$RC" -eq 2 ] && ok || bad "missing path: expected exit 2, got $RC"
  run "$GOOD" --frobnicate .; [ "$RC" -eq 2 ] && ok || bad "unknown option: expected exit 2, got $RC"
  mkdir -p "$WORK/empty"; printf 'x\n' > "$WORK/empty/notes.txt"; run "$WORK/empty" .; [ "$RC" -eq 2 ] && ok || bad "no code: expected exit 2, got $RC"
  run "$WORK/empty" notes.txt; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q 'not a markup, CSS or JS file' && ok || bad "a text file: expected exit 2 naming it, got $RC"
  run "$GOOD" --core plain/missing.html .; [ "$RC" -eq 2 ] && ok || bad "--core outside the scan: expected exit 2, got $RC"
  run "$GOOD" --url-state vue/src/Missing.vue .; [ "$RC" -eq 2 ] && ok || bad "--url-state outside the scan: expected exit 2, got $RC"
  run "$GOOD" --offline sometimes .; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q 'required, optional or none' && ok || bad "--offline sometimes: expected exit 2, got $RC"
  run "$GOOD" --draft-fields 0 .; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q 'positive number' && ok || bad "--draft-fields 0: expected exit 2, got $RC"
  run "$GOOD" --draft-fields six .; [ "$RC" -eq 2 ] && ok || bad "--draft-fields six: expected exit 2, got $RC"
  run "$GOOD" --help; [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-ux-resilience.sh' && ok || bad "--help must print the usage line"
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

printf "test-check-ux-resilience: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
