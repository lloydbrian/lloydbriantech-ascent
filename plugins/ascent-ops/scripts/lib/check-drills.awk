# check-drills.awk — the checks of check-drills.sh, which passes the file list and the
# ENVIRON values. A separate file keeps bash 3.2 from parsing the program (a quoted
# heredoc inside $(...) breaks there). Run with LC_ALL=C. No regex intervals: some
# awks lack them.
BEGIN {
  TODAY = ENVIRON["CDR_TODAY"]; MAXAGE = ENVIRON["CDR_MAXAGE"] + 0; MAT = ENVIRON["CDR_MATURITY"]
  RTO = ENVIRON["CDR_RTO"]; RPO = ENVIRON["CDR_RPO"]; READY = ENVIRON["CDR_READY"]; MANUAL = ENVIRON["CDR_MANUAL"]
  REPO = ENVIRON["CDR_REPO"]; DIR = ENVIRON["CDR_DIR"]; sub(/\/+$/, "", REPO); if (REPO == "") REPO = "/"
  NP = 0; n = split(ENVIRON["CDR_PATHS"], L, "\n")
  for (i = 1; i <= n; i++) if (L[i] != "") { split(L[i], F, "\t"); NP++; PN[NP] = F[1]; PK[NP] = F[2]; PR[NP] = F[3]; ISPATH[F[1], F[2]] = 1 }
  NA = 0; n = split(ENVIRON["CDR_ALERTS"], L, "\n")
  for (i = 1; i <= n; i++) if (L[i] != "") { split(L[i], F, "\t"); NA++; AN[NA] = F[1]; AR[NA] = F[2]; AP[NA] = F[3] + 0 }
  split("path kind date result measured_rto measured_rpo evidence follow_up runbook reached probe probe_status", KEYS, " ")
  for (i in KEYS) ISKEY[KEYS[i]] = 1
  # Which rules the maturity target requires.
  split("R1 R2 R3 R4 R5 R6 R7 R8 X1 X2 X3", ORDER, " ")
  for (i = 1; i <= 11; i++) REQ[ORDER[i]] = (MAT == "enterprise") || (MAT == "standard" && i <= 5)
  # Records and runbooks are registered from ARGV, raw: an empty file reads no line,
  # and awk escape-processes RB=... when it assigns it (a backslash in a path).
  kk = ""; rb = ""
  for (i = 1; i < ARGC; i++) {
    if (ARGV[i] ~ /^K=/) { kk = substr(ARGV[i], 3); continue }
    if (ARGV[i] ~ /^RB=/) { rb = substr(ARGV[i], 4); continue }
    fn = ARGV[i]; sub(/^\.\//, "", fn)
    if (kk == "record") { NR_++; RF[NR_] = fn; RIDX[ARGV[i]] = NR_ }
    if (kk == "runbook") { RBSEEN[rb] = 1; RBF[rb] = fn; RBOF[ARGV[i]] = rb }
  }
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function norm(s) { s = tolower(s); gsub(/[^a-z0-9]/, "", s); return s }
function fail(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "OPS-" k, sev, where, msg); NF_[k]++; if (sev == "High") NHIGH[k]++; if (sev == "High") HIGH[k] = HIGH[k] sprintf("FAIL  %-7s %-6s %s  %s\n", "OPS-" k, sev, where, msg) }
function isdate(d,   y, m, dd) {   # YYYY-MM-DD and a real calendar day
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m < 1 || m > 12 || dd < 1) return 0
  if (m == 2) return dd <= 28 + ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)
  return dd <= ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
}
# A record value fit to print: short, plain characters, no "@", "?", "=" or "%".
# Anything else (a URL with credentials, an email address, a control character)
# is withheld, so a message never carries what OPS-R5 is about.
function safe(v) { return (v ~ /^[A-Za-z0-9._\/:+ -]*$/ && length(v) <= 60) ? v : "<value withheld>" }
function days(d,   y, m, dd, a, yy, mm) {   # days since 1970-01-01 (civil calendar)
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  a = (m <= 2) ? 1 : 0; yy = y - a; mm = m + 12 * a - 3
  return 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + int((153 * mm + 2) / 5) + dd - 719469
}
# A duration in seconds: <n>d, <n>h, <n>m, <n>s, combined; "0" is zero. -1 when unreadable.
function dur(s,   t, v, u, tot) {
  s = tolower(trim(s)); gsub(/ /, "", s)
  if (s == "0") return 0
  if (s == "" || s !~ /^([0-9]+[dhms])+$/) return -1
  tot = 0
  while (match(s, /^[0-9]+[dhms]/)) {
    t = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1); u = substr(t, length(t)); v = substr(t, 1, length(t) - 1) + 0
    tot += v * (u == "d" ? 86400 : u == "h" ? 3600 : u == "m" ? 60 : 1)
  }
  return tot
}
function secretish(n,   l) {
  l = tolower(n); gsub(/-/, "_", l)
  if (l ~ /(arn|id|name|path|file|url|ttl|length|version|ref|type|store|manager|policy|rotation|count|expires|expiry|at|days|age|seconds|minutes|hours)$/) return 0
  return l ~ /(password|passwd|passphrase|secret|token|apikey|api_key|private_key|access_key|secret_key|credential)/
}
# OPS-R5 on one line of a record or of its evidence. Values are never printed.
function scan(line, where,   tt, k, v, rest, eq, n, C, cell, url) {
  if (line ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/) fail("R5", "High", where, "private key block; remove it and rotate the key (→ ascent-security)")
  if (line ~ /AKIA[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]/) fail("R5", "High", where, "AWS access key id; remove it and rotate the key (→ ascent-security)")
  # A password in a URL (postgres://app:pw@db/app) or a bearer or basic token.
  if (line ~ /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\/:@ "']+:[^\/@ "']+@/) { fail("R5", "High", where, "a credential in a URL; remove it and rotate it (→ ascent-security)"); url = 1 } else url = 0
  if (match(line, /[Bb](earer|asic) +[A-Za-z0-9._~+\/=-]+/) && RLENGTH >= 22) fail("R5", "High", where, "an authorization token; remove it and rotate it (→ ascent-security)")
  # A Markdown table row whose key cell is credential-like: | db_password | value |.
  if (line ~ /^ *\|/) {
    n = split(line, C, "|"); k = C[2]; gsub(/[` *]/, "", k); cell = C[3]; gsub(/^[ \t`]+|[ \t`]+$/, "", cell)
    if (n >= 4 && secretish(k) && cell !~ /^(\$|\*\*\*|\.\.\.|xxx|XXX|REDACTED|redacted|none|null|true|false|—|-|\(|\{\{|arn:|ssm:|secretsmanager|resolve)/ && cell !~ / / && length(cell) >= 6) fail("R5", "High", where, "credential-like value for " k "; never keep secret values in a drill record or its evidence (→ ascent-security)")
  }
  tt = line
  while (match(tt, /["']?[A-Za-z_][A-Za-z0-9_.-]*["']? *(=|:) */)) {
    k = substr(tt, RSTART, RLENGTH); tt = substr(tt, RSTART + RLENGTH)
    eq = (k ~ /= *$/)
    sub(/["']? *(=|:) *$/, "", k); gsub(/["']/, "", k)
    if (!secretish(k) || !match(tt, /^["']?[^ "'<>|`,}]+/)) continue
    v = substr(tt, RSTART, RLENGTH); sub(/^["']/, "", v); rest = substr(tt, RLENGTH + 1)
    if (v ~ /^(\$|\*\*\*|\.\.\.|xxx|XXX|REDACTED|redacted|none|null|true|false|\(|\{\{|arn:|ssm:|secretsmanager|resolve)/ || length(v) < 6) continue
    # prose after a colon ("password: stored in the vault"); never after "=", where a
    # command follows the value (PGPASSWORD=... pg_restore).
    if (!eq && substr(rest, 1, 1) == " " && substr(rest, 2, 1) ~ /[A-Za-z]/) continue
    fail("R5", "High", where, "credential-like value for " k "; never keep secret values in a drill record or its evidence (→ ascent-security)")
  }
  if (!url && line ~ /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z][A-Za-z]+/) fail("R5", "Medium", where, "an email address; name the role that answered, never the person")
  if (line ~ /(^|[^0-9.:-])(\+?[0-9][0-9]?[0-9]?[ .-])?\(?[0-9][0-9][0-9]\)?[ .-][0-9][0-9][0-9][ .-][0-9][0-9][0-9][0-9]([^0-9]|$)/) fail("R5", "Medium", where, "a phone number; name the role that answered, never the person")
}
FNR == 1 { FN = FILENAME; sub(/^\.\//, "", FN); inCode = 0; sec = ""; inBk = 0; svcI = -1; inSvc = 0; secTop = ""; res = ""; rty = ""; CUR = RIDX[FILENAME]; if (K == "runbook") RB = RBOF[FILENAME] }
{ line = $0; sub(/\r$/, "", line) }
# --- records ------------------------------------------------------------------------
K == "record" {
  scan(line, FN ":" FNR)
  if (line ~ /^ *\|/ && line !~ /^ *\| *:?-+/) {
    n = split(line, C, "|"); key = tolower(trim(C[2])); gsub(/[` *]/, "", key); gsub(/-/, "_", key)
    if (n >= 4 && (key in ISKEY) && !((CUR, key) in V)) {
      v = trim(C[3]); gsub(/`/, "", v); if (v == "—" || v == "-" || v == "–" || tolower(v) == "none" || tolower(v) == "n/a") v = ""
      V[CUR, key] = v; VL[CUR, key] = FNR
    }
  }
  next
}
# --- runbooks (OPS-R2) ------------------------------------------------------------------
K == "runbook" {
  if (line ~ /^```/) { inCode = !inCode; next }
  if (inCode) next
  l = tolower(line)
  if (line ~ /^#+ /) {
    if (l ~ /pre-?flight|pre flight/) RBPRE[RB] = 1
    if (l ~ /post-?flight|post flight/) RBPOST[RB] = 1
    if (l ~ /rollback|roll back/) RBBACK[RB] = 1
    next
  }
  if (l ~ /expect/) RBEXP[RB] = 1
  if (l ~ /stop if/) RBSTOP[RB] = 1
  next
}
# --- the Maintenance manual (OPS-R7) -------------------------------------------------
K == "manual" {
  MSEEN = 1; MFN = FN
  if (line ~ /^```/) { inCode = !inCode; next }
  if (inCode) next
  if (line ~ /^## /) { inBk = (tolower(line) ~ /backup/); if (inBk) BKLINE = FNR; next }
  if (inBk && tolower(line) ~ /restore/) {
    t = line; gsub(/\]\([^)]*\)/, "]", t)   # a link to the record carries its date, not the manual's
    while (match(t, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { d = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH); if (d <= TODAY && d > MDATE) { MDATE = d; MDATEL = FNR } }   # a planned date is not a restore
  }
  next
}
# --- IaC: backups (proposed paths) and failover (OPS-R8) ------------------------------
K == "cfn" || K == "tf" {
  if (line ~ /^[ \t]*#/) next
  c = line; sub(/[ \t]+#.*$/, "", c)
  if (K == "cfn" && match(c, /^  [A-Za-z0-9]+:[ \t]*$/)) { res = trim(c); sub(/:.*/, "", res) }
  if (K == "tf" && match(c, /^resource +"[^"]+" +"[^"]+"/)) { s = substr(c, RSTART, RLENGTH); split(s, P, "\""); res = P[4]; rty = P[2] }
  if (c ~ /BackupRetentionPeriod:[ \t]*["']?[1-9]/ || c ~ /backup_retention_period[ \t]*=[ \t]*[1-9]/) bk(res, "backup retention")
  if (c ~ /PointInTimeRecoveryEnabled:[ \t]*true/ || (K == "tf" && c ~ /^[ \t]*point_in_time_recovery[ \t]*\{/)) bk(res, "point-in-time recovery")
  if (c ~ /Type:[ \t]*["']?AWS::Backup::BackupPlan/ || c ~ /^resource +"aws_backup_plan"/) bk(res, "backup plan")
  if (c ~ /VersioningConfiguration:/ || c ~ /^resource +"aws_s3_bucket_versioning"/) bk(res, "versioning")
  if (c ~ /MultiAZ:[ \t]*["']?true/ || c ~ /multi_az[ \t]*=[ \t]*true/) fo(res, "Multi-AZ")
  if (c ~ /Failover:[ \t]*["']?(PRIMARY|SECONDARY)/ || c ~ /failover_routing_policy/) fo(res, "Route 53 failover")
  if (c ~ /Type:[ \t]*["']?AWS::(DynamoDB::GlobalTable|RDS::GlobalCluster)/ || c ~ /^resource +"aws_(dynamodb_global_table|rds_global_cluster)"/) fo(res, "global table or cluster")
  if (K == "tf" && rty == "aws_dynamodb_table" && c ~ /^[ \t]*replica[ \t]*\{/) fo(res, "global table replica")
  if (c ~ /SourceDBInstanceIdentifier:/ || c ~ /replicate_source_db[ \t]*=/) fo(res, "read replica")
  next
}
K == "compose" {
  if (line ~ /^ *#/ || line ~ /^ *$/) next
  match(line, /^ */); i = RLENGTH
  if (i == 0) { inSvc = (line ~ /^services: *$/); svcI = -1; next }
  if (!inSvc) next
  if (svcI < 0) svcI = i
  if (i == svcI && line ~ /^ *[A-Za-z0-9_.-]+: *$/) { svc = trim(line); sub(/:.*/, "", svc); next }
  if (line ~ /^ *image: *["']?[^ ]*(postgres|mysql|mariadb|mongo)[:@"' ]/ || line ~ /^ *image: *["']?[^ ]*(postgres|mysql|mariadb|mongo) *$/) bk(svc, "database volume")
  next
}
function bk(name, what) { NBK++; BKN[NBK] = name; BKW[NBK] = what; BKAT[NBK] = FN ":" FNR }
function fo(name, what) { NFO++; FON[NFO] = name; FOW[NFO] = what; FOAT[NFO] = FN ":" FNR }
# The newest record of PATH and KIND (result "" for any, or "pass"); 0 if none.
function newest(path, kind, result, fresh,   i, best) {
  best = 0
  for (i = 1; i <= NR_; i++) {
    if (V[i, "path"] != path || V[i, "kind"] != kind || !isdate(V[i, "date"])) continue
    if (result != "" && V[i, "result"] != result) continue
    if (fresh && (days(TODAY) - days(V[i, "date"]) > MAXAGE || V[i, "date"] > TODAY)) continue
    if (!best || V[i, "date"] >= V[best, "date"]) best = i
  }
  return best
}
function at(i, key) { return RF[i] ":" ((i, key) in VL ? VL[i, key] : 1) }
END {
  SEP = sprintf("%c", 0)
  # Every record: its fields (OPS-R3), its evidence (OPS-R5) and its follow-up (OPS-R6).
  for (i = 1; i <= NR_; i++) {
    CHK["R3"]++; CHK["R5"]++
    miss = ""
    split("path kind date result", RQ, " ")
    for (j = 1; j <= 4; j++) if (V[i, RQ[j]] == "") miss = miss " " RQ[j]
    if (miss != "") fail("R3", "Low", RF[i] ":1", "record is missing field(s):" miss)
    k = V[i, "kind"]; r = V[i, "result"]; d = V[i, "date"]
    if (k != "" && k !~ /^(restore|failover|alarm|readiness|dry-run)$/) fail("R3", "Low", at(i, "kind"), "kind is \"" safe(k) "\"; use restore, failover, alarm, readiness or dry-run")
    if (r != "" && r !~ /^(pass|fail)$/) fail("R3", "Low", at(i, "result"), "result is \"" safe(r) "\"; use pass or fail")
    if (d != "" && !isdate(d)) fail("R3", "Low", at(i, "date"), "date \"" safe(d) "\" is not a YYYY-MM-DD calendar date")
    else if (d != "") {
      b = RF[i]; sub(/^.*\//, "", b)
      if (substr(b, 1, 10) != d) fail("R3", "Low", at(i, "date"), "date " d " differs from the file name")
      if (d > TODAY) fail("R3", "Low", at(i, "date"), "date " d " is in the future")
    }
    if ((k == "restore" || k == "failover") && V[i, "path"] != "" && !((V[i, "path"], k) in ISPATH)) NOTES = NOTES sprintf("NOTE  OPS-R3  -      %s:1  %s record for \"%s\", which no recovery path names\n", RF[i], k, safe(V[i, "path"]))
    # OPS-R5 — evidence inside the repository, present, and clean.
    ev = V[i, "evidence"]
    if (ev == "") fail("R5", "Medium", at(i, "evidence"), "no evidence: name the output files the drill produced")
    ne = split(ev, E, ",")
    for (j = 1; j <= ne; j++) {
      e = trim(E[j]); if (match(e, /\]\([^)]+\)/)) e = substr(e, RSTART + 2, RLENGTH - 3)
      if (e == "") continue
      if (e ~ /^\// || e ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || e ~ /(^|\/)\.\.(\/|$)/) { fail("R5", "Medium", at(i, "evidence"), "evidence " safe(e) " is outside the repository; commit it under the drills folder"); continue }
      f = REPO "/" e; got = 0; ln = 0
      while ((rc = (getline x < f)) > 0) { got = 1; ln++; sub(/\r$/, "", x); scan(x, e ":" ln) }
      if (rc < 0 && !got) fail("R5", "Medium", at(i, "evidence"), "evidence " safe(e) " not found")
      close(f)
    }
    # OPS-R6 — a failed drill is followed up.
    if (r == "fail") {
      CHK["R6"]++
      if (V[i, "follow_up"] == "") {
        later = 0
        for (j = 1; j <= NR_; j++) if (V[j, "path"] == V[i, "path"] && V[j, "kind"] == k && V[j, "result"] == "pass" && V[j, "date"] > d) later = 1
        if (!later) fail("R6", "Medium", at(i, "result"), "failed " k " drill with no follow_up and no later passing drill")
      }
    }
  }
  # OPS-R1, R2, R3 and R4 — each recovery path.
  if (NP == 0 && NBK > 0) {
    w = ""; for (j = 1; j <= NBK && j <= 5; j++) w = w (w == "" ? "" : ", ") BKN[j] " (" BKW[j] ", " BKAT[j] ")"
    fail("R1", "Low", BKAT[1], "the IaC declares backups but no recovery path is given (ops.drills.paths, unmeasured): " w (NBK > 5 ? ", ..." : ""))
  }
  for (p = 1; p <= NP; p++) {
    CHK["R1"]++; CHK["R3"]++
    if (PR[p] == "") fail("R1", "Medium", "absent", PN[p] " (" PK[p] ") names no runbook")
    else if (!(PR[p] in RBSEEN)) fail("R1", "Medium", "absent", PN[p] " (" PK[p] "): runbook " PR[p] " not found")
    else {
      CHK["R2"]++; miss = ""
      if (!RBPRE[PR[p]]) miss = miss ", pre-flight"
      if (!RBPOST[PR[p]]) miss = miss ", post-flight"
      if (!RBBACK[PR[p]]) miss = miss ", rollback"
      if (!RBEXP[PR[p]]) miss = miss ", Expect"
      if (!RBSTOP[PR[p]]) miss = miss ", Stop if"
      if (miss != "" && !(PR[p] in R2DONE)) { R2DONE[PR[p]] = 1; fail("R2", "Medium", RBF[PR[p]] ":1", "runbook for " PN[p] " lacks " substr(miss, 3) " (references/runbook-standard.md)") }
    }
    b = newest(PN[p], PK[p], "pass", 1)
    if (!b) {
      a_ = newest(PN[p], PK[p], "", 0); ap = newest(PN[p], PK[p], "pass", 0)
      if (!a_) fail("R3", "Medium", "absent", "no " PK[p] " drill record for " PN[p] " in " DIR)
      else if (!ap) fail("R3", "Medium", at(a_, "result"), "no passing " PK[p] " drill for " PN[p] "; the newest, " V[a_, "date"] ", failed")
      else fail("R3", "Medium", at(ap, "date"), "newest passing " PK[p] " drill for " PN[p] " is " days(TODAY) - days(V[ap, "date"]) " days old (limit " MAXAGE ")")
    }
    if (b && (RTO != "" || RPO != "")) {
      CHK["R4"]++
      split("rto rpo", TG, " ")
      for (j = 1; j <= 2; j++) {
        tgt = (j == 1) ? RTO : RPO; if (tgt == "") continue
        mv = V[b, "measured_" TG[j]]; mt = dur(tgt); mm = dur(mv)
        if (mt < 0) fail("R4", "Medium", "absent", "the " TG[j] " target \"" tgt "\" is not a duration (<n>d, <n>h, <n>m, <n>s)")
        else if (mv == "") fail("R4", "Medium", at(b, "result"), PN[p] ": no measured_" TG[j] " in the newest passing " PK[p] " drill")
        else if (mm < 0) fail("R4", "Medium", at(b, "measured_" TG[j]), PN[p] ": measured_" TG[j] " \"" safe(mv) "\" is not a duration")
        else if (mm > mt) fail("R4", "Medium", at(b, "measured_" TG[j]), PN[p] ": measured_" TG[j] " " safe(mv) " exceeds the " TG[j] " target " tgt)
      }
    } else if (b) R4NOTGT = 1
  }
  # OPS-R7 — the manual's restore date.
  rs = 0; for (p = 1; p <= NP; p++) if (PK[p] == "restore") { b = newest(PN[p], "restore", "pass", 0); if (b && (!rs || V[b, "date"] > V[rs, "date"])) rs = b }
  if (rs && MANUAL != "") {
    CHK["R7"]++
    if (!MSEEN) fail("R7", "Low", "absent", "manual " MANUAL " not found")
    else if (MDATE == "") fail("R7", "Low", MFN ":" (BKLINE ? BKLINE : 1), "the Backup and restore section names no restore date; the newest restore drill is " V[rs, "date"])
    else if (MDATE < V[rs, "date"]) fail("R7", "Low", MFN ":" MDATEL, "the manual's last restore is " MDATE "; the newest restore drill is " V[rs, "date"] " (" RF[rs] ")")
  }
  # OPS-R8 — declared failover has a failover path.
  if (NFO > 0) {
    CHK["R8"]++; has = 0; for (p = 1; p <= NP; p++) if (PK[p] == "failover") has = 1
    if (!has) { w = ""; for (j = 1; j <= NFO && j <= 5; j++) w = w (w == "" ? "" : ", ") FON[j] " (" FOW[j] ", " FOAT[j] ")"; fail("R8", "Low", FOAT[1], "the IaC declares failover but no failover path is given: " w (NFO > 5 ? ", ..." : "")) }
  }
  # OPS-X1 — paging alarms exercised.
  for (a = 1; a <= NA; a++) if (AP[a]) {
    CHK["X1"]++; b = newest(AN[a], "alarm", "pass", 1)
    if (!b) fail("X1", "Low", "absent", "paging alert " AN[a] " has no passing alarm drill in the last " MAXAGE " days")
    else if (V[b, "reached"] == "") fail("X1", "Low", at(b, "result"), "alarm drill for " AN[a] " does not say which role it reached")
  }
  # OPS-X2 — readiness fails with a dependency down.
  if (READY != "") {
    CHK["X2"]++; best = 0; seen = 0
    for (i = 1; i <= NR_; i++) {
      if (V[i, "kind"] != "readiness" || V[i, "result"] != "pass" || !isdate(V[i, "date"]) || days(TODAY) - days(V[i, "date"]) > MAXAGE || V[i, "date"] > TODAY) continue
      seen = i; st = V[i, "probe_status"]
      pr = V[i, "probe"]
      # The contract path, alone or after a scheme and host (http://localhost:8080/-/ready).
      if ((pr == READY || (substr(pr, length(pr) - length(READY) + 1) == READY && substr(pr, 1, length(pr) - length(READY)) ~ /^https?:\/\/[^\/]+$/)) && st ~ /^[0-9][0-9][0-9]$/ && st !~ /^2/) best = i
    }
    if (!best && seen) fail("X2", "Low", at(seen, "probe"), "the readiness drill must show " READY " answering a non-2xx status (probe " safe(V[seen, "probe"]) ", status " safe(V[seen, "probe_status"]) ")")
    else if (!best) fail("X2", "Low", "absent", "no passing readiness drill in the last " MAXAGE " days shows " READY " failing with a dependency down")
  }
  # OPS-X3 — every runbook an alert links to was dry-run.
  for (a = 1; a <= NA; a++) if (AR[a] != "" && !(AR[a] in X3DONE)) {
    X3DONE[AR[a]] = 1; CHK["X3"]++; got = 0
    for (i = 1; i <= NR_; i++) if (V[i, "kind"] == "dry-run" && V[i, "result"] == "pass" && V[i, "runbook"] == AR[a] && isdate(V[i, "date"]) && days(TODAY) - days(V[i, "date"]) <= MAXAGE && V[i, "date"] <= TODAY) got = 1
    if (!got) fail("X3", "Low", "absent", "runbook " AR[a] " (alert " AN[a] ") has no passing dry-run in the last " MAXAGE " days")
  }
  for (j = 1; j <= NBK; j++) {
    named = 0; for (p = 1; p <= NP; p++) if (norm(PN[p]) != "" && (index(norm(BKN[j]), norm(PN[p])) || index(norm(PN[p]), norm(BKN[j])))) named = 1
    if (NP > 0 && !named) NOTES = NOTES sprintf("NOTE  OPS-R1  -      %s  %s on %s: list it in ops.drills.paths if it is a recovery path\n", BKAT[j], BKW[j], BKN[j])
  }
  D["R1"] = "every recovery path has a runbook"
  D["R2"] = "recovery runbooks follow the runbook standard"
  D["R3"] = "every recovery path has a current passing drill"
  D["R4"] = "drills meet the rto and rpo targets"
  D["R5"] = "drill evidence is present, in the repository and clean"
  D["R6"] = "failed drills are followed up"
  D["R7"] = "the manual's restore date is current"
  D["R8"] = "declared failover has a failover drill path"
  D["X1"] = "paging alerts are exercised and reach a role"
  D["X2"] = "readiness fails with a dependency down"
  D["X3"] = "runbooks linked from alerts are dry-run"
  NA_["R1"] = "no recovery path given and no backup in the IaC"
  NA_["R2"] = "no recovery runbook found"
  NA_["R3"] = "no recovery path and no record"
  NA_["R4"] = R4NOTGT ? "no rto or rpo target (unmeasured)" : "no passing restore or failover drill"
  NA_["R5"] = "no record"
  NA_["R6"] = "no failed drill"
  NA_["R7"] = (MANUAL == "") ? "no --manual given" : "no passing restore drill"
  NA_["R8"] = "no failover declared in the IaC"
  NA_["X1"] = "no paging alert given"
  NA_["X2"] = "no --ready-path given"
  NA_["X3"] = "no alert names a runbook"
  NFAIL = 0
  for (j = 1; j <= 11; j++) {
    k = ORDER[j]
    if (!REQ[k]) {
      if (k == "R5" && HIGH[k] != "") { printf "%s", HIGH[k]; NFAIL += NHIGH[k] }
      else printf "N/A   %-7s %s (not required at %s)\n", "OPS-" k, D[k], MAT
      continue
    }
    if (NF_[k] > 0) { printf "%s", OUT[k]; NFAIL += NF_[k] }
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "OPS-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (%s)\n", "OPS-" k, D[k], NA_[k]
  }
  printf "%s", NOTES
  printf "check-drills: %d record(s), %d recovery path(s), %d alert(s), %d failure(s); a record shows a drill was recorded consistently, not that it was honest\n", NR_, NP, NA, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
