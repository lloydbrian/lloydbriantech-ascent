# check-live-results.awk — the program check-live-results.sh runs. Reads the files in
# its argument list (K=<kind> before each: results, zap, nuclei, dalfox) and the
# options from CLR_* in the environment. Loaded after json.awk.
# Portable: POSIX awk (BWK, mawk, gawk).

BEGIN {
  FS = "\t"
  TGT = ENVIRON["CLR_TARGET"]; URL = ENVIRON["CLR_URL"]; TODAY = ENVIRON["CLR_TODAY"]; MAXAGE = ENVIRON["CLR_MAXAGE"] + 0
  MAT = ENVIRON["CLR_MATURITY"]; THR = ENVIRON["CLR_THRESHOLD"]; WAIVED = ENVIRON["CLR_WAIVED"]
  HASW = ENVIRON["CLR_HASW"] + 0; HASANYW = ENVIRON["CLR_HASANYW"] + 0; HASAI = ENVIRON["CLR_HASAI"] + 0; NEP = ENVIRON["CLR_NEP"] + 0; DIR = ENVIRON["CLR_DIR"]
  RANK["Low"] = 1; RANK["Medium"] = 2; RANK["High"] = 3; RANK["Critical"] = 4
  NRES = 0; NREP = 0; NREPORTS = ENVIRON["CLR_NREPORTS"] + 0
}
function where(f, l) { sub(/^\.\//, "", f); return f ":" l }
function waived(id) { return index(WAIVED, "," id ",") > 0 }
# fail RULE SEVERITY WHERE MESSAGE WAIVER-ID
function fail(k, sev, w, msg, id) {
  if (id != "" && waived(id)) { INFOS = INFOS sprintf("INFO  %-8s -      %s  %s (waived: %s)\n", "SEC-" k, w, msg, id); return }
  if (MAT == "prototype") { NOTES = NOTES sprintf("NOTE  %-8s %-6s %s  %s (prototype: not rated)\n", "SEC-" k, sev, w, msg); return }
  OUT[k] = OUT[k] sprintf("FAIL  %-8s %-6s %s  %s\n", "SEC-" k, sev, w, msg); NF_[k]++
}
function days(d,   y, m, dd) {  # days since 0000-03-01, for differences
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
}
function count(k) { CHK[k]++ }
function is2xx(s) { return s ~ /^2[0-9][0-9]$/ }

FNR == 1 { json_reset(); FILE_ = FILENAME; if (K == "results") RESFILE = FILENAME; else if (K == "zap") ZAPFILE = FILENAME }

# --- the results file -------------------------------------------------------
K == "results" && FNR == 1 && $0 != "# ascent-live-results 1" { BADRES = 1 }
K == "results" && /^# / { split(substr($0, 3), h, "\t"); H[h[1]] = h[2]; next }
K == "results" && $1 == "probe" { next }
K == "results" && NF >= 5 {
  NRES++
  pr = $1; m = $2; p = $3; s = $4; d = $5; w = where(FILENAME, FNR)
  if (d ~ /^skipped=/) { SKIP[pr] = substr(d, 9); next }
  if (s == "000" && pr != "burst") { NOANS[pr]++; NOANSW[pr] = w }
  if (pr == "headers") {
    if (s == "000") next
    count("L1"); count("L6")
    n = split(d, part, ";")
    for (i = 1; i <= n; i++) {
      if (part[i] ~ /^missing=/) {
        nm = split(substr(part[i], 9), mh, ",")
        for (j = 1; j <= nm; j++) {
          sev = (mh[j] == "referrer-policy" || mh[j] == "permissions-policy") ? "Low" : "Medium"
          fail("L1", sev, w, "missing " mh[j], "SEC-L1:" mh[j])
        }
      } else if (part[i] ~ /^banner=/) fail("L6", "Low", w, "version banner " substr(part[i], 8), "SEC-L6:banner")
    }
  } else if (pr == "verb") {
    count("L2")
    if (is2xx(s) && d ~ /echo=1/) fail("L2", "Medium", w, m " " p " answered " s " and echoed the request (cross-site tracing)", "SEC-L2:" p)
    else if (is2xx(s)) fail("L2", "Low", w, m " " p " answered " s, "SEC-L2:" p)
  } else if (pr == "traversal") {
    count("L3")
    if (d ~ /leak=1/) fail("L3", "High", w, "GET " p " returned a system file (" s ")", "SEC-L3:" p)
  } else if (pr == "disclosure" || pr == "malformed") {
    count("L6")
    if (d ~ /secret|git|env/ && is2xx(s)) {
      what = d; gsub(/,?trace/, "", what)
      fail("L6", "High", w, m " " p " served " what " content (" s ")", "SEC-L6:" p)
    }
    if (d ~ /trace/) fail("L6", "Medium", w, m " " p " answered " s " with a stack trace", "SEC-L6:" p)
  } else if (pr == "unauth-write") {
    count("L4")
    if (is2xx(s)) fail("L4", "High", w, m " " p " answered " s " without sign-in", "SEC-L4:" p)
  } else if (pr == "oversize") {
    count("L5")
    if (is2xx(s) || s ~ /^5/ || s == "000") fail("L5", "Medium", w, m " " p " answered " (s == "000" ? "nothing" : s) " to a body over the limit; expected 413 or 400", "SEC-L5:" p)
  } else if (pr == "canary") {
    count("L7")
    if (d ~ /canary=1/) fail("L7", "High", w, m " " p " followed an injected instruction (canary answered)", "SEC-L7:" p)
  } else if (pr == "burst") {
    count("L8")
    nb = split(d, bk, ";"); acc = 0; lim = 0; gate = 0; err = 0; tot = 0
    for (i = 1; i <= nb; i++) {
      split(bk[i], kv, "="); c = kv[2] + 0; tot += c
      if (kv[1] == "429") lim += c
      else if (kv[1] == "401" || kv[1] == "403") gate += c
      else if (kv[1] ~ /^5/ || kv[1] == "000") err += c
      else if (kv[1] ~ /^2/) acc += c
    }
    if (err > 0) fail("L8", "Medium", w, m " " p ": " err " of " tot " burst requests failed (" d ")", "SEC-L8:" p)
    else if (lim == 0 && gate < tot) fail("L8", "Medium", w, m " " p ": " tot " requests in a burst, none rate-limited (" d ")", "SEC-L8:" p)
  }
  next
}

# --- ZAP JSON ---------------------------------------------------------------
K == "zap" || K == "nuclei" || K == "dalfox" { line = $0; sub(/\r$/, "", line); if (K != "zap") json_reset(); NUCLINE = FNR; json_feed(line, FNR); if (K == "nuclei") nuc_flush(); else if (K == "dalfox") dal_flush(); next }
function clip(s) { gsub(/[^ -~]/, "", s); gsub(/:\/\/[^\/@ ]+@/, "://***@", s); return length(s) > 120 ? substr(s, 1, 117) "..." : s }
function on_json(p, v, l,   n, a, key) {
  if (K == "zap") {
    n = split(p, a, "\034")
    if (n >= 5 && a[1] == "site" && a[3] == "alerts") {
      key = a[2] SUBSEP a[4]
      if (!(key in ZL)) { ZL[key] = l; ZORD[++NZ] = key }
      if (a[5] == "pluginid") ZID[key] = v
      else if (a[5] == "riskcode") ZRISK[key] = v
      else if (a[5] == "name" || a[5] == "alert") { if (ZNAME[key] == "") ZNAME[key] = v }
      else if (n >= 7 && a[5] == "instances" && a[7] == "uri") ZN[key]++
    }
    ZAPSEEN = 1
  } else if (K == "nuclei") {
    if (p == "template-id") NUC["id"] = v
    else if (p == "info\034severity") NUC["sev"] = v
    else if (p == "info\034name") NUC["name"] = v
    else if (p == "matched-at") NUC["at"] = v
  } else if (K == "dalfox") {
    if (p == "type" || p == "severity" || p == "param" || p == "data" || p == "inject_type") DAL[p] = v
  }
}
function nuc_flush(   s, sev) {
  NUCSEEN = 1
  if (NUC["id"] == "") { split("", NUC); return }
  s = tolower(NUC["sev"])
  sev = (s == "critical") ? "Critical" : (s == "high") ? "High" : (s == "medium") ? "Medium" : (s == "low") ? "Low" : (s == "info") ? "" : "Medium"
  if (sev != "") rep("nuclei", sev, where(FILE_, NUCLINE), "nuclei " NUC["id"] " (" s "): " clip(NUC["name"]) " at " clip(NUC["at"]), NUC["id"])
  split("", NUC)
}
function dal_flush(   t, s, sev) {  # one dalfox v3 JSONL line; the meta line has no type
  DALSEEN = 1
  t = DAL["type"]; s = tolower(DAL["severity"])
  if (t == "" || t == "I") { split("", DAL); return }
  sev = (t == "V") ? "High" : (s == "high") ? "High" : (s == "medium") ? "Medium" : (s == "low") ? "Low" : "Medium"
  rep("dalfox", sev, where(FILE_, NUCLINE), "dalfox " t " (" (t == "V" ? "verified" : t == "A" ? "found in the code" : "reflected") ") " DAL["inject_type"] " in " DAL["param"] ": " clip(DAL["data"]), "dalfox:" DAL["param"])
  split("", DAL)
}
# rep SCANNER SEVERITY WHERE MESSAGE ID — a scanner finding, against the threshold
function rep(sc, sev, w, msg, id,   rated) {
  NREP++; count("L9")
  if (RANK[sev] < RANK[THR]) { BELOW[sc]++; return }
  rated = (sev == "Critical") ? "High" : sev
  fail("L9", rated, w, msg, id)
}

END {
  for (j = 1; j <= NZ; j++) {
    key = ZORD[j]; r = ZRISK[key] + 0
    if (r == 0) continue
    sev = (r == 3) ? "High" : (r == 2) ? "Medium" : "Low"
    rep("zap", sev, where(ZAPFILE, ZL[key]), "ZAP " ZID[key] " " clip(ZNAME[key]) " (" (ZN[key] + 0) " instance(s))", ZID[key])
  }
  # SEC-L10: are there results, fresh, for this target, with every probe measured?
  if (NRES == 0 && !BADRES) {
    fail("L10", "Low", (DIR == "" ? "-" : DIR) ":absent", "no results file for target " TGT ": the live checks are unmeasured", "SEC-L10:absent")
    NOTRES = 1
  } else {
    count("L10")
    rf = where(RESFILE, 1)
    if (BADRES) fail("L10", "Low", rf, "not a results file of run-live-checks.sh (first line is not \"# ascent-live-results 1\")", "")
    if (H["target"] != TGT) fail("L10", "Low", rf, "results are for target \"" H["target"] "\", not " TGT, "")
    if (H["url"] != URL) fail("L10", "Low", rf, "results are for " H["url"] ", not " URL, "")
    if (H["date"] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) fail("L10", "Low", rf, "results have no date", "")
    else {
      age = days(TODAY) - days(H["date"])
      if (age > MAXAGE) fail("L10", "Low", rf, "results are " age " days old (max " MAXAGE ")", "")
      else if (age < 0) fail("L10", "Low", rf, "results are dated " H["date"] ", after today", "")
    }
    if (HASW && ("unauth-write" in SKIP)) fail("L10", "Low", rf, "unauth-write, oversize and malformed were skipped (" SKIP["unauth-write"] "): SEC-L4 and SEC-L5 are unmeasured", "SEC-L10:writes")
    else if (HASANYW && ("oversize" in SKIP) && SKIP["oversize"] ~ /allow-writes/) fail("L10", "Low", rf, "oversize and malformed were skipped (" SKIP["oversize"] "): SEC-L5 is unmeasured", "SEC-L10:writes")
    if (HASAI && ("canary" in SKIP)) fail("L10", "Low", rf, "canary and burst were skipped (" SKIP["canary"] "): SEC-L7 and SEC-L8 are unmeasured", "SEC-L10:ai")
    if ("headers" in NOANS) fail("L10", "Low", NOANSW["headers"], "the target did not answer: SEC-L1 is unmeasured", "")
  }
  D["L1"] = "security headers"; D["L2"] = "TRACE and CONNECT refused"; D["L3"] = "no path traversal"
  D["L4"] = "writes need sign-in"; D["L5"] = "oversized bodies refused"; D["L6"] = "no secret, stack trace or banner served"
  D["L7"] = "AI endpoints ignore injected instructions"; D["L8"] = "AI bursts gated or rate-limited"
  D["L9"] = "scanner reports"; D["L10"] = "results present, fresh and complete"
  NA_["L4"] = HASW ? "unmeasured: skipped" : "no write endpoint that requires sign-in"
  NA_["L5"] = HASANYW ? "unmeasured: skipped" : "no write endpoint"
  NA_["L7"] = HASAI ? "unmeasured: skipped" : "no ai endpoint"; NA_["L8"] = NA_["L7"]
  NA_["L9"] = "no --zap, --nuclei or --dalfox report"
  if (NREPORTS > 0 && !CHK["L9"]) CHK["L9"] = 0.5
  NFAIL = 0
  for (j = 1; j <= 10; j++) {
    k = "L" j
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-8s %s (%s)\n", "SEC-" k, D[k], (CHK[k] < 1 ? "no finding" : int(CHK[k]) " checked")
    else printf "N/A   %-8s %s (%s)\n", "SEC-" k, D[k], (NOTRES && k != "L9" ? "unmeasured: no results" : (k in NA_ ? NA_[k] : "nothing to check"))
  }
  for (sc in BELOW) NOTES = NOTES sprintf("NOTE  SEC-L9   -      %s: %d finding(s) below the %s threshold, not rated\n", sc, BELOW[sc], THR)
  printf "%s%s", NOTES, INFOS
  printf "check-live-results: target %s, %d result(s), %d scanner finding(s), %d failure(s); results show what the target answered when the checks ran, not that it is unchanged since\n", TGT, NRES, NREP, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
