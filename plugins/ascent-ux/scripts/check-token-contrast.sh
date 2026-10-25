#!/usr/bin/env bash
# WCAG 2.2 contrast check for design-token color pairs, per theme. Part of the
# ascent-ux plugin (design-system-check Step 3, design-directions Step 4). Read-only.
#
# Usage: check-token-contrast.sh [--pairs PAIRS.tsv] TOKENS...
#
# TOKENS are Design Tokens JSON files (format 2025.10; the theme comes from the file
# name, NAME.THEME.tokens.json, else "default") or CSS files with custom properties
# (themes "light" and "dark", see scripts/lib/tokens.awk). Token names are the CSS
# custom property names without "--" (JSON paths joined with "-").
#
# PAIRS.tsv rows: foreground<TAB>background<TAB>kind, where kind is
#   text        4.5:1  (WCAG 1.4.3 Contrast (Minimum), normal text)
#   large-text  3:1    (1.4.3, text at least 24px, or 18.66px bold)
#   ui          3:1    (1.4.11 Non-text Contrast: borders, icons, focus indicators)
# Without --pairs the pairs are inferred and every line says "inferred": CSS rules that
# set both color and background from var(--x); then, by name, every color-text-* on
# every color-surface-*, and any *-on-X token on color-X, color-X-base and color-X-strong.
#
# Output, one line per pair and theme:
#   PASS|FAIL  THEME  FG on BG  RATIO:1  KIND (needs N)
#   SKIP       THEME  FG on BG  reason (translucent or unsupported color)
# then "check-token-contrast: ...". A pair-file token that is missing is a FAIL; an
# inferred pair whose token is not defined in the scanned files is a SKIP.
# The ratio uses WCAG relative luminance (sRGB, 0.04045 threshold) and is truncated,
# never rounded up, to two decimals.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //' >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/lib/tokens.awk"
[ -f "$LIB" ] || { echo "check-token-contrast: missing $LIB" >&2; exit 2; }
PAIRS=""
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --pairs) [ $# -ge 2 ] || usage; PAIRS="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "check-token-contrast: unknown option $1" >&2; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done
[ ${#FILES[@]} -gt 0 ] || usage
for f in "${FILES[@]}" ${PAIRS:+"$PAIRS"}; do [ -f "$f" ] || { echo "check-token-contrast: no such file: $f" >&2; exit 2; }; done

# One record per input: KIND<TAB>THEME<TAB>path. The awk program reads the files itself.
LIST=""
for f in "${FILES[@]}"; do
  case "$f" in
    *.json) th=$(basename "$f" | sed -n 's/^.*\.\([A-Za-z0-9_-][A-Za-z0-9_-]*\)\.tokens\.json$/\1/p'); LIST="$LIST$(printf 'json\t%s\t%s' "${th:-default}" "$f")
" ;;
    *.css|*.scss) LIST="$LIST$(printf 'css\t-\t%s' "$f")
" ;;
    *) echo "check-token-contrast: unsupported file type: $f (use .json or .css)" >&2; exit 2 ;;
  esac
done

