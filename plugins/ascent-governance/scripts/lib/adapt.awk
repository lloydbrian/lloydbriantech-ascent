# adapt.awk — one check's options and inputs, from the contract and adapters.tsv.
#
# Usage: awk -F '\t' -v check=<plugin>/<script> -v today=YYYY-MM-DD -v nogit=0|1 \
#            [-v item=N -v envname=ENV -v toprung=ENV] -f adapt.awk CONTRACT.tsv adapters.tsv
#
# CONTRACT.tsv is contract.awk's output. Prints one line per result, in the
# order the checker is given them:
#   K                 the check has rows in the table
#   I<TAB>n           the check runs once for each of the n items of a list (an
#                     item row); nothing else is printed until it is asked again
#                     with -v item=0, 1, ... n-1
#   F<TAB>text        an option or an option's value
#   P<TAB>text        an input given by position (a leading "-" becomes "./-")
#   X<TAB>opt<TAB>names  the option once for each named file that exists
#   D<TAB>folder      the folder of dated records the checker runs on, one by one
#   U<TAB>key         an input the contract does not give, with no default
#   E<TAB>message     an entry that could not be turned into a value
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

# with -v item=N, a key under the item row's list takes its value from item N
function at(k) { if (ITEMKEY != "" && item != "" && index(k, ITEMKEY "[*].") == 1) k = ITEMKEY "[" item "]" substr(k, length(ITEMKEY) + 4); return k }
function items(k,   m, i, n) {   # how many items the list k has: its highest index, plus one
  n = 0
  for (i = 1; i <= NC; i++) if (index(KEY[i], k "[") == 1) { m = substr(KEY[i], length(k) + 2); sub(/\].*$/, "", m); if (m ~ /^[0-9]+$/ && m + 1 > n) n = m + 1 }
  return n
}
function star(k) { gsub(/\[[0-9]+\]/, "[*]", k); return k }
function pos(v) { if (substr(v, 1, 1) == "-") v = "./" v; print "P\t" v }

# the values whose key matches pat, into V[1..n]
function matches(pat, V,   i, n) {
  n = 0
  for (i = 1; i <= NC; i++) if (STAR[i] == pat && VAL[i] != "") V[++n] = VAL[i]
  return n
}
function field(k) { return (k in C) ? C[k] : "" }
function joined(prefix,   m, s) {
  s = ""
  for (m = 0; (prefix "[" m "]") in C; m++) if (C[prefix "[" m "]"] != "") s = s (s == "" ? "" : ",") C[prefix "[" m "]"]
  return s
}
# one entry of a list of maps through a template; MISSING names a field it lacks
function expand(tpl, item,   out, a, b, tok, k, v, q) {
  out = ""; MISSING = ""
  while ((a = index(tpl, "{")) > 0) {
    out = out substr(tpl, 1, a - 1); tpl = substr(tpl, a + 1)
    b = index(tpl, "}"); tok = substr(tpl, 1, b - 1); tpl = substr(tpl, b + 1)
    if (substr(tok, 1, 1) == "@") {   # {@key|default}: a contract key, else the default
      k = substr(tok, 2); q = index(k, "|"); v = (q ? field(substr(k, 1, q - 1)) : field(k))
      out = out (v != "" ? v : (q ? substr(k, q + 1) : ""))
    } else if ((q = index(tok, "|")) > 0) {   # {k|default}: the field, else the default
      v = field(item "." substr(tok, 1, q - 1)); out = out (v != "" ? v : substr(tok, q + 1))
    } else if ((q = index(tok, "?")) > 0) {
      v = field(item "." substr(tok, 1, q - 1))
      if (v == "true" || v == "yes") out = out substr(tok, q + 1)
    } else if (tok ~ /,-$/) {
      v = joined(item "." substr(tok, 1, length(tok) - 2)); out = out (v == "" ? "-" : v)
    } else if (tok ~ /,$/) {
      k = substr(tok, 1, length(tok) - 1); v = joined(item "." k)
      if (v == "" && MISSING == "") MISSING = k
      out = out v
    } else {
      v = field(item "." tok)
      if (v == "" && MISSING == "") MISSING = tok
      out = out v
    }
  }
  return out tpl
}

