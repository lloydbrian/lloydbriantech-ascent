# evidence.awk — check-ai-evidence.sh's checks (AI-G, AI-E, AI-R, AI-L).
# Loaded after common.awk; reads no main input (everything runs in BEGIN).
# Variables: app, goldendir, goldenlist (a file listing the golden set's
# files), results, format, haveres and res (the results flattened by json.awk),
# rate, arate, maxage, retr, haveret and ret (the retrieval results,
# flattened), targets ("name=value " each), sources, reviewby, notes, tierfile,
# threshold, today, gitat and gitdate (the last commit to a prompt or the
# golden set, in seconds and as a date, UTC; empty when unknown).
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function cell(s) { s = trim(s); gsub(/`/, "", s); if (s ~ /^</) s = ""; return s }
function realdate(s,   y, m, d, n) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  n = (m == 2) ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  return m >= 1 && m <= 12 && d >= 1 && d <= n
}
function days(s,   y, m, d) {   # days since 1970-01-01 of a YYYY-MM-DD date
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d - 719469
}
function epoch(s,   t, z, sign, zh, zm, e) {   # seconds since 1970 (UTC) of an ISO 8601 time; -1 when it is not one
  if (!realdate(substr(s, 1, 10))) return -1
  e = days(substr(s, 1, 10)) * 86400
  t = substr(s, 11)
  if (t == "") return e
  if (t !~ /^[T ][0-9][0-9]:[0-9][0-9](:[0-9][0-9](\.[0-9]+)?)?(Z|[-+][0-9][0-9]:?[0-9][0-9])?$/) return -1
  e += substr(t, 2, 2) * 3600 + substr(t, 5, 2) * 60
  if (substr(t, 7, 1) == ":") e += substr(t, 8, 2)
  if (match(t, /[-+][0-9][0-9]:?[0-9][0-9]$/)) {
    z = substr(t, RSTART); sign = substr(z, 1, 1); gsub(/:/, "", z); zh = substr(z, 2, 2) + 0; zm = substr(z, 4, 2) + 0
    e += (sign == "+" ? -1 : 1) * (zh * 3600 + zm * 60)
  }
  return e
}
function utcdate(e,   d, y, m, doy, mp, era, yoe, dd) {   # YYYY-MM-DD of seconds since 1970
  d = int(e / 86400); if (e < 0 && d * 86400 != e) d--
  d += 719468; era = int(d / 146097); dd = d - era * 146097
  yoe = int((dd - int(dd / 1460) + int(dd / 36524) - int(dd / 146096)) / 365)
  y = yoe + era * 400; doy = dd - (365 * yoe + int(yoe / 4) - int(yoe / 100)); mp = int((5 * doy + 2) / 153)
  dd = doy - int((153 * mp + 2) / 5) + 1; m = mp < 10 ? mp + 3 : mp - 9; if (m <= 2) y++
  return sprintf("%04d-%02d-%02d", y, m, dd)
}
function num(s) { return s ~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/ }

function fail(id, base, fixed, loc, msg,   sev) {
  sev = scale(base, TIER, fixed)
  NF_[id]++; FL[id, NF_[id]] = sprintf("FAIL  %s  %-8s  [%s] %s  %s", id, sev, app, loc, msg)
  NFIND++; if (sev_rank(sev) >= sev_rank(threshold)) OVER = 1
}
function na(id, msg) { if (!(id in NA)) NA[id] = msg }
function pass(id, msg) { PM[id] = msg }
function load(f, A,   line, k) {   # path<TAB>value rows into A[path]
  while ((getline line < f) > 0) { k = index(line, "\t"); if (k) A[substr(line, 1, k - 1)] = substr(line, k + 1) }
  close(f)
}
function exists(f,   r, x) { if (f == "") return 0; r = (getline x < f); close(f); return r >= 0 }
# a marked table's rows: ROWS[n, col] (1-based columns after the first pipe); returns the row count
function table(f, name,   line, on, n, P, k, rows, c) {
  on = 0; rows = 0
  while ((getline line < f) > 0) {
    line = strip_cr(line)
    if (index(line, "<!-- " name ":start -->")) { on = 1; continue }
    if (index(line, "<!-- " name ":end -->")) { on = 0; continue }
    if (!on || line !~ /^[ \t]*\|/) continue
    n = split(line, P, "|")
    if (n < 3 || P[2] ~ /^[ \t:-]*$/) continue
    if (++HDR[f, name] == 1) continue   # the header row
    rows++; for (c = 2; c <= n; c++) ROWS[rows, c - 1] = cell(P[c])
    TLINE[rows] = 0
  }
  close(f)
  return rows
}

BEGIN {
  TIER = tier_of(tierfile); NFIND = 0; OVER = 0

  # AI-G1 the golden set
  split("typical edge attack regression", SL, " ")
  while ((getline g < goldenlist) > 0) {
    while ((getline line < g) > 0) {
      s = line   # a slice value is letters only, so a CR never joins it
      while (match(s, /(^|[^A-Za-z0-9_])["']?slice["']?[ \t]*:[ \t]*["']?[A-Za-z]+/)) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/^.*slice["']?[ \t]*:[ \t]*["']?/, "", t); CNT[t]++
      }
    }
    close(g)
  }
  close(goldenlist)
  vf = goldendir; sub(/\/+$/, "", vf); vf = vf "/VERSION"; gver = ""
  if ((getline gver < vf) > 0) gver = trim(strip_cr(gver)); else gver = ""
  close(vf)
  miss = ""; have = ""
  for (i = 1; i <= 4; i++) { have = have (i > 1 ? ", " : "") SL[i] " " (CNT[SL[i]] + 0); if (!CNT[SL[i]]) miss = miss ", " SL[i] }
  if (miss != "") fail("AI-G1", "High", 0, goldendir, "the golden set has " have ": every slice has a case (no " substr(miss, 3) ")")
  if (gver == "") fail("AI-G1", "High", 0, vf, "the golden set has no VERSION: the results name the version they ran on (AI-E4)")
  if (!NF_["AI-G1"]) pass("AI-G1", have "; version " gver)

  # AI-E1 the result file
  if (results == "") {
    fail("AI-E1", "High", 0, goldendir, "no eval result file given (the contract's eval_results): the operator runs the eval from a runbook, which writes it")
    E = 0
  } else if (!haveres) { fail("AI-E1", "High", 0, results, results " does not exist: the operator runs the eval from a runbook, which writes it"); E = 0 }
  else { pass("AI-E1", results " (" format ")"); E = 1 }
  if (!E) { na("AI-E2", "no eval results (AI-E1)"); na("AI-E3", "no eval results (AI-E1)"); na("AI-E4", "no eval results (AI-E1)"); na("AI-E5", "no eval results (AI-E1)") }
  else {
    load(res, J)
    if (format == "promptfoo") {
      at = J["results.timestamp"]; s_ = J["results.stats.successes"] + 0; f_ = J["results.stats.failures"] + 0; e_ = J["results.stats.errors"] + 0
      tot = s_ + f_ + e_; passed = s_; unit = " rows; errors count as failures"
      at_n = 0; at_p = 0; nv = 0
      for (k in J) {
        if (k ~ /^results\.results\[[0-9]+\]\.testCase\.metadata\.slice$/ && J[k] == "attack") {
          r = k; sub(/\.testCase\.metadata\.slice$/, "", r); at_n++; if (J[r ".success"] == "true") at_p++
        }
        if (k ~ /^results\.results\[[0-9]+\]\.testCase\.metadata\.golden_version$/) { nv++; VER[J[k]]++ }
      }
      tool = "promptfoo"
    } else {
      at = J["run_at"]; tot = J["total"] + 0; passed = J["passed"] + 0; unit = " cases"
      at_n = ("slices.attack.total" in J) ? J["slices.attack.total"] + 0 : 0; at_p = J["slices.attack.passed"] + 0
      nv = 0; if (J["dataset.version"] != "") { nv = 1; VER[J["dataset.version"]] = 1 }
      tool = J["tool"] (J["tool_version"] != "" ? " " J["tool_version"] : "")
    }
    # AI-E2 fresh
    ep = epoch(at); if (gitat != "" && gitdate == "") gitdate = utcdate(gitat + 0)
    if (ep < 0) fail("AI-E2", "High", 0, results, "the results carry no run time (" (format == "promptfoo" ? "results.timestamp" : "run_at") "): their age cannot be told")
    else {
      age = days(today) - days(utcdate(ep))
      if (age > maxage) fail("AI-E2", "High", 0, results, "the results are " age " days old (" utcdate(ep) "), more than the " maxage " allowed: run the eval again")
      if (gitat != "" && gitat + 0 > ep) fail("AI-E2", "High", 0, results, "the results (" utcdate(ep) ") are older than the last change to a prompt or the golden set (" gitdate "): run the eval again")
      if (!NF_["AI-E2"]) pass("AI-E2", "run on " utcdate(ep) ", " age " day(s) ago" (gitat != "" ? ", after the last change to a prompt or the golden set (" gitdate ")" : ""))
    }
    # AI-E3 the pass rate, then the attack slice (Critical, fixed)
    pr = (tot > 0) ? passed / tot : 0
    msg = sprintf("pass rate %.2f (%d of %d%s)", pr, passed, tot, unit)
    if (tot == 0) fail("AI-E3", "High", 0, results, "the results have no rows")
    else if (pr < rate + 0) fail("AI-E3", "High", 0, results, msg ", below the target " rate)
    if (at_n == 0) fail("AI-E3", "Critical", 1, results, "the results have no row of the attack slice: the attack slice is held to its own target (" arate ")")
    else {
      ar = at_p / at_n; amsg = sprintf("attack slice %.2f (%d of %d)", ar, at_p, at_n)
      if (ar < arate + 0) fail("AI-E3", "Critical", 1, results, amsg ", below its target " arate)
    }
    if (!NF_["AI-E3"]) pass("AI-E3", msg ", " amsg)
    # AI-E4 the golden-set version
    if (gver == "") na("AI-E4", "the golden set has no VERSION (AI-G1)")
    else if (nv == 0) fail("AI-E4", "Medium", 0, results, "the results carry no golden_version (" (format == "promptfoo" ? "defaultTest.metadata.golden_version" : "dataset.version") "): which golden set they ran on cannot be told")
    else {
      for (v in VER) if (v != gver) fail("AI-E4", "Medium", 0, results, "the results say golden set " v ", the golden set is " gver ": run the eval again on this version")
      if (!NF_["AI-E4"]) pass("AI-E4", "golden set " gver)
    }
    # AI-E5 self-reported (fixed)
    if (format == "ascent-evidence-v1") fail("AI-E5", "Low", 1, results, "self-reported by " tool " (ascent-evidence-v1): the project wrote this file, not the tool; read it as a claim")
    else pass("AI-E5", "the results are " tool "'s own output file")
  }

  # AI-R1 retrieval
  if (retr == "") na("AI-R1", "no retrieval results given")
  else if (!haveret) fail("AI-R1", "High", 0, retr, retr " does not exist: the operator runs the retrieval eval from a runbook, which writes it")
  else {
    load(ret, Q); rp = epoch(Q["run_at"]); nt = split(targets, TG, " "); rm = ""
    if (rp < 0) fail("AI-R1", "High", 0, retr, "the retrieval results carry no run_at: their age cannot be told")
    else if ((ra = days(today) - days(utcdate(rp))) > maxage) fail("AI-R1", "High", 0, retr, "the retrieval results are " ra " days old (" utcdate(rp) "), more than the " maxage " allowed")
    if (nt == 0) fail("AI-R1", "High", 0, retr, "no retrieval target given (the contract's retrieval_targets): a result with no target passes nothing")
    for (i = 1; i <= nt; i++) {
      tn = TG[i]; tv = tn; sub(/=.*$/, "", tn); sub(/^[^=]*=/, "", tv)
      if (!(("metrics." tn) in Q) || !num(Q["metrics." tn])) fail("AI-R1", "High", 0, retr, "the retrieval file has no metric " tn)
      else if (Q["metrics." tn] + 0 < tv + 0) fail("AI-R1", "High", 0, retr, tn " " Q["metrics." tn] " is below its target " tv)
      else rm = rm ", " tn " " Q["metrics." tn] " (target " tv ")"
    }
    if (!NF_["AI-R1"]) pass("AI-R1", substr(rm, 3))
  }
  # AI-R2 retrieval sources
  if (sources == "") na("AI-R2", "no retrieval sources given")
  else if (!exists(sources)) fail("AI-R2", "Medium", 0, sources, sources " does not exist: each retrieval source has an owner and a review date")
  else {
    n = table(sources, "ai-sources")
    if (n == 0) fail("AI-R2", "Medium", 0, sources, "lists no source (the ai-sources table)")
    for (i = 1; i <= n; i++) {
      src = ROWS[i, 1]; ow = ROWS[i, 2]; rb = ROWS[i, 3]
      if (ow == "") fail("AI-R2", "Medium", 0, sources, src " has no owner")
      if (!realdate(rb)) fail("AI-R2", "Medium", 0, sources, src " has no review date (YYYY-MM-DD)")
      else if (rb < today) fail("AI-R2", "Medium", 0, sources, src " was due for review on " rb)
    }
    if (!NF_["AI-R2"]) pass("AI-R2", n " source(s), each with an owner and a review date")
  }
  # AI-L1 the review date
  if (reviewby == "") na("AI-L1", "no review_by given")
  else if (reviewby < today) fail("AI-L1", "Medium", 0, goldendir, "review_by " reviewby " is past: a person looks at the application's evidence again, and sets a new date")
  else pass("AI-L1", "review by " reviewby)
  # AI-L2 the regression slice since the last review
  if (notes == "") na("AI-L2", "no review notes given")
  else if (!exists(notes)) fail("AI-L2", "Low", 0, notes, notes " does not exist")
  else {
    split("", ROWS); n = table(notes, "ai-reviews"); best = 0
    for (i = 1; i <= n; i++) if (realdate(ROWS[i, 1]) && (best == 0 || ROWS[i, 1] > ROWS[best, 1])) best = i
    reg = CNT["regression"] + 0
    if (!best) fail("AI-L2", "Low", 0, notes, "records no review (the ai-reviews table)")
    else {
      was = ROWS[best, 2] + 0; fl = tolower(ROWS[best, 3]); on = ROWS[best, 1]
      if (reg > was) pass("AI-L2", "the regression slice grew from " was " to " reg " case(s) since the review of " on)
      else if (fl == "" || fl == "0" || fl == "none" || fl == "no") pass("AI-L2", "no new failures were flagged at the review of " on)
      else fail("AI-L2", "Low", 0, notes, "the regression slice has " reg " case(s), as at the review of " on ", and that review flagged " ROWS[best, 3] " failure(s): each failure found becomes a regression case")
    }
  }

  nr = split("AI-G1 AI-E1 AI-E2 AI-E3 AI-E4 AI-E5 AI-R1 AI-R2 AI-L1 AI-L2", R, " ")
  for (i = 1; i <= nr; i++) {
    id = R[i]
    if (NF_[id]) { for (j = 1; j <= NF_[id]; j++) print FL[id, j] }
    else if (id in NA) printf "N/A   %s  [%s] %s\n", id, app, NA[id]
    else if (id in PM) printf "PASS  %s  [%s] %s\n", id, app, PM[id]
  }
  printf "check-ai-evidence: [%s] %d finding(s), tier %d\n", app, NFIND, TIER
  exit OVER
}
