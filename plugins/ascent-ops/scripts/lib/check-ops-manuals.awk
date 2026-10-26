# check-ops-manuals.awk — the checks of check-ops-manuals.sh, which passes the file list and
# the ENVIRON values. A separate file keeps bash 3.2 from parsing the program
# (a quoted heredoc inside $(...) breaks there). Run with LC_ALL=C.
BEGIN {
  TODAY = ENVIRON["COM_TODAY"]; MAXAGE = ENVIRON["COM_MAXAGE"] + 0; GIT["mo"] = ENVIRON["COM_GIT_MO"]; GIT["ts"] = ENVIRON["COM_GIT_TS"]
  MOP = ENVIRON["COM_MO"]; TSP = ENVIRON["COM_TS"]; NIAC = ENVIRON["COM_NIAC"] + 0
  NREQ["mo"] = split("overview|architecture|dependenc|environment|configuration|deploy|rollback|backup|maintenance|upgrade|access|escalation|change history", REQ_mo, "|")
  NAME_mo = "overview|architecture diagrams|dependency map|environments|configuration and secrets|deploy|rollback|backup and restore|scheduled maintenance|upgrades|access|escalation and contacts|change history"
  split(NAME_mo, RN_mo, "|")
  NREQ["ts"] = split("symptom|diagnos|known issue|escalation", REQ_ts, "|")
  split("symptom table|diagnostic commands|known issues|escalation", RN_ts, "|")
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function norm(s) { s = tolower(s); gsub(/[^a-z0-9]/, "", s); return s }
function fail(k, sev, where, msg) { OUT[k] = OUT[k] sprintf("FAIL  %-4s %-6s %s  %s\n", k, sev, where, msg); NF_[k]++; NFAIL++ }
function secretish(n,   l) {
  l = tolower(n); gsub(/-/, "_", l)
  if (l ~ /(arn|id|name|path|file|url|ttl|length|version|ref|type|store|manager|policy|rotation)$/) return 0
  return l ~ /(password|passwd|passphrase|secret|token|apikey|api_key|private_key|access_key|secret_key|credential)/
}
function days(d,   y, m, dd, a, yy, mm) {   # days since 1970-01-01 (civil calendar)
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  a = (m <= 2) ? 1 : 0; yy = y - a; mm = m + 12 * a - 3
  return 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + int((153 * mm + 2) / 5) + dd - 719469
}
function role(k) { return k == "mo" ? "Maintenance and Operations Manual" : "Troubleshooting Manual" }
FNR == 1 { FN = FILENAME; sub(/^\.\//, "", FN); if (K == "mo" || K == "ts") { PATHOF[K] = FN; SEEN[K] = 1 }; inFM = 0; fmDone = 0; inSrc = 0; inCode = 0; inMer = 0; svcI = -1; inSvc = 0; sec = ""; lvl = -1; head = "" }
{ line = $0; sub(/\r$/, "", line) }
# --- manuals ----------------------------------------------------------------------
K == "mo" || K == "ts" {
  if (FNR == 1 && line == "---") { inFM = 1; next }
  if (inFM) {
    if (line == "---") { inFM = 0; fmDone = 1; HASFM[K] = 1; next }
    sub(/[ \t]+#.*$/, "", line)
    if (line ~ /^as_of:/) { v = trim(substr(line, 7)); gsub(/["']/, "", v); ASOF[K] = v; ASOFL[K] = FNR }
    if (line ~ /^describes:/) { v = trim(substr(line, 11)); gsub(/["']/, "", v); DESC[K] = v }
    if (line ~ /^sources:/) { inSrc = 1; v = trim(substr(line, 9)); if (v ~ /^\[ *[^] ]/) NSRC[K]++; next }
    if (inSrc && line ~ /^ +- +[^ ]/) { NSRC[K]++; next }
    inSrc = 0
    next
  }
  if (line ~ /^```/) {
    if (!inCode) { inCode = 1; inMer = (line ~ /^```+ *mermaid/); if (inMer) { NMER++; MERHEAD = head; MERL = FNR; MERFIRST = 1 } }
    else { inCode = 0; inMer = 0 }
    next
  }
  if (inMer) {
    MERTEXT = MERTEXT " " line
    t = trim(line)
    if (MERFIRST && t != "") {
      MERFIRST = 0
      if (t ~ /^C4Context/ || tolower(MERHEAD) ~ /context/) LEVEL["context"] = 1
      if (t ~ /^C4Container/ || tolower(MERHEAD) ~ /container/) LEVEL["container"] = 1
      if (t ~ /^C4Deployment/ || tolower(MERHEAD) ~ /deployment/) LEVEL["deployment"] = 1
    }
  }
  # M8 — credential-like values, in prose and code alike
  if (line ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/) fail("M8", "High", FN ":" FNR, "private key block in the manual; remove it and rotate the key (→ ascent-security)")
  if (line ~ /AKIA[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]/) fail("M8", "High", FN ":" FNR, "AWS access key id in the manual; remove it and rotate the key (→ ascent-security)")
  tt = line
  while (match(tt, /["']?[A-Za-z_][A-Za-z0-9_.-]*["']? *(=|: ) */)) {
    k = substr(tt, RSTART, RLENGTH); tt = substr(tt, RSTART + RLENGTH)
    sub(/["']? *(=|: ) *$/, "", k); gsub(/["']/, "", k)
    if (!secretish(k) || !match(tt, /^["']?[^ "'<>|`]+/)) continue
    v = substr(tt, RSTART, RLENGTH); sub(/^["']/, "", v); rest = substr(tt, RLENGTH + 1)
    if (v ~ /^(\$|\*\*\*|\.\.\.|xxx|XXX|REDACTED|redacted|none|null|true|false|\(|\{\{|arn:|ssm:|secretsmanager|resolve)/ || length(v) < 6) continue
    if (substr(rest, 1, 1) == " " && substr(rest, 2, 1) ~ /[A-Za-z]/) continue   # prose: "password: stored in ..."
    fail("M8", "High", FN ":" FNR, "credential-like value for " k "; never write secret values in a manual (→ ascent-security)")
  }
  if (inCode) next
  if (line ~ /^#+ /) {
    head = line; sub(/^#+ +/, "", head); h = tolower(head)
    if (line ~ /^##+ /) for (j = 1; j <= NREQ[K]; j++) { r = (K == "mo") ? REQ_mo[j] : REQ_ts[j]; if (index(h, r)) HAVE[K, j] = 1 }
    cur = h; tblRow[K] = 0
    next
  }
  if (line ~ /^ *\|/) {
    if (line ~ /^ *\| *:?-+/) next
    if (K == "mo" && index(cur, "dependenc")) { if (!DEPHDR) { DEPHDR = 1; if (tolower(line) ~ /version/) DEPVER = 1 } else DEPROWS++ ; DEPAT = FNR }
    if (K == "ts" && index(cur, "symptom")) {
      if (!SYMHDR) { SYMHDR = 1; l = tolower(line); SYMCOLS = (l ~ /symptom/) + (l ~ /look/) + (l ~ /cause/) + (l ~ /fix|escalat/) } else SYMROWS++
    }
  }
  next
}
# --- services to draw ---------------------------------------------------------------
K == "compose" {
  if (line ~ /^ *#/ || line ~ /^ *$/) next
  match(line, /^ */); i = RLENGTH
  if (i == 0) { inSvc = (line ~ /^services: *$/); svcI = -1; next }
  if (!inSvc) next
  if (svcI < 0) svcI = i
  if (i == svcI && line ~ /^ *[A-Za-z0-9_.-]+: *$/) { s = trim(line); sub(/:.*/, "", s); addsvc(s, s, FN ":" FNR) }
  next
}
K == "cfn" {
  if (line ~ /^ *#/ || line ~ /^ *$/) next
  match(line, /^ */); i = RLENGTH
  if (i == 0) { sec = line; sub(/:.*/, "", sec); lvl = -1; next }
  if (sec != "Resources") next
  if (lvl < 0) lvl = i
  if (i == lvl) { rn = trim(line); sub(/:.*/, "", rn); rl = FN ":" FNR; next }
  if (line ~ /^ *Type: *["']?AWS::(ECS::Service|ECS::Cluster|Lambda::Function|Serverless::Function|RDS::DBInstance|RDS::DBCluster|DynamoDB::Table|S3::Bucket|CloudFront::Distribution|ElasticLoadBalancingV2::LoadBalancer|SQS::Queue|SNS::Topic|ApiGatewayV2::Api|ApiGateway::RestApi|Serverless::Api|Serverless::HttpApi|EC2::Instance|ElastiCache::CacheCluster|ElastiCache::ReplicationGroup|Cognito::UserPool|ECR::Repository|EFS::FileSystem|StepFunctions::StateMachine|Route53::HostedZone)/) {
    t = line; sub(/^ *Type: *["']?AWS::/, "", t); sub(/::.*/, "", t); addsvc(rn, t, rl)
  }
  next
}
K == "tf" {
  if (match(line, /^resource +"(aws_(ecs_service|ecs_cluster|lambda_function|db_instance|rds_cluster|dynamodb_table|s3_bucket|cloudfront_distribution|lb|alb|sqs_queue|sns_topic|elasticache_cluster|elasticache_replication_group|apigatewayv2_api|api_gateway_rest_api|instance|cognito_user_pool|ecr_repository|efs_file_system|sfn_state_machine|eks_cluster|opensearch_domain|route53_zone)|google_(cloud_run_service|cloud_run_v2_service|sql_database_instance|storage_bucket)|azurerm_(linux_web_app|windows_web_app|container_app|mssql_server|storage_account))" +"[^"]+"/)) {
    s = substr(line, RSTART, RLENGTH); n = split(s, P, "\""); ty = P[2]; nm = P[4]
    kind = ty; sub(/^(aws|google|azurerm)_/, "", kind); sub(/_.*/, "", kind)
    addsvc(nm, kind, FN ":" FNR)
  }
  next
}
function addsvc(name, kind, where,   key) {
  key = tolower(name)
  if (key ~ /^(this|main|default|primary|self|root|it|app|site|web)$/) key = kind
  NSVC++; SVC[NSVC] = name; SVCK[NSVC] = norm(key); SVCAT[NSVC] = where
}
END {
  split("mo ts", MANS, " ")
  for (q = 1; q <= 2; q++) {
    m = MANS[q]; p = (m == "mo") ? MOP : TSP
    if (!(m in SEEN)) { fail("M1", "Medium", "absent", role(m) " not found at " p); continue }
    CHK["M1"]++; CHK["M8"]++
    if (!HASFM[m]) fail("M1", "Medium", PATHOF[m] ":1", "no front matter (--- as_of, describes, sources ---)")
    else {
      miss = ""
      if (ASOF[m] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) miss = miss " as_of"
      if (DESC[m] == "") miss = miss " describes"
      if (NSRC[m] + 0 == 0) miss = miss " sources"
      if (miss != "") fail("M1", "Medium", PATHOF[m] ":1", "front matter is missing" miss)
    }
    # M2 — sections
    CHK["M2"]++; miss = ""
    for (j = 1; j <= NREQ[m]; j++) if (!((m, j) in HAVE)) miss = miss (miss == "" ? "" : ", ") (m == "mo" ? RN_mo[j] : RN_ts[j])
    if (miss != "") fail("M2", "Medium", PATHOF[m] ":1", role(m) " is missing sections: " miss)
    # M6 — current
    CHK["M6"]++
    if (ASOF[m] ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
      age = days(TODAY) - days(ASOF[m])
      if (age > MAXAGE) fail("M6", "Medium", PATHOF[m] ":" ASOFL[m], "out of date: as_of " ASOF[m] " is " age " days old (limit " MAXAGE ")")
    }
    g = GIT[m]; ng = split(g, G, "\t")
    if (G[1] == "NOTE") { NOTES = NOTES sprintf("NOTE  M6   -      %s:1  %s\n", PATHOF[m], G[2]); if (ng >= 3 && G[3] != "") fail("M6", "Medium", PATHOF[m] ":1", "sources no longer exist:" G[3]) }
    else if (g != "") {
      if (G[1] + 0 > 0) fail("M6", "Medium", PATHOF[m] ":1", "out of date: " G[1] " commit(s) changed its sources since " DESC[m] (G[2] != "" ? " (" trim(G[2]) ")" : ""))
      if (G[3] != "") fail("M6", "Medium", PATHOF[m] ":1", "sources no longer exist:" G[3])
    }
  }
  # M3, M4, M5 — MO manual
  if ("mo" in SEEN) {
    CHK["M3"]++; miss = ""
    if (!("context" in LEVEL)) miss = miss " system context"
    if (!("container" in LEVEL)) miss = miss " containers"
    if (!("deployment" in LEVEL)) miss = miss " deployment"
    if (miss != "") fail("M3", "Medium", PATHOF["mo"] ":1", "missing Mermaid diagram level(s):" miss " (" NMER + 0 " Mermaid block(s) found)")
    if (NSVC > 0) {
      CHK["M4"] = NSVC; nt = norm(MERTEXT); miss = ""; nm = 0
      for (j = 1; j <= NSVC; j++) if (SVCK[j] == "" || index(nt, SVCK[j]) == 0) { nm++; if (nm <= 10) miss = miss (miss == "" ? "" : ", ") SVC[j] " (" SVCAT[j] ")" }
      if (nm > 0) fail("M4", "Medium", PATHOF["mo"] ":1", nm " of " NSVC " service(s) are in no diagram: " miss (nm > 10 ? ", ..." : ""))
    }
    CHK["M5"]++
    if (!DEPHDR || !DEPVER || DEPROWS == 0) fail("M5", "Low", PATHOF["mo"] ":" (DEPAT ? DEPAT : 1), "the dependency map needs a table with a version column and at least one row")
  }
  if ("ts" in SEEN) {
    CHK["M7"]++
    if (!SYMHDR || SYMCOLS < 4 || SYMROWS == 0) fail("M7", "Medium", PATHOF["ts"] ":1", "no symptom table with symptom, where to look, likely cause and fix or escalation columns and at least one row")
  }
  split("M1 M2 M3 M4 M5 M6 M7 M8", ORDER, " ")
  D["M1"] = "manuals exist with front matter (as_of, describes, sources)"
  D["M2"] = "manuals have their required sections"
  D["M3"] = "diagrams cover system context, containers and deployment"
  D["M4"] = "every IaC and Compose service is in a diagram"
  D["M5"] = "the dependency map lists versions"
  D["M6"] = "manuals are current"
  D["M7"] = "the troubleshooting manual has a symptom table"
  D["M8"] = "no credential-like values in the manuals"
  for (j = 1; j <= 8; j++) {
    k = ORDER[j]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (k == "M4" && NSVC == 0 && ("mo" in SEEN)) printf "N/A   %-4s %s (no IaC or Compose services found%s; check the diagrams against the system by reading)\n", k, D[k], (NIAC > 0 ? " in " NIAC " file(s)" : "")
    else if (CHK[k] > 0) printf "PASS  %-4s %s (%d checked)\n", k, D[k], CHK[k]
    else printf "N/A   %-4s %s (nothing to check)\n", k, D[k]
  }
  printf "%s", NOTES
  printf "check-ops-manuals: 2 manual(s) expected, %d found, %d service(s) to draw, %d failure(s)\n", ("mo" in SEEN) + ("ts" in SEEN), NSVC, NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
