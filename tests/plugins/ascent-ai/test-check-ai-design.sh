#!/usr/bin/env bash
# Behavior test for plugins/ascent-ai/scripts/check-ai-design: an AI
# application's declarations against its code (AI-V, AI-M, AI-A, AI-P, AI-K,
# AI-F; ADR-031).
#
# Good fixtures: py-agent (an agent with two tools, one irreversible, tier 3)
# and ts-workflow (a fixed workflow with no tools, tier 2). Each rule then gets
# negative controls: a copy broken in exactly one way fails that rule and no
# other, at the severity its tier gives it. Also covers every tool and loop
# shape the checker recognises, nested application roots, CRLF records,
# thresholds and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-ai-design: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-check-ai-design
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-ai-design.sh"
need "$CHECK" "$FIX/py-agent/docs/ai/design.md" "$FIX/ts-workflow/docs/ai/design.md"
D=docs/ai/design.md; PT=docs/governance/ai-tier/support-assistant.md; TT=docs/governance/ai-tier/ticket-router.md
PY="--app support-assistant --root . --design $D --tier-record $PT --prompts prompts --golden tests/evals/golden --selection docs/ai/model-bake-off.md --pilot docs/ai/pilot.md"
TS="--app ticket-router --root . --design $D --tier-record $TT"
py() { local n="$1"; shift; run "$n" $PY "$@" .; }   # the py-agent copy NAME, with its usual options
ts() { local n="$1"; shift; run "$n" $TS "$@" .; }
pyedit() { mk "$1" py-agent; edit "$1" "$2" "$(subst "$3" "$4")"; }   # COPY FILE FROM TO
tsedit() { mk "$1" ts-workflow; edit "$1" "$2" "$(subst "$3" "$4")"; }
put() { mkdir -p "$(dirname "$WORK/$1/$2")"; printf '%s\n' "$3" > "$WORK/$1/$2"; }   # COPY FILE TEXT
matrix() {
  mk good py-agent; py good; expect_pass good
  has good 'PASS  AI-A3  [support-assistant] issue_refund needs approval and its limit is enforced in agent/refund.py'
  has good 'N/A   AI-F1  [support-assistant] no fine-tune runbook'; has good 'check-ai-design: [support-assistant] 0 finding(s)'
  mk tsgood ts-workflow; ts tsgood; expect_pass tsgood; has tsgood 'N/A   AI-P1  [ticket-router] no prompts folder given'

  # AI-V: value
  mk v1 py-agent; edit v1 "$D" "$(drop '| baseline value |')"; py v1; expect_only v1 AI-V1 High; has v1 "[support-assistant] $D"
  pyedit v1-date "$D" '| measured on | 2026-10-01 |' '| measured on | last year |'; py v1-date; expect_only v1-date AI-V1 High
  pyedit v1-placeholder "$D" '| target value | 9 |' '| target value | <the value the AI must reach> |'; py v1-placeholder; expect_only v1-placeholder AI-V1 High
  mk v2 py-agent; rm -f "$WORK/v2/docs/ai/pilot.md"; py v2 --env prod --prod-env prod; expect_only v2 AI-V2 Medium; has v2 'docs/ai/pilot.md does not exist'
  pyedit v2-metric docs/ai/pilot.md 'Median minutes to first reply' 'Speed'; py v2-metric --env prod --prod-env prod; expect_only v2-metric AI-V2 Medium
  has v2-metric "does not name the baseline metric (median minutes to first reply)"
  mk v2-beta py-agent; rm -f "$WORK/v2-beta/docs/ai/pilot.md"; py v2-beta --env beta --prod-env prod; expect_pass v2-beta

  # AI-M: models
  pyedit m1 agent/loop.py 'model=MODEL, messages=messages' 'model="gpt-4o", messages=messages'; py m1; expect_only m1 AI-M1 Medium
  has m1 '[support-assistant] agent/loop.py:9'
  mk m1-other py-agent; put m1-other agent/extra.py 'BACKUP = "claude-sonnet-5-5"'; py m1-other; expect_only m1-other AI-M1 Medium
  mk m1-ignored py-agent; put m1-ignored tests/test_router.py 'MODEL = "gpt-4o"'; put m1-ignored docs/notes.md 'We use "gpt-4o".'
  put m1-ignored agent/test_loop.py 'M = "gpt-4o"'; put m1-ignored agent/notes.py '# "gpt-4o" was slower'
  put m1-ignored web/router.test.ts 'const m = "gpt-4o";'; put m1-ignored tests/helpers.py 'MODEL = "gpt-4o"'; py m1-ignored; expect_pass m1-ignored
  # test data, wherever it sits, is not the application (as detect-ai skips it): no model name, tool or call counts
  mk m1-fixtures py-agent; put m1-fixtures src/fixtures/sample.py "$(printf 'MODEL = "gpt-4o"\n@tool\ndef refund_everything(x):\n    return client.chat.completions.create(model=MODEL, messages=[])')"
  put m1-fixtures pkg/testdata/t.py 'r = client.messages.create(model="claude-sonnet-5-5", messages=[])'; put m1-fixtures web/__fixtures__/m.ts 'const m = "gpt-4o";'
  py m1-fixtures; expect_pass m1-fixtures
  mk m2 py-agent; edit m2 "$D" "$(drop '| fallback |')"; py m2; expect_only m2 AI-M2 Medium
  pyedit m2-code agent/config.py 'FALLBACK_MODEL = "gpt-4o"' 'FALLBACK_MODEL = None'; py m2-code; expect_only m2-code AI-M2 Medium
  mk m3 py-agent; run m3 --app support-assistant --root . --design $D --tier-record $PT --prompts prompts --golden tests/evals/golden --pilot docs/ai/pilot.md .
  expect_only m3 AI-M3 Medium; expect_rc m3 0
  mk m3-two ts-workflow; ts m3-two; expect_pass m3-two; has m3-two 'N/A   AI-M3  [ticket-router] tier 2'

  # AI-A: autonomy, tools, limits
  pyedit a1-prompt "$D" '| autonomy | agent |' '| autonomy | prompt |'; py a1-prompt; expect_only a1-prompt AI-A1 High
  has a1-prompt 'agent/main.py:11  tag_ticket is a tool, and the autonomy is prompt'; has a1-prompt 'agent/loop.py:8'
  pyedit a1-loop "$D" '| autonomy | agent |' '| autonomy | workflow |'; py a1-loop; expect_only a1-loop AI-A1 High
  has a1-loop '[support-assistant] agent/loop.py:8  a model-driven loop'
  pyedit a1-none "$D" '| autonomy | agent |' '| autonomy | maybe |'; py a1-none; expect_only a1-none AI-A1 High; has a1-none "the autonomy is 'maybe'"
  mk a1-record py-agent; rm -f "$WORK/a1-record/$D"; py a1-record; expect_only a1-record AI-A1 High; has a1-record 'no AI design record'
  mk a2-undeclared py-agent; edit a2-undeclared "$D" "$(drop '| tag_ticket |')"; py a2-undeclared; expect_only a2-undeclared AI-A2 High
  has a2-undeclared '[support-assistant] agent/main.py:11  tag_ticket is a tool in the code'
  pyedit a2-missing "$D" '| issue_refund | no |' '| close_ticket | yes | no | |\n| issue_refund | no |'; py a2-missing; expect_only a2-missing AI-A2 High; has a2-missing 'close_ticket is declared'
  pyedit a3 "$D" '| issue_refund | no | yes |' '| issue_refund | no | no |'; py a3; expect_only a3 AI-A3 Critical
  pyedit a3-file "$D" '| agent/refund.py |' '| agent/limits.py |'; py a3-file; expect_only a3-file AI-A3 Critical; has a3-file 'which does not exist'
  pyedit a3-names "$D" '| agent/refund.py |' '| agent/config.py |'; py a3-names; expect_only a3-names AI-A3 Critical
  mk a3-tier1 py-agent; edit a3-tier1 "$D" "$(subst '| issue_refund | no | yes |' '| issue_refund | no | no |')"; edit a3-tier1 "$PT" "$(subst '| tier | 3 |' '| tier | 1 |')"
  py a3-tier1; has a3-tier1 'FAIL  AI-A3  Critical'; has a3-tier1 'FAIL  AI-A5  High'; expect_rc a3-tier1 1
  mk a4 py-agent; edit a4 "$D" "$(drop '| max steps |')"; py a4; expect_only a4 AI-A4 High
  mk a4-call py-agent; edit a4-call agent/main.py "$(drop 'max_tokens=800,')"; py a4-call; expect_only a4-call AI-A4 High
  has a4-call '[support-assistant] agent/main.py:21  a model call with no output token limit'
  tsedit a4-ts src/index.ts 'max_tokens: 600, ' ''; ts a4-ts; expect_only a4-ts AI-A4 Medium
  tsedit a4-prompt "$D" '| autonomy | workflow |' '| autonomy | prompt |'; edit a4-prompt "$D" "$(drop '| max steps |')"; ts a4-prompt; expect_pass a4-prompt
  pyedit a5 "$PT" '| tier | 3 |' '| tier | 2 |'; py a5; expect_only a5 AI-A5 High; has a5 'issue_refund is irreversible and the tier record says tier 2'

  # every tool shape the checker reads: an undeclared lookup_order is AI-A2
  for shape in openai-fn openai-fn-ts openai-fn-ts-line openai-agents anthropic langchain structured agent-sdk vercel; do
    mk "tool-$shape" py-agent; f=agent/extra.py
    case "$shape" in
      openai-fn) put "tool-$shape" $f 'X = [{"type": "function",
  "function": {"name": "lookup_order"}}]' ;;
      openai-fn-ts) f=web/tools.ts; put "tool-$shape" $f 'const tools = [{
  type: "function",
  function: { name: "lookup_order", parameters: {} },
}];' ;;
      openai-fn-ts-line) f=web/tools.ts; put "tool-$shape" $f 'const tools = [{ type: "function", function: { name: "lookup_order" } }];' ;;
      openai-agents) put "tool-$shape" $f '@function_tool
