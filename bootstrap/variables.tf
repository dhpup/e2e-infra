variable "org_name" {
  description = "Akuity Platform organization name"
  type        = string
}

variable "argocd_instance_name" {
  description = "Name for the ArgoCD instance on Akuity Platform"
  type        = string
  default     = "e2e-argocd"
}

variable "argocd_version" {
  description = "ArgoCD version to deploy"
  type        = string
  default     = "v3.3.9-ak.87"
}

variable "kargo_instance_name" {
  description = "Name for the Kargo instance on Akuity Platform"
  type        = string
  default     = "e2e-kargo"
}

variable "kargo_version" {
  description = "Kargo version to deploy"
  type        = string
  default     = "v1.10.1-ak.0"
}

variable "clusters" {
  description = <<-EOT
    Set of cluster names to register with ArgoCD and Kargo.
    Each name must match a k3d cluster and have a kubeconfig at
    bootstrap/.kubeconfigs/<name>.yaml (written by `make kubeconfig CLUSTER_NAME=<name>`).
  EOT
  type        = set(string)
  default     = ["demo1"]
}

variable "default_shard" {
  description = "Which cluster to use as the Kargo default shard. Must be in var.clusters."
  type        = string
  default     = "demo1"
}

variable "fleet_clusters" {
  description = <<-EOT
    Subset of var.clusters that should receive the fleet=true label, enabling
    ArgoCD ApplicationSet addon deployment. Add a cluster here only after
    confirming its Akuity agent is healthy (run `make infra` first without it,
    then `make enable-fleet CLUSTER_NAME=<name>`).
  EOT
  type        = set(string)
  default     = []
}

variable "admin_password" {
  description = "Admin password for both ArgoCD and Kargo"
  type        = string
  sensitive   = true
}
