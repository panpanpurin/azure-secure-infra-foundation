.PHONY: help init plan apply destroy test validate fmt clean

TF_DIR        := terraform
VALIDATE_SH   := scripts/validate.sh

help: ## Show available targets
	@echo "Azure Infrastructure & Identity Challenge"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  %-12s %s\n", $$1, $$2}'

init: ## Initialize Terraform in $(TF_DIR)
	cd $(TF_DIR) && terraform init

plan: init ## Run terraform plan
	cd $(TF_DIR) && terraform plan

apply: init ## Run terraform apply
	cd $(TF_DIR) && terraform apply

destroy: init ## Tear down candidate-managed resources
	cd $(TF_DIR) && terraform destroy

validate: init ## Run terraform validate
	cd $(TF_DIR) && terraform validate

test: ## Run infrastructure validation scripts
	@test -f $(VALIDATE_SH) || (echo "Missing $(VALIDATE_SH)" >&2; exit 1)
	bash $(VALIDATE_SH)

fmt: ## Format Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

clean: ## Remove local Terraform cache and plan artifacts
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/tfplan $(TF_DIR)/*.tfplan