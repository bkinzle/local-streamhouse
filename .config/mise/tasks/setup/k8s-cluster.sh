#!/usr/bin/env bash
set -euo pipefail

#MISE description="Sets up a local kind kubernetes cluster"

mkdir -p "k8s/.local-registry/localhost:${LOCAL_REGISTRY_PORT}" "k8s/.local-registry/${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}"

cat <<EOF > "k8s/.local-registry/localhost:${LOCAL_REGISTRY_PORT}/hosts.toml"
  [host."http://${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}"]
    skip_verify = true
EOF

cat <<EOF > "k8s/.local-registry/${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}/hosts.toml"
  server = "http://${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}"
  
  [host."http://${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}"]
    capabilities = ["pull", "resolve"]
    skip_verify = true
EOF

mkdir -p k8s/.cluster-config
envsubst < ./k8s/kind-config.yaml > k8s/.cluster-config/kind-config.yaml
kind create cluster --name ${STACK_NAME} --config k8s/.cluster-config/kind-config.yaml
