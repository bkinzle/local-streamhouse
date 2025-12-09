#!/usr/bin/env bash
set -euo pipefail

#MISE description="Manage Kafka Topics"
#MISE depends=["check:kubecontext"]

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: engine-reports-stats
  labels:
    strimzi.io/cluster: kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 259200000
    cleanup.policy: delete
    max.message.bytes: 33555555
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: engine-reports-operation-stats
  labels:
    strimzi.io/cluster: kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 259200000
    cleanup.policy: delete
    max.message.bytes: 33555555
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: feature-usage-analytics
  labels:
    strimzi.io/cluster: kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 60000
    cleanup.policy: delete
EOF