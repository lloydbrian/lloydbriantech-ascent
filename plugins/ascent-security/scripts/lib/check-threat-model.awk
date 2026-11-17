# check-threat-model.awk — the program check-threat-model.sh runs. Reads the threat
# model (or /dev/null when it is absent) and the options from CTM_* in the
# environment. Portable: POSIX awk (BWK, mawk, gawk).

BEGIN {
  TODAY = ENVIRON["CTM_TODAY"]; MAXAGE = ENVIRON["CTM_MAXAGE"] + 0; MAT = ENVIRON["CTM_MATURITY"]; MODEL = ENVIRON["CTM_MODEL"]
  n = split(ENVIRON["CTM_EPS"], e, "\n"); NE = 0
  for (i = 1; i <= n; i++) if (e[i] != "") { NE++; EPM[NE] = e[i]; sub(/ .*/, "", EPM[NE]); EPP[NE] = e[i]; sub(/^[^ ]* /, "", EPP[NE]) }
  n = split(ENVIRON["CTM_FOUND"], f, "\n"); for (i = 1; i <= n; i++) if (f[i] != "") FOUND[f[i]] = 1
  n = split(ENVIRON["CTM_ADRS"], f, "\n"); for (i = 1; i <= n; i++) if (f[i] != "") ADRS[f[i]] = 1
  SEC = "head"; NEP = 0; NTH = 0
  sub(/^\.\//, "", MODEL)
}
function fail(k, sev, l, msg,   w) {
  w = (l == "absent") ? MODEL ":absent" : MODEL ":" l
  if (MAT == "prototype") { NOTES = NOTES sprintf("NOTE  %-7s %-6s %s  %s (prototype: not rated)\n", "SEC-" k, sev, w, msg); return }
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "SEC-" k, sev, w, msg); NF_[k]++
}
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function norm(p) { gsub(/\{[^}\/]+\}/, "{}", p); gsub(/\/:[^\/]+/, "/{}", p); sub(/\/$/, "", p); return p }
function days(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
}
function cells(s,   n, i) {  # a table row into C[1..n]
  sub(/^[ \t]*\|/, "", s); sub(/\|[ \t]*$/, "", s)
  n = split(s, C, "|"); for (i = 1; i <= n; i++) C[i] = trim(C[i]); return n
}
FILENAME == "/dev/null" { next }
{ sub(/\r$/, ""); SEEN = 1 }
/^## / { h = tolower(trim(substr($0, 4))); SEC = (h ~ /^entry points/) ? "ep" : (h ~ /^threats/) ? "th" : "other"; if (SEC == "ep") EPSEC = NR; if (SEC == "th") THSEC = NR; next }
/^[ \t]*\|/ {
  n = cells($0)
  if (C[1] ~ /^:?-+:?$/ || tolower(C[1]) == "field" || tolower(C[1]) == "id") next
  if (SEC == "head" && n >= 2) { FIELD[tolower(C[1])] = C[2]; FL[tolower(C[1])] = NR; NFIELD++ }
  else if (SEC == "ep" && n >= 4) {
    NEP++; EID[NEP] = C[1]; ETXT[NEP] = C[2]; EL[NEP] = NR; ISEP[C[1]] = NEP
    t = C[2]; while (match(t, /\/[^ ,;|`]*/)) { EPATH[norm(substr(t, RSTART, RLENGTH))] = NEP; t = substr(t, RSTART + RLENGTH) }
  } else if (SEC == "th" && n >= 6) { NTH++; TID[NTH] = C[1]; TEP[NTH] = C[2]; TS[NTH] = C[3]; TT[NTH] = C[4]; TM[NTH] = C[5]; TST[NTH] = tolower(C[6]); TL[NTH] = NR }
  else if (SEC == "ep" || SEC == "th") { BADROW[++NBAD] = NR; BADSEC[NBAD] = SEC }
}

END {
  # SEC-T1: the model and its shape
  if (!SEEN) fail("T1", "Medium", "absent", "no threat model: the entry points and their threats are not recorded")
  else {
    CHK["T1"]++
    if (NFIELD == 0) fail("T1", "Medium", 1, "no field table (reviewed_on, reviewed_by, method)")
    else if (toupper(FIELD["method"]) != "STRIDE") fail("T1", "Medium", (FL["method"] ? FL["method"] : 1), "method is \"" FIELD["method"] "\", not STRIDE")
    if (!EPSEC) fail("T1", "Medium", 1, "no \"## Entry points\" table")
    if (!THSEC) fail("T1", "Medium", 1, "no \"## Threats\" table")
    for (i = 1; i <= NBAD; i++) fail("T1", "Medium", BADROW[i], (BADSEC[i] == "ep" ? "an entry point row needs 4 cells (Id, Entry point, Trust boundary, Auth)" : "a threat row needs 6 cells (Id, Entry point, STRIDE, Threat, Mitigation, Status)"))
  }
  # SEC-T2: endpoints covered, entry points threatened
  if (SEEN) {
    for (i = 1; i <= NE; i++) {
      CHK["T2"]++
      if (!(norm(EPP[i]) in EPATH)) fail("T2", "Medium", (EPSEC ? EPSEC : 1), "endpoint " EPM[i] " " EPP[i] " is not an entry point")
    }
    for (j = 1; j <= NTH; j++) { m = split(TEP[j], te, /[ ,;]+/); for (k = 1; k <= m; k++) if (te[k] != "") { HIT[te[k]] = 1; if (!(te[k] in ISEP) && te[k] != "all" && te[k] != "*") fail("T3", "Low", TL[j], TID[j] " names entry point \"" te[k] "\", which the Entry points table does not list") } }
    if (THSEC) for (i = 1; i <= NEP; i++) { CHK["T2"]++; if (!(EID[i] in HIT) && !HIT["all"] && !HIT["*"]) fail("T2", "Medium", EL[i], "entry point " EID[i] " (" ETXT[i] ") has no threat") }
  }
  # SEC-T3: each threat answered
  for (j = 1; j <= NTH; j++) {
    CHK["T3"]++
    s = toupper(TS[j]); st = TST[j]
    if (s !~ /^[STRIDE]$/) fail("T3", "Low", TL[j], TID[j] ": STRIDE is \"" TS[j] "\", not one of S, T, R, I, D, E")
    else COVER[s] = 1
    if (st == "open") fail("T3", "Medium", TL[j], TID[j] " is open: " TT[j])
    else if (st == "mitigated") {
      ok = 0; t = TM[j]
      while (match(t, /`[^` ]+`/)) { p = substr(t, RSTART + 1, RLENGTH - 2); if (p in FOUND) ok = 1; t = substr(t, RSTART + RLENGTH) }
      if (!ok) fail("T3", "Low", TL[j], TID[j] " is mitigated, but its mitigation names no file that exists in the repository")
    } else if (st ~ /^accepted/) {
      if (match(st, /adr-[0-9]+/)) { a = toupper(substr(st, RSTART, RLENGTH)); sub(/-0*/, "-", a); if (!(a in ADRS)) fail("T3", "Low", TL[j], TID[j] " is accepted under " a ", which is not in " ENVIRON["CTM_ADR"]) }
      else fail("T3", "Low", TL[j], TID[j] " is accepted with no ADR: write \"accepted (ADR-NNN)\"")
    } else fail("T3", "Low", TL[j], TID[j] ": status is \"" TST[j] "\", not mitigated, accepted (ADR-NNN) or open")
  }
  # SEC-T4: reviewed by a person, recently
  if (SEEN && NFIELD > 0) {
    CHK["T4"]++
    d = FIELD["reviewed_on"]; l = FL["reviewed_on"] ? FL["reviewed_on"] : 1
    if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) fail("T4", "Low", l, "reviewed_on is \"" d "\", not a date: a person has not reviewed the model")
    else { age = days(TODAY) - days(d); if (age > MAXAGE) fail("T4", "Low", l, "reviewed " age " days ago (max " MAXAGE ")"); else if (age < 0) fail("T4", "Low", l, "reviewed_on " d " is after today") }
    r = FIELD["reviewed_by"]
    if (r == "" || r ~ /^(-|—|tbd|TBD|n\/a|N\/A|<.*>|claude|Claude)$/) fail("T4", "Low", (FL["reviewed_by"] ? FL["reviewed_by"] : 1), "reviewed_by names no person")
  }
  if (NTH > 0) { miss = ""; for (i = 1; i <= 6; i++) { c = substr("STRIDE", i, 1); if (!(c in COVER)) miss = miss c } if (miss != "") NOTES = NOTES sprintf("NOTE  SEC-T3  -      %s  no threat in STRIDE categor%s %s: consider whether any applies\n", MODEL, (length(miss) > 1 ? "ies" : "y"), miss) }
  D["T1"] = "threat model present and well formed"; D["T2"] = "endpoints are entry points with threats"; D["T3"] = "threats mitigated or accepted"; D["T4"] = "reviewed by a person recently"
  NFAIL = 0
  for (i = 1; i <= 4; i++) {
    k = "T" i
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "SEC-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "SEC-" k, D[k], (!SEEN ? "no threat model" : (k == "T2" ? "no endpoint and no entry point" : "no threat"))
  }
  printf "%s", NOTES
  printf "check-threat-model: %s, %d entry point(s), %d threat(s), %d endpoint(s), %d failure(s); it checks that threats are recorded and answered, not that the answers are right\n", (SEEN ? MODEL : "no model"), NEP, NTH, NE, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
