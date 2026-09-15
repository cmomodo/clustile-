.DEFAULT_GOAL := plan

-include .env

TF_DIR ?= infra
BOOTSTRAP_DIR ?= infra/bootstrap
PLAN_FILE ?= tfplan
TERRAFORM ?= terraform
AWS_ACCOUNT_ID ?=
AWS_REGION ?= us-east-1
ECR_REPOSITORY ?= gamehub
APP_DIR ?= app
IMAGE_TAG ?= latest

.PHONY: init plan apply destroy bootstrap bootstrap-init bootstrap-plan bootstrap-apply bootstrap-destroy push

init:
	$(TERRAFORM) -chdir=$(TF_DIR) init

plan: init
	$(TERRAFORM) -chdir=$(TF_DIR) plan -out=$(PLAN_FILE)

apply: plan
	$(TERRAFORM) -chdir=$(TF_DIR) apply $(PLAN_FILE)

destroy: init
	$(TERRAFORM) -chdir=$(TF_DIR) destroy

bootstrap-init:
	$(TERRAFORM) -chdir=$(BOOTSTRAP_DIR) init

bootstrap-plan: bootstrap-init
	$(TERRAFORM) -chdir=$(BOOTSTRAP_DIR) plan -out=$(PLAN_FILE)

bootstrap-apply: bootstrap-plan
	$(TERRAFORM) -chdir=$(BOOTSTRAP_DIR) apply $(PLAN_FILE)

bootstrap: bootstrap-apply

bootstrap-destroy: bootstrap-init
	$(TERRAFORM) -chdir=$(BOOTSTRAP_DIR) destroy

push: bootstrap-apply
	@set -eu; \
	test -n "$(AWS_ACCOUNT_ID)" || { echo "AWS_ACCOUNT_ID is required in .env" >&2; exit 1; }; \
	registry="$(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com"; \
	repository_url="$$registry/$(ECR_REPOSITORY)"; \
	password="$$(aws ecr get-login-password --region $(AWS_REGION))"; \
	printf '%s' "$$password" | docker login --username AWS --password-stdin "$$registry"; \
	docker build --tag "$$repository_url:$(IMAGE_TAG)" "$(APP_DIR)"; \
	docker push "$$repository_url:$(IMAGE_TAG)"
