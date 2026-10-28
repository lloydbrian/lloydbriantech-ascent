# json.awk — a streaming JSON reader for the ascent-security scripts. Load it with
# -f before the program that uses it. For every scalar it calls
#   on_json(path, value, line)
# which that program defines. path is the key and index segments joined by "\034"
# (packages\034node_modules/lodash\034version); value is the decoded string or the
# raw number, true, false or null; line is the line the value starts on. Containers
# are not reported, except that an empty object or array reports value "" with
# kind "{}" or "[]" in JK (the kind of the last value: "s", "n", "{}", "[]").
# Call json_reset() at the first line of each file (FNR == 1) and json_feed(line)
# for every line. Strings never span lines in JSON, so the reader is line-based.
# JSONC comments (// to the end of a line, /* */ on one line) are skipped.
# Portable: POSIX awk (BWK, mawk, gawk).
function json_reset() { JSP = 0; JEXP = 1; JBAD = 0; split("", JST); split("", JKEY); split("", JIX); split("", JEK); split("", JEMPTY); split("", JLINE) }
function json_path(   k, p) {
  p = ""
  for (k = 1; k <= JSP; k++) p = p (k > 1 ? "\034" : "") (JST[k] == "o" ? JKEY[k] : JIX[k])
  return p
}
function json_unq(s,   out, i, c, n, h) {
  s = substr(s, 2, length(s) - 2)
  if (index(s, "\\") == 0) return s
  out = ""
  while ((i = index(s, "\\")) > 0) {
    out = out substr(s, 1, i - 1); c = substr(s, i + 1, 1)
    if (c == "u") {
      h = tolower(substr(s, i + 2, 4))
      n = json_hex(h)
      out = out (n >= 32 && n < 127 ? sprintf("%c", n) : "?"); s = substr(s, i + 6)
      continue
    }
    if (c == "n" || c == "t" || c == "r" || c == "b" || c == "f") out = out " "
    else out = out c
    s = substr(s, i + 2)
  }
  return out s
}
function json_hex(h,   i, n, d) {
  n = 0
  for (i = 1; i <= length(h); i++) { d = index("0123456789abcdef", substr(h, i, 1)); if (d == 0) return -1; n = n * 16 + d - 1 }
  return n
}
# A value (scalar or container start) arrives at the current position.
function json_value(tok, kind, line) {
  if (JSP > 0 && JST[JSP] == "o" && JEK[JSP]) { JBAD = 1; return }
  if (kind == "{" || kind == "[") {
    JSP++; JST[JSP] = (kind == "{" ? "o" : "a"); JIX[JSP] = 0; JKEY[JSP] = ""; JEK[JSP] = (kind == "{"); JEMPTY[JSP] = 1; JLINE[JSP] = line
    if (JSP > 1) JEMPTY[JSP - 1] = 0
    return
  }
  if (JSP > 0) JEMPTY[JSP] = 0
  JK = kind
  on_json(json_path(), tok, line)
}
function json_close(line,   p) {
  if (JSP == 0) { JBAD = 1; return }
  if (JEMPTY[JSP]) { JK = (JST[JSP] == "o" ? "{}" : "[]"); JSP--; p = json_path(); JSP++; on_json(p, "", JLINE[JSP]) }
  JSP--
}
function json_feed(s, line,   t, c) {
  while (s != "") {
    if (match(s, /^[ \t\r]+/)) { s = substr(s, RLENGTH + 1); continue }
    c = substr(s, 1, 1)
    if (c == "/" && substr(s, 2, 1) == "/") return
    if (c == "/" && substr(s, 2, 1) == "*") { if ((t = index(s, "*/")) > 0) { s = substr(s, t + 2); continue } return }
    if (c == "\"") {
      if (!match(s, /^"([^"\\]|\\.)*"/)) { JBAD = 1; return }
      t = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1)
      if (JSP > 0 && JST[JSP] == "o" && JEK[JSP]) { JKEY[JSP] = json_unq(t); JEK[JSP] = 0; continue }
      json_value(json_unq(t), "s", line); continue
    }
    if (c == "{" || c == "[") { json_value("", c, line); s = substr(s, 2); continue }
    if (c == "}" || c == "]") { json_close(line); s = substr(s, 2); continue }
    if (c == ":") { s = substr(s, 2); continue }
    if (c == ",") {
      if (JSP > 0) { if (JST[JSP] == "a") JIX[JSP]++; else JEK[JSP] = 1 }
      s = substr(s, 2); continue
    }
    if (match(s, /^-?[0-9][0-9.eE+-]*/) || match(s, /^(true|false|null)/)) {
      t = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1)
      json_value(t, "n", line); continue
    }
    JBAD = 1; return
  }
}
# Path helpers: segment N of a path (1-based), and the number of segments.
function jseg(p, n,   a, m) { m = split(p, a, "\034"); return (n <= m ? a[n] : "") }
function jlen(p,   a) { return split(p, a, "\034") }
