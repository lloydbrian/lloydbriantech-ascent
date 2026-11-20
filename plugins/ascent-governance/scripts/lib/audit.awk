# audit.awk — the waivers (GOV-W1–W4) and the review log (GOV-R1–R3) of check-audit.sh.
#
# Usage: awk -F '\t' -v today=YYYY-MM-DD -v cname=<contract path> -v fallback=<ADR folder or ""> \
#            -v launch=0|1 -v logname=<review log path> -v haslog=0|1 \
#            -f audit.awk CONTRACT.tsv ADRS.tsv FLOOR.tsv LOGROWS.tsv
#
# CONTRACT.tsv is contract.awk's output (key, value, line). ADRS.tsv lists the
# decision records check-audit.sh found: folder, number, 1 when its status is
# Accepted, file. A waiver is an entry of any section's waivers list; its ADR
# is looked for in that section's adr_dir, else in the fallback folder.
# FLOOR.tsv holds the reviews the floor needs ("review", name, most days old,
# rung). LOGROWS.tsv is log-rows.awk's output for the review log.
#
# Prints result rows for check-audit.sh (kind, id, status, severity, source,
# text), and for each waiver and acknowledged change a listing row with five
# more fields: section, id, what it skips, review_by, days left.
#
# A review is current when its newest readable row is no older than the floor
# allows. With launch=1 a review that is due is High; otherwise it is Medium, so
# a project's CI reports it and stays green. An open High finding in the newest
# row is High unless a waiver that has not expired names its rule id. When a
# newer row of the review cannot be read, the review is due: an older record
# does not stand for a newer one.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function days(d,   y, m, dd, a, yy, mm) {   # days since 1970-01-01 (civil calendar)
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  a = (m <= 2) ? 1 : 0; yy = y - a; mm = m + 12 * a - 3
  return 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + int((153 * mm + 2) / 5) + dd - 719469
}
function realdate(s,   y, m, d, n) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  n = (m == 2) ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  return m >= 1 && m <= 12 && d >= 1 && d <= n
}
function plural(n, word) { return n " " word (n == 1 ? "" : "s") }
function row(kind, id, st, sev, src, text) { printf "%s\t%s\t%s\t%s\t%s\t%s\n", kind, id, st, sev, src, text }
function fail(k, sev, src, text) { NF_[k]++; row("waiver", "GOV-W" k, "fail", sev, src, text) }
function rfail(k, st, sev, src, text) { RF[k]++; row("review", "GOV-R" k, st, sev, src, text) }
# whether a waiver that has not expired, and whose review date is a date, names this rule id, as a whole word
function waived(rule,   i, w, s, p, a, b) {
  for (i = 1; i <= NW; i++) {
    w = WS[i] SUBSEP WN[i]
    if (EXPIRED[w]) continue
    s = ALL[w]
    while ((p = index(s, rule)) > 0) {
      a = (p == 1) ? " " : substr(s, p - 1, 1); b = substr(s, p + length(rule), 1)
      if (a !~ /[A-Za-z0-9_-]/ && b !~ /[A-Za-z0-9_-]/) return 1
      s = substr(s, p + length(rule))
    }
  }
  return 0
}

