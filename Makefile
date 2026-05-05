CLUSTER_NAME    ?= demo1
TF_DIR          := bootstrap
KUBECONFIGS_DIR := $(TF_DIR)/.kubeconfigs

ARGOCD_SERVER     ?= $(shell cd $(TF_DIR) && terraform output -raw argocd_url 2>/dev/null | sed 's|https://||')
KARGO_SERVER      ?= $(shell cd $(TF_DIR) && terraform output -raw kargo_url 2>/dev/null)
PLATFORM_REPO_URL  ?= https://github.com/dhpup/e2e-platform
PLATFORM_REPO_PATH ?= ../e2e-platform

.PHONY: all cluster kubeconfig infra bootstrap-apps kargo-creds add-cluster register-cluster remove-cluster destroy destroy-infra destroy-cluster

## Full initial bootstrap: create first cluster, write kubeconfig, apply Terraform
all: cluster kubeconfig infra

## Create k3d cluster (CLUSTER_NAME=demo1 by default).
## Traefik and metrics-server are disabled — not needed for this demo and
## they consume enough memory to crowd out the Akuity agent on small hosts.
cluster:
	k3d cluster create $(CLUSTER_NAME) \
	  --k3s-arg "--disable=traefik@server:*" \
	  --k3s-arg "--disable=metrics-server@server:*" \
	  --wait

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
	  --password "$(GITHUB_TOKEN)" \
	  2>/dev/null || echo "  (github-dhpup credentials already exist, skipping)"
	@ARGOCD_TOKEN=$$(argocd account generate-token --account admin) && \
	kargo delete generic-credentials argocd-refresh-token \
	  --shared 2>/dev/null || true && \
	kargo create generic-credentials argocd-refresh-token \
	  --shared \
	  --set url=https://$(ARGOCD_SERVER) \
	  --set token=$$ARGOCD_TOKEN

## Create a k3d cluster and write its kubeconfig — step 1 of adding a fleet cluster.
## Follow with `make register-cluster` once you're ready to wire it into the pipeline.
## Usage: make add-cluster CLUSTER_NAME=demo2
add-cluster:
	$(MAKE) cluster CLUSTER_NAME=$(CLUSTER_NAME)
	$(MAKE) kubeconfig CLUSTER_NAME=$(CLUSTER_NAME)
	@echo ""
	@echo "  Cluster '$(CLUSTER_NAME)' is ready."
	@echo "  Run 'make register-cluster CLUSTER_NAME=$(CLUSTER_NAME)' to wire it into the pipeline."
	@echo ""

## Wire an existing cluster into the GitOps pipeline — step 2 of adding a fleet cluster.
## Updates terraform.tfvars, stages.yaml, project.yaml, copies the env dir,
## commits the platform repo, and applies Terraform.
## Usage: make register-cluster CLUSTER_NAME=demo2
register-cluster:
	@echo "Registering $(CLUSTER_NAME) in platform repo..."
	@python3 scripts/register-cluster.py $(CLUSTER_NAME) $(PLATFORM_REPO_PATH)
	@cd $(PLATFORM_REPO_PATH) && \
	  git add apps/team-daniel/kargo/stages.yaml \
	          apps/team-daniel/kargo/project.yaml \
	          apps/team-daniel/env/prod-$(CLUSTER_NAME)/ && \
	  git commit -m "feat(kargo): add prod-$(CLUSTER_NAME) stage and env"
	@echo ""
	@echo "  Platform repo committed. Push e2e-platform when ready, then run 'make infra'."
	@echo ""

## Remove a cluster from the fleet pipeline and destroy it — full demo reset.
## Removes the prod-CLUSTER_NAME stage, env dir, and tfvars entry, commits the
## platform repo, deregisters from Akuity via Terraform, then deletes the k3d cluster.
## Usage: make remove-cluster CLUSTER_NAME=demo2
remove-cluster:
	@echo "Deregistering $(CLUSTER_NAME) from platform repo..."
	@python3 scripts/deregister-cluster.py $(CLUSTER_NAME) $(PLATFORM_REPO_PATH)
	@cd $(PLATFORM_REPO_PATH) && \
	  git add apps/team-daniel/kargo/stages.yaml \
	          apps/team-daniel/kargo/project.yaml \
	          apps/team-daniel/env/ && \
	  git commit -m "feat(kargo): remove prod-$(CLUSTER_NAME) stage and env"
	@echo ""
	@echo "  Platform repo committed. Push e2e-platform when ready, then:"
	@echo "  Removing from Akuity via Terraform..."
	@echo ""
	$(MAKE) infra
	$(MAKE) destroy-cluster CLUSTER_NAME=$(CLUSTER_NAME)
	@echo ""
	@echo "  $(CLUSTER_NAME) removed. Run 'make add-cluster CLUSTER_NAME=$(CLUSTER_NAME)' to start fresh."
	@echo ""

## Tear down Terraform resources then delete every cluster in bootstrap/.kubeconfigs/
destroy: destroy-infra
	@for cfg in $(KUBECONFIGS_DIR)/*.yaml; do \
	  [ -f "$$cfg" ] || continue; \
	  name=$$(basename $$cfg .yaml); \
	  echo "Deleting cluster: $$name"; \
	  k3d cluster delete $$name; \
	  rm -f $$cfg; \
	done

destroy-infra:
	cd $(TF_DIR) && terraform destroy -auto-approve

## Delete a single cluster and its kubeconfig (CLUSTER_NAME=demo1 by default)
destroy-cluster:
	k3d cluster delete $(CLUSTER_NAME)
	rm -f $(KUBECONFIGS_DIR)/$(CLUSTER_NAME).yaml
