# memory-entries.awk — prints every entry of a working-memory file as
# "<section><TAB><entry>", one per line: the "- " lines under "## Decisions",
# "## Patterns adopted" and "## Patterns rejected", trailing spaces dropped. Used by
# check-session.sh to compare versions of the file (SES-S3) and by check-session.awk.
# Portable: POSIX awk (BWK, mawk, gawk).

{ sub(/\r$/, "") }
/^[ \t]*(```|~~~)/ { fence = !fence; next }
fence { next }
/^## / { h = tolower($0); sub(/^## +/, "", h); sub(/[ \t]+$/, "", h); sec = (h == "decisions" || h == "patterns adopted" || h == "patterns rejected") ? h : ""; next }
/^# / { sec = ""; next }
sec != "" && /^[-*] / { e = $0; sub(/^[-*] +/, "", e); sub(/[ \t]+$/, "", e); print sec "\t" e }
