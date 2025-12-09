#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up a Kafka UI"
#MISE depends=["check:kubecontext"]

# Custom build just to add the proto files (the subsequent helm deployment generates the classes from the proto files)
docker build -t localhost:${LOCAL_REGISTRY_PORT}/kafbat/kafka-ui:0.0.0 ${MISE_PROJECT_ROOT}/kafka-ui --push

helm upgrade --repo https://ui.charts.kafbat.io kafka-ui kafka-ui \
  --version 1.5.3 \
  --namespace kafka-control-plane \
  --install \
  --values - <<EOF
replicaCount: 2
image:
  registry: ${LOCAL_REGISTRY_NAME}:${INCLUSTER_REGISTRY_PORT}
  repository: kafbat/kafka-ui
  tag: "0.0.0"
yamlApplicationConfig:
  kafka:
    clusters:
      - name: kafka-kafka
        bootstrapServers: kafka-kafka-bootstrap.streamhouse.svc.cluster.local:9092
        schemaRegistry: http://schema-registry.kafka-control-plane.svc.cluster.local:8081
        metrics:
          port: 9999
          type: JMX
        serde:
          - name: ProtobufFile
            topicKeysPattern: engine-reports-stats|engine-reports-operation-stats
            topicValuesPattern: engine-reports-stats|engine-reports-operation-stats|feature-usage-analytics
            properties:
              protobufFilesDir: "/protos"
              protobufMessageNameForKeyByTopic:
                engine-reports-stats: mdg.engine.proto.ReportKafkaKey
                engine-reports-operation-stats: mdg.engine.proto.ReportKafkaKey
              protobufMessageNameByTopic:
                engine-reports-stats: mdg.engine.proto.StatsKafkaValue
                engine-reports-operation-stats: mdg.engine.proto.StatsKafkaValue
                feature-usage-analytics: mdg.engine.proto.featureusageanalytics.FeatureUsageAnalyticsValue
  auth:
    type: disabled
  management:
    health:
      ldap:
        enabled: false
EOF

kubectl apply -n kafka-control-plane -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kafka-ui
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - kafka-ui.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: kafka-ui
        port: 80
      sessionPersistence:
        sessionName: kafbat-ui
        type: Cookie
        absoluteTimeout: 1h
        cookieConfig:
          lifetimeType: Session
EOF
