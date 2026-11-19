# adr-common.awk — reads ADR files in the three formats ascent-adr knows: ASCENT
# (**Status:** and **Date:** fields, five sections), Nygard and adr-tools ("## Status"
# section, "Date:" line), and MADR (front matter or "* Status:" lines). Loaded with
# -f before the program that uses it. Portable: POSIX awk (BWK, mawk, gawk).
#
# Per file, call adr_begin() on its first line and adr_line($0) on every line; then:
#   A_STATUS, A_STATUS_L   the status text and its line ("" and 0 when absent)
#   A_DATE, A_DATE_L       the date text and its line
#   A_TITLE, A_TITLE_L     the first "# " heading
#   A_HEAD[h]              the line of each "## " heading, lower case
#   A_SUPS                 "<line>:<number> " for every number a "supersedes" names
#   A_SKIP[n]              1 for a line that carries the status (adr_body skips it)

function adr_trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function adr_strip(s) {  # markdown emphasis, list marks and link brackets
  gsub(/[*_`]/, "", s); sub(/^[ \t]*[-+][ \t]+/, "", s); return adr_trim(s)
}
function adr_isfile(path,   b) {  # an ADR by its file name: NNNN-title.md or ADR-NNN-title.md
  b = path; sub(/.*\//, "", b); b = tolower(b)
  return (b ~ /^(adr-)?[0-9]+[-_][^\/]*\.md$/ && b !~ /^(adr-)?0+[-_]template/)
}
function adr_num(path,   b) {  # the number in the file name, as a number
  b = path; sub(/.*\//, "", b); sub(/^[Aa][Dd][Rr]-/, "", b)
  if (match(b, /^[0-9]+/)) return substr(b, 1, RLENGTH) + 0
  return -1
}
function adr_class(s) {  # the status class: accepted, proposed, rejected, deprecated, superseded or ""
  s = tolower(adr_strip(s)); sub(/^\[/, "", s)
  if (s ~ /^superseded/) return "superseded"
  if (s ~ /^accepted/) return "accepted"
  if (s ~ /^(proposed|draft)/) return "proposed"
  if (s ~ /^rejected/) return "rejected"
  if (s ~ /^deprecated/) return "deprecated"
  return ""
}
function adr_after(s, word,   t, i) {  # the first number after WORD in S, or -1
  t = tolower(s); if (!(i = index(t, word))) return -1
  t = substr(t, i + length(word))
  # an ADR reference follows at once: "ADR-5", "#5", "5", "[5. Title](0005-x.md)", "[ADR-5](...)"
  if (match(t, /^[ \t:]*\[?[ \t]*(adr[- ]?|#)?[0-9]+/)) { t = substr(t, RSTART, RLENGTH); match(t, /[0-9]+/); return substr(t, RSTART, RLENGTH) + 0 }
  return -1
}
function adr_begin() {
  A_STATUS = ""; A_STATUS_L = 0; A_DATE = ""; A_DATE_L = 0; A_TITLE = ""; A_TITLE_L = 0; A_SUPS = ""
  delete A_HEAD; delete A_SKIP; A_FM = 0; A_INSTATUS = 0; A_FENCE = 0
}
function adr_line(s,   t, l, k, v, n, i, P, got) {
  sub(/\r$/, "", s)
  if (FNR == 1 && s ~ /^---[ \t]*$/) { A_FM = 1; return }
  if (A_FM) {  # MADR front matter: status: and date:
    if (s ~ /^---[ \t]*$/) { A_FM = 0; return }
    k = tolower(s); sub(/:.*/, "", k); v = s; sub(/^[^:]*:[ \t]*/, "", v); v = adr_trim(v); gsub(/^["']|["']$/, "", v)
    if (k == "status" && !A_STATUS_L) { A_STATUS = v; A_STATUS_L = FNR; A_SKIP[FNR] = 1 }
    if (k == "date" && !A_DATE_L) { A_DATE = v; A_DATE_L = FNR }
    return
  }
  if (s ~ /^[ \t]*(```|~~~)/) { A_FENCE = !A_FENCE; return }
  if (A_FENCE) return
  if (s ~ /^# / && !A_TITLE_L) { A_TITLE = adr_trim(substr(s, 3)); A_TITLE_L = FNR; return }
  if (s ~ /^##[ \t]/) {
    t = tolower(adr_strip(substr(s, 3))); sub(/[ \t]*:$/, "", t)
    if (!(t in A_HEAD)) A_HEAD[t] = FNR
    A_INSTATUS = (t == "status"); if (A_INSTATUS) A_SKIP[FNR] = 1
    return
  }
  if (tolower(s) ~ /supersedes/) {
    t = tolower(s); while ((v = adr_after(t, "supersedes")) >= 0) { A_SUPS = A_SUPS FNR ":" v " "; t = substr(t, index(t, "supersedes") + 10) }
  }
  if (A_INSTATUS) {  # "## Status" then the status on its own line; later lines may add links
    A_SKIP[FNR] = 1
    if (!A_STATUS_L && adr_trim(s) != "") { A_STATUS = adr_strip(s); A_STATUS_L = FNR }
    return
  }
  t = adr_strip(s); l = tolower(t)
  if (index(t, "|") && t !~ /^\|/) {  # "Date: 2026-03-25 | Status: Accepted": a field per part
    n = split(t, P, "|"); got = 0
    for (i = 1; i <= n; i++) {
      v = adr_trim(P[i]); k = tolower(v)
      if (k ~ /^status[ \t]*:/ && !A_STATUS_L) { sub(/^[^:]*:[ \t]*/, "", v); A_STATUS = v; A_STATUS_L = FNR; A_SKIP[FNR] = 1; got = 1 }
      else if (k ~ /^date[ \t]*:/ && !A_DATE_L) { sub(/^[^:]*:[ \t]*/, "", v); A_DATE = v; A_DATE_L = FNR; got = 1 }
    }
    if (got) return
  }
  if (l ~ /^status[ \t]*:/ && !A_STATUS_L) { sub(/^[^:]*:[ \t]*/, "", t); A_STATUS = t; A_STATUS_L = FNR; A_SKIP[FNR] = 1; return }
  if (l ~ /^date[ \t]*:/ && !A_DATE_L) { sub(/^[^:]*:[ \t]*/, "", t); A_DATE = t; A_DATE_L = FNR; return }
}
function adr_realdate(d,   y, m, dd, ml) {  # YYYY-MM-DD at the start, a real calendar date
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) return 0
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m < 1 || m > 12 || dd < 1) return 0
  ml = substr("312831303130313130313031", 2 * m - 1, 2) + 0
  if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) ml = 29
  return dd <= ml
}
function adr_days(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
}
