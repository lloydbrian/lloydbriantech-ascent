#!/usr/bin/env bash
# Acceptance sign-off check: every acceptance criterion of a change has evidence, and a
# person accepted it by name and date. Part of the ascent-delivery plugin (delivery-loop
# Steps 5 and 7, ADR-024). Read-only.
#
# Usage: check-acceptance.sh [--draft] [--acceptor NAME]... [--root DIR] RECORD
#
# RECORD is an acceptance record (by default docs/delivery/acceptance/<date>-<slug>.md,
# the contract's delivery.acceptance_dir): a Markdown table whose header names the
# columns Criterion, Evidence, Accepted by and Accepted on (a # column is optional).
# The first such table is read. --root is the repository that evidence paths are
# relative to (default: the current directory). --acceptor is a person the contract
# lists under delivery.acceptors, once per person; with none, any name counts.
# --draft checks the evidence only (DEL-A1), as the definition of done does before a
# person has signed.
#
# Checks (all High: any failure stops the production step):
#   DEL-A1  every criterion has evidence: a test at path:line (or path:line-line) that
#           exists inside the repository, or "manual: <what was checked>"; several
#           items are separated by ";". A record with no criteria fails.
#   DEL-A2  every criterion is accepted by a person, by name, on a date (YYYY-MM-DD,
#           a real date, not after today). Claude, an assistant or a placeholder
#           (TBD, -, <name>) is not a person.
#   DEL-A3  with --acceptor, every "Accepted by" is one of the listed people
#           (case and spacing ignored)
#
# Output: one FAIL line per finding (FAIL  DEL-An  High   record:line  message), a PASS
# line per check with no finding (with the count checked), N/A for DEL-A2 and DEL-A3
# with --draft and for DEL-A3 with no --acceptor, then "check-acceptance: ...".
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input (no record, or no acceptance table).
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
DRAFT=0; ROOT="."; ACCEPTORS=""; RECORD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --draft) DRAFT=1; shift ;;
    --acceptor) [ $# -ge 2 ] || { usage >&2; exit 2; }
      ACCEPTORS="$ACCEPTORS$2
"; shift 2 ;;
    --root) [ $# -ge 2 ] || { usage >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    -*) echo "check-acceptance: unknown option $1" >&2; exit 2 ;;
    *) [ -z "$RECORD" ] || { echo "check-acceptance: one record at a time: $RECORD, $1" >&2; exit 2; }; RECORD="$1"; shift ;;
  esac
done
[ -n "$RECORD" ] || { usage >&2; exit 2; }
[ -f "$RECORD" ] || { echo "check-acceptance: no such record: $RECORD" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "check-acceptance: --root is not a directory: $ROOT" >&2; exit 2; }

