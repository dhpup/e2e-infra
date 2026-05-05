# e2e-infra

Bootstraps the full local demo environment. Uses k3d (local Kubernetes in Docker) — no cloud account required for the clusters. Akuity Platform hosts the ArgoCD and Kargo control planes.

## What it creates

| Resource | Tool | Details |
|---|---|---|
| k3d cluster(s) | k3d | Local Kubernetes clusters in Docker (traefik + metrics-server disabled) |
| ArgoCD instance | Akuity Platform (Terraform) | Hosted ArgoCD, declarative management + promotion controller enabled |
| Kargo instance | Akuity Platform (Terraform) | Hosted Kargo control plane, promotion controller enabled |
| ArgoCD agent(s) | Akuity Platform (Terraform) | One per cluster, `size=small` |
| Kargo agent(s) | Akuity Platform (Terraform) | One per cluster, linked to ArgoCD |

## Prerequisites

- [`k3d`](https://k3d.io) — `brew install k3d`
- [`terraform`](https://developer.hashicorp.com/terraform) >= 1.5 — `brew install terraform`
- [`argocd`](https://argo-cd.readthedocs.io/en/stable/cli_installation/) — `brew install argocd`
- [`kargo`](https://docs.kargo.io/installation/) — `brew install kargo-tech/tap/kargo`
- Akuity Platform account with an API key ([docs](https://docs.akuity.io/akuity-portal/organizations/api-keys/))

## Initial setup

```bash
# 1. Export Akuity API credentials
export AKUITY_API_KEY_ID=...
export AKUITY_API_KEY_SECRET=...

# 2. Set admin password (used for both ArgoCD and Kargo)
export TF_VAR_admin_password=...

# 3. Copy and fill in tfvars
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
# edit bootstrap/terraform.tfvars — set org_name at minimum

# 4. Bootstrap everything
make all
```

Terraform prints the ArgoCD and Kargo URLs after apply.

## Giving Kargo credentials

After `make all`, log in to ArgoCD then run:

```bash
argocd login <argocd-server> --username admin --password $TF_VAR_admin_password --insecure

export GITHUB_USER=your-username
export GITHUB_TOKEN=ghp_...   # repo scope required
make kargo-creds
```

This creates:
1. A shared Git credential for pushing promotion commits to GitHub
2. A long-lived SA token (`terraform-runner-token`) in the `akuity` namespace, stored as a shared `k8s-tf-creds` credential — used by the `tf-apply` promotion step to authenticate against the in-cluster Kubernetes API without relying on automounted SA token files
3. A shared `argocd-refresh-token` credential — used by the `pipeline-refresh` Kargo stage to auto-refresh ArgoCD when pipeline config changes (accessed via `sharedSecret()` in promotion templates)

## Fleet management

### Add a cluster (demo story — two steps)

```bash
# Step 1: create the k3d cluster (stop here during a demo)
make add-cluster CLUSTER_NAME=demo2

# Step 2: wire it into the GitOps pipeline
make register-cluster CLUSTER_NAME=demo2
# then push e2e-platform and apply:
git -C ../e2e-platform push origin main
make infra
```

`register-cluster` automatically updates `terraform.tfvars`, `stages.yaml`, `project.yaml`, and copies the env directory template — no manual file editing needed.

`make infra` also re-applies the `fleet=true` label to newly registered clusters via the ArgoCD CLI so fleet ApplicationSet generators detect them immediately without a manual label toggle.

### Remove a cluster (demo reset)

```bash
make remove-cluster CLUSTER_NAME=demo2
git -C ../e2e-platform push origin main
```

Deregisters from Akuity, removes the Kargo stage + env dir, and deletes the k3d cluster.

## Teardown

```bash
# Remove all Terraform resources + all k3d clusters
make destroy

# Remove a single cluster only
make destroy-cluster CLUSTER_NAME=demo2
```

## Directory structure

```
e2e-infra/
├── Makefile
├── modules/
│   └── cluster/          # reusable module: ArgoCD + Kargo registration per cluster
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   ├── register-cluster.py   # wires a new cluster into the platform repo
│   └── deregister-cluster.py # removes a cluster from the platform repo
└── bootstrap/            # root module: Akuity instances + fleet
    ├── providers.tf
    ├── variables.tf      # clusters = ["demo1", ...]
    ├── main.tf           # ArgoCD + Kargo instances, cluster registrations
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── templates/
        └── kustomization.yaml   # reduces CPU requests for k3d scheduling
```
