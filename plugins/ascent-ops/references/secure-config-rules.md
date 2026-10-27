# Secure-by-design configuration: OPS-S1–S10

Infrastructure as code is the only way configuration changes. These rules keep configuration values and secrets out of the code, out of the images and out of anyone's terminal history. `check-iac-config.sh` applies them mechanically; `iac-config-check` reads what the script cannot see. Severities come from the [ops-review](../skills/ops-review/SKILL.md) table.

A finding names the key and its `file:line`. It never contains the value, even when the value is a placeholder.

| Rule | Severity | The rule | Why |
|---|---|---|---|
| OPS-S1 | High | No secret value is written as a literal or a default: parameter `Default`, variable `default`, an attribute, a tfvars entry, `ENV` or `ARG` in a Dockerfile, a Compose `environment` value | a value in the repository is a value in every clone, fork and backup; `ENV` persists in every image layer |
| OPS-S2 | Medium | Sensitive parameters are marked: `NoEcho: true`; `sensitive = true` on variables and outputs | unmarked values are printed in plans, events and console pages |
| OPS-S3 | High | Secrets reach tasks and functions from Secrets Manager or SSM SecureString (`Secrets`/`valueFrom`, or a runtime read); no secret is stored in an SSM `String`. Medium for Compose: use Compose `secrets:` (a mounted file) | plain environment values show in the console, in `describe` output and in crash dumps |
| OPS-S4 | High | Terraform state is remote, encrypted and locked (`encrypt = true`, `use_lockfile = true` or a lock table); no state file is in the repository | state holds every secret Terraform touched, in plain text |
| OPS-S5 | Medium | IAM policies grant no wildcard actions (`*`, `service:*`); each reader can get only its own secrets. The account-root statement of a KMS key policy is exempt | a wildcard turns one compromised role into every secret |
| OPS-S6 | Low | Every Secrets Manager secret has a rotation schedule | a secret that never rotates stays valid after every leak |
| OPS-S7 | Medium | Configuration is separated per environment: an environment parameter or variable, per-environment tfvars or parameter files, workspaces or environment directories | shared values let a dev change reach production |
| OPS-S8 | High | No `.env` file is copied into an image. Medium: a production Compose file reads an `env_file` | an image is pushed, cached and shared; a host file has no rotation or audit |
| OPS-S9 | Medium | Drift is visible: a scheduled `terraform plan -detailed-exitcode`, `aws cloudformation detect-stack-drift` or `driftctl`; no `lifecycle { ignore_changes = all }` | changes made by hand in a console are the changes nobody can reproduce |
| OPS-S10 | Low | Every parameter and variable is documented in the Maintenance and Operations Manual (where it lives, secret or not, rotation) | the next operator has to know what each value does before changing it |

## Fixes, by tool

**CloudFormation.** Generate secrets (`AWS::SecretsManager::Secret` with `GenerateSecretString`), encrypt them with a customer key (`KmsKeyId`), add an `AWS::SecretsManager::RotationSchedule`, and pass them to ECS with `Secrets: - Name: … ValueFrom: !Ref Secret`. Use `{{resolve:secretsmanager:…}}` for properties that need the value at deploy time. A parameter that must carry a secret gets `NoEcho: true` and no `Default`. The blueprint's [secure-parameters.yaml](../blueprints/operable-service/secure-parameters.yaml) shows each of these.

**Terraform / OpenTofu.** Mark secret variables and outputs `sensitive = true`, never give them a `default`, and read them from `aws_secretsmanager_secret_version` data sources or `ephemeral` resources where the provider supports them. Use an S3 backend with `encrypt = true` and `use_lockfile = true` (or the remote backend of your platform). Keep per-environment values in `<env>.tfvars` or workspaces.

**Dockerfile and Compose.** Pass secrets at run time: Compose `secrets:` mounted as files (`*_FILE` variables), BuildKit `--mount=type=secret` during builds, never `ENV`, `ARG` defaults or `COPY .env`.

## What the script cannot see

Read these by hand (`iac-config-check` Step 3):
- a secret whose key name is built at runtime or does not name a secret (a `config` blob holding a password)
- a `{{resolve:…}}` or data source that points at the wrong environment's secret
- a policy that is least privilege per action but still grants `Resource: "*"` for secret reads
- rotation that is scheduled but whose function cannot reach the database
- CDK, Pulumi, Kubernetes manifests and CloudFormation JSON (reported as NOTE lines)