FILENAME == ARGV[1] { NC++; KEY[NC] = $1; VAL[NC] = $2; STAR[NC] = star($1); C[$1] = $2; next }

$1 != check { next }
!known { known = 1; print "K" }
DONE_ { next }
{
  opt = $2; kind = $3; key = at($4); last = ($5 == "-" ? "" : $5)
  if (kind == "item") {   # the first row of a check that runs once per item of a list
    ITEMKEY = key
    if (item == "") { print "I\t" items(key); DONE_ = 1 }
    next
  }
  if (kind == "scalar") { v = field(key); if (v != "") { print "F\t" opt; print "F\t" v } }
  else if (kind == "list") { n = matches(key, V); for (i = 1; i <= n; i++) { print "F\t" opt; print "F\t" V[i] } }
  else if (kind == "csv") {
    n = matches(key, V); s = ""
    for (i = 1; i <= n; i++) s = s (i > 1 ? "," : "") V[i]
    if (n > 0) { print "F\t" opt; print "F\t" s }
  }
  else if (kind == "fmt") {
    for (m = 0; ; m++) {          # e, not item: item is the application an item check runs for
      e = key "[" m "]"; seen = 0
      for (i = 1; i <= NC; i++) if (KEY[i] == e || index(KEY[i], e ".") == 1) { seen = 1; break }
      if (!seen) break
      v = expand(last, e)
      if (MISSING != "") print "E\t" e " has no " MISSING ", so " check " was not given it (" opt ")"
      else { print "F\t" opt; print "F\t" v }
    }
  }
  else if (kind == "const") { print "F\t" opt; if (last != "") print "F\t" last }
  else if (kind == "when") { if (field(key) != "") { print "F\t" opt; if (last != "") print "F\t" last } }
  else if (kind == "today") { print "F\t" opt; print "F\t" today }
  else if (kind == "nogit") { if (nogit == 1) print "F\t" opt }
  else if (kind == "files") print "X\t" opt "\t" last
  else if (kind == "pos") { v = (key == "-" ? "" : field(key)); pos(v == "" ? last : v) }
  else if (kind == "posdir") {
    n = matches(key, V); split("", DONE); k = 0
    for (i = 1; i <= n; i++) {
      v = V[i]
      if (match(v, /[*?\[]/)) { v = substr(v, 1, RSTART - 1); sub(/[^\/]*$/, "", v); sub(/\/+$/, "", v); if (v == "") v = "." }
      if (!(v in DONE)) { DONE[v] = 1; pos(v); k++ }
    }
    if (k == 0) { sub(/\[\*\]$/, "", key); print "U\t" key }      # no default: nothing else says which files to read
  }
  else if (kind == "each") { v = field(key); print "D\t" (v == "" ? last : v) }
  else if (kind == "itemfmt") {   # the key's value, else the template filled from this item
    v = (key == "-" ? "" : field(key)); MISSING = ""
    if (v == "") { v = expand(last, ITEMKEY "[" item "]"); gsub(/\/\/+/, "/", v) }
    if (MISSING != "") print "E\t" ITEMKEY "[" item "] has no " MISSING ", so " check " was not given it (" opt ")"
    else if (opt == "-") pos(v)
    else { print "F\t" opt; print "F\t" v }
  }
  else if (kind == "others") {    # the option once for each other item, from the template
    n = items(ITEMKEY)
    for (m = 0; m < n; m++) if (m "" != item "") { v = expand(last, ITEMKEY "[" m "]"); if (MISSING == "") { print "F\t" opt; print "F\t" v } }
  }
  else if (kind == "words") { v = field(key); n = split(v, W, " "); for (i = 1; i <= n; i++) { print "F\t" opt; print "F\t" W[i] } }
  else if (kind == "env") { if (envname != "") { print "F\t" opt; print "F\t" envname } }
  else if (kind == "toprung") { if (toprung != "") { print "F\t" opt; print "F\t" toprung } }
}
