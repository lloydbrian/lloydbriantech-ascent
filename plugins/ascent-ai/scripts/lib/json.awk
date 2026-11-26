# json.awk — flattens JSON to one "path<TAB>value" row for each scalar value:
#   results.stats.successes	95
#   results.results[2].testCase.metadata.slice	attack
# Strings are unescaped (\" \\ \/; \n \r \t become a space; \uXXXX is kept as
# written); true, false, null and numbers are printed as written. Empty objects
# and arrays print nothing. With -v multi=1 the input is a sequence of JSON
# values (JSON Lines), and every path starts with the value's index: [0].probe.
#
# Run it with RS set to a double quote: awk -v RS='"' -f json.awk FILE. Records
# then alternate between text outside strings and a string's contents, so no
# record is read twice and a file on one long line costs no more than a
# pretty-printed one. Exits 1, with "json.awk: <reason>" on stderr, when the
# input is not JSON.
#
# This file is copied, byte for byte, as ascent-ai's scripts/lib/json.awk and
# ascent-security's scripts/lib/json-flat.awk (ascent-security's json.awk is
# another reader); test-check-redteam.sh pins the two copies identical.
# Portable: POSIX awk (BWK awk, mawk, gawk); a one-character RS only.

function jerr(why) { if (!ERR) printf "json.awk: %s\n", why > "/dev/stderr"; ERR = 1 }
function here(   d) {   # the path of the value about to be read
  d = D
  if (d == 0) return multi ? "[" NDOC "]" : ""
  if (T[d] == "a") return P[d] "[" I[d] "]"
  return (P[d] == "") ? K[d] : P[d] "." K[d]
}
function value(v) {   # a scalar in value position
  if (D > 0 && T[D] == "o" && WANT[D] != "value") { jerr("a value where a key belongs"); return }
  if (D > 0 && T[D] == "a" && WANT[D] == "comma") { jerr("two values with no comma"); return }
  if (D == 0 && TOP) { if (!multi) { jerr("more than one value"); return } }
  printf "%s\t%s\n", here(), v
  after()
}
function after() {   # a value just ended
  if (D == 0) { TOP = 1; NDOC++; return }
  WANT[D] = "comma"
}
function open_(t,   p) {
  if (D > 0 && T[D] == "o" && WANT[D] != "value") { jerr("a container where a key belongs"); return }
  if (D > 0 && T[D] == "a" && WANT[D] == "comma") { jerr("two values with no comma"); return }
  if (D == 0 && TOP && !multi) { jerr("more than one value"); return }
  p = here(); D++; T[D] = t; P[D] = p; I[D] = 0; K[D] = ""
  WANT[D] = (t == "o") ? "key" : "first"; SEEN[D] = 0
}
function close_(t) {
  if (D == 0 || T[D] != t) { jerr("an unbalanced " (t == "o" ? "}" : "]")); return }
  if ((T[D] == "o" && WANT[D] == "key" && SEEN[D]) || (T[D] == "a" && WANT[D] == "next")) jerr("a trailing comma")
  if (T[D] == "o" && (WANT[D] == "colon" || WANT[D] == "value")) jerr("a key with no value")
  D--
  after()
}
function bare(   w) {
  if (W == "") return
  w = W; W = ""
  if (w !~ /^(true|false|null|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?)$/) { jerr("an unknown word " substr(w, 1, 20)); return }
  value(w)
}
function outside(s,   n, k, c) {
  n = length(s)
  for (k = 1; k <= n; k++) {
    c = substr(s, k, 1)
    if (c == " " || c == "\t" || c == "\n" || c == "\r") { bare(); continue }
    if (c == "{" || c == "[") { bare(); open_(c == "{" ? "o" : "a"); continue }
    if (c == "}" || c == "]") { bare(); close_(c == "}" ? "o" : "a"); continue }
    if (c == ":") {
      bare()
      if (D == 0 || T[D] != "o" || WANT[D] != "colon") jerr("a colon out of place"); else WANT[D] = "value"
      continue
    }
    if (c == ",") {
      bare()
      if (D == 0 || WANT[D] != "comma") { jerr("a comma out of place"); continue }
      if (T[D] == "a") { I[D]++; WANT[D] = "next" } else { WANT[D] = "key"; SEEN[D] = 1 }
      continue
    }
    W = W c
  }
}
function unescape(s,   out, k, c, n) {
  if (index(s, "\\") == 0) return s
  out = ""; n = length(s)
  for (k = 1; k <= n; k++) {
    c = substr(s, k, 1)
    if (c != "\\") { out = out c; continue }
    c = substr(s, ++k, 1)
    if (c == "n" || c == "r" || c == "t") out = out " "
    else if (c == "u") out = out "\\u"
    else out = out c
  }
  return out
}
function string(s) {
  bare(); s = unescape(s)
  if (D > 0 && T[D] == "o" && WANT[D] == "key") { K[D] = s; WANT[D] = "colon"; return }
  gsub(/\t/, " ", s)
  value(s)
}
BEGIN { D = 0; NDOC = 0; TOP = 0; ERR = 0; INSTR = 0; BUF = ""; W = "" }
{
  if (!INSTR) { outside($0); INSTR = 1; LAST = "out"; next }
  LAST = "str"
  # inside a string: a record ending in an odd number of backslashes ended on an escaped quote
  t = $0; nb = 0
  while (substr(t, length(t) - nb, 1) == "\\" && nb < length(t)) nb++
  if (nb % 2 == 1) { BUF = BUF $0 "\""; next }
  string(BUF $0); BUF = ""; INSTR = 0
}
END {
  if (LAST == "str" || BUF != "") jerr("an unterminated string")
  bare()
  if (D != 0) jerr("an unclosed " (T[D] == "o" ? "object" : "array"))
  if (!TOP && !ERR) jerr("no JSON value")
  exit ERR
}
