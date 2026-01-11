#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up cloud-native postgres operator and Atlas operator for declarative database schema management"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://cloudnative-pg.github.io/charts cnpg cloudnative-pg \
  --version 0.26.1 \
  --namespace postgres-control-plane \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
config:
  data:
    WATCH_NAMESPACE: streamhouse,observability-platform
EOF

helm upgrade atlas-operator oci://ghcr.io/ariga/charts/atlas-operator \
  --version 0.7.15 \
  --namespace postgres-control-plane \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail
