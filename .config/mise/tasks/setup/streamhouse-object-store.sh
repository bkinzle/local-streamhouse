#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up an object store datalake implemented with a MinIO Tenant"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://operator.min.io tenant tenant \
  --version ${MINIO_HELM_VERSION} \
  --namespace streamhouse \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
tenant:
  name: minio-datalake
  pools:
    - name: pool-0
      servers: 4
      size: 250Mi
      volumesPerServer: 4
  buckets:
    - name: zone-0-bronze
    - name: zone-1-silver
    - name: zone-2-gold
    - name: openobserve
  certificate:
    requestAutoCert: false
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: datalake
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - datalake.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: minio-datalake-console
        port: 9090
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: datalake-api
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
  hostnames:
    - datalake-api.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: minio
        port: 80
EOF
