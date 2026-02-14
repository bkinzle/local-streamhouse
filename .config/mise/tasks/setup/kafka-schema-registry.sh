#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a Kafka Schema Registry for each Kafka Cluster"
#MISE depends=["check:kubecontext"]

SCHEMA_REGISTRY_VERSION="26.0.5"

helm upgrade chaos-schema-registry oci://registry-1.docker.io/bitnamicharts/schema-registry \
  --version ${SCHEMA_REGISTRY_VERSION} \
  --namespace kafka-control-plane \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
global:
  security:
    allowInsecureImages: true
image:
  registry: docker.io
  repository: bitnamilegacy/schema-registry
  tag: 8.0.0-debian-12-r5
replicaCount: 2
kafka:
  enabled: false
externalKafka:
  listener:
    protocol: PLAINTEXT
  brokers:
    - "PLAINTEXT://chaos-kafka-kafka-bootstrap.streamhouse.svc.cluster.local:9092"
EOF

helm upgrade stable-schema-registry oci://registry-1.docker.io/bitnamicharts/schema-registry \
  --version ${SCHEMA_REGISTRY_VERSION} \
  --namespace kafka-control-plane \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
global:
  security:
    allowInsecureImages: true
image:
  registry: docker.io
  repository: bitnamilegacy/schema-registry
  tag: 8.0.0-debian-12-r5
replicaCount: 1
kafka:
  enabled: false
externalKafka:
  listener:
    protocol: PLAINTEXT
  brokers:
    - "PLAINTEXT://stable-kafka-kafka-bootstrap.streamhouse.svc.cluster.local:9092"
EOF

kubectl apply -n kafka-control-plane -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: stable-schema-registry
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - schema-registry.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: stable-schema-registry
        port: 8081
EOF
