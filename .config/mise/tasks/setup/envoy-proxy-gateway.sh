#!/usr/bin/env bash

#MISE description="Set up an envoy proxy gateway for ingress"
#MISE depends=["check:kubecontext"]

ENVOY_PROXY_GATEWAY_VERSION="0.0.0-latest"

# Step 1: Manage installation of the Gatwway CRDs independently
# using helm template within process substitution for kubectl apply instead of helm upgrade/install due to a known Helm limitation related to large CRDs in the templates/ directory
kubectl apply --namespace kube-system --server-side -f <(
  helm template envoy-proxy-gateway-crds oci://docker.io/envoyproxy/gateway-crds-helm \
    --version $ENVOY_PROXY_GATEWAY_VERSION \
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

# Step 2: Install or upgrade the Envoy Proxy Gateway itself
helm upgrade envoy-proxy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version $ENVOY_PROXY_GATEWAY_VERSION \
  --namespace envoy-gateway-system \
  --create-namespace \
  --install \
  --skip-crds \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
service:
  type: NodePort
deployment:
  replicas: 3
  pod:
    nodeSelector:
      ingress-ready: "true"
EOF

# Step 3: Now that the Gateway is installed, the Deployment and Service can be customized with EnvoyProxy CRD
kubectl apply -f - <<EOF
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-proxy-gateway
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 2
        pod:
          nodeSelector:
            ingress-ready: "true"
      envoyService:
        externalTrafficPolicy: Local
        type: NodePort
EOF

# Step 4: Setup the standard k8s GatewayClass using the Envoy Proxy Gateway controller
kubectl apply -n envoy-gateway-system -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF

# Step 5: Attach listeners to the Gateway (link to the EnvoyProxy)
kubectl apply -n envoy-gateway-system -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
spec:
  gatewayClassName: envoy-gateway
  infrastructure:
    parametersRef:
      group: gateway.envoyproxy.io
      kind: EnvoyProxy
      name: envoy-proxy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
EOF
