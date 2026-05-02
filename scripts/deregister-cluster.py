#!/usr/bin/env python3
"""
deregister-cluster.py CLUSTER_NAME PLATFORM_REPO_PATH

Reverses register-cluster.py:
  1. Removes CLUSTER_NAME from bootstrap/terraform.tfvars
  2. Removes env/prod-CLUSTER_NAME/ directory
  3. Removes prod-CLUSTER_NAME Stage from stages.yaml
  4. Removes prod-CLUSTER_NAME policy from project.yaml
"""
import sys, re, os, shutil

cluster  = sys.argv[1]
platform = os.path.abspath(sys.argv[2])

# ── 1. terraform.tfvars ───────────────────────────────────────────────────────

tfvars = "bootstrap/terraform.tfvars"
txt = open(tfvars).read()
txt = re.sub(r',\s*"' + re.escape(cluster) + '"', '', txt)   # trailing entry
txt = re.sub(r'"' + re.escape(cluster) + '"\s*,\s*', '', txt) # leading entry
txt = re.sub(r'"' + re.escape(cluster) + '"', '', txt)         # only entry
open(tfvars, "w").write(txt)
print(f"  ✓ terraform.tfvars: removed {cluster}")

# ── 2. env directory ──────────────────────────────────────────────────────────

target = os.path.join(platform, "apps/team-daniel/env", f"prod-{cluster}")
if os.path.exists(target):
    shutil.rmtree(target)
    print(f"  ✓ env/prod-{cluster}/ removed")
else:
    print(f"  - env/prod-{cluster}/ not found, skipping")

# ── 3. stages.yaml ────────────────────────────────────────────────────────────

stages_path = os.path.join(platform, "apps/team-daniel/kargo/stages.yaml")
txt = open(stages_path).read()

# Split on document boundaries, filter out the target stage, reassemble
docs = re.split(r'(?:^|\n\n)---\n', txt)
docs = [d for d in docs if d.strip() and f'name: prod-{cluster}' not in d]
txt = '---\n' + '\n\n---\n'.join(docs)

open(stages_path, "w").write(txt)
print(f"  ✓ stages.yaml: removed prod-{cluster} stage")

# ── 4. project.yaml ───────────────────────────────────────────────────────────

project_path = os.path.join(platform, "apps/team-daniel/kargo/project.yaml")
txt = open(project_path).read()
txt = re.sub(
    r'  - stageSelector:\n      name: prod-' + re.escape(cluster) + r'\n    autoPromotionEnabled: false\n',
    '',
    txt
)
open(project_path, "w").write(txt)
print(f"  ✓ project.yaml: removed prod-{cluster} policy")
