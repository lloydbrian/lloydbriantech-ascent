#!/usr/bin/env bash
# Behavior test for plugins/ascent-ai/scripts/check-ai-runtime: an AI
# application's running safeguards (AI-O, AI-C; ADR-031).
#
# Good fixtures: py-agent (tier 3, model calls through a LiteLLM proxy with a
# policy, OpenTelemetry tracing, a capture policy) and ts-workflow (tier 2,
# gateway none, OpenInference tracing). Each rule then gets negative controls:
# a copy broken in exactly one way fails that rule and no other, at the severity
# its tier gives it. Also covers every tracing package family, a client built
# over several lines, nested roots, CRLF and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-ai-runtime: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-check-ai-runtime
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-ai-runtime.sh"
need "$CHECK" "$FIX/py-agent/deploy/gateway/policy.yaml" "$FIX/py-agent/docs/ai/capture-policy.md"
D=docs/ai/design.md; GP=deploy/gateway/policy.yaml; CP=docs/ai/capture-policy.md
PY="--app support-assistant --root . --design $D --tier-record docs/governance/ai-tier/support-assistant.md --capture-policy $CP --gateway-policy $GP"
TS="--app ticket-router --root . --design $D --tier-record docs/governance/ai-tier/ticket-router.md --capture-policy $CP"
py() { local n="$1"; shift; run "$n" $PY "$@" .; }
ts() { local n="$1"; shift; run "$n" $TS "$@" .; }
pyedit() { mk "$1" py-agent; edit "$1" "$2" "$(subst "$3" "$4")"; }   # COPY FILE FROM TO
put() { mkdir -p "$(dirname "$WORK/$1/$2")"; printf '%s\n' "$3" > "$WORK/$1/$2"; }   # COPY FILE TEXT
matrix() {
  mk good py-agent; py good; expect_pass good
  has good 'PASS  AI-O1  [support-assistant] tracing: opentelemetry-instrumentation-openai-v2 (pyproject.toml)'
  has good 'PASS  AI-C1  [support-assistant] model clients go through the litellm gateway'
  has good 'check-ai-runtime: [support-assistant] 0 finding(s)'
  mk tsgood ts-workflow; ts tsgood; expect_pass tsgood; has tsgood 'PASS  AI-C1  [ticket-router] gateway none, at tier 2'
  has tsgood 'N/A   AI-C2  [ticket-router] gateway none'

  # AI-O1: tracing
  pyedit o1 pyproject.toml '    "opentelemetry-instrumentation-openai-v2>=2.0b0",' '    "requests>=2",'; py o1; expect_only o1 AI-O1 High
  has o1 'no tracing for model calls in the dependencies'
  # a model client in test data is not the application's (as detect-ai skips it)
  mk c1-fixtures py-agent; mkdir -p "$WORK/c1-fixtures/agent/fixtures"; printf 'from openai import OpenAI\nc = OpenAI()\n' > "$WORK/c1-fixtures/agent/fixtures/client.py"; py c1-fixtures; expect_pass c1-fixtures
  mk o1-ts ts-workflow; edit o1-ts package.json "$(drop '@arizeai/')"; edit o1-ts package.json "$(subst '"0.40.0",' '"0.40.0"')"
  ts o1-ts; expect_only o1-ts AI-O1 Medium; expect_rc o1-ts 0
  for pkg in 'langfuse>=2' 'arize-phoenix-otel>=0.6' 'openinference-instrumentation-openai>=0.1' 'opentelemetry-instrumentation-anthropic>=0.3' 'traceloop-sdk>=0.30'; do
    pyedit "o1-$pkg" pyproject.toml '"opentelemetry-instrumentation-openai-v2>=2.0b0"' "\"$pkg\""; py "o1-$pkg"; expect_pass "o1-$pkg"
  done
  # pip names with underscores are the same packages
  mk o1-underscore py-agent; edit o1-underscore pyproject.toml "$(drop 'opentelemetry')"; put o1-underscore requirements.txt 'opentelemetry_instrumentation_openai_v2==2.0b0'; py o1-underscore; expect_pass o1-underscore
  # a manifest under another application's root is that application's
  mk o1-other-root py-agent; edit o1-other-root pyproject.toml "$(drop 'opentelemetry')"; put o1-other-root bots/pyproject.toml '"langfuse>=2"'
  py o1-other-root --app-root bots=bots; expect_only o1-other-root AI-O1 High
  mk o1-req py-agent; edit o1-req pyproject.toml "$(drop 'opentelemetry')"; put o1-req requirements.txt 'langfuse==2.50'; py o1-req; expect_pass o1-req
  # a src layout: the manifests in the folders above the application's root are its dependencies too, a sibling's are not
  mk o1-src py-agent; run o1-src --app support-assistant --root agent --design $D --capture-policy $CP --gateway-policy $GP .
  has o1-src 'PASS  AI-O1  [support-assistant] tracing: opentelemetry-instrumentation-openai-v2 (pyproject.toml)'
  mk o1-sibling py-agent; edit o1-sibling pyproject.toml "$(drop 'opentelemetry')"; put o1-sibling docs/pyproject.toml '"langfuse>=2"'
  run o1-sibling --app support-assistant --root agent --design $D --capture-policy $CP --gateway-policy $GP .; has o1-sibling 'FAIL  AI-O1  High'
  for pkg in '@langfuse/otel' '@opentelemetry/instrumentation-openai' '@traceloop/node-server-sdk'; do
    n="o1-$(printf '%s' "$pkg" | tr '@/' '__')"   # a copy name holds no slash
    mk "$n" ts-workflow; edit "$n" package.json "$(subst '@arizeai/openinference-instrumentation-anthropic' "$pkg")"; ts "$n"; expect_pass "$n"
  done
  mk o1-other ts-workflow; edit o1-other package.json "$(subst '@arizeai/openinference-instrumentation-anthropic' '@opentelemetry/api')"; ts o1-other
  expect_only o1-other AI-O1 Medium

  # AI-O2: the capture policy
  mk o2 py-agent; run o2 ${PY/--capture-policy $CP/} .; expect_only o2 AI-O2 High; has o2 'no capture policy given'
  mk o2-missing py-agent; py o2-missing --capture-policy docs/ai/none.md; expect_only o2-missing AI-O2 High; has o2-missing 'does not exist'
  mk o2-redact py-agent; edit o2-redact "$CP" "$(drop '- Redacted:')"; py o2-redact; expect_only o2-redact AI-O2 High
  has o2-redact 'does not say what is redacted'
  mk o2-stored py-agent; edit o2-stored "$CP" "$(drop '- Stored:')"; py o2-stored; expect_only o2-stored AI-O2 High; has o2-stored 'does not say what is stored'
  mk o2-dropped py-agent; edit o2-dropped "$CP" "$(drop '- Dropped:')"; py o2-dropped; expect_only o2-dropped AI-O2 High; has o2-dropped 'does not say what is dropped'

  # AI-C1: the gateway
  pyedit c1 agent/main.py 'client = OpenAI(base_url=os.environ["LLM_GATEWAY_URL"])' 'client = OpenAI()'; py c1; expect_only c1 AI-C1 Medium
  has c1 '[support-assistant] agent/main.py:8  a model client that does not go through the litellm gateway'; expect_rc c1 0
  mk c1-multi py-agent; edit c1-multi agent/main.py "$(subst 'client = OpenAI(base_url=os.environ["LLM_GATEWAY_URL"])' 'client = OpenAI(\n    base_url=os.environ["LLM_GATEWAY_URL"],\n)')"
  py c1-multi; expect_pass c1-multi
  for shape in anthropic async genai bedrock ts; do
    mk "c1-$shape" py-agent; f=agent/extra.py
    case "$shape" in
      anthropic) put "c1-$shape" $f 'c = anthropic.Anthropic()' ;;
      async) put "c1-$shape" $f 'c = AsyncOpenAI(api_key=k)' ;;
      genai) put "c1-$shape" $f 'c = genai.Client()' ;;
      bedrock) put "c1-$shape" $f 'c = boto3.client("bedrock-runtime")' ;;
      ts) f=web/client.ts; put "c1-$shape" $f 'const c = new Anthropic({ apiKey: k });' ;;
    esac
    py "c1-$shape"; expect_only "c1-$shape" AI-C1 Medium; has "c1-$shape" "[support-assistant] $f:1"
  done
  mk c1-baseurl py-agent; put c1-baseurl web/client.ts 'const c = new Anthropic({ baseURL: process.env.LLM_GATEWAY_URL });'; py c1-baseurl; expect_pass c1-baseurl
  mk c1-litellm py-agent; put c1-litellm agent/extra.py 'r = litellm.completion(model="gpt-4o-mini", messages=m)'; py c1-litellm; expect_pass c1-litellm
  mk c1-comment py-agent; put c1-comment agent/extra.py '# c = OpenAI()'; py c1-comment; expect_pass c1-comment
  mk c1-prefix py-agent; put c1-prefix agent/extra.py 'c = MyOpenAI()'; py c1-prefix; expect_pass c1-prefix
  mk c1-s3 py-agent; put c1-s3 agent/extra.py 's3 = boto3.client("s3")'; py c1-s3; expect_pass c1-s3
  mk c1-tests-dir py-agent; put c1-tests-dir tests/helpers.py 'c = OpenAI()'; py c1-tests-dir; expect_pass c1-tests-dir
  mk c1-test py-agent; put c1-test tests/test_main.py 'c = OpenAI()'; py c1-test; expect_pass c1-test
  pyedit c1-none "$D" '| gateway | litellm |' '| gateway | none |'; py c1-none; expect_only c1-none AI-C1 Medium
  has c1-none 'the design record says gateway: none, and the tier is 3'; has c1-none 'N/A   AI-C2  [support-assistant] gateway none'
  mk c1-unset py-agent; edit c1-unset "$D" "$(drop '| gateway |')"; py c1-unset; expect_only c1-unset AI-C1 Medium; has c1-unset 'no gateway declared'
  pyedit c1-other "$D" '| gateway | litellm |' '| gateway | kong |'; py c1-other; expect_only c1-other AI-C1 Medium; has c1-other "the gateway is 'kong'"
  mk c1-tier1 py-agent; edit c1-tier1 "$D" "$(subst '| gateway | litellm |' '| gateway | none |')"; edit c1-tier1 docs/governance/ai-tier/support-assistant.md "$(subst '| tier | 3 |' '| tier | 1 |')"
  py c1-tier1; expect_pass c1-tier1
  mk c1-nested py-agent; put c1-nested agent/sub/x.py 'c = OpenAI()'; py c1-nested --app-root other=agent/sub; expect_pass c1-nested

  # AI-C2: the gateway policy
  mk c2 py-agent; run c2 ${PY/--gateway-policy $GP/} .; expect_only c2 AI-C2 High; has c2 'no gateway policy given'
  mk c2-missing py-agent; py c2-missing --gateway-policy deploy/none.yaml; expect_only c2-missing AI-C2 High; has c2-missing 'does not exist'
  mk c2-budget py-agent; edit c2-budget "$GP" "$(drop 'max_budget')"; py c2-budget; expect_only c2-budget AI-C2 High; has c2-budget 'names no budget'
  mk c2-rate py-agent; edit c2-rate "$GP" '{ gsub(/, rpm: [0-9]+, tpm: [0-9]+/, ""); print }'; py c2-rate; expect_only c2-rate AI-C2 High; has c2-rate 'names no rate limits'
  mk c2-models py-agent; edit c2-models "$GP" '{ sub(/^model_list:/, "models_unused:"); sub(/model_name:/, "name:"); print }'; py c2-models; expect_only c2-models AI-C2 High
  has c2-models 'names no allowed models'
  mk c2-alert py-agent; edit c2-alert "$GP" "$(drop 'alert')"; py c2-alert; expect_only c2-alert AI-C2 High; has c2-alert 'names no alert threshold'
  mk c2-crlf py-agent; edit c2-crlf "$GP" '{ printf "%s\r\n", $0 }'; edit c2-crlf "$D" '{ printf "%s\r\n", $0 }'; edit c2-crlf "$CP" '{ printf "%s\r\n", $0 }'; py c2-crlf; expect_pass c2-crlf

  # AI-C3: the cost-per-task alert
  mk c3 py-agent; edit c3 "$D" "$(drop '| cost per task alert |')"; py c3; expect_only c3 AI-C3 Medium; expect_rc c3 0
  mk c3-record py-agent; py c3-record --design docs/ai/none.md; has c3-record 'FAIL  AI-C1'; has c3-record 'no AI design record'

  # bad input
  mk bad py-agent
  run bad --root . --design $D .; expect_rc bad 2; first bad 'check-ai-runtime: --app: required'
  run bad --app x --design $D .; expect_rc bad 2; first bad 'check-ai-runtime: --root: required'
  run bad --app x --root . .; expect_rc bad 2; first bad 'check-ai-runtime: --design: required'
  run bad --app x --root ../up --design $D .; expect_rc bad 2; first bad 'check-ai-runtime: --root: ../up is not inside the repository'
  run bad $PY --app-root other .; expect_rc bad 2; first bad 'check-ai-runtime: --app-root: expected NAME=ROOT, got other'
  run bad $PY --threshold Severe .; expect_rc bad 2; first bad 'check-ai-runtime: --threshold: expected Critical, High, Medium or Low, got Severe'
  run bad $PY --frobnicate .; expect_rc bad 2; first bad 'check-ai-runtime: --frobnicate: unknown option'
  run bad --help; expect_rc bad 0; has bad 'Usage: check-ai-runtime.sh --app NAME --root DIR --design FILE'
}
run_matrix
