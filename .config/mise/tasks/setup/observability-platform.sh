#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up the OpenObserve platform (an open source Datadog alternative) and OpenTelemetry Collectors"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://charts.openobserve.ai openobserve openobserve \
  --version 0.40.2 \
  --namespace observability-platform \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --timeout 10m0s \
  --values - <<EOF
replicaCount:
  ingester: 2
  querier: 2
  router: 1
  alertmanager: 1
  alertquerier: 0
  compactor: 2
  zplane: 0
  reportserver: 0
  actions: 1
postgres:
  enabled: false
auth:
  ZO_S3_ACCESS_KEY: "minio"
  ZO_S3_SECRET_KEY: "minio123"
  ZO_META_POSTGRES_DSN: "postgres://openobserve_admin:iWillNeverTell@${PG_CLUSTER_NAME}-rw.streamhouse.svc:5432/openobserve"
  OPENFGA_DATASTORE_URI: "postgres://openobserve_admin:iWillNeverTell@${PG_CLUSTER_NAME}-rw.streamhouse.svc:5432/openobserve"
config:
  ZO_S3_SERVER_URL: http://minio.streamhouse.svc
  ZO_S3_BUCKET_NAME: openobserve
  ZO_S3_REGION_NAME: us-east-1
  ZO_S3_PROVIDER: minio
EOF

kubectl apply -n observability-platform -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: openobserve
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - openobserve.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: openobserve-router
        port: 5080
EOF

kubectl apply -n observability-platform -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: openobserve-grpc
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - openobserve-grpc.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: openobserve-router
        port: 5081
EOF

# OTel Collector for K8s nodes/kubelet metrics and logs
helm upgrade --repo https://open-telemetry.github.io/opentelemetry-helm-charts otel-collector-k8s-nodes opentelemetry-collector \
  --version ${OPENTELEMETRY_OPERATOR_VERSION} \
  --namespace observability-platform \
  --install \
  --values - <<EOF
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s
mode: daemonset
command:
  name: otelcol-k8s
resources:
  limits:
    memory: 2Gi
presets:
  # receiver is configured to read the files where Kubernetes container runtime writes all containers console output (/var/log/pods/*/*/*.log)
  logsCollection:
    enabled: true
  # adds Kubernetes metadata, such as k8s.pod.name, k8s.namespace.name, and k8s.node.name, to logs, metrics and traces
  kubernetesAttributes:
    enabled: true
  # collects node, pod, and container metrics from the API server on a kubelet
  kubeletMetrics:
    enabled: true
  # collects k8s node metrics
  hostMetrics:
    enabled: true
config:
  receivers:
    kubeletstats:
      auth_type: serviceAccount
      collection_interval: 20s
      endpoint: \${env:K8S_NODE_IP}:10250
      insecure_skip_verify: true
  exporters:
    otlphttp/openobserve:
      endpoint: http://openobserve-router.observability-platform.svc:5080/api/default
      headers:
        Authorization: Basic cm9vdEBleGFtcGxlLmNvbTpDb21wbGV4cGFzcyMxMjM=
        stream-name: k8s_node_telemetry
  service:
    pipelines:
      logs:
        exporters:
          - otlphttp/openobserve
      metrics:
        exporters:
          - otlphttp/openobserve
      traces:
        exporters:
          - otlphttp/openobserve
EOF

# OTel Collector for K8s cluster as a whole and events from the k8s API server
helm upgrade --repo https://open-telemetry.github.io/opentelemetry-helm-charts otel-collector-k8s-cluster opentelemetry-collector \
  --version ${OPENTELEMETRY_OPERATOR_VERSION} \
  --namespace observability-platform \
  --install \
  --values - <<EOF
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s
mode: deployment
replicaCount: 1
command:
  name: otelcol-k8s
resources:
  limits:
    memory: 2Gi
presets:
  # enables the k8sclusterreceiver and adds it to the metrics pipelines
  clusterMetrics:
    enabled: true
  # enables the k8sobjectsreceiver to collect events only and adds it to the logs pipelines
  kubernetesEvents:
    enabled: true
config:
  exporters:
    otlphttp/openobserve:
      endpoint: http://openobserve-router.observability-platform.svc:5080/api/default
      headers:
        Authorization: Basic cm9vdEBleGFtcGxlLmNvbTpDb21wbGV4cGFzcyMxMjM=
        stream-name: k8s_cluster_telemetry
  service:
    pipelines:
      logs:
        exporters:
          - otlphttp/openobserve
      metrics:
        exporters:
          - otlphttp/openobserve
      traces:
        exporters:
          - otlphttp/openobserve
EOF

# OTel Collector for other apps
helm upgrade --repo https://open-telemetry.github.io/opentelemetry-helm-charts otel-collector-apps opentelemetry-collector \
  --version ${OPENTELEMETRY_OPERATOR_VERSION} \
  --namespace observability-platform \
  --install \
  --values - <<EOF
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib
mode: deployment
replicaCount: 1
command:
  name: otelcol-contrib
resources:
  limits:
    memory: 2Gi
config:
  receivers:
    kafkametrics/chaos:
      brokers:
        - chaos-kafka-kafka-bootstrap.streamhouse.svc.cluster.local:9092
      protocol_version: ${KAFKA_VERSION}
      collection_interval: 10s
      scrapers:
        - brokers
        - topics
        - consumers
    kafkametrics/stable:
      brokers:
        - stable-kafka-kafka-bootstrap.streamhouse.svc.cluster.local:9092
      protocol_version: ${KAFKA_VERSION}
      collection_interval: 10s
      scrapers:
        - brokers
        - topics
        - consumers
    # Data sources: traces, metrics, logs
    otlp/hyperdx:
      protocols:
        grpc:
          include_metadata: true
          endpoint: 0.0.0.0:4327
        http:
          cors:
            allowed_origins: ['*']
            allowed_headers: ['*']
          include_metadata: true
          endpoint: 0.0.0.0:4328
  processors:
    resource/chaos-kafka:
      attributes:
        - key: cluster_name
          value: chaos-kafka
          action: upsert
    resource/stable-kafka:
      attributes:
        - key: cluster_name
          value: stable-kafka
          action: upsert
    batch:
      send_batch_size: 8192
      timeout: 200ms
      send_batch_max_size: 0
    memory_limiter:
      # 80% of maximum memory up to 2G
      limit_mib: 1500
      # 25% of limit up to 2G
      spike_limit_mib: 512
      check_interval: 5s
    transform:
      log_statements:
        - context: log
          error_mode: ignore
          statements:
            # JSON parsing: Extends log attributes with the fields from structured log body content, either as an OTEL map or
            # as a string containing JSON content.
            - set(log.cache, ExtractPatterns(log.body, "(?P<0>(\\\\{.*\\\\}))")) where
              IsString(log.body)
            - merge_maps(log.attributes, ParseJSON(log.cache["0"]), "upsert")
              where IsMap(log.cache)
            - flatten(log.attributes) where IsMap(log.cache)
            - merge_maps(log.attributes, log.body, "upsert") where IsMap(log.body)
        - context: log
          error_mode: ignore
          conditions:
            - severity_number == 0 and severity_text == ""
          statements:
            # Infer: extract the first log level keyword from the first 256 characters of the body
            - set(log.cache["substr"], log.body.string) where Len(log.body.string)
              < 256
            - set(log.cache["substr"], Substring(log.body.string, 0, 256)) where
              Len(log.body.string) >= 256
            - set(log.cache, ExtractPatterns(log.cache["substr"],
              "(?i)(?P<0>(alert|crit|emerg|fatal|error|err|warn|notice|debug|dbug|trace))"))
            # Infer: detect FATAL
            - set(log.severity_number, SEVERITY_NUMBER_FATAL) where
              IsMatch(log.cache["0"], "(?i)(alert|crit|emerg|fatal)")
            - set(log.severity_text, "fatal") where log.severity_number ==
              SEVERITY_NUMBER_FATAL
            # Infer: detect ERROR
            - set(log.severity_number, SEVERITY_NUMBER_ERROR) where
              IsMatch(log.cache["0"], "(?i)(error|err)")
            - set(log.severity_text, "error") where log.severity_number ==
              SEVERITY_NUMBER_ERROR
            # Infer: detect WARN
            - set(log.severity_number, SEVERITY_NUMBER_WARN) where
              IsMatch(log.cache["0"], "(?i)(warn|notice)")
            - set(log.severity_text, "warn") where log.severity_number ==
              SEVERITY_NUMBER_WARN
            # Infer: detect DEBUG
            - set(log.severity_number, SEVERITY_NUMBER_DEBUG) where
              IsMatch(log.cache["0"], "(?i)(debug|dbug)")
            - set(log.severity_text, "debug") where log.severity_number ==
              SEVERITY_NUMBER_DEBUG
            # Infer: detect TRACE
            - set(log.severity_number, SEVERITY_NUMBER_TRACE) where
              IsMatch(log.cache["0"], "(?i)(trace)")
            - set(log.severity_text, "trace") where log.severity_number ==
              SEVERITY_NUMBER_TRACE
            # Infer: else
            - set(log.severity_text, "info") where log.severity_number == 0
            - set(log.severity_number, SEVERITY_NUMBER_INFO) where
              log.severity_number == 0
        - context: log
          error_mode: ignore
          statements:
            # Normalize the severity_text case
            - set(log.severity_text, ConvertCase(log.severity_text, "lower"))
  connectors:
    routing/logs:
      default_pipelines:
        - logs/out-default
      error_mode: ignore
      table:
        - context: log
          statement: route() where IsMatch(attributes["rr-web.event"], ".*")
          pipelines:
            - logs/out-rrweb
  exporters:
    otlphttp/openobserve:
      endpoint: http://openobserve-router.observability-platform.svc:5080/api/default
      headers:
        Authorization: Basic cm9vdEBleGFtcGxlLmNvbTpDb21wbGV4cGFzcyMxMjM=
        stream-name: streamhouse_apps
    clickhouse/rrweb:
      database: default
      endpoint: tcp://clickstack-clickhouse.streamhouse.svc:9000?dial_timeout=10s
      ttl: 720h
      logs_table_name: hyperdx_sessions
      timeout: 5s
      retry_on_failure:
        enabled: true
        initial_interval: 5s
        max_interval: 30s
        max_elapsed_time: 300s
    clickhouse:
      database: default
      endpoint: tcp://clickstack-clickhouse.streamhouse.svc:9000?dial_timeout=10s
      ttl: 720h
      timeout: 5s
      retry_on_failure:
        enabled: true
        initial_interval: 5s
        max_interval: 30s
        max_elapsed_time: 300s
  service:
    pipelines:
      metrics/chaos-kafka:
        receivers:
          - kafkametrics/chaos
        processors:
          - resource/chaos-kafka
        exporters:
          - otlphttp/openobserve
      metrics/stable-kafka:
        receivers:
          - kafkametrics/stable
        processors:
          - resource/stable-kafka
        exporters:
          - otlphttp/openobserve
      traces:
        receivers:
          - otlp/hyperdx
        processors: 
          - memory_limiter
          - batch
        exporters:
          - clickhouse
      metrics:
        receivers:
          - otlp/hyperdx
        processors:
          - memory_limiter
          - batch
        exporters:
          - clickhouse
      logs/in:
        receivers:
          - otlp/hyperdx
        exporters:
          - routing/logs
      logs/out-default:
        receivers:
          - routing/logs
        processors:
          - memory_limiter
          - transform
          - batch
        exporters:
          - clickhouse
      logs/out-rrweb:
        receivers:
          - routing/logs
        processors:
          - memory_limiter
          - batch
        exporters:
          - clickhouse/rrweb
EOF

# kubectl apply -n observability-platform -f - <<EOF
# apiVersion: gateway.networking.k8s.io/v1
# kind: HTTPRoute
# metadata:
#   name: otel-collector
# spec:
#   parentRefs:
#     - kind: Gateway
#       name: envoy-gateway
#       namespace: gateway-system
#       sectionName: https
#   hostnames:
#     - otel-collector.${DNSMASQ_DOMAIN}
#   rules:
#     - backendRefs:
#       - kind: Service
#         name: otel-collector
#         port: 4318
# EOF
