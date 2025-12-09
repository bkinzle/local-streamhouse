#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a Kafka Schema Registry"
#MISE depends=["check:kubecontext"]

helm upgrade schema-registry oci://registry-1.docker.io/bitnamicharts/schema-registry \
  --version 26.0.5 \
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
    - "PLAINTEXT://kafka-kafka-bootstrap.streamhouse.svc.cluster.local:9092"
EOF