def lookup_order(order: str) -> str:
    return order' ;;
      anthropic) put "tool-$shape" $f 'X = [{"name": "lookup_order", "description": "Find an order.",
       "input_schema": {"type": "object"}}]' ;;
      langchain) put "tool-$shape" $f '@tool
def lookup_order(order: str) -> str:
    return order' ;;
      structured) put "tool-$shape" $f 'T = StructuredTool.from_function(func=f, name="lookup_order")' ;;
      agent-sdk) f=web/tools.ts; put "tool-$shape" $f 'export const t = tool("lookup_order", "Find an order", {}, async () => ({ content: [] }));' ;;
      vercel) f=web/tools.ts; put "tool-$shape" $f 'const tools = { lookup_order: tool({ description: "Find an order" }) };' ;;
    esac
    py "tool-$shape"; expect_only "tool-$shape" AI-A2 High; has "tool-$shape" "[support-assistant] $f:"; has "tool-$shape" 'lookup_order is a tool in the code'
  done
  # every loop shape: under a workflow it is AI-A1
  for shape in react executor runner stopwhen; do
    mk "loop-$shape" ts-workflow; f=src/agent.ts
    case "$shape" in
      react) f=src/agent.py; put "loop-$shape" $f 'agent = create_react_agent(model, tools)' ;;
      executor) f=src/agent.py; put "loop-$shape" $f 'runner = AgentExecutor(agent=a, tools=t)' ;;
      runner) f=src/agent.py; put "loop-$shape" $f 'result = Runner.run_sync(agent, "hi")' ;;
      stopwhen) put "loop-$shape" $f 'const r = await generateText({ model, maxTokens: 100, stopWhen: stepCountIs(5) });' ;;
    esac
    ts "loop-$shape"; expect_only "loop-$shape" AI-A1 Medium; has "loop-$shape" "[ticket-router] $f:1  a model-driven loop"
  done
  # a model call of each SDK needs an output token limit
  for shape in anthropic vercel genai converse; do
    mk "call-$shape" ts-workflow; f=src/more.ts
    case "$shape" in
      anthropic) put "call-$shape" $f 'const r = await client.messages.create({ model: MODEL, messages: [] });' ;;
      vercel) put "call-$shape" $f 'const r = await generateText({ model: m, prompt: "x" });' ;;
      genai) f=src/more.py; put "call-$shape" $f 'r = client.models.generate_content(model=MODEL, contents="x")' ;;
      converse) f=src/more.py; put "call-$shape" $f 'r = br.converse(modelId=MODEL, messages=[])' ;;
    esac
    ts "call-$shape"; expect_only "call-$shape" AI-A4 Medium; has "call-$shape" "[ticket-router] $f:1"
  done
  mk call-limited ts-workflow; put call-limited src/more.ts 'const r = await generateText({ model: m, prompt: "x", maxOutputTokens: 200 });'
  put call-limited src/more.py 'r = br.converse(modelId=MODEL, messages=[], inferenceConfig={"maxTokens": 200})'; ts call-limited; expect_pass call-limited
  # a call whose only argument is a variable: a limit set in the lines before it counts (trial: aws-doc-sdk-examples
  # converse.js); one that is not set there, or a call with its own arguments and no limit, is still a finding
  mk call-var ts-workflow; put call-var src/more.js "$(printf 'const request = {\n  messages: [m],\n  inferenceConfig: { maxTokens: 500 },\n};\nconst r = await client.send(new ConverseCommand(request));')"
  put call-var src/more.py "$(printf 'payload = {"model": M, "max_tokens": 300}\nr = client.chat.completions.create(**payload)')"; ts call-var; expect_pass call-var
  mk call-var-none ts-workflow; put call-var-none src/more.py "$(printf 'payload = {"model": M, "messages": []}\nr = client.chat.completions.create(**payload)')"
  ts call-var-none; expect_only call-var-none AI-A4 Medium; has call-var-none '[ticket-router] src/more.py:2'
  mk call-inline ts-workflow; put call-inline src/more.py "$(printf 'cfg = {"max_tokens": 300}\nr = client.chat.completions.create(model=M, messages=[])')"
  ts call-inline; expect_only call-inline AI-A4 Medium; has call-inline '[ticket-router] src/more.py:2'
  mk call-var-far ts-workflow; put call-var-far src/more.py "$(printf 'payload = {"max_tokens": 300}\n'; i=0; while [ $i -lt 41 ]; do printf 'x = %s\n' $i; i=$((i + 1)); done; printf 'r = client.chat.completions.create(**payload)')"
  ts call-var-far; expect_only call-var-far AI-A4 Medium; has call-var-far '[ticket-router] src/more.py:43'

  # AI-P: prompts are files with a golden case
  mk p1 py-agent; put p1 prompts/summary.txt 'Summarise the ticket.'; py p1; expect_only p1 AI-P1 Medium; has p1 '[support-assistant] prompts/summary.txt'
  mk p1-dir py-agent; run p1-dir $PY --prompts nowhere .; expect_only p1-dir AI-P1 Medium
  # AI-K: the off switch
  pyedit k1 agent/main.py 'SUPPORT_AI_ENABLED' 'SUPPORT_ENABLED'; py k1; expect_only k1 AI-K1 High; has k1 'SUPPORT_AI_ENABLED is not read in agent/main.py'
  mk k1-row py-agent; edit k1-row "$D" "$(drop '| flag |')"; py k1-row; expect_only k1-row AI-K1 High; has k1-row 'no off switch declared'
  # AI-F: fine-tuning
  mk f1 py-agent; put f1 docs/operations/fine-tune.md '# Fine-tune
