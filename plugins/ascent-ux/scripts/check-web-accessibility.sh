#!/usr/bin/env bash
# Static accessibility checks for web markup: HTML and the common template
# syntaxes (JSX/TSX, Vue, Svelte, Astro, Eta, EJS, Handlebars, Nunjucks). Part of
# the ascent-ux plugin (ux-review Step 3, accessibility-audit Step 2). Read-only.
#
# Usage: check-web-accessibility.sh [--core FILE]... PATH...
#
# PATH is a file or a directory (searched for markup and CSS, skipping
# node_modules, dist, build, .git, vendor and *.min.*). --core marks a file as part
# of a core user flow: U3 and U12 failures there are High instead of Medium.
#
# Checks (severity from the ux-review severity table; WCAG 2.2 criterion):
#   U1  Medium  <html> declares lang                                  3.1.1
#   U2  Medium  every <img> has alt (alt="" when decorative)          1.1.1
#   U3  Medium  form controls have a label, aria-label or aria-labelledby   1.3.1, 4.1.2
#   U4  Medium  buttons and links have an accessible name             4.1.2, 2.4.4
#   U5  Medium  the viewport meta tag allows zoom                     1.4.4
#   U6  Low     no positive tabindex                                  2.4.3
#   U7  Low     heading levels do not skip; a full page has an <h1>   1.3.1, 2.4.6
#   U8  Low     id values are unique within a file                    4.1.2
#   U9  Medium  a full page has a non-empty <title>                   2.4.2
#   U10 Medium  autoplay media is muted and has controls              1.4.2, 2.2.2
#   U11 Medium  focus outlines are not removed unless a :focus-visible style exists   2.4.7, 2.4.11
#   U12 Medium  click handlers sit on elements a keyboard can reach (role, tabindex, key handler)   2.1.1
#
# Output: one FAIL line per finding (FAIL  Uk  SEVERITY  file:line  message), a
# PASS line per check with no finding (with the count checked), N/A when a check
# found nothing to check, then "check-web-accessibility: ...".
# Limits: static. Markup is read as text: a ">" inside a template expression ends a
# tag early, names built at runtime cannot be seen (a dynamic name counts as
# present), and capitalized JSX/Vue/Svelte components are skipped. Every finding is
# "static" until the browser pass (live accessibility tree) confirms it.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //' >&2; exit 2; }
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
      -type f -print 2>/dev/null | grep -Ei "\\.($MARKUP|css|scss)\$" | grep -v '\.min\.' | LC_ALL=C sort || true)
"
  elif [ -f "$p" ]; then
    printf '%s\n' "$p" | grep -Eiq "\\.($MARKUP|css|scss)\$" || { echo "check-web-accessibility: not a markup or CSS file: $p" >&2; exit 2; }
    FILES="$FILES$p
"
  else
    echo "check-web-accessibility: no such file or directory: $p" >&2; exit 2
  fi
done
FILES=$(printf '%s' "$FILES" | grep -v '^$' || true)
[ -n "$FILES" ] || { echo "check-web-accessibility: no markup or CSS files under: ${PATHS[*]}" >&2; exit 2; }
for c in $(printf '%s' "$CORE"); do printf '%s\n' "$FILES" | grep -qxF "$c" || { echo "check-web-accessibility: --core $c is not among the scanned files" >&2; exit 2; }; done

# U11: a :focus-visible style anywhere (CSS, <style>, Tailwind variants) is the replacement.
FV=0
# shellcheck disable=SC2086
if printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 grep -lE ':focus-visible|focus-visible:|focus:ring|focus:outline' >/dev/null 2>&1; then FV=1; fi

