#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a local oci artifact registry"
#MISE depends=["check:kubecontext"]

docker run \
  -d --restart=always -p "127.0.0.1:${LOCAL_REGISTRY_PORT}:${INCLUSTER_REGISTRY_PORT}" --name "${LOCAL_REGISTRY_NAME}" \
  -e REGISTRY_HTTP_ADDR=:${INCLUSTER_REGISTRY_PORT} \
  registry:3

# connect the registry to the cluster network
docker network connect "kind" "${LOCAL_REGISTRY_NAME}"

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
