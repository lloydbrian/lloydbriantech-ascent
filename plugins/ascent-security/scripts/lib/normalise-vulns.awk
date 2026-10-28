# normalise-vulns.awk — rates the JSON that run-vuln-scan.sh collects (F=<format>,
# L=<the lockfile or requirements file it describes> and S=<the scan's label> before
# each file). A file that is not a complete report of its format (cut short, an error
# object, another format) counts as a failed scan, not a clean one. Formats:
# trivy (fs or image), trivy-version, osv, npm-audit, pip-audit. Loaded after json.awk.
# Run with LC_ALL=C.
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function rank(s) { s = toupper(s); if (s == "CRITICAL") return 4; if (s == "HIGH") return 3; if (s == "MEDIUM" || s == "MODERATE") return 2; if (s == "LOW" || s == "INFO" || s == "NEGLIGIBLE") return 1; return 0 }
function sevname(r) { return (r == 4 ? "Critical" : r == 3 ? "High" : r == 2 ? "Medium" : r == 1 ? "Low" : "no severity") }
function cvss(x) { x += 0; return (x >= 9 ? 4 : x >= 7 ? 3 : x >= 4 ? 2 : x > 0 ? 1 : 0) }
function days(dt,   y, m, dd) {  # days since 1970-01-01 for YYYY-MM-DD; -1 if malformed
  if (dt !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return -1
  y = substr(dt, 1, 4) + 0; m = substr(dt, 6, 2) + 0; dd = substr(dt, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd - 719469
}
function rel(p) { if (ROOTABS != "" && index(p, ROOTABS "/") == 1) p = substr(p, length(ROOTABS) + 2); return p }
function under(p) { return (ROOT == "." || ROOT == "" || substr(p, 1, 1) == "/") ? p : ROOT "/" p }
BEGIN {
  n = split(WAIVED, t, ","); for (i = 1; i <= n; i++) if (trim(t[i]) != "") WAIVE[toupper(trim(t[i]))] = 1
  TR = (THRESH == "none" ? 99 : rank(THRESH))
  sub(/\/$/, "", ROOTABS)
}

# --- the current advisory (A*) is recorded when the next one starts; END fills in what
# the scanner left out (version, fix, line), then merges duplicates ---------------------
function adv_new(k) { adv_flush(); ACUR = k; AID = ""; AAL = ""; APKG = ""; AVER = ""; AFIX = ""; ASEV = 0; ALINE = 0; AWHERE = ""; ACHK = "D7" }
function adv_alias(x) { if (x != "" && x != AID) AAL = AAL " " x }
function adv_flush() {
  if (ACUR == "" || AID == "") { ACUR = ""; return }
  ACUR = ""; NRAW++
  QW[NRAW] = AWHERE; QP[NRAW] = APKG; QV[NRAW] = AVER; QI[NRAW] = AID; QAL[NRAW] = trim(AAL); QC[NRAW] = ACHK
  QL[NRAW] = ALINE; QLF[NRAW] = ALOCK; QS[NRAW] = ASEV; QF[NRAW] = AFIX
}
# Merge raw advisory r into the findings: the same package and version at the same place,
# and an id or alias in common (trivy's CVE with its GHSA, npm audit's GHSA, osv's GHSA).
function merge(r,   key, n, a, i, idx) {
  key = QW[r] SUBSEP tolower(QP[r]) SUBSEP QV[r]
  n = split(trim(QI[r] " " QAL[r]), a, / +/); idx = 0
  for (i = 1; i <= n && !idx; i++) if ((key, a[i]) in SEEN) idx = SEEN[key, a[i]]
  if (!idx) { idx = ++NADV; VW[idx] = QW[r]; VP[idx] = QP[r]; VV[idx] = QV[r]; VI[idx] = QI[r]; VC[idx] = QC[r]; VL[idx] = QL[r]; VS[idx] = QS[r]; VF[idx] = QF[r]; VA[idx] = "" }
  else { if (QS[r] > VS[idx]) VS[idx] = QS[r]; if (VF[idx] == "") VF[idx] = QF[r]; if (!VL[idx]) VL[idx] = QL[r] }
  for (i = 1; i <= n; i++) { SEEN[key, a[i]] = idx; if (a[i] != VI[idx] && index(" " VA[idx] " ", " " a[i] " ") == 0) VA[idx] = trim(VA[idx] " " a[i]) }
}

# The file just read: a complete report of its format, or a failed scan (SEC-D8).
function file_check(   why) {
  if (FCUR == "" || FMT == "none") { FCUR = ""; return }
  why = ""
  if (JBAD || JSP > 0) why = "the output is not valid JSON or was cut short"
  else if (FERR) why = "the output is an error, not a report"
  else if (FNPM6) why = "the output is npm 6 audit format, which is not read (use npm 7 or later)"
  else if (!FOK) why = "the output is not a " FMT " report"
  if (why != "") {
    BADS[++NBAD] = (FLABEL != "" ? FLABEL : FMT) ": " why
    if (FMT == "trivy-version") TVSEEN = 0; else NSRC--
    NFS -= FNFS; IMAGES -= FIMG; NTGT -= FTGT
  }
  FCUR = ""
}
FNR == 1 {
  adv_flush(); osv_flush(); file_check(); json_reset(); FMT = F; ALOCK = L; FLABEL = S; IMAGE = 0; TARGET = ""; RCUR = ""
  FCUR = FILENAME; FOK = 0; FERR = 0; FNPM6 = 0; FNFS = 0; FIMG = 0; FTGT = 0
  if (FMT == "trivy-version") TVSEEN = 1; else NSRC++
  if (FMT == "osv" || FMT == "npm-audit" || FMT == "pip-audit") { NFS++; FNFS++ }
  # a dependency target: a lockfile trivy fs read, or one the network scanners were given
  if (FMT == "npm-audit" || FMT == "pip-audit") { NTGT++; FTGT++ }
}
{ line = $0; sub(/\r$/, "", line); json_feed(line, FNR) }

function on_json(p, v, l,   n, s1, s2, s3, s4, s5, k) {
  n = jlen(p); s1 = jseg(p, 1)
  # the keys that make a file a report of its format
  if (FMT == "trivy-version" && s1 == "Version") FOK = 1
  if (FMT == "trivy" && (s1 == "SchemaVersion" || s1 == "ArtifactName" || s1 == "Results")) FOK = 1
  if (FMT == "osv" && s1 == "results") FOK = 1
  if (FMT == "npm-audit") { if (s1 == "vulnerabilities" || s1 == "auditReportVersion") FOK = 1; if (s1 == "error") FERR = 1; if (s1 == "advisories" || s1 == "actions") FNPM6 = 1 }
  if (FMT == "pip-audit" && (s1 == "dependencies" || s1 ~ /^[0-9]+$/ || (p == "" && JK == "[]"))) FOK = 1
  if (FMT == "trivy-version") { if (s1 == "VulnerabilityDB" && jseg(p, 2) == "UpdatedAt") DBDATE = substr(v, 1, 10); if (s1 == "Version" && n == 1) TVER = v; return }
  if (FMT == "trivy") {
    if (n == 1 && s1 == "ArtifactType") { IMAGE = (v == "container_image"); if (IMAGE) { IMAGES++; FIMG++ } else { NFS++; FNFS++ } }
    if (n == 1 && s1 == "ArtifactName") ARTNAME = v
    if (s1 == "Metadata" && jseg(p, 2) == "OS") { if (jseg(p, 3) == "Family") OSF = v; if (jseg(p, 3) == "Name") OSN = v; if (jseg(p, 3) == "EOSL" && v == "true") EOSL[ARTNAME] = OSF " " OSN }
    if (s1 != "Results") return
    s2 = jseg(p, 2); s3 = jseg(p, 3); s4 = jseg(p, 4); s5 = jseg(p, 5)
    if (n == 3 && s3 == "Target") { TGT[FILENAME, s2] = v; if (!IMAGE) { NTGT++; FTGT++ } }
    if (s3 == "Packages") {
      if (s5 == "Identifier" && jseg(p, 6) == "UID") PUID[FILENAME, s2, s4] = v
      if (s5 == "Locations" && jseg(p, 7) == "StartLine" && jseg(p, 6) == "0") UIDLINE[FILENAME, s2, PUID[FILENAME, s2, s4]] = v
      return
    }
    if (s3 != "Vulnerabilities" || n < 5) return
    k = s2 SUBSEP s4
    if (k != ACUR) { adv_new(k); ACHK = (IMAGE ? "D9" : "D7"); AWHERE = (IMAGE ? TGT[FILENAME, s2] : under(rel(TGT[FILENAME, s2]))); RFILE = FILENAME; RIX = s2 }
    if (n == 5 && s5 == "VulnerabilityID") AID = v
    if (s5 == "VendorIDs") adv_alias(v)
    if (n == 5 && s5 == "PkgName") APKG = v
    if (n == 5 && s5 == "InstalledVersion") AVER = v
    if (n == 5 && s5 == "FixedVersion") AFIX = v
    if (n == 5 && s5 == "Severity") ASEV = rank(v)
    if (s5 == "PkgIdentifier" && jseg(p, 6) == "UID") { AUID = v; if ((RFILE, RIX, v) in UIDLINE) ALINE = UIDLINE[RFILE, RIX, v] }
    return
  }
  if (FMT == "osv") {
    # results[r].source.path, .packages[k].package{name,version}, .packages[k].vulnerabilities[v]
    # {id, aliases, affected[].ranges[].events[].fixed, database_specific.severity},
    # .packages[k].groups[g]{ids, max_severity}
    if (s1 != "results") return
    s2 = jseg(p, 2); s3 = jseg(p, 3)
    if (s3 == "source" && jseg(p, 4) == "path") { OSRC[s2] = rel(v); NTGT++; FTGT++ }
    if (s3 != "packages") return
    s4 = jseg(p, 4); s5 = jseg(p, 5); k = s2 SUBSEP s4
    if (k != OSVK) { osv_flush(); OSVK = k; ONV = 0; ONG = 0; ONAME = ""; OVER = ""; OWHERE = OSRC[s2] }
    if (s5 == "package") { if (jseg(p, 6) == "name") ONAME = v; if (jseg(p, 6) == "version") OVER = v; return }
    if (s5 == "vulnerabilities") {
      vi = jseg(p, 6) + 1; if (vi > ONV) ONV = vi
      if (n == 7 && jseg(p, 7) == "id") OID[vi] = v
      if (jseg(p, 7) == "aliases" && n == 8) OAL[vi] = OAL[vi] " " v
      if (jseg(p, 7) == "affected" && jseg(p, 9) == "ranges" && jseg(p, 11) == "events" && jseg(p, 13) == "fixed" && OFIX[vi] == "") OFIX[vi] = v
      if (jseg(p, 7) == "database_specific" && jseg(p, 8) == "severity") ODS[vi] = rank(v)
      return
    }
    if (s5 == "groups") {
      gi = jseg(p, 6)
      if (jseg(p, 7) == "ids" && n == 8) OGID[v] = gi
      if (jseg(p, 7) == "max_severity" && v != "") OGS[gi] = cvss(v)
    }
    return
  }
  if (FMT == "npm-audit") {
    # vulnerabilities.<name>.{severity, via[] (objects are advisories), fixAvailable}
    if (s1 != "vulnerabilities") return
    s2 = jseg(p, 2); s3 = jseg(p, 3)
    if (n == 3 && s3 == "fixAvailable") NFIXA[ALOCK, s2] = v
    if (s3 == "fixAvailable" && n == 4 && jseg(p, 4) == "version") NFIXV[ALOCK, s2] = v
    if (s3 == "via" && n == 5) {
      k = s2 SUBSEP jseg(p, 4)
      if (k != ACUR) { adv_new(k); APKG = s2; AWHERE = under(ALOCK) }
      if (jseg(p, 5) == "url") { AID = v; sub(/^.*\//, "", AID) }
      if (jseg(p, 5) == "source" && AID == "") AID = "npm-" v
      if (jseg(p, 5) == "severity") ASEV = rank(v)
    }
    return
  }
  if (FMT == "pip-audit") {
    # {"dependencies": [{name, version, vulns: [{id, fix_versions, aliases}]}]}, or the bare array
    if (s1 == "dependencies") { p = substr(p, length("dependencies") + 2); n--; s1 = jseg(p, 1) }
    if (s1 !~ /^[0-9]+$/) return
    s2 = jseg(p, 2); s3 = jseg(p, 3)
    if (n == 2 && s2 == "name") PANAME[s1] = v
    if (n == 2 && s2 == "version") PAVER[s1] = v
    if (s2 == "vulns" && n >= 4) {
      k = s1 SUBSEP s3
      if (k != ACUR) { adv_new(k); APKG = PANAME[s1]; AVER = PAVER[s1]; AWHERE = under(ALOCK) }
      if (n == 4 && jseg(p, 4) == "id") AID = v
      if (jseg(p, 4) == "aliases") adv_alias(v)
      if (jseg(p, 4) == "fix_versions" && AFIX == "") AFIX = v
    }
    return
  }
}
function osv_flush(   i, j, na, a, sv) {
  if (OSVK == "") return
  for (i = 1; i <= ONV; i++) {
    if (OID[i] == "") continue
    adv_new("osv" i); AID = OID[i]; APKG = ONAME; AVER = OVER; AFIX = OFIX[i]; AWHERE = under(OWHERE)
    na = split(trim(OAL[i]), a, / +/); for (j = 1; j <= na; j++) adv_alias(a[j])
    sv = 0; if (AID in OGID && OGID[AID] in OGS) sv = OGS[OGID[AID]]
    if (!sv) sv = ODS[i] + 0
    ASEV = sv
  }
  adv_flush()
  split("", OID); split("", OAL); split("", OFIX); split("", ODS); split("", OGID); split("", OGS); OSVK = ""
}

# --- the end: line lookup, rating, output ----------------------------------------------------
function findline(f, pkg, eco,   ln, n, nl, want, lv) {  # the first line naming pkg in f; 0 if none
  if (f == "" || pkg == "") return 0
  n = 0; nl = 0; want = tolower(pkg)
  while ((getline ln < f) > 0) {
    n++
    lv = tolower(ln)
    if (index(lv, "\"node_modules/" want "\"") || index(lv, "/node_modules/" want "\"") || index(lv, "\"" want "@") == 1 || index(lv, want "@") == 1 || index(lv, want "==") == 1 || index(lv, want " ==") == 1) { nl = n; break }
  }
  close(f)
  return nl
}
function lockver(f, pkg,   ln, on, v) {  # the version package-lock.json records for node_modules/pkg
  on = 0; v = ""
  while ((getline ln < f) > 0) {
    if (index(ln, "\"node_modules/" pkg "\"")) on = 1
    else if (on && match(ln, /"version": *"[^"]*"/)) { v = substr(ln, RSTART, RLENGTH); sub(/^"version": *"/, "", v); sub(/"$/, "", v); break }
  }
  close(f)
  return v
}
function emit(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "SEC-" k, sev, where, msg); NFK[k]++; NFAIL++ }
function note(k, msg) { NOTES = NOTES sprintf("NOTE  %-7s %s\n", "SEC-" k, msg) }
END {
  adv_flush(); osv_flush(); file_check()
  for (r = 1; r <= NRAW; r++) {
    if (QV[r] == "" && QLF[r] ~ /package-lock\.json$|npm-shrinkwrap\.json$/) QV[r] = lockver(under(QLF[r]), QP[r])
    if (QF[r] == "" && QLF[r] != "") QF[r] = (NFIXV[QLF[r], QP[r]] != "" ? NFIXV[QLF[r], QP[r]] : (NFIXA[QLF[r], QP[r]] == "true" ? "a release npm audit fix can install" : ""))
    if (QL[r] == 0 && QC[r] == "D7") QL[r] = findline(QW[r], QP[r])
    merge(r)
  }
  for (i = 1; i <= NADV; i++) {
    ids = VI[i] (VA[i] != "" ? " (" VA[i] ")" : "")
    w = 0; na = split(trim(VI[i] " " VA[i]), a, / +/); for (j = 1; j <= na; j++) if (toupper(a[j]) in WAIVE) w = 1
    CHK[VC[i]]++
    if (w) { NW++; INFOS = INFOS sprintf("INFO  %-7s %s  %s in %s %s is waived\n", "SEC-" VC[i], VW[i] (VL[i] ? ":" VL[i] : ""), ids, VP[i], VV[i]); continue }
    if (VS[i] > 0 && VS[i] < TR || TR == 99) { NB++; BELOW[VC[i]]++; BSEV[VC[i], sevname(VS[i])]++; continue }
    fix = (VF[i] != "")
    if (VS[i] == 0) sev = "Medium"
    else if (VS[i] >= 3) sev = (fix ? "High" : "Medium")
    else sev = "Low"
    if (++PERW[VW[i]] > 25) { if (!MOREW[VW[i]]++) { MOREL[++NMORE] = VW[i]; MOREK[VW[i]] = VC[i] } NFAIL++; NFK[VC[i]]++; continue }
    emit(VC[i], sev, VW[i] (VL[i] ? ":" VL[i] : ""), ids " in " VP[i] " " (VV[i] != "" ? VV[i] : "(version not recorded)") ": " sevname(VS[i]) ", " (fix ? "fixed in " VF[i] : "no fixed release yet"))
  }
  for (j = 1; j <= NMORE; j++) note(MOREK[MOREL[j]], MOREL[j] ": " MOREW[MOREL[j]] " more rated advisories, not listed")
  for (o = 1; o <= 2; o++) { k = (o == 1 ? "D7" : "D9"); if (!BELOW[k]) continue; s = ""; split("Critical High Medium Low", SN, " "); for (j = 1; j <= 4; j++) if (BSEV[k, SN[j]]) s = s (s == "" ? "" : ", ") BSEV[k, SN[j]] " " SN[j]; note(k, BELOW[k] " advisor" (BELOW[k] > 1 ? "ies" : "y") " below the threshold (" (TR == 99 ? "none: nothing is rated" : THRESH) "): " s) }
  for (w in EOSL) note("D9", w ": the base image OS " EOSL[w] " is past end of support; its packages get no more fixes")
  # SEC-D8: was the scan measured, and how old is the database?
  r8 = ""
  if (NSRC == 0) r8 = (UNMEASURED != "" ? UNMEASURED : "no scanner output, so dependency vulnerabilities are unmeasured")
  else if (TVSEEN && DBDATE == "") r8 = "trivy reports no vulnerability database: advisories cannot be matched"
  else if (DBDATE != "" && days(TODAY) - days(DBDATE) > MAXAGE + 0) r8 = "the trivy database was updated " DBDATE ", " (days(TODAY) - days(DBDATE)) " days ago (scan_max_age_days " MAXAGE "): advisories published since then are not seen"
  if (r8 != "") { CHK["D8"]++; if (MATURITY == "prototype") note("D8", r8); else emit("D8", "Low", (TVSEEN ? "trivy" : "scan"), r8) }
  else { CHK["D8"]++; if (!TVSEEN) note("D8", "the database date is not recorded for these results, so their age is unknown") }
  # A scanner that failed, or wrote no complete report, leaves part of the scan unmeasured.
  n = split(FAILED, a, "|"); for (j = 1; j <= n; j++) if (a[j] != "") BADS[++NBAD] = a[j]
  for (j = 1; j <= NBAD; j++) { CHK["D8"]++; if (MATURITY == "prototype") note("D8", BADS[j]); else emit("D8", "Low", "scan", BADS[j] ": that part of the scan is unmeasured") }
  n = split(SKIPPED, a, "|"); for (j = 1; j <= n; j++) if (a[j] != "") note("D8", a[j])
  split("D7 D8 D9", ORD, " ")
  for (i = 1; i <= 3; i++) printf "%s", OUT[ORD[i]]
  NAREASON["D7"] = (NSRC == 0 ? "not scanned" : NTGT == 0 ? "no lockfile the scanners read" : "no advisories"); NAREASON["D8"] = "no scan ran"; NAREASON["D9"] = (IMAGES > 0 ? "no advisories" : "no --image or --image-tar")
  for (i = 1; i <= 3; i++) { k = ORD[i]
    if (NFK[k] > 0) continue
    if (k == "D7" && NFS > 0 && NTGT > 0) printf "PASS  %-7s %d advisories rated, none at or above the threshold\n", "SEC-D7", CHK["D7"] + 0
    else if (k == "D9" && IMAGES > 0) printf "PASS  %-7s %d image%s scanned, no rated advisory\n", "SEC-D9", IMAGES, (IMAGES > 1 ? "s" : "")
    else if (k == "D8" && CHK["D8"] > 0) printf "PASS  %-7s %s\n", "SEC-D8", (DBDATE != "" ? "database " DBDATE ", within " MAXAGE " days" : "scanned; the database date is not recorded")
    else printf "N/A   %-7s %s\n", "SEC-" k, NAREASON[k] }
  printf "%s%s", NOTES, INFOS
  printf "run-vuln-scan: %d advisories (%d rated, %d below the threshold, %d waived) from %d scan%s (%s), database %s%s, %d findings\n", NADV, NADV - NB - NW, NB, NW, NSRC, (NSRC == 1 ? "" : "s"), (SCANNERS != "" ? SCANNERS : "none"), (DBDATE != "" ? DBDATE : "not recorded"), (TVER != "" ? " (trivy " TVER ")" : ""), NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
