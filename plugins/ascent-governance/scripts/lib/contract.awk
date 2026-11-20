# contract.awk — flattens the YAML subset .ascent/contract.yml uses.
#
# Prints one "path<TAB>value<TAB>line" row per scalar: the line is where the
# value's key is in the file. Maps nest with ".", lists index with "[n]":
#
#   governance.environments[0]<TAB>local<TAB>4
#   governance.floors.beta.reviews.ux-review<TAB>60<TAB>11
#   security.waivers[0].id<TAB>ADR-021<TAB>31
#
# Reads nested maps, inline lists ([a, b], which may continue on the next
# lines) and inline maps ({ k: v }), block lists of scalars and of maps,
# comments, single and double quotes, and CRLF line ends. A block scalar (| or
# >) is skipped. A key with no value and no children prints nothing.
#
# Exit 2, with "contract.awk: line N: <reason>" on stderr, when a tab is used
# for indentation or an inline list or map never closes: the file is not what its
# author thinks it is, and a guess would hide a floor or a waiver.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function fail(msg) { printf "contract.awk: line %d: %s\n", NR, msg > "/dev/stderr"; bad = 1; exit 2 }

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# the text before a comment: a # at the start or after a blank, outside quotes
function uncomment(s,   i, c, q, out, prev) {
  q = ""; out = ""; prev = " "
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (q != "") { if (c == q) q = "" }
    else if (c == "\"" || c == "'") { if (prev ~ /[ \t:\[{,-]/) q = c }
    else if (c == "#" && prev ~ /[ \t]/) break
    out = out c; prev = c
  }
  return out
}

function unquote(s,   a, z) {
  s = trim(s); a = substr(s, 1, 1); z = substr(s, length(s), 1)
  if (length(s) >= 2 && (a == "\"" || a == "'") && a == z) s = substr(s, 2, length(s) - 2)
  gsub(/\t/, " ", s)
  return s
}

# split on commas outside quotes and brackets; returns the count, parts in P[]
function csv(s, P,   i, c, q, d, n, cur) {
  n = 0; cur = ""; q = ""; d = 0
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (q != "") { if (c == q) q = "" }
    else if (c == "\"" || c == "'") q = c
    else if (c == "[" || c == "{") d++
    else if (c == "]" || c == "}") d--
    else if (c == "," && d == 0) { P[++n] = cur; cur = ""; continue }
    cur = cur c
  }
  if (trim(cur) != "") P[++n] = cur
  return n
}

function emit(path, v) { printf "%s\t%s\t%d\n", path, unquote(v), LN }

function value(path, v,   P, n, i, k, kv, inner) {
  v = trim(v)
  if (v == "" || v == "~" || v == "null") return
  if (v ~ /^\[.*\]$/) {
    n = csv(substr(v, 2, length(v) - 2), P)
    for (i = 1; i <= n; i++) value(path "[" (i - 1) "]", P[i])
    return
  }
  if (v ~ /^\{.*\}$/) {
    n = csv(substr(v, 2, length(v) - 2), P)
    for (i = 1; i <= n; i++) {
      kv = trim(P[i]); k = index(kv, ":")
      if (k > 1) value(path "." unquote(substr(kv, 1, k - 1)), substr(kv, k + 1))
    }
    return
  }
  emit(path, v)
}

# a "key: value" or "key:" line at this indent, under the innermost open container
function keyline(ind, s,   k, key, v, parent, full) {
  k = match(s, /:([ \t]|$)/)
  key = unquote(substr(s, 1, k - 1)); v = trim(substr(s, k + 1))
  while (depth > 0 && IND[depth] >= ind) depth--
  parent = depth > 0 ? PATH[depth] : ""
  full = parent == "" ? key : parent "." key
  if (v ~ /^[|>][+-]?$/) { skip = ind; return }
  if ((v ~ /^\[/ && v !~ /\]$/) || (v ~ /^\{/ && v !~ /\}$/)) { open = full; openv = v; openline = NR; closer = (v ~ /^\[/) ? "]" : "}"; return }
  if (v == "") { depth++; IND[depth] = ind; PATH[depth] = full; KIND[depth] = "key"; return }
  value(full, v)
}

BEGIN { depth = 0; skip = -1; open = "" }

{
  sub(/\r$/, "")
  if (NR == 1 && index($0, "\357\273\277") == 1) $0 = substr($0, length("\357\273\277") + 1)   # a byte-order mark is not part of the first key
  raw = $0
  if (raw ~ /^ *\t/ && raw !~ /^[ \t]*(#|$)/ && open == "") fail("a tab is used for indentation; use spaces")
  line = uncomment(raw)
  if (line ~ /^[ \t]*$/) next

  if (open != "") {                       # an inline list or map continued on this line
    openv = openv " " trim(line)
    if (substr(openv, length(openv), 1) == closer) { LN = openline; value(open, openv); open = "" }
    next
  }

  LN = NR
  ind = match(line, /[^ ]/) - 1
  s = substr(line, ind + 1)
  if (skip >= 0) { if (ind > skip) next; skip = -1 }

  if (s ~ /^-([ \t]|$)/) {                # a list item
    while (depth > 0 && (IND[depth] > ind || (IND[depth] == ind && KIND[depth] != "key"))) depth--
    if (depth == 0) next
    parent = PATH[depth]
    item = parent "[" (CNT[parent] + 0) "]"; CNT[parent]++
    rest = s; sub(/^-[ \t]*/, "", rest)
    off = length(s) - length(rest)
    if (rest == "") next
    if (rest ~ /^[^ \t"'\[{][^ \t]*:([ \t]|$)/ || rest ~ /^("[^"]*"|'[^']*'):([ \t]|$)/) {
      depth++; IND[depth] = ind; PATH[depth] = item; KIND[depth] = "item"
      keyline(ind + off, rest)
    } else value(item, rest)
    next
  }

  if (match(s, /:([ \t]|$)/)) { keyline(ind, s); next }
}

END {
  if (bad) exit 2
  if (open != "") { printf "contract.awk: line %d: the inline list or map that starts here never closes\n", openline > "/dev/stderr"; exit 2 }
}
