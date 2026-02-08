#!/usr/bin/env bash
set -euo pipefail

# Helm 4 post-renderer plugin: applies kustomize patches to rendered manifests.
# Usage: --post-renderer kustomize-renderer --post-renderer-args <kustomize-dir>
#
# The kustomize directory must contain a kustomization.yaml that references
# "helm-output.yaml" as a resource (this script writes stdin there temporarily and then cleans it up).

KUSTOMIZE_DIR="${1:?Usage: --post-renderer-args <kustomize-dir>}"

# Write Helm's rendered output as a kustomize resource
cat > "$KUSTOMIZE_DIR/helm-output.yaml"
trap 'rm -f "$KUSTOMIZE_DIR/helm-output.yaml"' EXIT

kubectl kustomize "$KUSTOMIZE_DIR"
