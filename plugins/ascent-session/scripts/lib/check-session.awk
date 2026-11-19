# check-session.awk — the program check-session.sh runs. Reads the working memory,
# the session state and the handoff that exist, named by CS_*_IN;
# the options and the history findings come from CS_* in the environment.
# Portable: POSIX awk (BWK, mawk, gawk).

BEGIN {
  TODAY = ENVIRON["CS_TODAY"]; MAXAGE = ENVIRON["CS_MAXAGE"] + 0; MAT = ENVIRON["CS_MATURITY"]
  MEM = ENVIRON["CS_MEMORY"]; ST = ENVIRON["CS_STATE"]; HO = ENVIRON["CS_HANDOFF"]
  HAVEM = ENVIRON["CS_HAVE_MEMORY"] == 1; HAVES = ENVIRON["CS_HAVE_STATE"] == 1; HAVEH = ENVIRON["CS_HAVE_HANDOFF"] == 1
  NOGIT = ENVIRON["CS_NOGIT"]; REQH = ENVIRON["CS_REQUIRE_HANDOFF"] == 1
  NLOST = split(ENVIRON["CS_LOST"], LOST, "\n"); TRACKED = ENVIRON["CS_STATE_TRACKED"]; IGNORED = ENVIRON["CS_STATE_IGNORED"]
  HCHECKED = ENVIRON["CS_HISTORY_CHECKED"] + 0
  MF = ENVIRON["CS_MEMORY_IN"]; SF = ENVIRON["CS_STATE_IN"]; HF = ENVIRON["CS_HANDOFF_IN"]
}
function fail(k, sev, w, msg) {
  if (MAT == "prototype") { NOTES = NOTES sprintf("NOTE  %-7s %-6s %s  %s (prototype: not rated)\n", "SES-" k, sev, w, msg); return }
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "SES-" k, sev, w, msg); NF_[k]++
}
function realdate(d,   y, m, dd, ml) {
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) return 0
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m < 1 || m > 12 || dd < 1) return 0
  ml = substr("312831303130313130313031", 2 * m - 1, 2) + 0
  if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) ml = 29
  return dd <= ml
}
function days(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
}
FNR == 1 { FENCE = 0; SEC = "" }
{ sub(/\r$/, "") }
/^[ \t]*(```|~~~)/ { FENCE = !FENCE; next }
FENCE { next }
FILENAME == MF && /^## / {  # the working memory
  h = tolower($0); sub(/^## +/, "", h); sub(/[ \t]+$/, "", h)
  SEC = (h == "decisions" || h == "patterns adopted" || h == "patterns rejected") ? h : ""
  if (h == "decisions") MDEC = FNR
  next
}
FILENAME == MF && SEC != "" && /^[-*] / {
  NENT++; e = $0; sub(/^[-*] +/, "", e)
  if (e !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]: / && SEC != "decisions") next  # patterns may be undated (session-protocol)
  if (e !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]: /) fail("S2", "Low", MEM ":" FNR, "a decision does not start with a date (- YYYY-MM-DD: ...)")
  else {
    d = substr(e, 1, 10)
    if (!realdate(d)) fail("S2", "Low", MEM ":" FNR, "an entry under \"## " SEC "\" is dated " d ", not a real date")
    else if (days(d) > days(TODAY)) fail("S2", "Low", MEM ":" FNR, "an entry under \"## " SEC "\" is dated " d ", after today")
    else {
      if ((SEC in LASTD) && d < LASTD[SEC]) fail("S2", "Low", MEM ":" FNR, "an entry under \"## " SEC "\" is dated " d ", before the entry above it (" LASTD[SEC] "): entries are appended in order")
      LASTD[SEC] = d; if (d > NEWEST) NEWEST = d
    }
  }
  next
}
FILENAME == SF && index($0, "(fill in:") && !SFILL { SFILL = FNR }
FILENAME == SF && /^## / { h = tolower($0); sub(/^## +/, "", h); sub(/[ \t]+$/, "", h); SHEAD[h] = FNR; next }
FILENAME == SF && tolower($0) ~ /^\**captured:?\**:? *[0-9]/ && !SCAP { t = $0; sub(/^[^0-9]*/, "", t); SCAP = substr(t, 1, 10); SCAPL = FNR; next }
FILENAME == HF && /^## / { h = tolower($0); sub(/^## +/, "", h); sub(/[ \t]+$/, "", h); HHEAD[h] = FNR; next }
FILENAME == HF && tolower($0) ~ /^\**(generated|updated):?\**:? *[0-9]/ && !HGEN { t = $0; sub(/^[^0-9]*/, "", t); HGEN = substr(t, 1, 10); HGENL = FNR; next }

END {
  # SES-S1: the shared record exists
  if (!HAVEM) fail("S1", "Medium", MEM ":absent", "no working memory: decisions made in one session are lost to the next and to the team")
  else { CHK["S1"]++; if (!MDEC) fail("S1", "Medium", MEM ":1", "the working memory has no \"## Decisions\" section") }
  if (HAVEM) CHK["S2"] += NENT
  # SES-S3: entries are only appended (from the history the shell compared)
  if (HCHECKED > 0) {
    CHK["S3"] += HCHECKED
    for (i = 1; i <= NLOST; i++) if (LOST[i] != "") { split(LOST[i], p, "\t"); fail("S3", "Medium", MEM ":1", "an entry under \"## " p[2] "\" in " p[1] " was changed or removed later: \"" substr(p[3], 1, 70) "\"; record a correction as a new dated entry") }
  }
  # SES-S4: the session state is personal and transient, never committed
  if (NOGIT == "" && (HAVEM || HAVES)) {
    CHK["S4"]++
    if (TRACKED == 1) fail("S4", "Medium", ST ":1", "the session state is tracked by git: one person's working state overwrites another's; untrack it and add it to .gitignore")
    else if (IGNORED != 1) fail("S4", "Medium", ST ":absent", "the session state is not in .gitignore, so git add would commit it")
  }
  # SES-S5: the session state is complete and fresh
  if (HAVES) {
    CHK["S5"]++
    m = split("current focus|active decisions|blockers|next actions", r, "|"); miss = ""
    for (i = 1; i <= m; i++) if (!(r[i] in SHEAD)) miss = miss (miss == "" ? "" : ", ") "\"## " r[i] "\""
    if (miss != "") fail("S5", "Low", ST ":1", "the session state is missing " miss)
    if (SFILL) fail("S5", "Low", ST ":" SFILL, "the session state still holds a \"(fill in: ...)\" placeholder from make session-snapshot")
    if (!SCAP) fail("S5", "Low", ST ":1", "the session state has no \"Captured: YYYY-MM-DD\" line")
    else if (!realdate(SCAP)) fail("S5", "Low", ST ":" SCAPL, "the session state was captured on " SCAP ", not a real date")
    else if (days(TODAY) - days(SCAP) > MAXAGE) fail("S5", "Low", ST ":" SCAPL, "the session state was captured " (days(TODAY) - days(SCAP)) " days ago (max " MAXAGE "): the next session resumes from stale state")
  }
  # SES-S6: the handoff is complete and no older than the newest decision
  if (HAVEH) {
    CHK["S6"]++
    m = split("where to start|project state|project conventions", r, "|"); miss = ""
    for (i = 1; i <= m; i++) if (!(r[i] in HHEAD)) miss = miss (miss == "" ? "" : ", ") "\"## " r[i] "\""
    if (miss != "") fail("S6", "Low", HO ":1", "the handoff is missing " miss)
    if (!HGEN) fail("S6", "Low", HO ":1", "the handoff has no \"Generated: YYYY-MM-DD\" line")
    else if (!realdate(HGEN)) fail("S6", "Low", HO ":" HGENL, "the handoff was generated on " HGEN ", not a real date")
    else if (NEWEST != "" && HGEN < NEWEST) fail("S6", "Low", HO ":" HGENL, "the handoff was generated on " HGEN ", before the newest working-memory entry (" NEWEST "): it misses decisions")
  } else if (REQH) { CHK["S6"]++; fail("S6", "Low", HO ":absent", "no handoff, and session.handoff_required is set") }

  D["S1"] = "working memory present"; D["S2"] = "entries dated, real and in order"; D["S3"] = "entries only appended"
  D["S4"] = "session state kept out of git"; D["S5"] = "session state complete and fresh"; D["S6"] = "handoff complete and current"
  NA["S1"] = ""; NA["S2"] = (HAVEM ? "no entry yet" : "no working memory"); NA["S3"] = (ENVIRON["CS_S3NOGIT"] != "" ? ENVIRON["CS_S3NOGIT"] : "no earlier version of the working memory in the git history")
  NA["S4"] = (NOGIT != "" ? NOGIT : "no session records yet"); NA["S5"] = "no session state: the next session starts cold"; NA["S6"] = "no handoff"
  NFAIL = 0
  for (i = 1; i <= 6; i++) {
    k = "S" i
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "SES-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "SES-" k, D[k], NA[k]
  }
  printf "%s", NOTES
  printf "check-session: %s, %d entr%s, newest %s, %d failure(s); it checks that the records are kept, not that they are accurate\n", (HAVEM ? MEM : "no working memory"), NENT, (NENT == 1 ? "y" : "ies"), (NEWEST == "" ? "none" : NEWEST), NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
