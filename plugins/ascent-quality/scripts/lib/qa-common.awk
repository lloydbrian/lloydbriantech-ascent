# qa-common.awk — helpers shared by check-test-inventory.awk and check-tests.awk
# (awk -f qa-common.awk -f <check>.awk). Run with LC_ALL=C. POSIX awk only.
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function at() { return FN ":" FNR }
function fail(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "QA-" k, sev, where, msg); NF_[k]++; NFAIL++ }
function note(k, where, msg) { NOTES = NOTES sprintf("NOTE  %-7s %-6s %s  %s\n", "QA-" k, "-", where, msg) }
# lang FILE — js, py, go, bats, sh or other, by extension.
function lang(f) {
  if (f ~ /\.(js|jsx|ts|tsx|mjs|cjs|mts|cts)$/) return "js"
  if (f ~ /\.py$/) return "py"
  if (f ~ /\.go$/) return "go"
  if (f ~ /\.bats$/) return "bats"
  if (f ~ /\.(sh|bash)$/) return "sh"
  return "other"
}
# mask LINE LANG — the line with string contents and comments removed: quotes stay,
# their contents go, so 'skip("x")' reads skip(""). Sets HADCOM when the line has a
# comment. A /* */ comment, a backtick template and a Python triple-quoted string
# carry over to the next line (MCOM, MQ); reset both for each new file. MSTART is
# set when the line starts inside one, so its indentation means nothing.
function mask(s, lg,   out, i, j, c, n, q, nx) {
  HADCOM = 0; out = ""; n = length(s); i = 1; q = MQ; MQ = ""; MSTART = (q != "" || MCOM)
  if (MCOM) {
    j = index(s, "*/"); HADCOM = 1
    if (!j) return ""
    i = j + 2; MCOM = 0
  }
  while (i <= n) {
    c = substr(s, i, 1)
    if (q != "") {
      if (c == "\\") { i += 2; continue }
      if (substr(s, i, length(q)) == q) { out = out q; i += length(q); q = ""; continue }
      i++; continue
    }
    if (lg == "py" && (substr(s, i, 3) == "\"\"\"" || substr(s, i, 3) == "'''")) { q = substr(s, i, 3); out = out q; i += 3; continue }
    if (c == "\"" || c == "'" || (c == "`" && lg != "py")) { q = c; out = out c; i++; continue }
    if (lg == "py" || lg == "bats" || lg == "sh") { if (c == "#") { HADCOM = 1; break } }
    else {
      nx = substr(s, i, 2)
      if (nx == "//") { HADCOM = 1; break }
      if (nx == "/*") {
        HADCOM = 1; j = index(substr(s, i + 2), "*/")
        if (!j) { MCOM = 1; break }
        i = i + 2 + j + 1; continue
      }
    }
    out = out c; i++
  }
  if (q == "`" || length(q) == 3) MQ = q
  return out
}
# addtokens LINE — every word of a test file goes into TOK: module names, import
# paths and identifiers, split on anything but letters, digits, _ and -.
function addtokens(s,   n, i, W) {
  n = split(s, W, /[^A-Za-z0-9_-]+/)
  for (i = 1; i <= n; i++) if (W[i] != "") TOK[W[i]] = 1
  # Dotted file names (user.service) are named through their import paths.
  n = split(s, W, /[^A-Za-z0-9_.-]+/)
  for (i = 1; i <= n; i++) if (W[i] ~ /[A-Za-z0-9]\.[A-Za-z0-9]/) { sub(/^\.+/, "", W[i]); TOK[W[i]] = 1 }
}
# ttype FILE — unit, integration, contract or e2e, from the path, the name and what
# the file imports (E2EC, INTC, CONC, set while reading it).
function ttype(f,   b) {
  b = f; sub(/^.*\//, "", b)
  if (f ~ /(^|\/)(e2e|end-to-end|cypress|playwright|acceptance)\// || b ~ /\.(e2e|cy)\./ || b ~ /^e2e[-_.]/ || (f in E2EC)) return "e2e"
  if (f ~ /(^|\/)(contract|contracts|pact)\// || b ~ /(^|[-_.])(contract|contracts|pact)([-_.]|$)/ || (f in CONC)) return "contract"
  if (f ~ /(^|\/)(integration|integration-tests|it)\// || b ~ /integration|\.int\.|[-_]int[-_.]/ || (f in INTC)) return "integration"
  return "unit"
}
# typeflags LINE — marks the current test file by what it imports or declares.
function typeflags(s) {
  if (s ~ /@playwright\/test|from +["']playwright|require\(["']playwright|["']cypress["']|selenium-webdriver|from +selenium|["']puppeteer|["']webdriverio|testcafe/) E2EC[FN] = 1
  if (s ~ /@pact-foundation|from +pact |import +pact|pact-go/) CONC[FN] = 1
  if (s ~ /@pytest\.mark\.integration|^\/\/(go:build| \+build) .*integration/) INTC[FN] = 1
}
# isblock LINE LANG — the masked line starts a test block (it, test, def test_,
# func TestX, @test).
function isblock(m, lg) {
  if (lg == "js") return (m ~ /(^|[^A-Za-z0-9_$.])(it|test|specify)(\.(only|skip|todo|fixme|concurrent|serial|failing|each))?[ \t]*\(/ && m !~ /function[ \t]+(it|test|specify)[ \t]*\(|(const|let|var)[ \t]+(it|test|specify)[ \t]*=|(it|test|specify)[ \t]*=[ \t]*(function|\()/)
  if (lg == "py") return (m ~ /^[ \t]*(async[ \t]+)?def[ \t]+test[A-Za-z0-9_]*[ \t]*\(/)
  if (lg == "go") return (m ~ /^func[ \t]+Test[A-Za-z0-9_]*[ \t]*\(.*\*testing\.T[ \t]*\)/)
  if (lg == "bats") return (m ~ /^[ \t]*@test[ \t]/)
  return 0
}
