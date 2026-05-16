# INFRA — infrastructure deployment and operations.
#
# Each target is a named stub shipped from Day 1 per Principle 4.
# Implementation lands when the project's deploy target (ECS, Kubernetes, local Podman) is configured.
# AWS targets follow the MAKE-NAMING convention: aws-<resource>-<action>-<environment>.

.PHONY: aws-ecs-deploy-staging aws-ecs-deploy-prod aws-ecs-rollback-prod

aws-ecs-deploy-staging:  ## INFRA: Deploy to ECS staging environment
	@printf "aws-ecs-deploy-staging: [STUB] implement when AWS ECS staging is configured\n"
	@printf "  Builds production image, pushes to ECR, updates ECS task definition,\n"
	@printf "  waits for healthy deployment. Requires AWS credentials in environment.\n"

aws-ecs-deploy-prod:  ## INFRA: Deploy to ECS production environment
	@printf "aws-ecs-deploy-prod: [STUB] implement when AWS ECS production is configured\n"
	@printf "  Same as staging deploy but targets production cluster.\n"
	@printf "  Run 'make qa' and 'make sec-scan' first. Gate: all tests green.\n"

aws-ecs-rollback-prod:  ## INFRA: Rollback ECS production to previous task definition
	@printf "aws-ecs-rollback-prod: [STUB] implement when AWS ECS production is configured\n"
	@printf "  Reverts to the previous ECS task definition. This is a make target,\n"
	@printf "  not a panic operation — run it from the runbook under pressure.\n"
