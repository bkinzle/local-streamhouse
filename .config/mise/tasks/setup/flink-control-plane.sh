#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up Apache Flink Kubernetes Operator and CRDs"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.13.0 flink-kubernetes-operator flink-kubernetes-operator \
  --namespace flink-control-plane \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
replicas: 2
EOF