PROG='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function norm(s) { s = tolower(trim(s)); gsub(/[ \t]+/, " ", s); return s }
# cells of a table row, with \| kept as a literal bar
function cells(line,   n, i) {
  gsub(/\\\|/, "\001", line); sub(/^[ \t]*\|/, "", line); sub(/\|[ \t]*$/, "", line)
  n = split(line, C, "|")
  for (i = 1; i <= n; i++) { C[i] = trim(C[i]); gsub(/\001/, "|", C[i]) }
  return n
}
function fail(k, ln, msg) { NF_[k]++; NFAIL++; OUT[k] = OUT[k] sprintf("FAIL  %-7s High   %s:%d  %s\n", "DEL-" k, REC, ln, msg) }
function placeholder(v) { return v == "" || v ~ /^(-|—|–|tbd|todo|pending|n\/a|none|\?+|x+)$/ || v ~ /^<.*>$/ }
# a test at path:line inside ROOT, or "" with the reason in WHY
function evidence_ok(item,   p, a, b, f, n, line, rc) {
  gsub(/`/, "", item); item = trim(item)
  if (tolower(item) ~ /^manual[ \t]*:/) {
    sub(/^[^:]*:[ \t]*/, "", item)
    if (length(item) < 8 || placeholder(tolower(item))) { WHY = "\"manual:\" needs what was checked and where"; return 0 }
    return 1
  }
  if (!match(item, /:[0-9]+(-[0-9]+)?$/)) { WHY = "\"" item "\" is neither path:line nor \"manual: <what was checked>\""; return 0 }
  p = substr(item, 1, RSTART - 1); a = substr(item, RSTART + 1); b = a
  if (index(a, "-")) { b = substr(a, index(a, "-") + 1); a = substr(a, 1, index(a, "-") - 1) }
  a += 0; b += 0
  if (p == "" || p ~ /^\// || p ~ /(^|\/)\.\.(\/|$)/) { WHY = "\"" p "\" is not a path inside the repository"; return 0 }
  if (a < 1 || b < a) { WHY = "\"" item "\" names no line"; return 0 }
  f = ROOT "/" p; n = 0
  while ((rc = (getline line < f)) > 0) { n++; if (n >= b) break }
  close(f)
  if (rc < 0 && n == 0) { WHY = p " does not exist"; return 0 }
  if (n < b) { WHY = p " has " n " line(s), so line " b " does not exist"; return 0 }
  return 1
}
function real_date(d,   y, m, dd, ml) {
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m < 1 || m > 12 || dd < 1) return 0
  ml = (m == 2) ? ((y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  return dd <= ml
}
BEGIN {
  REC = ENVIRON["A_RECORD"]; ROOT = ENVIRON["A_ROOT"]; DRAFT = ENVIRON["A_DRAFT"] + 0; TODAY = ENVIRON["A_TODAY"]
  na = split(ENVIRON["A_ACCEPTORS"], al, "\n"); NACC = 0
  for (i = 1; i <= na; i++) if (trim(al[i]) != "") { ACC[norm(al[i])] = 1; NACC++ }
  D["A1"] = "every criterion has evidence"; D["A2"] = "every criterion is accepted by a person, by name and date"
  D["A3"] = "every acceptor is listed in the contract"
  intable = 0; found = 0; done_ = 0; nrow = 0
  while ((getline line < REC) > 0) {
    ln++; sub(/\r$/, "", line)
    if (done_) continue
    if (!intable) {
      if (line !~ /^[ \t]*\|/) continue
      n = cells(line); ci = ev = by = on = 0
      for (i = 1; i <= n; i++) { h = norm(C[i]); if (h == "criterion") ci = i; else if (h == "evidence") ev = i; else if (h == "accepted by") by = i; else if (h == "accepted on") on = i }
      if (ci && ev && by && on) { intable = 1; found = 1; HEADN = n }
      continue
    }
    if (line !~ /^[ \t]*\|/) { intable = 0; done_ = 1; continue }
    if (line ~ /^[ \t]*\|[ \t:|-]*$/) continue
    n = cells(line); nrow++
    crit = C[ci]; label = "criterion " ((C[1] ~ /^[0-9]+$/) ? C[1] : nrow)
    if (placeholder(tolower(crit))) label = label " (no text)"
    # DEL-A1: evidence
    CHK["A1"]++; e = C[ev]; nb = split(e, items, ";"); okn = 0; bad = ""
    for (j = 1; j <= nb; j++) { if (trim(items[j]) == "") continue; if (evidence_ok(items[j])) okn++; else if (bad == "") bad = WHY }
    if (placeholder(tolower(trim(e)))) fail("A1", ln, label " has no evidence (a test at path:line, or \"manual: <what was checked>\")")
    else if (bad != "") fail("A1", ln, label ": " bad)
    else if (okn == 0) fail("A1", ln, label " has no evidence (a test at path:line, or \"manual: <what was checked>\")")
    if (DRAFT) continue
    # DEL-A2: a person, by name, on a date
    CHK["A2"]++; who = trim(C[by]); when = trim(C[on]); lw = tolower(who); person = 0
    if (placeholder(lw)) fail("A2", ln, label " is not accepted: \"Accepted by\" is empty; only the person who accepts it fills it in")
    else if (lw ~ /(^|[^a-z])(claude|assistant|copilot|chatgpt|gemini|llm|bot)([^a-z]|$)/) fail("A2", ln, label " is \"accepted\" by " who ", which is not a person; only a person accepts a criterion")
    else person = 1
    if (placeholder(tolower(when))) fail("A2", ln, label " has no \"Accepted on\" date (YYYY-MM-DD)")
    else if (!real_date(when)) fail("A2", ln, label ": \"Accepted on\" is " when ", not a date as YYYY-MM-DD")
    else if (when > TODAY) fail("A2", ln, label ": \"Accepted on\" is " when ", after today (" TODAY ")")
    # DEL-A3: a listed acceptor
    if (NACC > 0 && person) { CHK["A3"]++; if (!(norm(who) in ACC)) fail("A3", ln, label " is accepted by " who ", who is not among the contract\047s delivery.acceptors") }
  }
  close(REC)
  if (!found) { print "check-acceptance: " REC " has no acceptance table (columns Criterion, Evidence, Accepted by, Accepted on)" > "/dev/stderr"; exit 2 }
  if (nrow == 0) { CHK["A1"]++; fail("A1", ln, "the record lists no criteria") }
  split("A1 A2 A3", ORDER, " ")
  for (i = 1; i <= 3; i++) {
    k = ORDER[i]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (DRAFT && k != "A1") printf "N/A   %-7s %s (--draft: not signed yet)\n", "DEL-" k, D[k]
    else if (k == "A3" && NACC == 0) printf "N/A   %-7s %s (the contract lists no acceptors)\n", "DEL-" k, D[k]
    else printf "PASS  %-7s %s (%d checked)\n", "DEL-" k, D[k], CHK[k]
  }
  printf "check-acceptance: %s, %d criteria, %d failure(s)%s\n", REC, nrow, NFAIL, DRAFT ? " (draft: evidence only)" : ""
  exit (NFAIL > 0) ? 1 : 0
}'
A_RECORD="$RECORD" A_ROOT="$ROOT" A_DRAFT="$DRAFT" A_ACCEPTORS="$ACCEPTORS" A_TODAY="$(date +%Y-%m-%d)" \
  LC_ALL=C awk "$PROG"
