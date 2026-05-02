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
  default     = "v2.13.4"
}

variable "kargo_instance_name" {
  description = "Name for the Kargo instance on Akuity Platform"
  type        = string
  default     = "e2e-kargo"
}

variable "kargo_version" {
  description = "Kargo version to deploy"
  type        = string
  default     = "v1.4.0"
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

variable "admin_password" {
  description = "Admin password for both ArgoCD and Kargo"
  type        = string
  sensitive   = true
}
