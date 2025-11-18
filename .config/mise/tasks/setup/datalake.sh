#!/usr/bin/env bash

#MISE description="Set up an object store datalake implemented with a MinIO Tenant"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://operator.min.io tenant tenant \
  --version ${MINIO_HELM_VERSION} \
  --namespace datalake \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
tenant:
  name: minio-datalake
  pools:
    - name: pool-0
      servers: 4
      size: 250Mi
      volumesPerServer: 4
  buckets:
    - name: zone-0-bronze
    - name: zone-1-silver
    - name: zone-2-gold
    - name: openobserve
  certificate:
    requestAutoCert: false
# ingress:
#   api:
#     enabled: true
#     ingressClassName: nginx
#     host: datalake-api.${DNSMASQ_DOMAIN}
#   console:
#     enabled: true
#     ingressClassName: nginx
#     host: datalake.${DNSMASQ_DOMAIN}
EOF
