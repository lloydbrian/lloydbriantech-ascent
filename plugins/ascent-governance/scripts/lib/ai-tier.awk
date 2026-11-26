# ai-tier.awk — the AI risk-tier records (GOV-A1–A5) of check-audit.sh.
#
# Usage: awk -F '\t' -v today=YYYY-MM-DD -v dir=<ai_tier_dir> -v cname=<contract path> \
#            -f ai-tier.awk CONTRACT.tsv APPS.tsv
#
# CONTRACT.tsv is contract.awk's output (key, value, line): governance.approvers
# is read from it. APPS.tsv lists the AI applications, one "name<TAB>where" row
# each: where is the contract line that declares it. Each application's record
# is <dir>/<name>.md, read here with getline; its marked table is
#
#   <!-- ai-tier:start -->
#   | Field | Value | Note |
#   |---|---|---|
#   | application | support-assistant | |
#   | tier | 2 | |
#   ...
#   <!-- ai-tier:end -->
#
# with the fields application, tier, audience, actions, decisions_about_people,
# personal_data, decided_by, decided_on and review_by. A person decides the tier
# and signs; GOV-A5 holds that choice to the reasons the record gives:
# actions irreversible or financial, or decisions_about_people yes, is tier 3;
# audience external or actions reversible is at least tier 2.
#
# Prints result rows for check-audit.sh (kind, id, status, severity, source, text).
# CR line ends are read as LF ones.
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
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cell(s) { s = trim(s); if (s ~ /^`.*`$/ && length(s) >= 2) s = substr(s, 2, length(s) - 2); return trim(s) }
function row(id, st, sev, src, text) { printf "launch\t%s\t%s\t%s\t%s\t%s\n", id, st, sev, src, text }
function afail(k, sev, src, text) { FAILED++; row("GOV-A" k, "fail", sev, src, text) }
function oneof(v, list) { return index(" " list " ", " " v " ") > 0 && v != "" }
function listed(list,   P, n, i, out) { n = split(list, P, " "); out = P[1]; for (i = 2; i <= n; i++) out = out (i == n ? " or " : ", ") P[i]; return out }

# the record's table into R[field]; returns 1 when it has one
function readrecord(f,   line, on, seen, n, P, k) {
  split("", R); on = 0; seen = 0
  while ((getline line < f) > 0) {
    sub(/\r$/, "", line)
    if (index(line, "<!-- ai-tier:start -->")) { on = 1; seen = 1; continue }
    if (index(line, "<!-- ai-tier:end -->")) { on = 0; continue }
    if (!on || line !~ /^[ \t]*\|/) continue
    n = split(line, P, "|")
    if (n < 3) continue
    k = tolower(cell(P[2]))
    if (k == "" || k == "field" || k ~ /^-+$/ || k ~ /^:?-+:?$/) continue
    R[k] = cell(P[3]); HAS[k] = 1
  }
  close(f)
  return seen
}

FILENAME == ARGV[1] {
  if ($1 ~ /^governance\.approvers\[[0-9]+\]$/ && $2 != "") { NAP++; AP[NAP] = $2 }
  next
}
{ NAPP++; APP[NAPP] = $1; WHERE[NAPP] = $2 }

