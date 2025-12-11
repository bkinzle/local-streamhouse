#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a local oci artifact registry"
#MISE depends=["check:kubecontext"]

# Only create and start the registry container if it doesn't exist or isn't running
if ! docker ps -a --format '{{.Names}}' | grep -q "^${LOCAL_REGISTRY_NAME}$"; then
  docker run \
    -d --restart=always -p "127.0.0.1:${LOCAL_REGISTRY_PORT}:${INCLUSTER_REGISTRY_PORT}" --name "${LOCAL_REGISTRY_NAME}" \
    -e REGISTRY_HTTP_ADDR=:${INCLUSTER_REGISTRY_PORT} \
    registry:3

  # connect the registry to the cluster network
  docker network connect "kind" "${LOCAL_REGISTRY_NAME}"
elif ! docker ps --format '{{.Names}}' | grep -q "^${LOCAL_REGISTRY_NAME}$"; then
  echo "Container '${LOCAL_REGISTRY_NAME}' exists but is stopped, starting it..."
  docker start "${LOCAL_REGISTRY_NAME}"
else
  echo "Container '${LOCAL_REGISTRY_NAME}' is already running"
fi

# document the local registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${LOCAL_REGISTRY_PORT}"
    hostFromContainerRuntime: "${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}"
    hostFromClusterNetwork: "${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
