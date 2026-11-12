# check-test-evidence.awk — the checks of check-test-evidence.sh, which passes the file
# list and the ENVIRON values (QA_P95, QA_RPS, QA_MIN, QA_MAXAGE, QA_TODAY,
# QA_MATURITY, QA_RDATES, QA_PATHS). Loaded after qa-common.awk. A separate file keeps
# bash 3.2 from parsing the program. Run with LC_ALL=C. No regex intervals: some awks
# lack them.
BEGIN {
  P95 = ENVIRON["QA_P95"]; RPS = ENVIRON["QA_RPS"]; MIN = ENVIRON["QA_MIN"] + 0
  MAXAGE = ENVIRON["QA_MAXAGE"] + 0; TODAY = ENVIRON["QA_TODAY"]; MAT = ENVIRON["QA_MATURITY"]
  # Which rules the maturity target requires.
  split("L1 L2 L3 L4 L5 M1 M2 M3 M4", ORDER, " ")
  for (i = 1; i <= 9; i++) { k = ORDER[i]; REQ[k] = (MAT == "enterprise") || (MAT == "standard" && (k == "L1" || k == "L2" || k == "M1")) }
  # Report dates from git (check-test-evidence.sh), one "file<TAB>date" per line.
  n = split(ENVIRON["QA_RDATES"], L, "\n")
  for (i = 1; i <= n; i++) if (L[i] != "") { split(L[i], F, "\t"); RDATE[F[1]] = F[2] }
  NTOOL = 0; NREP = 0; LUSERS = 0; SR = -1; SHALLOW = (ENVIRON["QA_SHALLOW"] == 1)
}
function isdate(d,   y, m, dd) {   # YYYY-MM-DD and a real calendar day
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m < 1 || m > 12 || dd < 1) return 0
  if (m == 2) return dd <= 28 + ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)
  return dd <= ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
}
function days(d,   y, m, dd, a, yy, mm) {   # days since 1970-01-01 (civil calendar)
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  a = (m <= 2) ? 1 : 0; yy = y - a; mm = m + 12 * a - 3
  return 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + int((153 * mm + 2) / 5) + dd - 719469
}
# num LINE REGEX — the number at the end of the first match of REGEX in LINE, or -1.
# REGEX is a string: a /regex/ argument would be matched against $0 instead.
function num(s, re,   m) {
  if (!match(s, re)) return -1
  m = substr(s, RSTART, RLENGTH); sub(/^.*[^0-9.]/, "", m)
  return (m ~ /^[0-9]+(\.[0-9]+)?$/) ? m + 0 : -1
}
# tool NAME — records a mutation tool at the current line, once.
function tool(t) { if (!(t in TOOLAT)) { NTOOL++; TL[NTOOL] = t; TOOLAT[t] = at() } }
function brk(t, v) { if (v >= 0 && !(t in MBRK)) { MBRK[t] = v; MBRKAT[t] = at() } }
# maxnum LINE REGEX — the largest number ending a match of REGEX in LINE, or -1.
function maxnum(s, re,   v, b) {
  b = -1
  while ((v = num(s, re)) >= 0) { if (v > b) b = v; s = substr(s, RSTART + RLENGTH) }
  return b
}
# runs LINE CI — a line that runs a load test (any CI step, make recipe, package script
# or runbook line) or a mutation tool (a CI step only, CI set). Installing a tool is
# not running it, and locust counts only as a command (followed by an option).
function runs(s, ci) {
  s = noinstall(s)
  if (s ~ /(^|[^A-Za-z0-9_-])(k6[ \t]+(run|cloud)|artillery[ \t]+run|locust([ \t]+-|[ \t]*$|[ \t]*[;&|]))|grafana\/(run-k6-action|k6-action)/) LRUN = 1
  if (ci && s ~ /stryker[ \t]+run|mutmut[ \t]+run|pitest|mutationCoverage|go-mutesting|gremlins[ \t]+unleash/) MRUN = 1
}
# cmdtools LINE — mutation tools run from a command line, not a configuration file.
function cmdtools(s) {
  s = noinstall(s)
  if (s ~ /go-mutesting/) tool("go-mutesting")
  if (s ~ /gremlins[ \t]+unleash/) { tool("gremlins"); brk("gremlins", num(s, "--threshold-efficacy[ =]+[0-9.]+")) }
  if (s ~ /mutmut[ \t]+run/) tool("mutmut")
}
# users LINE — a Locust user count: -u N, --users N or --users=N after the last
# "locust" on a command (so docker run -u UID is not read), or users = N in locust.conf.
function users(s,   v, i, j) {
  v = -1
  if (i = index(s, "locust")) { while ((j = index(substr(s, i + 1), "locust")) > 0) i += j; v = num(substr(s, i), "(^|[ \\t])(-u|--users)[ =]+[0-9]+") }
  if (FN ~ /(^|\/)locust\.conf$/) v = num(s, "^[ \\t]*users[ \\t]*=[ \\t]*[0-9]+")
  if (v > LUSERS) LUSERS = v
}
# k6th SEGMENT — a part of the threshold array of metric THM.
function k6th(seg,   base, v) {
  base = THM; sub(/\{.*$/, "", base)
  while (base == "http_req_duration" && (v = num(seg, "p\\(95\\)[ \\t]*<=?[ \\t]*[0-9.]+")) >= 0) {
    seg = substr(seg, RSTART + RLENGTH)
    if (THM ~ /\{/) { if (!(FN in K6TAG) || v > K6TAG[FN]) { K6TAG[FN] = v; K6TAGAT[FN] = at() } }
    else if (!(FN in K6ALL) || v < K6ALL[FN]) { K6ALL[FN] = v; K6ALLAT[FN] = at() }
  }
  if ((base == "http_req_failed" && seg ~ /rate[ \t]*<=?/) || (base == "checks" && seg ~ /rate[ \t]*>=?/)) ERR[FN] = 1
}
# k6scen LINE — a line of one k6 scenario: its executor, its rates (rate, startRate,
# stage targets) and its timeUnit, read together.
function k6scen(s,   u, q, v) {
  if (match(s, /executor[ \t]*:[ \t]*["'][A-Za-z-]+["']/)) { u = substr(s, RSTART, RLENGTH); sub(/^[^"']*["']/, "", u); sub(/["']$/, "", u); SEX = u }
  if ((v = maxnum(s, "(^|[^A-Za-z0-9_])(rate|startRate|target)[ \\t]*:[ \\t]*[0-9]+")) > SR) { SR = v; SRAT = at() }
  if (match(s, /timeUnit[ \t]*:[ \t]*["'][0-9.]*(ms|s|m|h)["']/)) {
    u = substr(s, RSTART, RLENGTH); sub(/^[^"']*["']/, "", u); sub(/["']$/, "", u)
    q = u; sub(/^[0-9.]*/, "", q); sub(/[a-z]+$/, "", u); u = (u == "") ? 1 : u + 0
    STU = u * (q == "ms" ? 0.001 : q == "h" ? 3600 : q == "m" ? 60 : 1)
  }
}
# k6end — closes the current scenario: an arrival-rate executor gives a rate per second.
function k6end(   r) {
  if (SCN && SEX ~ /arrival-rate/ && SR >= 0) {
    K6AR[FN] = 1; r = SR / (STU > 0 ? STU : 1)
    if (!(FN in K6R) || r > K6R[FN]) { K6R[FN] = r; K6RAT[FN] = SRAT }
  }
  SCN = 0; SEX = ""; SR = -1; SRAT = ""; STU = 0
}
function newfile() {
  k6end()
  FN = FILENAME; sub(/^\.\//, "", FN); LG = lang(FN); KN[K]++; INSCR = 0; MT = ""; INTH = 0; THM = ""
  INBC = 0; INXC = 0; INSC = 0; DEP = 0
}
FNR == 1 { newfile() }
{ raw = $0; sub(/\r$/, "", raw); t = trim(raw) }
# --- load tests ---------------------------------------------------------------
(K == "s" || K == "t" || K == "td") && LG == "js" {
  # Block comments are dropped; a line that is only a comment is skipped.
  s = raw
  if (INBC) { e = index(s, "*/"); if (!e) next; s = substr(s, e + 2); INBC = 0 }
  while ((b = index(s, "/*")) > 0) {
    e = index(substr(s, b + 2), "*/")
    if (!e) { s = substr(s, 1, b - 1); INBC = 1; break }
    s = substr(s, 1, b - 1) " " substr(s, b + e + 3)
  }
  t = trim(s)
  if (t == "" || t ~ /^(\/\/|\*)/) next
  if (s ~ /from[ \t]+["']k6(\/[A-Za-z0-9\/_-]*)?["']|require\(["']k6(\/[A-Za-z0-9\/_-]*)?["']\)|^import[ \t]+["']k6/) K6[FN] = 1
  # Thresholds: each metric (with an optional {tag}) and its array, several on a line
  # or one over several lines.
  x = s
  while (1) {
    if (INTH) {
      e = index(x, "]")
      k6th(e ? substr(x, 1, e - 1) : x)
      if (!e) break
      INTH = 0; x = substr(x, e + 1)
    }
    if (!match(x, /["']?[A-Za-z_][A-Za-z0-9_]*(\{[^}]*\})?["']?[ \t]*:[ \t]*\[/)) break
    THM = substr(x, RSTART, RLENGTH); sub(/["']?[ \t]*:[ \t]*\[$/, "", THM); sub(/^["']/, "", THM)
    x = substr(x, RSTART + RLENGTH); INTH = 1
  }
  # Scenarios: each object directly inside scenarios: { } is one scenario.
  x = s; ob = gsub(/\{/, "", x); x = s; cb = gsub(/\}/, "", x)
  if (!INSC && s ~ /(^|[^A-Za-z0-9_])scenarios[ \t]*:/) { INSC = 1; SCB = DEP }
  else if (INSC && DEP == SCB + 1 && ob > 0) { k6end(); SCN = 1 }
  if (SCN) k6scen(s)
  DEP += ob - cb
  if (INSC && DEP <= SCB + 1) k6end()
  if (INSC && DEP <= SCB) INSC = 0
  next
}
(K == "s" || K == "t" || K == "td") && LG == "py" {
  if (t ~ /^#/) next
  if (raw ~ /^[ \t]*(from[ \t]+locust([ \t.]|$)|import[ \t]+locust)/) LOC[FN] = 1
  if ((v = num(raw, "get_response_time_percentile\\([ \\t]*0?\\.95[ \\t]*\\)[ \\t]*>=?[ \\t]*[0-9.]+")) >= 0 && (!(FN in LP95) || v < LP95[FN])) { LP95[FN] = v; LP95AT[FN] = at() }
  if (raw ~ /fail_ratio[ \t]*>|num_failures[ \t]*>/) ERR[FN] = 1
  if ((v = num(raw, "constant_throughput\\([ \\t]*[0-9.]+")) > 0) { LTP[FN] = v; LTPAT[FN] = at() }
  else if ((v = num(raw, "constant_pacing\\([ \\t]*[0-9.]+")) > 0) { LTP[FN] = 1 / v; LTPAT[FN] = at() }
  next
}
K == "yml" {
  if (t ~ /^#/) next
  if (raw ~ /^config:/) ACFG[FN] = 1
  if (raw ~ /^scenarios:/) ASCN[FN] = 1
  if ((v = num(raw, "(arrivalRate|rampTo)[ \\t]*:[ \\t]*[0-9.]+")) > (FN in AR ? AR[FN] : -1)) { AR[FN] = v; ARAT[FN] = at() }
  if ((v = num(raw, "(^|[^A-Za-z0-9_])p95[\"']?[ \\t]*(:|<=?)[ \\t]*[0-9.]+")) >= 0 && (!(FN in AP95) || v < AP95[FN])) { AP95[FN] = v; AP95AT[FN] = at() }
  if (raw ~ /maxErrorRate[ \t]*:|(^|[ \t"'(-])(vusers\.failed|errors\.[A-Za-z0-9_.]+)["']?[ \t]*(:|<|>|==|!=)/) ERR[FN] = 1
  next
}
# --- mutation tools -------------------------------------------------------------
K == "mut" {
  # Comments are skipped: a commented-out threshold is not a threshold.
  s = raw
  if (INXC) { e = index(s, "-->"); if (!e) next; s = substr(s, e + 3); INXC = 0 }
  while ((b = index(s, "<!--")) > 0) {
    e = index(substr(s, b + 4), "-->")
    if (!e) { s = substr(s, 1, b - 1); INXC = 1; break }
    s = substr(s, 1, b - 1) " " substr(s, b + e + 6)
  }
  t = trim(s)
  if (t ~ /^(\/\/|#|\*|\/\*)/) next
  b = FN; sub(/^.*\//, "", b)
  if (b ~ /stryker/) { tool("stryker"); brk("stryker", num(s, "(^|[^A-Za-z0-9_])[\"']?break[\"']?[ \\t]*:[ \\t]*[0-9]+")) }
  else if (b == "pom.xml") { if (s ~ /pitest-maven/) tool("pit"); brk("pit", num(s, "<mutationThreshold>[ \\t]*[0-9]+")) }
  else if (b ~ /^build\.gradle/) { if (s ~ /pitest/) tool("pit"); brk("pit", num(s, "mutationThreshold[ \\t]*(=|\\.set\\()[ \\t]*[0-9]+")) }
  else if (b ~ /gremlins/) { tool("gremlins"); brk("gremlins", num(s, "efficacy[ \\t]*:[ \\t]*[0-9.]+")) }
  next
}
K == "cfg" {
  if (raw ~ /^\[(tool\.)?mutmut\]/) tool("mutmut")
  users(raw)
  next
}
K == "pkg" {
  if (raw ~ /"@stryker-mutator\/core"/) tool("stryker")
  pkgline(raw)
  next
}
K == "make" { makeline(raw); if (raw ~ /^\t/) { runs(raw, 0); users(raw); cmdtools(raw) }; next }
K == "ci" {
  if (t ~ /^#/ || t ~ /^-?[ \t]*(name|description)[ \t]*:/) next
  NCI++; CIL[NCI] = t; users(t); cmdtools(t)
  next
}
K == "doc" { runs(raw, 0); users(raw); next }
# --- mutation reports -------------------------------------------------------------
K == "mrep" {
  if (FNR == 1) { NREP++; RF[NREP] = FN }
  # Stryker's mutation.json and PIT's mutations.xml: count mutants by status (gsub
  # counts in one pass, so a minified report on one line is not read quadratically).
  s = raw; DET[FN] += gsub(/"status"[ \t]*:[ \t]*"(Killed|Timeout)"/, "", s)
  s = raw; UND[FN] += gsub(/"status"[ \t]*:[ \t]*"(Survived|NoCoverage)"/, "", s)
  s = raw; DET[FN] += gsub(/status=["'](KILLED|TIMED_OUT|MEMORY_ERROR|RUN_ERROR)["']/, "", s)
  s = raw; UND[FN] += gsub(/status=["'](SURVIVED|NO_COVERAGE)["']/, "", s)
  # A text summary: "mutation score: 72.5%", go-mutesting's "The mutation score is
  # 0.725000", gremlins' "Test efficacy: 85.00%". A line that states a target
  # ("minimum mutation score: 80%") is not the score.
  l = tolower(raw)
  if (!(FN in TSC) && l !~ /minimum|min[_ -]|threshold|target|required|at least|break/) {
    if (match(l, /(mutation score|test efficacy)[^0-9]*[0-9]+(\.[0-9]+)?%?/)) {
      m = substr(l, RSTART, RLENGTH); pct = (m ~ /%$/); sub(/%$/, "", m); sub(/^.*[^0-9.]/, "", m)
      v = m + 0; if (!pct && v <= 1 && m ~ /\./) v = v * 100
      TSC[FN] = v; TSCAT[FN] = at()
    }
  }
  next
}
END {
  k6end()
  for (j = 1; j <= NCI; j++) runs(expand(CIL[j], 0), 1)
  for (nm in SCR) runs(SCR[nm], 0)
  where = "absent: searched " ENVIRON["QA_PATHS"]
  # The load-test scripts, by tool.
  NL = 0
  for (f in K6) if (K6[f]) { NL++; LF[NL] = f; LT[f] = "k6"; NK["k6"]++ }
  for (f in ACFG) if (f in ASCN) { NL++; LF[NL] = f; LT[f] = "Artillery"; NK["Artillery"]++ }
  for (f in LOC) { NL++; LF[NL] = f; LT[f] = "Locust"; NK["Locust"]++ }
  # Sorted, so the first script named in a message is the same on every awk.
  for (i = 2; i <= NL; i++) { x = LF[i]; for (j = i - 1; j >= 1 && LF[j] > x; j--) LF[j + 1] = LF[j]; LF[j + 1] = x }
  targets = (P95 != "" ? "p95_latency_ms " P95 : "") (P95 != "" && RPS != "" ? " and " : "") (RPS != "" ? "peak_rps " RPS : "")
  # QA-L1 — a load test exists when there is a target
  if (targets != "") { CHK["L1"]++; if (NL == 0) fail("L1", "Medium", where, "no load-test script (k6, Artillery or Locust), and the contract sets " targets) }
  # QA-L2 — the p95 threshold is no looser than the target
  if (P95 != "" && NL > 0) {
    CHK["L2"]++; best = -1; bat = ""
    for (i = 1; i <= NL; i++) {
      f = LF[i]; v = -1; a = ""
      if (LT[f] == "k6") { if (f in K6ALL) { v = K6ALL[f]; a = K6ALLAT[f] } else if (f in K6TAG) { v = K6TAG[f]; a = K6TAGAT[f] } }
      else if (LT[f] == "Artillery" && (f in AP95)) { v = AP95[f]; a = AP95AT[f] }
      else if (LT[f] == "Locust" && (f in LP95)) { v = LP95[f]; a = LP95AT[f] }
      if (v >= 0 && (best < 0 || v < best)) { best = v; bat = a }
    }
    if (best < 0) fail("L2", "Medium", LF[1] ":1", "no load test sets a p95 latency threshold, so a slow run passes (target p95_latency_ms " P95 ")")
    else if (best > P95 + 0) fail("L2", "Medium", bat, "the tightest p95 threshold is " best " ms, looser than p95_latency_ms " P95)
  }
  # QA-L3 — the load reaches the target rate
  if (RPS != "" && NL > 0) {
    best = -1; bat = ""
    for (i = 1; i <= NL; i++) {
      f = LF[i]; v = -1; a = ""
      if (LT[f] == "k6" && (f in K6AR) && (f in K6R)) { v = K6R[f]; a = K6RAT[f] }
      else if (LT[f] == "Artillery" && (f in AR)) { v = AR[f]; a = ARAT[f] }
      else if (LT[f] == "Locust" && (f in LTP) && LUSERS > 0) { v = LTP[f] * LUSERS; a = LTPAT[f] }
      if (v >= 0 && v > best) { best = v; bat = a }
    }
    if (best < 0) note("L3", LF[1] ":1", "no load test sets a request rate the check can read (virtual users, or a rate set at runtime); read the scripts against peak_rps " RPS)
    else { CHK["L3"]++; if (best < RPS + 0) fail("L3", "Medium", bat, "the highest request rate is " best "/s, below peak_rps " RPS) }
  }
  # QA-L4 — an error-rate threshold
  if (NL > 0) {
    CHK["L4"]++; got = 0
    for (i = 1; i <= NL; i++) if (LF[i] in ERR) got = 1
    if (!got) fail("L4", "Low", LF[1] ":1", "no load test sets an error-rate threshold, so a run full of errors passes")
  }
  # QA-L5 — something runs the load test
  if (NL > 0) { CHK["L5"]++; if (!LRUN) fail("L5", "Low", LF[1] ":1", "no CI step, make target or runbook runs the load test (k6 run, artillery run, locust)") }
  # QA-M1 — a mutation tool is configured
  if (KN["s"] + KN["t"] + KN["td"] + KN["mut"] + NTOOL > 0) { CHK["M1"]++; if (NTOOL == 0) fail("M1", "Medium", where, "no mutation tool configured (Stryker, mutmut, PIT, go-mutesting or gremlins), so nothing shows the tests fail when the code is broken") }
  # QA-M2 — the break threshold
  for (i = 1; i <= NTOOL; i++) {
    tl = TL[i]
    if (tl == "mutmut" || tl == "go-mutesting") { note("M2", TOOLAT[tl], tl " has no break threshold; the report's score (QA-M4) is the evidence"); continue }
    CHK["M2"]++
    if (!(tl in MBRK)) fail("M2", "Medium", TOOLAT[tl], tl ": no break threshold, so the mutation run passes at any score (min_score " MIN ")")
    else if (MBRK[tl] < MIN) fail("M2", "Medium", MBRKAT[tl], tl ": the break threshold " MBRK[tl] " is below min_score " MIN)
  }
  # QA-M3 — CI runs the mutation tool
  if (NTOOL > 0) { CHK["M3"]++; if (!MRUN) fail("M3", "Low", TOOLAT[TL[1]], "no CI step runs the mutation tool (" TL[1] ")") }
  # QA-M4 — a committed, current report at min_score
  if (NTOOL > 0 || NREP > 0) {
    CHK["M4"]++; nb = 0; np = 0
    for (i = 1; i <= NREP; i++) {
      f = RF[i]; d = ""
      s = f; while (match(s, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { c = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH); if (isdate(c)) d = c }
      if (d == "" && isdate(RDATE[f])) d = RDATE[f]
      if (DET[f] + UND[f] > 0) sc = int(1000 * DET[f] / (DET[f] + UND[f]) + 0.5) / 10
      else if (f in TSC) sc = TSC[f]
      else { np++; PW[np] = f ":1"; PM[np] = "no mutation score can be read from this report"; continue }
      if (d == "") { np++; PW[np] = f ":1"; PM[np] = "the report has no date (none in its path, and " (SHALLOW ? "the clone is shallow, so no commit dates it" : "it is not committed") ")"; continue }
      if (d > TODAY) { np++; PW[np] = f ":1"; PM[np] = "the report is dated " d ", after today"; continue }
      if (!nb || d > BD) { nb = i; BD = d; BS = sc }
    }
    # A report that cannot be used fails only when no usable report is left; beside
    # a usable one (a local run, a stray summary) it is a NOTE.
    for (i = 1; i <= np; i++) {
      if (nb) note("M4", PW[i], PM[i] "; not counted")
      else fail("M4", "Medium", PW[i], PM[i])
    }
    if (NREP == 0) fail("M4", "Medium", where, "no mutation report in the repository (mutation.json, mutations.xml or a score summary), so the score is not known")
    else if (nb) {
      f = RF[nb]
      if (days(TODAY) - days(BD) > MAXAGE) fail("M4", "Medium", f ":1", "the newest report, " BD ", is " days(TODAY) - days(BD) " days old (max_age_days " MAXAGE ")")
      else if (BS < MIN) fail("M4", "Medium", f ":1", "the newest report scores " BS "%, below min_score " MIN)
    }
  }
  D["L1"] = "a load test exists for the latency and throughput targets"
  D["L2"] = "a p95 threshold no looser than p95_latency_ms"
  D["L3"] = "a load that reaches peak_rps"
  D["L4"] = "a load test sets an error-rate threshold"
  D["L5"] = "something runs the load test"
  D["M1"] = "a mutation tool is configured"
  D["M2"] = "the break threshold is at least min_score"
  D["M3"] = "CI runs the mutation tool"
  D["M4"] = "a current report scores at least min_score"
  NA_["L1"] = "no p95_latency_ms or peak_rps target given"
  NA_["L2"] = (P95 == "") ? "no p95_latency_ms target given" : "no load test"
  NA_["L3"] = (RPS == "") ? "no peak_rps target given" : (NL == 0 ? "no load test" : "no request rate readable; see NOTE")
  NA_["L4"] = "no load test"; NA_["L5"] = "no load test"
  NA_["M1"] = "no source or test files"; NA_["M2"] = "no tool with a break threshold"; NA_["M3"] = "no mutation tool"; NA_["M4"] = "no mutation tool and no report"
  NFAIL = 0
  for (j = 1; j <= 9; j++) {
    k = ORDER[j]
    if (!REQ[k]) { printf "N/A   %-7s %s (not required at %s)\n", "QA-" k, D[k], MAT; continue }
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "QA-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "QA-" k, D[k], NA_[k]
  }
  printf "%s", NOTES
  printf "check-test-evidence: %d load script(s) (k6 %d, Artillery %d, Locust %d), %d mutation tool(s), %d report(s), %d failure(s)\n", \
    NL, NK["k6"], NK["Artillery"], NK["Locust"], NTOOL, NREP, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
