# check-iac-config.awk — the checks of check-iac-config.sh, which passes the file list and
# the ENVIRON values. A separate file keeps bash 3.2 from parsing the program
# (a quoted heredoc inside $(...) breaks there). Run with LC_ALL=C.
BEGIN { STATES = ENVIRON["CIC_STATES"]; ENVFILES = ENVIRON["CIC_ENVFILES"]; NOTES = ENVIRON["CIC_NOTES"]; MANUAL = ENVIRON["CIC_MANUAL"]; MTEXT = ENVIRON["CIC_MTEXT"] }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function ind(s) { match(s, /^ */); return RLENGTH }
function lc(s) { return tolower(s) }
# A key that names a secret, and is not the id, name, path or length of one.
function secretish(n,   l) {
  l = lc(n); gsub(/["'\[\] ]/, "", l); gsub(/-/, "_", l)
  if (l ~ /(arn|id|ids|name|names|path|file|url|uri|ttl|length|len|version|ref|policy|rotation|enabled|type|count|days|prefix|suffix|endpoint|header|manager|store|kms|kms_key|validity|units)$/) return 0
  if (l ~ /^(secrets|secretstringtemplate|secret_string_template|secretsmanager)$/) return 0
  return l ~ /(password|passwd|passphrase|secret|token|apikey|api_key|private_key|privatekey|access_key|accesskey|secret_key|credential|connection_string|connectionstring|signing_key|auth_key)/
}
function envish(n,   l) { l = lc(n); gsub(/[_ -]/, "", l); return l ~ /^(env|environment|environmentname|envname|stage|stagename|deploymentenvironment|deployenv|tier)$/ }
# A literal value: quoted (or, in YAML, bare) text that is not a reference.
function literal(v, yaml,   q, inner) {
  v = trim(v); sub(/,$/, "", v); v = trim(v)
  if (v == "" || v ~ /^[|>\[{(&*]/) return 0
  if (v ~ /^!/ || v ~ /\{\{resolve:/ || v ~ /\$\{/ || v ~ /^(Ref|Fn::)/) return 0
  if (v ~ /^["']?(seconds|minutes|hours|days)["']?$/) return 0
  q = substr(v, 1, 1)
  if (q == "\"" || q == "'") {
    inner = substr(v, 2); sub(/["']$/, "", inner)
    if (inner == "" || inner ~ /^(arn:|\{\{resolve:)/) return 0
    return 1
  }
  if (!yaml) return 0
  if (v ~ /^(true|false|yes|no|on|off|null|~|[0-9][0-9.]*)$/) return 0
  return 1
}
function wild(tok) { tok = trim(tok); gsub(/["',\[\]]/, "", tok); sub(/^- */, "", tok); tok = trim(tok); return tok == "*" || tok ~ /^[A-Za-z0-9-]+:\*$/ }
function wildany(s,   n, T, i) { gsub(/[\[\],]/, " ", s); n = split(s, T, " "); for (i = 1; i <= n; i++) if (wild(T[i])) return 1; return 0 }
function fail(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-4s %-6s %s  %s\n", k, sev, where, msg); NF_[k]++; NFAIL++ }
function at() { return FN ":" FNR }
function yamlkey(s) {   # sets YK and YV; returns 1 for a "key: value" line
  if (!match(s, /^ *(- +)?["']?[A-Za-z0-9_.\/@-]+["']? *:/)) return 0
  YC = substr(s, RSTART + RLENGTH, 1); if (YC != "" && YC != " ") return 0
  YK = substr(s, RSTART, RLENGTH); sub(/^ *(- +)?/, "", YK); sub(/ *:$/, "", YK); gsub(/["']/, "", YK)
  YV = trim(substr(s, RSTART + RLENGTH)); return 1
}
# A CodeBuild-style environment entry is a plain value unless its Type is a store.
function envFlush() { if (penName != "") fail("S3", "High", penAt, "secret " penName " passed as a plain environment value in " penItem "; use Secrets (ValueFrom) or read it from Secrets Manager at runtime"); penName = ""; entStore = 0 }
# A wildcard in a key policy is exempt only in the statement that names the account root.
function kmsFlush() { if (kmsWild != "" && !kmsRoot) fail("S5", "Medium", kmsWild, "wildcard IAM action in " kmsItem " (only the account-root statement of a key policy may use one)"); kmsWild = ""; kmsRoot = 0 }
function kmsSeen(where, what) { if (kmsWild == "") { kmsWild = where; kmsItem = what } }
# One Terraform argument (k = v) of the current block.
function tfkv(k, v) {
  sub(/ *[=:]$/, "", k); k = trim(k); gsub(/"/, "", k)
  if (tfB == "variable" || tfB == "output") {
    if (k == "sensitive" && v ~ /true/) tfSens = 1
    if (tfB == "variable" && k == "default" && secretish(tfN) && literal(v, 0)) fail("S1", "High", at(), "variable " tfN " has a literal default value")
  } else {
    if (k == "type") { tfType = trim(v); gsub(/"/, "", tfType) }
    if (k == "secret_id" && tfT == "aws_secretsmanager_secret_rotation" && match(v, /aws_secretsmanager_secret\.[A-Za-z0-9_-]+/)) { s = substr(v, RSTART, RLENGTH); sub(/^aws_secretsmanager_secret\./, "", s); ROT[s] = 1 }
    if (k == "name" && tfT == "aws_ssm_parameter") tfSecretRef = v
    if (k != "environment" && secretish(k) && literal(v, 0)) fail("S1", "High", at(), "literal value for " k " in " (tfT != "" ? tfT "." tfN : (tfB != "" ? tfB : "configuration")))
  }
}
# A wildcard action in Terraform: key policies wait for their statement's principal.
function tfwild(s) { if (tfT ~ /^aws_kms_key/ || (tfT == "aws_iam_policy_document" && s ~ /kms:\*/)) kmsSeen(at(), tfT "." tfN); else fail("S5", "Medium", at(), "wildcard IAM action in " tfT "." tfN) }
function newfile() {
  cfnEnd()
  FN = FILENAME; sub(/^\.\//, "", FN); NFILES++; KN[K]++
  sec = ""; item = ""; envI = -1; actI = -1; tfD = 0; tfB = ""; envD = -1; actOpen = 0; svcI = -1; inEnv = 0; envKI = -1; inSvc = 0; inCmt = 0; dacc = ""; envDep = 0
  penName = ""; entStore = 0; rotNext = 0; kmsWild = ""; kmsRoot = 0
}
# CloudFormation item end: evaluate the finished parameter or resource.
function cfnEnd() {
  envFlush(); kmsFlush()
  if (item == "") return
  if (sec == "Parameters") {
    PARAMS[++NPARAM] = item; CHK["S10"]++
    if (envish(item)) ENVHINT = ENVHINT == "" ? FN ":" itemL : ENVHINT
    if (secretish(item)) { CHK["S2"]++; if (!noecho) fail("S2", "Medium", FN ":" itemL, "parameter " item " is sensitive but has no NoEcho: true") }
  }
  if (sec == "Resources") {
    if (rtype == "AWS::SecretsManager::Secret") { SECRET[++NSEC] = item; SECAT[NSEC] = FN ":" itemL }
    if (rtype == "AWS::SecretsManager::RotationSchedule" && rotref != "") ROT[rotref] = 1
    if (rtype == "AWS::SSM::Parameter") { CHK["S3"]++; if (secretish(item) || secretish(ssmname)) fail("S3", "High", FN ":" itemL, "SSM parameter " item " holds a secret as a plain String (CloudFormation cannot create SecureString); use AWS::SecretsManager::Secret") }
  }
  item = ""
}
FNR == 1 { newfile() }
{
  line = $0; sub(/\r$/, "", line); gsub(/\t/, "  ", line); raw = line
}
# --- CI, make and scripts: drift detection only --------------------------------
K == "ci" {
  if (raw ~ /^ *(#|\/\/)/) next
  if (raw ~ /(terraform|tofu|terragrunt).*plan.*-detailed-exitcode/ || raw ~ /-refresh-only/ || raw ~ /detect-stack-drift|describe-stack-resource-drifts|driftctl/) DRIFT = DRIFT == "" ? at() : DRIFT
  next
}
# --- CloudFormation --------------------------------------------------------------
K == "cfn" {
  if (line ~ /^ *#/) next
  sub(/ +#.*$/, "", line)
  if (line ~ /^ *$/) next
  i = ind(line)
  if (i == 0) { cfnEnd(); sec = line; sub(/:.*/, "", sec); lvl = -1; next }
  if (sec != "Parameters" && sec != "Resources") next
  if (lvl < 0) lvl = i
  if (i == lvl) { cfnEnd(); item = trim(line); sub(/:.*/, "", item); itemL = FNR; noecho = 0; rtype = ""; rotref = ""; ssmname = ""; envI = -1; actI = -1; next }
  if (rtype == "AWS::KMS::Key") {
    if (line ~ /^ *- +["']?(Sid|Effect|Principal|NotPrincipal|Action|NotAction|Resource|Condition)["']? *:/) kmsFlush()
    if (line ~ /:root["']?( |$)/) kmsRoot = 1
  }
  if (!yamlkey(line)) {
    if (actI >= 0 && (i < actI || (i == actI && line !~ /^ *- /))) actI = -1
    if (actI >= 0 && line ~ /^ *- / && wild(line)) { CHK["S5"]++; if (rtype == "AWS::KMS::Key") kmsSeen(at(), item); else fail("S5", "Medium", at(), "wildcard IAM action in " item) }
    else if (actI >= 0 && line ~ /^ *- /) CHK["S5"]++
    next
  }
  if (envI >= 0 && (i < envI || (i == envI && line !~ /^ *- /))) { envFlush(); envI = -1 }
  if (rotNext) { rotNext = 0; if (YK == "Ref") { rotref = YV; gsub(/["']/, "", rotref) } }
  if (actI >= 0 && (i < actI || (i == actI && line !~ /^ *- /))) actI = -1
  if (sec == "Parameters") {
    if (YK == "NoEcho" && YV ~ /^["']?true["']?$/) noecho = 1
    if (YK == "Default" && secretish(item) && literal(YV, 1)) fail("S1", "High", at(), "parameter " item " has a literal Default value")
    next
  }
  if (YK == "Type" && rtype == "") { rtype = YV; gsub(/["']/, "", rtype) }
  if (YK == "SecretId" && YV == "") rotNext = 1
  if (YK == "SecretId") { rotref = YV; sub(/^!Ref */, "", rotref); sub(/^Ref: */, "", rotref); gsub(/["']/, "", rotref) }
  if (YK == "Name" && envI < 0) { ssmname = YV }
  if (YK == "Environment" && YV == "") { envI = i; next }
  if (YK ~ /^(Action|NotAction)$/) {
    if (YV == "") { actI = i; next }
    CHK["S5"]++
    if (wildany(YV)) { if (rtype == "AWS::KMS::Key") kmsSeen(at(), item); else fail("S5", "Medium", at(), "wildcard IAM action in " item) }
    next
  }
  if (envI >= 0) {
    if (line ~ /^ *- /) envFlush()
    if (YK == "Type" && YV ~ /^["']?(SECRETS_MANAGER|PARAMETER_STORE)["']?$/) { entStore = 1; penName = ""; next }
    if (YK == "Name") { CHK["S3"]++; if (secretish(YV) && !entStore) { penName = YV; penAt = at(); penItem = item } }
    else if (YK != "Value" && YK != "Variables" && YK != "Type") { CHK["S3"]++; if (secretish(YK)) fail("S3", "High", at(), "secret " YK " passed as a plain environment variable in " item "; read it from Secrets Manager or SSM SecureString at runtime") }
    next
  }
  if (secretish(YK) && literal(YV, 1)) fail("S1", "High", at(), "literal value for " YK " in " item)
  next
}
# --- Terraform / OpenTofu --------------------------------------------------------
K == "tf" || K == "tfvars" {
  if (inCmt) { if (line ~ /\*\//) { sub(/^.*\*\//, "", line); inCmt = 0 } else next }
  if (line ~ /\/\*/ && line !~ /\*\//) { sub(/\/\*.*$/, "", line); inCmt = 1 }
  if (line ~ /^ *(#|\/\/)/) next
  sub(/ +(#|\/\/) .*$/, "", line)
  if (line ~ /^ *$/) next
  if (K == "tfvars") {
    if (match(line, /^ *[A-Za-z0-9_-]+ *=/)) {
      k = substr(line, RSTART, RLENGTH); sub(/ *=$/, "", k); k = trim(k); v = substr(line, RSTART + RLENGTH)
      if (secretish(k) && literal(v, 0)) fail("S1", "High", at(), "literal value for " k " in a tfvars file")
    }
    next
  }
  pre = tfD
  if (tfD == 0) {
    tfB = ""; tfN = ""; tfT = ""
    if (match(line, /^(resource|data) "[^"]+" "[^"]+"/)) { s = substr(line, RSTART, RLENGTH); split(s, P, "\""); tfB = P[1]; tfT = P[2]; tfN = P[4]; sub(/ +$/, "", tfB); if (tfB == "resource") TFRES++; tfL = FNR; tfSens = 0; tfType = ""; tfSecretRef = "" }
    else if (match(line, /^(variable|output) "[^"]+"/)) { s = substr(line, RSTART, RLENGTH); split(s, P, "\""); tfB = P[1]; tfN = P[2]; sub(/ +$/, "", tfB); tfL = FNR; tfSens = 0 }
    else if (match(line, /^(provider|module) "[^"]+"/)) { s = substr(line, RSTART, RLENGTH); split(s, P, "\""); tfB = P[1]; tfT = P[1]; tfN = P[2]; sub(/ +$/, "", tfB); sub(/ +$/, "", tfT); if (tfB == "module") TFRES++ }
    else if (line ~ /^terraform *\{/) tfB = "terraform"
    else if (line ~ /^locals *\{/) tfB = "locals"
  }
  o = line; c = line; no = gsub(/[{\[]/, "", o); nc = gsub(/[}\]]/, "", c); tfD += no - nc
  # A block opened and closed on one line (variable "x" { default = "y" }): check its argument.
  one = (pre == 0 && tfB != "" && no > 0 && tfD == 0)
  if (one) { inner = line; sub(/^[^{]*\{/, "", inner); sub(/\}[^}]*$/, "", inner); if (match(inner, /^ *"?[A-Za-z0-9_-]+"? *=/)) tfkv(substr(inner, RSTART, RLENGTH), substr(inner, RSTART + RLENGTH)) }
  kmsTf = (tfT ~ /^aws_kms_key/ || tfT == "aws_iam_policy_document")
  if (kmsTf) {
    if (line ~ /^ *(statement *\{|\{ *$|\{ *"?[A-Za-z_]+"? *=)/ || line ~ /(^|[^A-Za-z_])"?[Ss]id"? *[=:]/) kmsFlush()
    if (line ~ /:root["']?( |,|\]|$)/) kmsRoot = 1
  }
  if (line ~ /terraform\.workspace/) ENVHINT = ENVHINT == "" ? at() : ENVHINT
  if (line ~ /ignore_changes *= *all/) { CHK["S9"]++; fail("S9", "Medium", at(), "lifecycle ignore_changes = all hides drift in " tfT "." tfN) }
  if (tfB == "terraform") {
    if (match(line, /backend "[^"]+"/)) { s = substr(line, RSTART, RLENGTH); split(s, P, "\""); BACKEND = P[2]; BACKAT = at() }
    if (line ~ /^ *cloud *\{/) { BACKEND = "cloud"; BACKAT = at() }
    if (line ~ /^ *encrypt *= *true/) BENC = 1
    if (line ~ /^ *(dynamodb_table *=|use_lockfile *= *true)/) BLOCK = 1
  }
  if (actOpen) {
    CHK["S5"]++
    if (wildany(line)) tfwild(line)
    if (line ~ /\]/) actOpen = 0
  } else if (match(line, /(^|[^A-Za-z_])"?(Action|NotAction|actions|not_actions)"? *[=:]/)) {
    rest = substr(line, RSTART + RLENGTH); CHK["S5"]++
    if (wildany(rest)) tfwild(rest)
    if (rest ~ /\[/ && rest !~ /\]/) actOpen = 1
  }
  envOpen = 0
  if (envD < 0 && line ~ /(^|[^A-Za-z_])"?environment"? *[=:]? *[\[{]/) { envD = pre; envOpen = 1 }
  if (envD >= 0) {
    # Environment entries: every name = "X" on the line (ECS), else a KEY = value line (Lambda variables).
    t = line; found = 0
    while (match(t, /(^|[^A-Za-z0-9_])"?name"? *[=:] *"[^"]*"/)) {
      nm = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH); sub(/^.*name"? *[=:] *"/, "", nm); sub(/"$/, "", nm); found = 1; CHK["S3"]++
      if (secretish(nm)) fail("S3", "High", at(), "secret " nm " passed as a plain environment value in " tfT "." tfN "; use secrets/valueFrom or read it at runtime")
    }
    # An inline map (variables = { DB_PASSWORD = "x", LEVEL = "info" }): every key in it.
    if (!found && line ~ /\{.*[A-Za-z0-9_] *=/) {
      t = line; sub(/^[^{]*\{/, "", t); gsub(/"[^"]*"/, "\"\"", t)
      while (match(t, /[A-Za-z0-9_-]+ *=/)) {
        k = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH); sub(/ *=$/, "", k); found = 1; CHK["S3"]++
        if (k != "value" && k != "variables" && k != "valueFrom" && secretish(k)) fail("S3", "High", at(), "secret " k " passed as a plain environment variable in " tfT "." tfN "; read it from Secrets Manager or SSM SecureString at runtime")
      }
    }
    if (!found && !envOpen && match(line, /^ *"?[A-Za-z0-9_-]+"? *[=:]/)) {
      k = substr(line, RSTART, RLENGTH); sub(/ *[=:]$/, "", k); k = trim(k); gsub(/"/, "", k)
      if (k != "value" && k != "variables" && k != "valueFrom") { CHK["S3"]++; if (secretish(k)) fail("S3", "High", at(), "secret " k " passed as a plain environment variable in " tfT "." tfN "; read it from Secrets Manager or SSM SecureString at runtime") }
    }
  } else if (!one && match(line, /^ *"?[A-Za-z0-9_-]+"? *[=:]/)) tfkv(substr(line, RSTART, RLENGTH), substr(line, RSTART + RLENGTH))
  if (envD >= 0 && tfD <= envD) envD = -1
  if (tfD == 0 && (pre > 0 || one)) {
    kmsFlush()
    if (tfB == "variable") {
      VARS[++NVAR] = tfN; CHK["S10"]++
      if (envish(tfN)) ENVHINT = ENVHINT == "" ? FN ":" tfL : ENVHINT
    }
    if ((tfB == "variable" || tfB == "output") && secretish(tfN)) { CHK["S2"]++; if (!tfSens) fail("S2", "Medium", FN ":" tfL, tfB " " tfN " is sensitive but has no sensitive = true") }
    if (tfT == "aws_secretsmanager_secret") { SECRET[++NSEC] = tfN; SECAT[NSEC] = FN ":" tfL }
    if (tfT == "aws_ssm_parameter") { CHK["S3"]++; if (tfType != "SecureString" && (secretish(tfN) || secretish(tfSecretRef))) fail("S3", "High", FN ":" tfL, "SSM parameter " tfN " holds a secret but its type is not SecureString") }
    tfB = ""; tfT = ""; tfN = ""
  }
  next
}
# --- Dockerfile ------------------------------------------------------------------
K == "docker" {
  if (line ~ /^ *#/) next
  if (dacc == "") dl = FNR
  if (line ~ /\\ *$/) { sub(/\\ *$/, " ", line); dacc = dacc line; next }
  line = dacc line; dacc = ""
  if (line ~ /^ *$/) next
  u = line; sub(/^ +/, "", u); w = toupper(substr(u, 1, 4))
  if (w == "ENV " || toupper(substr(u, 1, 4)) == "ARG ") {
    rest = substr(u, 5); n = split(rest, T, " ")
    isenv = (w == "ENV ")
    if (rest !~ /=/ && n >= 2) { CHK["S1"]++; if (secretish(T[1])) fail("S1", "High", FN ":" dl, "secret " T[1] " baked into the image by " substr(u, 1, 3) "; pass it at run time from a secret store") }
    for (j = 1; j <= n; j++) if (T[j] ~ /=/) {
      k = T[j]; sub(/=.*/, "", k); v = T[j]; sub(/^[^=]*=/, "", v); gsub(/["']/, "", v); CHK["S1"]++
      if (secretish(k) && (isenv || (v != "" && v !~ /^\$/))) fail("S1", "High", FN ":" dl, "secret " k " baked into the image by " substr(u, 1, 3) "; pass it at run time from a secret store")
    }
  }
  if (toupper(substr(u, 1, 5)) == "COPY " || toupper(substr(u, 1, 4)) == "ADD ") {
    n = split(u, T, " "); CHK["S8"]++
    for (j = 2; j < n; j++) { t = T[j]; sub(/^.*\//, "", t); if (t ~ /^(\.env|\.env\..+|.+\.env)$/ && t !~ /\.(example|sample|template|dist)$/) { fail("S8", "High", FN ":" dl, "an env file (" t ") is copied into the image"); break } }
  }
  next
}
# --- Compose ---------------------------------------------------------------------
K == "compose" {
  if (line ~ /^ *#/) next
  sub(/ +#.*$/, "", line)
  if (line ~ /^ *$/) next
  i = ind(line)
  if (i == 0) { inSvc = (line ~ /^services: *$/); svcI = -1; inEnv = 0; next }
  if (!inSvc) next
  if (svcI < 0) svcI = i
  if (i == svcI) { svc = trim(line); sub(/:.*/, "", svc); inEnv = 0; next }
  if (inEnv && (i < envKI || (i == envKI && line !~ /^ *- /))) inEnv = 0
  if (!inEnv && yamlkey(line) && i > svcI) {
    if (YK == "environment" && YV == "") { inEnv = 1; envKI = i; next }
    if (YK == "env_file") { CHK["S8"]++; if (lc(FN) ~ /prod/ && lc(FN) !~ /local|dev|test|example/) fail("S8", "Medium", at(), "production Compose service " svc " reads an env file; use a config store or Compose secrets") }
    next
  }
  if (inEnv) {
    e = trim(line); isl = (e ~ /^- /); sub(/^- */, "", e); gsub(/["']/, "", e)
    if (isl) { k = e; sub(/=.*/, "", k); v = (e ~ /=/) ? e : ""; sub(/^[^=]*=?/, "", v) }
    else { k = e; sub(/ *:.*/, "", k); v = e; sub(/^[^:]*: */, "", v) }
    k = trim(k); v = trim(v); CHK["S3"]++
    if (!secretish(k)) next
    if (v != "" && v !~ /^\$/) fail("S1", "High", at(), "literal value for " k " in service " svc)
    else fail("S3", "Medium", at(), "secret " k " passed to service " svc " as an environment value; use Compose secrets (a mounted file)")
  }
  next
}
# --- ECS task-definition JSON ----------------------------------------------------
K == "taskjson" {
  t = line
  if (!inEnv && match(t, /"environment" *: *\[/)) { inEnv = 1; envDep = 0; t = substr(t, RSTART + RLENGTH - 1) }
  if (!inEnv) next
  # Only the text inside the environment array, which may close on this line.
  seg = ""
  for (q = 1; q <= length(t); q++) { ch = substr(t, q, 1); if (ch == "[") envDep++; else if (ch == "]" && --envDep == 0) { inEnv = 0; break }; seg = seg ch }
  while (match(seg, /"name" *: *"[^"]*"/)) {
    s = substr(seg, RSTART, RLENGTH); seg = substr(seg, RSTART + RLENGTH); sub(/^"name" *: *"/, "", s); sub(/"$/, "", s); CHK["S3"]++
    if (secretish(s)) fail("S3", "High", at(), "secret " s " passed as a plain environment value; use \"secrets\" with valueFrom")
  }
  next
}
END {
  cfnEnd()
  NIAC = KN["cfn"] + KN["tf"]
  CHK["S1"] += KN["cfn"] + KN["tf"] + KN["tfvars"] + KN["docker"] + KN["compose"] + KN["taskjson"]
  # S4 — Terraform state
  ns = split(STATES, ST, "\n")
  for (j = 1; j <= ns; j++) if (ST[j] != "") { s = ST[j]; sub(/^\.\//, "", s); CHK["S4"]++; fail("S4", "High", s ":1", "Terraform state file in the repository (it can hold secrets; remove it and rotate them → ascent-security)") }
  if (KN["tf"] > 0) {
    CHK["S4"]++
    if (BACKEND == "" && TFRES > 0) fail("S4", "High", "absent", "no backend block: Terraform state is local (searched " KN["tf"] " .tf file(s)); use a remote, encrypted, locked backend")
    else if (BACKEND == "local") fail("S4", "High", BACKAT, "backend \"local\" keeps state on disk; use a remote, encrypted, locked backend")
    else if (BACKEND == "s3") {
      if (!BENC) fail("S4", "High", BACKAT, "S3 backend without encrypt = true")
      if (!BLOCK) fail("S4", "High", BACKAT, "S3 backend without locking (use_lockfile = true or dynamodb_table)")
    }
  }
  # S6 — rotation
  for (j = 1; j <= NSEC; j++) { CHK["S6"]++; if (!(SECRET[j] in ROT)) fail("S6", "Low", SECAT[j], "secret " SECRET[j] " has no rotation schedule") }
  # S7 — per-environment configuration
  if (NIAC > 0) {
    CHK["S7"]++
    if (ENVHINT == "" && ENVFILES == "") fail("S7", "Medium", "absent", "no per-environment configuration: no environment parameter or variable, per-environment tfvars or parameter files, workspace or environment directory")
  }
  # S9 — drift detection
  if (NIAC > 0) {
    CHK["S9"]++
    if (DRIFT == "") fail("S9", "Medium", "absent", "no drift check found in CI, make targets or scripts (terraform plan -detailed-exitcode, aws cloudformation detect-stack-drift, driftctl)")
  }
  # S10 — configuration documented in the manual
  if (MANUAL != "" && NPARAM + NVAR > 0) {
    if (MTEXT == "") fail("S10", "Low", MANUAL, "manual not found")
    else {
      while ((getline ml < MTEXT) > 0) DOC = DOC "\n" ml
      close(MTEXT); miss = ""; nm = 0
      for (j = 1; j <= NPARAM; j++) if (index(DOC, PARAMS[j]) == 0) { nm++; if (nm <= 10) miss = miss (miss == "" ? "" : ", ") PARAMS[j] }
      for (j = 1; j <= NVAR; j++) if (index(DOC, VARS[j]) == 0) { nm++; if (nm <= 10) miss = miss (miss == "" ? "" : ", ") VARS[j] }
      if (nm > 0) fail("S10", "Low", MANUAL ":1", nm " of " NPARAM + NVAR " configuration parameter(s) not documented in the manual: " miss (nm > 10 ? ", ..." : ""))
    }
  }
  split("S1 S2 S3 S4 S5 S6 S7 S8 S9 S10", ORDER, " ")
  D["S1"] = "no secret values written as literals or defaults"
  D["S2"] = "sensitive parameters are marked (NoEcho, sensitive)"
  D["S3"] = "secrets come from a secret store, not plain environment values"
  D["S4"] = "Terraform state is remote, encrypted and locked"
  D["S5"] = "IAM policies grant no wildcard actions"
  D["S6"] = "secrets have a rotation schedule"
  D["S7"] = "configuration is separated per environment"
  D["S8"] = "no .env file in an image or a production Compose file"
  D["S9"] = "drift is detected and not hidden"
  D["S10"] = "configuration is documented in the manual"
  CHK["S8"] = KN["docker"] + KN["compose"]
  for (j = 1; j <= 10; j++) {
    k = ORDER[j]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (k == "S10" && MANUAL == "") printf "N/A   %-4s %s (no --manual given)\n", k, D[k]
    else if (CHK[k] > 0) printf "PASS  %-4s %s (%d checked)\n", k, D[k], CHK[k]
    else printf "N/A   %-4s %s (nothing to check)\n", k, D[k]
  }
  printf "%s", NOTES
  printf "check-iac-config: %d file(s) (CloudFormation %d, Terraform %d, tfvars %d, Dockerfile %d, Compose %d, task definition %d), %d failure(s)\n", \
    NFILES - KN["ci"] - KN["none"], KN["cfn"], KN["tf"], KN["tfvars"], KN["docker"], KN["compose"], KN["taskjson"], NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
