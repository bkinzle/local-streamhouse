#!/usr/bin/env bash
set -euo pipefail

#MISE description="Manage Kafka Topics in both the stable and chaos Kafka Clusters"
#MISE depends=["check:kubecontext"]

# Topics for the chaos-kafka cluster
kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: chaos-kafka-engine-reports-stats
  labels:
    strimzi.io/cluster: chaos-kafka
spec:
  topicName: engine-reports-stats
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
  name: chaos-kafka-engine-reports-operation-stats
  labels:
    strimzi.io/cluster: chaos-kafka
spec:
  topicName: engine-reports-operation-stats
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
  name: chaos-kafka-feature-usage-analytics
  labels:
    strimzi.io/cluster: chaos-kafka
spec:
  topicName: feature-usage-analytics
  partitions: 3
  replicas: 3
  config:
    retention.ms: 60000
    cleanup.policy: delete
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: chaos-kafka-product-feature-usage-events
  labels:
    strimzi.io/cluster: chaos-kafka
spec:
  topicName: product-feature-usage-events
  partitions: 3
  replicas: 3
  config:
    retention.ms: 120000
    cleanup.policy: delete
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: chaos-kafka-user-session-feature-activity
  labels:
    strimzi.io/cluster: chaos-kafka
spec:
  topicName: user-session-feature-activity
  partitions: 3
  replicas: 3
  config:
    retention.ms: 180000
    cleanup.policy: delete
EOF

# Topics for the stable-kafka cluster
kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: stable-kafka-engine-reports-stats
  labels:
    strimzi.io/cluster: stable-kafka
spec:
  topicName: engine-reports-stats
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
  name: stable-kafka-engine-reports-operation-stats
  labels:
    strimzi.io/cluster: stable-kafka
spec:
  topicName: engine-reports-operation-stats
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
  name: stable-kafka-feature-usage-analytics
  labels:
    strimzi.io/cluster: stable-kafka
spec:
  topicName: feature-usage-analytics
  partitions: 3
  replicas: 3
  config:
    retention.ms: 60000
    cleanup.policy: delete
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: stable-kafka-product-feature-usage-events
  labels:
    strimzi.io/cluster: stable-kafka
spec:
  topicName: product-feature-usage-events
  partitions: 3
  replicas: 3
  config:
    retention.ms: 180000
    cleanup.policy: delete
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: stable-kafka-user-session-feature-activity
  labels:
    strimzi.io/cluster: stable-kafka
spec:
  topicName: user-session-feature-activity
  partitions: 3
  replicas: 3
  config:
    retention.ms: 180000
    cleanup.policy: delete
EOF