END {
  sub(/\/+$/, "", dir)
  aplist = ""; for (i = 1; i <= NAP; i++) aplist = aplist (i > 1 ? ", " : "") AP[i]
  for (a = 1; a <= NAPP; a++) {
    name = APP[a]; f = dir "/" name ".md"; FAILED = 0
    if (name !~ /^[A-Za-z0-9][A-Za-z0-9_-]*$/) {
      afail(2, "High", WHERE[a], "the AI application '" name "' is not letters, digits, - and _; its name is its tier record's file name")
      continue
    }
    if ((getline probe < f) <= 0) {
      close(f)
      afail(1, "High", f, name " has no AI risk-tier record (" f "): launch-readiness drafts one; a person decides the tier and signs it")
      continue
    }
    close(f)
    split("", HAS)
    if (!readrecord(f)) { afail(2, "High", f, f " has no ai-tier table (<!-- ai-tier:start --> ... <!-- ai-tier:end -->): see references/ai-tier-template.md"); continue }

    # GOV-A2: every field, the tier, the fixed values, the name
    nf = split("application tier audience actions decisions_about_people personal_data decided_by decided_on review_by", FLD, " ")
    for (i = 1; i <= nf; i++) if (!(FLD[i] in HAS)) afail(2, "High", f, f " has no " FLD[i] " row; the record has every field of references/ai-tier-template.md")
    t = R["tier"]; tok = 1
    if (("tier" in HAS) && !oneof(t, "1 2 3")) { tok = 0; afail(2, "High", f, f ": tier is '" t "'; it is 1, 2 or 3") }
    split("audience=internal external|actions=none reversible irreversible financial|decisions_about_people=no yes|personal_data=none personal sensitive", REASONS, "|")
    rok = 1
    for (i = 1; i <= 4; i++) {
      k = REASONS[i]; sub(/=.*$/, "", k); vals = REASONS[i]; sub(/^[^=]*=/, "", vals)
      if (!(k in HAS)) { rok = 0; continue }
      if (!oneof(R[k], vals)) { rok = 0; afail(2, "High", f, f ": " k " is '" R[k] "'; it is " listed(vals)) }
    }
    if (("application" in HAS) && R["application"] != name)
      afail(2, "High", f, f " names the application '" R["application"] "', and its file name says '" name "'; they are the same")
    rb = R["review_by"]
    if (("review_by" in HAS) && !realdate(rb)) afail(2, "High", f, f ": review_by is '" rb "', which is not a real date (YYYY-MM-DD)")

    # GOV-A3: a person decided, on a date
    by = R["decided_by"]; on = R["decided_on"]
    if ("decided_by" in HAS) {
      if (by == "" || by ~ /^_+$/ || index(by, "# guess")) afail(3, "High", f, f ": no person has decided it yet (decided_by is empty); a person decides the tier and signs, never Claude")
      else if (NAP > 0) {
        found = 0; for (i = 1; i <= NAP; i++) if (tolower(AP[i]) == tolower(by)) found = 1
        if (!found) afail(3, "High", f, f ": " by " decided the tier and is not in governance.approvers (" aplist ")")
      }
    }
    if ("decided_on" in HAS) {
      if (!realdate(on)) afail(3, "High", f, f ": decided_on is '" on "', which is not a real date (YYYY-MM-DD)")
      else if (on > today) afail(3, "High", f, f ": decided_on " on " is after today (" today ")")
    }

    # GOV-A4: the review date is not past
    if (realdate(rb) && rb < today) afail(4, "Medium", f, f ": review_by " rb " is past (" (days(today) - days(rb)) " day(s) ago): a person reviews the tier and its reasons, and sets a new date")

    # GOV-A5: the tier is not below the floor its reasons imply
    if (tok && rok) {
      floor = 1; why = ""
      if (R["actions"] == "irreversible" || R["actions"] == "financial") { floor = 3; why = "actions: " R["actions"] }
      if (R["decisions_about_people"] == "yes") { floor = 3; why = why (why == "" ? "" : ", ") "decisions_about_people: yes" }
      if (floor < 3) {
        if (R["audience"] == "external") { floor = 2; why = "audience: external" }
        if (R["actions"] == "reversible") { floor = 2; why = why (why == "" ? "" : ", ") "actions: reversible" }
      }
      if (t + 0 < floor) afail(5, "High", f, f ": tier " t " is below tier " floor ", which its reasons imply (" why "); raise the tier, or correct the reasons, or waive it in an accepted ADR")
    }
    if (!FAILED) row("GOV-A1", "pass", "-", f, name ": tier " t ", decided by " by " on " on ", review by " rb " (" f ")")
  }
}
