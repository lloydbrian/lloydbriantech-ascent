# check-ops-scripts.awk — the checks of check-ops-scripts.sh, which passes the file list and
# the ENVIRON values. A separate file keeps bash 3.2 from parsing the program
# (a quoted heredoc inside $(...) breaks there). Run with LC_ALL=C.
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function secretish(n,   l) {
  l = tolower(n); gsub(/-/, "_", l)
  if (l ~ /(arn|id|name|path|file|url|uri|ttl|length|len|version|ref|type|count|days|prefix|suffix|endpoint|header|dir|env|var|store)$/) return 0
  return l ~ /(password|passwd|passphrase|secret|token|apikey|api_key|private_key|access_key|secret_key|credential|auth_key|signing_key)/
}
function fail(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "OPS-" k, sev, where, msg); NF_[k]++; NFAIL++ }
function at() { return FN ":" FNR }
function endsh() {
  if (FN == "" || PK != "sh") return
  if (!LIB) {
    CHK["Z1"]++; if (!SHEBANG) fail("Z1", "Medium", FN ":1", "no shebang on line 1 (#!/usr/bin/env bash)")
    CHK["Z2"]++
    if (!(SE && SU && (SP || POSIX))) fail("Z2", "Medium", FN ":1", "no strict mode (" (POSIX ? "set -eu" : "set -euo pipefail") "): missing" (SE ? "" : " -e") (SU ? "" : " -u") (SP || POSIX ? "" : " pipefail"))
    CHK["Z3"]++; if (!HELP) fail("Z3", "Low", FN ":1", "does not answer --help with usage text")
    # A change stored in a variable counts where it is defined when no later line runs it.
    if (CHANGE == "" && CHANGEV != "") { CHANGE = CHANGEV; CF = CVF; CL = CVF }
    # A check before the last change is a pre-flight; a check after the first is a post-flight.
    if (CKMIN > 0 && CKMIN < CL) PRE = 1
    if (CKMAX > CF) POST = 1
    if (CHANGE != "") {
      CHK["Z4"]++; if (!DRY) fail("Z4", "Medium", CHANGE, "changes systems but offers no dry run (--dry-run, DRY_RUN, --check, --plan, or preview unless --apply)")
      CHK["Z9"]++
      if (!PRE || !POST) fail("Z9", "Low", CHANGE, "changes systems without " (!PRE && !POST ? "pre-flight or post-flight checks" : (!PRE ? "a pre-flight check" : "a post-flight check")))
    }
  }
  if (NDEST > 0 && !GUARD) for (j = 1; j <= NDEST && j <= 5; j++) fail("Z6", "High", DEST[j], "destructive command with no confirmation or explicit flag (--yes, --apply, CONFIRM): " DESTC[j])
}
function newfile() {
  endsh(); cflush(); cSvc = 0; cI = -1
  FN = FILENAME; sub(/^\.\//, "", FN); KN[K]++; PK = K
  SHEBANG = 0; SE = 0; SU = 0; SP = 0; POSIX = 0; HELP = 0; USAGE = 0; DRY = 0; PRE = 0; POST = 0; GUARD = 0
  CHANGE = ""; CHANGEV = ""; CF = 0; CL = 0; CVF = 0; CKMIN = 0; CKMAX = 0; split("", CMDV)
  NDEST = 0; HD = ""; split("", TMPV); split("", STAGES); inProv = 0; provBlk = ""; inDef = 0
  b = FN; sub(/^.*\//, "", b)
  LIB = (K == "sh" && (FN ~ /(^|\/)lib\// || b ~ /^(lib.*|_.*|common)\.(sh|bash)$/ || b ~ /-lib\.(sh|bash)$/))
}
FNR == 1 { newfile() }
{ line = $0; sub(/\r$/, "", line) }
# --- shell scripts -------------------------------------------------------------------
K == "sh" {
  if (FNR == 1 && line ~ /^#!/) { SHEBANG = 1; if (line ~ /(\/|env +)(sh|dash|ash)( |$)/) POSIX = 1; next }
  if (HD != "") { t = trim(line); if (t == HD) HD = ""; next }
  if (line ~ /^[ \t]*#/) next
  if (match(line, /(^|[^<])<<-?[ ]*["']?[A-Za-z_][A-Za-z0-9_]*["']?/)) { HD = substr(line, RSTART, RLENGTH); sub(/^[^<]*<<-?[ ]*["']?/, "", HD); sub(/["']$/, "", HD) }
  if (line ~ /^[ \t]*set +-/ || line ~ /^[ \t]*set +-o/) {
    s = line; sub(/#.*/, "", s)
    n = split(s, T, " ")
    for (j = 2; j <= n; j++) {
      if (T[j] ~ /^-[A-Za-z]*e/ ) SE = 1
      if (T[j] ~ /^-[A-Za-z]*u/) SU = 1
      if (T[j] == "pipefail") SP = 1
      if (T[j] == "errexit") SE = 1
      if (T[j] == "nounset") SU = 1
    }
  }
  # --help, or "$@" handed to a shared help function (show_help "$@").
  if (line ~ /--help/ || line ~ /(^|[ \t;&|])[A-Za-z_][A-Za-z0-9_]*[Hh]elp[A-Za-z0-9_]* +"?\$\{?[@*]\}?"?/) HELP = 1
  # A script that previews by default and changes only with --apply has a dry run.
  if (line ~ /--dry-run|DRY_RUN|dry_run|DRYRUN|--check|--plan|--what-if|--noop|NOOP|--apply|(^|[^A-Za-z_])APPLY=|--preview|PREVIEW/) DRY = 1
  if (line ~ /[Pp]re-?_?flight|PRE_?FLIGHT|preflight|precheck|pre-check/) PRE = 1
  if (line ~ /[Pp]ost-?_?flight|POST_?FLIGHT|postflight|postcheck|post-check|verify|smoke|health/) POST = 1
  if (line ~ /\$\{?REPLY/ || line ~ /--yes|--force\)|--apply|--execute|--confirm|CONFIRM=|ASSUME_YES|[Aa]re you sure|to confirm/) GUARD = 1
  if (match(line, /[A-Za-z_][A-Za-z0-9_]*=["'(]*\$\( *mktemp/)) { v = substr(line, RSTART, RLENGTH); sub(/=.*/, "", v); TMPV[v] = 1 }
  # OPS-Z5 — secrets from arguments, read without -s, printed
  # Quoted prompts are masked first, so read -rp "Token: " NAME parses like read -r -p P NAME.
  t = line; gsub(/"[^"]*"|'[^']*'/, "P", t)
  if (match(t, /(^|[ \t;])read( +-[A-Za-z]+( +P)?)* +[A-Za-z_][A-Za-z0-9_]*/)) {
    s = substr(t, RSTART, RLENGTH); n = split(s, T, " "); silent = 0; vars = ""
    for (j = 1; j <= n; j++) { if (T[j] ~ /^-[A-Za-z]*s/) silent = 1 }
    nm = T[n]
    # A confirmation prompt guards the file's destructive commands (OPS-Z6).
    if (tolower(nm) ~ /^(confirm|confirmation|answer|reply|ok|yn|yesno|proceed|sure)$/) GUARD = 1
    if (secretish(nm)) { CHK["Z5"]++; if (!silent) fail("Z5", "High", at(), "reads " nm " without -s, so the secret is echoed to the terminal; use read -rs") }
  }
  if (match(line, /(^|[ \t;])(local +|export +|readonly +|declare +)?[A-Za-z_][A-Za-z0-9_]*=["']?\$\{?[1-9]/)) {
    s = substr(line, RSTART, RLENGTH); sub(/^[ \t;]*(local +|export +|readonly +|declare +)?/, "", s); sub(/=.*/, "", s)
    if (secretish(s)) { CHK["Z5"]++; fail("Z5", "High", at(), s " comes from a command-line argument (visible in ps and shell history); read it with read -rs or from a secret store") }
  }
  if (line ~ /^[ \t]*[-A-Za-z|=*]*--(password|passwd|token|secret|api-key|apikey|client-secret)[-A-Za-z|=*]*\)/) { CHK["Z5"]++; fail("Z5", "High", at(), "takes a secret as a command-line option; read it with read -rs or from a secret store") }
  if (line ~ /(^|[ \t;&|])(echo|printf)( |$)/ && line !~ /\|/ && line !~ />/) {
    t = line
    while (match(t, /\$\{?[A-Za-z_][A-Za-z0-9_]*/)) {
      v = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
      sub(/^\$\{?/, "", v)
      if (substr(t, 1, 2) == ":+") continue
      if (secretish(v)) { CHK["Z5"]++; fail("Z5", "High", at(), "prints " v " to standard output; never print a secret (pipe it to the command that needs it)"); break }
    }
  }
  # OPS-Z4 / OPS-Z9 — commands that change systems. Quoted text is masked (a message that says
  # "reboot" changes nothing) unless the line hands it to ssh, sh -c, eval or sudo. A
  # line that only stores a command in a variable is a change where the variable runs.
  cl = line
  if (line !~ /(ssh|(ba|z|da)?sh +-c|eval|sudo|su +-c|xargs)[^"']*["']/) gsub(/"[^"]*"|'[^']*'/, "P", cl)
  sub(/[ \t]+#.*$/, "", cl)
  if (line ~ /^[ \t]*(local +|export +|readonly +|declare +)?[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'[^']*')[ \t]*(#.*)?$/ && line !~ /\$\(|`/) {
    if (ischange(line)) { v = line; sub(/^[ \t]*(local +|export +|readonly +|declare +)?/, "", v); sub(/=.*/, "", v); CMDV[v] = 1; if (CHANGEV == "") { CHANGEV = at(); CVF = FNR } }
  } else {
    hit = ischange(cl)
    if (!hit) for (v in CMDV) if (index(line, "$" v) || index(line, "${" v "}")) { hit = 1; break }
    if (hit) { if (CHANGE == "") { CHANGE = at(); CF = FNR }; CL = FNR }
    else if (cl ~ /(^|[^A-Za-z0-9])(gate|health|healthy|verify|verification|validate|assert|check|checks|smoke|probe|ready|readiness|status|require)([^A-Za-z]|$)/ || cl ~ /[a-z]_ok([^A-Za-z]|$)/) { if (CKMIN == 0) CKMIN = FNR; CKMAX = FNR }
  }
  # OPS-Z6 — destructive commands
  if (line ~ /(^|[ \t;&|(])(sudo +)?rm +(-[A-Za-z]*r[A-Za-z]*f|-[A-Za-z]*f[A-Za-z]*r|--recursive)/ || line ~ /(terraform|tofu) +(-chdir=[^ ]+ +)?destroy/ || line ~ /aws +[a-z0-9-]+ +(delete-|terminate-)/ || line ~ /aws +s3 +(rm|rb) / || line ~ /(DROP +(TABLE|DATABASE|SCHEMA)|TRUNCATE +TABLE)/ || line ~ /kubectl +delete / || line ~ /helm +uninstall / || line ~ /(docker|podman) +(system +prune|volume +(rm|prune)|image +prune +-a)/ || line ~ /mkfs|wipefs|shred / || line ~ /(^|[ \t;&|])dd +.*of=/ || line ~ /git +reset +--hard|git +clean +-[a-z]*f|git +push +.*(--force|-f( |$))/ || line ~ /gh +repo +delete/) {
    safe = 0
    if (line ~ /(^|[ \t;&|(])(sudo +)?rm +/ && line !~ /destroy|delete|DROP|TRUNCATE|prune|mkfs|dd /) {
      if (line ~ /trap /) safe = 1
      if (line ~ /rm +-[A-Za-z]+ +((\.\/)?(node_modules|dist|build|coverage|out|target|tmp|\.cache|\.terraform|__pycache__|\.pytest_cache)\/? *)+($|[;&|])/) safe = 1
      for (v in TMPV) if (index(line, "$" v) || index(line, "${" v)) safe = 1
    }
    # Name the command, never the line: it can carry an inline secret (PGPASSWORD=... psql).
    if (!safe) { CHK["Z6"]++; NDEST++; DEST[NDEST] = at(); DESTC[NDEST] = destword(line) }
    else CHK["Z6"]++
  }
  floating(line)
  next
}
function ischange(s) {
  return (s ~ /(terraform|tofu) +(-chdir=[^ ]+ +)?(apply|destroy|import|state +(rm|mv|push))/ || s ~ /aws +[a-z0-9-]+ +(create|delete|put|update|deploy|terminate|start|stop|reboot|modify|attach|detach|register|deregister|invoke|execute|send|run|restore|import|reset|enable|disable|set|tag|untag)-?/ || s ~ /aws +s3 +(rm|cp|mv|sync|rb|mb) / || s ~ /kubectl +(apply|delete|create|patch|replace|scale|rollout|drain|cordon|set) / || s ~ /helm +(install|upgrade|uninstall|rollback) / || s ~ /(docker|podman) +(rm|rmi|push|run|stop|kill|restart|system +prune|volume +rm|network +rm|compose +(up|down|rm|restart)|play +kube)( |$)/ || s ~ /(docker-compose|podman-compose) +(up|down|rm|restart)/ || s ~ /systemctl +(start|stop|restart|enable|disable|reload|mask) / || s ~ /curl [^|]*-X *(POST|PUT|DELETE|PATCH)/ || s ~ /git +(push|commit|tag|reset|clean) / || s ~ /(apt|apt-get|dnf|yum) +(-y +)?(install|remove|upgrade|purge)/ || s ~ /(^|[ \t;&|"'])(sudo +)?(reboot|shutdown)([ "']|$)/ || s ~ /crontab +-/ || s ~ /scp +|rsync +/)
}
function destword(s) {
  if (match(s, /rm +-[A-Za-z-]+|(terraform|tofu) +(-chdir=[^ ]+ +)?destroy|aws +s3 +(rm|rb)|aws +[a-z0-9-]+ +(delete|terminate)-[a-z0-9-]+|DROP +(TABLE|DATABASE|SCHEMA)|TRUNCATE +TABLE|kubectl +delete|helm +uninstall|(docker|podman) +(system +prune|volume +(rm|prune)|image +prune)|mkfs[.a-z0-9]*|wipefs|shred|git +reset +--hard|git +clean +-[a-z]+|git +push|gh +repo +delete/)) return substr(s, RSTART, RLENGTH)
  if (s ~ /(^|[ \t;&|])dd +/) return "dd of="
  return "a destructive command"
}
# A tag is floating when it is latest or names no version (alpine, stable, lts).
function floattag(t) { return t !~ /:/ || t ~ /:latest$/ || t ~ /:[A-Za-z_-]+$/ }
function floating(s) {
  if (s ~ /@latest([^A-Za-z0-9_-]|$)/) { CHK["Z8"]++; fail("Z8", "Medium", at(), "@latest is a floating version; pin an exact version") }
  if (s ~ /(docker|podman) +(run|pull|create)[^#]*:latest([^A-Za-z0-9_.-]|$)/) { CHK["Z8"]++; fail("Z8", "Medium", at(), "a :latest image is a floating version; pin a tag or digest") }
  if (s ~ /(curl|wget)[^|#]*\| *(sudo +)?(ba|z|da)?sh/) { CHK["Z8"]++; fail("Z8", "Medium", at(), "pipes a remote script into a shell; pin a version and verify a checksum") }
}
# --- make --------------------------------------------------------------------------
K == "make" {
  if (line ~ /^define /) { inDef = 1; next }
  if (inDef) { if (line ~ /^endef/) inDef = 0; next }
  if (line ~ /^\t/) { floating(line); if (line ~ /--help/) HELP = 1; next }
  if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) next
  if (line ~ /^[A-Za-z0-9][A-Za-z0-9_-]*( +[A-Za-z0-9][A-Za-z0-9_-]*)* *:/ && line !~ /^[^:]*:[:]?=/ && line !~ /^[^:]*\?=/ && line !~ /^[^:]*%/) {
    tg = line; sub(/ *:.*/, "", tg); n = split(tg, T, " ")
    for (j = 1; j <= n; j++) {
      MT[T[j]]++; CHK["Z7"]++
      if (line ~ /##/) MDOC[T[j]] = 1
      else if (!(T[j] in MFIRST)) MFIRST[T[j]] = at()
    }
  }
  next
}
# --- Dockerfile, Compose, Terraform, workflows: pinning ------------------------------
K == "docker" {
  if (line ~ /^[ \t]*#/) next
  u = trim(line)
  if (toupper(substr(u, 1, 5)) == "FROM ") {
    n = split(u, T, " "); img = ""
    for (j = 2; j <= n; j++) if (T[j] !~ /^--/) { img = T[j]; break }
    for (j = 1; j < n; j++) if (toupper(T[j]) == "AS") STAGES[tolower(T[j + 1])] = 1
    CHK["Z8"]++
    if (img == "" || img == "scratch" || img ~ /^\$/ || (tolower(img) in STAGES)) next
    if (img ~ /@sha256:/) next
    t = img; sub(/^.*\//, "", t)
    if (t !~ /:/) fail("Z8", "Medium", at(), "FROM " img " has no tag; pin a version or digest")
    else if (floattag(t)) fail("Z8", "Medium", at(), "FROM " img " is a floating version; pin a version or digest")
  }
  if (toupper(substr(u, 1, 4)) == "RUN ") floating(u)
  next
}
# A service's image is judged when the service ends: one with build: names its own build output.
function cflush() {
  if (cImg != "") { CHK["Z8"]++; if (!cBuild) { t = cImg; sub(/^.*\//, "", t); if (floattag(t)) fail("Z8", "Medium", cAt, "image " cImg " is a floating version; pin a tag or digest") } }
  cImg = ""; cBuild = 0
}
K == "compose" {
  if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) next
  if (line ~ /^[^ ]/) { cflush(); cSvc = (line ~ /^services: *$/); cI = -1; next }
  if (!cSvc) next
  match(line, /^ */); i = RLENGTH; if (cI < 0) cI = i
  if (i == cI) { cflush(); next }
  if (line ~ /^ +build *:/) cBuild = 1
  if (match(line, /^ +image: */)) {
    img = trim(substr(line, RSTART + RLENGTH)); gsub(/["']/, "", img); sub(/ +#.*/, "", img)
    if (img ~ /^\$/ || img ~ /@sha256:/) CHK["Z8"]++
    else { cImg = img; cAt = at() }
  }
  next
}
K == "gha" {
  if (line ~ /^[ \t]*#/) next
  if (match(line, /uses: *["']?[^ "'#]+/)) {
    u = substr(line, RSTART, RLENGTH); sub(/^uses: *["']?/, "", u); CHK["Z8"]++
    if (u ~ /^\.\//) next
    if (u !~ /@/ || u ~ /@(main|master|latest|HEAD|dev|develop|trunk)$/ || u ~ /:latest$/) fail("Z8", "Medium", at(), "action " u " follows a branch; pin a release tag or commit")
    next
  }
  else floating(line)
  next
}
K == "tf" {
  if (line ~ /^[ \t]*(#|\/\/)/) next
  if (match(line, /^ *required_version *= *"[^"]*"/)) {
    v = substr(line, RSTART, RLENGTH); sub(/^[^"]*"/, "", v); sub(/"$/, "", v); CHK["Z8"]++
    if (v ~ />/ && v !~ /</ && v !~ /~>/) fail("Z8", "Medium", at(), "terraform required_version \"" v "\" has no upper bound; use ~> or an exact version")
    next
  }
  if (line ~ /required_providers *\{/) { inProv = 1; pd = 1; next }
  if (inProv) {
    pd0 = pd; o = line; c = line; pd += gsub(/\{/, "", o) - gsub(/\}/, "", c)
    if (pd0 == 1 && match(line, /^ *[A-Za-z0-9_-]+ *= *"[^"]*"/)) { provBlk = trim(line); sub(/ *=.*/, "", provBlk); provAt = at(); provVer = line; sub(/^[^=]*= */, "version = ", provVer); checkprov() }
    else if (pd0 == 1 && match(line, /^ *[A-Za-z0-9_-]+ *= *\{/)) { provBlk = trim(substr(line, 1, RLENGTH)); sub(/ *=.*/, "", provBlk); provAt = at(); provVer = ""; if (match(line, /version *= *"[^"]*"/)) provVer = substr(line, RSTART, RLENGTH); if (pd == 1) checkprov() }
    else if (provBlk != "" && match(line, /version *= *"[^"]*"/)) provVer = substr(line, RSTART, RLENGTH)
    if (provBlk != "" && pd0 == 2 && pd == 1) checkprov()
    if (pd <= 0) inProv = 0
    next
  }
  if (match(line, /^module +"[^"]+"/)) { modName = substr(line, RSTART, RLENGTH); sub(/^module +"/, "", modName); sub(/"$/, "", modName); modAt = at(); modSrc = ""; modVer = 0; inMod = 1; md = 0 }
  if (inMod) {
    o = line; c = line; md += gsub(/\{/, "", o) - gsub(/\}/, "", c)
    if (match(line, /source *= *"[^"]*"/)) { modSrc = substr(line, RSTART, RLENGTH); sub(/^source *= *"/, "", modSrc); sub(/"$/, "", modSrc) }
    if (line ~ /^ *version *=/) modVer = 1
    if (md <= 0) {
      inMod = 0; CHK["Z8"]++
      if (modSrc ~ /^(git::|git@)|github\.com[\/:]/ && modSrc !~ /[?&]ref=/) fail("Z8", "Medium", modAt, "module " modName " pulls a git source without ?ref=; pin a tag or commit")
      else if (modSrc !~ /^(\.|\/|git::|git@|github\.com|https?:|s3::|gcs::)/ && modSrc != "" && !modVer) fail("Z8", "Medium", modAt, "registry module " modName " has no version; pin one")
    }
  }
  next
}
function checkprov(   v) {
  CHK["Z8"]++; v = provVer; sub(/^version *= *"/, "", v); sub(/"$/, "", v)
  if (v == "") fail("Z8", "Medium", provAt, "provider " provBlk " has no version constraint; pin one (~> or an exact version)")
  else if (v ~ />/ && v !~ /</ && v !~ /~>/) fail("Z8", "Medium", provAt, "provider " provBlk " version \"" v "\" has no upper bound; use ~> or an exact version")
  provBlk = ""
}
END {
  endsh(); cflush()
  for (t in MT) if (!(t in MDOC) && t != ".PHONY" && t !~ /^_/) fail("Z7", "Low", MFIRST[t], "make target " t " has no ## help text, so make help does not list it")
  split("Z1 Z2 Z3 Z4 Z5 Z6 Z7 Z8 Z9", ORDER, " ")
  D["Z1"] = "scripts start with a shebang"
  D["Z2"] = "scripts run in strict mode"
  D["Z3"] = "scripts answer --help"
  D["Z4"] = "scripts that change systems offer a dry run"
  D["Z5"] = "secrets are never taken from arguments or printed"
  D["Z6"] = "destructive commands need a confirmation or an explicit flag"
  D["Z7"] = "make targets have ## help text"
  D["Z8"] = "versions are pinned"
  D["Z9"] = "scripts that change systems run pre-flight and post-flight checks"
  if (KN["sh"] > 0 && CHK["Z5"] == 0) CHK["Z5"] = KN["sh"]
  if (KN["sh"] > 0 && CHK["Z6"] == 0) CHK["Z6"] = KN["sh"]
  for (j = 1; j <= 9; j++) {
    k = ORDER[j]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "OPS-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (nothing to check)\n", "OPS-" k, D[k]
  }
  printf "check-ops-scripts: %d script(s), %d make file(s), %d Dockerfile(s), %d Compose file(s), %d Terraform file(s), %d workflow(s), %d failure(s)\n", \
    KN["sh"], KN["make"], KN["docker"], KN["compose"], KN["tf"], KN["gha"], NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
