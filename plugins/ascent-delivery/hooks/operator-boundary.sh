#!/usr/bin/env bash
# ascent-delivery — operator boundary (PreToolUse hook on the Bash tool). ADR-010.
#
# Claude never runs git write operations or deploys. The operator does, from the
# hand-off runbook (delivery-loop Step 6). This hook enforces that mechanically in
# every session where the plugin is enabled, whatever the instructions say.
#
# Input:  the PreToolUse JSON on stdin ({"tool_name":"Bash","cwd":…,
#         "tool_input":{"command":…}}).
# Output: exit 0 = allow; exit 2 = block, with the reason on stderr (Claude Code
#         shows it to Claude); exit 1 = hook error, non-blocking, reported on stderr.
#
# What is analysed: every simple command in the line — split on ; && || | & and
# newlines, inside ( ) subshells, $( ) and `` substitutions (heredoc-aware),
# $(( )), <( ), unquoted heredoc bodies, `bash|sh -c "…"`, shells fed by a
# heredoc, here-string or pipe, `eval`, `env -S`, `find -exec`, `su -c`,
# `script -c`, `trap '…'`, `parallel` — after stripping prefixes and wrappers
# (VAR=x, env, sudo, command, exec, time, nohup, nice, ionice, stdbuf, setsid,
# flock, timeout, watch, xargs, coproc, npx/npm x/pnpm dlx/yarn dlx/bunx/uvx,
# python -m) and redirects. Quoted text and quoted heredoc bodies are data:
# `git commit -m "push later"` is a commit, and `cat > f <<'EOF' … EOF` writes
# a file. Commands over 512 KB are blocked without parsing.
#
# Policy:
#   git — allow-list. Read-only subcommands are allowed (status, diff, log, show,
#     ls-files, rev-parse, blame, grep, describe, …); branch/tag listing, remote -v,
#     config reads, stash list/show, worktree list, `fetch` without a local refspec,
#     and `apply --check` are allowed. Everything else — including unknown
#     subcommands and aliases — is blocked. Global options (-C dir, -c k=v,
#     --git-dir, --no-pager) are skipped before the subcommand is read.
#   gh — allow-list: pr view/list/checks/diff/status, issue/run/workflow/release/
#     repo view and list, search, status, auth status, and `gh api` only when the
#     effective method is GET (fields imply POST) or a GraphQL query, not mutation.
#   deploys — every command listed under deploy_beta / deploy_prod in the
#     project's .delivery-loop.yml (found from the hook's cwd upward, then
#     $CLAUDE_PROJECT_DIR): the last command of each entry, matched by command
#     name plus its positional words in any order, with any flags; plus well-known deploy and
#     publish verbs (terraform/tofu apply|destroy|import|taint, kubectl/oc writes
#     and rollout, helm install|upgrade|uninstall|rollback, aws cloudformation
#     deploy|*-stack, aws s3 cp|sync|mv to s3:// and rm|mb|rb, npm|pnpm|yarn|bun
#     publish, docker|podman push, cdk deploy|destroy, sam deploy|sync|delete,
#     serverless deploy, vercel --prod, netlify deploy --prod, firebase|fly|
#     wrangler [pages] deploy, gcloud … deploy, gcloud storage/gsutil to gs://,
#     az … deploy, pulumi up, terragrunt apply, helmfile apply|sync, cargo/uv/
#     poetry publish, twine upload, gem push, mvn deploy, gradle publish,
#     changeset publish, semantic-release). Dry runs are blocked too, by design.
#
# Known limits (documented in the plugin README): commands hidden inside scripts,
# make targets or npm scripts are only caught when the contract lists them; a
# command word built at run time ($GIT push, aliases, functions) is not resolved;
# other interpreters (python -c, node -e) are not inspected. This is a guard rail
# for an honest assistant, not a sandbox.
#
# Portable: bash 3.2+, POSIX awk (BWK awk on macOS, mawk, gawk). No jq.

set -u

# read -d '' rather than $(cat <<…): bash 3.2 mis-parses quotes in a heredoc
# inside a command substitution.
IFS= read -r -d '' PROG <<'AWK' || true
function has(list, w) { return index(list, " " w " ") > 0 }
function inl(list, w) { return index(list, "|" w "|") > 0 }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# ---------- strings from character arrays ----------
# All scanning works on character arrays made once with split(s, A, ""), and
# strings are built in 256-character pieces: awks that index UTF-8 strings
# (BWK awk on macOS) make substr() and long appends linear per call, which would
# make a large heredoc take seconds instead of milliseconds.
function arr2str(A, i, j,    r, p, c) {
  r = ""; p = ""; c = 0
  for (; i <= j; i++) { p = p A[i]; if (++c == 256) { r = r p; p = ""; c = 0 } }
  return r p
}
function lwadd(c) { LB = LB c; if (++LBN == 256) { LW = LW LB; LB = ""; LBN = 0 } }
function lwflush() { if (LBN) { LW = LW LB; LB = ""; LBN = 0 } }

# ---------- JSON (only the fields we need) ----------
function hexv(h,    i, v, d) {
  v = 0
  for (i = 1; i <= length(h); i++) { d = index("0123456789abcdef", substr(h, i, 1)); if (d == 0) return -1; v = v * 16 + d - 1 }
  return v
}
function jdec(i, n,    c, e, v) {  # decode the JSON string starting at R[i] into D[1..DL]
  DL = 0
  while (i <= n) {
    c = R[i]
    if (c == "\"") return i + 1
    if (c == "\\") {
      e = R[i + 1]
      if (e == "n") c = "\n"; else if (e == "t") c = "\t"; else if (e == "r") c = "\r"
      else if (e == "b" || e == "f") c = " "
      else if (e == "u") { v = hexv(tolower(R[i + 2] R[i + 3] R[i + 4] R[i + 5])); D[++DL] = (v > 0 && v < 128) ? sprintf("%c", v) : "?"; i += 6; continue }
      else c = e
      D[++DL] = c; i += 2; continue
    }
    D[++DL] = c; i++
  }
  return i
}
function json(n,    i, c, d, j) {
  i = 1; d = 0
  while (i <= n) {
    c = R[i]
    if (c == "\"") {
      i = jdec(i + 1, n)
      j = i; while (j <= n && (R[j] == " " || R[j] == "\t" || R[j] == "\r" || R[j] == "\n")) j++
      if (R[j] == ":" && JT[d] == "o") { JK[d] = (DL <= 256) ? arr2str(D, 1, DL) : "_long_"; i = j + 1; continue }
      if (d == 1 && JK[1] == "tool_name") TN = arr2str(D, 1, DL)
      else if (d == 1 && JK[1] == "cwd") CWD = arr2str(D, 1, DL)
      else if (d == 2 && JK[1] == "tool_input" && JK[2] == "command") { CMD = arr2str(D, 1, DL); HAVECMD = 1 }
      continue
    }
    if (c == "{") { d++; JT[d] = "o"; JK[d] = "" }
    else if (c == "[") { d++; JT[d] = "a"; JK[d] = "" }
    else if (c == "}" || c == "]") d--
    i++
  }
}

