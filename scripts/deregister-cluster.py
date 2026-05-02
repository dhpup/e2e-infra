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
txt = re.sub(r',\s*"' + re.escape(cluster) + '"', '', txt)    # trailing entry
txt = re.sub(r'"' + re.escape(cluster) + '"\s*,\s*', '', txt)  # leading entry
txt = re.sub(r'"' + re.escape(cluster) + '"', '', txt)          # only entry
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
#
# Split line-by-line into YAML documents (boundaries are bare "---" lines).
# Filter out the document that is a Stage with metadata.name == prod-{cluster}.
# This avoids any regex sensitivity to blank-line count between documents.

stages_path = os.path.join(platform, "apps/team-daniel/kargo/stages.yaml")
lines = open(stages_path).readlines()

# Group lines into documents; each doc starts at a "---" line.
docs = []
current = []
for line in lines:
    if line.rstrip() == "---":
        if current:
            docs.append(current)
        current = [line]
    else:
        current.append(line)
if current:
    docs.append(current)

def is_target_stage(doc_lines):
    text = "".join(doc_lines)
    return (
        "kind: Stage" in text
        and bool(re.search(r"^\s+name:\s+prod-" + re.escape(cluster) + r"\s*$", text, re.MULTILINE))
    )

kept = [doc for doc in docs if not is_target_stage(doc)]

if len(kept) == len(docs):
    print(f"  - prod-{cluster} not found in stages.yaml, skipping")
else:
    # Reassemble: join docs, separated by a blank line between each
    result_lines = []
    for i, doc in enumerate(kept):
        result_lines.extend(doc)
        if i < len(kept) - 1:
            # Ensure exactly one blank line between documents
            if result_lines and result_lines[-1].strip():
                result_lines.append("\n")
    open(stages_path, "w").writelines(result_lines)
    print(f"  ✓ stages.yaml: removed prod-{cluster} stage")

# ── 4. project.yaml ───────────────────────────────────────────────────────────

project_path = os.path.join(platform, "apps/team-daniel/kargo/project.yaml")
txt = open(project_path).read()
txt = re.sub(
    r"  - stageSelector:\n      name: prod-" + re.escape(cluster) + r"\n    autoPromotionEnabled: false\n",
    "",
    txt,
)
open(project_path, "w").write(txt)
print(f"  ✓ project.yaml: removed prod-{cluster} policy")
