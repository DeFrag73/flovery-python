.PHONY: init plan apply destroy
ENV=flowery-dev-01
init:
	terraform init
	terraform workspace select -or-create ${ENV}

plan: init
	terraform plan -var-file=workspace_vars/${ENV}.tfvars

apply: init
	terraform apply -var-file=workspace_vars/${ENV}.tfvars -auto-approve

destroy: init
	terraform destroy -var-file=workspace_vars/${ENV}.tfvars -auto-approve