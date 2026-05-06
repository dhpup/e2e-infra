variable "name" {
  description = "Cluster name — must match the k3d cluster and the kubeconfig filename"
  type        = string
}

variable "kubeconfig_path" {
  description = "Absolute or module-relative path to the cluster kubeconfig file"
  type        = string
}

variable "argocd_instance_id" {
  description = "ID of the Akuity ArgoCD instance to register this cluster with"
  type        = string
}

variable "kargo_instance_id" {
  description = "ID of the Akuity Kargo instance to register this cluster with"
  type        = string
}

variable "kustomization_path" {
  description = "Path to kustomization.yaml applied to agent manifests (e.g. to reduce CPU requests)"
  type        = string
}

variable "fleet_enabled" {
  description = "When true, adds fleet=true label so ArgoCD ApplicationSets pick up this cluster for addon deployment"
  type        = bool
  default     = false
}
