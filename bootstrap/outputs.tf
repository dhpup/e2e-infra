output "argocd_url" {
  description = "ArgoCD UI URL (Akuity-provided subdomain)"
  value       = "https://${akp_instance.argocd.id}.cd.akuity.cloud"
}

output "kargo_url" {
  description = "Kargo UI URL (Akuity-provided subdomain)"
  value       = "https://${akp_kargo_instance.kargo.id}.kargo.akuity.cloud"
}

output "argocd_instance_id" {
  description = "Akuity ArgoCD instance ID"
  value       = akp_instance.argocd.id
}

output "kargo_instance_id" {
  description = "Akuity Kargo instance ID"
  value       = akp_kargo_instance.kargo.id
}
