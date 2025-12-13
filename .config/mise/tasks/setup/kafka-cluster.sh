#!/usr/bin/env bash
set -euo pipefail

#MISE description="Manage a Kafka Cluster"
#MISE depends=["check:kubecontext"]

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: kraft-controller-pool-a
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
  template:
    pod:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            strimzi.io/cluster: kafka
            strimzi.io/controller-role: "true"
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker-pool-a
  labels:
    strimzi.io/cluster: kafka
spec:
  replicas: 3
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
  template:
    pod:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            strimzi.io/cluster: kafka
            strimzi.io/broker-role: "true"
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker-pool-b
  labels:
    strimzi.io/cluster: kafka
spec:
  replicas: 2
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
  template:
    pod:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            strimzi.io/cluster: kafka
            strimzi.io/broker-role: "true"
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
      # This replica selector plugin enables consumers to fetch from closest replica (not just the leader)
      # In addition to the broker configuration, you also need to specify the client.rack option in your consumers
      replica.selector.class: org.apache.kafka.common.replica.RackAwareReplicaSelector
    jmxOptions: {}
    # Broker pods use init containers to collect the topology label from the k8s cluster nodes and assigns a rack ID to each broker
    # Brokers will spread partition replicas across as many different racks as possible, improving resiliency, availability and reliability
    rack:
      topologyKey: topology.kubernetes.io/zone
  entityOperator:
    topicOperator: {}
    userOperator: {}
  kafkaExporter:
    topicRegex: ".*"
    groupRegex: ".*"
  # cruiseControl:
EOF
