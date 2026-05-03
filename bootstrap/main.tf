# ── ArgoCD instance ────────────────────────────────────────────────────────────

resource "akp_instance" "argocd" {
  name = var.argocd_instance_name
  argocd = {
    spec = {
      version = var.argocd_version
      instance_spec = {
        declarative_management_enabled = true
      }
    }
  }
  argocd_cm = {
    "accounts.admin" = "apiKey,login"
    "resource.customizations.health.argoproj.io_Application" = <<-EOT
      hs = {}
      hs.status = "Progressing"
      hs.message = ""
      if obj.status ~= nil then
        if obj.status.health ~= nil then
          hs.status = obj.status.health.status
          if obj.status.health.message ~= nil then
            hs.message = obj.status.health.message
          end
        end
      end
      return hs
    EOT
    "resource.customizations.actions.argoproj.io_ApplicationSet" = <<-EOT
      discovery.lua: |
        actions = {}
        actions["refresh"] = {}
        return actions
      definitions:
        - name: refresh
          action.lua: |
            local os = require("os")
            if obj.metadata.annotations == nil then
                obj.metadata.annotations = {}
            end
            obj.metadata.annotations["akuity.io/refreshedAt"] = os.date("!%Y-%m-%dT%XZ")
            return obj
    EOT
  }
  argocd_secret = {
    "admin.password" = bcrypt(var.admin_password)
  }
  lifecycle {
    # bcrypt produces a different hash on each plan; ignore to avoid perpetual drift
    ignore_changes = [argocd_secret]
  }
}

# ── Kargo instance ─────────────────────────────────────────────────────────────

resource "akp_kargo_instance" "kargo" {
  name      = var.kargo_instance_name
  workspace = "default"
  kargo = {
    spec = {
      version             = var.kargo_version
      kargo_instance_spec = {
        promo_controller_enabled = true
      }
    }
  }
  kargo_cm = {
    adminAccountEnabled  = "true"
    adminAccountTokenTtl = "24h"
  }
  kargo_secret = {
    adminAccountPasswordHash = bcrypt(var.admin_password)
  }
  lifecycle {
    ignore_changes = [kargo.spec.version, kargo_secret]
  }
}

# ── Register Kargo control plane in ArgoCD ─────────────────────────────────────
# Gives ArgoCD declarative write access to the Kargo instance so that
# e2e-platform can manage Kargo projects via GitOps.

resource "akp_cluster" "kargo" {
  instance_id = akp_instance.argocd.id
  name        = "kargo"
  namespace   = "akuity"
  spec = {
    data = {
      direct_cluster_spec = {
        kargo_instance_id = akp_kargo_instance.kargo.id
        cluster_type      = "kargo"
      }
      size = "small"
    }
  }
  depends_on = [akp_kargo_instance.kargo, akp_instance.argocd]
}

# ── Clusters ───────────────────────────────────────────────────────────────────
# One module instance per cluster. Add a name to var.clusters and run
# `make add-cluster CLUSTER_NAME=<name>` to expand the fleet.

module "cluster" {
  for_each = var.clusters
  source   = "../modules/cluster"

  name               = each.key
  kubeconfig_path    = "${path.module}/.kubeconfigs/${each.key}.yaml"
  kustomization_path = "${path.module}/templates/kustomization.yaml"
  argocd_instance_id = akp_instance.argocd.id
  kargo_instance_id  = akp_kargo_instance.kargo.id

  depends_on = [akp_instance.argocd, akp_kargo_instance.kargo]
}

# ── Kargo default shard ────────────────────────────────────────────────────────

resource "akp_kargo_default_shard_agent" "default" {
  kargo_instance_id = akp_kargo_instance.kargo.id
  agent_id          = module.cluster[var.default_shard].kargo_agent_id
  depends_on        = [module.cluster]
}
