# check-doc-drift.awk — the program check-doc-drift.sh runs, after md-common.awk.
# Inputs, in order: DD_FILES (every repository path), DD_TARGETS (make targets),
# DD_SCRIPTS (package.json scripts), DD_ENV (environment variable names the
# repository defines or reads), then the documents checked. Options and pinned
# versions come from DD_* in the environment.
# Portable: POSIX awk (BWK, mawk, gawk), run with LC_ALL=C.

BEGIN {
  MAT = ENVIRON["DD_MATURITY"]; HAVEMAKE = ENVIRON["DD_HAVE_MAKE"] == 1; HAVEPKG = ENVIRON["DD_HAVE_PKG"] == 1
  VER = ENVIRON["DD_VERSION"]; VERSRC = ENVIRON["DD_VERSION_SRC"]
  NODE = ENVIRON["DD_NODE"]; NODESRC = ENVIRON["DD_NODE_SRC"]; PY = ENVIRON["DD_PYTHON"]; PYSRC = ENVIRON["DD_PYTHON_SRC"]
  n = split(ENVIRON["DD_IGNORE_ENV"], a, " "); for (i = 1; i <= n; i++) IGNENV[a[i]] = 1
  n = split(ENVIRON["DD_IGNORE"], a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") IGN[a[i]] = 1
  FF = ENVIRON["DD_FILES"]; FT = ENVIRON["DD_TARGETS"]; FSC = ENVIRON["DD_SCRIPTS"]; FE = ENVIRON["DD_ENV"]
}
function fail(k, sev, w, msg) {
  if (MAT == "prototype") { NOTES = NOTES sprintf("NOTE  %-7s %-6s %s  %s (prototype: not rated)\n", "DOC-" k, sev, w, msg); return }
  OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "DOC-" k, sev, w, msg); NF_[k]++
}
function addfile(p,   d) {
  EXISTS[p] = 1
  d = p; while (d ~ /\//) { sub(/\/[^\/]*$/, "", d); if (d in EXISTS) break; EXISTS[d] = 1 }
}
FILENAME == FF { addfile($0); next }
FILENAME == FT { TARGET[$0] = 1; next }
FILENAME == FSC { SCRIPT[$0] = 1; next }
FILENAME == FE { ENVN[$0] = 1; next }
# check_cmd(s, w) — make targets and package scripts in a command line: a command
# counts only at the start of the line or after ;, &&, || or |, and a make target
# list ends at the first word that is not a target name, or at a run of spaces
# before an aligned description
function check_cmd(s, w,   n, t, i, start, sawmake, cmd) {
  sub(/^[ \t]+/, "", s); sub(/[ \t]#.*$/, "", s); sub(/(  |\t).*$/, "", s)
  gsub(/&&|\|\||;|\|/, " ; ", s)
  n = split(s, t, /[ \t]+/); sawmake = 0; start = 1
  for (i = 1; i <= n; i++) {
    if (t[i] == ";") { sawmake = 0; start = 1; continue }
    if (start && (t[i] == "make" || t[i] == "gmake")) { sawmake = HAVEMAKE; start = 0; continue }
    if (sawmake) {
      # -C DIR and -f FILE run another Makefile: its targets are not this one's
      if (t[i] ~ /^-[Cf]/ || t[i] ~ /^--(directory|file|makefile)/) { sawmake = 0; continue }
      if (t[i] ~ /^-[IoW]$/) { i++; continue }  # an option that takes the next word
      if (t[i] ~ /^-/ || t[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
      if (t[i] !~ /^[A-Za-z0-9_.\/-]+$/ || t[i] ~ /^[0-9]+$/) { sawmake = 0; continue }
      if (t[i] in IGN) continue
      CHK["R2"]++
      if (!(t[i] in TARGET)) fail("R2", "Medium", w, "make " t[i] ": the Makefile has no target " t[i])
      continue
    }
    if (start && (t[i] == "npm" || t[i] == "pnpm" || t[i] == "yarn" || t[i] == "bun") && (t[i + 1] == "run" || t[i + 1] == "run-script") && i + 2 <= n && HAVEPKG) {
      cmd = t[i + 2]; start = 0
      if (cmd !~ /^[A-Za-z0-9_.:\/-]+$/ || cmd ~ /^-/ || cmd in IGN) continue
      CHK["R3"]++
      if (!(cmd in SCRIPT)) fail("R3", "Medium", w, t[i] " run " cmd ": package.json has no script " cmd)
      i += 2; continue
    }
    start = 0
  }
}
function check_path(p, w, doc,   q, d, b) {
  sub(/^\.\//, "", p); sub(/:[0-9]+(-[0-9]+)?$/, "", p); sub(/\/$/, "", p)
  if (p !~ /\// || p ~ /[^A-Za-z0-9_.\/@+-]/ || p ~ /^[\/.-]/ || index(p, "//") || index(p, "...")) return
  if (p in IGN || p ~ /(^|[-_.\/])(N+|X+)([-_.\/]|$)/) return
  b = p; sub(/^.*\//, "", b); sub(/\.[^.]*$/, "", b)  # an example name: scripts/x.mjs, scripts/whatever.sh
  if (length(b) == 1 || b ~ /^(foo|bar|baz|whatever|example|sample|something)$/ || b ~ /^(your|my)[-_]/) return
  if (p in EXISTS) { CHK["R1"]++; return }
  q = md_resolve(doc, p); if (q in EXISTS) { CHK["R1"]++; return }
  d = md_dir(p); if (!(d in EXISTS)) return
  CHK["R1"]++
  fail("R1", "Medium", w, "names " p ", which does not exist (its folder " d "/ does)")
}
function check_env(e, w) {
  sub(/^\$\{?/, "", e); sub(/\}$/, "", e); sub(/=.*$/, "", e)
  if (e !~ /^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$/) return
  if (e in IGNENV || e ~ /^(LC|GITHUB|RUNNER|XDG)_/) return
  CHK["R4"]++
  if (!(e in ENVN)) fail("R4", "Low", w, "names the environment variable " e ", which nothing in the repository defines or reads")
}
{
  doc = FILENAME; sub(/^\.\//, "", doc); w = doc ":" FNR
  if (!md_line()) {
    if (MD_FENCE && (MD_LANG == "" || MD_LANG ~ /^(sh|bash|shell|console|zsh|terminal|make)$/)) {
      s = $0; sub(/^[ \t]*\$[ \t]+/, "", s)
      if (s !~ /^[ \t]*(```|~~~)/) check_cmd(s, w)
    }
    next
  }
  line = $0
  while (match(line, /`[^`]+`/)) {
    c = substr(line, RSTART + 1, RLENGTH - 2); line = substr(line, RSTART + RLENGTH)
    if (c ~ /^(make|gmake|npm|pnpm|yarn|bun)[ \t]/) check_cmd(c, w)
    else if (c ~ /^\$?\{?[A-Z][A-Z0-9_]*\}?(=.*)?$/) check_env(c, w)
    else check_path(c, w, doc)
  }
  p = md_nocode($0)
  if (VER != "" && tolower(doc) ~ /(^|\/)readme\.md$/ && tolower(p) ~ /^[-* ]*\**(current )?version:?\**:?\**[ \t]+v?[0-9]+\.[0-9]+/) {
    v = p; sub(/^[^0-9]*/, "", v); sub(/[^0-9A-Za-z.+-].*$/, "", v); sub(/[.,]$/, "", v)  # keeps "1.2.0-rc.1"
    CHK["R5"]++
    if (v != VER) fail("R5", "Low", w, "says version " v "; " VERSRC " says " VER)
  }
  if (NODE != "") {
    s = p
    while (match(s, /[Nn]ode(\.js)?[ \t]*(version[ \t]*)?(>=|v|:|=)?[ \t]*[0-9]+/)) {
      m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      if (s ~ /^[0-9]/) continue
      num = m; sub(/^[^0-9]*/, "", num); ge = (index(m, ">=") > 0 || substr(s, 1, 1) == "+")  # "Node.js 20+"
      CHK["R6"]++
      if ((ge && num + 0 > NODE + 0) || (!ge && num + 0 != NODE + 0)) fail("R6", "Low", w, "says " m "; " NODESRC " pins Node.js " NODE)
    }
  }
  if (PY != "") {
    s = p
    while (match(s, /[Pp]ython[ \t]*(>=)?[ \t]*3\.[0-9]+/)) {
      m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      num = m; sub(/^[^3]*3\./, "", num); ge = (index(m, ">=") > 0); pm = PY; sub(/^3\./, "", pm)
      CHK["R6"]++
      if ((ge && num + 0 > pm + 0) || (!ge && num + 0 != pm + 0)) fail("R6", "Low", w, "says " m "; " PYSRC " pins Python " PY)
    }
  }
}
END {
  D["R1"] = "named paths exist"; D["R2"] = "make targets exist"; D["R3"] = "package scripts exist"
  D["R4"] = "environment variables are defined or read"; D["R5"] = "stated versions match"; D["R6"] = "stated runtimes match the pins"
  NA["R1"] = "no repository path named"; NA["R2"] = (HAVEMAKE ? "no make command named" : "no Makefile"); NA["R3"] = (HAVEPKG ? "no package script named" : "no package.json")
  NA["R4"] = "no environment variable named"; NA["R5"] = (VER == "" ? "no version file (VERSION, package.json, pyproject.toml, Cargo.toml)" : "no Version: line"); NA["R6"] = (NODE == "" && PY == "" ? "no pinned runtime (.nvmrc, .node-version, engines.node, .python-version)" : "no runtime version stated")
  NFAIL = 0
  for (i = 1; i <= 6; i++) {
    k = "R" i
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "DOC-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "DOC-" k, D[k], NA[k]
  }
  printf "%s", NOTES
  printf "check-doc-drift: %d failure(s); it checks what the documents name against the repository, not that their descriptions are right\n", NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