FILENAME == ARGV[1] {
  C[$1] = $2
  if ($1 ~ /^[A-Za-z_-]+\.waivers\[[0-9]+\]/) {
    sec = $1; sub(/\..*$/, "", sec)
    n = $1; sub(/^[^\[]*\[/, "", n); sub(/\].*$/, "", n)
    fld = $1; sub(/^[^\]]*\]\.?/, "", fld)
    w = sec SUBSEP n
    if (!(w in SEEN)) { SEEN[w] = 1; NW++; WS[NW] = sec; WN[NW] = n; LINE[w] = $3 }
    if (fld == "") fld = "id"                      # a waiver written as a bare id
    if (fld == "id" || fld == "skips" || fld == "review_by") F[w, fld] = $2
    ALL[w] = ALL[w] " " $2
  } else if ($1 ~ /^decisions\.acknowledged_changes\[[0-9]+\]\./) {
    n = $1; sub(/^[^\[]*\[/, "", n); sub(/\].*$/, "", n)
    fld = $1; sub(/^[^\]]*\]\./, "", fld)
    if (!(n in ASEEN)) { ASEEN[n] = 1; NA++; AN[NA] = n; ALINE[n] = $3 }
    A[n, fld] = $2
  }
  next
}
FILENAME == ARGV[2] { sub(/\/+$/, "", $1); ADR[$1, $2 + 0] = $3; ADRFILE[$1, $2 + 0] = $4; next }
FILENAME == ARGV[3] {
  if ($1 != "review") next
  if (!($2 in MAXAGE)) { NREV++; REV[NREV] = $2; MAXAGE[$2] = $3 + 0 }
  else if ($3 + 0 < MAXAGE[$2]) MAXAGE[$2] = $3 + 0            # a higher rung may ask for a newer review
  next
}
$1 == "H" { TABLE = 1; next }
$1 == "R" {
  NROWS++; ln = $2; src = logname ":" ln; why = ""
  d = $4; name = $5; commit = $6; rating = tolower($7)
  if ($3 + 0 != 9) why = "it has " plural($3 + 0, "cell") ", not 9"
  else if (!realdate(d)) why = "its date '" d "' is not a real date (YYYY-MM-DD)"
  else if (d > today) why = "its date " d " is after today (" today ")"
  else if (name == "") why = "it names no review"
  else if (commit !~ /^[0-9A-Fa-f]+$/ || length(commit) < 7 || length(commit) > 40) why = "its commit '" commit "' is not a commit id (7 to 40 hex digits)"
  else if (rating != "strong" && rating != "moderate" && rating != "weak") why = "its rating '" $7 "' is not strong, moderate or weak"
  else if ($8 !~ /^[0-9]+$/ || $9 !~ /^[0-9]+$/ || $10 !~ /^[0-9]+$/) why = "its High, Medium and Low counts are not all numbers"
  if (why != "") { NBAD++; BADSRC[NBAD] = src; BADWHY[NBAD] = why; BADLN[NBAD] = ln; BADNAME[NBAD] = ($3 + 0 >= 2) ? name : ""; BADDATE[NBAD] = realdate(d) ? d : ""; next }
  if (!(name in NEWEST) || d >= RDATE[name]) { NEWEST[name] = ln; RDATE[name] = d; RCOMMIT[name] = commit; RRATING[name] = rating; RHIGH[name] = $8 + 0; ROPEN[name] = $11 }
  next
}

END {
  sub(/\/+$/, "", fallback)
  waivers()
  if (NREV > 0) reviews()
}

# the line of an unreadable row that names this review and is newer than its newest readable row, or 0
function unread(name,   i) {
  for (i = 1; i <= NBAD; i++)
    if (BADNAME[i] == name && BADLN[i] + 0 > NEWEST[name] + 0 && (BADDATE[i] == "" || BADDATE[i] >= RDATE[name])) return BADLN[i]
  return 0
}

function reviews(   i, name, age, max, src, n, k, T, open, covered, r, sev, st, note, named, u) {
  sev = launch ? "High" : "Medium"; st = "due"
  if (haslog && !TABLE) rfail(3, "fail", "Medium", logname, "the review log has no table with the columns Date, Review, Commit, Rating, High, Medium, Low, Open High rules, Asked by; no review in it can be read")
  for (i = 1; i <= NBAD; i++) rfail(3, "fail", "Medium", BADSRC[i], "this row of the review log cannot be read: " BADWHY[i] "; it does not count as a review")
  for (i = 1; i <= NREV; i++) {
    name = REV[i]; max = MAXAGE[name]
    if (!(name in NEWEST)) {
      rfail(1, st, sev, logname, name " has no review record" (haslog ? "" : " (no review log at " logname ")") ": run the review and record it (review-record), then ask again")
      continue
    }
    src = logname ":" NEWEST[name]; age = days(today) - days(RDATE[name])
    open = ROPEN[name]; gsub(/[,;]/, " ", open); n = split(open, T, " "); r = ""; covered = ""; named = 0
    for (k = 1; k <= n; k++) {
      if (T[k] == "-") continue
      named++
      if (waived(T[k])) covered = covered (covered == "" ? "" : ", ") T[k]; else r = r (r == "" ? "" : ", ") T[k]
    }
    note = (covered == "" ? "" : "; " covered " waived")
    u = unread(name)
    if (u) rfail(1, st, sev, logname ":" u, name ": a newer row of " name " (line " u ") cannot be read, so its record of " RDATE[name] " does not stand for it; run the review again and record it")
    else if (age > max) rfail(1, st, sev, src, name " is " plural(age, "day") " old (max " max "): its newest record is " RDATE[name] " at " RCOMMIT[name] "; run the review again and record it")
    else row("review", "GOV-R1", "pass", "-", src, name ": " RRATING[name] " on " RDATE[name] " at " RCOMMIT[name] ", " plural(age, "day") " old (max " max ")" note)
    if (RHIGH[name] > 0 && named == 0) rfail(2, "fail", "High", src, name " (" RDATE[name] ") lists " plural(RHIGH[name], "High finding") " and names no rule, so no waiver can cover " (RHIGH[name] == 1 ? "it" : "them") "; fix " (RHIGH[name] == 1 ? "it" : "them") " and run the review again")
    else if (r != "") rfail(2, "fail", "High", src, name " (" RDATE[name] ") has an open High finding no waiver covers: " r "; fix it and run the review again, or waive it in an accepted ADR")
    else if (RHIGH[name] > named) rfail(2, "fail", "High", src, name " (" RDATE[name] ") lists " plural(RHIGH[name], "High finding") " and names " plural(named, "rule") ": each open High finding names its rule, one id for each finding, or no waiver can be held against it; record the review again with every rule")
    else if (RRATING[name] == "weak") rfail(2, "fail", "Medium", src, name " (" RDATE[name] ") is rated weak" note)
  }
  if (!RF[2]) row("setup", "GOV-R2", "pass", "-", logname, "no review on the floor has an open High finding without a waiver, and none is rated weak")
  if (!haslog) row("setup", "GOV-R3", "na", "-", logname, "no review log at " logname)
  else if (!RF[3]) row("setup", "GOV-R3", "pass", "-", logname, "every row of the review log can be read (" plural(NROWS, "row") ")")
}

