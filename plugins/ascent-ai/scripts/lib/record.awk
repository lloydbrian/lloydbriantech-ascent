# record.awk — what check-ai-design.sh and check-ai-runtime.sh share: the AI
# design record's marked tables (references/design-record-template.md), and
# whether a code file belongs to this application or to another one whose root
# is deeper. Loaded after common.awk, before the checker's own program.
#
#   read_design(f)  reads the record's tables into A[table, field] (field names
#       lowercased, spaces and underscores alike), the tools table into TN, TREV,
#       TAPP, TLIM and TLN (NT rows), and each table's first line into ALINE.
#   v(table, field)  a field's value, "" when it is missing or a <placeholder>.
#   roots_init()  reads others ("name=root;" for each other application) into
#       the roots deeper than root; mine(path) is 1 when the deepest root holding
#       path is this application's.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function cell(s) { s = trim(s); gsub(/`/, "", s); if (s ~ /^</) s = ""; return s }   # a <placeholder> is empty
function key(s) { s = tolower(cell(s)); gsub(/[_ \t]+/, " ", s); return s }
function norm(p) { p = trim(p); while (p ~ /^\.\//) p = substr(p, 3); return p }
function exists(f,   r, x) { if (f == "") return 0; r = (getline x < f); close(f); return r >= 0 }
function has_text(f, t,   r, line, found) {   # f exists and names t (case-sensitive)
  found = 0
  while ((r = (getline line < f)) > 0) if (index(line, t)) { found = 1; break }
  close(f); return found
}

# the design record's marked tables: A[table, key] = value, ALINE[table] = its line
function read_design(f,   line, n, on, P, k, ln, nt) {
  on = ""; ln = 0; nt = 0
  while ((getline line < f) > 0) {
    ln++; line = strip_cr(line)
    if (line ~ /<!-- ai-design:[a-z-]+:start -->/) { on = line; sub(/^.*<!-- ai-design:/, "", on); sub(/:start -->.*$/, "", on); ALINE[on] = ln; continue }
    if (line ~ /<!-- ai-design:[a-z-]+:end -->/) { on = ""; continue }
    if (on == "" || line !~ /^[ \t]*\|/) continue
    n = split(line, P, "|")
    if (n < 3) continue
    k = key(P[2])
    if (k == "" || k ~ /^-+$/ || P[2] ~ /^[ \t:-]+$/) continue
    if (on == "tools") {
      if (k == "name") continue
      nt++; TN[nt] = cell(P[2]); TREV[nt] = tolower(cell(P[3])); TAPP[nt] = tolower(cell(P[4])); TLIM[nt] = norm(cell(P[5])); TLN[nt] = ln
      continue
    }
    if (k == "field") continue
    A[on, k] = cell(P[3])
  }
  close(f)
  NT = nt
}
function v(t, k) { return ((t, k) in A) ? A[t, k] : "" }

# whether a code file is this application's: its deepest root is ours
function deeper(r) { return r != root && (root == "." || index(r, root "/") == 1) }
function under(p, r) { return r == "." || p == r || index(p, r "/") == 1 }
function mine(p,   i, best) {
  best = (root == ".") ? 0 : length(root)
  for (i = 1; i <= NO; i++) if (under(p, OR_[i]) && length(OR_[i]) > best) return 0
  return 1
}
function roots_init(   n, i, r, OT) {
  n = split(others, OT, ";"); NO = 0
  for (i = 1; i <= n; i++) if (OT[i] != "") { r = OT[i]; sub(/^[^=]*=/, "", r); if (deeper(r)) OR_[++NO] = r }
}
