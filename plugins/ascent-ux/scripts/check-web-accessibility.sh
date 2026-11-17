#!/usr/bin/env bash
# Static accessibility checks for web markup: HTML and the common template
# syntaxes (JSX/TSX, Vue, Svelte, Astro, Eta, EJS, Handlebars, Nunjucks). Part of
# the ascent-ux plugin (ux-review Step 3, accessibility-audit Step 2). Read-only.
#
# Usage: check-web-accessibility.sh [--core FILE]... PATH...
#
# PATH is a file or a directory (searched for markup, CSS and JS/TS, skipping
# node_modules, dist, build, .git, vendor, *.min.* and *.test.*/*.spec.*). In
# .js/.ts/.mjs/.cjs files only HTML inside template literals is checked (views of
# single-page apps); those findings say "[js template]", and UX-U7 and UX-U8 are not applied
# there because one file holds many separate templates. --core marks a file as part
# of a core user flow (with or without a leading ./): UX-U3 and UX-U12 failures there are
# High instead of Medium.
#
# Checks (severity from the ux-review severity table; WCAG 2.2 criterion):
#   UX-U1  Medium  <html> declares lang                                  3.1.1
#   UX-U2  Medium  every <img> has alt (alt="" when decorative)          1.1.1
#   UX-U3  Medium  form controls have a label, aria-label or aria-labelledby   1.3.1, 4.1.2
#   UX-U4  Medium  buttons and links have an accessible name             4.1.2, 2.4.4
#   UX-U5  Medium  the viewport meta tag allows zoom                     1.4.4
#   UX-U6  Low     no positive tabindex                                  2.4.3
#   UX-U7  Low     heading levels do not skip; a full page has an <h1> (or a scanned JS
#               template renders one: a NOTE, to confirm in the browser)  1.3.1, 2.4.6
#   UX-U8  Low     id values are unique within a file                    4.1.2
#   UX-U9  Medium  a full page has a non-empty <title>                   2.4.2
#   UX-U10 Medium  autoplay media is muted and has controls              1.4.2, 2.2.2
#   UX-U11 Medium  an outline removed on a selector is replaced by a :focus-visible style for
#               that selector (or a universal :focus-visible rule), or by a box-shadow
#               ring in the same :focus rule with 3:1 against the page background in
#               every theme the CSS defines (1.4.11; a NOTE when the ring's colour or
#               the background cannot be read)                        2.4.7, 2.4.11
#   UX-U12 Medium  click handlers sit on elements a keyboard can reach (role, tabindex, key
#               handler), including elements a JS click listener in any scanned file
#               finds with closest() or matches() ("[delegated]")     2.1.1
#
# Output: one FAIL line per finding (FAIL  Uk  SEVERITY  file:line  message), a
# PASS line per check with no finding (with the count checked), N/A when a check
# found nothing to check, NOTE lines (unrated, not failures) for what only the
# browser can settle, then "check-web-accessibility: ...".
# Limits: static. Markup is read as text: a ">" inside a template expression ends a
# tag early, names built at runtime cannot be seen (a dynamic name counts as
# present), capitalized JSX/Vue/Svelte components are skipped, elements built with
# document.createElement are not seen, and delegated listeners are matched only for
# compound selectors (a tag, #id, .class, [attr] and [attr="value"]; a list is split
# at its commas): a selector with a combinator or a pseudo-class is skipped, and a
# bare tag (closest("li")) is matched only in the listener's own file. The key
# listener that excuses a delegated element must be in the listener's file. A
# box-shadow ring is measured against the html, body or :root background (white
# when none is set), not against the element's own container (read the rest, and
# rely on the browser pass). Every finding is "static" until the browser pass (live
# accessibility tree) confirms it.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk. awk runs with LC_ALL=C:
# in a UTF-8 locale some awks count characters in one place and bytes in another,
# which shifts line numbers after non-ASCII text, and stop on invalid UTF-8.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //' >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/lib/tokens.awk"
[ -f "$LIB" ] || { echo "check-web-accessibility: missing $LIB" >&2; exit 2; }
CORE=""
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --core) [ $# -ge 2 ] || usage; CORE="$CORE$2
"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "check-web-accessibility: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || usage

MARKUP='html|htm|jsx|tsx|vue|svelte|astro|eta|ejs|hbs|njk'
FILES=""
for p in "${PATHS[@]}"; do
  if [ -d "$p" ]; then
    FILES="$FILES$(find "$p" \( -name node_modules -o -name dist -o -name build -o -name .git -o -name vendor \) -prune -o \
      -type f -print 2>/dev/null | grep -Ei "\\.($MARKUP|css|scss|js|ts|mjs|cjs)\$" | grep -Ev '\.min\.|\.(test|spec)\.' | LC_ALL=C sort || true)
"
  elif [ -f "$p" ]; then
    printf '%s\n' "$p" | grep -Eiq "\\.($MARKUP|css|scss|js|ts|mjs|cjs)\$" || { echo "check-web-accessibility: not a markup, CSS or JS file: $p" >&2; exit 2; }
    FILES="$FILES$p
"
  else
    echo "check-web-accessibility: no such file or directory: $p" >&2; exit 2
  fi
done
FILES=$(printf '%s' "$FILES" | grep -v '^$' || true)
[ -n "$FILES" ] || { echo "check-web-accessibility: no markup, CSS or JS files under: ${PATHS[*]}" >&2; exit 2; }
for c in $(printf '%s' "$CORE"); do printf '%s\n' "$FILES" | sed 's|^\./||' | grep -qxF "${c#./}" || { echo "check-web-accessibility: --core $c is not among the scanned files" >&2; exit 2; }; done


PROG="$(cat "$LIB")"'
function blank(s) { gsub(/[^\n]/, " ", s); return s }
function blank_between(opn, cls, keep,   out, rest, i, j, done) {
  out = ""; rest = B; done = 0
  while ((i = index(tolower(rest), opn)) > 0) {
    j = index(substr(tolower(rest), i + length(opn)), cls)
    if (j == 0) { out = out substr(rest, 1, i - 1) blank(substr(rest, i)); rest = ""; break }
    j = i + length(opn) + j - 1 + length(cls)
    if (keep) { NST++; SST[NST] = done + i; SEN[NST] = done + j }
    out = out substr(rest, 1, i - 1) blank(substr(rest, i, j - i))
    done += j - 1; rest = substr(rest, j)
  }
  B = out rest
}
function blank_css_comments(t,   out, i, j) {
  out = ""
  while ((i = index(t, "/*")) > 0) {
    j = index(substr(t, i + 2), "*/")
    if (j == 0) { out = out substr(t, 1, i - 1) blank(substr(t, i)); t = ""; break }
    out = out substr(t, 1, i - 1) blank(substr(t, i, j + 3)); t = substr(t, i + j + 3)
  }
  return out t
}
function selector_before(t, p,   pre, k, j, c) {
  pre = substr(t, 1, p); k = 0
  for (j = length(pre); j > 0; j--) { c = substr(pre, j, 1); if (c == "{") { k = j; break } if (c == "}") return "" }
  if (k == 0) return ""
  pre = substr(pre, 1, k - 1)
  for (j = length(pre); j > 0; j--) { c = substr(pre, j, 1); if (c == "}" || c == "{" || c == ";" || c == ">") break }
  return substr(pre, j + 1)
}
function selnorm(x) { gsub(/::?[A-Za-z-]+(\([^)]*\))?/, "", x); gsub(/[ \t\r\n]+/, " ", x); sub(/^ /, "", x); sub(/ $/, "", x); return x }
function covered(sel,   n, parts, i, b) {
  if (FVALL) return 1
  n = split(sel, parts, ",")
  if (n == 0) return 0
  for (i = 1; i <= n; i++) { b = selnorm(parts[i]); if (b == "" || !(b in FVSEL)) return 0 }
  return 1
}
function fv_prepass(raw,   full, t, off, p, j, c, k, sel, n, parts, i, b) {
  full = blank_css_comments(raw); t = full; off = 0
  while (match(t, /:focus-visible/)) {
    p = off + RSTART
    for (j = p - 1; j > 0; j--) { c = substr(full, j, 1); if (c == "{" || c == "}" || c == ";" || c == ">") break }
    k = index(substr(full, p), "{")
    sel = (k == 0) ? substr(full, j + 1, p - j - 1 + RLENGTH) : substr(full, j + 1, p - j - 1 + k - 1)
    n = split(sel, parts, ",")
    for (i = 1; i <= n; i++) if (parts[i] ~ /:focus-visible/) { b = selnorm(parts[i]); if (b == "" || b == "*" || b == "html" || b == "body") FVALL = 1; else FVSEL[b] = 1 }
    off += RSTART + RLENGTH - 1; t = substr(t, RSTART + RLENGTH)
  }
}
function ring(t, p,   j, e, body, v) {
  for (j = p; j > 0; j--) if (substr(t, j, 1) == "{") break
  e = index(substr(t, p), "}"); body = (e == 0) ? substr(t, j + 1) : substr(t, j + 1, p - j - 1 + e - 1)
  if (!match(body, /box-shadow[ \t\r\n]*:[^;}]*/)) return 0
  v = substr(body, RSTART, RLENGTH); sub(/^box-shadow[ \t\r\n]*:/, "", v); sub(/[ \t]*!important[ \t]*$/, "", v)
  RINGV = v
  return v ~ /[1-9]/ && v !~ /^[ \t\r\n]*none/
}
# The page background per theme: background(-color) on html, :root or body (body wins).
function bg_load(text,   depth, seg, k, c, pre, j, decl) {
  while (match(text, /\/\*/)) {
    k = index(substr(text, RSTART + 2), "*/")
    text = substr(text, 1, RSTART - 1) " " ((k == 0) ? "" : substr(text, RSTART + 2 + k + 1))
  }
  depth = 0
  while (match(text, /[{}]/)) {
    seg = substr(text, 1, RSTART - 1); c = substr(text, RSTART, 1); text = substr(text, RSTART + 1)
    if (c == "{") {
      j = 0; pre = seg
      while (match(pre, /;/)) { j += RSTART; pre = substr(pre, RSTART + 1) }
      decl = (j > 0) ? substr(seg, 1, j) : ""
      if (depth > 0 && decl != "") bg_decls(decl, depth)
      depth++; BCTX[depth] = trim(pre)
    } else {
      if (depth > 0) bg_decls(seg, depth)
      depth--; if (depth < 0) depth = 0
    }
  }
}
function bg_decls(decls, depth,   ctx, i, np, parts, b, pri, th, n, d, k, prop, v) {
  pri = 0; np = split(BCTX[depth], parts, ",")
  for (i = 1; i <= np; i++) {
    b = tolower(trim(parts[i]))
    if (b ~ /^:root/) b = "html"; else sub(/[.#:[].*$/, "", b)
    if (b == "body") pri = 2; else if (b == "html" && pri < 1) pri = 1
  }
  if (pri == 0) return
  ctx = ""; for (i = 1; i <= depth; i++) ctx = ctx " " BCTX[i]
  th = css_theme(ctx)
  n = split(decls, d, ";")
  for (i = 1; i <= n; i++) {
    k = index(d[i], ":"); if (k == 0) continue
    prop = tolower(trim(substr(d[i], 1, k - 1))); v = trim(substr(d[i], k + 1)); sub(/[ \t]*!important$/, "", v)
    if ((prop == "background-color" || prop == "background") && pri >= BGP[th]) { BGV[th] = v; BGP[th] = pri }
  }
}
# The first colour in S for THEME: the resolved value, or "?" and why it cannot be read.
function color_in(s, th,   v, low) {
  if (match(s, /var\([ \t]*--[A-Za-z0-9_-]+/)) {
    v = substr(s, RSTART, RLENGTH); sub(/^var\([ \t]*--/, "", v)
    v = resolve(th, v)
    return (RESERR != "") ? "?" RESERR : v
  }
  if (match(s, /#[0-9A-Fa-f]+/)) return substr(s, RSTART, RLENGTH)
  if (match(s, /rgba?\([^)]*\)/)) return substr(s, RSTART, RLENGTH)
  low = " " tolower(s) " "; gsub(/[ \t\r\n]+/, " ", low)
  if (index(low, " white ")) return "white"
  if (index(low, " black ")) return "black"
  if (index(low, "currentcolor")) return "?currentColor"
  if (low ~ /(gradient|url)\(/) return "?a gradient or image"
  if (low ~ / [a-z]+ / && low !~ /^( (inset|[-0-9.]+(px|em|rem)?|0))+ $/) return "?a named colour"
  return "?no colour, so currentColor"
}
function lin(c) { c = c / 255; return (c <= 0.04045) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
function lum() { return 0.2126 * lin(CR) + 0.7152 * lin(CG) + 0.0722 * lin(CB) }
# U11: "" when a ring layer has 3:1 against the page background in every theme,
# "F" and the finding when one theme has none, "N" and why when it cannot be read.
function ring_check(v, shown,   L, nl, i, k, depth, c, cur, nth, ths, t, th, raw, bg, assumed, br, bgg, bb, lb, best, bestc, col, unres, l1, rt, msg) {
  nl = 0; depth = 0; cur = ""
  for (i = 1; i <= length(v); i++) {
    c = substr(v, i, 1)
    if (c == "(") depth++; else if (c == ")") depth--
    if (c == "," && depth == 0) { L[++nl] = cur; cur = "" } else cur = cur c
  }
  L[++nl] = cur
  ths = "base"; if (NAMES["dark"] != "" || ("dark" in BGV)) ths = ths " dark"; if (NAMES["light"] != "" || ("light" in BGV)) ths = ths " light"
  nth = split(ths, t, " ")
  for (k = 1; k <= nth; k++) {
    th = t[k]; assumed = 0
    raw = (th in BGV) ? BGV[th] : (("base" in BGV) ? BGV["base"] : "")
    if (raw == "") { bg = "#ffffff"; assumed = 1 } else bg = color_in(raw, th)
    if (bg ~ /^\?/) return "Nthe page background is not a colour that can be read (" substr(bg, 2) ")"
    if (!parse_color(bg)) return "Nthe page background " bg " is not a colour that can be read"
    if (CA < 1) return "Nthe page background " bg " is translucent"
    br = CR; bgg = CG; bb = CB; lb = lum()
    best = 0; bestc = ""; unres = ""
    for (i = 1; i <= nl; i++) {
      if (tolower(L[i]) ~ /(^|[ \t])inset([ \t]|$)/) { if (unres == "") unres = "an inset ring sits on the element\047s own background"; continue }
      col = color_in(L[i], th)
      if (col ~ /^\?/) { unres = "the ring\047s colour is " substr(col, 2); continue }
      if (!parse_color(col)) { unres = "the ring\047s colour " col " is not supported"; continue }
      if (CA < 1) { CR = CA * CR + (1 - CA) * br; CG = CA * CG + (1 - CA) * bgg; CB = CA * CB + (1 - CA) * bb }
      l1 = lum(); rt = (l1 > lb) ? (l1 + 0.05) / (lb + 0.05) : (lb + 0.05) / (l1 + 0.05)
      if (rt > best) { best = rt; bestc = trim(col) }
    }
    if (bestc == "") return "N" unres
    if (best < 3) {
      msg = "outline on " shown " is replaced by a box-shadow ring (" bestc ") with " sprintf("%.2f", int(best * 100) / 100) ":1 against the page background (" (assumed ? "white: none is set" : trim(raw)) ")"
      return "F" msg ((th == "base") ? "" : " in the " th " theme") "; a focus indicator needs 3:1 (1.4.11, 2.4.7)"
    }
  }
  return ""
}
function css_scan(t, base,   full, off, p, sel, rs, rl, rc) {
  full = blank_css_comments(t); t = full; off = 0
  while (match(t, /outline[ \t]*:[ \t]*(none|0)([ \t;}!]|$)/)) {
    rs = RSTART; rl = RLENGTH
    p = off + rs; sel = selector_before(full, p)
    if (sel ~ /:focus/ && ring(full, p)) {
      CHK["U11"]++
      if (!covered(sel)) {
        rc = ring_check(RINGV, selnorm(sel))
        if (rc ~ /^F/) fail("U11", base + p, substr(rc, 2))
        else if (rc ~ /^N/) note("U11", base + p, "outline on " selnorm(sel) " is replaced by a box-shadow ring; its contrast is not computed: " substr(rc, 2) " (confirm in the browser pass)")
      }
    }
    else css_hit(base + p, sel)
    off += rs + rl - 1; t = substr(t, rs + rl)
  }
}
function lines_before(t, p,   s) { s = substr(t, 1, p - 1); return gsub(/\n/, "", s) + 1 }
# A delegated selector: one compound selector (tag, #id, .class, [attr], [attr=value]).
# Anything else (a combinator, a pseudo-class, a quoted value with a space) is skipped.
function add_dsel(f, s, line,   n, rest, t, k, name, op, v, rl) {
  s = trim(s); if (s == "" || s ~ /[ \t>+~:]/) return
  n = DNN + 1; DTAG[n] = ""; DID[n] = ""; DCLS[n] = ""; DATN[n] = 0
  rest = s
  if (match(rest, /^[A-Za-z][A-Za-z0-9-]*/)) { DTAG[n] = tolower(substr(rest, 1, RLENGTH)); rest = substr(rest, RLENGTH + 1) }
  while (rest != "") {
    if (match(rest, /^#[-A-Za-z0-9_]+/)) DID[n] = substr(rest, 2, RLENGTH - 1)
    else if (match(rest, /^\.[-A-Za-z0-9_]+/)) DCLS[n] = DCLS[n] " " tolower(substr(rest, 2, RLENGTH - 1))
    else if (match(rest, /^\[[A-Za-z_][-A-Za-z0-9_]*([~|^$*]?=("[^"]*"|\047[^\047]*\047|[-A-Za-z0-9_]*))?\]/)) {
      rl = RLENGTH; t = substr(rest, 2, rl - 2); k = DATN[n] + 1
      if (match(t, /[~|^$*]?=/)) { name = substr(t, 1, RSTART - 1); op = substr(t, RSTART, RLENGTH); v = substr(t, RSTART + RLENGTH) }
      else { name = t; op = ""; v = "" }
      if (v ~ /^["\047]/) v = substr(v, 2, length(v) - 2)
      DAN[n, k] = tolower(name); DAX[n, k] = (op == "="); DAV[n, k] = v; DATN[n] = k
      rest = substr(rest, rl + 1); continue
    }
    else return
    rest = substr(rest, RLENGTH + 1)
  }
  if (DTAG[n] == "" && DID[n] == "" && DCLS[n] == "" && DATN[n] == 0) return
  DNN = n; DSF[n] = f; DSS[n] = s; DSL[n] = line; DSK[n] = (f in DKEY)
}
function js_prepass(f, raw,   t, rest, off, s, line, np, parts, i) {
  if (f !~ /\.(m|c)?(js|ts)$/) return
  t = js_templates(raw)
  if (JSH1 == "" && match(tolower(t), /<h1[ \t\r\n>]/)) JSH1 = f ":" lines_before(t, RSTART)
  if (raw !~ /addEventListener\([ \t]*["\047]click["\047]/) return
  DCLICK[f] = 1
  if (raw ~ /addEventListener\([ \t]*["\047]key(down|up|press)["\047]/) DKEY[f] = 1
  rest = raw; off = 0
  while (match(rest, /target\.(closest|matches)\([ \t]*("[^"]+"|\047[^\047]+\047)[ \t]*\)/)) {
    s = substr(rest, RSTART, RLENGTH); sub(/^target\.[a-z]+\([ \t]*["\047]/, "", s); sub(/["\047][ \t]*\)$/, "", s)
    line = lines_before(raw, off + RSTART)
    off += RSTART + RLENGTH - 1; rest = substr(rest, RSTART + RLENGTH)
    np = split(s, parts, ",")
    for (i = 1; i <= np; i++) add_dsel(f, parts[i], line)
  }
}
function cmatch(n, tag, lname,   cl, nc, cs, i, v) {
  if (DTAG[n] != "" && DTAG[n] != lname) return 0
  if (DID[n] != "" && val(tag, "id") != DID[n]) return 0
  if (DCLS[n] != "") {
    cl = " " tolower(val(tag, "class|classname")) " "; gsub(/[ \t\r\n]+/, " ", cl)
    nc = split(DCLS[n], cs, " ")
    for (i = 1; i <= nc; i++) if (index(cl, " " cs[i] " ") == 0) return 0
  }
  for (i = 1; i <= DATN[n]; i++) {
    if (!has(tag, DAN[n, i])) return 0
    if (DAX[n, i]) { v = val(tag, DAN[n, i]); if (!dynamic(v) && v != DAV[n, i]) return 0 }
  }
  return 1
}
# The delegated selector an element matches, from any scanned file (a bare tag only
# from the file of the element), shown with its line; sets DHIT to its index.
function delegated(tag, lname,   n) {
  for (n = 1; n <= DNN; n++) {
    if (DSF[n] != FILE && DID[n] == "" && DCLS[n] == "" && DATN[n] == 0) continue
    if (cmatch(n, tag, lname)) { DHIT = n; return DSS[n] ((DSF[n] == FILE) ? " (line " DSL[n] ")" : " (" DSF[n] ":" DSL[n] ")") }
  }
  return ""
}
function js_templates(t,   out, i, j, k, rest, content) {
  out = ""
  while ((i = index(t, "`")) > 0) {
    out = out blank(substr(t, 1, i)); rest = substr(t, i + 1)
    j = 0
    while (1) { k = index(substr(rest, j + 1), "`"); if (k == 0) { j = 0; break } j += k; if (substr(rest, j - 1, 1) != "\\") break }
    if (j == 0) { out = out blank(rest); t = ""; break }
    content = substr(rest, 1, j - 1)
    out = out ((content ~ /<[A-Za-z]/) ? content : blank(content)) " "
    t = substr(rest, j + 1)
  }
  return out blank(t)
}
function line_at(pos,   seg, n) {
  if (pos < LASTPOS) { LASTPOS = 1; LASTLINE = 1 }
  seg = substr(B, LASTPOS, pos - LASTPOS); n = gsub(/\n/, "", seg)
  LASTLINE += n; LASTPOS = pos; return LASTLINE
}
function has(tag, re) { return match(tolower(tag), "[ \t\r\n]((v-bind|v-on)?[:@]|on:)?(" re ")(\\.[a-z0-9-]+)*([ \t\r\n]*=|[ \t\r\n]*/?>|[ \t\r\n])") > 0 }
function val(tag, re,   t, v) {
  t = tag
  if (!match(tolower(t), "[ \t\r\n]((v-bind)?:)?(" re ")[ \t\r\n]*=[ \t\r\n]*(\"[^\"]*\"|\047[^\047]*\047|\\{[^}]*\\}|[^ \t\r\n>]+)")) return ""
  v = substr(t, RSTART, RLENGTH); sub(/^[^=]*=[ \t\r\n]*/, "", v)
  if (v ~ /^["\047]/) v = substr(v, 2, length(v) - 2)
  return v
}
function dynamic(v) { return v ~ /[{]/ || v ~ /^\$/ }
function fail(k, pos, msg, sev) {
  NF_[k]++; NFAIL++
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s:%d  %s%s\n", "UX-" k, (sev == "") ? SEV[k] : sev, FILE, line_at(pos), msg, ISJS ? " [js template]" : "")
}
function note(k, pos, msg) { NOTES[k] = NOTES[k] sprintf("NOTE  %-7s %-6s %s:%d  %s\n", "UX-" k, "-", FILE, line_at(pos), msg) }
function named_content(c) {
  if (c ~ /[{]/ || tolower(c) ~ /<slot/) return 1
  if (match(tolower(c), /alt[ \t]*=[ \t]*["\047][^"\047]+["\047]/) || tolower(c) ~ /aria-label(ledby)?[ \t]*=/ || tolower(c) ~ /<title[ >]/) return 1
  gsub(/<[^>]*>/, "", c); gsub(/&nbsp;|&#160;|&#xa0;/, "", c); gsub(/[ \t\r\n]/, "", c)
  return c != ""
}
function process(   k, rest, off, tag, name, lname, pos, isclose, n, i, ty, lv, prev, v, c, j, endp, fulldoc, hash, hasH1, sel, d) {
  if (FILE == "") return
  LASTPOS = 1; LASTLINE = 1; NST = 0
  if (FILE ~ /\.(css|scss)$/) { css_scan(B, 0); return }
  if (ISJS) B = js_templates(B)
  ORIGB = B
  blank_between("<!--", "-->", 0)
  blank_between("{/*", "*/}", 0)
  blank_between("<script", "</script>", 0)
  blank_between("<style", "</style>", 1)
  n = 0; rest = B; off = 0
  while (match(rest, /<\/?[A-Za-z][A-Za-z0-9:._-]*[^>]*>/)) {
    n++; TT[n] = substr(rest, RSTART, RLENGTH); TP[n] = off + RSTART; TE[n] = off + RSTART + RLENGTH
    off += RSTART + RLENGTH - 1; rest = substr(rest, RSTART + RLENGTH)
  }
  LB = tolower(B); fulldoc = (LB ~ /<html[ \t\r\n>]/ || LB ~ /<body[ \t\r\n>]/); hasH1 = 0; prev = 0
  delete LABELFOR; delete IDS
  for (i = 1; i <= n; i++) {
    tag = TT[i]; if (substr(tag, 2, 1) == "/") continue
    name = tag; sub(/^</, "", name); sub(/[ \t\r\n\/>].*$/, "", name)
    if (name == "label") { v = val(tag, "for|htmlfor"); if (v != "") LABELFOR[v] = 1 }
  }
  ldepth = 0
  for (i = 1; i <= n; i++) {
    tag = TT[i]; pos = TP[i]
    isclose = (substr(tag, 2, 1) == "/")
    name = tag; sub(/^<\/?/, "", name); sub(/[ \t\r\n\/>].*$/, "", name)
    if (COMPONENTS && name ~ /^[A-Z]/) continue
    lname = tolower(name)
    if (lname == "label") { ldepth += isclose ? -1 : 1; if (ldepth < 0) ldepth = 0; if (!isclose && tag ~ /\/>$/) ldepth--; continue }
    if (isclose) continue
    if (has(tag, "style") && tolower(val(tag, "style")) ~ /outline[ \t]*:[ \t]*(none|0)([ \t;]|$)/) css_hit(pos, "")
    v = tolower(val(tag, "class|classname"))
    if (v ~ /(^|[ \t])outline-none([ \t]|$)/) { CHK["U11"]++; if (v !~ /focus-visible:|focus:ring|focus:outline/) fail("U11", pos, "class outline-none with no focus-visible: or focus:ring class on the element (2.4.7, 2.4.11)") }
    if (lname == "html") { CHK["U1"]++; if (!has(tag, "lang")) fail("U1", pos, "<html> has no lang attribute (3.1.1)") }
    if (lname == "img") {
      CHK["U2"]++
      if (!has(tag, "alt") && tolower(val(tag, "role")) !~ /^(presentation|none)$/ && tolower(val(tag, "aria-hidden")) != "true") fail("U2", pos, "<img> has no alt; use alt=\"\" when the image is decorative (1.1.1)")
    }
    if (lname == "input" || lname == "select" || lname == "textarea") {
      ty = tolower(val(tag, "type"))
      if (!(lname == "input" && ty ~ /^(hidden|submit|reset|button|image)$/)) {
        CHK["U3"]++; v = val(tag, "id")
        if (!(ldepth > 0 || has(tag, "aria-label|aria-labelledby|title") || (v != "" && (v in LABELFOR)) || dynamic(v)))
          fail("U3", pos, "<" lname "> has no label, aria-label or aria-labelledby" (has(tag, "placeholder") ? "; a placeholder is not a label" : "") " (1.3.1, 4.1.2)", ISCORE ? "High" : "")
      }
    }
    if (lname == "button" || lname == "a") {
      CHK["U4"]++
      v = val(tag, "aria-label|aria-labelledby|title")
      if (v == "") {
        if (tag ~ /\/>$/) c = ""
        else { j = index(substr(LB, TE[i]), "</" lname); c = (j == 0) ? "" : substr(B, TE[i], j - 1) }
        if (!named_content(c)) fail("U4", pos, "<" lname "> has no accessible name: no text, aria-label or labelled image (4.1.2, 2.4.4)")
      }
    }
    if (lname == "meta" && tolower(val(tag, "name")) == "viewport") {
      CHK["U5"]++; v = tolower(val(tag, "content")); gsub(/ /, "", v)
      if (v ~ /user-scalable=(no|0)/ || v ~ /maximum-scale=(0|1)(\.[0-9]+)?([,;]|$)/) fail("U5", pos, "viewport blocks zoom (" v ") (1.4.4)")
    }
    if (has(tag, "tabindex")) { CHK["U6"]++; v = val(tag, "tabindex"); gsub(/[{} ]/, "", v); if (v ~ /^[1-9][0-9]*$/) fail("U6", pos, "positive tabindex=\"" v "\" changes the focus order (2.4.3)") }
    if (lname ~ /^h[1-6]$/) {
      CHK["U7"]++; lv = substr(lname, 2) + 0; if (lv == 1) hasH1 = 1
      if (!ISJS && prev > 0 && lv > prev + 1) fail("U7", pos, "heading level skips from h" prev " to h" lv " (1.3.1, 2.4.6)")
      prev = lv
    }
    v = val(tag, "id")
    if (v != "" && !dynamic(v) && !ISJS) { CHK["U8"]++; if (v in IDS) fail("U8", pos, "duplicate id \"" v "\" (first on line " IDS[v] ") (4.1.2)"); else IDS[v] = line_at(pos) }
    if ((lname == "video" || lname == "audio") && has(tag, "autoplay")) {
      CHK["U10"]++; c = ""
      if (!has(tag, "muted")) c = "muted"
      if (!has(tag, "controls")) c = c (c == "" ? "" : " and ") "controls"
      if (c != "") fail("U10", pos, "<" lname " autoplay> has no " c " (1.4.2, 2.2.2)")
    }
    if (lname ~ /^(div|span|li|td|p|section|article|img|svg)$/ && has(tag, "onclick|click")) {
      CHK["U12"]++; c = ""
      if (!has(tag, "role")) c = "role"
      if (!has(tag, "tabindex")) c = c (c == "" ? "" : ", ") "tabindex"
      if (!has(tag, "onkeydown|onkeyup|onkeypress|keydown|keyup|keypress")) c = c (c == "" ? "" : ", ") "a key handler"
      if (c != "") fail("U12", pos, "<" lname "> has a click handler but no " c "; use a <button> (2.1.1)", ISCORE ? "High" : "")
    }
    else if (lname ~ /^(div|span|li|td|p|section|article|img|svg)$/ && (d = delegated(tag, lname)) != "") {
      CHK["U12"]++; c = ""
      if (!has(tag, "role")) c = "role"
      if (!has(tag, "tabindex")) c = c (c == "" ? "" : ", ") "tabindex"
      if (!DSK[DHIT] && !has(tag, "onkeydown|onkeyup|onkeypress|keydown|keyup|keypress")) c = c (c == "" ? "" : ", ") "a key listener"
      if (c != "") fail("U12", pos, "<" lname "> matches the delegated click selector " d " but has no " c "; use a <button> (2.1.1) [delegated]", ISCORE ? "High" : "")
    }
  }
  if (fulldoc) {
    CHK["U9"]++
    j = index(LB, "<title")
    if (j == 0) fail("U9", 1, "the page has no <title> (2.4.2)")
    else { c = substr(B, j); sub(/^<[^>]*>/, "", c); i = index(tolower(c), "</title>"); c = (i == 0) ? "" : substr(c, 1, i - 1); gsub(/[ \t\r\n]/, "", c); if (c == "") fail("U9", j, "the page has an empty <title> (2.4.2)") }
    CHK["U7"]++
    if (!hasH1 && JSH1 != "") note("U7", 1, "no static <h1>; a js template renders one at " JSH1 " (confirm in the browser pass)")
    else if (!hasH1) fail("U7", 1, "the page has no <h1> (1.3.1, 2.4.6)")
  }
  for (k = 1; k <= NST; k++) css_scan(substr(ORIGB, SST[k], SEN[k] - SST[k]), SST[k] - 1)
}
function css_hit(pos, sel,   shown) {
  CHK["U11"]++
  if (covered(sel)) return
  shown = selnorm(sel); if (shown == "") shown = "an inline style"
  fail("U11", pos, "focus outline removed on " shown " and no :focus-visible style covers it (2.4.7, 2.4.11)")
}
BEGIN {
  split("U1 U2 U3 U4 U5 U6 U7 U8 U9 U10 U11 U12", ORDER, " ")
  split("Medium Medium Medium Medium Medium Low Low Low Medium Medium Medium Medium", sv, " ")
  for (i = 1; i <= 12; i++) SEV[ORDER[i]] = sv[i]
  D["U1"] = "<html> declares lang"; D["U2"] = "images have alt"; D["U3"] = "form controls have labels"
  D["U4"] = "buttons and links have accessible names"; D["U5"] = "the viewport allows zoom"; D["U6"] = "no positive tabindex"
  D["U7"] = "heading levels do not skip; pages have an <h1>"; D["U8"] = "ids are unique within each file"; D["U9"] = "pages have a title"
  D["U10"] = "autoplay media is muted and has controls"; D["U11"] = "removed focus outlines are replaced by :focus-visible"
  D["U12"] = "click handlers sit on keyboard-reachable elements"
  for (i = 1; i < ARGC; i++) {
    T0 = ""; while ((getline line < ARGV[i]) > 0) T0 = T0 line "\n"; close(ARGV[i])
    fv_prepass(T0); js_prepass(ARGV[i], T0)
    if (ARGV[i] ~ /\.(css|scss)$/) { css_load(T0); bg_load(T0) }
    else if (ARGV[i] !~ /\.(m|c)?(js|ts)$/) {
      # the <style> blocks of a markup file
      rest = T0
      while ((p = index(tolower(rest), "<style")) > 0) {
        rest = substr(rest, p); q = index(rest, ">"); if (q == 0) break
        rest = substr(rest, q + 1); e = index(tolower(rest), "</style>"); if (e == 0) break
        css_load(substr(rest, 1, e - 1)); bg_load(substr(rest, 1, e - 1)); rest = substr(rest, e + 8)
      }
    }
  }
  nc = split(ENVIRON["ASCENT_CORE"], cl, "\n"); for (i = 1; i <= nc; i++) if (cl[i] != "") COREF[(cl[i] ~ /^\//) ? cl[i] : "./" cl[i]] = 1
  FILE = ""; NFILES = 0
}
FNR == 1 { process(); FILE = FILENAME; B = ""; NFILES++; ISCORE = (FILE in COREF); COMPONENTS = (FILE ~ /\.(jsx|tsx|vue|svelte|astro)$/); ISJS = (FILE ~ /\.(m|c)?(js|ts)$/) }
{ B = B $0 "\n" }
END {
  process()
  for (i = 1; i <= 12; i++) {
    k = ORDER[i]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "UX-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (nothing to check)\n", "UX-" k, D[k]
    printf "%s", NOTES[k]
  }
  printf "check-web-accessibility: %d file(s), %d failure(s) (static checks; confirm in the browser pass)\n", NFILES, NFAIL
  exit (NFAIL > 0) ? 1 : 0
}'
# awk reads "a=b.html" as an assignment, so every path is passed as ./path.
ARGS=()
while IFS= read -r f; do case "$f" in /*) ARGS+=("$f") ;; ./*) ARGS+=("$f") ;; *) ARGS+=("./$f") ;; esac; done <<EOF_FILES
$FILES
EOF_FILES
CORE_N=""
for c in $(printf '%s' "$CORE"); do case "$c" in /*|./*) CORE_N="$CORE_N${c#./}
" ;; *) CORE_N="$CORE_N$c
" ;; esac; done
ASCENT_CORE="$CORE_N" LC_ALL=C awk "$PROG" "${ARGS[@]}"