function waivers(   i, sec, w, src, id, skips, rb, name, left, state, dir, num, text, n, count) {
  for (i = 1; i <= NW; i++) {
    sec = WS[i]; w = sec SUBSEP WN[i]; src = cname ":" LINE[w]
    id = F[w, "id"]; skips = F[w, "skips"]; rb = F[w, "review_by"]
    name = "waiver " (id == "" ? "(no id)" : id) " (" sec ")"
    left = "-"; state = "not a real date"
    if (rb == "") fail(3, "Medium", src, name " has no review_by: it would never come up for review; add a date (YYYY-MM-DD)")
    else if (!realdate(rb)) { EXPIRED[w] = 1; fail(3, "Medium", src, name " has a review_by of '" rb "', which is not a real date (YYYY-MM-DD); it covers nothing until the date is one") }
    else {
      left = days(rb) - days(today)
      if (left < 0) { state = "expired"; EXPIRED[w] = 1; fail(1, "High", src, name " expired " plural(-left, "day") " ago (review_by " rb "): what it skips is a finding again; fix that, or renew the waiver in its ADR and here") }
      else {
        state = plural(left, "day") " left"
        if (left <= 14) fail(2, "Low", src, name " is due for review " (left == 0 ? "today" : "in " plural(left, "day")) " (" rb ")")
      }
    }
    if (skips == "") fail(4, "Medium", src, name " does not say what it skips: add skips, in words, with the rule id of each finding it covers")
    dir = ((sec ".adr_dir") in C && C[sec ".adr_dir"] != "") ? C[sec ".adr_dir"] : fallback
    sub(/\/+$/, "", dir)
    if (id == "") fail(4, "Medium", src, name " has no id: a waiver names the accepted ADR that allows it (ADR-<number>)")
    else if (id !~ /^ADR-[0-9]+$/) fail(4, "Medium", src, name " has an id of '" id "', which is not an ADR id (ADR-<number>)")
    else if (dir == "") NOADR++
    else {
      num = substr(id, 5) + 0
      if (!((dir, num) in ADR)) fail(4, "Medium", src, name ": no " id " in " dir ", so nothing records why this is skipped")
      else if (ADR[dir, num] != 1) fail(4, "Medium", ADRFILE[dir, num], name ": " id " is not accepted (its status is not Accepted)")
    }
    text = "waiver " sec " " (id == "" ? "(no id)" : id) ": " (skips == "" ? "(nothing named)" : skips) (rb == "" ? " (no review date)" : "; review by " rb " (" state ")")
    printf "waiver\t-\tnote\t-\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", src, text, sec, (id == "" ? "-" : id), (skips == "" ? "-" : skips), (rb == "" ? "-" : rb), left
  }
  for (i = 1; i <= NA; i++) {
    n = AN[i]
    text = "acknowledged change " A[n, "adr"] " at " A[n, "commit"] " (decisions.acknowledged_changes: not a waiver, never expires)"
    printf "ack\t-\tnote\t-\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", cname ":" ALINE[n], text, "decisions", A[n, "adr"], "the change at commit " A[n, "commit"], "-", "-"
  }
  if (NW == 0) { row("setup", "GOV-W1", "na", "-", cname, "the contract has no waivers (GOV-W1 to GOV-W4 have nothing to check)"); return }
  count = " (" plural(NW, "waiver") ")"
  if (!NF_[1]) row("setup", "GOV-W1", "pass", "-", cname, "no waiver is past its review date" count)
  if (!NF_[2]) row("setup", "GOV-W2", "pass", "-", cname, "no waiver is due for review within 14 days" count)
  if (!NF_[3]) row("setup", "GOV-W3", "pass", "-", cname, "every waiver has a real review date" count)
  if (!NF_[4]) {
    if (NOADR == NW) row("setup", "GOV-W4", "na", "-", cname, "no ADR folder: whether each waiver's ADR is accepted was not checked")
    else row("setup", "GOV-W4", "pass", "-", cname, "every waiver says what it skips and names an accepted ADR" count)
  }
}
