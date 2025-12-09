#!/usr/bin/env bash
set -euo pipefail

#MISE description="Sets up a Kubernetes Metrics Server"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://kubernetes-sigs.github.io/metrics-server/ metrics-server metrics-server \
  --version 3.13.0 \
  --namespace kube-system \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
metrics:
  enabled: true
apiService:
  caBundle: 
args:
- --kubelet-insecure-tls
EOF
