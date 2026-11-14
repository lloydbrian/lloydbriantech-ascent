#!/usr/bin/env bash
# Static reliability and pleasantness checks for web apps: what the user sees when
# a request fails, a button is clicked twice, a page reloads or the network drops.
# Part of the ascent-ux plugin (ux-review Step 3, flow-check). Rules:
# references/flow-and-reliability.md. Read-only.
#
# Usage: check-ux-resilience.sh [--core FILE]... [--url-state FILE]... [--offline required|optional|none] [--draft-fields N] [--motion-tokens] PATH...
#
# PATH is a file or a directory (searched for markup, CSS and JS/TS, skipping
# node_modules, dist, build, .git, vendor, .svelte-kit, .next, .nuxt, *.min.* and
# *.test.*/*.spec.*). --core marks a file as part of a core flow (the contract's
# core_flows pages and steps): UX-R3, R4 and P1 apply to core files only, and UX-R1
# and R2 failures there are Medium instead of Low. --url-state names a page whose
# view state must live in the URL (ux.reliability.url_state), --offline is
# ux.reliability.offline, --draft-fields is ux.reliability.draft_fields (default 6),
# and --motion-tokens says the token source has motion tokens (ux.pleasant).
#
# Checks (severity from the ux-review severity table):
#   UX-R1  Medium  a form submitted by a script disables its control, sets
#               aria-disabled or guards a pending flag (Low outside core files)
#   UX-R2  Medium  a failed request changes what the user sees; console.* alone is
#               not enough (Low outside core files); a data hook (useQuery, useSWR)
#               must read its error state
#   UX-R3  Low     a core file that handles failed requests offers a retry
#   UX-R4  Medium  a core-flow form with N fields or more keeps a draft across reload
#   UX-R5  Medium  each --url-state page keeps its view state in the URL
#   UX-R6  Medium  with --offline required, the app tells the user it is offline
#   UX-R7  Low     an optimistic update (onMutate) rolls back on error (onError)
#   UX-P1  Low     a core-flow async action shows progress (aria-busy, a spinner,
#               a loading or saving state)
#   UX-P2  Low     with motion tokens, transitions and animations use them
#   UX-P3  Medium  no consent, marketing or subscription checkbox is checked by default
#   UX-P4  Low     an app with a sign-up or subscribe action has a way to cancel,
#               unsubscribe or delete the account
# A UX-P rule that passes is "observed", never "met" (the pleasant principle has no
# target). UX-R5 is confirmed by the browser pass (reload and Back).
#
# Output: one FAIL line per finding (FAIL  UX-xn  SEVERITY  file:line  message), a
# PASS line per check with no finding (with the count checked), N/A when a check
# found nothing to check or its contract key is missing, then
# "check-ux-resilience: ...".
# Limits: static and file-scoped. A guard, failure branch, draft or retry counts when
# it is in the same file as the form or request it serves; logic in another file
# (a shared hook or service) is not followed, so read it before rating. A failure
# branch is the body of a .catch(), a catch block, an !res.ok / status check or an
# onError handler. Every finding is "static" until the browser pass confirms it.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk. awk runs with LC_ALL=C:
# in a UTF-8 locale some awks count characters in one place and bytes in another,
# which shifts line numbers after non-ASCII text, and stop on invalid UTF-8.

set -euo pipefail

usage() { sed -n '7p' "$0" | sed 's/^# //' >&2; exit 2; }
CORE=""; URLSTATE=""; OFFLINE=""; DRAFT=6; MOTION=0
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --core) [ $# -ge 2 ] || usage; CORE="$CORE${2#./}
"; shift 2 ;;
    --url-state) [ $# -ge 2 ] || usage; URLSTATE="$URLSTATE${2#./}
"; shift 2 ;;
    --offline) [ $# -ge 2 ] || usage
      case "$2" in required|optional|none) OFFLINE="$2" ;; *) echo "check-ux-resilience: --offline is required, optional or none: $2" >&2; exit 2 ;; esac
      shift 2 ;;
    --draft-fields) [ $# -ge 2 ] || usage
      case "$2" in ''|*[!0-9]*|0) echo "check-ux-resilience: --draft-fields needs a positive number: $2" >&2; exit 2 ;; esac
      DRAFT="$2"; shift 2 ;;
    --motion-tokens) MOTION=1; shift ;;
    -h|--help) usage ;;
    -*) echo "check-ux-resilience: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || usage

