# e2e-infra

Bootstraps the full local demo environment in one command. Uses k3d (local Kubernetes in Docker) instead of EKS — no AWS account required. Clusters are modular — add more to the fleet without touching instance config.

## What it creates

| Resource | Tool | Details |
|---|---|---|
| k3d cluster(s) | k3d | Local Kubernetes clusters in Docker |
| ArgoCD instance | Akuity Platform (Terraform) | Hosted ArgoCD, declarative management enabled |
| Kargo instance | Akuity Platform (Terraform) | Hosted Kargo control plane |
| ArgoCD agent(s) | Akuity Platform (Terraform) | One per cluster, `size=small` |
| Kargo agent(s) | Akuity Platform (Terraform) | One per cluster, self-hosted, linked to ArgoCD |

## Prerequisites

- [`k3d`](https://k3d.io) — `brew install k3d`
- [`terraform`](https://developer.hashicorp.com/terraform) >= 1.5 — `brew install terraform`
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

## Adding a cluster to the fleet

```bash
# 1. Create the cluster and write its kubeconfig
make add-cluster CLUSTER_NAME=my-second-cluster

# 2. Add it to bootstrap/terraform.tfvars:
#    clusters = ["demo1", "my-second-cluster"]

# 3. Apply
make infra
```

## Teardown

```bash
# Remove all Terraform resources (Akuity instances + cluster registrations)
make destroy-infra

# Delete a specific k3d cluster
make destroy-cluster CLUSTER_NAME=demo1
```

## Directory structure

```
e2e-infra/
├── Makefile
├── modules/
│   └── cluster/          # reusable module: one ArgoCD + Kargo registration per cluster
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── bootstrap/            # root module: instances + fleet
    ├── providers.tf
    ├── variables.tf      # clusters = ["demo1", ...]
    ├── main.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── templates/
        └── kustomization.yaml   # reduces CPU requests for k3d scheduling
```
