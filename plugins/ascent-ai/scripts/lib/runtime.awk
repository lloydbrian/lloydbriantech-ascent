# runtime.awk — check-ai-runtime.sh's checks (AI-O, AI-C). Loaded after
# common.awk and record.awk. Input: the application's code files, one
# repository-relative path a line. Variables: app, root, others, design,
# tierfile, capture, gwpolicy, threshold, manifests (a file listing the
# dependency manifests under the root), upmanifests (the ones directly in each
# folder above the root, read without the root check). Prints FAIL, PASS and N/A lines and
# the summary; exits 1 when a finding is at or above the threshold.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function fail(id, base, fixed, loc, msg,   sev) {
  sev = scale(base, TIER, fixed)
  NF_[id]++; FL[id, NF_[id]] = sprintf("FAIL  %s  %-8s  [%s] %s  %s", id, sev, app, loc, msg)
  NFIND++; if (sev_rank(sev) >= sev_rank(threshold)) OVER = 1
}
function na(id, msg) { if (!(id in NA)) NA[id] = msg }
function pass(id, msg) { PM[id] = msg }

# model clients: CL[n] = file:line, CLGW[n] = 1 when the call names a base URL
function client_done() {
  if (ctext ~ /^boto3/ && ctext !~ /bedrock-runtime/) { incl = 0; ctext = ""; return }   # another AWS client
  NCL++; CLAT[NCL] = cpath ":" cline; CLGW[NCL] = (ctext ~ /base_url|baseURL|baseUrl|api_base|openai_api_base|anthropic_api_url|endpoint_url|http_options/)
  incl = 0; ctext = ""
}
function scan(path,   line, ln, s, k, c) {
  ln = 0; incl = 0; ctext = ""
  while ((getline line < path) > 0) {
    ln++; line = strip_cr(line)
    if (line ~ /^[ \t]*(#|\/\/|\/\*|\*)/) continue
    s = line
    while (1) {
      if (incl) {
        for (k = 1; k <= length(s); k++) {
          c = substr(s, k, 1)
          if (c == "(") { depth++; opened = 1 } else if (c == ")") depth--
          if (opened && depth == 0) break
        }
        if (k <= length(s)) { ctext = ctext substr(s, 1, k); s = substr(s, k + 1); client_done(); continue }
        ctext = ctext " " s
        if (++clines > 20) client_done()
        break
      }
      if (!match(s, /(OpenAI|AsyncOpenAI|AzureOpenAI|AsyncAzureOpenAI|Anthropic|AsyncAnthropic|AnthropicBedrock|AnthropicVertex|ChatOpenAI|ChatAnthropic|BedrockRuntimeClient|genai\.Client|boto3\.client)[ \t]*\(/)) break
      if (RSTART > 1 && substr(s, RSTART - 1, 1) ~ /[A-Za-z0-9_]/) { s = substr(s, RSTART + RLENGTH); continue }   # MyOpenAI( is not a client
      incl = 1; cpath = path; cline = ln; ctext = ""; depth = 0; opened = 0; clines = 0; s = substr(s, RSTART)
    }
  }
  close(path)
  if (incl) client_done()
}

BEGIN {
  TIER = tier_of(tierfile); NFIND = 0; OVER = 0; NCL = 0
  roots_init()
  HAVE = exists(design)
  if (HAVE) read_design(design)
}
{ p = norm($0); if (p != "" && mine(p)) scan(p) }
END {
  # AI-O1 tracing in the dependencies
  tr = ""
  while ((getline m < manifests) > 0 || (getline m < upmanifests) > 0 && (UP = 1)) {
    if (!UP && !mine(m)) continue
    while ((getline line < m) > 0) {
      l = tolower(line); gsub(/_/, "-", l)
      if (match(l, /opentelemetry-instrumentation-(openai|anthropic|bedrock|vertexai|google-genai|langchain|llamaindex|mistralai|groq|ollama)|openinference-|langfuse|arize-phoenix|traceloop-sdk|openllmetry|@arizeai\/|@traceloop\/|@opentelemetry\/instrumentation-(openai|anthropic|bedrock)/)) {
        t = substr(l, RSTART); sub(/[^a-z0-9@\/.-].*$/, "", t)
        if (tr == "") tr = t " (" m ")"
      }
    }
    close(m)
  }
  close(manifests)
  if (tr == "") fail("AI-O1", "High", 0, root, "no tracing for model calls in the dependencies (OpenTelemetry GenAI instrumentation, OpenInference, Langfuse, Phoenix, Traceloop): what a model was asked and answered cannot be followed")
  else pass("AI-O1", "tracing: " tr)

  # AI-O2 the capture policy
  if (capture == "") fail("AI-O2", "High", 0, design, "no capture policy given (the contract's capture_policy): say what prompt and output content the traces store, redact and drop")
  else if (!exists(capture)) fail("AI-O2", "High", 0, capture, capture " does not exist")
  else {
    st = 0; rd = 0; dr = 0
    while ((getline line < capture) > 0) {
      l = tolower(line)   # a CR at the end changes nothing: each label is followed by : or |
      if (l ~ /^[ \t]*([-*|][ \t]*)?(\*\*)?stored(\*\*)?[ \t]*[:|]/) st = 1
      if (l ~ /^[ \t]*([-*|][ \t]*)?(\*\*)?redacted(\*\*)?[ \t]*[:|]/) rd = 1
      if (l ~ /^[ \t]*([-*|][ \t]*)?(\*\*)?dropped(\*\*)?[ \t]*[:|]/) dr = 1
    }
    close(capture)
    if (!st) fail("AI-O2", "High", 0, capture, "does not say what is stored (a Stored: line)")
    if (!rd) fail("AI-O2", "High", 0, capture, "does not say what is redacted (a Redacted: line)")
    if (!dr) fail("AI-O2", "High", 0, capture, "does not say what is dropped (a Dropped: line)")
    if (!NF_["AI-O2"]) pass("AI-O2", capture " says what is stored, redacted and dropped")
  }

  # AI-C1 the gateway; AI-C2 its policy
  gw = tolower(v("model", "gateway"))
  if (!HAVE) { fail("AI-C1", "Medium", 0, design, "no AI design record (" design "): the gateway and the cost-per-task alert are declared there"); na("AI-C2", "no AI design record"); na("AI-C3", "no AI design record") }
  else if (gw == "") { fail("AI-C1", "Medium", 0, design, "no gateway declared (litellm, portkey or none)"); na("AI-C2", "no gateway declared") }
  else if (gw != "litellm" && gw != "portkey" && gw != "none") { fail("AI-C1", "Medium", 0, design, "the gateway is '" v("model", "gateway") "'; it is litellm, portkey or none"); na("AI-C2", "no known gateway") }
  else if (gw == "none") {
    if (TIER >= 3) fail("AI-C1", "Medium", 0, design, "the design record says gateway: none, and the tier is 3: model calls go through a gateway, with a budget, rate limits and one place to change the model")
    else pass("AI-C1", "gateway none, at tier " TIER)
    na("AI-C2", "gateway none")
  } else {
    for (i = 1; i <= NCL; i++) if (!CLGW[i]) fail("AI-C1", "Medium", 0, CLAT[i], "a model client that does not go through the " gw " gateway (no base URL): its calls skip the budget and the rate limits")
    if (!NF_["AI-C1"]) pass("AI-C1", "model clients go through the " gw " gateway")
    if (gwpolicy == "") fail("AI-C2", "High", 0, design, "no gateway policy given (the contract's gateway_policy): the " gw " configuration that holds the budget and the limits")
    else if (!exists(gwpolicy)) fail("AI-C2", "High", 0, gwpolicy, gwpolicy " does not exist")
    else {
      mo = 0; bu = 0; al = 0; ra = 0
      while ((getline line < gwpolicy) > 0) {
        l = tolower(line)
        if (l ~ /(^|[^a-z_])["']?(model_list|allowed_models|models)["']?[ \t]*:/) mo = 1
        if (l ~ /(^|[^a-z_])["']?(max_budget|soft_budget|budget_limit|monthly_budget|budget)["']?[ \t]*:/) bu = 1
        if (l ~ /alert/) al = 1
        if (l ~ /(^|[^a-z_])["']?(rpm|tpm|rpm_limit|tpm_limit|rate_limit|rate_limits|requests_per_minute|tokens_per_minute)["']?[ \t]*:/) ra = 1
      }
      close(gwpolicy)
      if (!mo) fail("AI-C2", "High", 0, gwpolicy, "names no allowed models (model_list): any model can be called")
      if (!bu) fail("AI-C2", "High", 0, gwpolicy, "names no budget (max_budget): spend has no ceiling")
      if (!al) fail("AI-C2", "High", 0, gwpolicy, "names no alert threshold: nobody hears of spend before the ceiling")
      if (!ra) fail("AI-C2", "High", 0, gwpolicy, "names no rate limits (rpm, tpm): one loop can use the whole budget")
      if (!NF_["AI-C2"]) pass("AI-C2", gwpolicy " names the allowed models, a budget, an alert threshold and rate limits")
    }
  }
  # AI-C3 the cost-per-task alert
  if (HAVE) {
    if (v("model", "cost per task alert") == "") fail("AI-C3", "Medium", 0, design, "no cost-per-task alert declared: a task that costs ten times the usual goes unseen")
    else pass("AI-C3", "cost-per-task alert: " v("model", "cost per task alert"))
  }

  nr = split("AI-O1 AI-O2 AI-C1 AI-C2 AI-C3", R, " ")
  for (i = 1; i <= nr; i++) {
    id = R[i]
    if (NF_[id]) { for (j = 1; j <= NF_[id]; j++) print FL[id, j] }
    else if (id in NA) printf "N/A   %s  [%s] %s\n", id, app, NA[id]
    else if (id in PM) printf "PASS  %s  [%s] %s\n", id, app, PM[id]
  }
  printf "check-ai-runtime: [%s] %d finding(s), tier %d\n", app, NFIND, TIER
  exit OVER
}