PROG="$(cat "$LIB")"'
function slurp(path,   line, s) { s = ""; while ((getline line < path) > 0) s = s line "\n"; close(path); return s }
function lin(c) { c = c / 255; return (c <= 0.04045) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
function lum() { return 0.2126 * lin(CR) + 0.7152 * lin(CG) + 0.0722 * lin(CB) }
function need(kind) { if (kind == "text") return 4.5; if (kind == "large-text" || kind == "ui") return 3; return 0 }
BEGIN {
  LIST = ENVIRON["ASCENT_TOKEN_LIST"]; PAIRS = ENVIRON["ASCENT_TOKEN_PAIRS"]
  n = split(LIST, rec, "\n")
  for (i = 1; i <= n; i++) {
    if (rec[i] == "") continue
    split(rec[i], f, "\t")
    TOKERR = ""
    if (f[1] == "json") { ok = json_load(slurp(f[3]), f[2]); THEMES[f[2]] = 1 }
    else { ok = css_load(slurp(f[3])); HASCSS = 1 }
    if (!ok || TOKERR != "") { printf "check-token-contrast: cannot read %s: %s\n", f[3], TOKERR > "/dev/stderr"; exit 2 }
  }
  if (HASCSS) { THEMES["light"] = 1; if (NAMES["dark"] != "") THEMES["dark"] = 1 }
  np = 0
  if (PAIRS != "") {
    while ((getline line < PAIRS) > 0) {
      sub(/\r$/, "", line)
      if (line ~ /^[ \t]*(#|$)/) continue
      m = split(line, c, "\t")
      if (m < 3 || need(c[3]) == 0) { printf "check-token-contrast: bad pairs line: %s (want fg<TAB>bg<TAB>text|large-text|ui)\n", line > "/dev/stderr"; exit 2 }
      np++; PF[np] = c[1]; PB[np] = c[2]; PK[np] = c[3]
    }
    SRC = "pairs file"
  } else {
    SRC = "inferred"
    for (i = 1; i <= NRULEPAIR; i++) { split(RULEPAIR[i], c, " "); np++; PF[np] = c[1]; PB[np] = c[2]; PK[np] = "text" }
    for (th in THEMES) { m = split(NAMES[th], nm, " "); for (i = 1; i <= m; i++) ALL[nm[i]] = 1 }
    for (a in ALL) {
      if (match(a, /-on-[A-Za-z0-9_-]+$/)) {
        x = substr(a, RSTART + 4)
        for (q = 1; q <= 3; q++) { b = "color-" x ((q == 2) ? "-base" : (q == 3) ? "-strong" : "")
          if ((b in ALL) && !((a, b) in SEEN)) { SEEN[a, b] = 1; np++; PF[np] = a; PB[np] = b; PK[np] = "text" } }
      } else if (a ~ /^color-text-/) for (b in ALL) if (b ~ /^color-surface-/ && !((a, b) in SEEN)) { SEEN[a, b] = 1; np++; PF[np] = a; PB[np] = b; PK[np] = "text" }
    }
  }
  if (np == 0) { print "check-token-contrast: no pairs to check (give --pairs, or name tokens color-text-* and color-surface-*)" > "/dev/stderr"; exit 2 }
  tag = (SRC == "inferred") ? "  inferred" : ""
  nt = 0; for (th in THEMES) TL[++nt] = th
  for (i = 1; i <= nt; i++) for (j = i + 1; j <= nt; j++) if (TL[j] < TL[i]) { t = TL[i]; TL[i] = TL[j]; TL[j] = t }
  pass = 0; fail = 0; skip = 0
  for (i = 1; i <= nt; i++) {
    th = TL[i]
    for (p = 1; p <= np; p++) {
      label = sprintf("%-6s %s on %s", th, PF[p], PB[p])
      fv = resolve(th, PF[p]); if (RESERR == "") bv = resolve(th, PB[p])
      if (RESERR != "") {
        if (SRC == "inferred") { printf "SKIP  %s  not defined in the scanned files: %s%s\n", label, RESERR, tag; skip++ }
        else { printf "FAIL  %s  missing: %s%s\n", label, RESERR, tag; fail++ }
        continue
      }
      if (!parse_color(fv)) { printf "SKIP  %s  unsupported color %s%s\n", label, fv, tag; skip++; continue }
      if (CA < 1) { printf "SKIP  %s  translucent foreground %s%s\n", label, fv, tag; skip++; continue }
      l1 = lum()
      if (!parse_color(bv)) { printf "SKIP  %s  unsupported color %s%s\n", label, bv, tag; skip++; continue }
      if (CA < 1) { printf "SKIP  %s  translucent background %s%s\n", label, bv, tag; skip++; continue }
      l2 = lum()
      r = (l1 > l2) ? (l1 + 0.05) / (l2 + 0.05) : (l2 + 0.05) / (l1 + 0.05)
      shown = sprintf("%.2f", int(r * 100) / 100)
      st = (r >= need(PK[p])) ? "PASS" : "FAIL"
      if (st == "PASS") pass++; else fail++
      printf "%s  %s  %s:1  %s (needs %s)%s\n", st, label, shown, PK[p], need(PK[p]), tag
    }
  }
  printf "check-token-contrast: %d pairs in %d theme(s), %d pass, %d fail, %d skipped (pairs: %s)\n", np, nt, pass, fail, skip, SRC
  exit (fail > 0) ? 1 : 0
}'
ASCENT_TOKEN_LIST="$LIST" ASCENT_TOKEN_PAIRS="$PAIRS" awk "$PROG" </dev/null
