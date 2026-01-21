#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up Druid"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://wiremind.github.io/wiremind-helm-charts druid druid \
  --version 1.22.1 \
  --namespace streamhouse \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --timeout 10m0s \
  --wait-for-jobs \
  --values - <<EOF
image:
  tag: 35.0.1
extensions:
  loadList:
    - druid-basic-security
    - druid-bloom-filter
    - druid-datasketches
    - druid-histogram
    - druid-kinesis-indexing-service
    - druid-kubernetes-extensions
    - druid-lookups-cached-global
    - druid-lookups-cached-single
    - druid-pac4j
    - druid-parquet-extensions
    - druid-s3-extensions
    - druid-stats
    - postgresql-metadata-storage
    - prometheus-emitter
    - druid-kafka-indexing-service
secretEnvVars:
  druid_metadata_storage_connector_password: iWillNeverTell
configVars:
  druid_s3_endpoint_url: http://minio.streamhouse.svc.cluster.local/
  druid_s3_accessKey: minio
  druid_s3_secretKey: minio123
  druid_s3_enablePathStyleAccess: true
  druid_storage_type: s3
  druid_storage_bucket: druid-deep-storage
  druid_storage_baseKey: segments
  druid_indexer_logs_type: s3
  druid_indexer_logs_s3Bucket: druid-deep-storage
  druid_indexer_logs_s3Prefix: indexing-logs
  druid_metadata_storage_type: postgresql
  druid_metadata_storage_connector_connectURI: jdbc:postgresql://${PG_CLUSTER_NAME}-rw.streamhouse.svc:5432/druid
  druid_metadata_storage_connector_user: druid_admin
broker:
  replicaCount: 2
historical:
  defaults:
    replicaCount: 2
  tiers:
    default:
      envVars:
        DRUID_XMX: 256m
        DRUID_XMS: 256m
        DRUID_MAXDIRECTMEMORYSIZE: 400m
        druid_server_tier: "_default_tier"
        druid_segmentCache_locations: '[{"path":"/opt/druid/var/druid/segment-cache","maxSize":"1GiB"}]'
      persistence:
        size: 2Gi
indexer:
  defaults:
    replicaCount: 2
  categories:
    default:
      envVars:
        DRUID_XMX: 256m
        DRUID_XMS: 256m
        druid_worker_capacity: "1"
        druid_worker_category: "_default_worker_category"
      emptyDir:
        size: 1Gi
      persistence:
        enabled: true
        size: 1Gi
configJobs:
  dict:
    overlord-dyn-cfg:
      component:
        scheme: http
        name: coordinator
        port: 8081
        route: "/druid/indexer/v1/worker"
      payload:
        selectStrategy:
          type: "equalDistributionWithCategorySpec"
          workerCategorySpec:
            strong: true
            categoryMap:
              index_parallel:
                defaultCategory: "_default_worker_category"
              index:
                defaultCategory: "_default_worker_category"
              single_phase_sub_task:
                defaultCategory: "_default_worker_category"
              kill:
                defaultCategory: "_default_worker_category"
              compact:
                defaultCategory: "_default_worker_category"
postgresql:
  enabled: false
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: druid-router
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - druid-router.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: druid-router
        port: 8888
EOF
