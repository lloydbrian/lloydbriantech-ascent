# render.awk — one result set (items.tsv) as text or as Markdown.
#
# Input rows: kind<TAB>id<TAB>status<TAB>severity<TAB>source<TAB>text
#   kind:     check | review | waiver | ack | launch | setup
#   status:   pass | fail | due | unmeasured | na | note
#   severity: High | Medium | Low | -
# A waiver or ack row with status note is a listing row and has five more
# fields: section, id, what it skips, review_by, days left.
#
# The verdict: NO-GO when a High item failed or is due; GO WITH CONDITIONS when a
# Medium or Low item failed or something is unmeasured; GO otherwise.
#
# -v fmt=text prints the lines the other ASCENT checkers print, then the verdict
#   line (-v env).
# -v fmt=md prints the launch record: a header (-v project, env, date, commit,
#   maturity, msrc, version), the verdict, the evidence table, the waivers in
#   force and the conditions as a numbered list. With -v sign=1 it is a launch
#   record: it also has the place for the plain-words summary and the lines a
#   person signs. With sign=0 it is the same result for a job summary or a page.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function verdict() { return high > 0 ? "NO-GO" : (cond + unmeasured > 0 ? "GO WITH CONDITIONS" : "GO") }
# text for a Markdown table cell or list item: nothing in it starts a cell, a
# tag, a link, bold or code, and a backslash of its own cannot undo an escape
# (built by hand: what a backslash means in gsub's replacement differs between awks)
function esc(s,   out, c, i, n) {
  out = ""; n = length(s)
  for (i = 1; i <= n; i++) { c = substr(s, i, 1); out = out ((c == "\\" || c == "|" || c == "<" || c == "[" || c == "*" || c == "`") ? "\\" c : c) }
  return out
}
function result(st, sev) {
  if (st == "fail") return "FAIL (" sev ")"
  if (st == "due") return "due (" sev ")"
  if (st == "na") return "n/a"
  return st
}

{
  n++; KIND[n] = $1; ID[n] = $2; ST[n] = $3; SEV[n] = $4; SRC[n] = $5; TEXT[n] = $6
  SEC[n] = $7; WID[n] = $8; SKIPS[n] = $9; RB[n] = $10; LEFT[n] = $11
  if ($3 == "pass" || $3 == "fail" || $3 == "due" || $3 == "unmeasured") if ($1 != "setup") evidence++
  if ($3 == "unmeasured") unmeasured++
  else if ($3 == "fail" || $3 == "due") { if ($4 == "High") high++; else cond++ }
}

END {
  if (fmt == "text") {
    for (i = 1; i <= n; i++) {
      if (ST[i] == "pass") printf "PASS  %s  %s\n", ID[i], TEXT[i]
      else if (ST[i] == "na") printf "N/A   %s  %s\n", ID[i], TEXT[i]
      else if (ST[i] == "note") printf "NOTE  %s\n", TEXT[i]
      else printf "FAIL  %s  %-6s %s  %s\n", ID[i], SEV[i], SRC[i], TEXT[i]
    }
    printf "check-audit: %s: %s, %d evidence item(s), %d failure(s), %d condition(s), %d unmeasured; it checks that the evidence exists and is current, not that the system is good\n", env, verdict(), evidence, high, cond, unmeasured
  }
  if (fmt == "md") {
    printf "# %s: %s, %s\n\n", (sign ? "Launch record" : "Launch readiness"), esc(project), esc(env)
    printf "%s · commit %s · maturity %s (%s) · ascent-governance %s\n\n", date, commit, maturity, esc(msrc), version
    printf "**Verdict:** %s\n\n", verdict()
    if (sign) printf "## In plain words\n\n<!-- summary: written by launch-readiness -->\n\n"
    printf "## Evidence\n\n| What | Kind | Result | Source |\n|---|---|---|---|\n"
    for (i = 1; i <= n; i++)
      if (KIND[i] == "check" || KIND[i] == "review" || KIND[i] == "launch" || (KIND[i] == "setup" && ST[i] == "fail"))
        printf "| %s | %s | %s | %s |\n", esc(TEXT[i]), KIND[i], result(ST[i], SEV[i]), esc(SRC[i])
    printf "\n## Waivers in force\n\n"; k = 0
    for (i = 1; i <= n; i++) if (KIND[i] == "waiver" && ST[i] == "note") {
      if (!k++) printf "| Waiver | Section | What it skips | Review by | Days left |\n|---|---|---|---|---|\n"
      printf "| %s | %s | %s | %s | %s |\n", esc(WID[i]), esc(SEC[i]), esc(SKIPS[i]), esc(RB[i]), (LEFT[i] ~ /^-[0-9]/ ? "expired" : LEFT[i])
    }
    a = 0
    for (i = 1; i <= n; i++) if (KIND[i] == "ack") {
      if (!a++) printf "%sAcknowledged changes (not waivers; they never expire):\n\n", (k ? "\n" : "")
      printf "- %s: %s\n", esc(WID[i]), esc(SKIPS[i])
    }
    if (!k && !a) printf "None.\n"
    printf "\n## Conditions\n\n"; c = 0
    for (pass = 1; pass <= 3; pass++) for (i = 1; i <= n; i++) {
      if (ST[i] != "fail" && ST[i] != "due" && ST[i] != "unmeasured") continue
      rank = (SEV[i] == "High") ? 1 : (SEV[i] == "Medium" ? 2 : 3)
      if (rank != pass) continue
      printf "%d. **%s** %s: %s (%s)\n", ++c, SEV[i], ID[i], esc(TEXT[i]), esc(SRC[i])
    }
    if (!c) printf "None.\n"
    if (sign) {
      printf "\n## Sign-off\n\nOnly a person signs: add your name and the date. Claude never fills these in.\n\n"
      printf "**Signed:**\n\n**Date:**\n"
    }
  }
}