1. Check the dataset for personal data and remove it.
2. Submit the job.
3. Run the golden set eval on the new model.'
  py f1 --fine-tune-runbook docs/operations/fine-tune.md; expect_only f1 AI-F1 High; has f1 'no spend cap'
  mk f1-good py-agent; put f1-good docs/operations/fine-tune.md '# Fine-tune
1. Set the spend cap: 200 USD.
2. Check the dataset for personal data and remove it.
3. Run the golden set eval on the new model.'
  py f1-good --fine-tune-runbook docs/operations/fine-tune.md; expect_pass f1-good
  mk f1-missing py-agent; py f1-missing --fine-tune-runbook docs/operations/none.md; expect_only f1-missing AI-F1 High; has f1-missing 'does not exist'
  mk f1-pii py-agent; put f1-pii docs/operations/fine-tune.md '# Fine-tune
1. Set the spend cap: 200 USD.
2. Run the golden set eval on the new model.'
  py f1-pii --fine-tune-runbook docs/operations/fine-tune.md; expect_only f1-pii AI-F1 High; has f1-pii 'no personal-data check'
  mk f1-eval py-agent; put f1-eval docs/operations/fine-tune.md '# Fine-tune
1. Set the spend cap: 200 USD.
2. Check the dataset for personal data and remove it.'
  py f1-eval --fine-tune-runbook docs/operations/fine-tune.md; expect_only f1-eval AI-F1 High; has f1-eval 'no eval against the golden set'

  # the tier scales severities; no record is tier 3
  mk s-tier1 ts-workflow; edit s-tier1 "$D" "$(drop '| baseline value |')"; edit s-tier1 "$TT" "$(subst '| tier | 2 |' '| tier | 1 |')"
  ts s-tier1; expect_only s-tier1 AI-V1 Low; expect_rc s-tier1 0
  mk s-tier2 ts-workflow; edit s-tier2 "$D" "$(drop '| baseline value |')"; ts s-tier2; expect_only s-tier2 AI-V1 Medium; expect_rc s-tier2 0
  mk s-none ts-workflow; edit s-none "$D" "$(drop '| baseline value |')"; run s-none --app ticket-router --root . --design $D .
  has s-none 'FAIL  AI-V1  High'; has s-none 'FAIL  AI-M3  Medium'; expect_rc s-none 1
  mk s-thr py-agent; run s-thr --app support-assistant --root . --design $D --tier-record $PT --prompts prompts --golden tests/evals/golden --threshold Medium .
  has s-thr 'FAIL  AI-M3  Medium'; count s-thr 'FAIL  ' 1; expect_rc s-thr 1

  # a record with CRLF line ends reads the same
  mk crlf py-agent; edit crlf "$D" '/^\|/ { sub(/ *\|$/, "") } { printf "%s\r\n", $0 }'; edit crlf "$PT" '{ printf "%s\r\n", $0 }'; py crlf; expect_pass crlf
  # code with CRLF line ends reads the same: a split tool definition, a decorated def, a capped call
  mk crlf-code py-agent; for f in agent/main.py agent/loop.py agent/refund.py agent/config.py; do edit crlf-code "$f" '{ printf "%s\r\n", $0 }'; done; py crlf-code; expect_pass crlf-code
  # a bare decorator line with a CRLF end still marks the def as a tool
  mk a2-crlf-deco py-agent; printf '@function_tool\r\ndef lookup_order(order: str) -> str:\r\n    return order\r\n' > "$WORK/a2-crlf-deco/agent/extra.py"
  py a2-crlf-deco; expect_only a2-crlf-deco AI-A2 High; has a2-crlf-deco 'lookup_order'
  # an OpenAI tool definition split over lines finds its name up to four lines after "function": {
  pyedit a2-split agent/main.py '{"type": "function", "function": {"name": "issue_refund", "description": "Refund an order, up to the limit.",' '{"type": "function",\n     "function": {\n         "description": "Refund an order, up to the limit.",\n         "strict": True,\n         "name": "issue_refund",'
  py a2-split; expect_pass a2-split
  # nested roots: code under another application's root is not this one's
  mk nested py-agent; put nested agent/sub/x.py 'X = [{"type": "function", "function": {"name": "lookup_order"}}]'
  py nested --app-root other=agent/sub; expect_pass nested
  py nested --app-root other=agent/subway; expect_only nested AI-A2 High
  mk nested2 py-agent; put nested2 agent/subway/x.py 'X = [{"type": "function", "function": {"name": "lookup_order"}}]'
  py nested2 --app-root other=agent/sub; expect_only nested2 AI-A2 High
  mk same py-agent; py same --app-root twin=.; expect_pass same
  # an import is not a loop
  mk imp ts-workflow; put imp src/imp.py 'from langgraph.prebuilt import create_react_agent'; ts imp; expect_pass imp
  # a root below the repository: paths stay repository-relative
  mk sub multi-app; mkdir -p "$WORK/sub/services/support/docs/ai"; cp "$FIX/ts-workflow/$D" "$WORK/sub/services/support/docs/ai/design.md"
  put sub services/support/src/config.ts 'export const MODEL = "claude-haiku-5-5"; export const FALLBACK_MODEL = "claude-sonnet-5-5";'
  put sub services/support/src/index.ts 'if (process.env.ROUTER_AI_ENABLED === "0") {}'
  edit sub services/support/docs/ai/design.md "$(subst '| src/config.ts |' '| services/support/src/config.ts |')"
  edit sub services/support/docs/ai/design.md "$(subst '| src/index.ts |' '| services/support/src/index.ts |')"
  put sub services/screening/x.py 'M = "gpt-4o"'
  run sub --app support --root services/support --design services/support/docs/ai/design.md .; expect_only sub AI-M3 Medium
  lacks sub 'screening'

  # bad input
  mk bad py-agent
  run bad --app support-assistant --root . .; expect_rc bad 2; first bad 'check-ai-design: --design: required'
  run bad --root . --design $D .; expect_rc bad 2; first bad 'check-ai-design: --app: required'
  run bad --app support-assistant --root nowhere --design $D .; expect_rc bad 2; first bad 'check-ai-design: --root: nowhere is not a directory'
  run bad $PY --threshold Severe .; expect_rc bad 2; first bad 'check-ai-design: --threshold: expected Critical, High, Medium or Low, got Severe'
  run bad $PY --today 2026-13-01 .; expect_rc bad 2; first bad 'check-ai-design: --today: 2026-13-01 is not a real date (YYYY-MM-DD)'
  run bad $PY --app-root other .; expect_rc bad 2; first bad 'check-ai-design: --app-root: expected NAME=ROOT, got other'
  run bad --app x --root ../elsewhere --design $D .; expect_rc bad 2; first bad 'check-ai-design: --root: ../elsewhere is not inside the repository'
  run bad $PY --frobnicate .; expect_rc bad 2; first bad 'check-ai-design: --frobnicate: unknown option'
  run bad --help; expect_rc bad 0; has bad 'Usage: check-ai-design.sh --app NAME --root DIR --design FILE'
}
run_matrix
