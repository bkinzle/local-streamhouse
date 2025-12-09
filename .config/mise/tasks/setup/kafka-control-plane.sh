#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up Strimzi's Kafka Cluster Operator and CRDs"
#MISE depends=["check:kubecontext"]

# Simulate real world usage by installing CRDs separately and then the operator without CRD installation
kubectl apply --namespace kube-system --server-side -f <(
  gh release download --repo strimzi/strimzi-kafka-operator --pattern 'strimzi-crds-*.yaml' ${STRIMZI_VERSION} -O -
)

helm upgrade strimzi-kafka-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version ${STRIMZI_VERSION} \
  --namespace kafka-control-plane \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --skip-crds \
  --values - <<EOF
replicas: 2
watchNamespaces:
  - streamhouse
image:
  imagePullPolicy: Always
resources:
  limits:
    memory: 900Mi
generateNetworkPolicy: false
fullReconciliationIntervalMs: 20000
EOF
