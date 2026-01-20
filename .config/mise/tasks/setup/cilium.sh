#!/usr/bin/env bash
set -euo pipefail

#MISE description="Install Cilium CNI as replacement for kube-proxy with Hubble UI enabled (for more parity with GKE's default CNI)"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://helm.cilium.io cilium cilium \
  --version 1.19.0-rc.0 \
  --namespace kube-system \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
kubeProxyReplacement: true
k8sServiceHost: "${STACK_NAME}-control-plane"
k8sServicePort: "6443"
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
EOF

# Moved creation of hubble-ui route to a later task after the Gateway API CRDs are installed
