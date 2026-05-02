# k3d binds its API server to 0.0.0.0 inside Docker; rewrite to 127.0.0.1
# so the Terraform provider can reach it from the Mac host.
locals {
  kubeconfig = yamldecode(file(var.kubeconfig_path))
  host       = replace(local.kubeconfig.clusters[0].cluster.server, "0.0.0.0", "127.0.0.1")
  ca         = local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  cert       = local.kubeconfig.users[0].user["client-certificate-data"]
  key        = local.kubeconfig.users[0].user["client-key-data"]

  kube_config = {
    host                   = local.host
    cluster_ca_certificate = base64decode(local.ca)
    client_certificate     = base64decode(local.cert)
    client_key             = base64decode(local.key)
  }
}

# Register cluster with ArgoCD — the provider installs the Akuity agent into
# the cluster via the supplied kubeconfig.
resource "akp_cluster" "this" {
  instance_id = var.argocd_instance_id
  name        = var.name
  namespace   = "akuity"
  labels = {
    fleet = "true"
  }
  spec = {
    data = {
      size          = "small"
      kustomization = file(var.kustomization_path)
    }
  }
  kube_config    = local.kube_config
  ensure_healthy = true
}

# Register Kargo agent — self-hosted, runs inside this cluster.
# remote_argocd links Kargo promotions to ArgoCD syncs.
resource "akp_kargo_agent" "this" {
  instance_id                 = var.kargo_instance_id
  workspace                   = "default"
  name                        = var.name
  namespace                   = "akuity"
  reapply_manifests_on_update = true
  spec = {
    description = "k3d cluster: ${var.name}"
    data = {
      size           = "small"
      akuity_managed = false
      remote_argocd  = var.argocd_instance_id
    }
  }
  kube_config = local.kube_config
  depends_on  = [akp_cluster.this]
}
