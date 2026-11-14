#!/usr/bin/env bash
# Static flow-integrity checks for web apps: links, targets, core-flow steps, a
# not-found route and build targets. Part of the ascent-ux plugin (ux-review
# Step 3, flow-check). Rules: references/flow-and-reliability.md. Read-only.
#
# Usage: check-flow-integrity.sh [--core FILE]... [--flow NAME=STEP,STEP,...]... [--base PATH] [--browsers LIST] PATH...
#
# PATH is a file or a directory (searched, skipping node_modules, dist, build, .git,
# vendor, .svelte-kit, .next and .nuxt). Markup (HTML, JSX/TSX, Vue, Svelte, Astro and
# server templates) and JS/TS files are read for links; every file under PATH counts
# as a link target. --core marks a file as part of a core flow: UX-F1 and UX-F2
# failures there are High. --flow names a core flow and its ordered steps (files, as
# in the contract's core_flows[].steps); its steps are core files too. --base strips a
# deployment base path ("/app") from root-relative links. --browsers is the
# contract's ux.browsers, comma-separated, for UX-F7.
#
# Checks (severity from the ux-review severity table):
#   UX-F1  Medium  relative links, form actions, iframe sources, router links and
#               navigation calls resolve to a file or a route (High in a core file)
#   UX-F2  Medium  in-page anchors (#id) and aria-controls, aria-describedby and
#               aria-labelledby targets exist in the same file (High in a core file)
#   UX-F3  High    each core-flow step has a way forward to the next step (High), and
#               a way back or out (Medium); the last step needs only a way out
#   UX-F4  Low     the app has a not-found page or a catch-all route
#   UX-F7  Low     a project with a build step declares build targets, and they do not
#               exclude a browser family the contract lists
# UX-F5 and UX-F6 are browser rules (the core-flow walk and the engine loop); this
# script does not apply them.
#
# Resolution: a link relative to an HTML page resolves against the page's directory;
# a root-relative link (/x) resolves to a route, or to a file at that path under any
# scanned directory (a served root such as public/ is not known statically), with
# x.html, x/index.html and a trailing slash accepted; dynamic segments (:id, [id],
# [...rest], *) match any value. Routes come from route objects and <Route path>
# (React Router, Vue Router) and from file-based routing (pages/, app/**/page.*,
# src/routes/**/+page.svelte). External links (a scheme or //) are ignored.
#
# Output: one FAIL line per finding (FAIL  UX-Fn  SEVERITY  file:line  message), a
# PASS line per check with no finding (with the count checked), N/A when a check
# found nothing to check, NOTE lines (unrated, not failures) for links built at
# runtime and steps only the browser can settle, then "check-flow-integrity: ...".
# Limits: static. Markup is read as text: a ">" inside a template expression ends a
# tag early; a link built at runtime, a relative link inside a component and a
# cross-page fragment (page.html#x) are not resolved; a root-relative link that
# exists under some scanned directory counts as resolved. Every finding is "static"
# until the browser walk (UX-F5) confirms it.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk. awk runs with LC_ALL=C:
# in a UTF-8 locale some awks count characters in one place and bytes in another,
# which shifts line numbers after non-ASCII text, and stop on invalid UTF-8.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //' >&2; exit 2; }
CORE=""; FLOWS=""; BASE=""; BROWSERS=""
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --core) [ $# -ge 2 ] || usage; CORE="$CORE${2#./}
"; shift 2 ;;
    --flow) [ $# -ge 2 ] || usage
      case "$2" in *=?*) ;; *) echo "check-flow-integrity: --flow needs NAME=STEP,STEP,...: $2" >&2; exit 2 ;; esac
      FLOWS="$FLOWS$2
