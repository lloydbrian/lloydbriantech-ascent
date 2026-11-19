# doc-set.sh — sourced by check-docs.sh and check-doc-drift.sh, from the repository
# root, with T (a scratch folder), NOGIT, PATHS and EXCL set. doc_files writes every
# repository path to $T/files and the Markdown ones to $T/md; doc_set writes the
# documents checked to $T/set: Markdown under PATHS, less EXCL, ADR folders and
# ADR-NNN files (ascent-adr's) and the operations manuals, runbooks and drill records
# (ascent-ops's defaults).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

doc_files() {
  if [ -z "$NOGIT" ]; then git -c core.quotePath=false ls-files --cached --others --exclude-standard -- . > "$T/files"
  else find . -type f ! -path './.git/*' ! -path '*/node_modules/*' | sed 's|^\./||' > "$T/files"; fi
  grep -iE '\.md$' "$T/files" | grep -vE '(^|/)(node_modules|vendor|\.git)/' > "$T/md" || true
}
doc_set() {
  local p x
  : > "$T/set.all"
  for p in "${PATHS[@]}"; do
    p="${p%/}"; awk -v p="$p" '$0 == p || index($0, p "/") == 1' "$T/md" >> "$T/set.all"
  done
  LC_ALL=C sort -u "$T/set.all" \
    | grep -vE '(^|/)(adr|adrs|decisions|DECISIONS)/|(^|/)[Aa][Dd][Rr]-[0-9]+[-_][^/]*\.md$|^docs/operations/(MAINTENANCE-AND-OPERATIONS|TROUBLESHOOTING)\.md$|^docs/operations/(runbooks|drills)/' > "$T/set" || true
  for x in ${EXCL[@]+"${EXCL[@]}"}; do
    x="${x%/}"; awk -v p="$x" '!($0 == p || index($0, p "/") == 1)' "$T/set" > "$T/set.x"; mv "$T/set.x" "$T/set"
  done
}
