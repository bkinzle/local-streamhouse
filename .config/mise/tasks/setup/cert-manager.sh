#!/usr/bin/env bash

#MISE description="Set up cert-manager, create a Secret for root CA, and a ClusterIssuer from the secret"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://charts.jetstack.io jetstack cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
crds:
  enabled: true
EOF
