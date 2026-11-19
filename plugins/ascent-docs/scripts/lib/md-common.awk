# md-common.awk — Markdown helpers shared by check-docs.awk, check-doc-drift.awk and
# doc-marks.awk: code fences, inline code, links, GitHub heading slugs and path
# resolution. Load it before the program: awk -f md-common.awk -f <program>.
# Portable: POSIX awk (BWK, mawk, gawk), run with LC_ALL=C.

# md_isheading(s) — 1 for an ATX heading: up to three spaces, one to six #, a blank
function md_isheading(s) { return s ~ /^ ? ? ?#+[ \t]/ && s !~ /^ ? ? ?#######/ }
# md_line() — call on every line: returns 1 when the line is prose (not a fence and
# not inside one, and not an indented code block). MD_FENCE is 1 inside a fence;
# MD_LANG is the fence's info string. An indented code block is four spaces or a tab
# after a blank line, outside a list (MD_LIST), and continues while lines stay
# indented or blank.
function md_line(   t, blank) {
  if (FNR == 1) { MD_FENCE = 0; MD_MARK = ""; MD_LANG = ""; MD_PBLANK = 1; MD_ICODE = 0; MD_LIST = 0 }
  sub(/\r$/, "")
  t = $0; sub(/^[ \t]+/, "", t); blank = (t == "")
  if (!MD_FENCE) {
    if ($0 ~ /^(    |\t)/ && !blank && (MD_ICODE || (MD_PBLANK && !MD_LIST))) { MD_ICODE = 1; MD_PBLANK = 0; return 0 }
    if (!blank) {
      MD_ICODE = 0
      if (t ~ /^([-*+]|[0-9]+[.)])[ \t]/) MD_LIST = 1
      else if ($0 !~ /^[ \t]/) MD_LIST = 0
    }
    MD_PBLANK = blank
  }
  if (!MD_FENCE && (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~")) {
    MD_FENCE = 1; MD_MARK = substr(t, 1, 3); MD_LANG = tolower(substr(t, 4)); sub(/^[ \t]+/, "", MD_LANG); sub(/[ \t].*$/, "", MD_LANG); return 0
  }
  if (MD_FENCE) { if (substr(t, 1, 3) == MD_MARK) { MD_FENCE = 0; MD_LANG = "" } return 0 }
  return 1
}
# md_nocode(s) — s with inline code spans removed
function md_nocode(s) { gsub(/`[^`]*`/, "", s); return s }
# md_trim(s)
function md_trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
# md_dir(p) — the directory of a repository path, "" at the root
function md_dir(p) { if (p ~ /\//) { sub(/\/[^\/]*$/, "", p); return p } return "" }
# md_norm(p) — collapses ., .. and duplicate slashes; a path that climbs above the
# root comes back starting with "../"
function md_norm(p,   n, a, i, out, k, o) {
  n = split(p, a, "/"); k = 0
  for (i = 1; i <= n; i++) {
    if (a[i] == "" || a[i] == ".") continue
    if (a[i] == "..") { if (k > 0 && o[k] != "..") k--; else o[++k] = ".."; continue }
    o[++k] = a[i]
  }
  out = ""; for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") o[i]
  return out
}
# md_resolve(doc, target) — a link target as a repository path ("" for the root)
function md_resolve(doc, t,   d) {
  if (substr(t, 1, 1) == "/") return md_norm(substr(t, 2))
  d = md_dir(doc)
  return md_norm((d == "" ? "" : d "/") t)
}
# md_external(t) — 1 for a URL, a mail link or a template placeholder
function md_external(t) {
  return (t ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || substr(t, 1, 2) == "//" || index(t, "{{") || index(t, "<<") || index(t, "$"))
}
# md_unescape(t) — %20 and the other common escapes in a link target
function md_unescape(t) {
  gsub(/%20/, " ", t); gsub(/%28/, "(", t); gsub(/%29/, ")", t); gsub(/%23/, "#", t)
  return t
}
# md_links(s) — fills MD_L[1..n] with the link targets of prose line s (inline links,
# images and reference definitions; inline code removed first); returns n
function md_links(s,   n, r, t, i) {
  s = md_nocode(s); n = 0
  if (s ~ /^ ? ? ?\[[^]]+\]:[ \t]*[^ \t]/) {
    t = s; sub(/^ ? ? ?\[[^]]+\]:[ \t]*/, "", t); sub(/[ \t].*$/, "", t); sub(/^</, "", t); sub(/>$/, "", t)
    MD_L[++n] = t; return n
  }
  while (match(s, /\]\([^)]*\)/)) {
    t = substr(s, RSTART + 2, RLENGTH - 3); s = substr(s, RSTART + RLENGTH)
    t = md_trim(t)
    if (substr(t, 1, 1) == "<") { i = index(t, ">"); t = (i ? substr(t, 2, i - 2) : substr(t, 2)) }
    else sub(/[ \t].*$/, "", t)
    if (t != "") MD_L[++n] = t
  }
  return n
}
# md_slug(h) — the GitHub anchor of a heading's text; MD_LOOSE is set to 1 when the
# text keeps characters this awk cannot slug the way GitHub does (non-ASCII letters)
function md_slug(h) {
  MD_LOOSE = 0
  if (match(h, /\{#[^}]+\}[ \t]*$/)) return substr(h, RSTART + 2, RLENGTH - 3)
  sub(/[ \t]+#+[ \t]*$/, "", h)
  while (match(h, /\[[^]]*\]\([^)]*\)/)) h = substr(h, 1, RSTART - 1) substr(h, RSTART + 1, index(substr(h, RSTART), "]") - 2) substr(h, RSTART + RLENGTH)
  gsub(/<[^>]*>/, "", h)
  h = tolower(h)
  gsub(/\342\200\224|\342\200\223|\342\200\231|\342\200\230|\342\200\234|\342\200\235|\342\200\246|\342\206\222|\302\267|\302\247/, "", h)
  if (h ~ /[^ -~\t]/) MD_LOOSE = 1
  gsub(/[^a-z0-9 _\t-]/, "", h); gsub(/[ \t]/, "-", h)
  return h
}
# md_heading() — on a prose heading line, records its slug for FILENAME's document
# MD_DOC: MD_ANCH[doc SUBSEP slug]; MD_LOOSEDOC[doc] when a slug may be inexact
function md_heading(doc,   h, s, k) {
  if (md_isheading($0)) {
    h = $0; sub(/^ ? ? ?#+[ \t]+/, "", h); s = md_slug(h)
    if (MD_LOOSE) MD_LOOSEDOC[doc] = 1
    if ((doc SUBSEP s) in MD_ANCH) { k = ++MD_DUP[doc SUBSEP s]; s = s "-" k }
    MD_ANCH[doc SUBSEP s] = 1
  }
  while (match($0, /(id|name)="[^"]+"/)) { s = substr($0, RSTART, RLENGTH); sub(/^[a-z]+="/, "", s); sub(/"$/, "", s); MD_ANCH[doc SUBSEP s] = 1; $0 = substr($0, RSTART + RLENGTH) }
}
# md_days(d) — days since a fixed epoch, for YYYY-MM-DD
function md_days(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
}
