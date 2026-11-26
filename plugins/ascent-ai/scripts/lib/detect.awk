# detect.awk — the AI signals of each file detect-ai.sh gives it.
#
# Usage: awk -f detect.awk FILE...   (paths relative to the repository, "./" allowed)
#
# Prints "<kind><TAB><path><TAB><signal>" once for each signal of each file:
#   ai         sdk:<name>   a model SDK imported (Python, TypeScript, JavaScript)
#                           or listed in a manifest (pyproject.toml,
#                           requirements*.txt, package.json)
#   retrieval  <package>    a vector store, the same ways
#   gateway    litellm      a LiteLLM proxy configuration (a YAML file whose
#                           top-level model_list key is set)
#   gateway    portkey      the Portkey SDK
# Comment lines are not read. The SDK list is ADR-031's (DESIGN §3.6).
#
# Portable: POSIX awk (BWK awk, mawk, gawk); no regex intervals.

function out(kind, sig) { if (!((kind, sig) in SEEN)) { SEEN[kind, sig] = 1; printf "%s\t%s\t%s\n", kind, PATHN, sig } }
# a Python module path's signal
function pymod(m,   top) {
  top = m; sub(/\..*$/, "", top)
  if (top == "openai" || top == "anthropic" || top == "langgraph" || top == "litellm") out("ai", "sdk:" top)
  else if (top ~ /^langchain/) out("ai", "sdk:langchain")
  else if (top ~ /^llama_index/) out("ai", "sdk:llama-index")
  else if (m == "google.genai" || index(m, "google.genai.") == 1) out("ai", "sdk:google-genai")
  else if (top == "chromadb" || top == "lancedb" || top == "pgvector" || top == "pinecone" || top == "weaviate" || top == "faiss") out("retrieval", top)
  else if (top == "qdrant_client") out("retrieval", "qdrant-client")
  else if (top == "portkey_ai") out("gateway", "portkey")
}
# a Python distribution name's signal (pyproject.toml, requirements*.txt)
function pydist(d) {
  d = tolower(d); gsub(/_/, "-", d); gsub(/\./, "-", d)
  if (d == "openai" || d == "anthropic" || d == "langgraph" || d == "litellm" || d == "google-genai") out("ai", "sdk:" d)
  else if (d ~ /^langchain/) out("ai", "sdk:langchain")
  else if (d ~ /^llama-index/) out("ai", "sdk:llama-index")
  else if (d == "chromadb" || d == "lancedb" || d == "pgvector" || d == "qdrant-client" || d == "weaviate-client") out("retrieval", d)
  else if (d == "pinecone" || d == "pinecone-client") out("retrieval", "pinecone")
  else if (d ~ /^faiss(-cpu|-gpu)?$/) out("retrieval", "faiss")
  else if (d == "portkey-ai") out("gateway", "portkey")
}
# a JavaScript package name's signal (imports, package.json)
function jspkg(p,   n, S) {
  n = split(p, S, "/"); if (substr(p, 1, 1) == "@" && n >= 2) p = S[1] "/" S[2]; else if (n >= 1) p = S[1]   # a subpath import names its package
  if (p == "openai" || p == "@anthropic-ai/sdk" || p == "@anthropic-ai/claude-agent-sdk") out("ai", "sdk:" p)
  else if (index(p, "@langchain/") == 1) out("ai", "sdk:@langchain")
  else if (p == "ai" || index(p, "ai/") == 1 || index(p, "@ai-sdk/") == 1) out("ai", "sdk:ai")
  else if (p == "chromadb" || p == "@lancedb/lancedb" || p == "vectordb" || p == "@pinecone-database/pinecone" || p == "@qdrant/js-client-rest" || p == "weaviate-client" || p == "weaviate-ts-client") out("retrieval", p)
  else if (p == "portkey-ai") out("gateway", "portkey")
}
function quoted(s,   q, a, b) {   # the first quoted string in s
  a = match(s, /["'][^"']*["']/)
  if (!a) return ""
  return substr(s, RSTART + 1, RLENGTH - 2)
}

