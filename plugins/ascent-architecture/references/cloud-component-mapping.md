# Cloud component mapping

AWS first, with the nearest Azure and Google Cloud equivalent (decision 7, 2026-10-18). Equivalents are close, not identical: limits, pricing models and defaults differ, so re-check quality targets and cost when you move a design across clouds. Service names as of 2026-10; confirm a name before quoting it to a customer.

Rows marked **ARC-B1** are the components of blueprint [static-site-serverless-aws](../blueprints/static-site-serverless-aws/README.md).

| Capability | AWS | Azure | Google Cloud |
|---|---|---|---|
| Object storage (ARC-B1) | Amazon S3 | Blob Storage | Cloud Storage |
| CDN (ARC-B1) | Amazon CloudFront | Azure Front Door | Cloud CDN |
| Edge logic | CloudFront Functions, Lambda@Edge | Front Door rules engine | Cloud CDN edge features, Media CDN |
| Functions (ARC-B1) | AWS Lambda | Azure Functions | Cloud Run functions |
| HTTP API front door (ARC-B1) | Amazon API Gateway (HTTP API) | Azure API Management | API Gateway |
| Key-value / document database (ARC-B1) | Amazon DynamoDB | Azure Cosmos DB | Firestore |
| DNS (ARC-B1) | Amazon Route 53 | Azure DNS | Cloud DNS |
| TLS certificates (ARC-B1) | AWS Certificate Manager | Front Door managed certificates, Key Vault | Certificate Manager |
| Web application firewall | AWS WAF | Azure Web Application Firewall | Google Cloud Armor |
| Logs, metrics, alarms (ARC-B1) | Amazon CloudWatch | Azure Monitor (Log Analytics, Application Insights) | Cloud Logging, Cloud Monitoring |
| Notifications (ARC-B1) | Amazon SNS | Azure Monitor action groups | Cloud Monitoring notification channels |
| Budgets (ARC-B1) | AWS Budgets | Cost Management budgets | Cloud Billing budgets |
| Infrastructure as code (ARC-B1) | AWS CloudFormation, AWS CDK | Bicep (ARM templates) | Infrastructure Manager (Terraform) |
| Cross-cloud IaC | Terraform, OpenTofu | Terraform, OpenTofu | Terraform, OpenTofu |
| Secrets | AWS Secrets Manager, SSM Parameter Store | Azure Key Vault | Secret Manager |
| End-user sign-in | Amazon Cognito | Microsoft Entra External ID | Identity Platform |
| All-in-one static hosting | AWS Amplify Hosting | Azure Static Web Apps | Firebase Hosting |
| Serverless containers | Amazon ECS on AWS Fargate | Azure Container Apps | Cloud Run |
| Kubernetes | Amazon EKS | Azure Kubernetes Service | Google Kubernetes Engine |
| Virtual machines | Amazon EC2, Amazon Lightsail | Azure Virtual Machines | Compute Engine |
| Load balancer (HTTP) | Application Load Balancer | Application Gateway | Cloud Load Balancing |
| Relational database | Amazon RDS, Amazon Aurora | Azure SQL Database, Azure Database for PostgreSQL | Cloud SQL, AlloyDB |
| Queue | Amazon SQS | Azure Service Bus, Storage Queues | Pub/Sub, Cloud Tasks |
| Event bus | Amazon EventBridge | Azure Event Grid | Eventarc |

## Notes on blueprint 1 across clouds

- **Private origin.** CloudFront Origin Access Control maps to Front Door Premium with Private Link to Blob Storage on Azure (Private Link origins need the Premium tier, which has a much higher fixed monthly price), and to a Cloud CDN backend bucket with signed or private access on Google Cloud. In each case the storage must not be publicly readable.
- **API under the same domain.** All three CDNs can route `/api/*` to a second origin; on Azure and Google Cloud the function usually sits behind API Management or API Gateway, or is called directly as a Cloud Run service.
- **Point-in-time recovery.** DynamoDB PITR maps to Cosmos DB continuous backup and Firestore point-in-time recovery; check retention windows, which differ.
- **Cost model.** All three charge per request and per GB for the CDN and functions, so the usage profile carries over; the pricing file covers AWS only. For Azure or Google Cloud, do a live price lookup and label it with its date and source.
