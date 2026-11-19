# adr-tool.awk — after adr-common.awk, reads ADR files and prints, by MODE:
#   status  its status class (accepted, proposed, rejected, deprecated, superseded or empty)
#   body    the ADR without the lines that carry its status, trailing spaces and blank
#           lines dropped, so two versions compare equal when only the status changed
#   list    "<number><TAB><status class>" for every ADR given (check-decision-drift.sh)
# Portable: POSIX awk (BWK, mawk, gawk).

FNR == 1 { if (NR > 1) done(); adr_begin(); NAME = FILENAME }
{ adr_line($0); L[FNR] = $0; LAST = FNR }
END { if (NR > 0) done() }
function done(   i, s) {
  if (MODE == "status") print adr_class(A_STATUS)
  else if (MODE == "list") { if (adr_isfile(NAME)) printf "%d\t%s\n", adr_num(NAME), adr_class(A_STATUS) }
  else if (MODE == "body") for (i = 1; i <= LAST; i++) { if (i in A_SKIP) continue; s = L[i]; sub(/\r$/, "", s); sub(/[ \t]+$/, "", s); if (s != "") print s }
  delete L
}
