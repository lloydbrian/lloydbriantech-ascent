# check-docs.awk — the program check-docs.sh runs, after md-common.awk. Inputs, in
# order: CD_FILES (every repository path), CD_SET (the documents checked), CD_DATES
# ("path<TAB>YYYY-MM-DD", each file's last change), CD_MARKS ("path<TAB>line<TAB>
# YYYY-MM-DD", each stale marker's line, dated by git blame), then every Markdown
# file in the repository. Options come from CD_* in the environment.
# Portable: POSIX awk (BWK, mawk, gawk), run with LC_ALL=C.

BEGIN {
  TODAY = ENVIRON["CD_TODAY"]; MAT = ENVIRON["CD_MATURITY"]; NOGIT = ENVIRON["CD_NOGIT"]
  CLICKS = ENVIRON["CD_MAX_CLICKS"] + 0; MDAYS = ENVIRON["CD_MARKER_DAYS"] + 0; LAG = ENVIRON["CD_LAG_DAYS"] + 0
  FF = ENVIRON["CD_FILES"]; FS_ = ENVIRON["CD_SET"]; FD = ENVIRON["CD_DATES"]; FM = ENVIRON["CD_MARKS"]
  NP = split(ENVIRON["CD_PERSONAS"], PL, "\n")
}
function fail(k, sev, w, msg) {
  if (MAT == "prototype") { NOTES = NOTES sprintf("NOTE  %-7s %-6s %s  %s (prototype: not rated)\n", "DOC-" k, sev, w, msg); return }
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "DOC-" k, sev, w, msg); NF_[k]++
}
function note(k, w, msg) { NOTES = NOTES sprintf("NOTE  %-7s %s  %s\n", "DOC-" k, w, msg) }
function addfile(p,   d) {
  EXISTS[p] = 1
  d = p; while (d ~ /\//) { sub(/\/[^\/]*$/, "", d); if (d in EXISTS) break; EXISTS[d] = 1 }
}
FILENAME == FF { addfile($0); next }
FILENAME == FS_ { INSET[$0] = 1; SETN++; SETL[SETN] = $0; next }
FILENAME == FD { split($0, a, "\t"); DATE[a[1]] = a[2]; next }
FILENAME == FM { split($0, a, "\t"); MARK[a[1] SUBSEP a[2]] = a[3]; next }
{
  doc = FILENAME; sub(/^\.\//, "", doc)
  if (FNR == 1) { MDN++; MDL[MDN] = doc; ISMD[doc] = 1 }
  if (!md_line()) next
  md_heading(doc)
  if ((doc in INSET) && doc == "README.md" && md_isheading($0) && tolower($0) ~ /install|getting started|get started|quick ?start|setup|set up|usage|how to use|commands|development|running|run locally/) README_START = 1
  n = md_links($0)
  for (i = 1; i <= n; i++) {
    t = MD_L[i]; if (md_external(t)) continue
    anchor = ""; j = index(t, "#"); if (j) { anchor = substr(t, j + 1); t = substr(t, 1, j - 1) }
    sub(/\?.*$/, "", t); t = md_unescape(t)
    if (t == "") { target = doc } else target = md_resolve(doc, t)
    if (doc in INSET) {
      NL++; LDOC[NL] = doc; LLINE[NL] = FNR; LRAW[NL] = MD_L[i]; LT[NL] = target; LA[NL] = anchor; LCLIMB[NL] = (substr(target, 1, 3) == "../")
    }
    if (target != "" && substr(target, 1, 3) != "../") { EDGE[doc] = EDGE[doc] target "\n" }
  }
}
function mdtarget(t) {  # the Markdown document a link to t opens, or ""
  if (t in ISMD) return t
  if ((t (t == "" ? "" : "/") "README.md") in ISMD) return t (t == "" ? "" : "/") "README.md"
  return ""
}
END {
  # DOC-L1, DOC-L2 — links resolve; anchors name a heading
  for (i = 1; i <= NL; i++) {
    w = LDOC[i] ":" LLINE[i]; t = LT[i]
    CHK["L1"]++
    if (LCLIMB[i]) { fail("L1", "Medium", w, "the link " LRAW[i] " leaves the repository"); continue }
    if (t != "" && !(t in EXISTS)) { fail("L1", "Medium", w, "the link " LRAW[i] " points to " t ", which does not exist"); continue }
    if (LA[i] == "") continue
    m = mdtarget(t); if (m == "") continue
    if (LA[i] ~ /[^ -~]/ || index(LA[i], "%") || (m in MD_LOOSEDOC)) continue
    CHK["L2"]++
    if (!((m SUBSEP tolower(LA[i])) in MD_ANCH) && !((m SUBSEP LA[i]) in MD_ANCH)) fail("L2", "Low", w, "the link " LRAW[i] " names #" LA[i] ", which is not a heading in " m)
  }
  # DOC-L3 — stale markers, dated by git blame
  for (k in MARK) {
    split(k, p, SUBSEP); d = MARK[k]
    if (!(p[1] in INSET)) continue
    CHK["L3"]++
    if (NOGIT != "" || d == "") { fail("L3", "Low", p[1] ":" p[2], "a stale marker (TODO, TBD, FIXME, coming soon or a stub label); no git date, so it is reported as stale"); continue }
    age = md_days(TODAY) - md_days(d)
    if (age > MDAYS) fail("L3", "Low", p[1] ":" p[2], "a stale marker (TODO, TBD, FIXME, coming soon or a stub label) written " d ", " age " days ago (max " MDAYS ")")
    else note("L3", p[1] ":" p[2], "a stale marker written " d " (" age " days ago, within " MDAYS ")")
  }
  # DOC-L4 — a document older than the files it links to
  if (NOGIT == "") for (i = 1; i <= NL; i++) {
    t = LT[i]; dd = DATE[LDOC[i]]
    if (t == "" || LCLIMB[i] || (t in ISMD) || mdtarget(t) != "" || !(t in DATE) || dd == "") continue
    key = LDOC[i] SUBSEP t; if (key in SEENL4) continue; SEENL4[key] = 1
    CHK["L4"]++
    lag = md_days(DATE[t]) - md_days(dd)
    if (lag > LAG) fail("L4", "Low", LDOC[i] ":" LLINE[i], LDOC[i] " last changed " dd "; " t ", which it links to, changed " DATE[t] " (" lag " days later, max " LAG "): check that it still describes it")
  }
  # DOC-L5 — a README at the root
  CHK["L5"]++
  if (!("README.md" in EXISTS)) fail("L5", "Medium", "README.md:absent", "no README at the repository root: nobody knows where to start")
  # DOC-P1 — persona entry points exist
  for (i = 1; i <= NP; i++) if (PL[i] != "") {
    split(PL[i], q, "="); CHK["P1"]++; ROOT[md_norm(q[2])] = q[1]
    if (!(md_norm(q[2]) in EXISTS)) fail("P1", "Medium", q[2] ":absent", "the entry point of the " q[1] " persona does not exist")
  }
  # DOC-P3 — the README says how to start
  if ("README.md" in INSET) { CHK["P3"]++; if (!README_START) fail("P3", "Low", "README.md:1", "the README has no getting-started section (install, setup, quick start or usage)") }
  # DOC-P2, DOC-P4 — every document is reachable from the README or a persona entry point
  if ("README.md" in ISMD) ROOT["README.md"] = "README"
  h = 0; tl = 0
  for (r in ROOT) if (r in ISMD) { DIST[r] = 0; Q[++tl] = r }
  while (h < tl) {
    u = Q[++h]; ne = split(EDGE[u], e, "\n")
    for (j = 1; j <= ne; j++) { v = mdtarget(e[j]); if (v != "" && !(v in DIST)) { DIST[v] = DIST[u] + 1; Q[++tl] = v } }
  }
  if (tl > 0) for (i = 1; i <= SETN; i++) {
    s = SETL[i]; if (s in ROOT) continue
    if (s !~ /\.md$/ && s !~ /\.MD$/) continue
    CHK["P2"]++
    if (!(s in DIST)) { fail("P2", "Low", s ":1", "no link reaches this document from the README or a persona entry point: readers will not find it"); continue }
    CHK["P4"]++
    if (DIST[s] > CLICKS) fail("P4", "Low", s ":1", "this document is " DIST[s] " links from the README or a persona entry point (max " CLICKS ")")
  }

  D["L1"] = "relative links resolve"; D["L2"] = "link anchors name a heading"; D["L3"] = "no stale markers older than the limit"
  D["L4"] = "documents not older than what they link to"; D["L5"] = "a README at the root"
  D["P1"] = "persona entry points exist"; D["P2"] = "every document reachable"; D["P3"] = "the README says how to start"; D["P4"] = "every document within the click limit"
  NA["L1"] = "no relative link"; NA["L2"] = "no link to a heading"; NA["L3"] = "no stale marker"
  NA["L4"] = (NOGIT != "" ? NOGIT : "no link from a document to a file with a git date"); NA["L5"] = ""
  NA["P1"] = "no persona in the contract (docs.personas)"; NA["P2"] = "no README or persona entry point to start from"; NA["P3"] = "no README"
  NA["P4"] = "no document reachable"
  split("L1 L2 L3 L4 L5 P1 P2 P3 P4", ORD, " "); NFAIL = 0
  for (i = 1; i <= 9; i++) {
    k = ORD[i]
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "DOC-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "DOC-" k, D[k], NA[k]
  }
  printf "%s", NOTES
  printf "check-docs: %d document(s), %d link(s), %d failure(s); it checks that the documents can be found and are kept, not that they are right\n", SETN, NL, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
