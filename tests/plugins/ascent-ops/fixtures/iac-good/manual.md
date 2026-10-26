# Configuration

| Parameter | Where | Notes |
|---|---|---|
| Environment | template.yaml | dev or prod |
| DbPassword | template.yaml | first deploy only; rotated |
| ImageTag | template.yaml | pinned image tag |
| environment | infra/main.tf | from <env>.tfvars |
| db_password | infra/main.tf | sensitive |
| image_tag | infra/main.tf | pinned |
