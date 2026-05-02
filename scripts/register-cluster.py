#!/usr/bin/env python3
"""
register-cluster.py CLUSTER_NAME PLATFORM_REPO_PATH

Idempotently wires a new fleet cluster into the platform repo:
  1. Adds CLUSTER_NAME to bootstrap/terraform.tfvars
  2. Copies env/prod-demo1/ -> env/prod-CLUSTER_NAME/ (template)
  3. Appends a prod-CLUSTER_NAME Stage to stages.yaml
  4. Appends a prod-CLUSTER_NAME policy to project.yaml
"""
import sys, re, os, shutil, textwrap

cluster  = sys.argv[1]
platform = os.path.abspath(sys.argv[2])

# ── 1. terraform.tfvars ───────────────────────────────────────────────────────

tfvars = "bootstrap/terraform.tfvars"
txt = open(tfvars).read()

def _add(m):
    if f'"{cluster}"' in m.group(0):
        return m.group(0)
    inner = m.group(2).rstrip()
    sep   = ", " if inner else ""
    return m.group(1) + inner + sep + f'"{cluster}"' + m.group(3)

txt = re.sub(r'(clusters\s*=\s*\[)([^\]]*?)(\])', _add, txt)
open(tfvars, "w").write(txt)
print(f"  ✓ terraform.tfvars: added {cluster}")

# ── 2. env directory ──────────────────────────────────────────────────────────

env_base = os.path.join(platform, "apps/team-daniel/env")
target   = os.path.join(env_base, f"prod-{cluster}")
template = os.path.join(env_base, "prod-demo1")

if os.path.exists(target):
    print(f"  - env/prod-{cluster}/ already exists, skipping")
else:
    shutil.copytree(template, target)
    print(f"  ✓ env/prod-{cluster}/ created from prod-demo1 template")

# ── 3. stages.yaml ────────────────────────────────────────────────────────────

stages_path = os.path.join(platform, "apps/team-daniel/kargo/stages.yaml")
stages_txt  = open(stages_path).read()

if f"name: prod-{cluster}" in stages_txt:
    print(f"  - prod-{cluster} already in stages.yaml, skipping")
else:
    stage = textwrap.dedent(f"""\

        ---
        apiVersion: kargo.akuity.io/v1alpha1
        kind: Stage
        metadata:
          name: prod-{cluster}
          namespace: team-daniel
          annotations:
            argocd.argoproj.io/sync-wave: "2"
            kargo.akuity.io/color: green
            kargo.akuity.io/argocd-context: '[{{"name":"team-daniel-prod-{cluster}","namespace":"argocd"}}]'
        spec:
          requestedFreight:
          - origin:
              kind: Warehouse
              name: guestbook
            sources:
              stages:
              - dev
          - origin:
              kind: Warehouse
              name: features
            sources:
              stages:
              - dev
          promotionTemplate:
            spec:
              steps:
              - if: ${{{{ ctx.targetFreight.origin.name == "guestbook" }}}}
                task:
                  name: provision-backend
              - task:
                  name: promote-guestbook
        """)
    open(stages_path, "a").write(stage)
    print(f"  ✓ stages.yaml: appended prod-{cluster} stage")

# ── 4. project.yaml ───────────────────────────────────────────────────────────

project_path = os.path.join(platform, "apps/team-daniel/kargo/project.yaml")
project_txt  = open(project_path).read()

if f"name: prod-{cluster}" in project_txt:
    print(f"  - prod-{cluster} already in project.yaml, skipping")
else:
    policy = (
        f"  - stageSelector:\n"
        f"      name: prod-{cluster}\n"
        f"    autoPromotionEnabled: false\n"
    )
    open(project_path, "a").write(policy)
    print(f"  ✓ project.yaml: added prod-{cluster} promotion policy")