FNR == 1 {
  split("", SEEN); PATHN = FILENAME; sub(/^\.\//, "", PATHN)
  base = PATHN; sub(/^.*\//, "", base)
  kind = ""
  if (base ~ /\.py$/) kind = "py"
  else if (base ~ /\.(ts|tsx|js|jsx|mjs|cjs)$/) kind = "js"
  else if (base == "pyproject.toml") kind = "pyproject"
  else if (base ~ /^requirements.*\.txt$/) kind = "req"
  else if (base == "package.json") kind = "pkg"
  else if (base ~ /\.ya?ml$/) kind = "yaml"
  indeps = 0; pdeps = 0; boto = 0
}
{ line = $0; sub(/\r$/, "", line) }

kind == "py" {
  if (line ~ /^[ \t]*#/) next
  if (match(line, /^[ \t]*import[ \t]+[A-Za-z_][A-Za-z0-9_.]*/)) { m = substr(line, RSTART, RLENGTH); sub(/^[ \t]*import[ \t]+/, "", m); pymod(m) }
  if (match(line, /^[ \t]*from[ \t]+[A-Za-z_][A-Za-z0-9_.]*[ \t]+import/)) {
    m = substr(line, RSTART, RLENGTH); sub(/^[ \t]*from[ \t]+/, "", m); sub(/[ \t]+import$/, "", m)
    if (m == "google" && line ~ /import[ \t(]+([^#]*[ ,(])?genai([ ,)]|$)/) pymod("google.genai"); else pymod(m)
  }
  if (line ~ /^[ \t]*(import|from)[ \t]+(boto3|aioboto3|botocore)([ \t.,]|$)/) boto = 1
  # the service name is a model call on a client( line, or in a file that imported boto3;
  # alone (a map of service names) it is not
  if ((index(line, "\"bedrock-runtime\"") || index(line, "'bedrock-runtime'")) && (boto || index(line, "client("))) out("ai", "sdk:bedrock-runtime")
  next
}
kind == "js" {
  if (line ~ /^[ \t]*(\/\/|\*|\/\*)/) next
  s = line
  while (match(s, /(from|import|require\()[ \t]*\(?[ \t]*["'][^"']+["']/)) {
    seg = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
    jspkg(quoted(seg))
  }
  next
}
kind == "req" {
  if (line ~ /^[ \t]*(#|-|$)/) next
  d = line; sub(/^[ \t]+/, "", d); sub(/[ \t;<>=!~\[@].*$/, "", d); pydist(d)
  next
}
kind == "pyproject" {
  if (line ~ /^[ \t]*#/) next
  if (line ~ /^[ \t]*\[/) { pdeps = (line ~ /dependencies\]/) ? 1 : 0; indeps = 0; next }
  if (line ~ /^[ \t]*[A-Za-z_-]*dependencies[ \t]*=[ \t]*\[/) { indeps = 1; s = line; sub(/^[^\[]*\[/, "", s) } else s = line
  if (indeps) {
    while (match(s, /["'][A-Za-z0-9_.-]+/)) { d = substr(s, RSTART + 1, RLENGTH - 1); s = substr(s, RSTART + RLENGTH); sub(/^[^"']*["']/, "", s); pydist(d) }
    if (line ~ /\]/) indeps = 0
  } else if (pdeps && match(line, /^[ \t]*[A-Za-z0-9_.-]+[ \t]*=/)) { d = substr(line, RSTART, RLENGTH); sub(/[ \t]*=$/, "", d); sub(/^[ \t]+/, "", d); if (d != "python") pydist(d) }
  next
}
kind == "pkg" {
  if (line ~ /"[A-Za-z]*[dD]ependencies"[ \t]*:[ \t]*\{/) { indeps = 1; s = line; sub(/^[^{]*\{/, "", s) } else s = line
  if (indeps) {
    while (match(s, /"[^"]+"[ \t]*:/)) { p = substr(s, RSTART + 1, RLENGTH - 1); sub(/"[ \t]*:$/, "", p); s = substr(s, RSTART + RLENGTH); jspkg(p) }
    if (s ~ /\}/ || (line ~ /\}/ && line !~ /\{/)) indeps = 0
  }
  next
}
kind == "yaml" {
  if (line ~ /^model_list:/) out("gateway", "litellm")
  next
}
