#!/usr/bin/env bash
set -euo pipefail

#MISE description="Manage a Kafka Cluster"
#MISE depends=["check:kubecontext"]

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: kraft-controller
  labels:
    strimzi.io/cluster: kafka
spec:
  replicas: 3
  roles:
    - controller
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 250Mi
        kraftMetadata: shared
        deleteClaim: false
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker
  labels:
    strimzi.io/cluster: kafka
spec:
  replicas: 4
  roles:
    - broker
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 250Mi
        # Indicates that this directory will be used to store Kraft metadata log
        kraftMetadata: shared
        deleteClaim: false
      - id: 1
        type: persistent-claim
        size: 3Gi
        deleteClaim: false
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: kafka
  annotations:
    strimzi.io/kraft: enabled
    strimzi.io/node-pools: enabled
spec:
  kafka:
    version: ${KAFKA_VERSION}
    metadataVersion: ${KAFKA_MINOR_VERSION}-IV0
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
        configuration:
          useServiceDnsDomain: true
      - name: tls
        port: 9093
        type: internal
        tls: true
        configuration:
          useServiceDnsDomain: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      replica.fetch.max.bytes: 33555555
      message.max.bytes: 33555555
      # auto.create.topics.enable: false
      # delete.topic.enable: true
    jmxOptions: {}
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF