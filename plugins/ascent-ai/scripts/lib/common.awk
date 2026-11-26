# common.awk — what every ascent-ai checker shares: severity scaling by the AI
# risk tier, the tier record, and CR line ends. Loaded with -f before a
# checker's own program.
#
#   scale(base, tier, fixed)  the severity a finding has at this tier. Every rule's
#       base severity is written for tier 3; at tier 2 it is one level lighter, at
#       tier 1 two levels, never below Low. A rule marked fixed (fixed = 1) is
#       the same at every tier. Levels: Critical, High, Medium, Low.
#   tier_of(file)  the tier in the record's ai-tier table (ascent-governance's
#       references/ai-tier-template.md): 1, 2 or 3; 3 when there is no file, no
#       table or no tier of 1 to 3 (no record means tier 3: the strictest).
#   strip_cr(s)  s without a CR at its end.
#   sev_rank(s)  4 Critical, 3 High, 2 Medium, 1 Low, 0 anything else.
#   sev_name(r)  the level of rank r; Low for 1 and below.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function strip_cr(s) { sub(/\r$/, "", s); return s }
function sev_rank(s) { return s == "Critical" ? 4 : (s == "High" ? 3 : (s == "Medium" ? 2 : (s == "Low" ? 1 : 0))) }
function sev_name(r) { return r >= 4 ? "Critical" : (r == 3 ? "High" : (r == 2 ? "Medium" : "Low")) }
function scale(base, tier, fixed,   r) {
  r = sev_rank(base)
  if (fixed || tier >= 3) return base
  r -= (3 - tier)
  return sev_name(r)   # sev_name floors at Low
}
function tier_of(file,   line, on, n, P, k, v, t) {
  t = 3
  if (file == "") return t
  on = 0
  while ((getline line < file) > 0) {
    line = strip_cr(line)
    if (index(line, "<!-- ai-tier:start -->")) { on = 1; continue }
    if (index(line, "<!-- ai-tier:end -->")) { on = 0; continue }
    if (!on || line !~ /^[ \t]*\|/) continue
    n = split(line, P, "|")
    if (n < 3) continue
    k = P[2]; gsub(/[ \t`]/, "", k); v = P[3]; gsub(/[ \t`]/, "", v)
    if (tolower(k) == "tier" && (v == "1" || v == "2" || v == "3")) t = v + 0
  }
  close(file)
  return t
}
