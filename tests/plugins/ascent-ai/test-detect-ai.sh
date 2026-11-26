#!/usr/bin/env bash
# Behavior test for plugins/ascent-ai/scripts/detect-ai.sh and the severity
# scaling and tier reading of scripts/lib/common.awk (ADR-031).
#
# Fixtures: py-agent (Python, OpenAI SDK), ts-workflow (TypeScript, Anthropic
# SDK), rag-only (a vector store and no model: not an AI application),
# no-ai, and multi-app (two applications in one repository). Covers the
# signals, the folders that are never read, the implicit application, code
# outside every declared application (orphans), nested roots (the deepest wins)
# and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-detect-ai: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-detect-ai
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/detect-ai.sh"
COMMON="$PLUGIN/scripts/lib/common.awk"
need "$CHECK" "$COMMON" "$FIX/py-agent/agent/main.py" "$FIX/multi-app/services/support/app.py"
line() { printf '%s' "$1" | tr '|' '\t'; }   # a|b|c -> a<TAB>b<TAB>c
awk_eval() {  # PROGRAM — runs an awk program with common.awk loaded; sets OUT
  printf '%s\n' "$1" > "$WORK/prog.awk"
  OUT=$(PATH="$SHIM:$PATH" awk -f "$COMMON" -f "$WORK/prog.awk" </dev/null 2>&1)
}
matrix() {
  mk py-agent; run py-agent .; expect_rc py-agent 0
  has py-agent "$(line 'ai|agent/main.py|sdk:openai')"; has py-agent "$(line 'ai|pyproject.toml|sdk:openai')"
  has py-agent "$(line 'app|py-agent|.')"; lacks py-agent 'orphan'
  lacks py-agent "$(line 'ai|agent/config.py')"

  mk ts-workflow; run ts-workflow; expect_rc ts-workflow 0
  has ts-workflow "$(line 'ai|src/index.ts|sdk:@anthropic-ai/sdk')"; has ts-workflow "$(line 'ai|package.json|sdk:@anthropic-ai/sdk')"
  has ts-workflow "$(line 'app|ts-workflow|.')"

  # test data is not an application (trial: this repository's own fixtures made it one): fixtures/, testdata/ and
  # __fixtures__/ are skipped at any depth, while the project's own tests/evals still counts
  mk fixtures-only no-ai; mkdir -p "$WORK/fixtures-only/tests/fixtures/bot/prompts" "$WORK/fixtures-only/pkg/testdata/tests/evals" "$WORK/fixtures-only/src/__fixtures__"
  printf 'import openai\n' > "$WORK/fixtures-only/tests/fixtures/bot/app.py"; printf 'import anthropic\n' > "$WORK/fixtures-only/src/__fixtures__/m.py"
  run fixtures-only .; expect_rc fixtures-only 0; lacks fixtures-only "$(line 'ai|')"; lacks fixtures-only "$(line 'app|')"
  mkdir -p "$WORK/fixtures-only/tests/evals"; run fixtures-only .; has fixtures-only "$(line 'ai|tests/evals|evals-dir')"; lacks fixtures-only 'testdata'
  mk rag-only; run rag-only .; expect_rc rag-only 0
  has rag-only "$(line 'retrieval|app.py|chromadb')"; has rag-only "$(line 'retrieval|requirements.txt|chromadb')"
  lacks rag-only "$(line 'ai|')"; lacks rag-only "$(line 'app|')"
  # a declared ai: section makes it one
  mk rag-optin rag-only; mkdir -p "$WORK/rag-optin/.ascent"; printf 'ai:\n  applications:\n  - name: handbook\n    root: .\n' > "$WORK/rag-optin/.ascent/contract.yml"
  run rag-optin .; has rag-optin "$(line 'ai|.ascent/contract.yml|contract')"; has rag-optin "$(line 'app|rag-optin|.')"

  mk no-ai; run no-ai .; expect_rc no-ai 0; if [ -z "$OUT" ]; then ok; else bad "no-ai: output should be empty: $(printf '%s' "$OUT" | head -2 | tr '\n' ';')"; fi

  # a prompts folder and an evals folder are signals
  mk dirs no-ai; mkdir -p "$WORK/dirs/prompts" "$WORK/dirs/tests/evals"; : > "$WORK/dirs/prompts/reply.txt"
  run dirs .; has dirs "$(line 'ai|prompts|prompts-dir')"; has dirs "$(line 'ai|tests/evals|evals-dir')"
  # a prompts folder of code (inquirer and enquirer question modules) is not a model's prompts
  mk cli-prompts no-ai; mkdir -p "$WORK/cli-prompts/src/prompts/init"
  printf 'module.exports = [];\n' > "$WORK/cli-prompts/src/prompts/questions.js"; printf 'export const q = 1;\n' > "$WORK/cli-prompts/src/prompts/init/index.ts"
  run cli-prompts .; lacks cli-prompts "$(line 'ai|')"; lacks cli-prompts "$(line 'app|')"
  printf 'You are a helpful assistant.\n' > "$WORK/cli-prompts/src/prompts/init/system.md"; run cli-prompts .; has cli-prompts "$(line 'ai|src/prompts|prompts-dir')"

  # other SDKs, Python and TypeScript, imports and manifests
  mk sdks no-ai; mkdir -p "$WORK/sdks/py" "$WORK/sdks/ts"
  printf 'from langchain_openai import ChatOpenAI\n' > "$WORK/sdks/py/a.py"
  printf 'from google import genai\n' > "$WORK/sdks/py/b.py"
  printf 'import boto3\nbr = boto3.client("bedrock-runtime")\n' > "$WORK/sdks/py/c.py"
  printf 'from llama_index.core import VectorStoreIndex\n' > "$WORK/sdks/py/d.py"
  printf 'import litellm\n' > "$WORK/sdks/py/e.py"
  printf 'from langgraph.graph import StateGraph\n' > "$WORK/sdks/py/f.py"
  printf '# import openai\n  # br = boto3.client("bedrock-runtime")\nx = "import anthropic"\n' > "$WORK/sdks/py/g.py"
  # the service name alone is not a model call (trial: a docs-tool map of service names); a client split over lines is
  printf 'SERVICES = {\n    "bedrock-runtime": "sap-abap/services/bdr",\n}\n' > "$WORK/sdks/py/h.py"
  printf 'import boto3\nbr = boto3.client(\n    "bedrock-runtime",\n    region_name="us-east-1",\n)\n' > "$WORK/sdks/py/i.py"
  printf 'session.client("bedrock-runtime")\n' > "$WORK/sdks/py/j.py"
  printf 'import { generateText } from "ai";\n' > "$WORK/sdks/ts/a.ts"
  printf "const { query } = require('@anthropic-ai/claude-agent-sdk');\n" > "$WORK/sdks/ts/b.js"
  printf 'import { ChatOpenAI } from "@langchain/openai";\n' > "$WORK/sdks/ts/c.mjs"
  printf 'import OpenAI from "openai";\n' > "$WORK/sdks/ts/d.tsx"
  printf 'import "@anthropic-ai/sdk/shims/node";\n// const c = require("openai");\n' > "$WORK/sdks/ts/e.ts"
  printf 'anthropic>=0.40\nLlama_Index==0.11\n' > "$WORK/sdks/requirements-ai.txt"
  run sdks .
  has sdks "$(line 'ai|py/a.py|sdk:langchain')"; has sdks "$(line 'ai|py/b.py|sdk:google-genai')"; has sdks "$(line 'ai|py/c.py|sdk:bedrock-runtime')"
  has sdks "$(line 'ai|py/d.py|sdk:llama-index')"; has sdks "$(line 'ai|py/e.py|sdk:litellm')"; has sdks "$(line 'ai|py/f.py|sdk:langgraph')"
  lacks sdks "$(line 'ai|py/g.py')"; lacks sdks "$(line 'ai|py/h.py')"
  has sdks "$(line 'ai|py/i.py|sdk:bedrock-runtime')"; has sdks "$(line 'ai|py/j.py|sdk:bedrock-runtime')"
  has sdks "$(line 'ai|ts/a.ts|sdk:ai')"; has sdks "$(line 'ai|ts/b.js|sdk:@anthropic-ai/claude-agent-sdk')"
  has sdks "$(line 'ai|ts/c.mjs|sdk:@langchain')"; has sdks "$(line 'ai|ts/d.tsx|sdk:openai')"
  has sdks "$(line 'ai|ts/e.ts|sdk:@anthropic-ai/sdk')"; lacks sdks "$(line 'ai|ts/e.ts|sdk:openai')"
  has sdks "$(line 'ai|requirements-ai.txt|sdk:anthropic')"; has sdks "$(line 'ai|requirements-ai.txt|sdk:llama-index')"

  # a gateway: a LiteLLM proxy configuration, the Portkey SDK
  mk gw py-agent; mkdir -p "$WORK/gw/deploy"; printf 'model_list:\n  - model_name: support\n' > "$WORK/gw/deploy/litellm.yaml"
  printf 'from portkey_ai import Portkey\n' > "$WORK/gw/agent/gw.py"
  run gw .; has gw "$(line 'gateway|deploy/litellm.yaml|litellm')"; has gw "$(line 'gateway|agent/gw.py|portkey')"

  # dependency and build folders are never read
  mk skip py-agent; mkdir -p "$WORK/skip/node_modules/openai" "$WORK/skip/.venv/lib" "$WORK/skip/venv" "$WORK/skip/dist" "$WORK/skip/build"
  for d in node_modules/openai/index.js .venv/lib/x.py venv/y.py dist/z.js build/w.py; do printf 'import openai\nimport OpenAI from "openai";\n' > "$WORK/skip/$d"; done
  run skip .; lacks skip node_modules; lacks skip .venv; lacks skip "$(line 'ai|venv')"; lacks skip dist/; lacks skip build/

  # spaces in paths
  mk spaced no-ai; mkdir -p "$WORK/spaced/my app"; printf 'import anthropic\n' > "$WORK/spaced/my app/bot.py"
  run spaced .; has spaced "$(line 'ai|my app/bot.py|sdk:anthropic')"

  # declared applications: orphans, and the deepest root wins
  mk orphan multi-app; run orphan --app support=services/support .; expect_rc orphan 0
  has orphan "$(line 'app|support|services/support')"; has orphan "$(line 'orphan|services/screening/app.py')"
  has orphan "$(line 'ai|services/support/app.py|sdk:anthropic|support')"; lacks orphan "$(line 'app|multi-app')"
  mk both multi-app; run both --app support=services/support/ --app screening=./services/screening .; lacks both orphan
  has both "$(line 'ai|services/screening/app.py|sdk:openai|screening')"
  mk nested multi-app; run nested --app all=services --app support=services/support .
  lacks nested orphan; count nested 'services/support/app.py' 1
  has nested "$(line 'ai|services/support/app.py|sdk:anthropic|support')"; has nested "$(line 'ai|services/screening/app.py|sdk:openai|all')"
  mk nested-rev multi-app; run nested-rev --app support=services/support --app all=services .
  has nested-rev "$(line 'ai|services/support/app.py|sdk:anthropic|support')"
  mk prefix multi-app; run prefix --app sup=services/sup .; has prefix "$(line 'orphan|services/support/app.py')"
  mk root multi-app; run root --app everything=. .; lacks root orphan; has root "$(line 'ai|services/support/app.py|sdk:anthropic|everything')"
  # the implicit application's name: the origin remote's repository name, else the folder's; never a name the checkers refuse
  mk next.js py-agent; run next.js .; has next.js "$(line 'app|next-js|.')"
  mk support-bot-wip py-agent; G support-bot-wip init -q; G support-bot-wip remote add origin https://github.com/acme/support-bot.git
  run support-bot-wip .; has support-bot-wip "$(line 'app|support-bot|.')"
  G support-bot-wip remote set-url origin git@github.com:acme/support.bot.git; run support-bot-wip .; has support-bot-wip "$(line 'app|support-bot|.')"
  mk _ py-agent; run _ .; has _ "$(line 'app|app|.')"

  # a src layout: the manifest, the tests, the evals and the prompts at the top belong to the one application below them;
  # source code outside every root is still an orphan, and what several applications share is no one's orphan
  mk srclayout no-ai; mkdir -p "$WORK/srclayout/src/helpdesk" "$WORK/srclayout/tests/evals" "$WORK/srclayout/prompts" "$WORK/srclayout/tools"
  printf 'import openai\n' > "$WORK/srclayout/src/helpdesk/bot.py"; printf 'import openai\n' > "$WORK/srclayout/tests/test_bot.py"
  printf '[project]\ndependencies = ["openai>=1"]\n' > "$WORK/srclayout/pyproject.toml"; : > "$WORK/srclayout/prompts/reply.txt"
  printf 'import openai\n' > "$WORK/srclayout/test_smoke.py"
  run srclayout --app helpdesk=src/helpdesk .; lacks srclayout orphan
  has srclayout "$(line 'ai|test_smoke.py|sdk:openai|helpdesk')"
  printf 'import openai\n' > "$WORK/srclayout/tests/helpers.py"; run srclayout --app helpdesk=src/helpdesk .; has srclayout "$(line 'ai|tests/helpers.py|sdk:openai|helpdesk')"
  has srclayout "$(line 'ai|tests/test_bot.py|sdk:openai|helpdesk')"; has srclayout "$(line 'ai|pyproject.toml|sdk:openai|helpdesk')"
  has srclayout "$(line 'ai|prompts|prompts-dir|helpdesk')"; has srclayout "$(line 'ai|tests/evals|evals-dir|helpdesk')"
  printf 'import anthropic\n' > "$WORK/srclayout/tools/summarize.py"; run srclayout --app helpdesk=src/helpdesk .; has srclayout "$(line 'orphan|tools/summarize.py')"
  mkdir -p "$WORK/srclayout/src/billing"; printf 'import openai\n' > "$WORK/srclayout/src/billing/b.py"
  run srclayout --app helpdesk=src/helpdesk --app billing=src/billing .; lacks srclayout "$(line 'orphan|tests')"; lacks srclayout "$(line 'orphan|pyproject.toml')"
  has srclayout "$(line 'ai|tests/test_bot.py|sdk:openai')"; lacks srclayout "$(line 'ai|tests/test_bot.py|sdk:openai|')"; has srclayout "$(line 'orphan|tools/summarize.py')"

  # bad input
  mk bad multi-app; run bad --app support .; expect_rc bad 2; first bad 'detect-ai: --app: expected NAME=ROOT, got support'
  run bad --app 'my app=services' .; expect_rc bad 2; first bad "detect-ai: --app: the name 'my app' is not letters, digits, - and _"
  run bad --app support=../elsewhere .; expect_rc bad 2; first bad 'detect-ai: --app: the root ../elsewhere is not inside the repository'
  run bad --frobnicate .; expect_rc bad 2; first bad 'detect-ai: --frobnicate: unknown option'
  run bad nowhere; expect_rc bad 2; first bad 'detect-ai: nowhere: not a directory'
  run bad --help; expect_rc bad 0; has bad 'Usage: detect-ai.sh [--app NAME=ROOT]... [REPO]'

  # common.awk: severity scaling and the tier record
  awk_eval 'BEGIN { print scale("High", 3, 0), scale("High", 2, 0), scale("High", 1, 0), scale("Medium", 1, 0), scale("Critical", 1, 1), scale("Critical", 2, 0), scale("Low", 1, 0), scale("Medium", 2, 0) }'
  if [ "$OUT" = "High Medium Low Low Critical High Low Low" ]; then ok; else bad "common: scale table: $OUT"; fi
  mkdir -p "$WORK/tiers"; cp "$HERE/../ascent-governance/fixtures/ai-tier-good/docs/governance/ai-tier/support-assistant.md" "$WORK/tiers/two.md"
  awk '{ sub(/ \|[^|]*\|$/, ""); printf "%s\r\n", $0 }' "$WORK/tiers/two.md" > "$WORK/tiers/two-crlf.md"   # CRLF, and no closing pipe: the CR ends the value cell
  awk '{ if (index($0, "| tier | 2 |")) print "| tier | 7 |"; else print }' "$WORK/tiers/two.md" > "$WORK/tiers/seven.md"
  awk_eval "BEGIN { print tier_of(\"$WORK/tiers/two.md\"), tier_of(\"$WORK/tiers/two-crlf.md\"), tier_of(\"$WORK/tiers/missing.md\"), tier_of(\"$WORK/tiers/seven.md\"), tier_of(\"\") }"
  if [ "$OUT" = "2 2 3 3 3" ]; then ok; else bad "common: tier_of: $OUT"; fi
  awk_eval 'BEGIN { s = "a\r"; print length(strip_cr(s)), strip_cr("b") }'
  if [ "$OUT" = "1 b" ]; then ok; else bad "common: strip_cr: $OUT"; fi
}
run_matrix
