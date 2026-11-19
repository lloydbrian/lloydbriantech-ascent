# check-adrs.awk — the program check-adrs.sh runs, after adr-common.awk. Reads the
# index (when there is one) and then every ADR file; the options come from CA_* in
# the environment. Portable: POSIX awk (BWK, mawk, gawk).

BEGIN {
  TODAY = ENVIRON["CA_TODAY"]; MAT = ENVIRON["CA_MATURITY"]; STYLE = ENVIRON["CA_STYLE"]; IDX = ENVIRON["CA_INDEX"]
  DIR = ENVIRON["CA_DIR"]; NOGIT = ENVIRON["CA_NOGIT"]
  n = split(ENVIRON["CA_DRIFT"], d, "\n"); for (i = 1; i <= n; i++) if (d[i] != "") { split(d[i], p, "\t"); DRIFT[p[1]] = p[2] }
  n = split(ENVIRON["CA_ACKED"], d, "\n"); for (i = 1; i <= n; i++) if (d[i] != "") { split(d[i], p, "\t"); ACKED[p[1]] = p[2] }
  n = split(ENVIRON["CA_COMPARED"], d, "\n"); for (i = 1; i <= n; i++) if (d[i] != "") COMPARED[d[i]] = 1
  n = split(ENVIRON["CA_OTHERS"], d, "\n"); NO = 0; for (i = 1; i <= n; i++) if (d[i] != "") OTHER[++NO] = d[i]
  REQ["ascent"] = "context|decision|alternatives considered|consequences|cost implications"
  REQ["nygard"] = "context|decision|consequences"
  REQ["madr"] = "context and problem statement|considered options|decision outcome"
  NF_ADR = 0; NIL = 0
}
function shown(f) { sub(/^\.\//, "", f); return f }
function fail(k, sev, w, msg) {
  if (MAT == "prototype") { NOTES = NOTES sprintf("NOTE  %-7s %-6s %s  %s (prototype: not rated)\n", "DEC-" k, sev, w, msg); return }
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "DEC-" k, sev, w, msg); NFL[k]++
}
function close_file() {
  if (!CUR) return
  ST[CUR] = A_STATUS; STL[CUR] = A_STATUS_L; CL[CUR] = adr_class(A_STATUS)
  if (!A_DATE_L && match(A_STATUS, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { A_DATE = substr(A_STATUS, RSTART, 10); A_DATE_L = A_STATUS_L }  # "Accepted (2026-07-15)"
  DT[CUR] = A_DATE; DTL[CUR] = A_DATE_L; TI[CUR] = A_TITLE; TIL[CUR] = A_TITLE_L; SUPS[CUR] = A_SUPS
  h = "|"; for (k in A_HEAD) h = h k "|"; HEADS[CUR] = h
  if (h ~ /\|cost implications\|/) VOTE["ascent"]++
  else if (h ~ /\|(decision outcome|considered options|context and problem statement)/) VOTE["madr"]++
  else VOTE["nygard"]++
  CUR = 0
}
FNR == 1 { close_file() }
FILENAME == IDX {  # the index: every link to an ADR file, and a status cell beside it
  s = $0
  while (match(s, /\]\([^)]+\)/)) {
    t = substr(s, RSTART + 2, RLENGTH - 3); s = substr(s, RSTART + RLENGTH); sub(/#.*/, "", t); sub(/[ \t].*/, "", t)
    b = t; sub(/.*\//, "", b)
    if (!adr_isfile(b)) continue
    NIL++; ILINK[NIL] = b; ILINE[NIL] = FNR; ICL[NIL] = ""
    if ($0 ~ /^[ \t]*\|/) { m = split($0, c, "|"); for (j = 2; j < m; j++) if (index(c[j], "](") == 0 && adr_class(c[j]) != "") { ICL[NIL] = adr_class(c[j]); break } }
  }
  next
}
FNR == 1 { NF_ADR++; CUR = NF_ADR; F[CUR] = FILENAME; B = FILENAME; sub(/.*\//, "", B); BASE[CUR] = B; NUM[CUR] = adr_num(FILENAME); BYBASE[B] = CUR; adr_begin() }
{ adr_line($0) }

END {
  close_file()
  if (STYLE == "auto" || STYLE == "") { STYLE = "ascent"; best = VOTE["ascent"] + 0; if (VOTE["madr"] + 0 > best) { STYLE = "madr"; best = VOTE["madr"] }; if (VOTE["nygard"] + 0 > best) STYLE = "nygard" }
  for (i = 1; i <= NF_ADR; i++) { if (NUM[i] in BYNUM) BYNUM[NUM[i]] = BYNUM[NUM[i]] " " i; else BYNUM[NUM[i]] = i }
  for (i = 1; i <= NF_ADR; i++) { split(BYNUM[NUM[i]], q, " "); FIRST[i] = q[1] + 0 }

  # DEC-S1: a decision record exists
  if (NF_ADR == 0) fail("S1", "Medium", (DIR == "" ? ".:absent" : shown(DIR) ":absent"), (DIR == "" ? "no decision record: no ADR folder (looked in " ENVIRON["CA_LOOKED"] ")" : "no decision record: " shown(DIR) " holds no ADR named NNNN-title.md"))
  else CHK["S1"]++

  for (i = 1; i <= NF_ADR; i++) {
    f = shown(F[i]); id = "ADR-" NUM[i]
    # DEC-S2: the sections the format requires
    CHK["S2"]++; m = split(REQ[STYLE], r, "|"); miss = ""
    for (j = 1; j <= m; j++) if (index(HEADS[i], "|" r[j]) == 0) miss = miss (miss == "" ? "" : ", ") "\"## " r[j] "\""
    if (miss != "") fail("S2", "Medium", f ":1", id " is missing " miss " (" STYLE " format)")
    # DEC-S3: numbers and titles
    CHK["S3"]++
    if (FIRST[i] != i) fail("S3", "Low", f ":1", id " has the same number as " shown(F[FIRST[i]]))
    if (!TIL[i]) fail("S3", "Low", f ":1", id " has no \"# \" title")
    else { t = tolower(TI[i]); if (match(t, /^(adr[- ]?)?[0-9]+[.:]?[ \t]/)) { tn = substr(t, RSTART, RLENGTH); gsub(/[^0-9]/, "", tn); if (tn + 0 != NUM[i]) fail("S3", "Low", f ":" TIL[i], "the title says " (tn + 0) " but the file is numbered " NUM[i]) } }
    # DEC-S5: a known status
    CHK["S5"]++
    if (!STL[i]) fail("S5", "Medium", f ":1", id " has no status")
    else if (CL[i] == "") fail("S5", "Medium", f ":" STL[i], id ": status \"" ST[i] "\" is not proposed, accepted, rejected, deprecated or superseded")
    # DEC-S6: supersession both ways
    if (CL[i] == "superseded") {
      CHK["S6"]++; to = adr_after(ST[i], "superseded by")
      if (to < 0) fail("S6", "Medium", f ":" STL[i], id " is superseded, but its status names no replacement: write \"Superseded by ADR-NNN\"")
      else if (!(to in BYNUM)) fail("S6", "Medium", f ":" STL[i], id " is superseded by ADR-" to ", which does not exist")
      else { k = FIRST[to]; if (index(" " SUPS[k], ":" NUM[i] " ") == 0) fail("S6", "Medium", f ":" STL[i], id " is superseded by ADR-" to ", but ADR-" to " does not say it supersedes " id) }
    }
    if (CL[i] != "proposed" && CL[i] != "rejected") {
      m = split(SUPS[i], sp, " ")
      for (j = 1; j <= m; j++) {
        split(sp[j], lv, ":"); o = lv[2] + 0; if (o == NUM[i]) continue
        CHK["S6"]++
        if (!(o in BYNUM)) fail("S6", "Medium", f ":" lv[1], id " supersedes ADR-" o ", which does not exist")
        else if (CL[FIRST[o]] != "superseded") fail("S6", "Medium", f ":" lv[1], id " supersedes ADR-" o ", but ADR-" o " is still " (CL[FIRST[o]] == "" ? "without a status" : CL[FIRST[o]]) ": set its status to \"Superseded by " id "\"")
      }
    }
    # DEC-S7: a real date, not in the future
    CHK["S7"]++
    if (!DTL[i]) fail("S7", "Low", f ":1", id " has no date")
    else if (!adr_realdate(DT[i])) fail("S7", "Low", f ":" DTL[i], id ": date \"" DT[i] "\" is not a real YYYY-MM-DD date")
    else if (adr_days(substr(DT[i], 1, 10)) > adr_days(TODAY)) fail("S7", "Low", f ":" DTL[i], id " is dated " substr(DT[i], 1, 10) ", after today")
    # DEC-S8: an accepted body never changes
    if (NOGIT == "" && f in COMPARED) {
      CHK["S8"]++
      if (f in ACKED) NOTES = NOTES sprintf("NOTE  DEC-S8  -      %s:1  %s: changes up to %s are acknowledged (decisions.acknowledged_changes); later changes are checked\n", f, id, ACKED[f])
      if (f in DRIFT) fail("S8", "Medium", f ":1", id " was accepted in " DRIFT[f] " and its body has changed since; only its status may change: record the new decision in a new ADR that supersedes it")
    }
  }
  for (j = 1; j <= NO; j++) { CHK["S3"]++; fail("S3", "Low", shown(OTHER[j]) ":1", "not named NNNN-title.md or ADR-NNN-title.md, so it is not read as an ADR") }

  # DEC-S4: the index lists every ADR, links only to ADRs, and agrees on status
  if (IDX != "" && NIL > 0) {
    CHK["S4"]++
    for (j = 1; j <= NIL; j++) {
      LISTED[ILINK[j]] = 1
      if (!(ILINK[j] in BYBASE)) fail("S4", "Low", shown(IDX) ":" ILINE[j], "the index links to " ILINK[j] ", which does not exist")
      else if (ICL[j] != "" && CL[BYBASE[ILINK[j]]] != "" && ICL[j] != CL[BYBASE[ILINK[j]]]) fail("S4", "Low", shown(IDX) ":" ILINE[j], "the index says " ICL[j] " for " ILINK[j] ", the ADR says " CL[BYBASE[ILINK[j]]])
    }
    for (i = 1; i <= NF_ADR; i++) if (!(BASE[i] in LISTED)) fail("S4", "Low", shown(IDX) ":1", "ADR-" NUM[i] " (" BASE[i] ") is not in the index")
  }

  D["S1"] = "a decision record exists"; D["S2"] = "every ADR has its format's sections"; D["S3"] = "numbers unique, files and titles agree"; D["S4"] = "the index lists every ADR"
  D["S5"] = "every ADR has a known status"; D["S6"] = "supersession recorded both ways"; D["S7"] = "every ADR has a real date"; D["S8"] = "accepted ADRs unchanged since acceptance"
  NA["S4"] = (IDX == "" ? "no index file" : "the index links to no ADR"); NA["S6"] = "no supersession"; NA["S8"] = (NOGIT != "" ? NOGIT : "no accepted ADR in the git history")
  NFAIL = 0
  for (i = 1; i <= 8; i++) {
    k = "S" i
    if (NFL[k] > 0) { printf "%s", OUT[k]; NFAIL += NFL[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "DEC-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "DEC-" k, D[k], (NF_ADR == 0 && k != "S1" ? "no ADR" : NA[k])
  }
  printf "%s", NOTES
  printf "check-adrs: %s, %d ADR(s), %s format, %d failure(s); it checks that decisions are recorded and kept, not that they are right\n", (DIR == "" ? "no ADR folder" : shown(DIR)), NF_ADR, STYLE, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
