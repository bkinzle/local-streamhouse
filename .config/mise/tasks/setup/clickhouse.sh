#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a minimal deployment of the ClickHouse observability stack using ClickStack"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://clickhouse.github.io/ClickStack-helm-charts clickstack clickstack \
  --version 1.1.0 \
  --namespace streamhouse \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
global:
  storageClassName: standard
replicaCount: 3
otel:
  enabled: false
hyperdx:
  frontendUrl: https://clickhouse-hyperdx.localtest.me
  usageStatsEnabled: false
  otelExporterEndpoint: "http://otel-collector-apps-opentelemetry-collector.observability-platform.svc:4328"
EOF

# Make clickhouse externally accessible via the gateway
kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: clickhouse
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: clickhouse
  rules:
  - backendRefs:
    - name: clickstack-clickhouse
      port: 9000
EOF

# hyperdx UI access via the gateway
kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: clickhouse-hyperdx
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - clickhouse-hyperdx.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: clickstack-app
        port: 3000
EOF
