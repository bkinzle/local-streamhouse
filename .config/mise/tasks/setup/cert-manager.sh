#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up cert-manager, create a Secret for root CA, and a ClusterIssuer from the secret"
#MISE depends=["check:kubecontext"]

# Manage installation of the standard k8s Gateway API and the Envoy Gateway CRDs independently (Gateway API CRDs are required for cert-manager's Gateway support)
# using helm template within process substitution for kubectl apply instead of helm upgrade/install due to a known Helm limitation related to large CRDs in the templates/ directory
kubectl apply --namespace kube-system --server-side -f <(
  helm template gateway-crds oci://docker.io/envoyproxy/gateway-crds-helm \
    --version ${ENVOY_PROXY_GATEWAY_VERSION} \
    --values - <<EOF
crds:
  gatewayAPI:
    enabled: true
    # which Gateway API channel to use (standard or experimental)
    channel: experimental
  envoyGateway:
    # whether to include Envoy Gateway-specific CRDs
    enabled: true
EOF
)

helm upgrade cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
crds:
  enabled: true
config:
  apiVersion: controller.config.cert-manager.io/v1alpha1
  kind: ControllerConfiguration
  enableGatewayAPI: true
EOF

kubectl delete secret -n cert-manager root-ca &>/dev/null || true
kubectl create secret tls -n cert-manager root-ca --cert=.ssl/root-ca.pem --key=.ssl/root-ca-key.pem
kubectl apply -n cert-manager -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: root-ca
EOF