EXT='html|htm|jsx|tsx|vue|svelte|astro|eta|ejs|hbs|njk|js|ts|mjs|cjs|css|scss'
# a file name with a newline in it would split the file list, so it is skipped
NLNAME="$(printf '*\n*')"
FILES=""
for p in "${PATHS[@]}"; do
  if [ -d "$p" ]; then
    FILES="$FILES$(find -H "$p" \( -name node_modules -o -name dist -o -name build -o -name .git -o -name vendor \
      -o -name .svelte-kit -o -name .next -o -name .nuxt \) -prune -o -type f ! -path "$NLNAME" -print 2>/dev/null \
      | grep -Ei "\\.($EXT)\$" | grep -Ev '\.min\.|\.(test|spec)\.|\.d\.ts$' | LC_ALL=C sort || true)
"
  elif [ -f "$p" ]; then
    printf '%s\n' "$p" | grep -Eiq "\\.($EXT)\$" || { echo "check-ux-resilience: not a markup, CSS or JS file: $p" >&2; exit 2; }
    FILES="$FILES$p
"
  else
    echo "check-ux-resilience: no such file or directory: $p" >&2; exit 2
  fi
done
FILES=$(printf '%s' "$FILES" | grep -v '^$' | sed 's|^\./||' | LC_ALL=C sort -u || true)
[ -n "$FILES" ] || { echo "check-ux-resilience: no markup, CSS or JS files under: ${PATHS[*]}" >&2; exit 2; }
while IFS= read -r c; do [ -n "$c" ] || continue; printf '%s\n' "$FILES" | grep -qxF -e "$c" || { echo "check-ux-resilience: $c (--core or --url-state) is not among the scanned files" >&2; exit 2; }; done <<EOF_CORE
$CORE$URLSTATE
EOF_CORE

