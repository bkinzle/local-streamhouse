#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up Apache Flink Kubernetes Operator and CRDs"
#MISE depends=["check:kubecontext"]

# Ensure the kustomize post-renderer plugin is installed (idempotent)
if ! helm plugin list | grep -q kustomize-renderer; then
  helm plugin install "$MISE_PROJECT_ROOT/.helm-plugins/kustomize-renderer"
fi

helm upgrade --repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.13.0 flink-kubernetes-operator flink-kubernetes-operator \
  --namespace flink-control-plane \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --post-renderer kustomize-renderer \
  --post-renderer-args "$MISE_PROJECT_ROOT/kustomize/flink-control-plane" \
  --values - <<EOF
watchNamespaces:
- streamhouse
replicas: 2
strategy:
  # the chart default is Recreate, but RollingUpdate is more suitable when leader election is enabled and will cause less downtime during updates
  type: RollingUpdate
operatorPod:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: flink-kubernetes-operator
defaultConfiguration:
  create: true
  append: true  # loads the built-in default configs (https://github.com/apache/flink-kubernetes-operator/tree/main/helm/flink-kubernetes-operator/conf)
  # Use the new config.yaml format rather than flink-config.yaml
  config.yaml: |+
    # Flink Config Overrides (set in the Operator's helm chart)
    kubernetes.operator:
      # Enable leader election for the operator, which allows for multiple replicas to be deployed with high availability
      leader-election.enabled: true
      leader-election.lease-name: flink-operator-lease  # name for the Kubernetes Lease object used to coordinate leadership
      metrics.reporter.slf4j:
        factory.class: org.apache.flink.metrics.slf4j.Slf4jReporterFactory
        interval: 1 MINUTE
      reconcile.interval: 15 s
      observer.progress-check.interval: 5 s
  log4j-operator.properties: |+
    # Flink Operator Logging Overrides (set in the Operator's helm chart)
    rootLogger.level = INFO
  log4j-console.properties: |+
    # Flink Deployment Logging Overrides (set in the Operator's helm chart)
    rootLogger.level = INFO
EOF