# ---------- shell lexer (over the character array A[1..n]) ----------
function emitw() {
  lwflush()
  if (LIN) {
    if (LSKIP == 2) { SEGIN[LSEG] = SEGIN[LSEG] LW "\n"; LSKIP = 0 }
    else if (LSKIP) LSKIP = 0
    else { NT++; TK[NT] = LW; TY[NT] = "w" }
  }
  LW = ""; LIN = 0
}
function emits(op) { emitw(); LSKIP = 0; NT++; TK[NT] = op; TY[NT] = "s"; LSEG++ }
function addsub(i, j) { if (j >= i) { NSUB++; SUBS[NSUB] = arr2str(A, i, j) } }
function squote_end(i, n) { while (i <= n && A[i] != "'") i++; return i }
# hd_delim(i, n): parse a heredoc delimiter starting just after "<<"; sets HDD
# (the delimiter) and HDQ (1 when any part was quoted, so the body is literal).
function hd_delim(i, n,    c) {
  if (A[i] == "-") i++
  while (A[i] == " " || A[i] == "\t") i++
  HDD = ""; HDQ = 0
  while (i <= n) {
    c = A[i]
    if (index(" \t\n;|&<>()", c) > 0) break
    if (c == "'" || c == "\"" || c == "\\") HDQ = 1; else HDD = HDD c
    i++
  }
  return i
}
# hd_end(i, n, delim): i is the first body line; returns the index after the
# delimiter line and sets HDBEND to the last body character.
function hd_end(i, n, delim,    j, line, c) {
  while (i <= n) {
    line = ""; c = 0
    for (j = i; j <= n && A[j] != "\n"; j++) if (++c <= 256) line = line A[j]
    sub(/^\t+/, "", line); sub(/\r$/, "", line)
    if (line == delim) { HDBEND = i - 1; return j + 1 }
    i = j + 1
  }
  HDBEND = n
  return n + 1
}
# pending heredocs inside a $( ) or `` scan: delimiters joined by \034
function hd_flush(i, n, pend,    m, q) {
  m = split(pend, HDTMP, "\034")
  for (q = 1; q <= m; q++) i = hd_end(i, n, HDTMP[q])
  return i
}
function backtick_end(i, n,    pend) {
  pend = ""
  while (i <= n) {
    if (A[i] == "\\") { i += 2; continue }
    if (A[i] == "`") return i
    if (A[i] == "\n" && pend != "") { i = hd_flush(i + 1, n, pend); pend = ""; continue }
    if (A[i] == "<" && A[i + 1] == "<" && A[i + 2] != "<") { i = hd_delim(i + 2, n); pend = pend (pend == "" ? "" : "\034") HDD; continue }
    i++
  }
  return n + 1
}
# paren_end(i, n, arith): A[i] is "("; returns the index of the matching ")".
# Skips quotes, comments and heredoc bodies (not in arithmetic, where << shifts).
function paren_end(i, n, arith,    c, d, pend, p) {
  d = 0; pend = ""
  while (i <= n) {
    c = A[i]
    if (c == "\\") { i += 2; continue }
    if (c == "\n" && pend != "") { i = hd_flush(i + 1, n, pend); pend = ""; continue }
    if (c == "'") { i = squote_end(i + 1, n) + 1; continue }
    if (c == "\"") { i++; while (i <= n && A[i] != "\"") { if (A[i] == "\\") i++; i++ } i++; continue }
    if (c == "#" && !arith) { p = A[i - 1]; if (p == " " || p == "\t" || p == "\n" || p == "(" || p == ";") { while (i <= n && A[i] != "\n") i++; continue } }
    if (!arith && c == "<" && A[i + 1] == "<") {
      if (A[i + 2] == "<") { i += 3; continue }
      i = hd_delim(i + 2, n); pend = pend (pend == "" ? "" : "\034") HDD; continue
    }
    if (c == "(") d++
    else if (c == ")") { d--; if (d == 0) return i }
    i++
  }
  return n + 1
}
# a $( or $(( at A[i]; queues the command text (or the arithmetic's inner text,
# for substitutions nested in it) and returns the index after the closing ")"
function dollar_paren(i, n,    j) {
  if (A[i + 2] == "(") { j = paren_end(i + 1, n, 1); addsub(i + 3, j - 2) }
  else { j = paren_end(i + 1, n, 0); addsub(i + 2, j - 1) }
  return j + 1
}
# scan_subs(i, j, sq): queue every $( ) and `` in A[i..j] (unquoted heredoc
# bodies, array literals). sq: single quotes protect their content.
function scan_subs(i, j, sq,    c, e) {
  while (i <= j) {
    c = A[i]
    if (c == "\\") { i += 2; continue }
    if (sq && c == "'") { i = squote_end(i + 1, LN) + 1; continue }
    if (c == "$" && A[i + 1] == "(") { i = dollar_paren(i, LN); continue }
    if (c == "`") { e = backtick_end(i + 1, LN); addsub(i + 1, e - 1); i = e + 1; continue }
    i++
  }
}
function lex_dq(i, n,    c, c2, j) {
  while (i <= n) {
    c = A[i]
    if (c == "\\") {
      c2 = A[i + 1]
      if (c2 == "\n") { i += 2; continue }
      if (c2 == "\"" || c2 == "\\" || c2 == "$" || c2 == "`") { lwadd(c2); i += 2; continue }
      lwadd(c); i++; continue
    }
    if (c == "\"") return i + 1
    if (c == "`") { j = backtick_end(i + 1, n); addsub(i + 1, j - 1); lwadd("_SUB_"); i = j + 1; continue }
    if (c == "$" && A[i + 1] == "(") { i = dollar_paren(i, n); lwadd("_SUB_"); continue }
    lwadd(c); i++
  }
  return i
}
function lex(n,    i, c, c2, j, k, nhd, b) {
  NT = 0; NSUB = 0; LW = ""; LB = ""; LBN = 0; LIN = 0; LSKIP = 0; nhd = 0; LN = n; LSEG = 1
  split("", SEGIN)
  i = 1
  while (i <= n) {
    c = A[i]
    if (c == " " || c == "\t" || c == "\r") { emitw(); i++; continue }
    if (c == "\n") {
      emits(";"); i++
      for (k = 1; k <= nhd; k++) {
        b = i; i = hd_end(i, n, HD[k])
        if (HDBEND >= b) {
          SEGIN[HSEG[k]] = SEGIN[HSEG[k]] arr2str(A, b, HDBEND) "\n"
          if (!HQ[k]) scan_subs(b, HDBEND, 0)
        }
      }
      nhd = 0; continue
    }
    if (c == "\\") { if (A[i + 1] != "\n") { lwadd(A[i + 1]); LIN = 1 } i += 2; continue }
    if (c == "$" && A[i + 1] == "'") {  # $'…' ANSI-C quoting
      i += 2
      while (i <= n && A[i] != "'") { if (A[i] == "\\") { i++; c2 = A[i]; lwadd(c2 == "n" ? "\n" : (c2 == "t" ? "\t" : c2)) } else lwadd(A[i]); i++ }
      LIN = 1; i++; continue
    }
    if (c == "'") {
      j = squote_end(i + 1, n)
      for (k = i + 1; k < j; k++) lwadd(A[k])
      LIN = 1; i = j + 1; continue
    }
    if (c == "\"") { i = lex_dq(i + 1, n); LIN = 1; continue }
    if (c == "`") { j = backtick_end(i + 1, n); addsub(i + 1, j - 1); lwadd("_SUB_"); LIN = 1; i = j + 1; continue }
    if (c == "$" && A[i + 1] == "(") { i = dollar_paren(i, n); lwadd("_SUB_"); LIN = 1; continue }
    if ((c == "<" || c == ">") && A[i + 1] == "(" && !LIN) {
      j = paren_end(i + 1, n, 0); addsub(i + 2, j - 1); lwadd("_SUB_"); LIN = 1; i = j + 1; continue
    }
    if (c == "#" && !LIN) { while (i <= n && A[i] != "\n") i++; continue }
    if (c == "(" && LIN) {  # name=( … ) array literal: words, not commands
      lwflush()
      if (LW ~ /=$/) { j = paren_end(i, n, 0); scan_subs(i + 1, j - 1, 1); lwadd("(…)"); i = j + 1; continue }
    }
    if (c == "(" && A[i + 1] == "(" && !LIN) {  # (( arithmetic command ))
      emits(";"); j = paren_end(i, n, 1); addsub(i + 2, j - 2); i = j + 1; continue
    }
    if (c == ";" || c == "|" || c == "(" || c == ")") {
      c2 = A[i + 1]
      if (c == "|" && c2 == "|") { emits("||"); i += 2; continue }
      if (c == "|" && c2 == "&") { emits("|"); i += 2; continue }
      if (c == ";" && c2 == ";") i++
      emits(c); i++; continue
    }
    if (c == "&") {
      c2 = A[i + 1]
      if (c2 == ">") { emitw(); i += 2; if (A[i] == ">") i++; LSKIP = 1; continue }
      if (c2 == "&") { emits("&&"); i += 2; continue }
      emits("&"); i++; continue
    }
    if (c == "<" || c == ">") {
      lwflush()
      if (LIN && LW ~ /^[0-9]+$/) { LW = ""; LIN = 0 } else emitw()
      c2 = A[i + 1]
      if (c == "<" && c2 == "<") {
        if (A[i + 2] == "<") { i += 3; LSKIP = 2; continue }  # here-string: kept as the segment's stdin
        i = hd_delim(i + 2, n)
        nhd++; HD[nhd] = HDD; HQ[nhd] = HDQ; HSEG[nhd] = LSEG; continue
      }
      i++
      if (c2 == ">" || c2 == "&" || c2 == "|" || (c == "<" && c2 == ">")) i++
      LSKIP = 1; continue
    }
    lwadd(c); LIN = 1; i++
  }
  emitw()
}
function lexs(s) { split("", A); lex(split(s, A, "")) }

