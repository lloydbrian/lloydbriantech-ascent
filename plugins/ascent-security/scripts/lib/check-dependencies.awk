# check-dependencies.awk — the checks of check-dependencies.sh, which passes the file
# list (K=<kind> before each file) and the options. Loaded after json.awk.
# Run with LC_ALL=C.
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function unq(s) { s = trim(s); if (s ~ /^".*"$/ || s ~ /^'.*'$/) s = substr(s, 2, length(s) - 2); return s }
function dirof(f) { if (index(f, "/") == 0) return "."; sub(/\/[^\/]*$/, "", f); return f }
function updir(d) { if (d == "." || d == "") return ""; if (index(d, "/") == 0) return "."; sub(/\/[^\/]*$/, "", d); return d }
function relto(base, d) { if (base == d) return ""; if (base == ".") return d; return substr(d, length(base) + 2) }
function pyname(n) { n = tolower(n); gsub(/[-_.]+/, "-", n); return n }
# A URL as printed: everything before the last "@" of the host part masked, the query
# string dropped, and path segments that look like tokens (20 or more letters and
# digits, mixed) masked.
function safeurl(u,   pre, auth, rest, n, a, i, out) {
  sub(/\?.*$/, "", u)
  if (!match(u, /\/\/[^\/]*/)) return u
  pre = substr(u, 1, RSTART + 1); auth = substr(u, RSTART + 2, RLENGTH - 2); rest = substr(u, RSTART + RLENGTH)
  if (match(auth, /.*@/)) auth = "***@" substr(auth, RLENGTH + 1)
  n = split(rest, a, "/"); out = ""
  for (i = 1; i <= n; i++) { if (length(a[i]) >= 20 && a[i] ~ /^[A-Za-z0-9_-]+$/ && a[i] ~ /[0-9]/ && a[i] ~ /[A-Za-z]/) a[i] = "***"; out = out (i > 1 ? "/" : "") a[i] }
  return pre auth out
}
# The URL compared with registries: scheme and host lowercased, user:password@ dropped.
function normurl(u,   h, r) {
  if (!match(u, /^[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\/?#]*/)) return u
  h = tolower(substr(u, 1, RLENGTH)); r = substr(u, RLENGTH + 1)
  sub(/:\/\/.*@/, "://", h)
  return h r
}
function fail(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "SEC-" k, sev, where, msg); NFK[k]++; NFAIL++ }
function note(k, msg) { NOTES = NOTES sprintf("NOTE  %-7s %s\n", "SEC-" k, msg) }
function info(k, msg) { INFOS = INFOS sprintf("INFO  %-7s %s\n", "SEC-" k, msg) }
function chk(k) { CHK[k]++ }
# Registries a dependency may come from: the public defaults and every --registry.
# A declared registry matches at a boundary: https://npm.corp.example allows
# https://npm.corp.example/x, never https://npm.corp.example.attacker.io/.
function allowed(u,   i, r) {
  u = normurl(u)
  if (u ~ /^https:\/\/(registry\.npmjs\.org|registry\.yarnpkg\.com|pypi\.org|files\.pythonhosted\.org)([\/?#]|$)/) return 1
  for (i = 1; i <= NREG; i++) { r = REG[i]
    if (index(u, r) == 1 && (r ~ /\/$/ || length(u) == length(r) || substr(u, length(r) + 1, 1) ~ /[\/?#]/)) return 1 }
  return 0
}
function srcsev(u) { return (tolower(u) ~ /^http:\/\//) ? "High" : "Medium" }
# An exact npm version (1.2.3, =1.2.3, v1.2.3, npm:name@1.2.3).
function npm_exact(s) { sub(/^npm:(@[^\/]+\/)?[^@]+@/, "", s); return s ~ /^[=v]?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$/ }
function npm_local(s) { return s ~ /^(file|link|workspace|portal|patch):/ || s ~ /^(\.\.?\/|\/|~\/)/ }
function npm_remote(s) { return s ~ /^(git|git\+[a-z]+|github|gitlab|bitbucket|gist|https?):/ || s ~ /^[A-Za-z0-9_][A-Za-z0-9_.-]*\/[A-Za-z0-9_.-]+(#.*)?$/ }
function unbounded(s,   n, a, i) {
  sub(/^npm:(@[^\/]+\/)?[^@]+@/, "", s)
  n = split(s, a, /\|\|/)
  for (i = 1; i <= n; i++) {
    a[i] = trim(a[i])
    if (a[i] == "" || a[i] ~ /^(\*|x|X|latest|next)$/) return 1
    if (a[i] ~ />/ && a[i] !~ /</) return 1
  }
  return 0
}
# PEP 508: the name, and whether the specifier is exact (== or ===, no wildcard).
function pep_name(s) { if (match(s, /^[A-Za-z0-9][A-Za-z0-9._-]*/)) return substr(s, 1, RLENGTH); return "" }
function pep_spec(s) { sub(/^[A-Za-z0-9][A-Za-z0-9._-]*/, "", s); sub(/^ *\[[^]]*\]/, "", s); sub(/;.*/, "", s); return trim(s) }
function pep_exact(sp) { return sp ~ /^===? *[0-9A-Za-z.!+-]+$/ }
function pep_unbounded(sp) { return sp == "" || sp ~ /\*/ && sp !~ /^==/ || (sp ~ />/ && sp !~ /</ && sp !~ /~=/) }
# Poetry and Pipfile specifiers: "1.2.3" or "==1.2.3" exact; "*" or ">=" unbounded.
function poetry_exact(sp) { sp = trim(sp); return sp ~ /^(==)?[0-9]+(\.[0-9]+)*([-.+]?[A-Za-z0-9.]+)?$/ && sp !~ /\*/ }
function poetry_unbounded(sp) { sp = trim(sp); return sp == "" || sp == "*" || (sp ~ />/ && sp !~ /</) }

# --- per-file state ---------------------------------------------------------------
function fileend() {
  if (FN == "") return
  if (PK == "py-req" || PK == "py-in") req_end()
  if (PK == "ignore-osv") osv_ignore_end()
  if (PK ~ /^(pyproject|pipfile|py-req|py-in|py-setup)$/ && NPY[FN] > 0) { MAN[++NM] = FN; MECO[FN] = "python" }
  if (PK == "cargo" && CDN[FN] > 0) { MAN[++NM] = FN; MECO[FN] = "cargo" }
  if (PK == "go-mod" && GOREQ[FN] > 0) { MAN[++NM] = FN; MECO[FN] = "go" }
  if (PK == "npm" && NDEP[FN] > 0) { MAN[++NM] = FN; MECO[FN] = "npm" }
}
function newfile() {
  fileend()
  FN = FILENAME; sub(/^\.\//, "", FN); PK = K; FD = dirof(FN); SEC = ""; ARR = ""; ACC = ""; json_reset()
  KIND[FN] = K; FL[++NFILES] = FN
  if (K == "npm") NNPM++
  if (K ~ /^(npm-lock|yarn-lock|pnpm-lock)$/) { LOCKAT["npm", FD] = LOCKAT["npm", FD] " " FN; NLOCK++ }
  if (K ~ /^(py-lock|pipfile-lock)$/) { LOCKAT["python", FD] = LOCKAT["python", FD] " " FN; NLOCK++ }
  if (K == "go-sum") { LOCKAT["go", FD] = LOCKAT["go", FD] " " FN; NLOCK++ }
  if (K == "cargo-lock") { LOCKAT["cargo", FD] = LOCKAT["cargo", FD] " " FN; NLOCK++ }
  if (K == "node-version") ENGDIR["npm", FD] = 1
  if (K == "python-version") ENGDIR["python", FD] = 1
  if (K ~ /^ignore-/) NIGN++
  if (K == "py-req" || K == "py-in") { NRQ = 0; RQALL = 1 }
}
BEGIN {
  NREG = split(trim(REGS), REG, / +/)
  for (i = 1; i <= NREG; i++) { REGNAME[REG[i]] = 1; REG[i] = normurl(REG[i]) }
  n = split(tolower(DENY), t, ","); for (i = 1; i <= n; i++) if (trim(t[i]) != "") DENIED[trim(t[i])] = 1
  n = split(WAIVED, t, ","); for (i = 1; i <= n; i++) if (trim(t[i]) != "") WAIVE[toupper(trim(t[i]))] = 1
  HAVEDENY = (DENY ~ /[A-Za-z]/)
}
FNR == 1 { newfile() }
K == "none" { next }
{ line = $0; sub(/\r$/, "", line) }

# --- npm: package.json and package-lock.json are JSON --------------------------------
K == "npm" || K == "npm-lock" || K == "pipfile-lock" || K == "ignore-json" { json_feed(line, FNR); next }
function on_json(p, v, l,   n, s1, s2, s3, key) {
  n = jlen(p); s1 = jseg(p, 1); s2 = jseg(p, 2); s3 = jseg(p, 3)
  if (K == "npm") {
    if (n == 2 && (s1 == "dependencies" || s1 == "devDependencies" || s1 == "optionalDependencies") && JK == "s") {
      NDEP[FN]++; DEP[FN, s2] = v; DLINE[FN, s2] = l; DNAME[FN, NDEP[FN]] = s2
    }
    if (n == 2 && (s1 == "engines" || s1 == "volta") && s2 == "node") ENG[FN] = 1
    return
  }
  if (K == "npm-lock") {
    if (n == 1 && s1 == "lockfileVersion") LVER[FN] = v
    if (s1 == "packages" && n >= 2) {
      key = FN SUBSEP s2
      LHAS[key] = 1
      if (n == 4 && (s3 == "dependencies" || s3 == "devDependencies" || s3 == "optionalDependencies")) { LDEP[FN, s2, jseg(p, 4)] = v; LDN[key]++; LDNAME[key, LDN[key]] = jseg(p, 4) }
      if (n == 3 && s3 == "resolved" && s2 != "") lock_source(FN, s2, v, l)
      if (n == 3 && s3 == "link" && v == "true") LLINK[key] = 1
      if (n == 3 && s3 == "license" && s2 != "") lock_licence(FN, s2, v, l)
    }
    # the legacy dependencies section: read for lockfile v1 only (v2 repeats packages)
    if (s1 == "dependencies" && n == 3 && LVER[FN] + 0 < 2 && jseg(p, 3) == "version") LV1[FN, s2] = 1
    if (s1 == "dependencies" && n == 3 && LVER[FN] + 0 < 2 && jseg(p, 3) == "resolved") lock_source(FN, "node_modules/" s2, v, l)
    return
  }
  if (K == "pipfile-lock") {
    if ((s1 == "default" || s1 == "develop") && n >= 2) PYLOCK[FN, pyname(s2)] = 1
    return
  }
  if (K == "ignore-json") {
    # .nsprc: top-level keys are advisory ids; audit-ci: the allowlist array.
    if (FN ~ /(^|\/)\.nsprc$/ && n >= 1) { if (!((FN, s1) in IGSEEN)) { IGSEEN[FN, s1] = 1; ignore_entry(s1, l, "") } }
    else if (s1 == "allowlist" && n == 2 && JK == "s") ignore_entry(v, l, "")
    else if (s1 == "allowlist" && n == 3 && s3 == "id") ignore_entry(v, l, "")
    return
  }
}
function lock_source(f, pkg, u, l,   host) {
  if (u == "" || u ~ /^[Ff][Ii][Ll][Ee]:/ || (u !~ /^[A-Za-z][A-Za-z0-9+.-]*:/ && u !~ /^git@/)) return  # a relative path is a local or workspace package
  chk("D5")
  if (allowed(u)) return
  host = u; if (match(host, /^[a-z+]+:\/\/[^\/]+/)) host = substr(host, 1, RLENGTH); else sub(/[#:].*$/, "", host)
  if (!((f, host) in SRCN)) { SRCK[f, ++SRCH[f]] = host; SRCL[f, host] = l; SRCP[f, host] = pkg; SRCU[f, host] = u }
  SRCN[f, host]++
}
# An SPDX expression is acceptable when some choice it allows avoids every denied
# licence: OR needs one acceptable side, AND both; parentheses group; WITH binds an
# exception to its licence.
function lic_ok(s) { gsub(/\(/, " ( ", s); gsub(/\)/, " ) ", s); LTN = split(trim(s), LT, /[ \t]+/); LTP = 1; LDEN = ""; return lic_or() }
function lic_or(   ok, r) { ok = lic_and(); while (LTP <= LTN && toupper(LT[LTP]) == "OR") { LTP++; r = lic_and(); if (r) ok = 1 } return ok }
function lic_and(   ok, r) { ok = lic_atom(); while (LTP <= LTN && toupper(LT[LTP]) == "AND") { LTP++; r = lic_atom(); if (!r) ok = 0 } return ok }
function lic_atom(   t, ok) {
  if (LTP > LTN) return 1
  t = LT[LTP++]
  if (t == "(") { ok = lic_or(); if (LTP <= LTN && LT[LTP] == ")") LTP++; return ok }
  if (LTP <= LTN && toupper(LT[LTP]) == "WITH") LTP += 2
  if (tolower(t) in DENIED) { LDEN = t; return 0 }
  return 1
}
function lock_licence(f, pkg, lic, l,   ok, den) {
  NLIC[f]++
  if (!HAVEDENY) return
  chk("D6")
  ok = lic_ok(lic); den = LDEN
  if (!ok) { sub(/^node_modules\//, "", pkg); gsub(/\/node_modules\//, " > ", pkg); if (++NDL[f] <= 10) fail("D6", "High", f ":" l, pkg " is licensed " lic ", which security.dependencies.licences_denied lists (" den ")"); else NDLX[f]++ }
}

# --- yarn.lock (v1 and berry) --------------------------------------------------------
K == "yarn-lock" {
  if (line ~ /^[^ #]/ && line ~ /:$/) {
    h = substr(line, 1, length(line) - 1); n = split(h, d, /, */)
    for (i = 1; i <= n; i++) { x = trim(d[i]); sub(/^"/, "", x); sub(/"$/, "", x); YD[FN, x] = 1; YCUR = x }
    next
  }
  if (match(line, /^  (resolved|resolution):? +"?/)) {
    u = substr(line, RLENGTH + 1); sub(/"$/, "", u)
    if (line ~ /resolution:/) { sub(/^(@[^\/@]+\/)?[^@]+@/, "", u); if (u ~ /^npm:/ || u ~ /^workspace:/ || u ~ /^(file|link|portal|patch):/) next }
    lock_source(FN, YCUR, u, FNR)
  }
  next
}
# --- pnpm-lock.yaml -----------------------------------------------------------------
K == "pnpm-lock" {
  if (line ~ /^[^ #]/) { PTOP = line; sub(/:.*/, "", PTOP); PIMP = (PTOP == "specifiers" || PTOP == "dependencies" || PTOP == "devDependencies" || PTOP == "optionalDependencies") ? "." : ""; PSECT = PTOP; next }
  if (PTOP == "importers") {
    if (match(line, /^  [^ ]/)) { PIMP = unq(substr(line, 3)); sub(/:$/, "", PIMP); PIMP = unq(PIMP); next }
    if (match(line, /^    [a-zA-Z]+:$/)) { PSECT = trim(line); sub(/:$/, "", PSECT); next }
    if (match(line, /^      [^ ]/)) { pnpm_name(PIMP); next }
    if (line ~ /^        specifier:/) { s = line; sub(/^ *specifier: */, "", s); PSP[FN, PIMP, PNAME] = unq(s); next }
    next
  }
  if (PTOP == "specifiers" && match(line, /^  [^ ]/)) { s = trim(line); n = index(s, ":"); PSP[FN, ".", unq(substr(s, 1, n - 1))] = unq(substr(s, n + 1)); next }
  # a single-project lockfile: top-level dependencies (v6: a specifier under each name)
  if (PIMP == "." && PTOP != "specifiers") {
    if (match(line, /^  [^ ]/)) { PSECT = "deps"; pnpm_name("."); next }
    if (line ~ /^    specifier:/) { s = line; sub(/^ *specifier: */, "", s); PSP[FN, ".", PNAME] = unq(s); next }
    next
  }
  if (PTOP == "packages" || PTOP == "snapshots") {
    if (match(line, /^  [^ ]/)) { PCUR = trim(line); sub(/:$/, "", PCUR); PCUR = unq(PCUR) }
    if (match(line, /tarball: *[^,}]+/)) { u = substr(line, RSTART, RLENGTH); sub(/^tarball: */, "", u); lock_source(FN, PCUR, unq(u), FNR) }
    if (match(line, /repo: *[^,}]+/)) { u = substr(line, RSTART, RLENGTH); sub(/^repo: */, "", u); lock_source(FN, PCUR, unq(u), FNR) }
  }
  next
}
# A dependency name line under an importer: v5 keeps the specifier on the line in its
# specifiers section; later versions put it on a specifier: line below.
function pnpm_name(imp,   s, n) {
  s = trim(line); n = index(s, ":"); PNAME = unq(substr(s, 1, n - 1))
  if (PSECT == "specifiers") PSP[FN, imp, PNAME] = unq(trim(substr(s, n + 1)))
  else if (!((FN, imp, PNAME) in PSP)) PSP[FN, imp, PNAME] = "?"
}
# --- .npmrc: registry lines only; nothing else is read into the output ----------------
K == "npmrc" {
  if (match(line, /^[ \t]*(@[^:=]+:)?registry[ \t]*=/)) {
    u = trim(substr(line, RLENGTH + 1)); chk("D5")
    if (!allowed(u)) fail("D5", srcsev(u), FN ":" FNR, "the registry " safeurl(u) " is not the public default or a declared registry (security.dependencies.registries)" (u ~ /^http:/ ? ", and it is plain http://" : ""))
  }
  next
}

# --- Python ---------------------------------------------------------------------------
function py_dep(f, name, spec, l, kind,   nn) {
  if (name == "" || tolower(name) == "python") return
  nn = pyname(name)
  if ((f, nn) in PYD) return
  PYD[f, nn] = l; PYS[f, nn] = spec; PYK[f, nn] = kind; NPY[f]++; PYN[f, NPY[f]] = nn
}
function pep508(f, s, l,   nm, sp, u) {
  s = trim(s); if (s == "") return
  nm = pep_name(s); if (nm == "") return
  if (match(s, /@ *[a-z+]+:\/\/[^ ;]+/)) { u = substr(s, RSTART, RLENGTH); sub(/^@ */, "", u); chk("D5"); if (!allowed(u)) fail("D5", srcsev(u), f ":" l, nm " comes from a direct URL (" safeurl(u) ")"); return }
  sp = pep_spec(s); py_dep(f, nm, sp, l, "pep")
}
function py_source(f, u, l, what) { chk("D5"); if (!allowed(u)) fail("D5", srcsev(u), f ":" l, what " " safeurl(u) " is not the public default or a declared registry (security.dependencies.registries)" (u ~ /^http:/ ? ", and it is plain http://" : "")) }
K == "py-req" || K == "py-in" {
  s = line; sub(/(^| )#.*$/, "", s)
  if (ACC != "") { s = ACC " " s; l0 = ACCL } else l0 = FNR
  if (s ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/, "", s); ACC = s; ACCL = l0; next }
  ACC = ""; s = trim(s); if (s == "") next
  if (match(s, /^(-i|--index-url|--extra-index-url)[ =]+/)) { u = trim(substr(s, RLENGTH + 1)); py_source(FN, u, l0, (s ~ /extra/ ? "the extra index" : "the index")); next }
  if (match(s, /^(-f|--find-links)[ =]+/)) { u = trim(substr(s, RLENGTH + 1)); if (u ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\// && u !~ /^[Ff][Ii][Ll][Ee]:/) py_source(FN, u, l0, "the find-links location"); next }
  if (match(s, /^--editable[ =]+/)) s = "-e " substr(s, RLENGTH + 1)
  if (match(s, /^--trusted-host[ =]+/)) { chk("D5"); fail("D5", "Medium", FN ":" l0, "--trusted-host " trim(substr(s, RLENGTH + 1)) " turns off TLS verification for that host"); next }
  if (s ~ /^-(r|c|-requirement|-constraint)[ =]/ || s ~ /^--?[a-z]/ && s !~ /^-e /) next
  if (s ~ /^-e / || s ~ /^(git\+|hg\+|svn\+|bzr\+|https?:\/\/)/) {
    u = s; sub(/^-e +/, "", u); sub(/ .*/, "", u)
    if (u ~ /^(\.|\/|~|[Ff][Ii][Ll][Ee]:)/) next  # a local project (pip-compile writes -e file:.)
    chk("D5"); fail("D5", srcsev(u), FN ":" l0, "a requirement installed from " safeurl(u))
    RQALL = 0; next
  }
  sub(/ --hash[= ][^ ]+/, "", s); gsub(/ --hash[= ][^ ]+/, "", s)
  nm = pep_name(s); if (nm == "") next
  if (match(s, /@ *[a-z+]+:\/\/[^ ;]+/)) { u = substr(s, RSTART, RLENGTH); sub(/^@ */, "", u); chk("D5"); if (!allowed(u)) fail("D5", srcsev(u), FN ":" l0, nm " comes from a direct URL (" safeurl(u) ")"); RQALL = 0; next }
  sp = pep_spec(s)
  NRQ++; RQN[NRQ] = nm; RQS[NRQ] = sp; RQL[NRQ] = l0
  if (!pep_exact(sp)) RQALL = 0
  next
}
# A requirements file whose every requirement is pinned exactly is a lockfile (pip-compile
# output); otherwise it is a manifest. A .in file is always a manifest.
function req_end(   i) {
  if (NRQ == 0) return
  if (PK == "py-req" && RQALL) { LOCKAT["python", FD] = LOCKAT["python", FD] " " FN; NLOCK++; for (i = 1; i <= NRQ; i++) PYLOCK[FN, pyname(RQN[i])] = 1; REQLOCK[FN] = 1; return }
  for (i = 1; i <= NRQ; i++) py_dep(FN, RQN[i], RQS[i], RQL[i], "pep")
}
# setup.cfg is INI: install_requires is a list of unquoted lines, indented under the key.
K == "py-setup" && FN ~ /(^|\/)setup\.cfg$/ {
  s = line; if (s ~ /^[ \t]*[#;]/ || s ~ /^[ \t]*$/) next
  if (ARR == "install") { if (s ~ /^[ \t]/) { sub(/[ \t]+[#;].*$/, "", s); pep508(FN, s, FNR); next } ARR = "" }
  if (match(s, /^\[[^]]+\]/)) { SEC = substr(s, 2, RLENGTH - 2); next }
  if (SEC == "options" && match(s, /^install_requires[ \t]*[=:]/)) { ARR = "install"; v = trim(substr(s, RLENGTH + 1)); if (v != "") pep508(FN, v, FNR); next }
  if (SEC == "options" && s ~ /^python_requires[ \t]*[=:]/) ENG[FN] = 1
  next
}
# setup.py: the quoted strings of install_requires=[...], and python_requires.
K == "py-setup" {
  s = line; sub(/[ \t]+#.*$/, "", s); if (s ~ /^[ \t]*#/) next
  if (s ~ /python_requires[ \t]*=/) ENG[FN] = 1
  if (ARR == "") { if (!match(s, /install_requires[ \t]*=[ \t]*[\[(]/)) next; ARR = "install"; s = substr(s, RSTART + RLENGTH) }
  toml_strings(s, FNR); gsub(/"([^"\\]|\\.)*"|'[^']*'/, "", s); if (s ~ /[\])]/) ARR = ""
  next
}
K == "pyproject" || K == "pipfile" || K == "cargo" || K == "cargo-lock" || K == "py-lock" || K == "ignore-osv" {
  s = line; if (s !~ /^[ \t]*["']/) sub(/[ \t]+#.*$/, "", s); if (s ~ /^[ \t]*#/) next
  if (match(s, /^[ \t]*\[\[?[^]]+\]\]?[ \t]*$/)) { if (K == "ignore-osv") osv_ignore_end(); SEC = trim(s); gsub(/^\[\[?|\]\]?$/, "", SEC); SEC = trim(SEC); ARR = ""; if (SEC == "package" || SEC == "IgnoredVulns" || SEC == "tool.uv.index" || SEC == "tool.poetry.source" || SEC == "source") TBL++; next }
  toml_line(s, FNR)
  next
}
function toml_kv(s, kv) { if (!match(s, /^[ \t]*[A-Za-z0-9_."'-]+[ \t]*=/)) return 0; kv["k"] = unq(trim(substr(s, 1, RLENGTH - 1))); kv["v"] = trim(substr(s, RLENGTH + 1)); return 1 }
function inline(v, key,   r) { if (match(v, key "[ \t]*=[ \t]*(\"[^\"]*\"|'[^']*'|[A-Za-z0-9_.-]+)")) { r = substr(v, RSTART, RLENGTH); sub(/^[^=]*=[ \t]*/, "", r); return unq(r) } return "" }
function toml_strings(v, l,   t) {  # every quoted string on the line, for arrays
  while (match(v, /"([^"\\]|\\.)*"|'[^']*'/)) { t = substr(v, RSTART + 1, RLENGTH - 2); v = substr(v, RSTART + RLENGTH); arr_item(t, l) }
}
function arr_item(t, l) {
  if (K == "pyproject" && (ARR == "deps" || ARR == "opt" || ARR == "group")) pep508(FN, t, l)
  if (K == "py-setup" && ARR == "install") pep508(FN, t, l)
}
# The array ends at a "]" outside quoted strings; {include-group = ...} tables are not
# dependencies.
function arr_closes(v) { gsub(/"([^"\\]|\\.)*"|'[^']*'/, "", v); return v ~ /\]/ }
function arr_feed(v, l) { gsub(/\{[^}]*\}/, "", v); toml_strings(v, l); if (arr_closes(v)) ARR = "" }
function toml_line(s, l,   kv, k, v, g, u, reg, nm) {
  if (ARR != "") { arr_feed(s, l); return }
  if (!toml_kv(s, kv)) return
  k = kv["k"]; v = kv["v"]
  if (K == "pyproject") {
    if (SEC == "project" && k == "requires-python") ENG[FN] = 1
    if (SEC == "project" && k == "dependencies") { ARR = "deps"; arr_feed(v, l); return }
    if (SEC == "project.optional-dependencies" || SEC == "dependency-groups") { ARR = (SEC == "dependency-groups" ? "group" : "opt"); arr_feed(v, l); return }
    if (SEC ~ /^tool\.poetry(\.group\.[^.]+)?\.(dev-)?dependencies$/) {
      if (k == "python") { ENG[FN] = 1; return }
      if (v ~ /^\{/) { g = inline(v, "git"); u = inline(v, "url")
        if (g != "") { chk("D5"); fail("D5", srcsev(g), FN ":" l, k " comes from git (" safeurl(g) ")") }
        if (u != "") { chk("D5"); if (!allowed(u)) fail("D5", srcsev(u), FN ":" l, k " comes from a URL (" safeurl(u) ")") }
        if (g != "" || u != "" || inline(v, "path") != "") return
        py_dep(FN, k, inline(v, "version"), l, "poetry"); return }
      py_dep(FN, k, unq(v), l, "poetry"); return
    }
    if (SEC == "tool.uv.sources" && v ~ /^\{/) { g = inline(v, "git"); u = inline(v, "url")
      if (g != "") { chk("D5"); fail("D5", srcsev(g), FN ":" l, k " comes from git (" safeurl(g) ")") }
      if (u != "") { chk("D5"); if (!allowed(u)) fail("D5", srcsev(u), FN ":" l, k " comes from a URL (" safeurl(u) ")") }
      return }
    if ((SEC == "tool.uv.index" || SEC == "tool.poetry.source") && k == "url") { py_source(FN, unq(v), l, "the package index"); return }
    return
  }
  if (K == "pipfile") {
    if (SEC == "requires" && k ~ /^python_(full_)?version$/) { ENG[FN] = 1; return }
    if (SEC == "source" && k == "url") { py_source(FN, unq(v), l, "the package index"); return }
    if (SEC == "packages" || SEC == "dev-packages") {
      if (v ~ /^\{/) { g = inline(v, "git"); if (g != "") { chk("D5"); fail("D5", srcsev(g), FN ":" l, k " comes from git (" safeurl(g) ")") }
        if (g != "" || inline(v, "path") != "" || inline(v, "file") != "") return
        py_dep(FN, k, inline(v, "version"), l, "poetry"); return }
      py_dep(FN, k, unq(v), l, "poetry")
    }
    return
  }
  if (K == "py-lock") { if (SEC == "package" && k == "name") PYLOCK[FN, pyname(unq(v))] = 1; return }
  # an [[IgnoredVulns]] entry is recorded at the next header or the end of the file, so
  # ignoreUntil may come before or after id
  if (K == "ignore-osv") { if (SEC == "IgnoredVulns" && k == "id") { OIGID = unq(v); OIGL = l } if (SEC == "IgnoredVulns" && k == "ignoreUntil") OIGEXP = substr(unq(v), 1, 10); return }
  # Cargo.lock: package sources other than crates.io (SEC-D5)
  if (K == "cargo-lock") {
    if (SEC == "package" && k == "name") CLNAME = unq(v)
    if (SEC == "package" && k == "source") { u = unq(v)
      if (u == "registry+https://github.com/rust-lang/crates.io-index" || u == "sparse+https://index.crates.io/") return
      sub(/^(registry|sparse)\+/, "", u); lock_source(FN, CLNAME, u, l) }
    return
  }
  if (K == "cargo") {
    if (SEC ~ /^(patch\.[^.]+|replace)$/) {
      if (v ~ /^\{/) { g = inline(v, "git"); if (g != "") { chk("D5"); fail("D5", srcsev(g), FN ":" l, k " is patched from git (" safeurl(g) ")") } }
      return
    }
    if (SEC ~ /^patch\.[^.]+\.[^.]+$/ && k == "git") { nm = SEC; sub(/^.*\./, "", nm); chk("D5"); fail("D5", srcsev(unq(v)), FN ":" l, nm " is patched from git (" safeurl(unq(v)) ")"); return }
    if (SEC ~ /(^|\.)(dev-|build-)?dependencies$/) {
      nm = k; sub(/\.workspace$/, "", nm)
      if (k ~ /\.workspace$/) return
      CDN[FN]++
      if (v ~ /^\{/) { g = inline(v, "git"); reg = inline(v, "registry")
        if (g != "") { chk("D5"); fail("D5", srcsev(g), FN ":" l, nm " comes from git (" safeurl(g) ")") }
        if (reg != "") { chk("D5"); if (!(reg in REGNAME)) fail("D5", "Medium", FN ":" l, nm " comes from the registry \"" reg "\", not crates.io or a declared registry") } }
      return
    }
    if (SEC ~ /(^|\.)(dev-|build-)?dependencies\.[^.]+$/) {
      if (k == "git") { nm = SEC; sub(/^.*\./, "", nm); chk("D5"); fail("D5", srcsev(unq(v)), FN ":" l, nm " comes from git (" safeurl(unq(v)) ")") }
      if (k == "registry" && !(unq(v) in REGNAME)) { nm = SEC; sub(/^.*\./, "", nm); chk("D5"); fail("D5", "Medium", FN ":" l, nm " comes from the registry \"" unq(v) "\", not crates.io or a declared registry") }
      if (k == "version" || k == "git" || k == "registry") { if (!(SEC in CSEEN)) { CSEEN[SEC] = 1; CDN[FN]++ } }
    }
    return
  }
}
# --- Go ---------------------------------------------------------------------------------
K == "go-mod" {
  s = line; sub(/\/\/.*/, "", s); s = trim(s)
  if (s ~ /^require[ \t]*\($/) { GOB = "require"; next }
  if (s ~ /^replace[ \t]*\($/) { GOB = "replace"; next }
  if (s == ")") { GOB = ""; next }
  if (s ~ /^require[ \t]/) { GOREQ[FN]++; next }
  if (GOB == "require" && s != "") { GOREQ[FN]++; next }
  if (s ~ /^replace[ \t]/) { s = substr(s, 9); GOB2 = 1 } else if (GOB == "replace" && s != "") GOB2 = 1; else GOB2 = 0
  if (GOB2 && (i = index(s, "=>")) > 0) {
    to = trim(substr(s, i + 2)); from = trim(substr(s, 1, i - 1)); chk("D5")
    split(from, fa, /[ \t]+/); split(to, ta, /[ \t]+/)
    if (to !~ /^(\.|\/)/ && fa[1] != ta[1]) fail("D5", "Medium", FN ":" FNR, from " is replaced by another module (" to "); verify that source")
  }
  next
}
# --- Scanner ignore files (SEC-D10) ------------------------------------------------------
function ignore_entry(id, l, until) { NIG++; IGF[NIG] = FN; IGI[NIG] = id; IGLN[NIG] = l; IGEXP[NIG] = until }
function osv_ignore_end() { if (OIGID != "") ignore_entry(OIGID, OIGL, OIGEXP); OIGID = ""; OIGEXP = "" }
K == "ignore-trivy" {
  s = line; sub(/#.*/, "", s); s = trim(s); if (s == "") next
  n = split(s, t, /[ \t]+/); e = ""
  for (i = 2; i <= n; i++) if (t[i] ~ /^exp:/) e = substr(t[i], 5, 10)
  ignore_entry(t[1], FNR, e); next
}
K == "ignore-trivy-yaml" {
  if (match(line, /^[ \t]*- +id: */)) { ignore_entry(unq(substr(line, RLENGTH + 1)), FNR, ""); next }
  if (match(line, /^[ \t]+expired_at: */) && NIG > 0 && IGF[NIG] == FN) IGEXP[NIG] = substr(unq(substr(line, RLENGTH + 1)), 1, 10)
  next
}

# --- Rules at the end ---------------------------------------------------------------------
# The nearest directory at or above D holding a lockfile of ecosystem ECO.
function lockdir(eco, d) { while (d != "") { if ((eco, d) in LOCKAT) return d; d = updir(d) } return "" }
function engine_near(eco, d) { while (d != "") { if ((eco, d) in ENGDIR) return 1; d = updir(d) } return 0 }
function untracked(f) { return index(UNTRACKED, "|" f "|") > 0 }
function covering(eco, d,   ld, n, a, i, out) {  # the tracked lockfiles at the nearest lock directory
  ld = lockdir(eco, d); if (ld == "") return ""
  n = split(trim(LOCKAT[eco, ld]), a, / +/); out = ""
  for (i = 1; i <= n; i++) { if (untracked(a[i])) { UNTR = a[i]; continue } out = out " " a[i] }
  return trim(out)
}
function first_line(f) { return (DNAME[f, 1] != "" ? DLINE[f, DNAME[f, 1]] : 1) }
# SEC-D5 from the manifest, where no lockfile records the sources.
function npm_manifest_sources(f,   i, nm, sp) {
  for (i = 1; i <= NDEP[f]; i++) { nm = DNAME[f, i]; sp = DEP[f, nm]
    if (npm_remote(sp)) { chk("D5"); fail("D5", (sp ~ /^http:/ ? "High" : "Medium"), f ":" DLINE[f, nm], nm " comes from " safeurl(sp)) } }
}
function npm_rules(f,   d, locks, n, a, i, j, lk, rel, diffs, nd, nm, sp, got, nr, ex, nx, cov, ld, ur) {
  d = dirof(f)
  # SEC-D2: ranges
  chk("D2"); nr = 0; ex = ""
  for (i = 1; i <= NDEP[f]; i++) { nm = DNAME[f, i]; sp = DEP[f, nm]
    if (npm_local(sp) || npm_remote(sp)) continue
    if (PINNING == "exact" ? !npm_exact(sp) : unbounded(sp)) { nr++; if (ex == "") { ex = nm " " safeurl(sp); exl = DLINE[f, nm] } } }
  if (nr > 0) fail("D2", "Low", f ":" exl, nr " of " NDEP[f] " dependencies use " (PINNING == "exact" ? "ranges under version_pinning exact" : "unbounded ranges") " (first: " ex ")")
  # SEC-D4: engine constraint
  chk("D4"); if (!ENG[f] && !engine_near("npm", d)) fail("D4", "Low", f ":1", "no engines.node, volta.node, .nvmrc or .node-version: the Node.js version is not declared")
  UNTR = ""; locks = covering("npm", d)
  # SEC-D1 and SEC-D3
  chk("D1")
  if (locks == "") {
    npm_manifest_sources(f)
    if (LOCKREQ == "yes") {
      if (UNTR != "") fail("D1", "Medium", f ":1", "the lockfile " UNTR " is not tracked by git, so no one else installs the versions it records")
      else fail("D1", "Medium", f ":1", NDEP[f] " dependencies and no package-lock.json, yarn.lock or pnpm-lock.yaml here or above")
    }
    return
  }
  ld = lockdir("npm", d); rel = relto(ld, d)
  n = split(locks, a, / +/); cov = 0
  for (i = 1; i <= n; i++) {
    lk = a[i]; chk("D3"); diffs = ""; nd = 0
    if (KIND[lk] == "npm-lock") {
      if (!((lk, rel) in LHAS)) {
        if (rel == "" && LVER[lk] + 0 < 2) { cov = 1; for (j = 1; j <= NDEP[f]; j++) { nm = DNAME[f, j]; if (!((lk, nm) in LV1)) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm " is not in the lockfile"; fdl = DLINE[f, nm] } } }
        else continue
      } else {
        cov = 1
        for (j = 1; j <= NDEP[f]; j++) { nm = DNAME[f, j]; sp = DEP[f, nm]
          if (!((lk, rel, nm) in LDEP)) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm " is not in the lockfile"; if (nd == 1) fdl = DLINE[f, nm] }
          else if (LDEP[lk, rel, nm] != sp) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm ": manifest " safeurl(sp) ", lockfile " safeurl(LDEP[lk, rel, nm]); if (nd == 1) fdl = DLINE[f, nm] } }
        key = lk SUBSEP rel
        for (j = 1; j <= LDN[key]; j++) { nm = LDNAME[key, j]; if (!((f, nm) in DEP)) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm " is in the lockfile but not the manifest"; if (nd == 1) fdl = 1 } }
      }
    } else if (KIND[lk] == "yarn-lock") {
      cov = 1
      for (j = 1; j <= NDEP[f]; j++) { nm = DNAME[f, j]; sp = DEP[f, nm]
        if (npm_local(sp)) continue
        if (!((lk, nm "@" sp) in YD) && !((lk, nm "@npm:" sp) in YD)) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm "@" safeurl(sp) " has no yarn.lock entry"; if (nd == 1) fdl = DLINE[f, nm] } }
    } else if (KIND[lk] == "pnpm-lock") {
      ur = (rel == "" ? "." : rel)
      cov = 1
      for (j = 1; j <= NDEP[f]; j++) { nm = DNAME[f, j]; sp = DEP[f, nm]
        if (!((lk, ur, nm) in PSP)) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm " is not in the lockfile"; if (nd == 1) fdl = DLINE[f, nm] }
        else if (PSP[lk, ur, nm] != "?" && PSP[lk, ur, nm] != sp) { nd++; if (nd <= 3) diffs = diffs (diffs == "" ? "" : "; ") nm ": manifest " safeurl(sp) ", lockfile " safeurl(PSP[lk, ur, nm]); if (nd == 1) fdl = DLINE[f, nm] } }
    }
    if (nd > 0) fail("D3", "Medium", f ":" fdl, lk " is out of step with this manifest: " nd " difference" (nd > 1 ? "s" : "") " (" diffs (nd > 3 ? "; …" : "") ")")
  }
  if (n > 1) note("D3", d "/: " n " npm lockfiles (" locks "); keep one package manager")
  if (!cov) npm_manifest_sources(f)
  if (!cov && LOCKREQ == "yes") fail("D1", "Medium", f ":1", "no lockfile covers this manifest: " locks " has no entry for " rel)
}
function py_rules(f,   d, locks, n, a, i, j, nm, sp, nr, ex, exl, miss, ml, ms) {
  d = dirof(f)
  chk("D2"); nr = 0; ex = ""
  for (i = 1; i <= NPY[f]; i++) { nm = PYN[f, i]; sp = PYS[f, nm]
    if (PYK[f, nm] == "poetry" ? (PINNING == "exact" ? !poetry_exact(sp) : poetry_unbounded(sp)) : (PINNING == "exact" ? !pep_exact(sp) : pep_unbounded(sp))) { nr++; if (ex == "") { ex = nm (sp == "" ? " (no version)" : " " sp); exl = PYD[f, nm] } } }
  if (nr > 0) fail("D2", "Low", f ":" exl, nr " of " NPY[f] " dependencies use " (PINNING == "exact" ? "ranges under version_pinning exact" : "unbounded ranges") " (first: " ex ")")
  chk("D4"); if (!py_engine(d)) fail("D4", "Low", f ":1", "no requires-python, python_requires, Poetry python, Pipfile [requires], .python-version or runtime.txt: the Python version is not declared")
  UNTR = ""; locks = covering("python", d); chk("D1")
  if (locks == "") {
    if (LOCKREQ == "yes") fail("D1", "Medium", f ":1", (UNTR != "" ? "the lockfile " UNTR " is not tracked by git" : NPY[f] " dependencies and no poetry.lock, uv.lock, pdm.lock, Pipfile.lock or fully pinned requirements file here or above"))
    return
  }
  chk("D3"); n = split(locks, a, / +/); miss = 0; ms = ""
  for (i = 1; i <= NPY[f]; i++) { nm = PYN[f, i]; hit = 0
    for (j = 1; j <= n; j++) if ((a[j], nm) in PYLOCK) hit = 1
    if (!hit) { miss++; if (miss <= 3) ms = ms (ms == "" ? "" : ", ") nm; if (miss == 1) ml = PYD[f, nm] } }
  if (miss > 0) fail("D3", "Medium", f ":" ml, "out of step with " locks ": " miss " dependenc" (miss > 1 ? "ies are" : "y is") " not in the lockfile (" ms (miss > 3 ? ", …" : "") ")")
}
function py_engine(d,   g) {  # any Python version declaration in the directory, or above it
  while (d != "") { if ((("python", d) in ENGDIR) || ((d) in PYENGD)) return 1; d = updir(d) }
  return 0
}
function simple_lock_rule(f, eco, what, here,   locks) {
  UNTR = ""; locks = ((here && !((eco, dirof(f)) in LOCKAT)) ? "" : covering(eco, dirof(f))); chk("D1")
  if (locks == "" && LOCKREQ == "yes") fail("D1", "Medium", f ":1", (UNTR != "" ? "the lockfile " UNTR " is not tracked by git" : what))
}
function days(dt,   y, m, dd, a) {  # days since 1970-01-01 for YYYY-MM-DD; -1 if malformed
  if (dt !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return -1
  y = substr(dt, 1, 4) + 0; m = substr(dt, 6, 2) + 0; dd = substr(dt, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd - 719469
}
function ignore_rules(   i, id, where) {
  for (i = 1; i <= NIG; i++) {
    id = IGI[i]; where = IGF[i] ":" IGLN[i]; chk("D10")
    if (toupper(id) in WAIVE) { info("D10", where "  " id " is suppressed and covered by a waiver ADR"); continue }
    if (IGEXP[i] != "" && days(IGEXP[i]) >= 0 && days(IGEXP[i]) < days(TODAY)) msg = id " is suppressed, and the suppression expired on " IGEXP[i]
    else msg = id " is suppressed with no waiver ADR (security.waivers)"
    if (MATURITY == "prototype") note("D10", where "  " msg)
    else fail("D10", "Low", where, msg)
  }
}
END {
  fileend()
  # A version declared in a manifest holds for its directory and below (workspace members).
  for (x = 1; x <= NFILES; x++) if ((f = FL[x]) != "") if ((KIND[f] == "pyproject" || KIND[f] == "pipfile" || KIND[f] == "py-setup") && ENG[f]) PYENGD[dirof(f)] = 1
  for (x = 1; x <= NFILES; x++) if ((f = FL[x]) != "") if (KIND[f] == "npm" && ENG[f]) ENGDIR["npm", dirof(f)] = 1
  ne = split("npm python go cargo", ECO, " ")
  for (i = 1; i <= NM; i++) {
    f = MAN[i]; ME[MECO[f]]++
    if (MECO[f] == "npm") npm_rules(f)
    else if (MECO[f] == "python") py_rules(f)
    else if (MECO[f] == "go") simple_lock_rule(f, "go", GOREQ[f] " required modules and no go.sum beside go.mod", 1)
    else if (MECO[f] == "cargo") simple_lock_rule(f, "cargo", CDN[f] " dependencies and no Cargo.lock here or above", 0)
  }
  # Lockfile sources (SEC-D5), one finding per lockfile and source.
  for (x = 1; x <= NFILES; x++) if ((f = FL[x]) != "") if (SRCH[f] > 0) for (j = 1; j <= SRCH[f]; j++) {
    h = SRCK[f, j]; u = SRCU[f, h]; p = SRCP[f, h]; sub(/^node_modules\//, "", p); gsub(/\/node_modules\//, " > ", p)
    fail("D5", srcsev(u), f ":" SRCL[f, h], SRCN[f, h] " package" (SRCN[f, h] > 1 ? "s" : "") " resolved from " safeurl(h) ", not the public default or a declared registry (first: " p ")")
  }
  for (x = 1; x <= NFILES; x++) if (FL[x] in NDLX) note("D6", FL[x] ": " NDLX[FL[x]] " more packages with a denied licence")
  if (HAVEDENY) for (x = 1; x <= NFILES; x++) if ((f = FL[x]) != "") if (KIND[f] ~ /^(yarn-lock|pnpm-lock|py-lock|pipfile-lock|cargo-lock|go-sum)$/ || (KIND[f] == "npm-lock" && NLIC[f] == 0)) note("D6", f " records no licences: licences_denied is not checked for it")
  ignore_rules()
  NAREASON["D1"] = "no manifest with dependencies"; NAREASON["D2"] = "no npm or Python manifest with dependencies"
  NAREASON["D3"] = "no lockfile to compare"; NAREASON["D4"] = "no npm or Python manifest with dependencies"
  NAREASON["D5"] = "no lockfile, registry or URL dependency"; NAREASON["D6"] = (HAVEDENY ? "no lockfile with licences" : "no licences_denied list (--deny)")
  NAREASON["D10"] = "no scanner ignore file"
  split("D1 D2 D3 D4 D5 D6 D10", ORD, " ")
  for (i = 1; i <= 7; i++) printf "%s", OUT[ORD[i]]
  for (i = 1; i <= 7; i++) { k = ORD[i]
    if (NFK[k] > 0) continue
    if (CHK[k] > 0) printf "PASS  %-7s %d checked\n", "SEC-" k, CHK[k]
    else printf "N/A   %-7s %s\n", "SEC-" k, NAREASON[k] }
  printf "%s%s", NOTES, INFOS
  printf "check-dependencies: %d manifests (npm %d, python %d, go %d, cargo %d), %d lockfiles, %d ignore files, %d findings\n", NM, ME["npm"], ME["python"], ME["go"], ME["cargo"], NLOCK, NIGN, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
