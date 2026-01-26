#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up Lakekeeper for an Apache Iceberg Catalog built with Rust"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://lakekeeper.github.io/lakekeeper-charts lakekeeper lakekeeper \
  --version 0.9.0 \
  --namespace streamhouse \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
helmWait: true
postgresql:
  enabled: false
externalDatabase:
  host_read: ${PG_CLUSTER_NAME}-ro.streamhouse.svc
  host_write: ${PG_CLUSTER_NAME}-rw.streamhouse.svc
  database: iceberg_catalog
  user: catalog_admin
  password: iWillNeverTell
catalog:
  replicas: 2
EOF

kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lakekeeper
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - lakekeeper.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: lakekeeper
        port: 8181
EOF

# Wait for Lakekeeper to be ready
kubectl rollout status deployment/lakekeeper -n streamhouse --timeout=600s &>/dev/null

# Bootstrap Lakekeeper, accept terms of use
curl -X POST https://lakekeeper.localtest.me/management/v1/bootstrap \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "accept-terms-of-use": true,
  "is-operator": true
}
JSON

# Create a warehouse in Lakekeeper using it's REST API, pointing to the datalake's zone-0-bronze bucket... (warehouse in the front, lake in the back)
curl -X POST https://lakekeeper.localtest.me/management/v1/warehouse \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "warehouse-name": "zone_0_bronze",
  "storage-profile": {
    "type": "s3",
    "endpoint": "http://minio.streamhouse.svc",
    "bucket": "zone-0-bronze",
    "region": "us-east-1",
    "sts-enabled": false,
    "remote-signing-enabled": false,
    "flavor": "s3-compat",
    "path-style-access": true
  },
  "storage-credential": {
    "type": "s3",
    "credential-type": "access-key",
    "aws-access-key-id": "minio",
    "aws-secret-access-key": "minio123"
  },
  "delete-profile": {
    "type": "hard"
  }
}
JSON

# Create a warehouse for the zone-1-silver
curl -X POST https://lakekeeper.localtest.me/management/v1/warehouse \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "warehouse-name": "zone_1_silver",
  "storage-profile": {
    "type": "s3",
    "endpoint": "http://minio.streamhouse.svc",
    "bucket": "zone-1-silver",
    "region": "us-east-1",
    "sts-enabled": false,
    "remote-signing-enabled": false,
    "flavor": "s3-compat",
    "path-style-access": true
  },
  "storage-credential": {
    "type": "s3",
    "credential-type": "access-key",
    "aws-access-key-id": "minio",
    "aws-secret-access-key": "minio123"
  },
  "delete-profile": {
    "type": "hard"
  }
}
JSON

# Create a warehouse for the zone-2-gold
curl -X POST https://lakekeeper.localtest.me/management/v1/warehouse \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "warehouse-name": "zone_2_gold",
  "storage-profile": {
    "type": "s3",
    "endpoint": "http://minio.streamhouse.svc",
    "bucket": "zone-2-gold",
    "region": "us-east-1",
    "sts-enabled": false,
    "remote-signing-enabled": false,
    "flavor": "s3-compat",
    "path-style-access": true
  },
  "storage-credential": {
    "type": "s3",
    "credential-type": "access-key",
    "aws-access-key-id": "minio",
    "aws-secret-access-key": "minio123"
  },
  "delete-profile": {
    "type": "hard"
  }
}
JSON