# ---------- segments ----------
function enqueue(s) {
  if (NOQ) { CQN++; CQ[CQN] = s; CQK[CQN] = CURKEY } else { QT++; Q[QT] = s }
}
function joinw(k,    j, r) { r = ""; for (j = k; j <= SN; j++) r = r (j > k ? " " : "") SW[j]; return r }
function basename(w) { sub(/.*\//, "", w); return w }
function pkgname(w,    r) {
  if (w ~ /^@/) { r = substr(w, 2); if (index(r, "@") > 0) r = substr(r, 1, index(r, "@") - 1); w = "@" r }
  else if (index(w, "@") > 0) w = substr(w, 1, index(w, "@") - 1)
  if (w == "@changesets/cli") w = "changeset"
  w = basename(w)
  if (w == "aws-cdk") w = "cdk"; else if (w == "netlify-cli") w = "netlify"; else if (w == "firebase-tools") w = "firebase"
  return w
}
# take_c(k): find "-c CMD"-style option from SW[k] on; queues CMD. Returns 1 if found.
function take_c(k, re,    j) {
  for (j = k; j <= SN; j++) {
    if (SW[j] ~ re) { if (j < SN) enqueue(SW[j + 1]); return 1 }
    if (SW[j] ~ /^--command=/) { enqueue(substr(SW[j], 11)); return 1 }
  }
  return 0
}
# strip(k): skip prefixes and wrappers; returns the index of the command word,
# 0 if there is none or the real command was queued (bash -c, su -c, trap …)
function strip(k,    w, g, j) {
  for (g = 0; g < 32 && k <= SN; g++) {
    w = SW[k]
    if (w ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) { k++; continue }
    if (has(" { } ! if then do else elif while until -- ", w)) { k++; continue }
    if (w == "time") { k++; while (k <= SN && SW[k] ~ /^-/) k++; continue }
    if (w == "coproc") { k++; if (k < SN && SW[k] ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && SW[k + 1] == "{") k++; continue }
    if (w == "env") {
      k++
      while (k <= SN) {
        w = SW[k]
        if (w == "-u" || w == "--unset" || w == "-C" || w == "--chdir") { k += 2; continue }
        if (w == "-S" || w == "--split-string") { if (k < SN) enqueue(joinw(k + 1)); return 0 }
        if (w ~ /^-S./) { SW[k] = substr(w, 3); enqueue(joinw(k)); return 0 }
        if (w ~ /^--split-string=/) { SW[k] = substr(w, 16); enqueue(joinw(k)); return 0 }
        if (w ~ /^-/ || w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { k++; continue }
        break
      }
      continue
    }
    if (w == "sudo" || w == "doas") { k++; while (k <= SN && SW[k] ~ /^-/) { if (SW[k] ~ /^-[ugpChrtTUDR]$/) k += 2; else k++ } continue }
    if (w == "command") { k++; while (k <= SN && SW[k] ~ /^-/) { if (SW[k] ~ /[vV]/) return 0; k++ } continue }
    if (w == "exec") { k++; while (k <= SN && SW[k] ~ /^-/) { if (SW[k] == "-a") k += 2; else k++ } continue }
    if (has(" builtin nohup noglob nocorrect setsid ", w)) { k++; while (k <= SN && SW[k] ~ /^-/) k++; continue }
    if (w == "nice" || w == "ionice" || w == "watch" || w == "stdbuf") {
      k++
      while (k <= SN && SW[k] ~ /^-/) { if (has(" -n -c -i -o -e --adjustment --interval --class --classdata ", SW[k])) k += 2; else k++ }
      continue
    }
    if (w == "timeout") { k++; while (k <= SN && SW[k] ~ /^-/) { if (has(" -s -k --signal --kill-after ", SW[k])) k += 2; else k++ } k++; continue }
    if (w == "xargs") { k++; while (k <= SN && SW[k] ~ /^-/) { if (SW[k] ~ /^-[InLPdsEa]$/) k += 2; else k++ } continue }
    if (w == "parallel") {
      k++; while (k <= SN && SW[k] ~ /^-/) { if (has(" -j --jobs -S --sshlogin -a --arg-file --delay --timeout ", SW[k])) k += 2; else k++ }
      for (j = k; j <= SN; j++) if (SW[j] ~ /^:::/) { SN = j - 1; break }
      continue
    }
    if (w == "flock") {
      k++
      while (k <= SN && SW[k] ~ /^-/) { if (SW[k] == "-c" || SW[k] == "--command") { if (k < SN) enqueue(SW[k + 1]); return 0 } if (has(" -w -E --timeout --wait --conflict-exit-code ", SW[k])) k += 2; else k++ }
      k++
      if (SW[k] == "-c" || SW[k] == "--command") { if (k < SN) enqueue(SW[k + 1]); return 0 }
      continue
    }
    if (w == "su" || w == "runuser") { take_c(k + 1, "^(-c|--command)$"); return 0 }
    if (w == "script") { take_c(k + 1, "^(-[A-Za-z]*c[A-Za-z]*|--command)$"); return 0 }
    if (w == "trap") { if (k < SN && SW[k + 1] !~ /^-/) enqueue(SW[k + 1]); return 0 }
    if (w == "npx" || w == "pnpx" || w == "bunx" || w == "uvx" || \
        ((w == "pnpm" || w == "yarn") && (SW[k + 1] == "dlx" || SW[k + 1] == "exec")) || \
        (w == "npm" && (SW[k + 1] == "exec" || SW[k + 1] == "x")) || (w == "bun" && SW[k + 1] == "x") || \
        (w == "pipx" && SW[k + 1] == "run")) {
      k += (w == "npx" || w == "pnpx" || w == "bunx" || w == "uvx") ? 1 : 2
      while (k <= SN && SW[k] ~ /^-/) {
        if (SW[k] == "-c" || SW[k] == "--call") { if (k < SN) enqueue(SW[k + 1]); return 0 }
        if (SW[k] == "-p" || SW[k] == "--package" || SW[k] == "--from") k += 2; else k++
      }
      if (k <= SN) SW[k] = pkgname(SW[k])
      continue
    }
    break
  }
  return (k <= SN) ? k : 0
}
# cmdstart(k): the command word after prefixes. Resolves `bash script` to the
# script, `python -m mod` to mod and `find -exec cmd …` to cmd; queues `bash -c
# STR` and `eval …`; flags a shell that reads commands from stdin (STDIN_SHELL).
# Sets NB (command basename) and returns the command index, or 0.
function cmdstart(k,    j, w, m) {
  k = strip(k); if (k == 0) return 0
  NB = basename(SW[k])
  if (NB ~ /^(bash|sh|zsh|dash|ksh)$/) {
    for (j = k + 1; j <= SN; j++) {
      w = SW[j]
      if (w ~ /^-[A-Za-z]*c[A-Za-z]*$/) { if (j < SN) enqueue(SW[j + 1]); return 0 }
      if (w == "-o" || w == "+o" || w == "-O" || w == "+O") { j++; continue }
      if (w ~ /^[-+]/) continue
      break
    }
    if (j > SN) { STDIN_SHELL = 1; return 0 }
    k = j; NB = basename(SW[k])
  }
  if (NB ~ /^python[0-9.]*$/ && SW[k + 1] == "-m" && k + 2 <= SN) { k += 2; NB = SW[k] }
  if (NB == "eval") { if (k < SN) enqueue(joinw(k + 1)); return 0 }
  if (NB == "find") {
    for (j = k + 1; j <= SN; j++) if (has(" -exec -execdir -ok -okdir ", SW[j])) break
    if (j > SN) return 0
    m = 0; for (j = j + 1; j <= SN && SW[j] != ";" && SW[j] != "+"; j++) { m++; SW[m] = SW[j] }
    SN = m; if (SN == 0) return 0
    return cmdstart(1)
  }
  return k
}
# positional words for contract matching: no options, no VAR=x, and npm-family
# "run" aliases dropped, as " w1 w2 … "
function cposl(k,    j, w, r) {
  r = " "
  for (j = k + 1; j <= SN; j++) {
    w = SW[j]
    if (w ~ /^-./ || w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    if (has(" npm pnpm yarn bun ", NB) && has(" run run-script rum urn ", w)) continue
    r = r w " "
  }
  return r
}
function contract_hit(k,    j, cp, m, q) {
  cp = ""
  for (j = 1; j <= ND; j++) {
    if (DENYB[j] != NB) continue
    if (cp == "") cp = cposl(k)
    m = split(DENYP[j], DPW, " ")
    for (q = 1; q <= m; q++) if (!has(cp, DPW[q])) break
    if (q > m) return DENY[j] " — a deploy command listed under " DENYK[j] " in .delivery-loop.yml"
  }
  return ""
}

function check(s,    t, r, k, seg, psep) {
  lexs(s)
  for (k = 1; k <= NSUB; k++) enqueue(SUBS[k])
  SN = 0; seg = 1; psep = ""; PREVPROD = ""; PREVIN = ""
  for (t = 1; t <= NT + 1; t++) {
    if (t > NT || TY[t] == "s") {
      if (SN > 0) {
        CURSEG = seg; CURPIPE = (psep == "|")
        r = segment(); if (r != "") return r
        PREVPROD = LASTPROD; PREVIN = SEGIN[seg]
      } else { PREVPROD = ""; PREVIN = "" }
      if (t <= NT) { psep = TK[t]; seg++ }
      SN = 0; continue
    }
    SN++; SW[SN] = TK[t]
  }
  return ""
}
function segment(    k, r) {
  STDIN_SHELL = 0; LASTPROD = ""
  k = cmdstart(1)
  if (STDIN_SHELL) {  # bash/sh with no -c and no script: commands come from stdin
    if (SEGIN[CURSEG] != "") { enqueue(SEGIN[CURSEG]); return "" }
    if (CURPIPE) {
      if (PREVPROD != "") { enqueue(PREVPROD); return "" }
      if (PREVIN != "") { enqueue(PREVIN); return "" }
      return "a shell reading commands from a pipe whose input cannot be checked"
    }
    return ""
  }
  if (k == 0) return ""
  if (NB == "echo" || NB == "printf") {
    r = k + 1; while (NB == "echo" && r <= SN && SW[r] ~ /^-[neE]+$/) r++
    LASTPROD = joinw(r); gsub(/\\n/, "\n", LASTPROD)
  }
  r = contract_hit(k); if (r != "") return r
  if (NB == "git" || NB == "hub") return git_rule(k)
  if (NB ~ /^git-/ && has(GIT_WRITE, substr(NB, 5))) return gw(substr(NB, 5))
  if (NB == "gh") return gh_rule(k)
  return deploy_rule(NB, k)
}

# ---------- git ----------
function gw(what) { return "git " what " — a git write operation" }
function pos1(    j) { for (j = 1; j <= NA; j++) if (GA[j] !~ /^-/) return GA[j]; return "" }
function anyarg(list,    j) { for (j = 1; j <= NA; j++) if (has(list, GA[j])) return 1; return 0 }
function git_rule(k,    j, sc, kv, key) {
  j = k + 1
  while (j <= SN && SW[j] ~ /^-/) {
    if (SW[j] == "-c" && j < SN) {  # config that runs a command: check that command too
      kv = SW[j + 1]; key = tolower(kv); sub(/=.*/, "", key)
      if (index(kv, "=") > 0 && key ~ /(fsmonitor|sshcommand|pager|editor|askpass|textconv|external|gitproxy|program|helper|\.cmd$|\.command$|^alias\.)/) {
        kv = substr(kv, index(kv, "=") + 1); sub(/^!/, "", kv); enqueue(kv)
      }
    }
    if (has(" -C -c --git-dir --work-tree --namespace --super-prefix --config-env --attr-source ", SW[j])) j += 2; else j++
  }
  if (j > SN) return ""
  sc = SW[j]; NA = 0
  for (j = j + 1; j <= SN; j++) { NA++; GA[NA] = SW[j] }
  return git_sub(sc)
}
function git_sub(sc,    p, j, w, npos, listm) {
  if (has(GIT_READ, sc)) return ""
  p = pos1()
  if (sc == "branch") return branch_rule()
  if (sc == "tag") return tag_rule()
  if (sc == "config") return config_rule()
  if (sc == "remote") return (p == "" || p == "show" || p == "get-url") ? "" : gw("remote " p)
  if (sc == "stash") return (p == "list" || p == "show") ? "" : gw("stash" (p == "" ? "" : " " p))
  if (sc == "worktree") return (p == "list") ? "" : gw("worktree " p)
  if (sc == "reflog") return (p == "expire" || p == "delete") ? gw("reflog " p) : ""
  if (sc == "notes") return (p == "" || p == "list" || p == "show") ? "" : gw("notes " p)
  if (sc == "submodule") return (p == "" || p == "status" || p == "summary") ? "" : gw("submodule " p)
  if (sc == "lfs") return has(" ls-files status env version ", p) ? "" : gw("lfs " p)
  if (sc == "sparse-checkout") return (p == "list") ? "" : gw("sparse-checkout " p)
  if (sc == "hash-object") return anyarg(" -w ") ? gw("hash-object -w") : ""
  if (sc == "interpret-trailers") return anyarg(" --in-place ") ? gw("interpret-trailers --in-place") : ""
  if (sc == "symbolic-ref") {
    if (anyarg(" -d --delete ")) return gw("symbolic-ref --delete")
    npos = 0; for (j = 1; j <= NA; j++) if (GA[j] !~ /^-/) npos++
    return (npos >= 2) ? gw("symbolic-ref (set)") : ""
  }
  if (sc == "fetch") {
    for (j = 1; j <= NA; j++) {
      w = GA[j]
      if (w == "--update-head-ok") return gw("fetch --update-head-ok")
      if (w !~ /^-/ && index(w, ":") > 0 && w !~ /:\/\// && w !~ /^[^:]*@/) return gw("fetch " w " (writes a local ref)")
    }
    return ""
  }
  if (sc == "apply") return (anyarg(" --check --stat --numstat --summary ") && !anyarg(" --apply ")) ? "" : gw("apply")
  if (has(GIT_WRITE, sc)) return gw(sc)
  return "git " sc " — not on the read-only git allow list (unknown subcommands and aliases are blocked)"
}
function branch_rule(    j, w, listm, npos) {
  listm = 0; npos = 0
  for (j = 1; j <= NA; j++) {
    w = GA[j]
    if (has(" -d -D --delete -m -M --move -c -C --copy -f --force -u --set-upstream-to --unset-upstream --edit-description -t --track --no-track --create-reflog ", w) || w ~ /^--(set-upstream-to|track)=/) return gw("branch " w)
    if (w ~ /^-[A-Za-z]+$/ && w ~ /[dDmMcCfut]/) return gw("branch " w)
    if (has(" -l --list -a --all -r --remotes --show-current ", w)) { listm = 1; continue }
    if (has(" --contains --no-contains --merged --no-merged --points-at --sort --format ", w)) { listm = 1; if (j < NA && GA[j + 1] !~ /^-/) j++; continue }
    if (w ~ /^-/) continue
    npos++
  }
  return (npos > 0 && !listm) ? "git branch <name> — creates a branch (a git write operation)" : ""
}
function tag_rule(    j, w, listm, ver, npos) {
  listm = 0; ver = 0; npos = 0
  for (j = 1; j <= NA; j++) {
    w = GA[j]
    if (has(" -d --delete -a --annotate -s --sign -u --local-user -f --force -m --message -F --file -e --edit --cleanup ", w) || w ~ /^--(message|file|local-user|cleanup)=/ || w ~ /^-[mFu]./) return gw("tag " w)
    if (has(" -l --list ", w) || w ~ /^-n[0-9]*$/) { listm = 1; continue }
    if (has(" --contains --no-contains --points-at --merged --no-merged --sort --format ", w)) { listm = 1; if (j < NA && GA[j + 1] !~ /^-/) j++; continue }
    if (has(" -v --verify ", w)) { ver = 1; continue }
    if (w ~ /^-/) continue
    npos++
  }
  return (npos > 0 && !listm && !ver) ? "git tag <name> — creates a tag (a git write operation)" : ""
}
function config_rule(    j, w, npos, first, rd) {
  npos = 0; first = ""; rd = 0
  for (j = 1; j <= NA; j++) {
    w = GA[j]
    if (has(" --file -f --blob --type --default --comment ", w)) { j++; continue }
    if (has(" --unset --unset-all --add --replace-all --rename-section --remove-section --edit -e ", w)) return gw("config " w)
    if (has(" --get --get-all --get-regexp --get-urlmatch --list -l ", w)) { rd = 1; continue }
    if (w ~ /^-/) continue
    npos++; if (npos == 1) first = w
  }
  if (first == "get" || first == "list") return ""
  if (has(" set unset rename-section remove-section edit ", first)) return gw("config " first)
  if (rd) return ""
  return (npos >= 2) ? gw("config <key> <value>") : ""
}

# ---------- gh ----------
function gh_rule(k,    j, w, g1, g2) {
  g1 = ""; g2 = ""
  for (j = k + 1; j <= SN; j++) {
    w = SW[j]
    if (has(" -R --repo --hostname ", w)) { j++; continue }
    if (w ~ /^-/) continue
    if (g1 == "") g1 = w; else { g2 = w; break }
  }
  if (g1 == "") return ""
  if (g1 == "api") return gh_api(k)
  if (g1 == "auth" && (g2 == "token" || anyw(k, " -t --show-token "))) return "gh auth " g2 " — prints a credential into the conversation"
  if (g1 == "browse") return anyw(k, " -n --no-browser ") ? "" : "gh browse — opens a browser; use gh browse --no-browser"
  if (has(" version help status search completion ", g1)) return ""
  if (inl(GH_READ, g1 " " g2)) return ""
  return "gh " g1 (g2 == "" ? "" : " " g2) " — not a read-only gh command"
}
function gh_api(k,    j, w, m, fields, mut, gql) {
  m = ""; fields = 0; mut = 0; gql = 0
  for (j = k + 1; j <= SN; j++) {
    w = SW[j]
    if (w == "-X" || w == "--method") { m = toupper(SW[j + 1]); j++; continue }
    if (w ~ /^-X./) { m = toupper(substr(w, 3)); continue }
    if (w ~ /^--method=/) { m = toupper(substr(w, 10)); continue }
    if (has(" -f -F --field --raw-field --input ", w)) {
      fields = 1; if (w == "--input" || SW[j + 1] ~ /mutation/ || SW[j + 1] ~ /^[^=]*=@/) mut = 1
      j++; continue
    }
    if (w ~ /^-[fF]./ || w ~ /^--(field|raw-field|input)=/) { fields = 1; if (w ~ /mutation/ || w ~ /^--input=/ || w ~ /=@/) mut = 1; continue }
    if (w == "graphql") gql = 1
  }
  if (gql) return mut ? "gh api graphql — a mutation, or a query read from a file that cannot be checked" : ""
  if (m == "") m = fields ? "POST" : "GET"
  return (m == "GET" || m == "HEAD") ? "" : "gh api -X " m " — a write through the GitHub API"
}
# ---------- deploys ----------
function positionals(k, valopts,    j, w) {
  NP = 0
  for (j = k + 1; j <= SN; j++) {
    w = SW[j]
    if (w ~ /^-./) { if (index(w, "=") == 0 && has(valopts, w)) j++; continue }
    NP++; POS[NP] = w
  }
  for (j = NP + 1; j <= NP + 4; j++) POS[j] = ""
}
function anyw(k, list,    j) { for (j = k + 1; j <= SN; j++) if (has(list, SW[j])) return 1; return 0 }
function anyre(k, re,    j) { for (j = k + 1; j <= SN; j++) if (SW[j] ~ re) return 1; return 0 }
function dep(what) { return what " — a deploy or publish command" }
function deploy_rule(b, k,    j) {
  if (b == "tofu") b = "terraform"
  if (b == "terraform" || b == "terragrunt") {
    positionals(k, "")
    if (b == "terragrunt" && (POS[1] == "run-all" || POS[1] == "run")) { POS[1] = POS[2]; POS[2] = POS[3] }
    if (has(" apply destroy import taint untaint ", POS[1])) return dep(b " " POS[1])
    if (POS[1] == "state" && has(" rm mv push replace-provider ", POS[2])) return dep(b " state " POS[2])
    if (POS[1] == "workspace" && POS[2] == "delete") return dep(b " workspace delete")
    return ""
  }
  if (b == "pulumi") { positionals(k, " -s --stack -C --cwd "); return (has(" up update destroy import refresh ", POS[1]) || (POS[1] == "stack" && POS[2] == "rm")) ? dep("pulumi " POS[1]) : "" }
  if (b == "kubectl" || b == "oc") {
    positionals(k, " -n --namespace --context --cluster --kubeconfig -s --server --user --token --as --as-group -l --selector -f --filename -o --output -c --container -p --request-timeout --certificate-authority --client-certificate --client-key --tls-server-name --cache-dir --log-file ")
    if (has(" apply create delete replace patch edit scale autoscale set label annotate expose run drain cordon uncordon taint ", POS[1])) return dep(b " " POS[1])
    if (b == "oc" && has(" new-app new-build start-build rollback tag import-image adm ", POS[1])) return dep(b " " POS[1])
    if (POS[1] == "rollout" && POS[2] != "status" && POS[2] != "history") return dep(b " rollout " POS[2])
    return ""
  }
  if (b == "helm") {
    positionals(k, " -n --namespace --kube-context --kubeconfig -f --values --set --set-string --version --repo ")
    return has(" install upgrade uninstall delete del un rollback push ", POS[1]) ? dep("helm " POS[1]) : ""
  }
  if (b == "helmfile") { positionals(k, " -f --file -e --environment -l --selector "); return has(" apply sync destroy deploy delete ", POS[1]) ? dep("helmfile " POS[1]) : "" }
  if (b == "aws") {
    positionals(k, AWS_VALOPTS)
    if (POS[1] == "cloudformation" && has(" deploy create-stack update-stack delete-stack execute-change-set ", POS[2])) return dep("aws cloudformation " POS[2])
    if (POS[1] == "s3" && has(" cp sync mv ", POS[2]) && POS[4] ~ /^s3:\/\//) return dep("aws s3 " POS[2] " to " POS[4])
    if (POS[1] == "s3" && has(" rm mb rb ", POS[2])) return dep("aws s3 " POS[2])
    if (POS[1] == "s3api" && POS[2] ~ /^(put|delete|create|restore|copy)-/) return dep("aws s3api " POS[2])
    if (POS[1] == "lambda" && POS[2] ~ /^(update|create|delete|publish)-/) return dep("aws lambda " POS[2])
    if (POS[1] == "ecs" && has(" update-service create-service delete-service ", POS[2])) return dep("aws ecs " POS[2])
    if (POS[1] == "deploy" && POS[2] == "create-deployment") return dep("aws deploy create-deployment")
    return ""
  }
  if (b == "gsutil") {
    positionals(k, " -h -o -u ")
    if (has(" cp mv rsync ", POS[1]) && POS[NP] ~ /^gs:\/\//) return dep("gsutil " POS[1] " to " POS[NP])
    return has(" rm rb mb ", POS[1]) ? dep("gsutil " POS[1]) : ""
  }
  if (b == "gcloud") {
    positionals(k, " --project --region --account --configuration ")
    for (j = 1; j <= NP; j++) if (POS[j] == "deploy") return dep("gcloud … deploy")
    if (POS[1] == "storage" && has(" cp mv rsync ", POS[2]) && POS[NP] ~ /^gs:\/\//) return dep("gcloud storage " POS[2] " to " POS[NP])
    if (POS[1] == "storage" && has(" rm ", POS[2])) return dep("gcloud storage rm")
    return ""
  }
  if (b == "az") {
    positionals(k, " -g --resource-group -n --name --subscription --src-path --type ")
    for (j = 1; j <= NP; j++) if (POS[j] == "deploy") return dep("az … deploy")
    if (POS[1] == "webapp" && POS[2] == "up") return dep("az webapp up")
    if (POS[1] == "deployment" && (POS[2] == "create" || POS[3] == "create")) return dep("az deployment create")
    return ""
  }
  if (has(" docker podman buildah nerdctl ", b)) {
    positionals(k, " -H --host --context -c --config -l --log-level -t --tag -f --file ")
    if (POS[1] == "push" || ((POS[1] == "image" || POS[1] == "manifest") && POS[2] == "push")) return dep(b " push")
    if (POS[1] == "buildx" && (anyw(k, " --push ") || anyre(k, "type=registry|push=true"))) return dep(b " buildx --push")
    if (POS[1] == "compose" && POS[2] == "push") return dep(b " compose push")
    if (POS[1] == "stack" && POS[2] == "deploy") return dep(b " stack deploy")
    if (POS[1] == "service" && has(" create update rm scale rollback ", POS[2])) return dep(b " service " POS[2])
    return ""
  }
  if (has(" npm pnpm yarn bun ", b)) {
    positionals(k, " -w --workspace --prefix -C --dir --filter --registry --tag --otp --access ")
    if (has(" publish unpublish ", POS[1])) return dep(b " " POS[1])
    if (b == "yarn" && POS[1] == "npm" && POS[2] == "publish") return dep("yarn npm publish")
    return ""
  }
  if (b == "uv" || b == "poetry") { positionals(k, " --index --repository -r --username -u --password -p --token "); return (POS[1] == "publish") ? dep(b " publish") : "" }
  if (b == "gradle" || b == "gradlew") { positionals(k, " -p --project-dir -b --build-file -c --settings-file "); for (j = 1; j <= NP; j++) if (POS[j] ~ /(^|:)publish/ && POS[j] !~ /ToMavenLocal$/) return dep(b " " POS[j]); return "" }
  if (b == "changeset") { positionals(k, ""); return (POS[1] == "publish") ? dep("changeset publish") : "" }
  if (b == "semantic-release") return dep("semantic-release")
  if (b == "cdk") { positionals(k, " --profile --app -a -c --context "); return has(" deploy destroy ", POS[1]) ? dep("cdk " POS[1]) : "" }
  if (b == "sam") { positionals(k, " --profile --region --stack-name -t --template-file --config-env "); return has(" deploy sync delete ", POS[1]) ? dep("sam " POS[1]) : "" }
  if (b == "serverless" || b == "sls") { positionals(k, " --stage -s --region -r --aws-profile "); return has(" deploy remove ", POS[1]) ? dep(b " " POS[1]) : "" }
  if (b == "vercel") {
    positionals(k, " --token --scope --cwd -A --local-config --target ")
    if (anyre(k, "^--prod(uction)?(=.*)?$") && !anyre(k, "^--prod(uction)?=(false|0)$")) return dep("vercel --prod")
    if (anyre(k, "^--target=production$")) return dep("vercel --target=production")
    for (j = k + 1; j < SN; j++) if (SW[j] == "--target" && SW[j + 1] == "production") return dep("vercel --target production")
    return has(" promote rollback remove rm ", POS[1]) ? dep("vercel " POS[1]) : ""
  }
  if (b == "netlify") { positionals(k, " --dir -d --site -s --auth --message -m --alias "); return (POS[1] == "deploy" && anyre(k, "^--prod(-if-unlocked)?$")) ? dep("netlify deploy --prod") : "" }
  if (b == "wrangler") { positionals(k, " -c --config --env -e "); return (has(" deploy publish ", POS[1]) || (has(" pages versions ", POS[1]) && has(" deploy publish ", POS[2]))) ? dep("wrangler " POS[1] (has(" deploy publish ", POS[1]) ? "" : " " POS[2])) : "" }
  if (has(" firebase fly flyctl ", b)) { positionals(k, " --project -P --app -a -c --config "); return (POS[1] == "deploy") ? dep(b " deploy") : "" }
  if (b == "cargo") { positionals(k, " --token --registry -p --package --manifest-path "); return has(" publish yank ", POS[1]) ? dep("cargo " POS[1]) : "" }
  if (b == "twine") { positionals(k, ""); return (POS[1] == "upload") ? dep("twine upload") : "" }
  if (b == "gem") { positionals(k, ""); return has(" push yank ", POS[1]) ? dep("gem " POS[1]) : "" }
  if (b == "mvn" || b == "mvnw") { positionals(k, " -f --file -P -pl --projects -s --settings -D "); for (j = 1; j <= NP; j++) if (POS[j] == "deploy" || POS[j] ~ /:deploy$/) return dep(b " deploy"); return "" }
  return ""
}
# ---------- contract (.delivery-loop.yml) ----------
function uncomment(s,    i, c, q, n) {
  q = ""; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (q != "") { if (c == q) q = ""; continue }
    if (c == "\"" || c == "'") { q = c; continue }
    if (c == "#" && (i == 1 || substr(s, i - 1, 1) == " " || substr(s, i - 1, 1) == "\t")) return trim(substr(s, 1, i - 1))
  }
  return trim(s)
}
function unquote(s,    f, l) {
  s = trim(s); sub(/^(cmd|run|command):[ \t]*/, "", s)
  f = substr(s, 1, 1); l = substr(s, length(s), 1)
  if (length(s) >= 2 && (f == "\"" || f == "'") && l == f) { s = substr(s, 2, length(s) - 2); if (f == "\"") gsub(/\\"/, "\"", s) }
  return s
}
function split_inline(s, key,    i, c, q, cur, n) {
  q = ""; cur = ""; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (q != "") { if (c == q) q = ""; cur = cur c; continue }
    if (c == "\"" || c == "'") { q = c; cur = cur c; continue }
    if (c == ",") { add_item(unquote(cur), key); cur = ""; continue }
    cur = cur c
  }
  add_item(unquote(cur), key)
}
function add_item(s, key) { if (s != "" && s != "none" && s !~ /^<.*>$/) { NI++; ITEM[NI] = s; ITEMK[NI] = key } }
# add_deny: a contract entry becomes one rule — the LAST command of its && / ;
# chain (the first command of that pipeline), so `npm run build && npx wrangler
# deploy` denies the deploy, not the build. Rule: command basename + its
# positional words, matched as a subset of a candidate's positional words.
function add_deny(s, key,    t, k, j, inpipe, dn) {
  CURKEY = key; NOQ = 1
  lexs(s); SN = 0; dn = 0; inpipe = 0
  for (t = 1; t <= NT + 1; t++) {
    if (t > NT || TY[t] == "s") {
      if (SN > 0 && !inpipe) { dn = SN; for (j = 1; j <= SN; j++) DW[j] = SW[j] }
      if (t <= NT) inpipe = (TK[t] == "|")
      SN = 0; continue
    }
    SN++; SW[SN] = TK[t]
  }
  if (dn > 0) {
    SN = dn; for (j = 1; j <= SN; j++) SW[j] = DW[j]
    k = cmdstart(1)
    if (k > 0 && !has(" cd pushd popd export source . set true : echo printf test [ ", NB)) {
      ND++; DENYB[ND] = NB; DENYP[ND] = cposl(k); DENYK[ND] = key
      DENY[ND] = NB; for (j = k + 1; j <= SN; j++) DENY[ND] = DENY[ND] " " SW[j]
    }
  }
  NOQ = 0
}
function load_contract(    d, f, g, line, key, rest, cur, j, item) {
  f = ""; d = CWD
  for (g = 0; g < 2 && f == ""; g++) {
    while (d != "") {
      if ((getline line < (d "/.delivery-loop.yml")) >= 0) { close(d "/.delivery-loop.yml"); f = d "/.delivery-loop.yml"; break }
      if (d == "/" || index(d, "/") == 0) break
      sub(/\/[^\/]*$/, "", d); if (d == "") d = "/"
    }
    d = ENVIRON["CLAUDE_PROJECT_DIR"]
  }
  if (f == "") return
  cur = ""
  while ((getline line < f) > 0) {
    sub(/\r$/, "", line)
    if (line ~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]*:/) {
      key = line; sub(/[ \t]*:.*/, "", key)
      rest = line; sub(/^[^:]*:[ \t]*/, "", rest); rest = uncomment(rest)
      cur = (key == "deploy_beta" || key == "deploy_prod") ? key : ""
      if (cur != "" && rest != "") {
        if (rest ~ /^\[/) { sub(/^\[/, "", rest); sub(/\][ \t]*$/, "", rest); split_inline(rest, cur) }
        else add_item(unquote(rest), cur)
      }
      continue
    }
    if (cur != "" && line ~ /^[ \t]*-[ \t]/) { item = line; sub(/^[ \t]*-[ \t]+/, "", item); add_item(unquote(uncomment(item)), cur) }
  }
  close(f)
  for (j = 1; j <= NI; j++) add_deny(ITEM[j], ITEMK[j])
  for (j = 1; j <= CQN && j <= 64; j++) add_deny(CQ[j], CQK[j])
}

BEGIN {
  GIT_READ = " status diff log show ls-files ls-tree ls-remote rev-parse rev-list blame annotate describe shortlog grep cat-file show-ref for-each-ref merge-base name-rev whatchanged help version --version check-ignore check-attr check-mailmap check-ref-format diff-tree diff-files diff-index count-objects fsck var cherry range-diff show-branch verify-commit verify-tag verify-pack patch-id archive format-patch difftool request-pull column get-tar-commit-id "
  GIT_WRITE = " commit push merge rebase reset revert cherry-pick am stash checkout switch clean restore rm mv add pull worktree update-ref update-index init clone gc prune repack filter-branch filter-repo replace commit-tree mktag mktree read-tree write-tree bisect maintenance fast-import send-email mergetool rerere "
  GH_READ = "|pr view|pr list|pr checks|pr diff|pr status|issue view|issue list|issue status|run list|run view|run watch|run download|workflow list|workflow view|release view|release list|release download|repo view|repo list|auth status|secret list|variable list|label list|cache list|gist list|gist view|ruleset list|ruleset view|ruleset check|project list|project view|"
  AWS_VALOPTS = " --profile --region --output --endpoint-url --query --color --ca-bundle --cli-read-timeout --cli-connect-timeout --cli-binary-format --acl --storage-class --exclude --include --sse --sse-kms-key-id --content-type --cache-control --content-disposition --content-encoding --content-language --expires --metadata --metadata-directive --grants --website-redirect --page-size --source-region --request-payer --checksum-algorithm --expected-size "
  raw = ""; MAXB = 524288; nb = 0
  while ((getline line) > 0) {
    raw = raw line "\n"; nb += length(line) + 1
    if (nb > MAXB) { print "BLOCK\tcommand too large for the operator-boundary check (over 512 KB) — split it, or put it in a script the operator runs"; exit 0 }
  }
  json(split(raw, R, ""))
  split("", R); raw = ""
  if (TN != "" && TN != "Bash") { print "ALLOW"; exit 0 }
  if (!HAVECMD || CMD == "") { print "ALLOW"; exit 0 }
  load_contract()
  QT = 1; Q[1] = CMD; qh = 1
  while (qh <= QT) {
    if (qh > 64) { print "BLOCK\tcommand nests too deeply to analyse — run it from the operator runbook"; exit 0 }
    r = check(Q[qh]); qh++
    if (r != "") { print "BLOCK\t" r; exit 0 }
  }
  print "ALLOW"
  exit 0
}
AWK

verdict=$(awk "$PROG") || verdict="ERROR"
case "$verdict" in
  ALLOW) exit 0 ;;
  BLOCK*)
    reason=${verdict#BLOCK?}
    {
      printf 'ascent-delivery operator boundary: blocked — %s.\n' "$reason"
      printf 'Claude never runs git write operations or deploys; the operator does. Do not retry or work around this. '
      printf 'Put the command in the operator runbook (delivery-loop Step 6) with its Expect list and Stop-if condition, and hand it to the operator. '
      printf 'Read-only git (status, diff, log, show) and gh (pr view/list/checks) are allowed.\n'
    } >&2
    exit 2 ;;
  *)
    printf 'ascent-delivery operator boundary: hook error — the command was not checked. Report this to the operator.\n' >&2
    exit 1 ;;
esac
