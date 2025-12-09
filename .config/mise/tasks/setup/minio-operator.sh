#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a MinIO Operator"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://operator.min.io operator operator \
  --version ${MINIO_HELM_VERSION} \
  --namespace minio-operator \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
operator:
  env:
    - name: OPERATOR_STS_AUTO_TLS_ENABLED
      value: "off"
    - name: OPERATOR_STS_ENABLED
      value: "on"
    - name: WATCHED_NAMESPACE
      value: "streamhouse"
EOF
