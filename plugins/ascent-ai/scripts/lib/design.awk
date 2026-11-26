# design.awk — check-ai-design.sh's checks (AI-V, AI-M, AI-A, AI-P, AI-K,
# AI-F). Loaded after common.awk and record.awk. Input: the application's code files, one
# repository-relative path a line. Variables: app, root, others ("name=root;"
# for each other application), design, tierfile, promptsdir, promptsok,
# goldendir, pilot, selection, finetune, envname, prodenv, threshold, today,
# promptlist and goldenlist (files listing the prompt files and the golden-set
# files). Prints FAIL, PASS and N/A lines and the summary; exits 1 when a
# finding is at or above the threshold.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals, no capture
# groups.

function has_quoted(f, t,   line, found) {   # f holds t as a whole string literal
  found = 0
  while ((getline line < f) > 0)
    if (index(line, "\"" t "\"") || index(line, "'" t "'") || index(line, "`" t "`")) { found = 1; break }
  close(f); return found
}
function realdate(s,   y, m, d, n) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  n = (m == 2) ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  return m >= 1 && m <= 12 && d >= 1 && d <= n
}
function posint(s) { return s ~ /^[0-9]+$/ && s + 0 > 0 }

# findings, printed in rule order at the end
function fail(id, base, fixed, loc, msg,   sev) {
  sev = scale(base, TIER, fixed)
  NF_[id]++; FL[id, NF_[id]] = sprintf("FAIL  %s  %-8s  [%s] %s  %s", id, sev, app, loc, msg)
  NFIND++; if (sev_rank(sev) >= sev_rank(threshold)) OVER = 1
}
function na(id, msg) { if (!(id in NA)) NA[id] = msg }
function pass(id, msg) { PM[id] = msg }



function quoted_name(s,   q) {   # the first quoted identifier in s
  if (!match(s, /["'][A-Za-z_][A-Za-z0-9_-]*["']/)) return ""
  return substr(s, RSTART + 1, RLENGTH - 2)
}
function tool(name, path, ln) { if (name != "" && !(name in TOOL)) { TOOL[name] = path ":" ln; NTOOL++; TOOLS[NTOOL] = name } }
function loop(path, ln, what) { if (!((path, ln) in LOOPSEEN)) { LOOPSEEN[path, ln] = 1; NL++; LOOPAT[NL] = path ":" ln; LOOPWHAT[NL] = what } }
function call_done(   ) {
  # a call whose only argument is a variable ((request), (**payload), (...params)) takes its
  # limit from that variable, which is built just before it: a limit in the 40 lines above counts
  if (calltext !~ LIMRE && !(calltext ~ /\([ \t]*(\*\*|\.\.\.)?[A-Za-z_$][A-Za-z0-9_$]*[ \t]*\)[ \t]*$/ && LIMLN > 0 && callline - LIMLN <= 40)) { NC++; CALLAT[NC] = callpath ":" callline }
  incall = 0; calltext = ""
}

function scan(path,   line, ln, s, k, c, lastloop, pendfn, pendef, lastname, lastnameln, m, nm, t) {
  ln = 0; lastloop = 0; pendfn = 0; pendef = 0; lastname = ""; lastnameln = -9; incall = 0; calltext = ""; LIMLN = 0
  while ((getline line < path) > 0) {
    ln++; line = strip_cr(line)
    if (line ~ /^[ \t]*(#|\/\/|\/\*|\*)/) continue
    # model names written as string literals (AI-M1)
    s = line
    while (match(s, /"[^"]*"|'[^']*'|`[^`]*`/)) {
      m = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
      if (m ~ /^(gpt-|chatgpt-|o[1-9]-|o[1-9]$|claude-|gemini-|anthropic\.|meta\.llama|mistral-|mistral\.|command-r|llama-?[0-9]|amazon\.nova|amazon\.titan)/) { NM++; MAT[NM] = path ":" ln; MNAME[NM] = m; MPATH[NM] = path }
    }
    # tools (AI-A1, AI-A2)
    if (line ~ /(^|[^A-Za-z0-9_$])["']?type["']?[ \t]*:[ \t]*["']function["']/ || line ~ /(^|[^A-Za-z0-9_$])["']?function["']?[ \t]*:[ \t]*\{/) pendfn = 4   # keys quoted (JSON, Python) or not (TS, JS)
    nm = ""
    if (match(line, /(^|[^A-Za-z0-9_])["']?name["']?[ \t]*[:=][ \t]*["'][A-Za-z_][A-Za-z0-9_-]*["']/)) { t = substr(line, RSTART, RLENGTH); sub(/^[^:=]*[:=]/, "", t); nm = quoted_name(t); lastname = nm; lastnameln = ln }
    if (pendfn > 0) { if (nm != "") { tool(nm, path, ln); pendfn = 0 } else pendfn-- }
    if (line ~ /input_schema|inputSchema/ && lastname != "" && ln - lastnameln <= 5) { tool(lastname, path, lastnameln); lastname = "" }
    if (line ~ /^[ \t]*@([A-Za-z_][A-Za-z0-9_]*\.)?(function_tool|tool)([ \t(]|$)/) {
      t = (line ~ /tool[ \t]*\([ \t]*["']/) ? quoted_name(substr(line, index(line, "("))) : ""
      if (t != "") tool(t, path, ln); else pendef = 3
    } else if (pendef > 0) {
      if (line ~ /^[ \t]*(async[ \t]+)?def[ \t]+[A-Za-z_]/) { t = line; sub(/^[ \t]*(async[ \t]+)?def[ \t]+/, "", t); sub(/[^A-Za-z0-9_].*$/, "", t); tool(t, path, ln); pendef = 0 }
      else pendef--
    }
    if (line ~ /Tool\.from_function[ \t]*\(/ && nm != "") tool(nm, path, ln)
    if (match(line, /(^|[^A-Za-z0-9_.@])tool\([ \t]*["'][A-Za-z_][A-Za-z0-9_-]*["']/)) tool(quoted_name(substr(line, RSTART)), path, ln)
    if (match(line, /["']?[A-Za-z_][A-Za-z0-9_]*["']?[ \t]*:[ \t]*tool\([ \t]*\{/)) { t = substr(line, RSTART, RLENGTH); sub(/[ \t]*:.*$/, "", t); gsub(/["']/, "", t); tool(t, path, ln) }
    # model-driven loops (AI-A1)
    if (line ~ /^[ \t]*(async[ \t]+)?(for|while)([ \t(]|$)/) lastloop = ln
    if (line ~ /finish_reason|stop_reason|finishReason|stopReason/ && line ~ /tool_calls|tool_use|tool-calls/ && lastloop) loop(path, lastloop, "it repeats until the model stops calling tools")
    if (line !~ /^[ \t]*(import|from)[ \t]/ && line !~ /require\(/) {
      if (match(line, /create_react_agent|AgentExecutor|Runner\.run(_sync|_streamed)?[ \t]*\(|ClaudeSDKClient|stopWhen|maxSteps/)) { t = substr(line, RSTART, RLENGTH); sub(/[ \t]*\($/, "", t); loop(path, ln, t) }
      else if (line ~ /(^|[^A-Za-z0-9_.])query\([ \t]*\{?[ \t]*prompt/) loop(path, ln, "query")
    }
    # model calls and their output token limit (AI-A4)
    if (line ~ LIMRE) LIMLN = ln
    s = line
    while (1) {
      if (incall) {
        for (k = 1; k <= length(s); k++) {
          c = substr(s, k, 1)
          if (c == "(") { depth++; opened = 1 } else if (c == ")") depth--
          if (opened && depth == 0) break
        }
        if (k <= length(s)) { calltext = calltext substr(s, 1, k); s = substr(s, k + 1); call_done(); continue }
        calltext = calltext " " s
        if (++calllines > 60) call_done()
        break
      }
      if (!match(s, /(\.chat\.completions\.create|\.responses\.create|\.completions\.create|\.messages\.create|\.messages\.stream|generateText|streamText|generateObject|streamObject|\.generate_content|\.generateContent|generateContentStream|\.converse|\.converse_stream|ConverseCommand|ConverseStreamCommand)[ \t]*\(/)) break
      incall = 1; callpath = path; callline = ln; calltext = ""; depth = 0; opened = 0; calllines = 0; s = substr(s, RSTART)
    }
  }
  close(path)
  if (incall) call_done()
}

BEGIN {
  LIMRE = "max_tokens|max_completion_tokens|max_output_tokens|max_new_tokens|maxTokens|maxOutputTokens|maxCompletionTokens"   # an output token limit (AI-A4)
  TIER = tier_of(tierfile); NFIND = 0; OVER = 0
  roots_init()
  HAVE = exists(design)
  if (HAVE) read_design(design)
  NM = 0; NTOOL = 0; NL = 0; NC = 0
}
{ p = norm($0); if (p != "" && mine(p)) scan(p) }
END {
  dl = design ((HAVE && ("application" in ALINE)) ? ":" ALINE["application"] : "")
  auton = tolower(v("application", "autonomy"))

  # AI-V1 the value it must show
  if (!HAVE) na("AI-V1", "no AI design record")
  else {
    miss = ""
    if (v("application", "baseline metric") == "") miss = miss ", baseline metric"
    if (v("application", "baseline value") == "") miss = miss ", baseline value"
    if (!realdate(v("application", "measured on"))) miss = miss ", measured on (a real date)"
    if (v("application", "target value") == "") miss = miss ", target value"
    if (miss != "") fail("AI-V1", "High", 0, dl, "the value it must show is not declared: no " substr(miss, 3) "; the baseline is how the work is measured today, before the AI")
    else pass("AI-V1", "baseline " v("application", "baseline metric") " " v("application", "baseline value") " on " v("application", "measured on") ", target " v("application", "target value"))
  }
  # AI-V2 the pilot, before a production launch
  if (envname == "" || envname != prodenv) na("AI-V2", (envname == "" ? "no environment given" : envname " is not " prodenv))
  else if (pilot == "") fail("AI-V2", "Medium", 0, design, "no pilot result given (the contract's pilot_result): a " prodenv " launch needs the pilot measured against the baseline")
  else if (!exists(pilot)) fail("AI-V2", "Medium", 0, pilot, "the pilot result " pilot " does not exist")
  else {
    bm = tolower(v("application", "baseline metric")); found = 0
    if (bm != "") { while ((getline line < pilot) > 0) if (index(tolower(line), bm)) { found = 1; break }; close(pilot) }
    if (!found) fail("AI-V2", "Medium", 0, pilot, "the pilot result does not name the baseline metric (" bm "): measure the pilot the way the baseline was measured")
    else pass("AI-V2", "the pilot result " pilot " names the baseline metric")
  }

  # AI-M1 models named in one place; AI-M2 a fallback; AI-M3 why this model
  if (!HAVE) { na("AI-M1", "no AI design record"); na("AI-M2", "no AI design record") }
  else {
    nd = split(v("model", "defined in"), DI, ","); delete DEF
    for (i = 1; i <= nd; i++) { d = norm(DI[i]); if (d != "") DEF[d] = 1 }
    dl_ = v("model", "defined in"); if (dl_ == "") dl_ = "no file"
    for (i = 1; i <= NM; i++) if (!(MPATH[i] in DEF)) fail("AI-M1", "Medium", 0, MAT[i], "names the model " MNAME[i] "; models are named only in " dl_ " (the design record's defined in), so a change of model is one edit")
    if (!NF_["AI-M1"]) pass("AI-M1", "models are named only in " dl_)
    fb = v("model", "fallback")
    if (fb == "") fail("AI-M2", "Medium", 0, design ((("model") in ALINE) ? ":" ALINE["model"] : ""), "no fallback model is declared: when " (v("model", "primary") == "" ? "the model" : v("model", "primary")) " is down or retired, the application has nowhere to go")
    else {
      found = 0
      for (d in DEF) if (has_quoted(d, fb)) found = 1
      if (!found) fail("AI-M2", "Medium", 0, design, "the fallback " fb " is not named in " dl_ ": declared, and not wired")
      else pass("AI-M2", "the fallback " fb " is named in " dl_)
    }
  }
  if (TIER < 3) na("AI-M3", "tier " TIER ": a model selection record is asked for at tier 3")
  else if (selection == "") fail("AI-M3", "Medium", 0, design, "no model selection record given (the contract's model_selection): at tier 3, record why this model, against which others, on the golden set")
  else if (!exists(selection)) fail("AI-M3", "Medium", 0, selection, "the model selection record " selection " does not exist")
  else pass("AI-M3", "the model selection record " selection " exists")

  # AI-A1 autonomy against the code
  if (!HAVE) fail("AI-A1", "High", 0, design, "no AI design record (" design "): ai-design drafts one, with the autonomy, the model, the tools, the limits and the off switch")
  else if (auton != "prompt" && auton != "workflow" && auton != "agent") fail("AI-A1", "High", 0, dl, "the autonomy is '" v("application", "autonomy") "'; it is prompt, workflow or agent, the least that does the job")
  else {
    if (auton == "prompt") {
      for (i = 1; i <= NTOOL; i++) fail("AI-A1", "High", 0, TOOL[TOOLS[i]], TOOLS[i] " is a tool, and the autonomy is prompt: a prompt calls no tools; declare workflow or agent")
      for (i = 1; i <= NT; i++) if (!(TN[i] in TOOL)) fail("AI-A1", "High", 0, design ":" TLN[i], "the design record declares the tool " TN[i] ", and the autonomy is prompt")
    }
    if (auton != "agent") for (i = 1; i <= NL; i++) fail("AI-A1", "High", 0, LOOPAT[i], "a model-driven loop (" LOOPWHAT[i] "), and the autonomy is " auton ": the model picks its next step, which is an agent; declare agent, or fix the steps in code")
    if (!NF_["AI-A1"]) pass("AI-A1", "the autonomy is " auton ", and the code matches it")
  }
  # AI-A2 tools declared and defined
  if (!HAVE) na("AI-A2", "no AI design record")
  else {
    delete DECL
    for (i = 1; i <= NT; i++) { DECL[TN[i]] = 1; if (!(TN[i] in TOOL)) fail("AI-A2", "High", 0, design ":" TLN[i], TN[i] " is declared in the design record, and no tool of that name is defined in the code") }
    for (i = 1; i <= NTOOL; i++) if (!(TOOLS[i] in DECL)) fail("AI-A2", "High", 0, TOOL[TOOLS[i]], TOOLS[i] " is a tool in the code, and the design record does not declare it: every tool the model can call is declared, with whether it can be undone")
    if (!NF_["AI-A2"]) pass("AI-A2", NT " tool(s), declared and defined")
  }
  # AI-A3 irreversible tools: a person approves, the code enforces the limit (fixed)
  # AI-A5 no irreversible tool below tier 3 (fixed)
  if (!HAVE) { na("AI-A3", "no AI design record"); na("AI-A5", "no AI design record") }
  else {
    pm = ""; irr = 0
    for (i = 1; i <= NT; i++) {
      if (TREV[i] == "yes") continue
      irr++; at = design ":" TLN[i]
      if (TAPP[i] != "yes") fail("AI-A3", "Critical", 1, at, TN[i] " cannot be undone and needs no person's approval: set approval required to yes, and make the code ask")
      if (TLIM[i] == "") fail("AI-A3", "Critical", 1, at, TN[i] " cannot be undone and names no limit enforced in file: the code, not the prompt, caps what it can do")
      else if (!exists(TLIM[i])) fail("AI-A3", "Critical", 1, at, TN[i] "'s limit is enforced in " TLIM[i] ", which does not exist")
      else if (!has_text(TLIM[i], TN[i])) fail("AI-A3", "Critical", 1, at, TN[i] "'s limit is enforced in " TLIM[i] ", which does not name " TN[i])
      else pm = pm "; " TN[i] " needs approval and its limit is enforced in " TLIM[i]
      if (TIER < 3) fail("AI-A5", "High", 1, at, TN[i] " is irreversible and the tier record says tier " TIER ": an application with an irreversible tool is tier 3 (ascent-governance GOV-A5); raise the tier or make the tool reversible")
    }
    if (!NF_["AI-A3"]) pass("AI-A3", irr ? substr(pm, 3) : "no irreversible tool")
    if (!NF_["AI-A5"]) pass("AI-A5", irr ? "tier 3, with " irr " irreversible tool(s)" : "no irreversible tool")
  }
  # AI-A4 limits, and an output token limit on every model call
  if (HAVE && (auton == "workflow" || auton == "agent")) {
    al = design (("limits" in ALINE) ? ":" ALINE["limits"] : "")
    if (!posint(v("limits", "max steps"))) fail("AI-A4", "High", 0, al, "a " auton " declares its most steps (max steps, a number): without it a task can run on")
    if (!posint(v("limits", "max tokens"))) fail("AI-A4", "High", 0, al, "a " auton " declares its most tokens a task may use (max tokens, a number)")
    if (!posint(v("limits", "max seconds"))) fail("AI-A4", "High", 0, al, "a " auton " declares its most seconds a task may take (max seconds, a number)")
  }
  for (i = 1; i <= NC; i++) fail("AI-A4", "High", 0, CALLAT[i], "a model call with no output token limit (max_tokens, maxOutputTokens or the SDK's own): the most one answer can cost is unbounded")
  if (!NF_["AI-A4"]) pass("AI-A4", NC == 0 && (auton != "workflow" && auton != "agent") ? "every model call sets an output token limit" : "limits declared, and every model call sets an output token limit")

  # AI-P1 every prompt file has a golden case
  if (promptsdir == "") na("AI-P1", "no prompts folder given")
  else if (!promptsok) fail("AI-P1", "Medium", 0, promptsdir, "the prompts folder " promptsdir " does not exist: prompts live in files, one a prompt, so a change to one shows in review")
  else {
    while ((getline g < goldenlist) > 0) {
      while ((getline line < g) > 0) {
        s = line
        while (match(s, /(^|[^A-Za-z0-9_])["']?prompt["']?[ \t]*:[ \t]*["']?[A-Za-z0-9_.\/-]+/)) {
          t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
          sub(/^.*prompt["']?[ \t]*:[ \t]*["']?/, "", t); NAMED[t] = 1
        }
      }
      close(g)
    }
    close(goldenlist); np = 0
    while ((getline f < promptlist) > 0) {
      np++; b = f; sub(/^.*\//, "", b); st = b; sub(/\.[^.]*$/, "", st)
      if (!((b in NAMED) || (st in NAMED) || (f in NAMED))) fail("AI-P1", "Medium", 0, f, "no golden test case names this prompt (metadata.prompt: " st "): a change to it is not checked by an eval")
    }
    close(promptlist)
    if (!NF_["AI-P1"]) pass("AI-P1", np " prompt file(s), each named by a golden test case")
  }
  # AI-K1 the off switch
  if (!HAVE) na("AI-K1", "no AI design record")
  else {
    fl = v("off-switch", "flag"); ri = norm(v("off-switch", "read in"))
    kl = design (("off-switch" in ALINE) ? ":" ALINE["off-switch"] : "")
    if (fl == "" || ri == "") fail("AI-K1", "High", 0, kl, "no off switch declared (a flag and the file that reads it): the AI cannot be turned off without a deploy")
    else if (!exists(ri)) fail("AI-K1", "High", 0, kl, "the off switch is read in " ri ", which does not exist")
    else if (!has_text(ri, fl)) fail("AI-K1", "High", 0, ri, fl " is not read in " ri ": the off switch is declared, and not wired")
    else pass("AI-K1", fl " is read in " ri)
  }
  # AI-F1 fine-tuning
  if (finetune == "") na("AI-F1", "no fine-tune runbook")
  else if (!exists(finetune)) fail("AI-F1", "High", 0, finetune, "the fine-tune runbook " finetune " does not exist")
  else {
    cap = 0; pii = 0; ev = 0
    while ((getline line < finetune) > 0) {
      l = tolower(line)
      if (l ~ /spend cap|spending cap|cost cap|budget|spend limit/) cap = 1
      if (l ~ /personal data|pii|personally identifiable/) pii = 1
      if (l ~ /golden/ && l ~ /eval/) ev = 1
    }
    close(finetune)
    if (!cap) fail("AI-F1", "High", 0, finetune, "has no spend cap: a training job is billed by the token")
    if (!pii) fail("AI-F1", "High", 0, finetune, "has no personal-data check of the dataset: what goes into the weights cannot be taken out")
    if (!ev) fail("AI-F1", "High", 0, finetune, "has no eval against the golden set after training: a tuned model is held to the same bar")
    if (!NF_["AI-F1"]) pass("AI-F1", finetune " has a spend cap, a personal-data check and a golden-set eval")
  }

  nr = split("AI-V1 AI-V2 AI-M1 AI-M2 AI-M3 AI-A1 AI-A2 AI-A3 AI-A4 AI-A5 AI-P1 AI-K1 AI-F1", R, " ")
  for (i = 1; i <= nr; i++) {
    id = R[i]
    if (NF_[id]) { for (j = 1; j <= NF_[id]; j++) print FL[id, j] }
    else if (id in NA) printf "N/A   %s  [%s] %s\n", id, app, NA[id]
    else if (id in PM) printf "PASS  %s  [%s] %s\n", id, app, PM[id]
  }
  printf "check-ai-design: [%s] %d finding(s), tier %d\n", app, NFIND, TIER
  exit OVER
}