PROG='
function blank(s) { gsub(/[^\n]/, " ", s); return s }
function blank_between(t, opn, cls,   out, i, j) {
  out = ""
  while ((i = index(t, opn)) > 0) {
    j = index(substr(t, i + length(opn)), cls)
    if (j == 0) { out = out substr(t, 1, i - 1) blank(substr(t, i)); t = ""; break }
    j = i + length(opn) + j - 1 + length(cls)
    out = out substr(t, 1, i - 1) blank(substr(t, i, j - i)); t = substr(t, j)
  }
  return out t
}
function blank_line_comments(t,   n, ln, i, out) {
  n = split(t, ln, "\n"); out = ""
  for (i = 1; i <= n; i++) { if (ln[i] ~ /^[ \t]*\/\//) ln[i] = blank(ln[i]); out = out ln[i] (i < n ? "\n" : "") }
  return out
}
# JS and CSS comments: everywhere in a script or style file, but only inside <script>
# and <style> blocks of a markup file, where "/*" in text (rm -rf /conf/*) is not one.
function code_comments(t, f,   out, lt, k, j, cl, seg) {
  if (f !~ /\.(html|htm|eta|ejs|hbs|njk|vue|svelte|astro)$/) { t = blank_between(t, "/*", "*/"); return (f ~ /\.(css|scss)$/) ? t : blank_line_comments(t) }
  out = ""
  while (match(tolower(t), /<(script|style)([ \t\r\n][^>]*)?>/)) {
    cl = (tolower(substr(t, RSTART + 1, 6)) == "script") ? "</script>" : "</style>"
    k = RSTART + RLENGTH
    j = index(tolower(substr(t, k)), cl); if (j == 0) j = length(t) - k + 2
    seg = blank_between(substr(t, k, j - 1), "/*", "*/"); if (cl == "</script>") seg = blank_line_comments(seg)
    out = out substr(t, 1, k - 1) seg; t = substr(t, k + j - 1)
  }
  return out t
}
function line_at(t, pos,   seg) { seg = substr(t, 1, pos - 1); return gsub(/\n/, "", seg) + 1 }
# The text between the bracket at p (an opening "{" or "(") and its partner.
function bracket_body(t, p,   o, c, d, i, ch) {
  o = substr(t, p, 1); c = (o == "{") ? "}" : ")"; d = 0
  for (i = p; i <= length(t); i++) {
    ch = substr(t, i, 1)
    if (ch == o) d++
    else if (ch == c) { d--; if (d == 0) return substr(t, p + 1, i - p - 1) }
  }
  return substr(t, p + 1)
}
# The body of a failure branch that starts at p: a {block}, or one statement.
function branch_body(t, p,   r, i) {
  r = substr(t, p)
  if (match(r, /^[^{;\n]*\{/) && substr(r, RLENGTH - 1, 1) != "$" && r !~ /^[^{\n]*=>[ \t]*[^{ \t]/) return bracket_body(t, p + RLENGTH - 1)
  i = index(r, "\n"); return (i == 0) ? r : substr(r, 1, i - 1)
}
# A request: fetch, axios, XMLHttpRequest, ky, or a call on an API client object.
function has_req(x) { return x ~ /(^|[^A-Za-z0-9_.$])(fetch|\$fetch|ofetch)\(|axios|XMLHttpRequest|(^|[^A-Za-z0-9_])ky\.[a-z]+\(|(^|[^A-Za-z0-9_])[A-Za-z_]*([Aa]pi|API)\.[A-Za-z_]+\(/ }
# The try block that ends just before position at (where "catch" starts), or "".
function try_body(t, at,   i, j, d, ch) {
  i = at - 1; while (i > 0 && substr(t, i, 1) ~ /[ \t\r\n]/) i--
  if (substr(t, i, 1) != "}") return ""
  d = 0
  for (j = i; j > 0; j--) { ch = substr(t, j, 1); if (ch == "}") d++; else if (ch == "{") { d--; if (d == 0) break } }
  if (j <= 1 || substr(t, (j > 12 ? j - 12 : 1), (j > 12 ? 12 : j - 1)) !~ /try[ \t\r\n]*$/) return ""
  return substr(t, j + 1, i - j - 1)
}
# The promise chain that ends just before position at (where ".catch(" starts).
function chain_before(t, at,   j, d, ch) {
  d = 0
  for (j = at - 1; j > 0; j--) {
    ch = substr(t, j, 1)
    if (ch == ")") d++
    else if (ch == "(") { if (d == 0) break; d-- }
    else if (d == 0 && (ch == ";" || ch == "{" || ch == "}")) break
  }
  return substr(t, j + 1, at - j - 1)
}
# A failure handed to the caller: a returned value, a throw, or an arrow that returns a
# fallback value (() => [], () => null, () => lost).
function handed_on(b) { return b ~ /(^|[^A-Za-z0-9_])return[ \t]+[^; \t\r\n}]|throw[ \t(]|^[ \t]*\(?[^)]*\)?[ \t]*=>[ \t]*(\[|\(|null|undefined|false|true|-?[0-9]|"|\047|`|[A-Za-z_$][A-Za-z0-9_$.]*[ \t\r\n]*$)/ }
function visible(b) {
  gsub(/console\.[a-z]+\([^)]*\)/, "", b)
  return b ~ /set[A-Z][A-Za-z0-9]*\(|[A-Za-z_.]*([Ee]rror|[Ee]rr|[Mm]essage|[Ss]tatus|[Pp]roblem|[Ff]ailed|[Oo]ffline|[Nn]otice|[Aa]lert|[Ww]arning|[Bb]anner)(\.value)?[ \t]*=[^=>]|\.(textContent|innerHTML|innerText|hidden)[ \t]*=|classList\.(add|remove|toggle)|toast|alert\(|notify|show[A-Z][A-Za-z]*\(|render[A-Za-z]*\(|throw[ \t(]|\$emit\(|dispatch\(|role=.?alert|aria-live/
}
function fail(k, f, ln, msg, sev) {
  NF_[k]++; NFAIL++
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s:%d  %s\n", "UX-" k, (sev == "") ? SEV[k] : sev, shown(f), ln, msg)
}
function shown(f) { return (f ~ /^\// || f ~ /^\.\.\//) ? f : "./" f }
# The end of a tag that may hold {...} with > inside (onChange={(e) => x}); 0 if none.
function tag_end(s,   i, c, d, q) {
  d = 0; q = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (q != "") { if (c == q) q = ""; continue }
    if (c == "\"" || c == "\047") q = c
    else if (c == "{") d++
    else if (c == "}") d--
    else if (c == ">" && d <= 0) return i
  }
  return 0
}
function is_code(f) { return f !~ /\.(css|scss)$/ }

function check_file(f, t,   lt, core, sev, req, hooks, ms, ml, rest, off, at, b, nb, ln, m, n, i, k, form, cnt, tag, nm, ty, sub_, fl, x, hk) {
  lt = tolower(t); core = (f in COREF); sev = core ? "" : "Low"
  req = match(t, /(^|[^A-Za-z0-9_.$])(fetch|\$fetch|ofetch)\(|axios(\.(get|post|put|patch|delete|request))?\(|new XMLHttpRequest|(^|[^A-Za-z0-9_])ky\.(get|post|put|patch|delete)\(|(^|[^A-Za-z0-9_])[A-Za-z_]*([Aa]pi|API)\.[A-Za-z_]+\(/) ? RSTART : 0
  # the match can start on the character before the call (often the newline): skip it
  if (req && substr(t, req, 1) ~ /[^A-Za-z0-9_$]/) req++
  hooks = match(t, /use(Query|SWR|Mutation|Fetch|AsyncData)\(/); hk = RSTART
  sub_ = (lt ~ /onsubmit[ \t]*=|@submit|on:submit|v-on:submit|addeventlistener\([ \t]*["\047]submit|\.onsubmit[ \t]*=|handlesubmit\(/)
  if (!is_code(f)) return

  # UX-R2: every failure branch of a request shows something, or hands the failure to
  # the caller; a request with no failure branch is returned to its caller or fails.
  if (req || hooks) {
    nb = 0; rest = t; off = 0
    while (match(rest, /\.catch\(|catch[ \t]*(\([^)]*\))?[ \t]*\{|!(res|resp|response|r)\.ok|\.status[ \t]*(>=[ \t]*[45]|!==?[ \t]*2)|onError[ \t]*[:=(]|\.onerror[ \t]*=/)) {
      ms = RSTART; ml = RLENGTH; at = off + ms; m = substr(rest, ms, ml)
      off += ms + ml - 1; rest = substr(rest, ms + ml)
      # !res.ok and a status test are a branch only as an if condition, not inside an expression
      if (m ~ /\.ok$|status/ && rest !~ /^[ \t]*\)/ && rest !~ /^[ \t]*[0-9]*[ \t]*\)/) continue
      if (m ~ /^\.catch\(/) {
        x = chain_before(t, at)
        # a .catch on .json() or .text() is a parse fallback, not a request failure
        if (!has_req(x) || x ~ /\.(json|text|blob|arrayBuffer)\(\)[ \t\r\n]*$/) continue
        b = bracket_body(t, at + ml - 1)
      } else if (m ~ /^catch/) {
        if (!has_req(try_body(t, at))) continue
        b = bracket_body(t, at + ml - 1)
        # a finally block that runs after the catch counts with it
        x = substr(t, at + ml - 1 + length(b) + 2)
        if (match(x, /^[ \t\r\n]*finally[ \t\r\n]*\{/)) b = b " " bracket_body(x, RLENGTH)
      } else b = branch_body(t, at + ml)
      nb++; CHK["R2"]++
      if (!visible(b) && !handed_on(b)) fail("R2", f, line_at(t, at), "a failed request shows nothing to the user here (only logging, or nothing); set an error state or message, or hand it to the caller", sev)
    }
    # a data hook whose error the component shows is a failure path that was checked and met
    if (nb == 0 && hooks && t ~ /isError|[^A-Za-z_.]error[ \t]*(&&|\?|\))|\.error[ \t]*(&&|\?|\))|[^A-Za-z_.]error\.message|status[ \t]*===?[ \t]*["\047`]error|v-if="[^"]*error|\{#if[^}]*error/) CHK["R2"]++
    else if (nb == 0 && t !~ /\.kind[ \t]*[!=]==?[ \t]*["\047`]|\.(ok|error)[ \t]*(\)|&&|\|\||\?)/ && !(req && t ~ /return[ \t]+(await[ \t]+)?(fetch|axios|\$fetch|ofetch|[A-Za-z_.]*[Aa]pi\.)|=>[ \t]*(fetch|axios|\$fetch|ofetch|[A-Za-z_.]*[Aa]pi\.)[.(A-Za-z]/)) { CHK["R2"]++; fail("R2", f, line_at(t, req ? req : hk), "this request has no failure path (no .catch, catch block, ok or status check); a failure is invisible", sev) }
    # UX-R3: a core file that handles failures lets the user try again.
    if (core && nb > 0) { CHK["R3"]++; if (lt !~ /retry|try again|tryagain|refetch\(|mutate\(|reload\(/) fail("R3", f, line_at(t, req ? req : 1), "failed requests in a core flow offer no way to try again (a retry control, or retry in code)") }
  }

  # UX-R1 and UX-P1: forms submitted by a script.
  if (sub_ && (req || hooks || lt ~ /\$emit\(|dispatch\(|mutate\(|action\(/)) {
    ln = match(lt, /onsubmit[ \t]*=|@submit|on:submit|v-on:submit|addeventlistener\([ \t]*["\047]submit|\.onsubmit[ \t]*=|handlesubmit\(/) ? line_at(t, RSTART) : 1
    CHK["R1"]++
    if (lt !~ /\.disabled[ \t]*=[ \t]*true|[ \t:]disabled[ \t]*=[ \t]*[{"\047]?[ \t]*\{?[ \t]*!?[a-z0-9_$]*[.]?(issubmitting|submitting|pending|ispending|busy|isbusy|saving|issaving|loading|isloading)|aria-disabled|issubmitting|useformstatus|usetransition|debounce|throttle|toosoon|if[ \t]*\([ \t]*(this\.)?(busy|submitting|pending|saving|inflight|isbusy|issubmitting|issaving)[ \t]*\)[ \t]*return/)
      fail("R1", f, ln, "this form is submitted by a script with no guard against a second click (disable the button, aria-disabled, or a pending flag)", sev)
    if (core) { CHK["P1"]++; if (lt !~ /aria-busy|spinner|loading|isloading|saving|issaving|<progress|role="progressbar"|role=.progressbar|pending|ispending|issubmitting/) fail("P1", f, ln, "an async action in a core flow shows no progress before the request returns (aria-busy, a spinner, a loading or saving state)") }
  }

  # UX-R4: long core-flow forms keep a draft.
  if (core) {
    rest = lt; off = 0
    while (match(rest, /<form[ \t\r\n>]/)) {
      ms = RSTART; at = off + ms; form = substr(lt, at); i = index(form, "</form>"); if (i > 0) form = substr(form, 1, i)
      cnt = 0; x = form
      while (match(x, /<(input|textarea|select)[ \t\r\n>\/]/)) {
        tag = substr(x, RSTART); tag = substr(tag, 1, index(tag, ">"))
        if (tag !~ /type[ \t]*=[ \t]*["\047]?(hidden|submit|button|reset|image)/) cnt++
        x = substr(x, RSTART + RLENGTH)
      }
      if (cnt >= DRAFT) {
        CHK["R4"]++
        if (!(lt ~ /(localstorage|sessionstorage)\.setitem|indexeddb|localforage|uselocalstorage|usesessionstorage|persist\(|savedraft|\/draft/ && lt ~ /(localstorage|sessionstorage)\.getitem|indexeddb|localforage|uselocalstorage|usesessionstorage|persist\(|loaddraft|restoredraft|restore\(/))
          fail("R4", f, line_at(t, at), "a core-flow form with " cnt " fields keeps no draft across a reload (write and restore it: localStorage, sessionStorage, IndexedDB or a draft request)")
      }
      off += ms; rest = substr(rest, ms + 1)
    }
  }

  # UX-R5: listed pages keep their view state in the URL.
  if (f in URLF) {
    CHK["R5"]++
    if (t !~ /URLSearchParams|searchParams|history\.(pushState|replaceState)|useSearchParams|route\.query|\$route\.query|query:[ \t]*\{|location\.search|useRouter\(\)\.query/)
      fail("R5", f, 1, "view state on this page (filters, sort, page, tab) is not kept in the URL, so Back and refresh lose it")
  }

  # UX-R7: optimistic updates roll back.
  if (t ~ /onMutate[ \t]*[:(]/) { CHK["R7"]++; if (t !~ /onError[ \t]*[:(]/) fail("R7", f, (match(t, /onMutate[ \t]*[:(]/) ? line_at(t, RSTART) : 1), "an optimistic update (onMutate) has no onError rollback; a failed request leaves the wrong data on screen") }

  # UX-P3: consent boxes are never checked by default.
  rest = t; off = 0
  while (match(rest, /<input[ \t\r\n]/)) {
    ms = RSTART; k = tag_end(substr(rest, ms)); if (k == 0) break
    at = off + ms; tag = substr(rest, ms, k); x = tolower(tag); ml = k
    if (x ~ /type[ \t]*=[ \t]*["\047{]?[ \t]*["\047]?checkbox/) {
      # the words beside the box: up to the end of its label, at most 160 characters
      nm = tolower(substr(rest, ms + ml, 160)); if ((i = index(nm, "</label")) > 0) nm = substr(nm, 1, i - 1)
      nm = x " " nm
      if (nm ~ /consent|marketing|newsletter|subscri|share (my|your|our)|sharing|partner|offers|promotion|promotional/) {
        CHK["P3"]++
        if (x ~ /[ \t\r\n](checked|defaultchecked)([ \t\r\n\/>]|[ \t]*=[ \t]*("checked"|"true"|\{[ \t]*true[ \t]*\}|true))|:checked[ \t]*=[ \t]*"true"/)
          fail("P3", f, line_at(t, at), "a consent or marketing checkbox is checked by default; leave it unchecked")
      }
    }
    off += ms + ml - 1; rest = substr(rest, ms + ml)
  }
}

function check_motion(f, t,   rest, off, at, d, ln) {
  rest = t; off = 0
  while (match(rest, /(transition|transition-duration|animation|animation-duration)[ \t]*:[^;}\n]*/)) {
    at = off + RSTART; d = substr(rest, RSTART, RLENGTH)
    # 0.01ms !important is the reduced-motion reset, not motion
    if (d !~ /var\(--/ && d ~ /[0-9.]+m?s([^a-z]|$)/ && d !~ /:[ \t]*(none|0m?s)[ \t]*$/ && d !~ /:[ \t]*0?\.[0-9]+ms|:[ \t]*0\.00[0-9]*s/) {
      CHK["P2"]++; fail("P2", f, line_at(t, at), "motion with a literal duration (" substr(d, 1, 60) "); use the motion tokens")
    } else if (d ~ /var\(--/) CHK["P2"]++
    off += RSTART + RLENGTH - 1; rest = substr(rest, RSTART + RLENGTH)
  }
}

BEGIN {
  split("R1 R2 R3 R4 R5 R6 R7 P1 P2 P3 P4", ORDER, " ")
  split("Medium Medium Low Medium Medium Medium Low Low Low Medium Low", sv, " ")
  for (i = 1; i <= 11; i++) SEV[ORDER[i]] = sv[i]
  D["R1"] = "scripted forms guard against a double submit"; D["R2"] = "failed requests are shown to the user"
  D["R3"] = "core flows offer a retry after a failure"; D["R4"] = "long core-flow forms keep a draft"
  D["R5"] = "listed view state is kept in the URL"; D["R6"] = "the app tells the user when it is offline"
  D["R7"] = "optimistic updates roll back on error"; D["P1"] = "core-flow async actions show progress"
  D["P2"] = "motion uses the motion tokens"; D["P3"] = "consent boxes are not checked by default"
  D["P4"] = "sign-up has a way to cancel or unsubscribe"
  DRAFT = ENVIRON["R_DRAFT"] + 0; OFFLINE = ENVIRON["R_OFFLINE"]; MOTION = ENVIRON["R_MOTION"] + 0
  nc = split(ENVIRON["R_CORE"], cl, "\n"); for (i = 1; i <= nc; i++) if (cl[i] != "") COREF[cl[i]] = 1
  nc = split(ENVIRON["R_URL"], cl, "\n"); for (i = 1; i <= nc; i++) if (cl[i] != "") URLF[cl[i]] = 1
  for (i = 1; i < ARGC; i++) {
    # a file over 512 KB is a bundle, not source: reading it would take minutes on some awks
    g = ARGV[i]; f = g; sub(/^\.\//, "", f); T = ""; big = 0; while ((getline x < g) > 0) { T = T x "\n"; if (length(T) > 524288) { big = 1; break } } close(g)
    if (big) { BIG = BIG sprintf("NOTE  %-7s %-6s %s:1  not read: larger than 512 KB, so a bundle rather than source; the browser pass covers it\n", "UX-R", "-", shown(f)); T = "" }
    T = blank_between(T, "<!--", "-->"); T = code_comments(T, f)
    FILES[i] = f; TEXT[i] = T
    check_file(f, T)
    if (MOTION) check_motion(f, T)
    lt = tolower(T)
    if (lt ~ /navigator\.online|addeventlistener\([ \t]*["\047](offline|online)|\.on(offline|online)[ \t]*=|serviceworker\.register|useonline|usenetwork/) ONLINE = 1
    # a sign-up is a link or control whose text starts with the action, or a sign-up link
    # "Join call" or "Register device" is not a sign-up; "Join", "Join now", "Register an account" are
    if (match(lt, /<(a|button|label)([ \t\n][^>]*)?>[ \t\n]*((sign[ -]?up|create (an |your )?account|subscribe)([^a-z]|$)|(register|join)[ \t\n]*(<|!|\.|$)|register[ \t]+(now|today|free|for|an?|your|another|account|here)([^a-z]|$)|join[ \t]+(now|today|free|us|our|the|for)([^a-z]|$))|type[ \t]*=[ \t]*["\047]?submit["\047]?[^>]*value[ \t]*=[ \t]*["\047](sign[ -]?up|register|subscribe|join)|href[ \t]*=[ \t]*["\047][^"\047]*(signup|sign-up|register|subscribe)/) && !SIGNUP) { SIGNUP = 1; SIGNF = f; SIGNL = line_at(T, RSTART) }
    if (lt ~ /unsubscribe|cancel (my |your )?(subscription|membership|plan|account)|delete (my |your )?account|delete-account|close (my |your )?account|deactivate/) WAYOUT = 1
    # the offline finding goes on the entry page: index.html, App.*, main.* or +layout.*
    if (ENTRY == "" && f ~ /(^|\/)(index\.html?|App\.(jsx|tsx|vue|svelte)|main\.(jsx|tsx|js|ts)|\+layout\.svelte)$/) ENTRY = f
    if (FIRST == "" && f ~ /\.(html|htm|jsx|tsx|vue|svelte|astro)$/) FIRST = f
  }
  if (OFFLINE == "required") { CHK["R6"]++; if (!ONLINE) fail("R6", (ENTRY != "" ? ENTRY : FIRST != "" ? FIRST : FILES[1]), 1, "the contract requires an offline notice, and nothing listens for offline (navigator.onLine, an offline event, a service worker)") }
  if (SIGNUP) { CHK["P4"]++; if (!WAYOUT) fail("P4", SIGNF, SIGNL, "the app has a sign-up or subscribe action and no way to cancel, unsubscribe or delete the account") }
  for (i = 1; i <= 11; i++) {
    k = ORDER[i]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked%s)\n", "UX-" k, D[k], CHK[k], (k ~ /^P/) ? "; observed, never met" : ""
    else printf "N/A   %-7s %s (nothing to check)\n", "UX-" k, D[k]
  }
  printf "%s", BIG
  printf "check-ux-resilience: %d file(s), %d failure(s) (static checks; confirm in the browser pass)\n", ARGC - 1, NFAIL
  exit (NFAIL > 0) ? 1 : 0
}'
# awk reads "a=b.html" as an assignment, so every path is passed as ./path; the
# leading ./ is removed again inside.
ARGS=()
while IFS= read -r f; do [ -n "$f" ] || continue; case "$f" in /*) ARGS+=("$f") ;; *) ARGS+=("./$f") ;; esac; done <<EOF_FILES
$FILES
EOF_FILES
R_CORE="$CORE" R_URL="$URLSTATE" R_OFFLINE="$OFFLINE" R_DRAFT="$DRAFT" R_MOTION="$MOTION" \
  LC_ALL=C awk "$PROG" "${ARGS[@]}"
