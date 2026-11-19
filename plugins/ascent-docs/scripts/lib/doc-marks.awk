# doc-marks.awk — prints "<file><TAB><line>" for every stale marker in the prose of
# the files it reads: TODO, TBD, FIXME, "coming soon", a "[STUB" label, or the
# doc-stub marker (XXX is left out: it is a common placeholder, as in ADR-XXX).
# Code fences and inline code are skipped. check-docs.sh dates each
# line with git blame for DOC-L3. Load md-common.awk first.
# Portable: POSIX awk (BWK, mawk, gawk), run with LC_ALL=C.

{
  if (!md_line()) next
  s = md_nocode($0)
  if (s ~ /(^|[^A-Za-z0-9_])(TODO|TBD|FIXME)([^A-Za-z0-9_]|$)/ || tolower(s) ~ /coming soon/ || index(s, "[STUB") || index(s, "<!-- doc-stub:"))
    print FILENAME "\t" FNR
}
