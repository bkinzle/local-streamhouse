#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a StarRocks cluster"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://starrocks.github.io/starrocks-kubernetes-operator starrocks kube-starrocks \
  --version 1.11.4 \
  --namespace streamhouse \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
starrocks:
  nameOverride: "starrocks"
  initPassword:
    enabled: true
    password: iWillNeverTell
  timeZone: UTC
  starrocksFESpec:
    replicas: 3
    storageSpec:
      name: front-end
      storageClassName: standard
    resources:
      requests:
        cpu: 1
        memory: 1Gi
      limits:
        cpu: "unlimited"
  starrocksBeSpec:
    replicas: 3
    storageSpec:
      name: back-end
      storageClassName: standard
      storageSize: 15Gi
    resources:
      requests:
        cpu: 1
        memory: 2Gi
      limits:
        cpu: "unlimited"
  starrocksFeProxySpec:
    enabled: true
    resolver: kube-dns.kube-system.svc.cluster.local
EOF

# Endpoint for MySQL clients via the gateway
kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: starrocks
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: starrocks
  rules:
  - backendRefs:
    - name: starrocks-fe-service
      port: 9030
EOF

# Endpoint for external data loading via the gateway
kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: starrocks
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - starrocks.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: starrocks-fe-proxy-service
        port: 8080
EOF

