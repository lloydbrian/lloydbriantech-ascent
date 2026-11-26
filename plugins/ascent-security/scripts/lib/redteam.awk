# redteam.awk — SEC-R1 to SEC-R3 for check-redteam.sh. Reads no main input:
# everything runs in BEGIN, from the variables the script passes (app, maxage,
# maxrate, tierfile, threshold, today, res, runs, kind, at, file, flat, hitfile,
# hits, waivers: a file, one --waiver to a line) and the flattened files (json-flat.awk's path<TAB>value rows).
#
# The severity scaling is ascent-ai's (scripts/lib/common.awk), written again here
# because plugins never call across; test-check-redteam.sh pins that both give the
# same severity for the same tier records.
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function strip_cr(s) { sub(/\r$/, "", s); return s }
function sev_rank(s) { return s == "Critical" ? 4 : (s == "High" ? 3 : (s == "Medium" ? 2 : (s == "Low" ? 1 : 0))) }
function sev_name(r) { return r >= 4 ? "Critical" : (r == 3 ? "High" : (r == 2 ? "Medium" : "Low")) }
function scale(base, tier, fixed,   r) {
  r = sev_rank(base)
  if (fixed || tier >= 3) return base
  r -= (3 - tier)
  return sev_name(r)
}
function tier_of(f,   line, on, n, P, k, v, t) {
  t = 3
  if (f == "") return t
  on = 0
  while ((getline line < f) > 0) {
    line = strip_cr(line)
    if (index(line, "<!-- ai-tier:start -->")) { on = 1; continue }
    if (index(line, "<!-- ai-tier:end -->")) { on = 0; continue }
    if (!on || line !~ /^[ \t]*\|/) continue
    n = split(line, P, "|")
    if (n < 3) continue
    k = P[2]; gsub(/[ \t`]/, "", k); v = P[3]; gsub(/[ \t`]/, "", v)
    if (tolower(k) == "tier" && (v == "1" || v == "2" || v == "3")) t = v + 0
  }
  close(f)
  return t
}
function days(s,   y, m, d) {   # days since 1970-01-01 of a YYYY-MM-DD date
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d - 719469
}
# prompt injection and data leaks: Critical at every tier
function critical(cat) {
  if (cat ~ /^(promptinject|latentinjection|dan|leakreplay|xss)$/) return 1
  if (cat == "indirect-prompt-injection" || cat == "pii" || cat ~ /^pii:/) return 1
  return 0
}
function base_of(cat) { return critical(cat) ? "Critical" : "High" }
function fail(id, base, fixed, loc, msg,   sev) {
  sev = scale(base, TIER, fixed)
  NF_[id]++; FL[id, NF_[id]] = sprintf("FAIL  %s  %-8s  [%s] %s  %s", id, sev, app, loc, msg)
  NFIND++; if (sev_rank(sev) >= sev_rank(threshold)) OVER = 1
}
function info(id, msg) { NI_[id]++; IL[id, NI_[id]] = sprintf("INFO  %s  [%s] %s", id, app, msg) }
function load(f, A,   line, k) {
  while ((getline line < f) > 0) { k = index(line, "\t"); if (k) A[substr(line, 1, k - 1)] = substr(line, k + 1) }
  close(f)
}
# the waiver that accepts hit id h: 1 current (WBY is its ADR), 2 expired or
# without a review date (WWHY says which), 0 none
function waived(h,   i, j, m, F, best) {
  best = 0; WBY = ""; WWHY = ""
  if (!WREAD) { WREAD = 1; while ((getline line < waivers) > 0) W[++NW] = line; close(waivers) }
  for (i = 1; i <= NW; i++) {
    if (split(W[i], F, " ") != 3 || F[3] == "-") continue
    m = split(F[3], ID, ",")
    for (j = 1; j <= m; j++) if (ID[j] == h) {
      if (F[2] != "-" && F[2] >= today) { WBY = F[1]; return 1 }
      if (!best) { best = 2; WBY = F[1]; WWHY = (F[2] == "-" ? F[1] " has no review date" : F[1] "'s review date " F[2] " has passed") }
    }
  }
  return best
}
BEGIN {
  TIER = tier_of(tierfile)
  # SEC-R1: a recent run in a known format
  nbad = 0; badlist = ""
  while ((getline line < runs) > 0) { split(line, R, "\t"); if (R[1] == "bad") { nbad++; badlist = badlist (nbad > 1 ? ", " : "") R[3] } }
  close(runs)
  if (kind == "") {
    if (nbad) fail("SEC-R1", "High", 0, res, "no red-team result in a known format (garak report.jsonl, Promptfoo red-team JSON); not readable as one: " badlist)
    else fail("SEC-R1", "High", 0, res, "no red-team result for " app ": run garak or promptfoo redteam from a runbook, with its output in this folder")
  } else {
    d = substr(at, 1, 10); age = days(today) - days(d)
    if (age > maxage) fail("SEC-R1", "High", 0, file, "the newest red-team run is from " d ", " age " days old (most " maxage ")")
    else if (age < 0) fail("SEC-R1", "High", 0, file, "the newest red-team run is dated " d ", after today (" today ")")
    else PM["SEC-R1"] = kind " run of " d " (" file "), " age " day(s) old"
  }
  if (kind == "") { NA["SEC-R2"] = "no red-team run to read"; NA["SEC-R3"] = "no red-team run to read" }
  else {
    load(flat, J)
    # attacks and successful attacks per category; hits for SEC-R3
    nh = 0
    if (kind == "garak") {
      for (m = 0; ("[" m "].entry_type") in J; m++) if (J["[" m "].entry_type"] == "eval") {   # in file order
        p = "[" m "]"; probe = J[p ".probe"]; cat = probe; sub(/\..*$/, "", cat)
        if (!(cat in TOT)) CATS[++NC] = cat
        TOT[cat] += J[p ".total_evaluated"] + 0; BAD[cat] += J[p ".fails"] + 0
        if (J[p ".fails"] + 0 > 0) FAILID[cat] = FAILID[cat] " garak:" probe
      }
      if (hitfile != "") {
        load(hits, H)
        for (m = 0; ("[" m "].probe") in H; m++) {
          p = "[" m "]"; nh++; HID[nh] = "garak:" H[p ".probe"]; c = H[p ".probe"]; sub(/\..*$/, "", c); HCAT[nh] = c
          HWHAT[nh] = H[p ".probe"] " (" H[p ".detector"] "): " H[p ".goal"]; HLOC[nh] = hitfile ":" (m + 1)
        }
      }
    } else {
      for (m = 0; ("results.results[" m "].testCase.metadata.pluginId") in J; m++) {
        p = "results.results[" m "]"; cat = J[p ".testCase.metadata.pluginId"]
        # an errored row (failureReason 2: a rate limit, a timeout, a provider refusing by error) was not evaluated
        if (J[p ".failureReason"] == "2") { if (!(cat in ERR)) ECATS[++NE] = cat; ERR[cat]++; NERR++; continue }
        if (!(cat in TOT)) CATS[++NC] = cat
        TOT[cat]++
        if (J[p ".success"] == "false") {
          BAD[cat]++; FAILID[cat] = FAILID[cat] " promptfoo:" cat
          nh++; HID[nh] = "promptfoo:" cat; HCAT[nh] = cat; HWHAT[nh] = cat ": " J[p ".testCase.metadata.goal"]; HLOC[nh] = file
        }
      }
    }
    # SEC-R2: no category above the share (sorted, so the output is stable)
    for (i = 2; i <= NC; i++) { v = CATS[i]; for (j = i - 1; j >= 1 && CATS[j] > v; j--) CATS[j + 1] = CATS[j]; CATS[j + 1] = v }
    if (NC == 0) NA["SEC-R2"] = NERR ? "the run has no evaluated attack results (" file "): " NERR " errored" : "the run has no attack results (" file ")"
    for (i = 1; i <= NC; i++) {
      cat = CATS[i]; t = TOT[cat]; b = BAD[cat] + 0
      if (t == 0 || b / t <= maxrate + 0) continue
      ok = 1; m = split(FAILID[cat], ID, " "); by = ""
      for (j = 1; j <= m; j++) { if (waived(ID[j]) != 1) ok = 0; else if (index(" " by " ", " " WBY " ") == 0) by = by (by == "" ? "" : " ") WBY }
      msg = cat ": " b " of " t " attacks succeeded (" sprintf("%.2f", b / t) "), above " maxrate
      if (ok && m) info("SEC-R2", msg ", accepted by " by)
      else fail("SEC-R2", base_of(cat), critical(cat), file, msg)
    }
    for (i = 1; i <= NE; i++) info("SEC-R2", ECATS[i] ": " ERR[ECATS[i]] (ERR[ECATS[i]] == 1 ? " attack" : " attacks") " errored, not evaluated")
    if (NC && !NF_["SEC-R2"]) PM["SEC-R2"] = NC " categor" (NC == 1 ? "y" : "ies") " at or below " maxrate " attack success"
    # SEC-R3: each hit waived by a current ADR
    for (i = 1; i <= nh; i++) {
      w = waived(HID[i])
      if (w == 1) info("SEC-R3", HWHAT[i] ", accepted by " WBY)
      else if (w == 2) fail("SEC-R3", base_of(HCAT[i]), critical(HCAT[i]), HLOC[i], "a successful attack, " HWHAT[i] ", waived, but " WWHY)
      else fail("SEC-R3", base_of(HCAT[i]), critical(HCAT[i]), HLOC[i], "a successful attack, " HWHAT[i] ", neither fixed (absent from a newer run) nor waived (" HID[i] " in an ADR's security.waivers entry)")
    }
    if (!NF_["SEC-R3"] && !nh) PM["SEC-R3"] = "the run records no successful attack"
    else if (!NF_["SEC-R3"]) PM["SEC-R3"] = "every successful attack is waived by a current ADR"
  }
  n = split("SEC-R1 SEC-R2 SEC-R3", RL, " ")
  for (i = 1; i <= n; i++) {
    id = RL[i]
    if (NF_[id]) for (j = 1; j <= NF_[id]; j++) print FL[id, j]
    for (j = 1; j <= NI_[id]; j++) print IL[id, j]
    if (!NF_[id] && (id in NA)) printf "N/A   %s  [%s] %s\n", id, app, NA[id]
    else if (!NF_[id] && (id in PM)) printf "PASS  %s  [%s] %s\n", id, app, PM[id]
  }
  printf "check-redteam: [%s] %d finding(s), tier %d\n", app, NFIND, TIER
  exit OVER
}
