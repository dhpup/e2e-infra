#!/usr/bin/env python3
"""
enable-fleet.py CLUSTER_NAME

Adds CLUSTER_NAME to fleet_clusters in bootstrap/terraform.tfvars so that
the next `make infra` applies the fleet=true label and ArgoCD addon
ApplicationSets begin targeting the cluster.

Run this only after `make infra` confirms the Akuity agent is healthy.
"""
import sys, re

cluster = sys.argv[1]
tfvars  = "bootstrap/terraform.tfvars"
txt     = open(tfvars).read()

def _add(m):
    if f'"{cluster}"' in m.group(0):
        return m.group(0)
    inner = m.group(2).rstrip()
    sep   = ", " if inner else ""
    return m.group(1) + inner + sep + f'"{cluster}"' + m.group(3)

txt = re.sub(r'(fleet_clusters\s*=\s*\[)([^\]]*?)(\])', _add, txt)
open(tfvars, "w").write(txt)
print(f"  ✓ terraform.tfvars: added {cluster} to fleet_clusters")
