#!/usr/bin/env bash

#MISE description="Set up the OpenObserve platform (an open source Datadog alternative) and OpenTelemetry Collectors"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://charts.openobserve.ai openobserve openobserve \
  --version 0.20.1 \
  --namespace observability-platform \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --timeout 10m0s \
  --values - <<EOF
auth:
  ZO_S3_ACCESS_KEY: "minio"
  ZO_S3_SECRET_KEY: "minio123"
config:
  ZO_S3_SERVER_URL: http://minio.streamhouse.svc
  ZO_S3_BUCKET_NAME: openobserve
  ZO_S3_REGION_NAME: us-east-1
  ZO_S3_PROVIDER: minio
EOF

kubectl apply -n observability-platform -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: openobserve
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - openobserve.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: openobserve-router
        port: 5080
EOF

kubectl apply -n observability-platform -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: openobserve-grpc
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - openobserve-grpc.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: openobserve-router
        port: 5081
EOF
