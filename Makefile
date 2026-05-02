CLUSTER_NAME    ?= demo1
TF_DIR          := bootstrap
KUBECONFIGS_DIR := $(TF_DIR)/.kubeconfigs

ARGOCD_SERVER     ?= $(shell cd $(TF_DIR) && terraform output -raw argocd_url 2>/dev/null | sed 's|https://||')
KARGO_SERVER      ?= $(shell cd $(TF_DIR) && terraform output -raw kargo_url 2>/dev/null)
PLATFORM_REPO_URL ?= https://github.com/dhpup/e2e-platform

.PHONY: all cluster kubeconfig infra bootstrap-apps kargo-creds add-cluster destroy destroy-infra destroy-cluster

## Full initial bootstrap: create first cluster, write kubeconfig, apply Terraform
all: cluster kubeconfig infra

## Create k3d cluster (CLUSTER_NAME=demo1 by default)
cluster:
	k3d cluster create $(CLUSTER_NAME) --wait

## Write kubeconfig for a cluster to bootstrap/.kubeconfigs/<name>.yaml
kubeconfig:
	mkdir -p $(KUBECONFIGS_DIR)
	k3d kubeconfig get $(CLUSTER_NAME) > $(KUBECONFIGS_DIR)/$(CLUSTER_NAME).yaml

## Apply Terraform (creates/updates all registered clusters)
infra:
	cd $(TF_DIR) && terraform init -upgrade && terraform apply -auto-approve

## Seed ArgoCD with the app-of-apps (run once after `make all`).
## Uses TF_VAR_admin_password — no token needed.
bootstrap-apps:
	@test -n "$(TF_VAR_admin_password)" || (echo "ERROR: TF_VAR_admin_password is not set"; exit 1)
	argocd login "$(ARGOCD_SERVER)" \
	  --username admin \
	  --password "$(TF_VAR_admin_password)" \
	  --insecure
	argocd app create app-of-apps \
	  --repo "$(PLATFORM_REPO_URL)" \
	  --path bootstrap \
	  --dest-name in-cluster \
	  --dest-namespace argocd \
	  --project default \
	  --sync-policy automated \
	  --auto-prune \
	  --self-heal \
	  --upsert

## Create Kargo Git credential for GitHub (run once after `make infra`).
## Requires: GITHUB_USER and GITHUB_TOKEN env vars. Uses TF_VAR_admin_password for Kargo login.
kargo-creds:
	@test -n "$(GITHUB_USER)"           || (echo "ERROR: GITHUB_USER is not set"; exit 1)
	@test -n "$(GITHUB_TOKEN)"          || (echo "ERROR: GITHUB_TOKEN is not set"; exit 1)
	@test -n "$(TF_VAR_admin_password)" || (echo "ERROR: TF_VAR_admin_password is not set"; exit 1)
	kargo login "$(KARGO_SERVER)" --admin --password "$(TF_VAR_admin_password)"
	kargo create repo-credentials github-dhpup \
	  --shared \
	  --git \
	  --repo-url '^https://github\.com/dhpup/.*$$' \
	  --regex \
	  --username "$(GITHUB_USER)" \
	  --password "$(GITHUB_TOKEN)"

## Add a new cluster to the fleet:
##   1. Creates the k3d cluster
##   2. Writes its kubeconfig
##   3. Reminds you to add it to terraform.tfvars, then runs apply
add-cluster:
	$(MAKE) cluster CLUSTER_NAME=$(CLUSTER_NAME)
	$(MAKE) kubeconfig CLUSTER_NAME=$(CLUSTER_NAME)
	@echo ""
	@echo "  Cluster '$(CLUSTER_NAME)' is ready."
	@echo "  Add \"$(CLUSTER_NAME)\" to the clusters set in bootstrap/terraform.tfvars,"
	@echo "  then run: make infra"
	@echo ""

## Tear down Terraform resources, then delete all k3d clusters
destroy: destroy-infra destroy-cluster

destroy-infra:
	cd $(TF_DIR) && terraform destroy -auto-approve

## Delete a specific k3d cluster and its kubeconfig (CLUSTER_NAME=demo1 by default)
destroy-cluster:
	k3d cluster delete $(CLUSTER_NAME)
	rm -f $(KUBECONFIGS_DIR)/$(CLUSTER_NAME).yaml
