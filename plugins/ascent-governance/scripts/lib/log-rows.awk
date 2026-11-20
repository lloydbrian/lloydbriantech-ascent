# log-rows.awk — the rows of a review log.
#
# The review log is a Markdown file. The first table whose header is
#
#   | Date | Review | Commit | Rating | High | Medium | Low | Open High rules | Asked by |
#
# starts it, and every table row below that header is one of its rows: a blank
# line or a sentence between two rows does not end the table, so a row is never
# dropped in silence (a row of another shape is reported by audit.awk as one
# that cannot be read). A rule line and a repeat of the header are not rows.
# Prints
#   H<TAB>line                          once, for the header
#   R<TAB>line<TAB>cells<TAB>cell...    for each row, cells trimmed
# so two versions of the log can be compared row by row whatever their spacing.
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

{
  line = $0; sub(/\r$/, "", line)
  gsub(/\t/, " ", line)                    # a tab inside a cell would read as the end of the cell
  if (line !~ /^ *\|/) next
  line = trim(line); sub(/^\|/, "", line); sub(/\|$/, "", line)
  n = split(line, c, "|")
  for (i = 1; i <= n; i++) c[i] = trim(c[i])
  head = 0
  if (n == 9 && tolower(c[1]) == "date" && tolower(c[2]) == "review" && tolower(c[3]) == "commit" && tolower(c[4]) == "rating" \
      && tolower(c[5]) == "high" && tolower(c[6]) == "medium" && tolower(c[7]) == "low" && tolower(c[8]) == "open high rules" && tolower(c[9]) == "asked by") head = 1
  if (!found) { if (head) { found = 1; print "H\t" FNR }; next }
  if (head) next
  rule = 1
  for (i = 1; i <= n; i++) if (c[i] !~ /^:?-+:?$/) rule = 0
  if (rule) next
  printf "R\t%d\t%d", FNR, n
  for (i = 1; i <= n; i++) printf "\t%s", c[i]
  printf "\n"
}
