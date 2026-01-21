#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up both an externally accessible, stable Kafka Cluster and a dynamically scalable, chaos Kafka Cluster"
#MISE depends=["check:kubecontext"]

# The chaos kafka cluster
kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: kraft-controller-pool-a
  labels:
    strimzi.io/cluster: chaos-kafka
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
            strimzi.io/cluster: chaos-kafka
            strimzi.io/controller-role: "true"
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker-pool-a
  labels:
    strimzi.io/cluster: chaos-kafka
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
            strimzi.io/cluster: chaos-kafka
            strimzi.io/broker-role: "true"
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker-pool-b
  labels:
    strimzi.io/cluster: chaos-kafka
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
            strimzi.io/cluster: chaos-kafka
            strimzi.io/broker-role: "true"
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: chaos-kafka
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

# The stable kafka cluster
kubectl apply -n streamhouse -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kafka-listeners-cert
spec:
  secretName: kafka-listeners-tls
  privateKey:
    algorithm: RSA
    encoding: PKCS8
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
    - "bootstrap.stable-kafka.${DNSMASQ_DOMAIN}"
    - "0.stable-kafka.${DNSMASQ_DOMAIN}"
    - "1.stable-kafka.${DNSMASQ_DOMAIN}"
    - "2.stable-kafka.${DNSMASQ_DOMAIN}"
    - "*.stable-kafka.${DNSMASQ_DOMAIN}"
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
EOF

while ! kubectl get secret kafka-listeners-tls -n streamhouse &>/dev/null; do echo "Waiting for kafka-listeners-tls secret. CTRL-C to exit."; sleep 1; done

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: kraft-controller-pool
  labels:
    strimzi.io/cluster: stable-kafka
spec:
  replicas: 2
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
            strimzi.io/cluster: stable-kafka
            strimzi.io/controller-role: "true"
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker-pool
  labels:
    strimzi.io/cluster: stable-kafka
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
            strimzi.io/cluster: stable-kafka
            strimzi.io/broker-role: "true"
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: stable-kafka
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
      - name: external
        port: 9094
        type: cluster-ip
        tls: true
        configuration:
          brokerCertChainAndKey:
            secretName: kafka-listeners-tls
            certificate: tls.crt
            key: tls.key
          bootstrap:
            alternativeNames:
              - bootstrap.stable-kafka.${DNSMASQ_DOMAIN}
          brokers:
          - broker: 0
            advertisedHost: 0.stable-kafka.${DNSMASQ_DOMAIN}
          - broker: 1
            advertisedHost: 1.stable-kafka.${DNSMASQ_DOMAIN}
          - broker: 2
            advertisedHost: 2.stable-kafka.${DNSMASQ_DOMAIN}
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
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: stable-kafka-kafka-external-bootstrap
spec:
  hostnames:
  - bootstrap.stable-kafka.${DNSMASQ_DOMAIN}
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: kafka
  rules:
  - backendRefs:
    - name: stable-kafka-kafka-external-bootstrap
      kind: Service
      port: 9094
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: stable-kafka-broker-pool-0
spec:
  hostnames:
  - 0.stable-kafka.${DNSMASQ_DOMAIN}
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: kafka
  rules:
  - backendRefs:
    - name: stable-kafka-broker-pool-0
      kind: Service
      port: 9094
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: stable-kafka-broker-pool-1
spec:
  hostnames:
  - 1.stable-kafka.${DNSMASQ_DOMAIN}
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: kafka
  rules:
  - backendRefs:
    - name: stable-kafka-broker-pool-1
      kind: Service
      port: 9094
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: stable-kafka-broker-pool-2
spec:
  hostnames:
  - 2.stable-kafka.${DNSMASQ_DOMAIN}
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: kafka
  rules:
  - backendRefs:
    - name: stable-kafka-broker-pool-2
      kind: Service
      port: 9094
EOF

# Export the TLS certs for local use
kubectl -n streamhouse get secret kafka-listeners-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > .ssl/kafka-ca.crt
kubectl -n streamhouse get secret kafka-listeners-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > .ssl/kafka.crt
kubectl -n streamhouse get secret kafka-listeners-tls -o jsonpath='{.data.tls\.key}' | base64 -d > .ssl/kafka.key
