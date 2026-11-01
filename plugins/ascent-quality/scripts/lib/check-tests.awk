# check-tests.awk — the checks of check-tests.sh, which passes the file list and the
# ENVIRON values (QA_ID_PATTERN, QA_HELPERS, QA_PATHS). Loaded after qa-common.awk.
# A separate file keeps bash 3.2 from parsing the program. Run with LC_ALL=C.
BEGIN {
  IDRE = ENVIRON["QA_ID_PATTERN"]; if (IDRE == "") IDRE = "AC-[0-9]+([.][0-9]+)?"
  HELPRE = ENVIRON["QA_HELPERS"]; gsub(/,/, "|", HELPRE)
}
# ids LINE — every criterion id on the line, separated by spaces. An id must not
# sit inside a longer word (XAC-1, AC-1a).
function ids(s,   out, pre, post, id) {
  out = ""
  while (match(s, IDRE)) {
    if (RLENGTH <= 0) break   # an empty match would never advance
    id = substr(s, RSTART, RLENGTH)
    pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
    post = substr(s, RSTART + RLENGTH, 1)
    if (pre !~ /[A-Za-z0-9_-]/ && post !~ /[A-Za-z0-9_]/) out = out " " id
    s = substr(s, RSTART + RLENGTH)
  }
  return out
}
function endblock() {
  if (!INB) return
  INB = 0
  if (BSKIP || !BFN) return
  if (!BASSERT) fail("H3", "Medium", BSTART, "test " BNAME "has no assertion, so it passes whatever the code does (name a project helper with --helper)")
}
function newfile() {
  endblock()
  FN = FILENAME; sub(/^\.\//, "", FN); LG = lang(FN); KN[K]++
  MCOM = 0; MQ = ""; PREVCOM = 0; PYSKIP = ""; FENCE = 0; PYSIG = 0
  if (K == "core") {
    NCORE++; CF[NCORE] = FN
  }
  if (K == "t" || K == "td") {
    b = FN; sub(/^.*\//, "", b)
    key = b; sub(/\.(test|spec|cy|e2e)\.[A-Za-z]+$/, "", key); sub(/^test_/, "", key); sub(/(_test)?\.[A-Za-z]+$/, "", key); sub(/^test-/, "", key)
    TNAME[key] = 1
    if (LG == "go") { d = FN; if (d ~ /\//) sub(/\/[^\/]*$/, "", d); else d = "."; GODIR[d] = 1 }
  }
}
function hasassert(m, lg) {
  if (HELPRE != "" && m ~ ("(^|[^A-Za-z0-9_$.])(" HELPRE ")[ \t]*\\(")) return 1
  if (lg == "js") return (m ~ /(^|[^A-Za-z0-9_$])(expect|assert|should|expectTypeOf)[ \t]*[.(]/ || m ~ /(^|[^A-Za-z0-9_$.])assert[A-Z_][A-Za-z0-9_]*[ \t]*\(/ || m ~ /\.should[.(]|\.to\.|\.must\./ || m ~ /(^|[^A-Za-z0-9_$.])t\.(is|not|deepEqual|notDeepEqual|true|false|truthy|falsy|throws|throwsAsync|notThrows|notThrowsAsync|pass|fail|regex|notRegex|snapshot|like|equal|same|ok|match|assert)[ \t]*\(/ || m ~ /(^|[^A-Za-z0-9_$.])throw[ \t(]/ || m ~ /[Ss]napshot[ \t]*\(/)
  if (lg == "py") return (m ~ /(^|[^A-Za-z0-9_.])assert([ \t(]|$)/ || m ~ /self\.(assert[A-Za-z]*|fail)[ \t]*\(/ || m ~ /pytest\.(raises|warns|fail|approx)/ || m ~ /\.assert_[a-z_]*[ \t]*\(/ || m ~ /raise[ \t]+AssertionError/ || m ~ /(^|[^A-Za-z0-9_.])assert[A-Z_][A-Za-z0-9_]*[ \t]*\(/)
  if (lg == "go") return (m ~ /t\.(Error|Errorf|Fatal|Fatalf|Fail|FailNow)[ \t]*\(/ || m ~ /(^|[^A-Za-z0-9_])(assert|require|is|qt)\.[A-Z][A-Za-z0-9]*[ \t]*\(/ || m ~ /(^|[^A-Za-z0-9_.])Expect[ \t]*\(/ || m ~ /\(t[,)]/ || m ~ /t\.Run\([^,]*,[ \t]*[A-Za-z_][A-Za-z0-9_.]*\)/)
  # bats fails a test on any command that exits non-zero; only run (which never
  # fails), skip and declarations are not checks.
  if (lg == "bats") { t = trim(m); return (t != "" && t != "}" && t !~ /^(run|skip|local|export|declare|load|bats_load_library)([ \t]|$)/ && t !~ /^@test/) }
  return 0
}
function skipcall(m, lg) {
  if (lg == "js") return (m ~ /(^|[^A-Za-z0-9_$.])(it|test|describe|context|suite|specify)(\.describe)?\.(skip|todo|fixme)[ \t]*\(/ || m ~ /(^|[^A-Za-z0-9_$.])x(it|describe|test|context|specify)[ \t]*\(/)
  if (lg == "py") return (m ~ /^[ \t]*@(pytest\.mark\.skip|unittest\.skip|skip)([ \t(]|$)/ || m ~ /(pytest\.skip|self\.skipTest)[ \t]*\(/)
  if (lg == "go") return (m ~ /t\.(Skip|Skipf|SkipNow)[ \t]*\(/)
  if (lg == "bats") return (m ~ /^[ \t]*skip([ \t]|$)/)
  return 0
}
# A skip says why when it carries a message, or a comment sits on its line or the
# line above it.
function skipreason(raw, lg) {
  if (HADCOM || PREVCOM) return 1
  if (lg == "js") return (raw ~ /\.(skip|fixme)\([ \t]*[^"'`) \t][^,]*,[ \t]*["'`][^"'`]/)
  if (lg == "py") return (raw ~ /(skip|skipTest)\([ \t]*(reason[ \t]*=[ \t]*)?["'][^"']/)
  if (lg == "go") return (raw ~ /t\.Skipf?\([ \t]*["`][^"`]/)
  if (lg == "bats") return (raw ~ /^[ \t]*skip[ \t]+[^ \t]/)
  return 0
}
FNR == 1 { newfile() }
{ raw = $0; sub(/\r$/, "", raw) }
K == "doc" {
  # Ids in a code fence are examples, not criteria.
  if (raw ~ /^[ \t]*(```|~~~)/) { FENCE = !FENCE; next }
  if (FENCE) next
  s = ids(raw); n = split(s, I, " ")
  for (j = 1; j <= n; j++) if (!(I[j] in DEF)) { DEF[I[j]] = at(); NDEF++ }
  next
}
K == "cfg" || K == "pkg" || K == "ci" {
  c = raw
  if (c ~ /^[ \t]*(#|\/\/)/) next
  sub(/[ \t]+#.*$/, "", c)
  if (K == "ci") { if (c ~ /--reruns|--retries[ =]+[1-9]|--retry[ =]+[1-9]/) { fail("H4", "Low", at(), "CI reruns failing tests, so a flaky test passes without anyone fixing it") } ; next }
  if (FNR == 1) CHK["H4"]++
  if (c ~ /retries["']?[ \t]*[:=][^,}]*[1-9]|"retries"[ \t]*:[ \t]*\{|retry["']?[ \t]*:[ \t]*[1-9]|--reruns|reruns[ \t]*=[ \t]*[1-9]|--retries[ =]+[1-9]|--retry[ =]+[1-9]|retryTimes/) fail("H4", "Low", at(), "the test runner retries failing tests, so a flaky test passes without anyone fixing it")
  next
}
K == "core" { next }
K != "t" && K != "td" { next }
{
  addtokens(raw); typeflags(raw)
  s = ids(raw); n = split(s, I, " ")
  for (j = 1; j <= n; j++) if (!(I[j] in REF)) { REF[I[j]] = at(); NREF++ }
  if (LG != "js" && LG != "py" && LG != "go" && LG != "bats") next
  if (FNR == 1) { NTF++; CHK["H1"]++; CHK["H2"]++; CHK["H4"]++ }
  m = mask(raw, LG); t = trim(m)
  # Python: a line at or left of the def's indentation ends the test.
  # Not inside a signature that spans lines (PYSIG counts its open parentheses), nor
  # on a line that starts inside a triple-quoted string.
  if (INB && LG == "py" && t != "") {
    if (PYSIG > 0) { p = m; PYSIG += gsub(/\(/, "(", p) - gsub(/\)/, ")", p) }
    else if (!MSTART) { match(m, /^[ \t]*/); if (RLENGTH <= BIND) endblock() }
  }
  # JS: a new test at or left of the open one's indentation ends it.
  if (INB && LG == "js" && isblock(m, LG)) { match(m, /^[ \t]*/); if (RLENGTH <= BIND) endblock() }
  # QA-H1 — focused tests
  if ((LG == "js" && (m ~ /(^|[^A-Za-z0-9_$.])(it|test|describe|context|suite|specify)(\.describe)?\.only[ \t]*\(/ || m ~ /(^|[^A-Za-z0-9_$.])f(it|describe|context)[ \t]*\(/)) || (LG == "py" && m ~ /^[ \t]*@pytest\.mark\.only([ \t(]|$)/)) fail("H1", "High", at(), "a focused test (.only) makes the runner skip every other test in its file or suite, and CI passes on that part alone")
  # QA-H4 — retries in a test file
  if ((LG == "js" && m ~ /jest\.retryTimes[ \t]*\(|this\.retries[ \t]*\([ \t]*[1-9]|(describe|test)\.configure[ \t]*\([^)]*retries[ \t]*:[ \t]*[1-9]/) || (LG == "py" && m ~ /^[ \t]*@(pytest\.mark\.flaky|flaky)([ \t(]|$)/)) fail("H4", "Low", at(), "the test retries on failure, so a flaky test passes without anyone fixing it")
  sk = skipcall(m, LG)
  # QA-H2 — skipped tests
  if (sk) {
    if (skipreason(raw, LG)) note("H2", at(), "skipped with a reason; review it when the reason no longer holds")
    else fail("H2", "Medium", at(), "a skipped test with no reason given, so nobody knows when it can run again")
    if (INB) BSKIP = 1
    if (LG == "py" && m ~ /^[ \t]*@/) PYSKIP = 1
  }
  if (isblock(m, LG)) {
    endblock(); INB = 1; NBLK++; CHK["H3"]++
    match(m, /^[ \t]*/); BIND = RLENGTH; BSTART = at(); BASSERT = 0; BSKIP = (sk || PYSKIP); PYSKIP = ""
    BNAME = ""
    if ((LG == "py" || LG == "go") && match(raw, /(def|func)[ \t]+[A-Za-z0-9_]+/)) { BNAME = substr(raw, RSTART, RLENGTH); sub(/^(def|func)[ \t]+/, "", BNAME); BNAME = BNAME " " }
    else if (match(raw, /["'`][^"'`]+["'`]/)) BNAME = substr(raw, RSTART, RLENGTH) " "
    BFN = (LG != "js" || m ~ /=>|function/)
    PYSIG = 0; if (LG == "py") { p = m; PYSIG = gsub(/\(/, "(", p) - gsub(/\)/, ")", p) }
    if (hasassert(m, LG)) BASSERT = 1
    # JS counts parentheses from the test call; Go counts braces from the func.
    if (LG == "js") {
      p = m; sub(/^.*(it|test|specify)(\.[a-z]+)?[ \t]*\(/, "(", p)
      BDEPTH = gsub(/\(/, "(", p) - gsub(/\)/, ")", p)
      if (BDEPTH <= 0) { endblock(); PREVCOM = 0; next }
    }
    if (LG == "go") {
      p = m; BDEPTH = gsub(/\{/, "{", p) - gsub(/\}/, "}", p)
      if (BDEPTH <= 0 && index(m, "{")) { endblock(); PREVCOM = 0; next }
    }
    PREVCOM = 0
    next
  }
  if (INB) {
    if (hasassert(m, LG)) BASSERT = 1
    if (LG == "js") {
      if (!BFN && m ~ /=>|function/) BFN = 1
      BDEPTH += gsub(/\(/, "(", m) - gsub(/\)/, ")", m)
      if (BDEPTH <= 0) endblock()
    } else if (LG == "go") {
      BDEPTH += gsub(/\{/, "{", m) - gsub(/\}/, "}", m)
      if (BDEPTH <= 0) endblock()
    } else if (LG == "bats" && raw ~ /^}/) endblock()
  }
  # A comment-only line before a skip is its reason; a code line clears it.
  if (t == "" && HADCOM) PREVCOM = 1
  else if (t != "") PREVCOM = 0
}
END {
  endblock()
  # QA-T1, QA-T2, QA-T3 — criteria to tests
  if (NDEF == 0 && NREF == 0) {
    CHK["T3"]++; fail("T3", "Low", "absent: searched " ENVIRON["QA_DOCS"], "no criterion ids (" IDRE ") in the criteria documents or the tests, so traceability is unmeasured")
  } else CHK["T3"]++
  for (id in DEF) {
    CHK["T1"]++
    hit = (id in REF)
    if (!hit) for (r in REF) if (index(r, id ".") == 1) { hit = 1; break }
    if (!hit) fail("T1", "Medium", DEF[id], "acceptance criterion " id " is named by no test")
  }
  for (id in REF) {
    CHK["T2"]++
    pid = id; hit = (id in DEF)
    while (!hit && pid ~ /[.][0-9]+$/) { sub(/[.][0-9]+$/, "", pid); hit = (pid in DEF) }
    if (!hit) fail("T2", "Low", REF[id], "the test names " id ", which no criteria document defines (renamed or removed?)")
  }
  # QA-T4 — core rules to tests
  for (j = 1; j <= NCORE; j++) {
    f = CF[j]; CHK["T4"]++
    b = f; sub(/^.*\//, "", b); key = b; sub(/\.[A-Za-z]+$/, "", key)
    d = f; if (d ~ /\//) sub(/\/[^\/]*$/, "", d); else d = "."
    if (key ~ /^(index|main|__init__|mod|lib)$/) { key = d; sub(/^.*\//, "", key) }
    hit = (key in TOK) || (key in TNAME) || (lang(f) == "go" && (d in GODIR))
    if (!hit) fail("T4", "Medium", f ":1", "core rule source " key " is named by no test, so a change to it ships untested")
  }
  split("T1 T2 T3 T4 H1 H2 H3 H4", ORDER, " ")
  D["T1"] = "every acceptance criterion is named by a test"
  D["T2"] = "every criterion id a test names is defined"
  D["T3"] = "criterion ids exist, so traceability is measured"
  D["T4"] = "every core rule source is named by a test"
  D["H1"] = "no focused tests"
  D["H2"] = "skipped tests say why"
  D["H3"] = "every test asserts something"
  D["H4"] = "no retries that hide flaky tests"
  if (NCORE == 0) NA["T4"] = (ENVIRON["QA_CORE"] == "") ? " (no --core paths given)" : " (no source files under the --core paths)"
  for (j = 1; j <= 8; j++) {
    k = ORDER[j]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "QA-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (nothing to check%s)\n", "QA-" k, D[k], NA[k]
  }
  printf "%s", NOTES
  printf "check-tests: %d test file(s), %d test(s), %d criteria document(s), %d criterion id(s) defined, %d named in tests, %d core file(s), %d failure(s)\n", \
    KN["t"] + KN["td"], NBLK, KN["doc"], NDEF, NREF, NCORE, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