PROG='
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
function css_scan(t, base,   off) {
  t = blank_css_comments(t); off = 0
  while (match(t, /outline[ \t]*:[ \t]*(none|0)([ \t;}!]|$)/)) {
    css_hit(base + off + RSTART)
    off += RSTART + RLENGTH - 1; t = substr(t, RSTART + RLENGTH)
  }
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
  OUT[k] = OUT[k] sprintf("FAIL  %-4s %-6s %s:%d  %s\n", k, (sev == "") ? SEV[k] : sev, FILE, line_at(pos), msg)
}
function named_content(c) {
  if (c ~ /[{]/ || tolower(c) ~ /<slot/) return 1
  if (match(tolower(c), /alt[ \t]*=[ \t]*["\047][^"\047]+["\047]/) || tolower(c) ~ /aria-label(ledby)?[ \t]*=/ || tolower(c) ~ /<title[ >]/) return 1
  gsub(/<[^>]*>/, "", c); gsub(/&nbsp;|&#160;|&#xa0;/, "", c); gsub(/[ \t\r\n]/, "", c)
  return c != ""
}
function process(   k, rest, off, tag, name, lname, pos, isclose, n, i, ty, lv, prev, v, c, j, endp, fulldoc, hash, hasH1, sel) {
  if (FILE == "") return
  LASTPOS = 1; LASTLINE = 1; NST = 0
  if (FILE ~ /\.(css|scss)$/) { css_scan(B, 0); return }
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
    if (has(tag, "style") && tolower(val(tag, "style")) ~ /outline[ \t]*:[ \t]*(none|0)([ \t;]|$)/) css_hit(pos)
    if (tolower(val(tag, "class|classname")) ~ /(^|[ \t])outline-none([ \t]|$)/) css_hit(pos)
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
      if (prev > 0 && lv > prev + 1) fail("U7", pos, "heading level skips from h" prev " to h" lv " (1.3.1, 2.4.6)")
      prev = lv
    }
    v = val(tag, "id")
    if (v != "" && !dynamic(v)) { CHK["U8"]++; if (v in IDS) fail("U8", pos, "duplicate id \"" v "\" (first on line " IDS[v] ") (4.1.2)"); else IDS[v] = line_at(pos) }
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
  }
  if (fulldoc) {
    CHK["U9"]++
    j = index(LB, "<title")
    if (j == 0) fail("U9", 1, "the page has no <title> (2.4.2)")
    else { c = substr(B, j); sub(/^<[^>]*>/, "", c); i = index(tolower(c), "</title>"); c = (i == 0) ? "" : substr(c, 1, i - 1); gsub(/[ \t\r\n]/, "", c); if (c == "") fail("U9", j, "the page has an empty <title> (2.4.2)") }
    CHK["U7"]++
    if (!hasH1) fail("U7", 1, "the page has no <h1> (1.3.1, 2.4.6)")
  }
  for (k = 1; k <= NST; k++) css_scan(substr(ORIGB, SST[k], SEN[k] - SST[k]), SST[k] - 1)
}
function css_hit(pos) { CHK["U11"]++; if (!FV) fail("U11", pos, "focus outline removed and no :focus-visible style exists in the scanned files (2.4.7, 2.4.11)") }
BEGIN {
  split("U1 U2 U3 U4 U5 U6 U7 U8 U9 U10 U11 U12", ORDER, " ")
  split("Medium Medium Medium Medium Medium Low Low Low Medium Medium Medium Medium", sv, " ")
  for (i = 1; i <= 12; i++) SEV[ORDER[i]] = sv[i]
  D["U1"] = "<html> declares lang"; D["U2"] = "images have alt"; D["U3"] = "form controls have labels"
  D["U4"] = "buttons and links have accessible names"; D["U5"] = "the viewport allows zoom"; D["U6"] = "no positive tabindex"
  D["U7"] = "heading levels do not skip; pages have an <h1>"; D["U8"] = "ids are unique within each file"; D["U9"] = "pages have a title"
  D["U10"] = "autoplay media is muted and has controls"; D["U11"] = "focus outlines are not removed without :focus-visible"
  D["U12"] = "click handlers sit on keyboard-reachable elements"
  FV = ENVIRON["ASCENT_FV"] + 0; nc = split(ENVIRON["ASCENT_CORE"], cl, "\n"); for (i = 1; i <= nc; i++) if (cl[i] != "") COREF[(cl[i] ~ /^\//) ? cl[i] : "./" cl[i]] = 1
  FILE = ""; NFILES = 0
}
FNR == 1 { process(); FILE = FILENAME; B = ""; NFILES++; ISCORE = (FILE in COREF); COMPONENTS = (FILE ~ /\.(jsx|tsx|vue|svelte|astro)$/) }
{ B = B $0 "\n" }
END {
  process()
  for (i = 1; i <= 12; i++) {
    k = ORDER[i]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-4s %s (%d checked)\n", k, D[k], CHK[k]
    else printf "N/A   %-4s %s (nothing to check)\n", k, D[k]
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
ASCENT_FV="$FV" ASCENT_CORE="$CORE_N" awk "$PROG" "${ARGS[@]}"
