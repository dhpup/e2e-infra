CLUSTER_NAME    ?= demo1
TF_DIR          := bootstrap
KUBECONFIGS_DIR := $(TF_DIR)/.kubeconfigs

# Set these before running bootstrap-apps:
#   export ARGOCD_TOKEN=...          (admin token from ArgoCD UI → User Info)
#   export PLATFORM_REPO_URL=...     (your fork of e2e-platform)
ARGOCD_SERVER   ?= $(shell cd $(TF_DIR) && terraform output -raw argocd_url 2>/dev/null | sed 's|https://||')
PLATFORM_REPO_URL ?= https://github.com/YOUR_ORG/e2e-platform

.PHONY: all cluster kubeconfig infra bootstrap-apps add-cluster destroy destroy-infra destroy-cluster

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
## Requires: ARGOCD_TOKEN and PLATFORM_REPO_URL env vars.
bootstrap-apps:
	@test -n "$(ARGOCD_TOKEN)" || (echo "ERROR: ARGOCD_TOKEN is not set"; exit 1)
	argocd app create app-of-apps \
	  --server "$(ARGOCD_SERVER)" \
	  --auth-token "$(ARGOCD_TOKEN)" \
	  --repo "$(PLATFORM_REPO_URL)" \
	  --path bootstrap \
	  --dest-name in-cluster \
	  --dest-namespace argocd \
	  --project default \
	  --sync-policy automated \
	  --auto-prune \
	  --self-heal \
	  --upsert

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
