#!/usr/bin/env bash
# Behavior test for plugins/ascent-ops/scripts/check-iac-config.sh.
#
# The good fixtures (CloudFormation, Terraform, tfvars, Dockerfile, Compose, an ECS
# task definition and a drift workflow) pass all ten checks. Then each check gets
# negative controls: a copy broken in exactly one way must fail that check and no
# other. Also covers values never printed, comments, CRLF, non-ASCII text before a
# finding, the KMS key-policy exemption, NOTE lines for IaC that is not covered,
# N/A on a repository with no IaC, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-iac-config: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-ops/scripts/check-iac-config.sh"
GOOD="$HERE/fixtures/iac-good"
for f in "$CHECK" "$GOOD/template.yaml" "$GOOD/infra/main.tf"; do [ -f "$f" ] || { echo "test-check-iac-config: missing $f"; echo "test-check-iac-config: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() {  # ARGS... -> RC, OUT
  PATH="$SHIM:$PATH" bash "$CHECK" "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
# edit NAME FILE AWK-PROGRAM — rewrites FILE in copy NAME; a program that changes
# nothing is reported as a stale anchor.
edit() {
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp"
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit of $2 changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
# Program builders. Double quotes are escaped for the awk string; "\n" in the new
# text becomes a line break.
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
after() { printf '{ print } index($0, "%s") && !d { print "%s"; d = 1 }' "$(q "$1")" "$(q "$2")"; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
expect_only() {  # NAME CHECK [SEVERITY] — the copy fails exactly CHECK
  run --manual "$WORK/$1/manual.md" "$WORK/$1"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|failure' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-70 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}

expect_clean() {  # NAME — the copy passes every check
  run --manual "$WORK/$1/manual.md" "$WORK/$1"
  if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | head -3 | tr '\n' ';')"; fi
}
expect_at() {  # NAME CHECK FILE:LINE — after a run, CHECK fails at FILE:LINE
  if printf '%s\n' "$OUT" | grep -q "^FAIL  $2 .*/$3 "; then ok; else bad "$1: expected $2 at $3: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | head -3 | tr '\n' ';')"; fi
}

matrix() {
  # Baseline: every check passes, and the KMS key policy (kms:*) is exempt.
  run --manual "$GOOD/manual.md" "$GOOD"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 10 ] && printf '%s\n' "$OUT" | grep -q ', 0 failure(s)$'; then ok
  else bad "good fixtures should pass all 10: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi

  # OPS-S1 — literal secrets
  mk s1-cfn-default;  edit s1-cfn-default template.yaml "$(after '    NoEcho: true' '    Default: fixture-literal-value')" && expect_only s1-cfn-default OPS-S1 High
  mk s1-cfn-prop;     edit s1-cfn-prop template.yaml "$(after '      Name: !Sub "app/${Environment}/db"' '      ApiToken: fixture-literal-value')" && expect_only s1-cfn-prop OPS-S1
  mk s1-tf-default;   edit s1-tf-default infra/main.tf "$(after '  sensitive = true' '  default   = "fixture-literal-value"')" && expect_only s1-tf-default OPS-S1
  mk s1-tf-provider;  printf 'provider "aws" {\n  region     = "us-east-1"\n  secret_key = "fixture-literal-value"\n}\n' > "$WORK/s1-tf-provider/infra/provider.tf"; expect_only s1-tf-provider OPS-S1
  mk s1-tfvars;       printf 'db_password = "fixture-literal-value"\n' >> "$WORK/s1-tfvars/infra/prod.tfvars"; expect_only s1-tfvars OPS-S1
  mk s1-docker-env;   edit s1-docker-env Dockerfile "$(after 'ENV NODE_ENV=production' 'ENV API_TOKEN=${API_TOKEN}')" && expect_only s1-docker-env OPS-S1
  mk s1-docker-arg;   edit s1-docker-arg Dockerfile "$(subst 'ARG BUILD_VERSION' 'ARG GITHUB_TOKEN=fixture-literal-value')" && expect_only s1-docker-arg OPS-S1
  mk s1-compose;      edit s1-compose compose.yml "$(after '      NODE_ENV: production' '      DB_PASSWORD: fixture-literal-value')" && expect_only s1-compose OPS-S1
  # The value itself is never printed.
  if printf '%s\n' "$OUT" | grep -q 'fixture-literal-value'; then bad "s1-compose: the secret value was printed"; else ok; fi

  # OPS-S2 — sensitive parameters marked
  mk s2-noecho;       edit s2-noecho template.yaml "$(drop '    NoEcho: true')" && expect_only s2-noecho OPS-S2 Medium
  mk s2-tf-var;       edit s2-tf-var infra/main.tf "$(drop '  sensitive = true')" && expect_only s2-tf-var OPS-S2
  mk s2-tf-output;    printf 'output "db_password" {\n  value = var.db_password\n}\n' >> "$WORK/s2-tf-output/infra/main.tf"; expect_only s2-tf-output OPS-S2

  # OPS-S3 — secrets from a store, not plain environment values
  mk s3-cfn-ecs;      edit s3-cfn-ecs template.yaml "$(after '              Value: production' '            - Name: API_TOKEN\n              Value: !Ref ImageTag')" && expect_only s3-cfn-ecs OPS-S3 High
  mk s3-cfn-lambda;   printf '  Fn:\n    Type: AWS::Lambda::Function\n    Properties:\n      Environment:\n        Variables:\n          DB_PASSWORD: !Ref DbPassword\n' >> "$WORK/s3-cfn-lambda/template.yaml"; expect_only s3-cfn-lambda OPS-S3
  mk s3-cfn-ssm;      edit s3-cfn-ssm template.yaml "$(subst '/log-level"' '/db-password"')" && expect_only s3-cfn-ssm OPS-S3
  mk s3-tf-env;       edit s3-tf-env infra/main.tf "$(subst '{ name = "APP_ENV", value = var.environment }' '{ name = "APP_ENV", value = var.environment },\n        { name = "API_TOKEN", value = var.db_password }')" && expect_only s3-tf-env OPS-S3
  mk s3-tf-ssm;       edit s3-tf-ssm infra/main.tf "$(subst '"SecureString"' '"String"')" && expect_only s3-tf-ssm OPS-S3
  mk s3-taskjson;     edit s3-taskjson taskdef.json "$(subst '{ "name": "NODE_ENV", "value": "production" }' '{ "name": "NODE_ENV", "value": "production" },\n        { "name": "API_KEY", "value": "x" }')" && expect_only s3-taskjson OPS-S3
  mk s3-compose;      edit s3-compose compose.yml "$(after '      - QUEUE=jobs' '      - DB_PASSWORD=${DB_PASSWORD}')" && expect_only s3-compose OPS-S3 Medium

  # OPS-S4 — Terraform state
  mk s4-no-encrypt;   edit s4-no-encrypt infra/main.tf "$(drop 'encrypt      = true')" && expect_only s4-no-encrypt OPS-S4 High
  mk s4-no-lock;      edit s4-no-lock infra/main.tf "$(drop 'use_lockfile = true')" && expect_only s4-no-lock OPS-S4
  mk s4-local;        edit s4-local infra/main.tf "$(subst 'backend "s3"' 'backend "local"')" && expect_only s4-local OPS-S4
  mk s4-no-backend;   edit s4-no-backend infra/main.tf '/backend "s3"/ { skip = 1 } skip { if ($0 ~ /^  }/) skip = 0; next } { print }' && expect_only s4-no-backend OPS-S4
  mk s4-state;        printf '{"version": 4}\n' > "$WORK/s4-state/infra/terraform.tfstate"; expect_only s4-state OPS-S4

  # OPS-S5 — wildcard actions (a KMS key policy is exempt; see the baseline)
  mk s5-cfn-list;     edit s5-cfn-list template.yaml "$(subst '- secretsmanager:GetSecretValue' '- secretsmanager:*')" && expect_only s5-cfn-list OPS-S5 Medium
  mk s5-cfn-inline;   edit s5-cfn-inline template.yaml "$(subst '                Action:' '                Action: "*"')" && expect_only s5-cfn-inline OPS-S5
  mk s5-tf;           edit s5-tf infra/main.tf "$(subst '["secretsmanager:GetSecretValue"]' '["s3:GetObject", "s3:*"]')" && expect_only s5-tf OPS-S5
  mk s5-tf-json;      printf 'resource "aws_iam_policy" "p" {\n  policy = jsonencode({\n    Statement = [{ Effect = "Allow", Action = "*", Resource = "*" }]\n  })\n}\n' >> "$WORK/s5-tf-json/infra/main.tf"; expect_only s5-tf-json OPS-S5

  # OPS-S6 — rotation
  mk s6-cfn;          edit s6-cfn template.yaml '/^  AppSecretRotation:/ { skip = 1; next } skip && /^  [A-Za-z]/ { skip = 0 } skip { next } { print }' && expect_only s6-cfn OPS-S6 Low
  mk s6-tf;           edit s6-tf infra/main.tf '/aws_secretsmanager_secret_rotation/ { skip = 1; next } skip { if ($0 ~ /^}/) skip = 0; next } { print }' && expect_only s6-tf OPS-S6

  # OPS-S7 — per-environment configuration (renamed throughout, manual updated, so only OPS-S7 changes)
  mk s7;              edit s7 template.yaml "$(subst '  Environment:' '  Flavor:')" && edit s7 infra/main.tf "$(subst 'variable "environment"' 'variable "flavor"')" \
    && mv "$WORK/s7/infra/prod.tfvars" "$WORK/s7/infra/values.tfvars" && printf '| Flavor | template.yaml | |\n| flavor | infra/main.tf | |\n' >> "$WORK/s7/manual.md" && expect_only s7 OPS-S7 Medium
  mk s7-workspace;    edit s7-workspace template.yaml "$(subst '  Environment:' '  Flavor:')" && edit s7-workspace infra/main.tf "$(subst 'variable "environment"' 'variable "flavor"')" \
    && mv "$WORK/s7-workspace/infra/prod.tfvars" "$WORK/s7-workspace/infra/values.tfvars" && printf '| Flavor | | |\n| flavor | | |\n' >> "$WORK/s7-workspace/manual.md" \
    && printf 'locals {\n  stage = terraform.workspace\n}\n' >> "$WORK/s7-workspace/infra/main.tf"
  run --manual "$WORK/s7-workspace/manual.md" "$WORK/s7-workspace"
  if [ "$RC" -eq 0 ]; then ok; else bad "s7-workspace: terraform.workspace counts as per-environment configuration: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi

  # OPS-S8 — .env files
  mk s8-docker;       edit s8-docker Dockerfile "$(subst 'COPY .env.example ./' 'COPY .env ./')" && expect_only s8-docker OPS-S8 High
  mk s8-compose-prod; printf 'services:\n  app:\n    image: registry.example/app:1.4.2\n    env_file: .env.prod\n' > "$WORK/s8-compose-prod/compose.prod.yml"; expect_only s8-compose-prod OPS-S8 Medium
  mk s8-compose-dev;  printf 'services:\n  app:\n    image: registry.example/app:1.4.2\n    env_file: .env\n' > "$WORK/s8-compose-dev/compose.dev.yml"
  run --manual "$WORK/s8-compose-dev/manual.md" "$WORK/s8-compose-dev"
  if [ "$RC" -eq 0 ]; then ok; else bad "s8-compose-dev: env_file outside production should pass"; fi

  # OPS-S9 — drift
  mk s9-none;         rm -rf "$WORK/s9-none/.github"; expect_only s9-none OPS-S9 Medium
  mk s9-hidden;       printf 'resource "aws_s3_bucket" "b" {\n  bucket = "x"\n  lifecycle {\n    ignore_changes = all\n  }\n}\n' >> "$WORK/s9-hidden/infra/main.tf"; expect_only s9-hidden OPS-S9
  mk s9-cfn;          rm -rf "$WORK/s9-cfn/.github"; printf 'drift:\n\taws cloudformation detect-stack-drift --stack-name app\n' > "$WORK/s9-cfn/Makefile"
  run --manual "$WORK/s9-cfn/manual.md" "$WORK/s9-cfn"
  if [ "$RC" -eq 0 ]; then ok; else bad "s9-cfn: a make target running detect-stack-drift counts as drift detection"; fi

  # OPS-S10 — documented in the manual
  mk s10;             edit s10 template.yaml "$(after '  ImageTag:' '    Type: String\n  ReplicaCount:')" && expect_only s10 OPS-S10 Low
  run --manual "$WORK/no-such-manual.md" "$GOOD"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-S10 .*manual not found'; then ok; else bad "missing manual should fail OPS-S10: $RC"; fi
  run "$GOOD"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^N/A   OPS-S10 .*no --manual given'; then ok; else bad "OPS-S10 should be N/A without --manual"; fi

  # Review findings (ADR-013 calibration): parser shapes that were missed or misread.
  # Task definitions: an empty environment array, and a one-line array with a secret.
  mk tj-empty;   printf '{\n  "containerDefinitions": [\n    {\n      "name": "w",\n      "image": "registry.example/w:1.0.0",\n      "environment": [],\n      "secrets": [\n        { "name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:us-east-1:000000000000:secret:w" }\n      ]\n    }\n  ]\n}\n' > "$WORK/tj-empty/worker.json"; expect_clean tj-empty
  mk tj-oneline; printf '{ "containerDefinitions": [ { "name": "w", "image": "registry.example/w:1.0.0", "environment": [ { "name": "API_TOKEN", "value": "x" } ], "secrets": [] } ] }\n' > "$WORK/tj-oneline/worker.json"; expect_only tj-oneline OPS-S3 High
  # Dockerfile ENV continued over two lines.
  mk docker-cont; edit docker-cont Dockerfile "$(subst 'ENV NODE_ENV=production' 'ENV NODE_ENV=production \\\n    DB_PASSWORD=fixture-literal-value')" && expect_only docker-cont OPS-S1 High && expect_at docker-cont OPS-S1 Dockerfile:4
  # One-line Terraform blocks.
  mk tf-oneline-default; printf 'variable "api_token" { default = "fixture-literal-value" }\n' >> "$WORK/tf-oneline-default/infra/main.tf"; printf '| api_token | infra/main.tf | |\n' >> "$WORK/tf-oneline-default/manual.md"
  run --manual "$WORK/tf-oneline-default/manual.md" "$WORK/tf-oneline-default"; expect_at tf-oneline-default OPS-S1 main.tf:"$(grep -c '' "$WORK/tf-oneline-default/infra/main.tf")"
  mk tf-oneline-var; printf 'variable "replica_count" {}\n' >> "$WORK/tf-oneline-var/infra/main.tf"; expect_only tf-oneline-var OPS-S10 Low
  mk tf-lambda-map; printf 'resource "aws_lambda_function" "f" {\n  function_name = "f"\n  environment {\n    variables = { LOG_LEVEL = "info", DB_PASSWORD = "fixture-literal-value" }\n  }\n}\n' >> "$WORK/tf-lambda-map/infra/main.tf"; expect_only tf-lambda-map OPS-S3 High
  # Rotation: a secret version is not a rotation; the CloudFormation long-form Ref is.
  mk tf-version-only; edit tf-version-only infra/main.tf "$(subst 'resource "aws_secretsmanager_secret_rotation" "db"' 'resource "aws_secretsmanager_secret_version" "db"')" && expect_only tf-version-only OPS-S6 Low
  mk cfn-long-ref; edit cfn-long-ref template.yaml "$(subst 'SecretId: !Ref AppSecret' 'SecretId:\n        Ref: AppSecret')" && expect_clean cfn-long-ref
  # Token validity units and CodeBuild variables from Secrets Manager are not secrets.
  mk cognito; printf '  Client:\n    Type: AWS::Cognito::UserPoolClient\n    Properties:\n      TokenValidityUnits:\n        AccessToken: hours\n        IdToken: hours\n        RefreshToken: days\n' >> "$WORK/cognito/template.yaml"
  printf 'resource "aws_cognito_user_pool_client" "c" {\n  name = "c"\n  token_validity_units {\n    access_token  = "hours"\n    refresh_token = "days"\n  }\n}\n' >> "$WORK/cognito/infra/main.tf"; expect_clean cognito
  mk codebuild; printf '  Build:\n    Type: AWS::CodeBuild::Project\n    Properties:\n      Environment:\n        EnvironmentVariables:\n          - Name: GITHUB_TOKEN\n            Type: SECRETS_MANAGER\n            Value: ci/github\n' >> "$WORK/codebuild/template.yaml"; expect_clean codebuild
  mk codebuild-plain; printf '  Build:\n    Type: AWS::CodeBuild::Project\n    Properties:\n      Environment:\n        EnvironmentVariables:\n          - Name: GITHUB_TOKEN\n            Type: PLAINTEXT\n            Value: ci/github\n' >> "$WORK/codebuild-plain/template.yaml"; expect_only codebuild-plain OPS-S3 High
  # A key policy: only the account-root statement may use kms:*.
  mk kms-any; edit kms-any template.yaml "$(subst ':root"' ':role/ops"')" && expect_only kms-any OPS-S5 Medium
  mk kms-tf-root; printf 'data "aws_iam_policy_document" "key" {\n  statement {\n    sid       = "Root"\n    actions   = ["kms:*"]\n    resources = ["*"]\n    principals {\n      type        = "AWS"\n      identifiers = ["arn:aws:iam::000000000000:root"]\n    }\n  }\n}\n' >> "$WORK/kms-tf-root/infra/main.tf"; expect_clean kms-tf-root
  mk kms-tf-any; printf 'data "aws_iam_policy_document" "key" {\n  statement {\n    sid       = "Everyone"\n    actions   = ["kms:*"]\n    resources = ["*"]\n  }\n}\n' >> "$WORK/kms-tf-any/infra/main.tf"; expect_only kms-tf-any OPS-S5 Medium
  # Drift evidence: a comment or a test is not a drift check.
  mk drift-comment; rm -rf "$WORK/drift-comment/.github"; printf '#!/usr/bin/env bash\n# TODO: run terraform plan -detailed-exitcode in CI\n' > "$WORK/drift-comment/notes.sh"; expect_only drift-comment OPS-S9 Medium
  mk drift-test; rm -rf "$WORK/drift-test/.github"; mkdir -p "$WORK/drift-test/tests"; printf '#!/usr/bin/env bash\nterraform plan -detailed-exitcode\n' > "$WORK/drift-test/tests/drift.sh"; expect_only drift-test OPS-S9 Medium
  # A local override is not a production Compose file.
  mk compose-prod-local; printf 'services:\n  app:\n    image: registry.example/app:1.4.2\n    env_file: .env\n' > "$WORK/compose-prod-local/docker-compose.prod.local.yml"; expect_clean compose-prod-local

  # Comments are not configuration.
  mk comments; printf '# DbPassword: commented-literal-value\n' >> "$WORK/comments/template.yaml"
  printf '# default = "commented-literal-value"\n// password = "commented-literal-value"\n/*\npassword = "commented-literal-value"\n*/\n' >> "$WORK/comments/infra/main.tf"
  run --manual "$WORK/comments/manual.md" "$WORK/comments"
  if [ "$RC" -eq 0 ]; then ok; else bad "comments should be ignored: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi

  # CRLF line endings.
  mk crlf; awk '{ printf "%s\r\n", $0 }' "$GOOD/template.yaml" > "$WORK/crlf/template.yaml"
  run --manual "$WORK/crlf/manual.md" "$WORK/crlf"
  if [ "$RC" -eq 0 ]; then ok; else bad "CRLF template should pass: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi

  # Non-ASCII text before a finding keeps the line number (awk runs with LC_ALL=C).
  mk utf8; { printf 'services:\n'; i=0; while [ $i -lt 30 ]; do printf '  # caf\303\251 \342\206\222 r\303\251sum\303\251\n'; i=$((i + 1)); done
    printf '  app:\n    image: x:1\n    environment:\n      DB_PASSWORD: fixture-literal-value\n'; } > "$WORK/utf8/compose.yml"
  run --manual "$WORK/utf8/manual.md" "$WORK/utf8"
  if printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-S1 .*compose.yml:35 '; then ok; else bad "utf8: expected OPS-S1 at compose.yml:35: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -1)"; fi

  # A path containing "=" is a file, not an awk assignment.
  mkdir -p "$WORK/a=b"; cp "$GOOD/template.yaml" "$WORK/a=b/template.yaml"
  run "$WORK/a=b/template.yaml"
  if printf '%s\n' "$OUT" | grep -q 'CloudFormation 1,'; then ok; else bad "a path with = should be read as a file: $(printf '%s\n' "$OUT" | tail -1)"; fi

  # IaC that is not covered: NOTE lines, never PASS or FAIL.
  mkdir -p "$WORK/notes/k8s"; printf '{}\n' > "$WORK/notes/cdk.json"; printf 'name: app\nruntime: nodejs\n' > "$WORK/notes/Pulumi.yaml"
  printf '{ "AWSTemplateFormatVersion": "2010-09-09", "Resources": {} }\n' > "$WORK/notes/stack.json"
  printf 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: app\n' > "$WORK/notes/k8s/deploy.yaml"
  run "$WORK/notes"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE ')" -eq 4 ] && ! printf '%s\n' "$OUT" | grep -q '^PASS '; then ok
  else bad "notes: expected 4 NOTE lines and no PASS: $(printf '%s\n' "$OUT" | grep -E '^(NOTE|PASS|FAIL)' | cut -c1-50 | tr '\n' ';')"; fi

  # No IaC at all: every check N/A, exit 0.
  mkdir -p "$WORK/none"; printf '# readme\n' > "$WORK/none/README.md"
  run "$WORK/none"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^N/A ')" -eq 10 ]; then ok; else bad "no IaC: expected 10 N/A lines, exit 0: $RC"; fi

  # Bad input and help.
  run "$WORK/does-not-exist"; [ "$RC" -eq 2 ] && ok || bad "missing path should exit 2, got $RC"
  run --bogus "$GOOD"; [ "$RC" -eq 2 ] && ok || bad "unknown option should exit 2, got $RC"
  run; [ "$RC" -eq 2 ] && ok || bad "no path should exit 2, got $RC"
  run --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-iac-config.sh'; then ok; else bad "--help should print usage and exit 0"; fi
}

realpath_of() {
  local p="$1" l
  while [ -L "$p" ]; do l=$(ls -l "$p" | sed 's/.* -> //'); case "$l" in /*) p="$l" ;; *) p="$(dirname "$p")/$l" ;; esac; done
  printf '%s' "$p"
}
AWKS="default"; SEEN=" $(realpath_of "$(command -v awk)") "
[ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
  p=$(command -v "$a" 2>/dev/null) || continue
  r=$(realpath_of "$p")
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; AWKS="$AWKS $a"
done
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-check-iac-config: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
