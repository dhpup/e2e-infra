output "argocd_cluster_id" {
  description = "ArgoCD cluster registration ID"
  value       = akp_cluster.this.id
}

output "kargo_agent_id" {
  description = "Kargo agent ID — used to set the default shard"
  value       = akp_kargo_agent.this.id
}