"; shift 2 ;;
    --base) [ $# -ge 2 ] || usage; BASE="$2"; shift 2 ;;
    --browsers) [ $# -ge 2 ] || usage; BROWSERS="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "check-flow-integrity: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || usage
case "$BASE" in ""|/*) ;; *) echo "check-flow-integrity: --base must start with /: $BASE" >&2; exit 2 ;; esac

MARKUP='html|htm|jsx|tsx|vue|svelte|astro|eta|ejs|hbs|njk|js|ts|mjs|cjs'
# a file name with a newline in it would split the file list, so it is skipped
NLNAME="$(printf '*\n*')"
ALL=""
for p in "${PATHS[@]}"; do
  if [ -d "$p" ]; then
    ALL="$ALL$(find -H "$p" \( -name node_modules -o -name dist -o -name build -o -name .git -o -name vendor \
      -o -name .svelte-kit -o -name .next -o -name .nuxt \) -prune -o -type f ! -path "$NLNAME" -print 2>/dev/null | LC_ALL=C sort || true)
"
  elif [ -f "$p" ]; then
    ALL="$ALL$p
"
  else
    echo "check-flow-integrity: no such file or directory: $p" >&2; exit 2
  fi
done
ALL=$(printf '%s' "$ALL" | grep -v '^$' | sed 's|^\./||' | LC_ALL=C sort -u || true)
SCAN=$(printf '%s\n' "$ALL" | grep -Ei "\\.($MARKUP)\$" | grep -Ev '\.min\.|\.(test|spec)\.|\.d\.ts$' || true)
CONF=$(printf '%s\n' "$ALL" | grep -E '(^|/)(package\.json|\.browserslistrc|tsconfig\.json|\.babelrc|babel\.config\.[a-z]+|vite\.config\.[a-z]+|nginx\.conf|[^/]*\.conf|_redirects|netlify\.toml|vercel\.json)$' || true)
[ -n "$SCAN" ] || { echo "check-flow-integrity: no markup or JS files under: ${PATHS[*]}" >&2; exit 2; }
while IFS= read -r c; do [ -n "$c" ] || continue; printf '%s\n' "$SCAN" | grep -qxF -e "$c" || { echo "check-flow-integrity: --core $c is not among the scanned files" >&2; exit 2; }; done <<EOF_CORE
$CORE
EOF_CORE
STEPS=$(printf '%s' "$FLOWS" | sed 's/^[^=]*=//' | tr ',' '\n' | sed 's|^\./||' | grep -v '^$' || true)
while IFS= read -r s; do
  case "$s" in ""|/*) continue ;; esac
  printf '%s\n' "$ALL" | grep -qxF -e "$s" || { echo "check-flow-integrity: flow step $s is not among the scanned files" >&2; exit 2; }
done <<EOF_STEPS
$STEPS
EOF_STEPS

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
printf '%s\n' "$ALL" > "$WORK/all"
printf '%s\n' "$CONF" > "$WORK/conf"

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
# Whole-line // comments only: a // inside a URL or a string stays.
function blank_line_comments(t,   n, ln, i, out) {
  n = split(t, ln, "\n"); out = ""
  for (i = 1; i <= n; i++) { if (ln[i] ~ /^[ \t]*\/\//) ln[i] = blank(ln[i]); out = out ln[i] (i < n ? "\n" : "") }
  return out
}
function line_at(t, pos,   seg) { seg = substr(t, 1, pos - 1); return gsub(/\n/, "", seg) + 1 }
# Line of pos in the file being scanned (CUR_T), counted on from the last call, so a
# page with thousands of links is read once, not once per link.
function lnat(pos,   seg) {
  if (pos < LA_P) { LA_P = 1; LA_L = 1 }
  seg = substr(CUR_T, LA_P, pos - LA_P); LA_L += gsub(/\n/, "", seg); LA_P = pos; return LA_L
}
function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
function dirof(f) { return (f ~ /\//) ? substr(f, 1, match(f, /\/[^\/]*$/) - 1) : "" }
function basename(f) { sub(/^.*\//, "", f); return f }
# Join a relative link to a directory, resolving "." and "..". "\001" when it climbs out.
# A leading / or ../ of the scanned path itself (an absolute PATH, or ../site) is kept.
function joinpath(dir, rel,   n, seg, i, out, m, st, pre) {
  pre = ""; if (dir ~ /^\//) { pre = "/"; dir = substr(dir, 2) }
  while (dir ~ /^\.\.(\/|$)/) { pre = pre "../"; dir = substr(dir, 4) }
  n = split((dir == "" ? "" : dir "/") rel, seg, "/"); m = 0
  for (i = 1; i <= n; i++) {
    if (seg[i] == "" || seg[i] == ".") continue
    if (seg[i] == "..") { if (m == 0) return "\001"; m--; continue }
    st[++m] = seg[i]
  }
  out = ""; for (i = 1; i <= m; i++) out = out (i > 1 ? "/" : "") st[i]
  return pre out (rel ~ /\/$/ && out != "" ? "/" : "")
}
# A path that exists as given, as x.html, as x/index.html or (for "x/") x/index.html.
function existing(t,   s) {
  s = t; sub(/\/$/, "", s)
  if (s == "" ) return ("index.html" in EXIST) ? "index.html" : ""
  if (t !~ /\/$/ && (s in EXIST)) return s
  if ((s ".html") in EXIST) return s ".html"
  if ((s "/index.html") in EXIST) return s "/index.html"
  return ""
}
function existing_suffix(t,   s) {
  s = t; sub(/\/$/, "", s)
  if (s == "") return ("index.html" in SUF) ? SUF["index.html"] : ""
  if (t !~ /\/$/ && (s in SUF)) return SUF[s]
  if ((s ".html") in SUF) return SUF[s ".html"]
  if ((s "/index.html") in SUF) return SUF[s "/index.html"]
  return ""
}
function dynseg(x) { return x ~ /^:/ || x ~ /^\[/ || x == "*" || x ~ /\(\.\*\)/ }
function catchall(x) { return x ~ /^\[\.\.\./ || x ~ /^\[\[\.\.\./ || x == "*" || x == "**" || x ~ /\(\.\*\)\*?$/ }
# Does the link path p (leading /) match the route pattern r (leading /)?
function route_match(p, r,   np, nr, sp, sr, i) {
  if (r == "/" ) return (p == "/" || p == "")
  np = split(substr(p, 2), sp, "/"); nr = split(substr(r, 2), sr, "/")
  if (np > 0 && sp[np] == "") np--
  for (i = 1; i <= nr; i++) {
    if (catchall(sr[i])) return 1
    if (i > np) return (sr[i] ~ /^\[\[/ && i == nr)
    if (dynseg(sr[i])) continue
    if (sr[i] != sp[i]) return 0
  }
  return np == nr
}
# A catch-all at the root (*, /:pathMatch(.*)*, /[...slug]) is the not-found route:
# it matches every link, so it never resolves one.
function route_ok(p,   k, first) {
  for (k = 1; k <= NR_; k++) {
    first = ROUTE[k]; sub(/^\//, "", first); sub(/\/.*$/, "", first)
    if (catchall(first)) continue
    if (route_match(p, ROUTE[k])) return 1
  }
  for (k = 1; k <= NREL; k++) if (rel_match(p, RELROUTE[k])) return 1
  return 0
}
# A relative route whose parent is unknown matches the last segments of the link.
function rel_match(p, r,   np, nr, sp, sr, i, d) {
  np = split(substr(p, 2), sp, "/"); if (np > 0 && sp[np] == "") np--
  nr = split(r, sr, "/"); if (nr > 0 && sr[nr] == "") nr--
  if (nr > np) return 0
  d = np - nr
  for (i = 1; i <= nr; i++) {
    if (catchall(sr[i])) return 1
    if (dynseg(sr[i])) continue
    if (sr[i] != sp[d + i]) return 0
  }
  return 1
}
function add_route(r) {
  r = trim(r); if (r == "" || r ~ /^(https?:|\.)/) return
  if (r !~ /^\//) { if (catchall(r)) { ROUTE[++NR_] = "/*"; NOTFOUND = NOTFOUND " " r } else RELROUTE[++NREL] = r; return }
  sub(/\/$/, "", r); if (r == "") r = "/"
  ROUTE[++NR_] = r
  if (r ~ /(^|\/)(\*\*?|\[\.\.\.[^]]*\]|\[\[\.\.\.[^]]*\]\]|:[A-Za-z]+\(\.\*\)\*?)$/) NOTFOUND = NOTFOUND " " r
}
# The route a file-based router gives a file, or "".
function file_route(f,   r, n, seg, i, out) {
  if (f ~ /(^|\/)src\/routes\// && f ~ /\/\+page\.(svelte|ts|js)$/) { r = f; sub(/^.*src\/routes\//, "", r); sub(/\/?\+page\.[a-z]+$/, "", r) }
  else if (f ~ /(^|\/)app\// && f ~ /\/page\.(jsx|tsx|js|ts|mdx)$/) { r = f; sub(/^.*(^|\/)app\//, "", r); sub(/\/?page\.[a-z]+$/, "", r) }
  # pages/ routes only in a framework that routes by file; elsewhere it is a folder name
  else if (PAGESROUTER && f ~ /(^|\/)pages\// && f ~ /\.(jsx|tsx|js|ts|vue|astro|mdx|md)$/) {
    r = f; sub(/^.*(^|\/)pages\//, "", r); sub(/\.[a-z]+$/, "", r)
    if (r ~ /(^|\/)(_|api\/)/) return ""
    sub(/(^|\/)index$/, "", r)
  } else return ""
  n = split(r, seg, "/"); out = ""
  for (i = 1; i <= n; i++) { if (seg[i] ~ /^\(.*\)$/ || seg[i] ~ /^@/ || seg[i] == "") continue; out = out "/" seg[i] }
  return out == "" ? "/" : out
}
# The literal value of attribute nm in tag, "\002" when it is built at runtime, "" when absent.
function attrv(tag, nm,   lt, v, c, i, bound, inner) {
  lt = tolower(tag)
  if (!match(lt, "[ \t\r\n](v-bind:|:)?" nm "[ \t\r\n]*=[ \t\r\n]*")) return ""
  bound = (substr(lt, RSTART + 1, 1) == ":" || substr(lt, RSTART + 1, 7) == "v-bind:")
  v = substr(tag, RSTART + RLENGTH); c = substr(v, 1, 1)
  # inside a script string the quotes are escaped: aria-controls=\"nav\"
  if (c == "\\" && substr(v, 2, 1) ~ /["\047]/) { c = substr(v, 2, 1); v = substr(v, 3); i = index(v, "\\" c); if (i == 0) return "\002"; v = substr(v, 1, i - 1) }
  else if (c == "\"" || c == "\047") { v = substr(v, 2); i = index(v, c); if (i == 0) return "\002"; v = substr(v, 1, i - 1) }
  else if (c == "{") {
    i = index(v, "}"); if (i == 0) return "\002"
    v = trim(substr(v, 2, i - 2)); c = substr(v, 1, 1)
    if ((c == "\"" || c == "\047" || c == "`") && length(v) > 1 && substr(v, length(v), 1) == c && v !~ /\$\{/) return substr(v, 2, length(v) - 2)
    return "\002"
  } else { match(v, /^[^ \t\r\n>]+/); v = substr(v, 1, RLENGTH); sub(/\/$/, "", v) }
  if (bound) {
    v = trim(v); c = substr(v, 1, 1)
    if ((c == "\047" || c == "`") && length(v) > 1 && substr(v, length(v), 1) == c && v !~ /\$\{/) return substr(v, 2, length(v) - 2)
    return "\002"
  }
  if (v ~ /\{\{|\$\{|<%|\{%|^\{/) return "\002"
  # a value built by string concatenation in a script, a quote then a plus sign
  if (v ~ /^[ \t]*[\047"`][ \t]*\+|\+[ \t]*[\047"`][ \t]*$/) return "\002"
  return v
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
function is_page(f) { return f ~ /\.(html|htm|eta|ejs|hbs|njk)$/ }

function pend_f2(f, ln, what, id, msg, sev) { PEND[++NPEND] = f SUBSEP ln SUBSEP what SUBSEP id SUBSEP msg SUBSEP sev }
function fail(k, f, ln, msg, sev) {
  NF_[k]++; NFAIL++
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s:%d  %s\n", "UX-" k, (sev == "") ? SEV[k] : sev, shown(f), ln, msg)
}
function note(k, f, ln, msg) { NOTES[k] = NOTES[k] sprintf("NOTE  %-7s %-6s %s:%d  %s\n", "UX-" k, "-", shown(f), ln, msg) }
function shown(f) { return (f ~ /^\// || f ~ /^\.\.\//) ? f : "./" f }

# Record one navigation target v found at pos in file f. Returns nothing; checks UX-F1
# and remembers what the link reaches, for UX-F3.
function link(f, pos, v,   p, frag, r, hit, sev, q, d) {
  if (v == "\002") { DYN[f]++; if (!(f in DYNAT)) DYNAT[f] = lnat(pos); return }
  v = trim(v)
  if (v == "" || v ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || v ~ /^\/\//) { if (v != "") TGT[f, "\003ext"] = 1; return }
  if (v ~ /^#/) return
  p = v; sub(/[?#].*$/, "", p)
  # the message never repeats a query string: it can carry a token
  d = v; sub(/\?[^#]*/, "?...", d)
  if (p == "") return
  sev = (f in COREF) ? "High" : ""
  if (p ~ /^\//) {
    if (BASE != "" && (p == BASE || index(p, BASE "/") == 1)) { p = substr(p, length(BASE) + 1); if (p == "") p = "/" }
    CHK["F1"]++
    if (route_ok(p)) { LINKS[f] = LINKS[f] SUBSEP p; return }
    hit = existing(substr(p, 2)); if (hit == "") hit = existing_suffix(substr(p, 2))
    if (hit != "") { TGT[f, hit] = 1; return }
    fail("F1", f, lnat(pos), "link \"" d "\" resolves to no file or route", sev); return
  }
  if (!is_page(f)) { REL[f]++; if (!(f in RELAT)) RELAT[f] = lnat(pos); return }
  CHK["F1"]++
  q = joinpath(dirof(f), p)
  hit = (q == "\001") ? "" : existing(q)
  # a server template (eta, ejs, hbs, njk) is served from a URL, not from where it sits
  if (hit == "" && f ~ /\.(eta|ejs|hbs|njk)$/) { r = p; while (sub(/^\.\.?\//, "", r)) ; hit = existing_suffix(r) }
  if (hit != "") { TGT[f, hit] = 1; return }
  fail("F1", f, lnat(pos), "link \"" d "\" resolves to no file" (q == "\001" ? " (it climbs above the scanned tree)" : ""), sev)
}

function scan_file(f, t,   rest, lrest, off, tag, nm, lname, v, i, n, parts, k, ids, refs, dynid, sev, m, lt, pos, at) {
  t = blank_between(t, "<!--", "-->")
  t = code_comments(t, f)
  lt = tolower(t); CUR_T = t; LA_P = 1; LA_L = 1
  # ids in this file, for UX-F2
  split("", ids); dynid = 0
  rest = t; lrest = lt; off = 0
  while (match(lrest, /[ \t\r\n](:|v-bind:)?id[ \t\r\n]*=[ \t\r\n]*/)) {
    at = RSTART + RLENGTH; v = substr(rest, at); m = substr(rest, RSTART + 1, 1)
    if (m == ":" || m == "v") dynid = 1
    else if (v ~ /^"/) { v = substr(v, 2); i = index(v, "\""); v = substr(v, 1, i - 1); if (v ~ /\{\{|\$\{|\{|<%/) dynid = 1; else { ids[v] = 1; if (!(v in GID)) GID[v] = f } }
    else if (v ~ /^\047/) { v = substr(v, 2); i = index(v, "\047"); v = substr(v, 1, i - 1); if (v ~ /\{\{|\$\{|\{|<%/) dynid = 1; else { ids[v] = 1; if (!(v in GID)) GID[v] = f } }
    else if (v ~ /^\{/) { if (v ~ /^\{[ \t]*"[^"]*"[ \t]*\}/) { sub(/^\{[ \t]*"/, "", v); sub(/".*/, "", v); ids[v] = 1; if (!(v in GID)) GID[v] = f } else dynid = 1 }
    # an unquoted value (id=main) ends at a space, > or />
    else if (v ~ /^[^ \t\r\n>"\047`{\/]/) { match(v, /^[^ \t\r\n>"\047`]+/); v = substr(v, 1, RLENGTH); sub(/\/$/, "", v); ids[v] = 1; if (!(v in GID)) GID[v] = f }
    off += at - 1; rest = substr(rest, at); lrest = substr(lrest, at)
  }
  sev = (f in COREF) ? "High" : ""
  # tags
  rest = t; off = 0
  while (match(rest, /<[A-Za-z][A-Za-z0-9:._-]*/)) {
    nm = substr(rest, RSTART + 1, RLENGTH - 1); lname = tolower(nm)
    at = RSTART; k = index(substr(rest, at), ">"); if (k == 0) break
    tag = substr(rest, at, k); pos = off + at
    if (lname == "a" || lname == "area") {
      v = attrv(tag, "href")
      # a hash-router link (#/settings, #!/about) or the #! placeholder is not an in-page anchor
      if (v ~ /^#!/ || v ~ /^#\//) link(f, pos, "\002")
      else if (v ~ /^#./ && v != "\002") {
        CHK["F2"]++; v = substr(v, 2)
        if (tolower(v) != "top" && !(v in ids)) {
          if (dynid) note("F2", f, lnat(pos), "anchor \"#" v "\" has no static target; this file builds ids at runtime")
          else pend_f2(f, lnat(pos), "anchor \"#" v "\"", v, "has no element with that id in this file", sev)
        }
      } else if (v != "") link(f, pos, v)
      if (tolower(tag) ~ /aria-label[ \t]*=[ \t]*["\047][ \t]*(back|cancel|close|home|previous|exit)/) BACK[f] = 1
    }
    else if (lname == "form") { v = attrv(tag, "action"); if (v != "") link(f, pos, v) }
    else if (lname == "iframe") { v = attrv(tag, "src"); if (v != "") link(f, pos, v) }
    else if (lname == "script") { v = attrv(tag, "src"); if (v != "" && v != "\002" && v !~ /^[A-Za-z][A-Za-z0-9+.-]*:|^\/\//) SCRIPTS[f] = SCRIPTS[f] SUBSEP v }
    else if (lname ~ /^(link|navlink|router-link|routerlink|nuxtlink|nuxt-link|navigate)$/ && nm != "link") {
      v = attrv(tag, "to"); if (v == "") v = attrv(tag, "href")
      if (v != "") link(f, pos, v)
    }
    if (lname == "button" && tolower(tag) ~ /aria-label[ \t]*=[ \t]*["\047][ \t]*(back|cancel|close|home|previous|exit)/) BACK[f] = 1
    n = split("aria-controls aria-describedby aria-labelledby", parts, " ")
    for (i = 1; i <= n; i++) {
      v = attrv(tag, parts[i])
      if (v == "" || v == "\002") continue
      m = split(v, refs, /[ \t]+/)
      for (k = 1; k <= m; k++) {
        if (refs[k] == "") continue
        CHK["F2"]++
        if (!(refs[k] in ids)) {
          if (dynid) note("F2", f, lnat(pos), parts[i] " \"" refs[k] "\" has no static target; this file builds ids at runtime")
          else pend_f2(f, lnat(pos), parts[i] " \"" refs[k] "\"", refs[k], "names no element in this file", sev)
        }
      }
    }
    off += at; rest = substr(rest, at + 1)
  }
  # navigation calls in script
  rest = t; off = 0
  while (match(rest, /(location\.(href|pathname)[ \t]*=|location\.(assign|replace)\(|window\.location[ \t]*=|[^A-Za-z0-9_.]navigate\(|router\.(push|replace)\(|[^A-Za-z0-9_.]goto\()[ \t]*["\047`]/)) {
    at = RSTART + RLENGTH; pos = off + RSTART; v = substr(rest, at - 1); m = substr(v, 1, 1); v = substr(v, 2)
    i = index(v, m)
    if (i > 0) { v = substr(v, 1, i - 1); if (m == "`" && v ~ /\$\{/) v = "\002"; link(f, pos, v) }
    off += at - 1; rest = substr(rest, at)
  }
  if (lt ~ /history\.(back|go)\(|router\.back\(/) BACK[f] = 1
  if (lt ~ /<(a|button)[^>]*>[ \t\r\n]*(&larr;|&lt;)?[ \t\r\n]*(back|cancel|close|exit|home|previous|return|start over)/) BACK[f] = 1
}

# Route sources: route objects and file-based routes, before any link is checked.
# A child route path joined to its parent: "invoices" under "/app" is "/app/invoices".
function child_route(parent, r) {
  r = trim(r)
  if (r ~ /^\// || parent == "") return r
  return (parent == "/" ? "" : parent) "/" r
}
# The end of a JSX tag that may hold {...} with > inside (element={<About />}); 0 if none.
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
# Route sources, before any link is checked: route objects (with children: arrays),
# JSX <Route> elements (nested ones joined to their parent) and server routes.
function collect_routes(f, t,   rest, v, m, i, at, ms, ml, ev, k, tag, sd, sp, nst, depth, last, r) {
  if (f !~ /\.(js|ts|mjs|cjs|jsx|tsx|vue)$/) return
  t = blank_between(t, "/*", "*/"); t = blank_line_comments(t)
  # route objects; a children: [ ... ] array takes the last path before it as its parent
  rest = t; nst = 0; depth = 0; last = ""
  while (match(rest, /[^A-Za-z0-9_.]path[ \t]*:[ \t]*["\047`]|children[ \t]*:[ \t]*\[|[][]/)) {
    ms = RSTART; ml = RLENGTH; ev = substr(rest, ms, ml)
    if (ev == "[") depth++
    else if (ev == "]") { depth--; if (nst > 0 && depth < sd[nst]) nst-- }
    else if (ev ~ /^children/) { depth++; sd[++nst] = depth; sp[nst] = last }
    else {
      v = substr(rest, ms + ml - 1); m = substr(v, 1, 1); v = substr(v, 2); i = index(v, m)
      if (i > 0) { r = child_route(nst > 0 ? sp[nst] : "", substr(v, 1, i - 1)); add_route(r); if (r ~ /^\//) last = r }
    }
    rest = substr(rest, ms + ml)
  }
  # JSX routes: an open <Route path="x"> is the parent of the routes inside it
  rest = t; nst = 0
  while (match(rest, /<\/?Route[ \t\r\n>\/]/)) {
    ms = RSTART; ml = RLENGTH
    if (substr(rest, ms + 1, 1) == "/") { if (nst > 0) nst--; rest = substr(rest, ms + ml); continue }
    k = tag_end(substr(rest, ms)); if (k == 0) break
    tag = substr(rest, ms, k); v = attrv(tag, "path")
    r = (v == "" || v == "\002") ? "" : child_route(nst > 0 ? sp[nst] : "", v)
    if (r != "") add_route(r)
    if (tag !~ /\/[ \t\r\n]*>$/) { sp[++nst] = (r != "" ? r : (nst > 1 ? sp[nst - 1] : "")) }
    rest = substr(rest, ms + k)
  }
  # server routes: app.get("/login"), router.post("/x"), fastify.route
  rest = t
  while (match(rest, /(app|router|server|fastify|api)\.(get|post|put|patch|delete|all|use|route)\([ \t\r\n]*["\047`]\//)) {
    ms = RSTART; ml = RLENGTH
    v = substr(rest, ms + ml - 2); m = substr(v, 1, 1); v = substr(v, 2); i = index(v, m)
    if (i > 0 && v !~ /^\/[*]?["\047`]/) add_route(substr(v, 1, i - 1))
    rest = substr(rest, ms + ml)
  }
}

function family_of(x) {
  x = tolower(x)
  if (x ~ /^(ios_saf|ios|iossafari)/) return "ios_saf"
  if (x ~ /^(safari)/) return "safari"
  if (x ~ /^(firefox|ff|and_ff)/) return "firefox"
  if (x ~ /^(chrome|and_chr|chromeandroid)/) return "chrome"
  if (x ~ /^(edge)/) return "edge"
  if (x ~ /^(samsung)/) return "samsung"
  if (x ~ /^(opera|op_)/) return "opera"
  return ""
}
function check_targets(   f, t, i, n, q, nq, k, decl, build, pj, fams, fam, only, ex, at, s, j, x, ln, need, bi) {
  if (BROWSERS == "") return
  pj = ""; build = 0; decl = ""; nq = 0
  for (i = 1; i <= NCONF; i++) {
    f = CONFF[i]; t = CONFT[i]
    if (basename(f) == "package.json") {
      if (pj == "") pj = f
      if (t ~ /"(vite|webpack|next|nuxt|@sveltejs\/kit|parcel|@babel\/core|esbuild|rollup|react-scripts|astro|typescript)"[ \t]*:/ || t ~ /"build"[ \t]*:/) build = 1
      # the browserslist key, not the browserslist package in a dependency list
      s = t; j = 0
      while ((bi = index(s, "\"browserslist\"")) > 0) {
        s = substr(s, bi + 14); x = s; sub(/^[ \t\r\n]*:[ \t\r\n]*/, "", x)
        if (x ~ /^[[{]/ || (x ~ /^"/ && x !~ /^"[\^~<>=*0-9]|^"(latest|npm:|workspace:)/)) { j = 1; break }
      }
      if (j) {
        s = x
        if (s ~ /^"/) { s = substr(s, 2); s = substr(s, 1, index(s, "\"") - 1); nq = split(s, q, ","); }
        else { s = (s ~ /^\[/) ? substr(s, 1, index(s, "]")) : substr(s, 1, index(s, "}")); while (match(s, /"[^"]*"/)) { x = substr(s, RSTART + 1, RLENGTH - 2); if (x !~ /^(production|development|test)$/) q[++nq] = x; s = substr(s, RSTART + RLENGTH) } }
        decl = f
      }
    } else if (basename(f) == ".browserslistrc") {
      n = split(t, ln, "\n"); for (k = 1; k <= n; k++) { x = trim(ln[k]); if (x != "" && x !~ /^#/ && x !~ /^\[/) q[++nq] = x }
      decl = f
    } else if (f ~ /(^|\/)vite\.config\.[a-z]+$/ && t ~ /target[ \t]*:/) { if (decl == "") decl = f }
    else if (f ~ /(^|\/)(babel\.config\.[a-z]+|\.babelrc)$/ && t ~ /targets/) { if (decl == "") decl = f }
    else if (basename(f) == "tsconfig.json" && t ~ /"target"[ \t]*:/) { if (decl == "") decl = f }
  }
  if (pj == "" || !build) return
  CHK["F7"]++
  if (decl == "") { fail("F7", pj, 1, "the project has a build step but declares no browser targets (browserslist, build.target); the contract lists " BROWSERS); return }
  if (nq == 0) return
  n = split(BROWSERS, fams, ",")
  only = 1
  for (k = 1; k <= nq; k++) { x = trim(tolower(q[k])); if (x ~ /^not /) continue; if (family_of(x) == "") only = 0 }
  for (i = 1; i <= n; i++) {
    x = tolower(trim(fams[i])); split("", need)
    if (x ~ /evergreen|^last-/) { need["chrome"]; need["firefox"]; need["edge"]; need["safari"] }
    else if (x ~ /ios/) need["ios_saf"]
    else if ((fam = family_of(x)) != "") need[fam]
    for (fam in need) {
      ex = 0; at = 0
      for (k = 1; k <= nq; k++) {
        s = trim(tolower(q[k]))
        if (s ~ /^not /) { sub(/^not[ \t]+/, "", s); if (family_of(s) == fam && s !~ /[<>=0-9]/) ex = 1 }
        else if (family_of(s) == fam) at = 1
      }
      if (ex) fail("F7", decl, 1, "the browser targets exclude " fam ", which the contract lists (" trim(fams[i]) ")")
      else if (only && !at) fail("F7", decl, 1, "the browser targets name specific browsers and leave out " fam ", which the contract lists (" trim(fams[i]) ")")
    }
  }
}

BEGIN {
  split("F1 F2 F3 F4 F7", ORDER, " ")
  SEV["F1"] = "Medium"; SEV["F2"] = "Medium"; SEV["F3"] = "High"; SEV["F4"] = "Low"; SEV["F7"] = "Low"
  D["F1"] = "links resolve to a file or a route"; D["F2"] = "in-page and ARIA id targets exist"
  D["F3"] = "core-flow steps have a way forward and a way out"; D["F4"] = "a not-found page or catch-all route exists"
  D["F7"] = "build targets match the contract browsers"
  BASE = ENVIRON["F_BASE"]; BROWSERS = ENVIRON["F_BROWSERS"]
  while ((getline f < ENVIRON["F_ALL"]) > 0) if (basename(f) == "package.json") {
    while ((getline x < f) > 0) if (x ~ /"(next|nuxt|astro|gatsby)"[ \t]*:/) PAGESROUTER = 1
    close(f)
  }
  close(ENVIRON["F_ALL"])
  while ((getline f < ENVIRON["F_ALL"]) > 0) {
    if (f == "") continue
    EXIST[f] = 1
    s = f; while ((i = index(s, "/")) > 0) { s = substr(s, i + 1); if (!(s in SUF)) SUF[s] = f }
    if ((r = file_route(f)) != "") { add_route(r); FROUTE[f] = r }
    if (basename(f) ~ /^(404|not-found|notfound|_error|\+error)\./) NOTFOUND = NOTFOUND " " f
  }
  close(ENVIRON["F_ALL"])
  while ((getline f < ENVIRON["F_CONF"]) > 0) {
    if (f == "") continue
    t = ""; while ((getline x < f) > 0) { t = t x "\n"; if (length(t) > 524288) break }; close(f)
    CONFF[++NCONF] = f; CONFT[NCONF] = t
    if (t ~ /error_page[ \t]+(40[0-9][ \t]+)*404/ || (basename(f) == "_redirects" && t ~ /[ \t]404[!]?[ \t]*(\n|$)/) || t ~ /status[ \t]*=[ \t]*404/) NOTFOUND = NOTFOUND " " f
  }
  close(ENVIRON["F_CONF"])
  nc = split(ENVIRON["F_CORE"], cl, "\n"); for (i = 1; i <= nc; i++) if (cl[i] != "") COREF[cl[i]] = 1
  NFL = split(ENVIRON["F_FLOWS"], fl, "\n")
  for (i = 1; i <= NFL; i++) {
    if (fl[i] == "") continue
    NFLOW++; FNAME[NFLOW] = substr(fl[i], 1, index(fl[i], "=") - 1)
    FSTEPS[NFLOW] = substr(fl[i], index(fl[i], "=") + 1)
    n = split(FSTEPS[NFLOW], st, ","); for (k = 1; k <= n; k++) { s = st[k]; sub(/^\.\//, "", s); if (s !~ /^\//) COREF[s] = 1 }
  }
  # a file over 512 KB is a bundle, not source: reading it would take minutes on some awks
  for (i = 1; i < ARGC; i++) { g = ARGV[i]; f = g; sub(/^\.\//, "", f); T = ""; big = 0; while ((getline x < g) > 0) { T = T x "\n"; if (length(T) > 524288) { big = 1; break } } close(g); FILES[i] = f; if (big) { BIG[f] = 1; T = "" } TEXT[i] = T; collect_routes(f, T) }
  for (i = 1; i < ARGC; i++) scan_file(FILES[i], TEXT[i])
  # an id another scanned file defines may be rendered into this view at runtime: a NOTE
  for (i = 1; i <= NPEND; i++) {
    split(PEND[i], pp, SUBSEP)
    if ((pp[4] in GID) && GID[pp[4]] != pp[1]) note("F2", pp[1], pp[2], pp[3] " is not in this file; " GID[pp[4]] " defines it, so confirm in the browser")
    else fail("F2", pp[1], pp[2], pp[3] " " pp[5], pp[6])
  }
  NFILES = ARGC - 1

  # UX-F3: each core-flow step reaches the next and has a way back or out.
  for (i = 1; i <= NFLOW; i++) {
    n = split(FSTEPS[i], st, ",")
    for (k = 1; k <= n; k++) { s = st[k]; sub(/^\.\//, "", s); st[k] = s }
    for (k = 1; k <= n; k++) {
      s = st[k]
      if (s ~ /^\//) { note("F3", "-", 0, "flow " FNAME[i] ": step " s " is a route, not a file; the browser walk (UX-F5) checks it"); continue }
      if (!is_page(s) && !(s in FROUTE)) { note("F3", s, 1, "flow " FNAME[i] ": step " s " is a component without a file-based route; the browser walk (UX-F5) checks it"); continue }
      CHK["F3"]++
      # targets of the step, and of the scripts an HTML step loads
      split("", reach); hasout = (s in BACK)
      for (key in TGT) { split(key, kp, SUBSEP); if (kp[1] == s) reach[kp[2]] = 1 }
      nsr = split(SCRIPTS[s], sr, SUBSEP)
      for (j = 2; j <= nsr; j++) {
        q = (sr[j] ~ /^\//) ? existing_suffix(substr(sr[j], 2)) : joinpath(dirof(s), sr[j])
        if (q == "" || q == "\001") continue
        for (key in TGT) { split(key, kp, SUBSEP); if (kp[1] == q) reach[kp[2]] = 1 }
        if (q in BACK) hasout = 1
        LINKS[s] = LINKS[s] LINKS[q]
      }
      fwd = 0
      if (k < n) {
        nx = st[k + 1]
        if (nx in reach) fwd = 1
        else if (nx in FROUTE) { nl = split(LINKS[s], lk, SUBSEP); for (j = 2; j <= nl; j++) if (route_match(lk[j], FROUTE[nx])) fwd = 1 }
        if (!fwd) fail("F3", s, 1, "flow " FNAME[i] ": step " k " has no link, form or navigation to the next step " nx, "High")
      }
      for (key in reach) if (key != s && (k == n || key != st[k + 1])) hasout = 1
      # a link that resolved to a route is a way out unless it leads to the next step or back here
      nl = split(LINKS[s], lk, SUBSEP)
      for (j = 2; j <= nl; j++) {
        if (k < n && (st[k + 1] in FROUTE) && route_match(lk[j], FROUTE[st[k + 1]])) continue
        if ((s in FROUTE) && route_match(lk[j], FROUTE[s])) continue
        hasout = 1
      }
      if (!hasout) fail("F3", s, 1, "flow " FNAME[i] ": step " k " has no way back or out (a link elsewhere, a back, cancel or close control)", "Medium")
    }
  }
  # UX-F4: one finding for the whole app.
  for (i = 1; i < ARGC; i++) if (FILES[i] ~ /\.(html|htm)$/ || (FILES[i] in FROUTE)) { pages++; if (first == "" || basename(FILES[i]) == "index.html" && basename(first) != "index.html") first = FILES[i] }
  # a single page with no router has no URL that could be "not found"
  if (first == "") first = FILES[1]
  if (pages > 1 || NR_ > 0) { CHK["F4"]++; if (NOTFOUND == "") fail("F4", first, 1, "the app has no not-found page (404.html, not-found.*, +error.svelte) or catch-all route (*, [...slug], /:pathMatch(.*)*), and no server fallback for 404") }
  check_targets()
  for (i = 1; i < ARGC; i++) {
    f = FILES[i]
    if (f in BIG) note("F1", f, 1, "not read: larger than 512 KB, so a bundle rather than source; the browser walk covers it")
    if (DYN[f] + REL[f] > 0) note("F1", f, (f in DYNAT) ? DYNAT[f] : RELAT[f], (DYN[f] + REL[f]) " link(s) not resolved statically (built at runtime, or relative inside a component); the browser walk follows them")
  }
  for (i = 1; i <= 5; i++) {
    k = ORDER[i]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "UX-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (nothing to check)\n", "UX-" k, D[k]
    printf "%s", NOTES[k]
  }
  printf "check-flow-integrity: %d file(s), %d failure(s) (static checks; confirm in the browser walk)\n", NFILES, NFAIL
  exit (NFAIL > 0) ? 1 : 0
}'
# awk reads "a=b.html" as an assignment, so every path is passed as ./path; the
# leading ./ is removed again inside.
ARGS=()
while IFS= read -r f; do [ -n "$f" ] && ARGS+=("$f"); done <<EOF_FILES
$SCAN
EOF_FILES
cd_args=()
for f in "${ARGS[@]}"; do case "$f" in /*) cd_args+=("$f") ;; *) cd_args+=("./$f") ;; esac; done
F_ALL="$WORK/all" F_CONF="$WORK/conf" F_CORE="$CORE" F_FLOWS="$FLOWS" F_BASE="$BASE" F_BROWSERS="$BROWSERS" \
  LC_ALL=C awk "$PROG" "${cd_args[@]}"
